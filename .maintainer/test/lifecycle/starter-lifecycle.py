#!/usr/bin/env python3
"""Explicit, expensive base lifecycle proof. Importing this module is inert."""

import hashlib
import importlib.util
import inspect
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import stat
import subprocess
import sys


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from test_resources import ENDPOINT, LABEL, Run, Unsafe, registry_directory

VERIFY_CHECKS = frozenset({"container-replaced", "managed-state", "candidate-unchanged", "locale-timezone", "runtime-directories"})
TEST_LOCALE = "en_GB.UTF-8"
TEST_TIMEZONE = "Europe/Madrid"
AUTHORITY = ".git/gentle-ai/review-mode/rar-authority"
SSH_SOURCE = ".env.d/.ssh-server"
SSH_TARGET = "/home/ubuntu/.ssh-server"
PORT_RESET = "services:\n  container-svc:\n    ports: !reset []\n"


def failure_message(lifecycle):
    check = getattr(lifecycle, "verify_check", None)
    check = check if isinstance(check, str) and check in VERIFY_CHECKS else None
    detail = f"; verify check: {check}" if check in VERIFY_CHECKS else ""
    if check == "candidate-unchanged" and hasattr(lifecycle, "snapshot_diagnostic"):
        detail += "; snapshot difference: " + ", ".join(
            f"{key}={value}" for key, value in lifecycle.snapshot_diagnostic.items()
            if key in {"added", "removed", "mode", "kind", "hash-or-link", "identity"}
            and type(value) is int and 0 <= value <= 1000000)
    owner = getattr(lifecycle, "ownership", None)
    data = getattr(owner, "data", {})
    stage = getattr(lifecycle, "diagnostic_stage", None)
    if not isinstance(stage, str):
        stage = data.get("stage") if isinstance(data, dict) else None
    return lifecycle_diagnostic(owner, stage, check if check in VERIFY_CHECKS else "unknown") + detail


def lifecycle_diagnostic(owner, stage, reason="unknown"):
    """Reuse preflight's fixed code vocabulary; inventory paths are never echoed."""
    stages = {"registration", "registered", "environment", "binding", "prepare", "probe",
              "build", "up", "restart", "recreate", "verify", "cleanup"}
    reasons = VERIFY_CHECKS | {"unknown", "interrupted", "retention-unverified", "cleanup-unverified",
                              "outcome-unpersisted", "primary-changed", "primary-unverified", "lease-unclosed"}
    stage = stage if isinstance(stage, str) and stage in stages else "unknown"
    reason = reason if isinstance(reason, str) and reason in reasons else "unknown"
    data = getattr(owner, "data", {})
    run = data.get("run") if isinstance(data, dict) else None
    token = run if isinstance(run, str) and re.fullmatch(
        r"[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}", run) else "none"
    evidence = "run-inventory:" + token if token != "none" else "none"
    next_step = "preview-selected-run" if stage == "cleanup" else "inspect-private-evidence"
    return f"run={token} stage={stage} reason={reason} next_step={next_step} evidence={evidence}"


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
    ignored_entries = {path.rstrip("/") for path in ignored if path}
    tracked = {}
    for entry in configured["index"].split("\0"):
        if entry:
            mode, _, path = entry.partition("\t")
            tracked[path] = mode.split(" ", 1)[0]
    files = {}
    for name, value in configured["files"].items():
        if value is None or value[1] != "file" or name in ignored_entries or name.startswith(ignored_dirs):
            files[name] = value
            continue
        mode = {"100644": 0o644, "100755": 0o755}.get(tracked.get(name, ""))
        files[name] = [mode if mode is not None else (0o755 if Path(name).name.endswith(".sh") else 0o644), *value[1:]]
    return {**configured, "files": files}


def configure(root, runtime_directories=False):
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
    if runtime_directories:
        installer = root / ".devcontainer/install/available/4010-tool-ssh-server.sh"
        if not installer.is_file() or installer.is_symlink():
            raise Unsafe("Runtime fixture requires the canonical SSH installer")
        (root / ".devcontainer/install/03-enabled" / installer.name).symlink_to("../available/" + installer.name)
        config["dockerComposeFile"] += ["./config/compose/docker-compose.ssh-server.yml",
                                       "./config/compose/starter-runtime-no-ports.yml"]
        (root / ".devcontainer/config/compose/starter-runtime-no-ports.yml").write_text(PORT_RESET)
        (root / ".devcontainer/devcontainer.json").write_text(json.dumps(config, indent=4) + "\n")


def tree_state(base):
    """Read only run-owned synthetic trees; reject links, special files and unsafe owners."""
    base = Path(base)
    if base.resolve() != base.absolute():
        raise Unsafe("Synthetic tree has a symlinked parent")
    result = {}
    pending = [base]
    while pending:
        path = pending.pop()
        metadata = path.lstat()
        mode = stat.S_IMODE(metadata.st_mode)
        if stat.S_ISLNK(metadata.st_mode):
            raise Unsafe("Synthetic tree contains a symlink")
        if metadata.st_uid != os.getuid() or mode & 0o7022:
            raise Unsafe("Synthetic tree has unsafe ownership or modes")
        if stat.S_ISDIR(metadata.st_mode):
            content = "directory"
            pending.extend(path.iterdir())
        elif stat.S_ISREG(metadata.st_mode) and metadata.st_nlink == 1:
            descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
            with os.fdopen(descriptor, "rb") as stream:
                opened = os.fstat(stream.fileno())
                if (opened.st_dev, opened.st_ino) != (metadata.st_dev, metadata.st_ino):
                    raise Unsafe("Synthetic file replaced during inspection")
                content = hashlib.sha256(stream.read()).hexdigest()
        else:
            raise Unsafe("Synthetic tree contains a symlink or unsupported file")
        result[str(path.relative_to(base))] = [metadata.st_uid, metadata.st_gid, mode, content]
    return result


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
        self.diagnostic_stage = "binding"
        adapter = getattr(self, "_generated_read_adapter", None)
        if adapter is None:
            raise Unsafe("Private plugin selection has not been prepared")
        adapter.validate_selection(self.env)

    def task(self, action):
        self.verify_check = None
        self.validate_private_selection()
        self.diagnostic_stage = action
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
        self.diagnostic_stage = "registration"
        self.ownership.arm()
        self.diagnostic_stage = "probe"
        self.ownership.probe_bind()
        self.diagnostic_stage = "prepare"
        self.ownership.stage("prepare")
        self.ownership.produce(["bash", str(HERE / "create-candidate.sh"), str(self.root), str(self.candidate)],
                               self.root, self.env, "prepare")
        runtime_directories = isinstance(self, RuntimeDirectoriesLifecycle)
        if runtime_directories:
            configure(self.candidate, runtime_directories=True)
        else:
            configure(self.candidate)
        for path in self.candidate.rglob("*"):
            if ".git" not in path.relative_to(self.candidate).parts and path.is_symlink() and not path.resolve().is_relative_to(self.candidate):
                raise ValueError("Candidate has an escaping symlink; replace it with a repository-local input before lifecycle execution")
        port = run("bash", ".taskfiles/scripts/project-identity.sh", "-o", "code", cwd=self.candidate, env=self.env)
        self.env.update(APP_NAME=self.candidate.name, APP_PORT=port, OPENCODE_PORT=str(int(port) + 1))
        if runtime_directories:
            self.env["SSH_PORT"] = "22"
        self.validate_base()
        self.label_candidate()
        if runtime_directories:
            self.prepare_runtime_directories()
        configured = expected_after_setup(self.candidate, snapshot(self.candidate))
        if getattr(self, "allow_generated_dockerfile_read", False):
            spec = importlib.util.spec_from_file_location("generated_read", HERE / "generated-dockerfile-read.py")
            assert spec and spec.loader
            adapter = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(adapter)
            if runtime_directories:
                adapter.prepare(self, runtime_directories=True)
            else:
                adapter.prepare(self)
            self._generated_read_adapter = adapter
        self.task("build")
        if runtime_directories:
            self.assert_runtime_seed()
        self.task("up")
        first = self.container()
        self.diagnostic_stage = "verify"
        if runtime_directories:
            self.verify_check = "runtime-directories"
            self.assert_runtime_directories(first, first=True)
        self.assert_state(first, write=True)
        self.verify_check = "locale-timezone"
        self.assert_locale(first)
        self.task("recreate")
        second = self.container()
        self.ownership.stage("verify")
        self.diagnostic_stage = "verify"
        self.verify_check = "container-replaced"
        if first == second:
            raise RuntimeError("Recreate did not replace the service container")
        self.verify_check = "managed-state"
        if runtime_directories:
            self.verify_check = "runtime-directories"
            self.assert_runtime_directories(second)
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
        # Shared-engine transport can contain paths or provider exceptions. Keep
        # only bounded counts public; private inventory is the recovery evidence.
        print("[starter-lifecycle:cleanup] " + lifecycle_diagnostic(self.ownership, "cleanup") +
              f" removed_count={len(result['removed'])} retained_count={len(result['retained'])}")
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
                errors.append("primary-changed")
                self.ownership.finish("failed")
        except (OSError, ValueError, Unsafe, subprocess.CalledProcessError):
            errors.append("primary-unverified")
        return errors

    def retain(self):
        self.ownership.retain()


class RuntimeDirectoriesLifecycle(Lifecycle):
    """Opt-in synthetic policy proof, never a native review receipt or SSH login."""

    def validate_base(self):
        module = resolver(self.candidate)
        _, paths, _ = module.selection(self.candidate)
        expected = ["docker-compose.yml", "config/compose/docker-compose-core-tools.yml",
                    "config/compose/docker-compose.ssh-server.yml", "config/compose/starter-runtime-no-ports.yml"]
        if paths != [self.candidate / ".devcontainer" / name for name in expected]:
            raise Unsafe("Runtime fixture requires the exact isolated Compose selection")
        ssh = module.read_compose_fragment(paths[2])
        if ssh != {"services": {"container-svc": {"ports": ["${SSH_PORT}:22"], "volumes": [
                {"type": "bind", "source": "../" + SSH_SOURCE, "target": SSH_TARGET,
                 "bind": {"create_host_path": False}}]}}} or paths[3].read_text() != PORT_RESET:
            raise Unsafe("Runtime fixture SSH override or port reset differs from the reviewed contract")
        manifest = super().validate_base()
        _, _, selected = self.resolve()
        if selected.get("ports"):
            raise Unsafe("Runtime fixture resolved ports must be empty; Compose !reset support is required")
        records = [v for v in manifest["volumes"] if v["source"] == SSH_SOURCE]
        if len(records) != 1 or records[0]["target"] != SSH_TARGET:
            raise Unsafe("Runtime fixture requires exact managed SSH mapping")
        return manifest

    def seed_runtime_directories(self):
        """Only after create-candidate: its independent .git never contains real authority."""
        if self.candidate == self.root or not self.candidate.is_relative_to(self.scratch):
            raise Unsafe("Runtime fixture must be isolated from the source")
        for name in (".git", ".env.d"):
            path = self.candidate / name
            metadata = path.lstat()
            if (path.resolve() != path.absolute() or not stat.S_ISDIR(metadata.st_mode)
                    or metadata.st_uid != os.getuid() or stat.S_IMODE(metadata.st_mode) & 0o7022):
                raise Unsafe("Runtime fixture parent has unsafe ownership, mode or type")
        for name in (".git/gentle-ai", SSH_SOURCE):
            if os.path.lexists(self.candidate / name):
                raise Unsafe("Synthetic runtime fixture already exists")
        for name in (".git/gentle-ai", ".git/gentle-ai/review-mode", AUTHORITY, SSH_SOURCE):
            path = self.candidate / name
            path.mkdir(mode=0o755)
            path.chmod(0o755)
        self.runtime_parents = {}
        for name in (".git", ".git/gentle-ai", ".git/gentle-ai/review-mode"):
            metadata = (self.candidate / name).lstat()
            self.runtime_parents[name] = [metadata.st_uid, metadata.st_gid, stat.S_IMODE(metadata.st_mode)]
        self.runtime_before = {}
        for name in (AUTHORITY, SSH_SOURCE):
            base = self.candidate / name
            child = base / "preserved"
            child.mkdir(mode=0o750)
            child.chmod(0o750)
            sentinel = child / "sentinel"
            sentinel.write_bytes(b"Synthetic lifecycle sentinel; not authority or credentials.\n")
            sentinel.chmod(0o640)
            self.runtime_before[name] = tree_state(base)
        if os.path.lexists(self.candidate / SSH_SOURCE / "ssh"):
            raise Unsafe("SSH policy child must be absent before up")

    def prepare_runtime_directories(self):
        self.seed_runtime_directories()

    def assert_runtime_seed(self):
        for name, expected in self.runtime_before.items():
            if tree_state(self.candidate / name) != expected:
                raise Unsafe("Synthetic initial runtime state changed before up")

    def assert_preserved_trees(self):
        for name, expected in self.runtime_parents.items():
            path = self.candidate / name
            metadata = path.lstat()
            if (path.resolve() != path.absolute() or not stat.S_ISDIR(metadata.st_mode)
                    or [metadata.st_uid, metadata.st_gid, stat.S_IMODE(metadata.st_mode)] != expected):
                raise Unsafe("Synthetic authority parent metadata was not preserved")
        for name, before in self.runtime_before.items():
            after = tree_state(self.candidate / name)
            expected = {key: list(value) for key, value in before.items()}
            expected["."][2] = 0o700
            if name == SSH_SOURCE:
                marker = "." + self.candidate.name + "-marker"
                after = {key: value for key, value in after.items()
                         if key != "ssh" and not key.startswith("ssh/") and key != marker}
            if after != expected:
                raise Unsafe("Synthetic runtime contents, descendants or ownership were not preserved")

    def container_tree(self, container, base):
        script = ("import hashlib, json, os, stat, sys\nfrom pathlib import Path\n"
                  "Unsafe = RuntimeError\n" + inspect.getsource(tree_state) +
                  "\nprint(json.dumps(tree_state(Path(sys.argv[1])), sort_keys=True))\n")
        return json.loads(self.docker("exec", "--user", "ubuntu", container, "python3", "-c", script, str(base)))

    def assert_runtime_directories(self, container, first=False):
        ports = json.loads(self.docker("inspect", "--format", "{{json .NetworkSettings.Ports}}", container))
        if not isinstance(ports, dict) or any(value for value in ports.values()):
            raise Unsafe("Runtime fixture actual published ports must be empty")
        mounts = json.loads(self.docker("inspect", "--format", "{{json .Mounts}}", container))
        workspace = "/home/ubuntu/" + self.candidate.name
        for source, target in ((self.candidate, workspace), (self.candidate / SSH_SOURCE, SSH_TARGET)):
            matches = [m for m in mounts if m["Destination"] == target]
            if len(matches) != 1 or not (matches[0]["Type"] == "bind" and matches[0]["Source"] == str(source) and matches[0]["RW"]):
                raise Unsafe("Runtime fixture actual workspace or SSH bind mapping differs")
        manifest = resolver(self.candidate).load_manifest(self.candidate)
        records = [v for v in manifest["volumes"] if v["source"] == SSH_SOURCE]
        if (len(records) != 1 or records[0]["target"] != SSH_TARGET
                or not records[0]["managed"] or records[0]["read_only"]):
            raise Unsafe("Applied runtime SSH mapping differs")
        identity = self.docker("exec", "--user", "ubuntu", container, "printenv", "DEVCONTAINER_BIND_MANIFEST_ID")
        if identity != manifest["id"]:
            raise Unsafe("Runtime container does not have the applied manifest identity")
        self.assert_preserved_trees()
        for name, expected in self.runtime_parents.items():
            value = self.docker("exec", "--user", "ubuntu", container, "stat", "-c", "%u:%g:%a", workspace + "/" + name)
            if value != f"{expected[0]}:{expected[1]}:{expected[2]:o}":
                raise Unsafe("Synthetic authority host/container parent metadata differs")
        for name, target in ((AUTHORITY, workspace + "/" + AUTHORITY), (SSH_SOURCE, SSH_TARGET)):
            if tree_state(self.candidate / name) != self.container_tree(container, target):
                raise Unsafe("Runtime fixture host/container metadata or content differs")
        keys = tree_state(self.candidate / SSH_SOURCE / "ssh")
        uid, gid = self.runtime_before[SSH_SOURCE]["."][:2]
        expected_names = {".", "ssh_host_rsa_key", "ssh_host_rsa_key.pub", "ssh_host_ed25519_key", "ssh_host_ed25519_key.pub"}
        if set(keys) != expected_names or keys["."] != [uid, gid, 0o700, "directory"]:
            raise Unsafe("SSH policy child or generated key set differs")
        for name in expected_names - {"."}:
            if keys[name][:3] != [uid, gid, 0o644 if name.endswith(".pub") else 0o600]:
                raise Unsafe("Generated SSH key ownership or mode differs")
        if first:
            self.runtime_keys = keys
        elif keys != self.runtime_keys:
            raise Unsafe("Generated SSH host keys changed across recreation")


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
        self.diagnostic_stage = "registration"
        self.ownership.arm()
        self.diagnostic_stage = "probe"
        self.ownership.probe_bind()
        self.diagnostic_stage = "prepare"
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
        self.diagnostic_stage = "verify"
        self.assert_nested_docker(container)
        if snapshot(self.candidate) != configured:
            raise RuntimeError("Consumer clone public files changed during startup")


def parse_options(argv):
    """One selector contract for inspection and execution; no I/O."""
    consumer = "--consumer" in argv
    attachment = "--attachment" in argv
    generated_read = "--allow-generated-dockerfile-read" in argv
    runtime_directories = "--runtime-directories" in argv
    if runtime_directories and (consumer or attachment):
        raise SystemExit("Runtime directories forbids consumer and attachment")
    if consumer and attachment:
        raise SystemExit("Select consumer or attachment, not both")
    if generated_read and (consumer or not (attachment or runtime_directories)):
        raise SystemExit("Generated Dockerfile read requires --attachment or --runtime-directories and forbids --consumer")
    selectors = {"--consumer", "--attachment", "--allow-generated-dockerfile-read", "--runtime-directories", "--preflight"}
    if any(argv.count(flag) > 1 for flag in selectors):
        raise SystemExit("Duplicate lifecycle selector")
    args = [arg for arg in argv if arg not in selectors]
    if not args:
        parent = Path("/home/ubuntu")
    elif len(args) == 2 and args[0] == "--daemon-visible-scratch":
        parent = Path(args[1])
    else:
        raise SystemExit("Usage: task test:starter:lifecycle [-- --preflight] [--consumer | --attachment | --runtime-directories] [--daemon-visible-scratch ABSOLUTE_PARENT]\n"
                         "[--allow-generated-dockerfile-read only with --attachment or --runtime-directories]\n"
                         "Explicit expensive build/start/recreate; the local Docker daemon must pass an exact-byte bind probe first.")
    return {"consumer": consumer, "attachment": attachment, "generated_read": generated_read,
            "runtime_directories": runtime_directories, "preflight": "--preflight" in argv,
            "parent": parent, "scenario": "consumer" if consumer else "runtime-directories" if runtime_directories
            else "attachment" if attachment else "base"}


PREFLIGHT_LIMIT = 262144
PREFLIGHT_TIMEOUT = 10
# A nonexistent Linux fd name prevents config/session discovery without creating HOME.
PREFLIGHT_HOME = "/proc/self/fd/-1"
PREFLIGHT_STEPS = {
    "options": ("invalid-options", "select-supported-options"),
    "tools": ("tools-unavailable", "install-required-tools"),
    "source": ("source-unavailable", "use-repository-root"),
    "scratch": ("scratch-unsafe", "select-writable-scratch-parent"),
    "registry": ("registry-unsafe", "inspect-registry-safety"),
    "scope": ("scope-unsupported", "review-selected-build-inputs"),
    "endpoint": ("local-endpoint-unavailable", "provide-authorized-local-daemon"),
    "daemon": ("daemon-metadata-unavailable", "inspect-local-daemon"),
    "image": ("cached-image-unavailable", "prepare-cached-probe-image"),
    "toolchain": ("toolchain-unsupported", "use-reviewed-toolchain"),
}


def preflight_report(scenario="invalid"):
    return {"schema": 1, "scenario": scenario, "readiness": "not-ready", "checks": [],
            "stage": "options", "reason": "invalid-options", "next_step": "select-supported-options", "run": None}


def preflight_environment():
    return {"PATH": os.environ.get("PATH", ""), "HOME": PREFLIGHT_HOME, "LANG": "C.UTF-8",
            "DOCKER_CONFIG": PREFLIGHT_HOME, "DOCKER_HOST": ENDPOINT,
            "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_OPTIONAL_LOCKS": "0",
            "PYTHONDONTWRITEBYTECODE": "1"}


def metadata_query(*args, cwd=None, payload=None):
    """Read-only callers only; timeout and output never escape as public exceptions."""
    result = subprocess.run(args, cwd=cwd, env=preflight_environment(), input=payload,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            timeout=PREFLIGHT_TIMEOUT, check=False)
    if result.returncode or len(result.stdout) > PREFLIGHT_LIMIT:
        raise Unsafe("metadata query refused")
    return result.stdout.strip()


def public_input(root, name):
    path = root / name
    metadata = path.lstat()
    if (not public_path(name) or path.resolve() != path or not stat.S_ISREG(metadata.st_mode)
            or metadata.st_size > PREFLIGHT_LIMIT):
        raise Unsafe("unsupported public input")
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, "rb") as stream:
        opened = os.fstat(stream.fileno())
        if (not stat.S_ISREG(opened.st_mode)
                or (opened.st_dev, opened.st_ino) != (metadata.st_dev, metadata.st_ino)):
            raise Unsafe("public input replaced")
        payload = stream.read(PREFLIGHT_LIMIT + 1)
        final = os.fstat(stream.fileno())
        if (len(payload) > PREFLIGHT_LIMIT or (final.st_size, final.st_mtime_ns, final.st_ctime_ns)
                != (opened.st_size, opened.st_mtime_ns, opened.st_ctime_ns)):
            raise Unsafe("public input changed or exceeds bound")
    return payload.decode()


def local_endpoint():
    return stat.S_ISSOCK(Path(ENDPOINT.removeprefix("unix://")).lstat().st_mode)


def scope_preflight(root, options):
    """Inspect the future reduced selection, never resolve environment or create it."""
    config = public_input(root, ".devcontainer/devcontainer.json")
    config = re.sub(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/',
                    lambda match: match[0] if match[0].startswith('"') else " ", config)
    config = re.sub(r'("(?:\\.|[^"\\])*")|,\s*(?=[}\]])', lambda match: match[1] or "", config)
    config = json.loads(config)
    files = config.get("dockerComposeFile")
    files = [files] if isinstance(files, str) else files
    if (config.get("service") != "container-svc" or not isinstance(files, list) or not files
            or files[0] not in {"docker-compose.yml", "./docker-compose.yml"}):
        raise Unsafe("unsupported base selection")
    helper = root / ".taskfiles/scripts/yq-compatibility.sh"
    public_input(root, str(helper.relative_to(root)))

    def fragment(name):
        payload = public_input(root, ".devcontainer/" + name)
        return json.loads(metadata_query("bash", "-c", 'source "$1"; yq_compatibility_json . /dev/stdin',
                                        "preflight-input", str(helper), payload=payload))

    base = fragment("docker-compose.yml")
    core = fragment("config/compose/docker-compose-core-tools.yml")
    if (set(base) != {"services"} or set(base["services"]) != {"container-svc"}
            or set(core) != {"services"} or set(core["services"]) != {"container-svc"}
            or set(core["services"]["container-svc"]) - {"volumes", "ports"}):
        raise Unsafe("unsupported base resources")
    selections = [base["services"]["container-svc"], core["services"]["container-svc"]]
    consumer_tools = None
    if options["consumer"]:
        # The current publisher normalizes these exact overrides and tool aliases;
        # it preserves Features, hooks, Dockerfile and attachment configuration.
        if (config.get("features") != {"ghcr.io/devcontainers/features/docker-in-docker:4": {},
                                      "ghcr.io/devcontainers/features/github-cli:1": {}}
                or config.get("runArgs") != ["--privileged"]
                or config.get("postCreateCommand") != "bash ${containerWorkspaceFolder}/.devcontainer/setup.sh"
                or config.get("mounts") != ["source=${localWorkspaceFolder},target=/home/ubuntu/${localEnv:APP_NAME},type=bind"]):
            raise Unsafe("unsupported consumer configuration")
        for name in ("config/compose/docker-compose.pi.yml", "config/compose/docker-compose.gentle-shell.yml"):
            override = fragment(name)
            if (set(override) != {"services"} or set(override["services"]) != {"container-svc"}
                    or set(override["services"]["container-svc"]) != {"volumes"}):
                raise Unsafe("unsupported consumer override")
            selections.append(override["services"]["container-svc"])
        consumer_tools = json.loads(public_input(root, ".maintainer/starter-tools.json"))
        if (not isinstance(consumer_tools, list) or len(consumer_tools) > 256
                or not all(isinstance(name, str) and re.fullmatch(r"[0-9]{4}-[a-z0-9-]+\.sh", name) for name in consumer_tools)
                or len(consumer_tools) != len(set(consumer_tools))):
            raise Unsafe("unsupported consumer tool selection")
    service = base["services"]["container-svc"]
    build = service.get("build", {})
    if (service.get("env_file") != ["../.env"]
            or set(service) & {"extends", "secrets", "configs", "devices", "volumes_from", "network_mode", "depends_on"}
            or build.get("context") != "." or build.get("dockerfile", "Dockerfile") not in {"Dockerfile", "./Dockerfile"}
            or set(build) - {"context", "dockerfile", "args", "target"}
            or service.get("container_name") != "${APP_NAME}-run" or service.get("image") != "${APP_NAME}-img:0.1"):
        raise Unsafe("unsupported base build")
    volumes = []
    for selected in selections:
        for volume in selected.get("volumes", []):
            if (not isinstance(volume, dict) or volume.get("type") != "bind"
                    or not isinstance(volume.get("source"), str) or not volume["source"].startswith("../.env.d/")
                    or volume["source"] != "../" + Path(volume["source"][3:]).as_posix()
                    or ".." in Path(volume["source"]).parts[1:] or volume.get("read_only", False) is not False
                    or volume.get("bind") != {"create_host_path": False}):
                raise Unsafe("unsupported base bind")
            volumes.append({**volume, "source": str(root / volume["source"][3:])})
    # Pure projection shares canonical-path, duplicate-target and bind-option gates;
    # it does not run Compose, read interpolation files or inspect the real .env.d.
    public_input(root, ".taskfiles/scripts/compose-manifest.py")
    module = resolver(root)
    paths = [root / ".devcontainer/docker-compose.yml",
             root / ".devcontainer/config/compose/docker-compose-core-tools.yml"]
    module.project_manifest(root, "container-svc", paths, {"volumes": volumes}, "starter-preflight")
    public_input(root, ".devcontainer/Dockerfile")
    counts = {}
    for group in ("01-foundation", "02-core-tools", "03-enabled", "04-hooks"):
        directory = root / ".devcontainer/install" / group
        if directory.resolve() != directory or not directory.is_dir():
            raise Unsafe("unsupported installer group")
        scripts = ([root / ".devcontainer/install/available" / name for name in consumer_tools]
                   if group == "03-enabled" and consumer_tools is not None
                   else [path for path in directory.iterdir() if path.name.endswith(".sh")])
        if len(scripts) > 256:
            raise Unsafe("installer selection exceeds bound")
        count = 0
        for path in scripts:
            if (not options["consumer"] and group == "03-enabled" and path.is_symlink()
                    and path.resolve().name in {"3030-ai-pi-coding.sh", "4010-tool-ssh-server.sh"}):
                continue  # configure removes these before build; runtime adds canonical SSH below.
            target = path.resolve()
            if not target.is_relative_to(root / ".devcontainer/install"):
                raise Unsafe("escaping installer selection")
            public_input(root, str(target.relative_to(root)))
            count += 1
        counts[group] = count
    if options["runtime_directories"]:
        public_input(root, ".devcontainer/install/available/4010-tool-ssh-server.sh")
        ssh = fragment("config/compose/docker-compose.ssh-server.yml")
        if ssh != {"services": {"container-svc": {"ports": ["${SSH_PORT}:22"], "volumes": [
                {"type": "bind", "source": "../" + SSH_SOURCE, "target": SSH_TARGET,
                 "bind": {"create_host_path": False}}]}}}:
            raise Unsafe("unsupported runtime selection")
        counts["03-enabled"] += 1
    return counts


def preflight(options):
    """Fail before registration; readiness is metadata, not daemon-visible byte proof."""
    report = preflight_report(options["scenario"])

    def check(stage, operation, reason="checked"):
        report.update(stage=stage, reason=PREFLIGHT_STEPS[stage][0], next_step=PREFLIGHT_STEPS[stage][1])
        value = operation()
        item = {"stage": stage, "reason": reason}
        if isinstance(value, dict):
            item["selected_scripts"] = value
        report["checks"].append(item)
        return value

    def require(condition):
        if not condition:
            raise Unsafe("preflight check refused")

    try:
        commands = ("bash", "docker", "devcontainer", "task", "git", "rsync", "yq")
        if options["attachment"]:
            commands += ("timeout",)
        check("tools", lambda: require(all(shutil.which(command) for command in commands)))
        root = Path.cwd()
        check("source", lambda: require(root.resolve() == root and root == Path(
            metadata_query("git", "rev-parse", "--show-toplevel", cwd=root))))
        parent = options["parent"]
        check("scratch", lambda: require(parent.is_absolute() and parent.resolve() == parent
              and parent.is_dir() and parent != root and not parent.is_relative_to(root)
              and os.access(parent, os.W_OK | os.X_OK)))

        def registry():
            common = Path(metadata_query("git", "rev-parse", "--path-format=absolute", "--git-common-dir", cwd=root))
            store = common / "starter-test-runs"
            require(common.is_absolute() and common.resolve() == common and common.is_dir()
                    and store.resolve() == store and not parent.is_relative_to(common))
            if os.path.lexists(store):
                registry_directory(store)
                require(os.access(store, os.W_OK | os.X_OK))
            else:
                registry_directory(common)
                require(os.access(common, os.W_OK | os.X_OK))
            return "registry-safe" if os.path.lexists(store) else "registry-planned-0755"

        registry_reason = check("registry", registry)
        report["checks"][-1]["reason"] = registry_reason
        check("scope", lambda: scope_preflight(root, options), "selected-build-inputs")
        check("endpoint", lambda: require(local_endpoint()))

        def daemon():
            value = metadata_query("docker", "--host", ENDPOINT, "info", "--format", "{{.ID}}")
            require(bool(value) and len(value) <= 128)

        check("daemon", daemon)

        def image():
            value = metadata_query("docker", "--host", ENDPOINT, "image", "inspect",
                                   "--format", "{{.Id}}", "ubuntu:24.04")
            require(re.fullmatch(r"sha256:[0-9a-f]{64}", value) is not None)

        check("image", image)

        def toolchain():
            spec = importlib.util.spec_from_file_location("generated_read_capability", HERE / "generated-dockerfile-read.py")
            assert spec and spec.loader
            adapter = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(adapter)
            compose = metadata_query("docker", "--host", ENDPOINT, "compose", "version", "--short")
            cli = metadata_query("devcontainer", "--version")
            require(compose in adapter.COMPOSE_VERSIONS and cli == adapter.CLI_VERSION)
            require(bool(metadata_query("docker", "--host", ENDPOINT, "buildx", "version")))
            if options["generated_read"]:
                # Discovery is fixed system paths only, not user plugin config or contexts.
                compose_path = adapter.find_native("docker-compose")
                buildx_path = adapter.find_native("docker-buildx")
                # Reuse the adapter's read-only origin safety/size boundary. No
                # private publication, binding, launcher or native grant is created.
                with adapter.NativeSnapshot(compose_path) as compose_source, \
                        adapter.NativeSnapshot(buildx_path) as buildx_source:
                    require(metadata_query(str(compose_path), "version", "--short") in adapter.COMPOSE_VERSIONS)
                    require(bool(metadata_query(str(buildx_path), "version")))
                    compose_source.recheck()
                    buildx_source.recheck()

        check("toolchain", toolchain)
    except (OSError, ValueError, TypeError, KeyError, AttributeError, RuntimeError, subprocess.SubprocessError):
        report["checks"].append({"stage": report["stage"], "reason": report["reason"]})
        return report
    report.update(readiness="ready", stage="complete", reason="metadata-ready", next_step="run-authorized-proof")
    return report


def main():
    try:
        options = parse_options(sys.argv[1:])
    except SystemExit:
        if "--preflight" not in sys.argv[1:]:
            raise
        print(json.dumps(preflight_report(), sort_keys=True))
        return 1
    report = preflight(options)
    if options["preflight"] or report["readiness"] != "ready":
        print(json.dumps(report, sort_keys=True))
        return 0 if report["readiness"] == "ready" else 1
    root, parent = Path.cwd(), options["parent"]
    consumer, attachment = options["consumer"], options["attachment"]
    runtime_directories, generated_read = options["runtime_directories"], options["generated_read"]
    print("[starter-lifecycle] Explicit " + ("consumer release/DinD" if consumer else
          "base lifecycle + synthetic runtime directories (no published ports)" if runtime_directories else
          "base lifecycle + Task attachment" if attachment else "base lifecycle") + " scenario. "
          "Expect downloads, minutes of CPU/build time and substantial disk use; startup may build. "
           "Shared build cache is retained; owned images are removed only when exclusive ownership is verified. "
           "Local daemon only; no initialization or optional socket proof.", flush=True)
    try:
        ownership = Run.create(root, parent, variant="consumer") if consumer else Run.create(root, parent)
    except Exception:
        print(lifecycle_diagnostic(None, "registration"), file=sys.stderr)
        return 1
    try:
        scratch = Path(ownership.data["scratch"])
        print("[starter-lifecycle] " + lifecycle_diagnostic(ownership, "prepare"), flush=True)
        lifecycle_class = ConsumerLifecycle if consumer else RuntimeDirectoriesLifecycle if runtime_directories else Lifecycle
        lifecycle = lifecycle_class(root, scratch, ownership)
        if attachment:
            lifecycle.attachment_scenario = True
        lifecycle.allow_generated_dockerfile_read = generated_read
    except (Exception, KeyboardInterrupt):
        print(lifecycle_diagnostic(ownership, "environment"), file=sys.stderr)
        try:
            ownership.finish("failed")
        except Exception:
            print(lifecycle_diagnostic(ownership, "cleanup", "outcome-unpersisted"), file=sys.stderr)
        try:
            ownership.retain()
        except Exception:
            print(lifecycle_diagnostic(ownership, "cleanup", "retention-unverified"), file=sys.stderr)
        finally:
            try:
                ownership.close()
            except Exception:
                print(lifecycle_diagnostic(ownership, "cleanup", "lease-unclosed"), file=sys.stderr)
        return 1
    original_env = dict(os.environ)
    failure = None
    errors = []
    phase = "environment"
    was_interrupted = False
    def interrupted(signum, _frame):
        nonlocal was_interrupted
        was_interrupted = True
        raise RuntimeError(f"Interrupted by signal {signum}")
    try:
        os.environ.clear()
        os.environ.update(lifecycle.env)
        signal.signal(signal.SIGTERM, interrupted)
        signal.signal(signal.SIGINT, interrupted)
        phase = None
        lifecycle.execute()
    except (Exception, KeyboardInterrupt):
        was_interrupted |= isinstance(sys.exc_info()[1], KeyboardInterrupt)
        failure = (lifecycle_diagnostic(ownership, phase) if phase else failure_message(lifecycle))
        if was_interrupted:
            failure = lifecycle_diagnostic(ownership, ownership.data.get("stage"), "interrupted")
    finally:
        try:
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            signal.signal(signal.SIGINT, signal.SIG_IGN)
        except Exception:
            errors.append("cleanup-unverified")
        try:
            cleanup_failed = True
            try:
                if failure or was_interrupted:
                    try:
                        lifecycle.retain()
                    except Exception:
                        errors.append("retention-unverified")
                    try:
                        if snapshot(root) != lifecycle.before or run("git", "status", "--porcelain=v1", "--untracked-files=all", cwd=root) != lifecycle.source_status:
                            errors.append("primary-changed")
                    except Exception:
                        errors.append("primary-unverified")
                else:
                    errors.extend(lifecycle.cleanup())
                cleanup_failed = False
            except Exception:
                errors.append("cleanup-unverified")
            finally:
                try:
                    ownership.finish("interrupted" if was_interrupted else "failed" if cleanup_failed or failure or errors else "passed")
                except Exception:
                    errors.append("outcome-unpersisted")
        finally:
            try:
                ownership.close()
            except Exception:
                errors.append("lease-unclosed")
            os.environ.clear()
            os.environ.update(original_env)
    if failure:
        print(f"[starter-lifecycle:error] {failure}", file=sys.stderr)
    for error in errors:
        reason = error if isinstance(error, str) and error in {"retention-unverified", "primary-changed", "primary-unverified",
                                   "cleanup-unverified", "outcome-unpersisted", "lease-unclosed"} else "unknown"
        print("[starter-lifecycle:cleanup] " + lifecycle_diagnostic(ownership, "cleanup", reason), file=sys.stderr)
    if failure or errors:
        return 1
    print(("Fixture release clone/build/start and nested Docker verified. Exactly two verified feature state volumes retained; "
           "this is not complete resource cleanup. " if consumer else
             "Base build/start/direct-exec/recreate, managed persistence verified. ") +
          ("Synthetic authority and SSH directory/key preservation with no published ports verified. " if runtime_directories else "") +
          "Primary preservation verified. "
          "Registered owned resources removed; shared build cache and compact run diagnostics retained.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
