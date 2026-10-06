#!/usr/bin/env python3
"""Resolve Compose on the host; publish only a versioned volume projection."""

import contextlib
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from typing import NoReturn


SCHEMA = 3
MANIFEST = ".devcontainer/.volume-manifest.json"
RECOVERY = "Run task container:up on the host; after selection or mount changes, use task container:recreate."
IDENTITY_FIELDS = {"schema", "service", "files", "project_name_fingerprint", "volumes"}
RECORD_FIELDS = {"type", "source", "source_fingerprint", "target", "managed", "read_only", "bind"}


def fail(message) -> NoReturn:
    raise ValueError(f"{message}. {RECOVERY}")


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def default_env_paths(workspace, paths):
    return {workspace / ".env", paths[0].parent / ".env", workspace / ".devcontainer/.env"}


def selection(workspace):
    config_path = workspace / ".devcontainer/devcontainer.json"
    config_bytes = config_path.read_bytes()
    text = config_bytes.decode()
    # Match strings first so comment markers and commas inside strings survive.
    text = re.sub(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/',
                  lambda match: match[0] if match[0].startswith('"') else " ", text)
    text = re.sub(r'("(?:\\.|[^"\\])*")|,\s*(?=[}\]])',
                  lambda match: match[1] or "", text)
    config = json.loads(text)
    service = config.get("service")
    files = config.get("dockerComposeFile")
    if isinstance(files, str):
        files = [files]
    if not isinstance(service, str) or not service or not isinstance(files, list) or not files:
        fail("Invalid devcontainer service or ordered Compose selection")
    paths = []
    for item in files:
        if not isinstance(item, str) or not item or "$" in item:
            fail("Compose selection must use literal repository paths")
        path = (config_path.parent / item).resolve()
        path.relative_to(workspace)
        if path in paths:
            fail("Duplicate selected Compose file")
        paths.append(path)
    inputs: dict[str, str | None] = {
        str(path.relative_to(workspace)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in paths
    }
    inputs[str(config_path.relative_to(workspace))] = hashlib.sha256(config_bytes).hexdigest()
    # Default interpolation files are repository inputs, including their absence.
    for path in default_env_paths(workspace, paths):
        inputs[str(path.relative_to(workspace))] = (
            hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None
        )
    return service, paths, inputs


def read_compose_fragment(path):
    helper = Path(__file__).with_name("yq-compatibility.sh")
    result = subprocess.run(["bash", "-c", 'source "$1"; yq_compatibility_json . "$2"',
                             "compose-input", str(helper), str(path)], capture_output=True, check=False)
    if result.returncode:
        fail("Cannot validate Compose inputs; supported yq and a single YAML mapping per file are required")
    fragment = json.loads(result.stdout) or {}
    if not isinstance(fragment, dict) or not isinstance(fragment.get("services", {}), dict):
        fail("Selected Compose files and their services must be mappings")
    return fragment


def supported_fragments(workspace, paths):
    if os.environ.get("COMPOSE_ENV_FILES"):
        fail("COMPOSE_ENV_FILES is unsupported; use the default repository .env files")
    for path in default_env_paths(workspace, paths):
        if path.exists() and re.search(r"^\s*(?:export\s+)?COMPOSE_ENV_FILES\s*=", path.read_text(), re.MULTILINE):
            fail("COMPOSE_ENV_FILES in .env is unsupported")
    fragments = []
    for path in paths:
        fragment = read_compose_fragment(path)
        services = fragment.get("services", {}).values()
        if "include" in fragment or any(isinstance(service, dict) and "extends" in service for service in services):
            fail("Compose include and extends are unsupported; list complete overrides in dockerComposeFile")
        name = fragment.get("name")
        if name is not None and (not isinstance(name, str) or "$" in name):
            fail("Compose top-level name must be literal; use COMPOSE_PROJECT_NAME for host configuration")
        fragments.append(fragment)
    return fragments


def project_name(workspace, paths):
    fragments = supported_fragments(workspace, paths)
    explicit = next((fragment["name"] for fragment in reversed(fragments) if fragment.get("name")), None)
    name = os.environ.get("COMPOSE_PROJECT_NAME") or explicit
    if not name:
        name = re.sub(r"[^a-z0-9_-]", "", workspace.name.lower()) + "_devcontainer"
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", name):
        fail("Compose project name must start with a lowercase letter or digit and contain only a-z, 0-9, _ or -")
    return name


def compose_model(workspace):
    service, paths, inputs = selection(workspace)
    project = project_name(workspace, paths)
    command = ["docker", "compose", "--project-name", project, "--project-directory", str(paths[0].parent)]
    for path in paths:
        command += ["-f", str(path)]
    # Never put full config or stderr (which may contain interpolated secrets) on disk or stdout.
    result = subprocess.run(command + ["config", "--format", "json"],
                            cwd=workspace, env={**os.environ, "COMPOSE_PROJECT_NAME": project},
                            capture_output=True, check=False)
    if result.returncode:
        fail("Compose resolution failed; check selected files and required host variables")
    model = json.loads(result.stdout)
    selected = model.get("services", {}).get(service)
    if not isinstance(selected, dict):
        fail("Selected service is absent from resolved Compose")
    return service, paths, inputs, selected, project


def canonical_path(value, absolute=False):
    if not isinstance(value, str) or not value or "\0" in value:
        return False
    if absolute:
        return value.startswith("/") and not value.startswith("//") and os.path.normpath(value) == value
    return not value.startswith("/") and all(part not in {"", ".", ".."} for part in value.split("/"))


def fingerprint(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def validate_record(record):
    if (not isinstance(record, dict) or set(record) != RECORD_FIELDS or record["type"] != "bind"
            or not canonical_path(record["target"], absolute=True)
            or type(record["managed"]) is not bool or type(record["read_only"]) is not bool
            or not fingerprint(record["source_fingerprint"])
            or not isinstance(record["bind"], dict) or set(record["bind"]) != {"create_host_path"}
            or record["bind"]["create_host_path"] is not False):
        fail("Malformed volume manifest bind")
    source = record["source"]
    if record["managed"]:
        if not canonical_path(source) or source.split("/")[0] != ".env.d":
            fail("Unsafe managed volume manifest source")
    elif source != "external":
        fail("External volume manifest must not persist its host source")


def project_bind(workspace, volume):
    if set(volume) - {"type", "source", "target", "read_only", "bind"}:
        fail("Unsupported resolved bind options")
    source, target = volume.get("source"), volume.get("target")
    if (not isinstance(source, str) or not source.startswith("/") or "\0" in source
            or not canonical_path(target, absolute=True)):
        fail("Invalid resolved bind paths")
    bind = volume.get("bind", {})
    # Compose can omit true creation flags; only an explicit false proves safety.
    if not isinstance(bind, dict) or set(bind) - {"create_host_path"}:
        fail("Unsupported resolved bind options")
    if bind.get("create_host_path") is not False:
        fail("All selected binds must set create_host_path: false")
    read_only = volume.get("read_only", False)
    if type(read_only) is not bool:
        fail("Resolved bind read_only must be boolean")
    candidate = Path(os.path.normpath(source))
    managed = candidate.is_relative_to(workspace / ".env.d")
    return {"type": "bind", "source": str(candidate.relative_to(workspace)) if managed else "external",
            "source_fingerprint": digest(str(candidate)), "target": target, "managed": managed,
            "read_only": read_only, "bind": {"create_host_path": False}}


def project_manifest(workspace, service, paths, selected, project=""):
    volumes = selected.get("volumes")
    if not isinstance(volumes, list) or not volumes:
        fail("Selected service has no volume contract")
    records = []
    for volume in volumes:
        if not isinstance(volume, dict):
            fail("Malformed resolved volume")
        if volume.get("type") != "bind":
            continue
        records.append(project_bind(workspace, volume))
    if not records:
        fail("Selected service has no bind volumes")
    manifest = {"schema": SCHEMA, "service": service,
                "project_name_fingerprint": digest(project),
                "files": [str(path.relative_to(workspace)) for path in paths],
                "volumes": sorted(records, key=lambda record: record["target"])}
    manifest["id"] = digest(manifest)
    manifest["snapshot_digest"] = digest(manifest)
    validate_manifest(manifest)
    return manifest


def validate_manifest(manifest):
    if (not isinstance(manifest, dict) or type(manifest.get("schema")) is not int
            or manifest["schema"] != SCHEMA):
        fail("Unsupported volume manifest schema; migration requires intentional host recreation with "
             "task container:recreate, never rewriting an existing container's manifest")
    if set(manifest) != IDENTITY_FIELDS | {"id", "snapshot_digest"}:
        fail("Malformed volume manifest fields")
    if (not isinstance(manifest["service"], str) or not manifest["service"] or "\0" in manifest["service"]
            or not fingerprint(manifest["project_name_fingerprint"])):
        fail("Malformed volume manifest service or project identity")
    files = manifest["files"]
    if (not isinstance(files, list) or not files or not all(canonical_path(path) for path in files)
            or len(set(files)) != len(files)):
        fail("Malformed volume manifest file selection")
    volumes = manifest.get("volumes")
    if not isinstance(volumes, list) or not volumes:
        fail("Malformed volume manifest records")
    for record in volumes:
        validate_record(record)
    targets = [record["target"] for record in volumes]
    if targets != sorted(set(targets)):
        fail("Volume manifest targets must be unique and canonical-order")
    if (not fingerprint(manifest["id"])
            or manifest["id"] != digest({key: manifest[key] for key in IDENTITY_FIELDS})):
        fail("Malformed volume manifest identity")
    if (not fingerprint(manifest["snapshot_digest"])
            or manifest["snapshot_digest"] != digest({k: v for k, v in manifest.items() if k != "snapshot_digest"})):
        fail("Malformed volume manifest snapshot integrity")


def load_manifest(workspace, runtime=False):
    manifest = json.loads((workspace / MANIFEST).read_text())
    validate_manifest(manifest)
    if runtime and os.environ.get("DEVCONTAINER_BIND_MANIFEST_ID") != manifest["id"]:
        fail("Stored volume snapshot is not applied to this container")
    return manifest


def check_ssh_agent(manifest):
    """Check only the already validated applied snapshot, never live Compose."""
    if ".devcontainer/config/compose/docker-compose.ssh-agent.yml" not in manifest["files"]:
        fail("SSH agent override is not applied")
    records = {record["target"]: record for record in manifest["volumes"]}
    agent = records.get("/ssh-agent", {})
    state = records.get("/home/ubuntu/.ssh", {})
    if (agent.get("managed") is not False or agent.get("source") != "external"
            or state.get("managed") is not True or state.get("source") != ".env.d/.ssh"
            or state.get("read_only") is not False):
        fail("SSH agent requires its external socket and writable managed .ssh binds")


def check_existing_container(name, identity):
    result = subprocess.run(["docker", "container", "ls", "-a", "--format", "{{.Names}}"],
                            capture_output=True, check=False, text=True)
    if result.returncode:
        fail("Cannot check existing container mount identity")
    if name not in result.stdout.splitlines():
        return
    result = subprocess.run(["docker", "container", "inspect", name], capture_output=True, check=False)
    if result.returncode:
        fail("Cannot inspect existing container mount identity")
    environment = json.loads(result.stdout)[0].get("Config", {}).get("Env", [])
    if f"DEVCONTAINER_BIND_MANIFEST_ID={identity}" not in environment:
        fail("Existing container uses different or unverified mounts; recreate it")


def attachment(workspace):
    """Read-only policy: resolve the exact target before allowing warning-only drift."""
    service, paths, inputs, selected, project = compose_model(workspace)
    name = selected.get("container_name")
    if not isinstance(name, str) or not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_.-]*", name):
        fail("Selected service requires a valid container_name")
    result = subprocess.run(["docker", "container", "ls", "-a", "--format", "{{.Names}}"],
                            capture_output=True, check=False, text=True)
    if result.returncode:
        fail("Cannot look up attachment target")
    names = result.stdout.splitlines()
    if any(not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_.-]*", item) for item in names) or len(names) != len(set(names)):
        fail("Malformed attachment lookup")
    if name not in names:
        check_preparation_inputs(workspace, inputs)
        return "absent"
    result = subprocess.run(["docker", "container", "inspect", name], capture_output=True, check=False)
    if result.returncode:
        fail("Cannot inspect attachment target")
    data = json.loads(result.stdout)
    if not isinstance(data, list) or len(data) != 1 or not isinstance(data[0], dict):
        fail("Malformed attachment inspection")
    container = data[0]
    state = container.get("State")
    config = container.get("Config")
    if (container.get("Name") != "/" + name or not isinstance(state, dict)
            or not isinstance(config, dict) or not isinstance(config.get("Env"), list)
            or not all(isinstance(item, str) and "=" in item for item in config["Env"])
            or type(state.get("Running")) is not bool or type(state.get("Paused")) is not bool
            or type(state.get("Restarting")) is not bool):
        fail("Malformed attachment target or state")
    status = state.get("Status")
    if state["Paused"] or state["Restarting"]:
        fail("Attachment target is in an unsupported state")
    if status in {"created", "exited"} and not state["Running"]:
        check_preparation_inputs(workspace, inputs)
        return "stopped"
    if status != "running" or not state["Running"]:
        fail("Attachment target is in an unsupported state")
    warnings = []
    tokens = [item.split("=", 1)[1] for item in config["Env"]
              if item.startswith("DEVCONTAINER_BIND_MANIFEST_ID=")]
    if len(tokens) > 1:
        fail("Malformed attachment creation identity")
    token = tokens[0] if tokens else ""
    if not fingerprint(token):
        warnings.append("Creation bind identity is missing or unverified")
    try:
        stored = load_manifest(workspace)
        if stored["id"] != token:
            warnings.append("Stored bind snapshot is not applied to the running container")
    except (ValueError, OSError, KeyError, TypeError):
        warnings.append("Stored bind snapshot is missing or invalid")
    try:
        desired = project_manifest(workspace, service, paths, selected, project)
        if desired["id"] != token:
            warnings.append("Desired bind contract differs from the running container")
    except (ValueError, OSError, KeyError, TypeError):
        warnings.append("Desired bind contract cannot be verified")
    check_preparation_inputs(workspace, inputs)
    for warning in warnings:
        print(f"[attachment:warning] {warning}; attaching without preparation. "
              "Intentional HOST task container:recreate is required to apply bind changes.", file=sys.stderr)
    return "running"


def prepare(workspace):
    service, paths, inputs, selected, project = compose_model(workspace)
    manifest = project_manifest(workspace, service, paths, selected, project)
    name = selected.get("container_name")
    if not isinstance(name, str) or not name:
        fail("Selected service requires container_name")
    check_existing_container(name, manifest["id"])
    check_preparation_inputs(workspace, inputs)
    spec = importlib.util.spec_from_file_location("bind_preparation", Path(__file__).with_name("prepare-bind-mounts.py"))
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with contextlib.redirect_stdout(sys.stderr):
        sources = set(module.managed_bind_sources(manifest["volumes"], str(workspace)))
        for path in module.required_components(sources, str(workspace)):
            module.prepare_directory(path, (os.getuid(), os.getgid()))
    destination = workspace / MANIFEST
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=destination.parent, delete=False) as stream:
            temporary = stream.name
            json.dump(manifest, stream, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        # Keep raw input tokens ephemeral and recheck immediately before publication.
        check_preparation_inputs(workspace, inputs)
        os.replace(temporary, destination)
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)
    print(manifest["id"])


def check_preparation_inputs(workspace, inputs):
    if selection(workspace)[2] != inputs:
        fail("Compose selection changed during host preparation")


def main():
    command, root = sys.argv[1:3]
    workspace = Path(root).resolve()
    if command in {"prepare", "name", "project-name", "attachment"}:
        if Path("/.dockerenv").exists() and os.environ.get("FORCE_HOST_CONTEXT") != "1":
            fail("Compose host resolution must run on the host")
        if command == "attachment":
            print(attachment(workspace))
        elif command == "prepare":
            prepare(workspace)
        elif command == "project-name":
            print(project_name(workspace, selection(workspace)[1]))
        else:
            name = compose_model(workspace)[3].get("container_name")
            if not isinstance(name, str) or not name:
                fail("Selected service requires container_name")
            print(name)
    elif command in {"records", "runtime", "check", "ssh-server", "ssh-agent", "service"}:
        manifest = load_manifest(workspace, runtime=command in {"runtime", "ssh-server", "ssh-agent"})
        if command == "ssh-agent":
            check_ssh_agent(manifest)
            return
        if command == "ssh-server":
            installer = workspace / ".devcontainer/install/available/4010-tool-ssh-server.sh"
            aliases = (link for group in ("02-core-tools", "03-enabled")
                       for link in (workspace / ".devcontainer/install" / group).glob("*.sh"))
            if not installer.is_file() or not any(link.is_symlink() and link.resolve() == installer.resolve()
                                                  for link in aliases):
                fail("SSH server installer is disabled")
            if (".devcontainer/config/compose/docker-compose.ssh-server.yml" not in manifest["files"]
                    or not any(record.get("managed") is True
                               and record["source"] == ".env.d/.ssh-server"
                               and record["target"] == "/home/ubuntu/.ssh-server"
                               and not record.get("read_only") for record in manifest["volumes"])):
                fail("SSH server requires its selected persisted-key override")
        if command == "service":
            print(manifest["service"])
        elif command != "check":
            print(json.dumps(manifest["volumes"]))
    else:
        fail("Unknown volume manifest operation")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError, AttributeError) as error:
        # Do not echo parser exceptions containing model/environment data.
        message = str(error) if isinstance(error, ValueError) and RECOVERY in str(error) else RECOVERY
        print(f"[volume-manifest:error] {message}", file=sys.stderr)
        sys.exit(1)
