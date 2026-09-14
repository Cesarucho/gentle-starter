#!/usr/bin/env python3
"""Explicit, expensive base lifecycle proof. Importing this module is inert."""

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import stat
import subprocess
import sys


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from test_resources import LABEL, Run, Unsafe


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


def configure(root):
    """Select the public base only; do not merge Compose in Python."""
    module = resolver(root)
    service, paths, _ = module.selection(root)
    base = root / ".devcontainer/docker-compose.yml"
    if paths[0] != base or service != "container-svc":
        raise ValueError("Base fixture requires docker-compose.yml first and service container-svc; review customization")
    config = {
        "name": "starter-lifecycle", "dockerComposeFile": ["./docker-compose.yml"],
        "service": service, "workspaceFolder": "/home/ubuntu/${localEnv:APP_NAME}",
        "overrideCommand": True, "remoteUser": "ubuntu",
        "mounts": ["source=${localWorkspaceFolder},target=/home/ubuntu/${localEnv:APP_NAME},type=bind"],
        "postCreateCommand": "bash ${containerWorkspaceFolder}/.devcontainer/setup.sh",
    }
    (root / ".devcontainer/devcontainer.json").write_text(json.dumps(config, indent=4) + "\n")
    disabled = {"3030-ai-pi-coding.sh", "3040-ai-pi-gentle.sh", "4010-tool-ssh-server.sh"}
    for link in (root / ".devcontainer/install/03-enabled").iterdir():
        if link.is_symlink() and link.resolve().name in disabled:
            link.unlink()
    for name in (".env", ".devcontainer/.env"):
        (root / name).write_text("")
        (root / name).chmod(0o600)


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

    def task(self, action):
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
        module, service, selected = self.resolve()
        _, paths, inputs = module.selection(self.candidate)
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
        manifest = module.project_manifest(self.candidate, service, paths, inputs, selected, self.project)
        if len(manifest["volumes"]) != len(selected.get("volumes", [])) or not all(v["managed"] and not v["read_only"] for v in manifest["volumes"]):
            raise ValueError("Base fixture accepts only writable managed .env.d binds; move sockets/external mounts to overrides")
        return manifest

    def container(self):
        _, service, _ = self.resolve()
        ids = self.docker("ps", "-q", "--filter", f"label=com.docker.compose.project={self.project}",
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
        identity = self.docker("exec", "--user", "ubuntu", container, "printenv", "GENTLE_VOLUME_MANIFEST_ID")
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

    def execute(self):
        self.ownership.arm()
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
        configured = snapshot(self.candidate)
        self.task("build")
        self.task("up")
        first = self.container()
        self.assert_state(first, write=True)
        self.task("restart")
        second = self.container()
        self.ownership.stage("verify")
        if first == second:
            raise RuntimeError("Restart did not recreate the service container")
        self.assert_state(second)
        if snapshot(self.candidate) != configured:
            raise RuntimeError("Candidate public source bytes, links, or modes changed")

    def cleanup(self):
        result = self.ownership.cleanup(apply=True)
        errors = list(result["failed"])
        for message in result["removed"] + result["retained"]:
            print(f"[starter-lifecycle:cleanup] {message}")
        if len(result["retained"]) > 1:
            errors.append("run images retained; inspect the recovery preview")
        try:
            if snapshot(self.root) != self.before or run("git", "status", "--porcelain=v1", "--untracked-files=all", cwd=self.root) != self.source_status:
                errors.append("primary branch, HEAD, index, public files, modes, links, or status changed")
                self.ownership.finish("failed")
        except (OSError, ValueError, Unsafe, subprocess.CalledProcessError):
            errors.append("could not verify primary preservation")
        return errors


def main():
    if len(sys.argv) != 3 or sys.argv[1] != "--daemon-visible-scratch":
        raise SystemExit("Usage: task test:starter:lifecycle -- --daemon-visible-scratch ABSOLUTE_PARENT\n"
                         "Explicitly confirm a local-daemon-visible scratch parent outside this repository; "
                         "inside a devcontainer use a mounted workspace sibling. Expensive: one build, up, restart; "
                         "downloads, disk and CPU use; startup may build automatically. No initialization or optional socket proof.")
    root = Path(run("git", "rev-parse", "--show-toplevel")).resolve()
    parent = Path(sys.argv[2])
    if Path.cwd() != root or not parent.is_absolute() or not parent.is_dir() or parent.resolve() != parent or parent == root or parent.is_relative_to(root):
        raise SystemExit("Run from repository root with an existing plain scratch parent outside the repository")
    for command in ("docker", "devcontainer", "task", "git", "rsync", "yq"):
        if not shutil.which(command):
            raise SystemExit(f"Required command unavailable: {command}")
    print("[starter-lifecycle] Explicit base scenario: one build, start, noninteractive connection, restart. "
          "Expect downloads, minutes of CPU/build time and substantial disk use; startup may build. "
           "Shared build cache is retained; owned images are removed only when exclusive ownership is verified. "
           "Local daemon only; no initialization or optional socket proof.", flush=True)
    ownership = Run.create(root, parent)
    scratch = Path(ownership.data["scratch"])
    print(f"[starter-lifecycle] Recovery run: {ownership.data['run']}; inventory: {ownership.path}", flush=True)
    try:
        lifecycle = Lifecycle(root, scratch, ownership)
    except BaseException:
        ownership.cleanup(apply=True)
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
        ownership.finish("passed")
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError):
        failure = "Sandbox failed; stage/exit are retained in the run inventory; private output withheld"
        try:
            ownership.finish("interrupted" if was_interrupted else "failed")
        except (OSError, Unsafe):
            failure += "; could not persist test outcome"
    finally:
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        try:
            errors = lifecycle.cleanup()
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
    print("Base build/start/connect/recreate, managed persistence and primary preservation verified. "
           "Registered resources removed; shared build cache and compact run diagnostics retained.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
