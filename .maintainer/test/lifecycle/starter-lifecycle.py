#!/usr/bin/env python3
"""Explicit, expensive base lifecycle proof. Importing this module is inert."""

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import stat
import subprocess
import sys


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from test_resources import LABEL, Run, Unsafe

VERIFY_CHECKS = frozenset({"container-replaced", "managed-state", "candidate-unchanged", "locale-timezone"})
TEST_LOCALE = "en_GB.UTF-8"
TEST_TIMEZONE = "Europe/Madrid"


def failure_message(lifecycle):
    check = getattr(lifecycle, "verify_check", None)
    detail = f"; verify check: {check}" if check in VERIFY_CHECKS else ""
    if check == "candidate-unchanged" and hasattr(lifecycle, "snapshot_diagnostic"):
        detail += "; snapshot difference: " + ", ".join(
            f"{key}={value}" for key, value in lifecycle.snapshot_diagnostic.items())
    return "Sandbox failed" + detail + "; stage/exit are retained in the run inventory; private output withheld"


def snapshot_difference(before, after):
    """Summarize snapshot differences without disclosing paths or file contents."""
    counts = {key: 0 for key in ("added", "removed", "mode", "kind", "hash-or-link", "identity")}
    for key in ("head", "branch", "index"):
        counts["identity"] += before[key] != after[key]
    original, current = before["files"], after["files"]
    for name in original.keys() | current.keys():
        if name not in original:
            counts["added"] += 1
        elif name not in current:
            counts["removed"] += 1
        elif original[name] != current[name]:
            old, new = original[name], current[name]
            if old is None or new is None:
                counts["kind"] += 1
            else:
                counts["mode"] += old[0] != new[0]
                counts["kind"] += old[1] != new[1]
                counts["hash-or-link"] += old[2:] != new[2:]
    return counts


def run(*args, cwd=None, env=None):
    environment = {**(os.environ if env is None else env), "GIT_OPTIONAL_LOCKS": "0"}
    return subprocess.check_output(args, cwd=cwd, env=environment, stderr=subprocess.PIPE, text=True).rstrip("\n")


def resolver(root):
    spec = importlib.util.spec_from_file_location("compose_manifest", root / ".taskfiles/scripts/compose-manifest.py")
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def public_path(name):
    path = Path(name)
    return not (any(part.startswith(".env") and part != ".env.example" for part in path.parts)
                or any(part in {".git", ".pi", ".atl", ".base-backup", "node_modules", ".cache",
                                "__pycache__", "coverage", "dist", ".vscode", ".ssh", ".aws",
                                ".gnupg", ".docker"} for part in path.parts)
                or any(part.endswith("-config.local") for part in path.parts)
                or path.suffix in {".key", ".pem", ".pyc", ".pyo"}
                or path.name.startswith(("id_rsa", "id_ed25519"))
                or path.name in {".volume-manifest.json", ".npmrc", ".netrc"})


def snapshot(root):
    """Never follow symlinks or hash excluded runtime/credential files."""
    paths = run("git", "ls-files", "-co", "--exclude-standard", "-z", cwd=root).split("\0")
    files = {}
    for name in sorted(set(paths) - {""}):
        if not public_path(name):
            continue
        path = root / name
        try:
            metadata = path.lstat()
        except FileNotFoundError:
            files[name] = None
            continue
        mode = stat.S_IMODE(metadata.st_mode)
        if path.is_symlink():
            files[name] = [mode, "link", os.readlink(path)]
        elif stat.S_ISREG(metadata.st_mode):
            # Reject symlinked parent directories rather than reading outside the repository.
            if path.resolve() != path.absolute():
                raise ValueError("Snapshot input has a symlinked parent; use a plain repository copy")
            files[name] = [mode, "file", hashlib.sha256(path.read_bytes()).hexdigest()]
        else:
            files[name] = [mode, "other"]
    return {"head": run("git", "rev-parse", "HEAD", cwd=root),
            "branch": run("git", "rev-parse", "--abbrev-ref", "HEAD", cwd=root),
            "index": run("git", "ls-files", "--stage", "-z", cwd=root),
            "files": files}


def expected_after_setup(root, configured):
    """Predict setup's public file modes without changing the candidate."""
    ignored = run("git", "ls-files", "--others", "--ignored", "--exclude-standard",
                  "--directory", "-z", cwd=root).split("\0")
    ignored_dirs = tuple(path.rstrip("/") + "/" for path in ignored if path.endswith("/"))
    tracked = {}
    for entry in configured["index"].split("\0"):
        if entry:
            mode, _, path = entry.partition("\t")
            tracked[path] = mode.split(" ", 1)[0]
    files = {}
    for name, value in configured["files"].items():
        if value is None or value[1] != "file" or name.startswith(ignored_dirs):
            files[name] = value
            continue
        mode = {"100644": 0o644, "100755": 0o755}.get(tracked.get(name, ""))
        files[name] = [mode if mode is not None else (0o755 if Path(name).name.endswith(".sh") else 0o644), *value[1:]]
    return {**configured, "files": files}


def configure(root):
    """Select the public base and core state; do not merge Compose in Python."""
    module = resolver(root)
    service, paths, _ = module.selection(root)
    base = root / ".devcontainer/docker-compose.yml"
    if paths[0] != base or service != "container-svc":
        raise ValueError("Base fixture requires docker-compose.yml first and service container-svc; review customization")
    config = {
        "name": "starter-lifecycle", "dockerComposeFile": [
            "./docker-compose.yml", "./config/compose/docker-compose-core-tools.yml"],
        "service": service, "workspaceFolder": "/home/ubuntu/${localEnv:APP_NAME}",
        "overrideCommand": True, "remoteUser": "ubuntu",
        "mounts": ["source=${localWorkspaceFolder},target=/home/ubuntu/${localEnv:APP_NAME},type=bind"],
        "postCreateCommand": "bash ${containerWorkspaceFolder}/.devcontainer/setup.sh",
    }
    (root / ".devcontainer/devcontainer.json").write_text(json.dumps(config, indent=4) + "\n")
    disabled = {"3030-ai-pi-coding.sh", "4010-tool-ssh-server.sh"}
    for link in (root / ".devcontainer/install/03-enabled").iterdir():
        if link.is_symlink() and link.resolve().name in disabled:
            link.unlink()
    for name in (".env", ".devcontainer/.env"):
        (root / name).write_text("")
        (root / name).chmod(0o600)
    (root / ".env").write_text(f"LOCALE={TEST_LOCALE}\nTZ={TEST_TIMEZONE}\n")


class Lifecycle:
    def __init__(self, root, scratch, ownership):
        self.root = root
        self.scratch = scratch
        self.ownership = ownership
        self.candidate = scratch / ("starter-lifecycle-" + ownership.data["run"])
        self.home = scratch / "home"
        self.home.mkdir(mode=0o700)
        self.env = {"PATH": os.environ["PATH"], "HOME": str(self.home), "LANG": "C.UTF-8",
                    "DOCKER_HOST": "unix:///var/run/docker.sock", "PYTHONDONTWRITEBYTECODE": "1"}
        self.project = self.candidate.name + "_devcontainer"
        self.env["COMPOSE_PROJECT_NAME"] = self.project
        self.bind_metadata = {}
        self.attachment_scenario = False
        self.allow_generated_dockerfile_read = False
        self.before = snapshot(root)
        self.source_status = run("git", "status", "--porcelain=v1", "--untracked-files=all", cwd=root)

    def docker(self, *args):
        return run("docker", *args, env=self.env)

    def capture_resources(self):
        self.ownership.capture()

    def label_candidate(self):
        path = self.candidate / ".devcontainer/docker-compose.yml"
        fragment = resolver(self.candidate).read_compose_fragment(path)
        labels = {LABEL: self.ownership.data["run"]}
        service = fragment["services"]["container-svc"]
        service["labels"] = {**service.get("labels", {}), **labels}
        service["build"]["labels"] = {**service["build"].get("labels", {}), **labels}
        fragment["networks"] = {"default": {"labels": labels}}
        path.write_text(json.dumps(fragment, indent=2) + "\n")

    def validate_private_selection(self):
        """Opt-in guard only; never require an active producer or current desired core."""
        if not getattr(self, "allow_generated_dockerfile_read", False):
            return
        adapter = getattr(self, "_generated_read_adapter", None)
        if adapter is None:
            raise Unsafe("Private plugin selection has not been prepared")
        adapter.validate_selection(self.env)

    def task(self, action):
        self.validate_private_selection()
        self.ownership.produce(["task", f"container:{action}"], self.candidate,
                               {**self.env, "FORCE_HOST_CONTEXT": "1"}, action)

    def resolve(self):
        # Resolver uses the process environment; install only the synthetic fixture environment.
        os.environ.update(self.env)
        module = resolver(self.candidate)
        service, _, _, selected, project = module.compose_model(self.candidate)
        if project != self.project:
            raise ValueError("Unexpected sandbox project identity")
        return module, service, selected

    def validate_base(self):
        # Reject file-backed integrations before Compose can read their contents.
        module = resolver(self.candidate)
        raw = module.read_compose_fragment(self.candidate / ".devcontainer/docker-compose.yml")
        services = raw.get("services", {})
        if set(services) != {"container-svc"} or "include" in raw:
            raise ValueError("Base fixture requires one self-contained container-svc service")
        service_input = services["container-svc"]
        if service_input.get("env_file") != ["../.env"] or any(key in service_input for key in ("extends", "secrets", "configs")):
            raise ValueError("Base fixture accepts only synthetic ../.env; move file-backed integrations to overrides")
        core = module.read_compose_fragment(
            self.candidate / ".devcontainer/config/compose/docker-compose-core-tools.yml")
        if (set(core) != {"services"} or set(core["services"]) != {"container-svc"}
                or set(core["services"]["container-svc"]) - {"volumes", "ports"}):
            raise ValueError("Core fixture accepts only container-svc volumes and ports")
        module, service, selected = self.resolve()
        _, paths, _ = module.selection(self.candidate)
        fragment = module.read_compose_fragment(paths[0])
        if set(fragment.get("services", {})) != {service} or any(key in fragment for key in ("volumes", "networks", "secrets", "configs")):
            raise ValueError("Base fixture requires one service and no custom top-level resources")
        if any(key in selected for key in ("secrets", "configs", "devices", "volumes_from", "network_mode", "depends_on")):
            raise ValueError("Unsupported base service integration; isolate it in an optional Compose file")
        build = selected.get("build", {})
        if Path(build.get("context", "")).resolve() != self.candidate / ".devcontainer" or any(key in build for key in ("ssh", "secrets", "additional_contexts")):
            raise ValueError("Base fixture requires local .devcontainer build context without credentials")
        dockerfile = (self.candidate / ".devcontainer" / build.get("dockerfile", "Dockerfile")).resolve()
        if dockerfile != self.candidate / ".devcontainer/Dockerfile":
            raise ValueError("Base fixture requires the repository-local .devcontainer/Dockerfile")
        if selected.get("container_name") != self.candidate.name + "-run":
            raise ValueError("Base fixture requires generated APP_NAME container identity")
        if selected.get("image") != self.candidate.name + "-img:0.1":
            raise ValueError("Base fixture requires generated APP_NAME image identity")
        manifest = module.project_manifest(self.candidate, service, paths, selected, self.project)
        if len(manifest["volumes"]) != len(selected.get("volumes", [])) or not all(v["managed"] and not v["read_only"] for v in manifest["volumes"]):
            raise ValueError("Base fixture accepts only writable managed .env.d binds; move sockets/external mounts to overrides")
        return manifest

    def container(self):
        _, service, _ = self.resolve()
        ids = self.docker("ps", "-q", "--no-trunc", "--filter", f"label=com.docker.compose.project={self.project}",
                          "--filter", f"label=com.docker.compose.service={service}").split()
        if len(ids) != 1:
            raise RuntimeError("Expected exactly one running sandbox service container")
        self.capture_resources()
        return ids[0]

    def assert_state(self, container, write=False):
        module = resolver(self.candidate)
        manifest = module.load_manifest(self.candidate)
        # Inspect only needed fields, never persist a resolved environment or full inspect.
        mounts = json.loads(self.docker("inspect", "--format", "{{json .Mounts}}", container))
        identity = self.docker("exec", "--user", "ubuntu", container, "printenv", "DEVCONTAINER_BIND_MANIFEST_ID")
        if identity != manifest["id"]:
            raise RuntimeError("Created container does not have the applied manifest identity")
        if self.docker("exec", "--user", "ubuntu", container, "id", "-un") != "ubuntu":
            raise RuntimeError("Noninteractive connection did not use ubuntu")
        for record in manifest["volumes"]:
            source = self.candidate / record["source"]
            target = record["target"]
            if not any(m["Type"] == "bind" and m["Source"] == str(source) and m["Destination"] == target and m["RW"] for m in mounts):
                raise RuntimeError("Actual managed bind differs from applied manifest")
            owner = self.docker("exec", container, "stat", "-c", "%u:%g:%a", target)
            metadata = source.stat()
            if owner != f"{metadata.st_uid}:{metadata.st_gid}:{stat.S_IMODE(metadata.st_mode):o}" or metadata.st_uid != os.getuid():
                raise RuntimeError("Managed bind-root ownership or mode changed")
            if write:
                self.bind_metadata[target] = owner
            elif self.bind_metadata.get(target) != owner:
                raise RuntimeError("Managed bind-root metadata changed across recreation")
            marker = "." + self.candidate.name + "-marker"
            script = 'test ! -e "$1/$2" && (umask 077; printf "%s" "$2" > "$1/$2")' if write else 'test "$(cat "$1/$2")" = "$2"'
            self.docker("exec", "--user", "ubuntu", container, "bash", "-c", script, "marker", target, marker)
            if (source / marker).read_text() != marker:
                raise RuntimeError("Sandbox host marker differs from connected container state")

    def assert_locale(self, container):
        expected = {"LOCALE": TEST_LOCALE, "TZ": TEST_TIMEZONE}
        root_values = (self.candidate / ".env").read_text().splitlines()
        generated = (self.candidate / ".devcontainer/.env").read_text().splitlines()
        for key, value in expected.items():
            if root_values.count(f"{key}={value}") != 1 or generated.count(f"{key}={value}") != 1:
                raise RuntimeError(f"Candidate root or generated {key} differs from fixture")
        for key, value in {"LOCALE": TEST_LOCALE, "LANG": TEST_LOCALE,
                           "LC_ALL": TEST_LOCALE, "TZ": TEST_TIMEZONE}.items():
            if self.docker("exec", "--user", "ubuntu", container, "printenv", key) != value:
                raise RuntimeError(f"Container {key} differs from candidate locale fixture")
        available = self.docker("exec", "--user", "ubuntu", container, "locale", "-a").splitlines()
        if TEST_LOCALE.lower().replace("-", "") not in {value.lower().replace("-", "") for value in available}:
            raise RuntimeError("Candidate locale was not generated")
        if self.docker("exec", container, "readlink", "-f", "/etc/localtime") != f"/usr/share/zoneinfo/{TEST_TIMEZONE}":
            raise RuntimeError("Container timezone link differs from candidate fixture")

    def execute(self):
        self.ownership.arm()
        self.ownership.probe_bind()
        self.ownership.stage("prepare")
        self.ownership.produce(["bash", str(HERE / "create-candidate.sh"), str(self.root), str(self.candidate)],
                               self.root, self.env, "prepare")
        configure(self.candidate)
        for path in self.candidate.rglob("*"):
            if ".git" not in path.relative_to(self.candidate).parts and path.is_symlink() and not path.resolve().is_relative_to(self.candidate):
                raise ValueError("Candidate has an escaping symlink; replace it with a repository-local input before lifecycle execution")
        port = run("bash", ".taskfiles/scripts/project-identity.sh", "-o", "code", cwd=self.candidate, env=self.env)
        self.env.update(APP_NAME=self.candidate.name, APP_PORT=port, OPENCODE_PORT=str(int(port) + 1))
        self.validate_base()
        self.label_candidate()
        configured = expected_after_setup(self.candidate, snapshot(self.candidate))
        if getattr(self, "allow_generated_dockerfile_read", False):
            spec = importlib.util.spec_from_file_location("generated_read", HERE / "generated-dockerfile-read.py")
            assert spec and spec.loader
            adapter = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(adapter)
            adapter.prepare(self)
            self._generated_read_adapter = adapter
        self.task("build")
        self.task("up")
        first = self.container()
        self.assert_state(first, write=True)
        self.verify_check = "locale-timezone"
        self.assert_locale(first)
        self.task("recreate")
        second = self.container()
        self.ownership.stage("verify")
        self.verify_check = "container-replaced"
        if first == second:
            raise RuntimeError("Recreate did not replace the service container")
        self.verify_check = "managed-state"
        self.assert_state(second)
        self.verify_check = "locale-timezone"
        self.assert_locale(second)
        self.verify_check = "candidate-unchanged"
        current = snapshot(self.candidate)
        if current != configured:
            self.snapshot_diagnostic = snapshot_difference(configured, current)
            raise RuntimeError("Candidate public source bytes, links, or modes changed")
        self.verify_check = None
        if getattr(self, "attachment_scenario", False):
            self.assert_attachment(second)
            if snapshot(self.candidate) != configured:
                raise Unsafe("Attachment fixture did not restore candidate public state")

    def fixture_state(self):
        """Hash only synthetic candidate state; never print contents or hashes."""
        names = [self.candidate / name for name in
                 (".env", ".devcontainer/.env", ".devcontainer/.volume-manifest.json", ".env.d")]
        state = {}
        for base in names:
            paths = [base, *base.rglob("*")] if base.is_dir() and not base.is_symlink() else [base]
            for path in paths:
                metadata = path.lstat()
                if path.is_symlink():
                    if path == base:
                        raise Unsafe("Synthetic state root contains a symlink")
                    state[str(path.relative_to(self.candidate))] = (
                        metadata.st_uid, metadata.st_gid, stat.S_IMODE(metadata.st_mode), "link", os.readlink(path))
                    continue
                if path.resolve() != path.absolute():
                    raise Unsafe("Attachment state has a symlinked parent")
                if not (stat.S_ISDIR(metadata.st_mode) or stat.S_ISREG(metadata.st_mode)):
                    raise Unsafe("Attachment state contains an unsupported file")
                state[str(path.relative_to(self.candidate))] = (
                    metadata.st_uid, metadata.st_gid, stat.S_IMODE(metadata.st_mode),
                    "directory" if path.is_dir() else hashlib.sha256(path.read_bytes()).hexdigest())
        return state

    def attachment_identity(self, container):
        if self.container() != container:
            raise Unsafe("Attachment selected a different container")
        return self.docker("inspect", "--format", "{{.Id}} {{json .Mounts}}", container)

    def connect_payload(self, container, warning=None, expect_failure=False, prepare_marker=True):
        """Real connect -> ensure-running -> run-devcontainer -> CLI exec, no TTY."""
        self.validate_private_selection()
        marker = self.ownership.data["run"] + ":" + (container or "startup")
        workspace = "/home/ubuntu/" + self.candidate.name
        # A fixture-only marker inside this exact ID distinguishes even containers
        # sharing the same workspace bind. Docker exec sets up the proof, not attach.
        if container and prepare_marker:
            self.docker("exec", "--user", "ubuntu", container, "bash", "-c",
                        'umask 077; printf "%s" "$1" > /tmp/starter-attachment-id', "marker", marker)
        payload = self.candidate / ".maintainer/attachment-payload.sh"
        identity_check = (f'test "$(cat /tmp/starter-attachment-id)" = {shlex.quote(marker)}\n'
                          if container else
                          f'umask 077; printf "%s" {shlex.quote(marker)} > /tmp/starter-attachment-id\n')
        payload.write_text("#!/bin/bash\nset -eu\n"
                           'test "$(id -un)" = ubuntu\n'
                           f'test "$PWD" = {shlex.quote(workspace)}\n'
                           + identity_check +
                           f'test "$(cat .maintainer/attachment-workspace)" = {shlex.quote(self.ownership.data["run"])}\n'
                           f"printf '%s\\n' {shlex.quote('ATTACHMENT_OK:' + marker)}\n")
        selection_validated = False
        try:
            budget = "120" if container and prepare_marker else "600"
            self.ownership.stage("verify")  # Clear stale exit evidence before a possible producer failure.
            self.validate_private_selection()
            selection_validated = True
            self.ownership.produce(["timeout", "--kill-after=10", budget, "task", "container:connect"], self.candidate,
                                   {**self.env, "FORCE_HOST_CONTEXT": "1"}, "verify")
        except Unsafe:
            if not selection_validated or not expect_failure or self.ownership.data.get("exit") in (None, 0, 124, 137):
                raise
        else:
            if expect_failure:
                raise Unsafe("Strict attachment startup unexpectedly succeeded")
        finally:
            payload.unlink()
        output = (self.scratch / "task.log").read_text()
        receipt = "ATTACHMENT_OK:" + marker
        if expect_failure:
            if "ATTACHMENT_OK:" in output or "duplicate LOCALE" not in output:
                raise Unsafe("Strict startup did not reject the intentional input before connection")
        elif output.splitlines().count(receipt) != 1 or (warning and warning not in output):
            raise Unsafe("Task connection receipt or expected warning missing")
        if not expect_failure:
            connected = self.container()
            if container and connected != container:
                raise Unsafe("Task connection replaced or selected a different target")
            if self.docker("exec", "--user", "ubuntu", connected, "cat", "/tmp/starter-attachment-id") != marker:
                raise Unsafe("Task payload did not run in the exact selected target")
            return connected

    def preserving_attachment(self, container, warning):
        before = self.fixture_state(), self.attachment_identity(container)
        self.connect_payload(container, warning)
        if before != (self.fixture_state(), self.attachment_identity(container)):
            raise Unsafe("Attachment mutated synthetic applied state, mounts or identity")

    def owned_operation(self, container, operation):
        self.validate_private_selection()
        self.ownership.capture()
        if container not in self.ownership.data["resources"]["container"]:
            raise Unsafe("Attachment fixture target is not registered")
        if self.ownership.inspect_owned("container", container) is None:
            raise Unsafe("Attachment fixture target disappeared")
        self.validate_private_selection()
        self.ownership.produce(["docker", operation, container], self.candidate, self.env, "verify")

    def assert_attachment(self, container):
        taskfile = self.candidate / ".taskfiles/devcontainer.yml"
        original = taskfile.read_bytes()
        old = b"ARGS: exec --workspace-folder {{.WORKSPACE}} bash --rcfile .taskfiles/scripts/container-connect.bash -i"
        if original.count(old) != 1:
            raise Unsafe("Unsupported connect payload; fixture adaptation requires exact task shape")
        taskfile.write_bytes(original.replace(old, b"ARGS: exec --workspace-folder {{.WORKSPACE}} bash .maintainer/attachment-payload.sh"))
        workspace_marker = self.candidate / ".maintainer/attachment-workspace"
        workspace_marker.write_text(self.ownership.data["run"])
        core = self.candidate / ".devcontainer/config/compose/docker-compose-core-tools.yml"
        core_original = core.read_bytes()
        root_env = self.candidate / ".env"
        env_original = root_env.read_bytes()
        try:
            module = resolver(self.candidate)
            fragment = module.read_compose_fragment(core)
            fragment["services"]["container-svc"]["volumes"].append({
                "type": "bind", "source": "../.env.d/attachment-new", "target": "/home/ubuntu/attachment-new",
                "bind": {"create_host_path": False}})
            core.write_text(json.dumps(fragment) + "\n")
            self.preserving_attachment(container, "Desired bind contract differs")
            core.write_bytes(core_original)

            # Invalid startup inputs must fail for stopped AND absent targets,
            # without an implicit recreate or payload. Restore fixture bytes.
            self.owned_operation(container, "stop")
            root_env.write_bytes(env_original + b"\nLOCALE=invalid-locale\n")
            self.connect_payload(None, expect_failure=True)
            if self.docker("inspect", "--format", "{{.Id}} {{.State.Running}}", container) != container + " false":
                raise Unsafe("Failed strict startup changed the stopped target")
            root_env.write_bytes(env_original)
            self.connect_payload(container, prepare_marker=False)
            self.owned_operation(container, "stop")
            self.owned_operation(container, "rm")
            root_env.write_bytes(env_original + b"\nLOCALE=invalid-locale\n")
            self.connect_payload(None, expect_failure=True)
            if self.docker("ps", "-aq", "--filter", f"name=^/{self.candidate.name}-run$"):
                raise Unsafe("Failed absent startup created a target")
            root_env.write_bytes(env_original)
            replacement = self.connect_payload(None)
            if replacement == container:
                raise Unsafe("Absent startup did not create a new target")
            self.missing_token_attachment(replacement)
            print("[starter-lifecycle:attachment] Task/CLI payload, running drift/missing-token preservation, "
                  "stopped/absent strict startup and input-error routing verified; simulated HOST in CONTAINER.")
        finally:
            core.write_bytes(core_original)
            root_env.write_bytes(env_original)
            taskfile.write_bytes(original)
            workspace_marker.unlink()

    def missing_token_attachment(self, container):
        """Create one scoped running fixture without provisioning or token fallback."""
        self.validate_private_selection()
        mounts = json.loads(self.docker("inspect", "--format", "{{json .Mounts}}", container))
        labels = json.loads(self.docker("inspect", "--format", "{{json .Config.Labels}}", container))
        image = self.docker("inspect", "--format", "{{.Image}}", container)
        argv = ["docker", "create", "--name", self.candidate.name + "-run", "--network", "none",
                "--user", "ubuntu", "--workdir", "/home/ubuntu/" + self.candidate.name]
        for key in (LABEL, "com.docker.compose.project", "com.docker.compose.service",
                    "devcontainer.local_folder", "devcontainer.config_file"):
            if not isinstance(labels.get(key), str) or not labels[key]:
                raise Unsafe("Missing fixture ownership or CLI selection label")
            argv.extend(["--label", key + "=" + labels[key]])
        if labels[LABEL] != self.ownership.data["run"] or labels["com.docker.compose.project"] != self.project:
            raise Unsafe("Missing-token fixture ownership mismatch")
        for mount in mounts:
            source = Path(mount["Source"])
            if (mount["Type"] != "bind" or not mount["RW"] or source.resolve() != source
                    or not source.is_relative_to(self.candidate) or "," in str(source)
                    or "," in mount["Destination"]):
                raise Unsafe("Unsupported missing-token fixture mount")
            argv.extend(["--mount", f'type=bind,source={source},target={mount["Destination"]}'])
        argv.extend([image, "sleep", "infinity"])
        self.owned_operation(container, "stop")
        self.owned_operation(container, "rm")
        self.validate_private_selection()
        self.ownership.produce(argv, self.candidate, self.env, "verify")
        self.capture_resources()
        ids = self.docker("ps", "-aq", "--no-trunc", "--filter", f"name=^/{self.candidate.name}-run$").split()
        if len(ids) != 1:
            raise Unsafe("Missing-token fixture target is ambiguous")
        fixture = ids[0]
        self.owned_operation(fixture, "start")
        token = self.docker("inspect", "--format",
                            '{{range .Config.Env}}{{if eq (index (split . "=") 0) "DEVCONTAINER_BIND_MANIFEST_ID"}}present{{end}}{{end}}', fixture)
        if token:
            raise Unsafe("Missing-token fixture inherited a creation token")
        self.preserving_attachment(fixture, "Creation bind identity is missing")


    def cleanup(self):
        result = self.ownership.cleanup(apply=True)
        errors = list(result["failed"])
        for message in result["removed"] + result["retained"]:
            print(f"[starter-lifecycle:cleanup] {message}")
        features = result.get("feature_volumes", set())
        expected_retention = ["shared build cache (no dedicated builder)"] + [
            "feature state volume " + name for name in sorted(features)]
        if not result["failed"] and self.ownership.data.get("variant") == "consumer":
            if (len(features) != 2 or set(self.ownership.data.get("feature_volumes", {})) != features
                    or result["retained"] != expected_retention):
                errors.append("consumer cleanup retained unexpected resources or lacks two verified feature volumes")
        elif not result["failed"] and (result["retained"] != expected_retention or features):
            errors.append("base cleanup retained unexpected resources; inspect the recovery preview")
        try:
            if snapshot(self.root) != self.before or run("git", "status", "--porcelain=v1", "--untracked-files=all", cwd=self.root) != self.source_status:
                errors.append("primary branch, HEAD, index, public files, modes, links, or status changed")
                self.ownership.finish("failed")
        except (OSError, ValueError, Unsafe, subprocess.CalledProcessError):
            errors.append("could not verify primary preservation")
        return errors

    def retain(self):
        self.ownership.retain()


class ConsumerLifecycle(Lifecycle):
    """Exercise the filtered release without reducing its published Features."""

    def assert_nested_docker(self, container):
        mounts = json.loads(self.docker("inspect", "--format", "{{json .Mounts}}", container))
        forbidden = {"/var/run/docker.sock", "/run/docker.sock", "/var/run", "/run"}
        if any(m["Type"] == "bind" and (
                m["Source"] in forbidden or m["Destination"] in forbidden) for m in mounts):
            raise RuntimeError("Consumer container binds the host Docker socket")
        host_id = self.ownership.data["daemon"]
        nested = ("exec", "--user", "ubuntu", container, "docker", "-H", "unix:///var/run/docker.sock")
        nested_id = self.docker(*nested, "info", "--format", "{{.ID}}")
        if not nested_id or nested_id == host_id:
            raise RuntimeError("Nested Docker daemon is unavailable or matches the host daemon")
        self.docker(*nested, "run", "--rm", "hello-world")

    def execute(self):
        self.ownership.arm()
        self.ownership.probe_bind()
        source = self.scratch / "fixture-source"
        self.ownership.produce(["bash", str(HERE / "create-candidate.sh"), str(self.root), str(source)],
                               self.root, self.env, "prepare")
        for path in source.rglob("*"):
            if ".git" not in path.relative_to(source).parts and path.is_symlink() and not path.resolve().is_relative_to(source):
                raise ValueError("Fixture source contains an escaping symlink")
        # The release builders accept committed objects only. Stage the fixture
        # overlay in its independent Git repository, never in the primary source.
        fixture_env = {**self.env, "GIT_AUTHOR_NAME": "Fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
                       "GIT_COMMITTER_NAME": "Fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid"}
        self.ownership.produce(["git", "add", "-A"], source, fixture_env, "prepare")
        self.ownership.produce(["git", "commit", "--allow-empty", "-m", "Fixture source"], source, fixture_env, "prepare")
        self.ownership.produce(["git", "branch", "fixture-source", "HEAD"], source, fixture_env, "prepare")
        fixture_head = run("git", "rev-parse", "HEAD", cwd=source, env=self.env)
        self.ownership.produce(["python3", ".maintainer/scripts/starter-candidate.py",
                                "--source", "fixture-source", "--base-absent"], source, fixture_env, "prepare")
        rc = run("git", "rev-parse", "refs/heads/starter-rc", cwd=source, env=self.env)
        tree = run("git", "rev-parse", f"{rc}^{{tree}}", cwd=source, env=self.env)
        self.ownership.produce(["python3", ".maintainer/scripts/starter-promote.py",
                                "--approved-rc", rc, "--expected-tree", tree,
                                "--expected-base", "absent", "--expected-source", fixture_head],
                               source, fixture_env, "prepare")
        release = run("git", "rev-parse", "refs/heads/starter", cwd=source, env=self.env)
        # No checkout or Docker build is allowed until the clone loses its origin.
        self.ownership.produce(["git", "clone", "--quiet", "--no-local", "--no-hardlinks",
                                "--no-checkout", "--branch", "starter", str(source), str(self.candidate)],
                               self.scratch, self.env, "prepare")
        self.ownership.produce(["git", "remote", "remove", "origin"], self.candidate, self.env, "prepare")
        self.ownership.produce(["git", "reset", "--hard", "HEAD"], self.candidate, self.env, "prepare")
        if run("git", "rev-parse", "HEAD", cwd=self.candidate, env=self.env) != release or run(
                "git", "rev-parse", "HEAD^{tree}", cwd=self.candidate, env=self.env) != tree:
            raise RuntimeError("Consumer clone does not match fixture release")
        if run("git", "remote", cwd=self.candidate, env=self.env):
            raise RuntimeError("Consumer clone retained a remote")
        for path in self.candidate.rglob("*"):
            if ".git" not in path.relative_to(self.candidate).parts and path.is_symlink() and not path.resolve().is_relative_to(self.candidate):
                raise ValueError("Consumer clone contains an escaping symlink")
        config = (self.candidate / ".devcontainer/devcontainer.json").read_text()
        if '"ghcr.io/devcontainers/features/docker-in-docker:4"' not in config or '"--privileged"' not in config:
            raise ValueError("Published consumer lacks DinD feature or privileged runArgs")
        for name in (".env", ".devcontainer/.env"):
            path = self.candidate / name
            path.write_text("LOCALE=en_GB.UTF-8\nTZ=Europe/Madrid\n" if name == ".env" else "")
            path.chmod(0o600)
        port = run("bash", ".taskfiles/scripts/project-identity.sh", "-o", "code", cwd=self.candidate, env=self.env)
        self.env.update(APP_NAME=self.candidate.name, APP_PORT=port, OPENCODE_PORT=str(int(port) + 1))
        self.validate_base()
        self.label_candidate()
        configured = expected_after_setup(self.candidate, snapshot(self.candidate))
        self.task("build")
        self.task("up")
        container = self.container()
        self.ownership.stage("verify")
        self.assert_nested_docker(container)
        if snapshot(self.candidate) != configured:
            raise RuntimeError("Consumer clone public files changed during startup")

def main():
    consumer = "--consumer" in sys.argv[1:]
    attachment = "--attachment" in sys.argv[1:]
    generated_read = "--allow-generated-dockerfile-read" in sys.argv[1:]
    if consumer and attachment:
        raise SystemExit("Select consumer or attachment, not both")
    if generated_read and (consumer or not attachment):
        raise SystemExit("Generated Dockerfile read requires --attachment and forbids --consumer")
    selectors = {"--consumer", "--attachment", "--allow-generated-dockerfile-read"}
    if any(sys.argv[1:].count(flag) > 1 for flag in selectors):
        raise SystemExit("Duplicate lifecycle selector")
    args = [arg for arg in sys.argv[1:] if arg not in selectors]
    if not args:
        parent = Path("/home/ubuntu")
    elif len(args) == 2 and args[0] == "--daemon-visible-scratch":
        parent = Path(args[1])
    else:
        raise SystemExit("Usage: task test:starter:lifecycle [-- --consumer | --attachment] [--daemon-visible-scratch ABSOLUTE_PARENT]\n"
                         "Explicit expensive build/start/recreate; the local Docker daemon must pass an exact-byte bind probe first.")
    root = Path(run("git", "rev-parse", "--show-toplevel")).resolve()
    if Path.cwd() != root or not parent.is_absolute() or not parent.is_dir() or parent.resolve() != parent or parent == root or parent.is_relative_to(root):
        raise SystemExit("Run from repository root with an existing plain scratch parent outside the repository")
    commands = ("docker", "devcontainer", "task", "git", "rsync", "yq") + (("timeout",) if attachment else ())
    for command in commands:
        if not shutil.which(command):
            raise SystemExit(f"Required command unavailable: {command}")
    print("[starter-lifecycle] Explicit " + ("consumer release/DinD" if consumer else
          "base lifecycle + Task attachment" if attachment else "base lifecycle") + " scenario. "
          "Expect downloads, minutes of CPU/build time and substantial disk use; startup may build. "
           "Shared build cache is retained; owned images are removed only when exclusive ownership is verified. "
           "Local daemon only; no initialization or optional socket proof.", flush=True)
    ownership = Run.create(root, parent, variant="consumer") if consumer else Run.create(root, parent)
    scratch = Path(ownership.data["scratch"])
    print(f"[starter-lifecycle] Recovery run: {ownership.data['run']}; inventory: {ownership.path}", flush=True)
    try:
        lifecycle = (ConsumerLifecycle if consumer else Lifecycle)(root, scratch, ownership)
        if attachment:
            lifecycle.attachment_scenario = True
        lifecycle.allow_generated_dockerfile_read = generated_read
    except BaseException:
        try:
            try:
                ownership.finish("failed")
                ownership.retain()
            except (OSError, Unsafe):
                print("[starter-lifecycle:error] Constructor failed; retained scope could not be verified", file=sys.stderr)
        finally:
            ownership.close()
        raise
    original_env = dict(os.environ)
    os.environ.clear()
    os.environ.update(lifecycle.env)
    failure = None
    was_interrupted = False
    def interrupted(signum, _frame):
        nonlocal was_interrupted
        was_interrupted = True
        raise RuntimeError(f"Interrupted by signal {signum}")
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        lifecycle.execute()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError, KeyboardInterrupt):
        failure = failure_message(lifecycle)
        was_interrupted |= isinstance(sys.exc_info()[1], KeyboardInterrupt)
    finally:
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        try:
            cleanup_failed = True
            errors = []
            try:
                if failure or was_interrupted:
                    try:
                        lifecycle.retain()
                    except (OSError, Unsafe):
                        errors.append("could not verify or stop retained owned resources; inspect recovery inventory")
                    try:
                        if snapshot(root) != lifecycle.before or run("git", "status", "--porcelain=v1", "--untracked-files=all", cwd=root) != lifecycle.source_status:
                            errors.append("primary branch, HEAD, index, public files, modes, links, or status changed")
                    except (OSError, ValueError, Unsafe, subprocess.CalledProcessError):
                        errors.append("could not verify primary preservation")
                else:
                    errors = lifecycle.cleanup()
                cleanup_failed = False
            finally:
                try:
                    ownership.finish("interrupted" if was_interrupted else "failed" if cleanup_failed or failure or errors else "passed")
                except (OSError, Unsafe):
                    if not cleanup_failed:
                        errors.append("could not persist test outcome")
        finally:
            ownership.close()
            os.environ.clear()
            os.environ.update(original_env)
    if failure:
        print(f"[starter-lifecycle:error] {failure}", file=sys.stderr)
    for error in errors:
        print(f"[starter-lifecycle:cleanup] {error}", file=sys.stderr)
    if failure or errors:
        return 1
    print(("Fixture release clone/build/start and nested Docker verified. Exactly two verified feature state volumes retained; "
           "this is not complete resource cleanup. " if consumer else
            "Base build/start/direct-exec/recreate, managed persistence verified. ") + "Primary preservation verified. "
          "Registered owned resources removed; shared build cache and compact run diagnostics retained.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
