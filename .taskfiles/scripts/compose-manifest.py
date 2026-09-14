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


SCHEMA = 2
MANIFEST = ".devcontainer/.volume-manifest.json"
RECOVERY = "Run task container:up on the host; after selection or mount changes, use task container:restart."


def fail(message) -> NoReturn:
    raise ValueError(f"{message}. {RECOVERY}")


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def default_env_paths(workspace, paths):
    return {workspace / ".env", paths[0].parent / ".env", workspace / ".devcontainer/.env"}


def selection(workspace):
    config_path = workspace / ".devcontainer/devcontainer.json"
    text = config_path.read_text()
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
        for path in [config_path, *paths]
    }
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


def project_manifest(workspace, service, paths, inputs, selected, project=""):
    volumes = selected.get("volumes")
    if not isinstance(volumes, list) or not volumes:
        fail("Selected service has no volume contract")
    records = []
    for volume in volumes:
        if not isinstance(volume, dict):
            fail("Malformed resolved volume")
        if volume.get("type") != "bind":
            continue
        source, target = volume.get("source"), volume.get("target")
        if not isinstance(source, str) or not isinstance(target, str) or not target.startswith("/"):
            fail("Invalid resolved bind paths")
        if "\0" in source + target or not Path(source).is_absolute():
            fail("Unresolved bind source")
        bind = volume.get("bind", {})
        # Compose's canonical JSON omits false booleans (bind: {}); short syntax
        # that permits creation is normalized to create_host_path: true.
        if not isinstance(bind, dict) or bind.get("create_host_path", False) is not False:
            fail("All selected binds must set create_host_path: false")
        candidate = Path(os.path.normpath(source))
        managed = candidate.is_relative_to(workspace / ".env.d")
        # External socket sources are never prepared. Hash their resolution, not host env.
        record = {"type": "bind", "source": str(candidate.relative_to(workspace)) if managed else "external",
                  "target": target, "bind": {"create_host_path": False},
                  "read_only": bool(volume.get("read_only", False)), "managed": managed}
        record["source_fingerprint"] = digest(source)
        records.append(record)
    if not records:
        fail("Selected service has no bind volumes")
    manifest = {"schema": SCHEMA, "service": service,
                "project_name_fingerprint": digest(project),
                "files": [str(path.relative_to(workspace)) for path in paths],
                "inputs": inputs, "volumes": records}
    manifest["id"] = digest(manifest)
    return manifest


def load_manifest(workspace, runtime=False):
    manifest = json.loads((workspace / MANIFEST).read_text())
    if not isinstance(manifest, dict) or manifest.get("schema") != SCHEMA:
        fail("Unsupported volume manifest schema")
    identity = manifest.get("id")
    if identity != digest({key: value for key, value in manifest.items() if key != "id"}):
        fail("Malformed volume manifest identity")
    if not re.fullmatch(r"[0-9a-f]{64}", manifest.get("project_name_fingerprint", "")):
        fail("Malformed volume manifest project identity")
    service, paths, inputs = selection(workspace)
    if (manifest.get("service") != service or manifest.get("inputs") != inputs
            or manifest.get("files") != [str(path.relative_to(workspace)) for path in paths]):
        fail("Stale volume manifest repository inputs")
    volumes = manifest.get("volumes")
    if not isinstance(volumes, list) or not volumes:
        fail("Malformed volume manifest records")
    for record in volumes:
        if (not isinstance(record, dict) or record.get("type") != "bind"
                or not isinstance(record.get("target"), str) or not record["target"].startswith("/")
                or not isinstance(record.get("source"), str)
                or "\0" in record["source"] + record["target"]
                or not isinstance(record.get("managed"), bool)
                or not isinstance(record.get("read_only"), bool)
                or not re.fullmatch(r"[0-9a-f]{64}", record.get("source_fingerprint", ""))
                or record.get("bind") != {"create_host_path": False}):
            fail("Malformed volume manifest bind")
        if record["managed"]:
            source = Path(record["source"])
            if source.is_absolute() or ".." in source.parts or source.parts[:1] != (".env.d",):
                fail("Unsafe managed volume manifest source")
        elif record["source"] != "external":
            fail("External volume manifest must not persist its host source")
    if runtime and (not identity or os.environ.get("GENTLE_VOLUME_MANIFEST_ID") != identity):
        fail("Desired volume manifest is not applied to this container")
    return manifest


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
    if f"GENTLE_VOLUME_MANIFEST_ID={identity}" not in environment:
        fail("Existing container uses different or unverified mounts; recreate it")


def prepare(workspace):
    service, paths, inputs, selected, project = compose_model(workspace)
    manifest = project_manifest(workspace, service, paths, inputs, selected, project)
    name = selected.get("container_name")
    if not isinstance(name, str) or not name:
        fail("Selected service requires container_name")
    check_existing_container(name, manifest["id"])
    spec = importlib.util.spec_from_file_location("bind_preparation", Path(__file__).with_name("prepare-bind-mounts.py"))
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with contextlib.redirect_stdout(sys.stderr):
        sources = set(module.managed_bind_sources(manifest["volumes"], str(workspace)))
        for path in module.required_components(sources, str(workspace)):
            module.prepare_directory(path, (os.getuid(), os.getgid()))
    # Reject concurrent repository edits before publishing the projection.
    if selection(workspace)[2] != inputs:
        fail("Compose selection changed during host preparation")
    destination = workspace / MANIFEST
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=destination.parent, delete=False) as stream:
            temporary = stream.name
            json.dump(manifest, stream, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, destination)
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)
    print(manifest["id"])


def main():
    command, root = sys.argv[1:3]
    workspace = Path(root).resolve()
    if command in {"prepare", "name", "project-name"}:
        if Path("/.dockerenv").exists() and os.environ.get("FORCE_HOST_CONTEXT") != "1":
            fail("Compose host resolution must run on the host")
        if command == "prepare":
            prepare(workspace)
        elif command == "project-name":
            print(project_name(workspace, selection(workspace)[1]))
        else:
            name = compose_model(workspace)[3].get("container_name")
            if not isinstance(name, str) or not name:
                fail("Selected service requires container_name")
            print(name)
    elif command in {"records", "runtime", "check", "ssh-server", "service"}:
        manifest = load_manifest(workspace, runtime=command in {"runtime", "ssh-server"})
        if command == "ssh-server":
            installer = workspace / ".devcontainer/install/available/4010-tool-ssh-server.sh"
            aliases = (link for group in ("02-core-tools", "03-enabled")
                       for link in (workspace / ".devcontainer/install" / group).glob("*.sh"))
            if not installer.is_file() or not any(link.is_symlink() and link.resolve() == installer.resolve()
                                                  for link in aliases):
                fail("SSH server installer is disabled")
            if (".devcontainer/compose-config/docker-compose.ssh-server.yml" not in manifest["files"]
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
    except (ValueError, OSError, KeyError, TypeError) as error:
        # Do not echo parser exceptions containing model/environment data.
        message = str(error) if isinstance(error, ValueError) and RECOVERY in str(error) else RECOVERY
        print(f"[volume-manifest:error] {message}", file=sys.stderr)
        sys.exit(1)
