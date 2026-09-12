"""Local test-owned resources. Importing this module performs no I/O."""

import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import uuid


LABEL = "org.gentle-starter.test-run"
ENDPOINT = "unix:///var/run/docker.sock"
KINDS = ("container", "network", "volume", "image")
MARKER = ".starter-test-owner"


class Unsafe(RuntimeError):
    """A bounded public reason, never a subprocess error or private output."""


def command(*args, cwd=None, env=None):
    try:
        return subprocess.check_output(args, cwd=cwd, env=env, text=True,
                                       stderr=subprocess.PIPE).strip()
    except (OSError, subprocess.CalledProcessError):
        raise Unsafe("command failed; private output withheld") from None


def registry_path(root):
    common = command("git", "rev-parse", "--path-format=absolute", "--git-common-dir", cwd=root)
    return Path(common).resolve() / "starter-test-runs"


def plain(path):
    return path.is_absolute() and path.resolve() == path and not path.is_symlink()


def private(path, directory=False):
    metadata = path.lstat()
    expected = stat.S_ISDIR if directory else stat.S_ISREG
    if not plain(path) or not expected(metadata.st_mode) or metadata.st_uid != os.getuid() or metadata.st_mode & 0o077:
        raise Unsafe("inventory path is not private and owned by the current user")


def atomic(path, data):
    private(path.parent, directory=True)
    fd, name = tempfile.mkstemp(prefix=".record-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(data, stream, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def read_record(path, root):
    private(path)
    if path.stat().st_size > 131072:
        raise Unsafe("inventory exceeds the bounded record size")
    try:
        data = json.loads(path.read_text())
    except (ValueError, UnicodeError):
        raise Unsafe("malformed inventory") from None
    return validate_record(data, path, root)


def validate_record(data, path, root):
    try:
        run = data["run"]
        if str(uuid.UUID(run)) != run or path.name != run + ".json":
            raise ValueError
        expected = {"version", "run", "source", "registry", "endpoint", "daemon", "scratch", "inode",
                    "project", "tag", "armed", "resources", "stage", "exit", "test", "outcome", "worker"}
        if set(data) != expected or data["version"] != 1 or data["source"] != str(root):
            raise ValueError
        if data["registry"] != str(path.parent) or data["endpoint"] != ENDPOINT:
            raise ValueError
        if data["project"] != "starter-lifecycle-" + run + "_devcontainer" or data["tag"] != "starter-lifecycle-" + run + "-img:0.1":
            raise ValueError
        if not isinstance(data["daemon"], str) or not data["daemon"] or len(data["daemon"]) > 128:
            raise ValueError
        if type(data["armed"]) is not bool or type(data["worker"]) is not int or data["worker"] < 0:
            raise ValueError
        if data["stage"] not in {"registered", "prepare", "build", "up", "restart", "verify", "cleanup"}:
            raise ValueError
        if data["outcome"] not in {"pending", "removed", "retained", "unverifiable"} or (data["exit"] is not None and type(data["exit"]) is not int):
            raise ValueError
        if data["test"] not in {"pending", "passed", "failed", "interrupted"}:
            raise ValueError
        if data["inode"] is not None and (not isinstance(data["inode"], list) or len(data["inode"]) != 2 or any(type(v) is not int for v in data["inode"])):
            raise ValueError
        resources = data["resources"]
        if set(resources) != set(KINDS):
            raise ValueError
        for kind, items in resources.items():
            if not isinstance(items, dict) or len(items) > 256:
                raise ValueError
            for identity, evidence in items.items():
                pattern = r"sha256:[0-9a-f]{64}" if kind == "image" else (r"[A-Za-z0-9][A-Za-z0-9_.-]{0,255}" if kind == "volume" else r"[0-9a-f]{64}")
                if not re.fullmatch(pattern, identity) or set(evidence) != {"labels", "tags", "created"}:
                    raise ValueError
                labels = {LABEL: run}
                if kind != "image":
                    labels["com.docker.compose.project"] = data["project"]
                if evidence["labels"] != labels or not isinstance(evidence["tags"], list):
                    raise ValueError
                if any(not isinstance(tag, str) or len(tag) > 256 for tag in evidence["tags"]):
                    raise ValueError
                if not isinstance(evidence["created"], str) or len(evidence["created"]) > 64 or (kind == "volume" and not evidence["created"]):
                    raise ValueError
        scratch = Path(data["scratch"])
        if scratch.name != "starter-test-" + run or not plain(scratch):
            raise ValueError
        for protected in (root, path.parent.parent):
            if scratch == protected or scratch.is_relative_to(protected) or protected.is_relative_to(scratch):
                raise ValueError
    except (ValueError, TypeError, KeyError, AttributeError):
        raise Unsafe("malformed inventory or conflicting worktree binding") from None
    return data


class Docker:
    def __init__(self, home):
        self.env = {"PATH": os.environ["PATH"], "HOME": str(home), "LANG": "C.UTF-8",
                    "DOCKER_HOST": ENDPOINT, "DOCKER_CONFIG": str(home / ".docker")}

    def __call__(self, *args):
        return command("docker", *args, env=self.env)

    def daemon(self):
        value = self("info", "--format", "{{.ID}}")
        if not value or len(value) > 128:
            raise Unsafe("local daemon identity unavailable")
        return value

    def ids(self, kind, filters=()):
        if kind == "container":
            args = ["ps", "-aq", "--no-trunc"]
        else:
            args = [kind, "ls", "-q"] + ([] if kind == "volume" else ["--no-trunc"])
            if kind == "image":
                args.append("--all")
        for value in filters:
            args.extend(["--filter", value])
        return set(self(*args).split())

    def inspect(self, kind, identity):
        # Successful enumeration proves absence. Inspect failure is never absence.
        if identity not in self.ids(kind):
            return None
        field = ".Config.Labels" if kind in {"image", "container"} else ".Labels"
        identifier = ".Name" if kind == "volume" else ".Id"
        fields = [identifier, field]
        if kind == "image":
            fields += [".RepoTags", ".RepoDigests"]
        elif kind == "volume":
            fields += [".CreatedAt"]
        template = "[" + ",".join("{{json " + field + "}}" for field in fields) + "]"
        try:
            result = json.loads(self(kind, "inspect", "--format", template, identity))
            if result[0] != identity or not isinstance(result[1] or {}, dict):
                raise ValueError
            return {"id": result[0], "labels": result[1] or {},
                    "tags": (result[2] or []) if kind == "image" else [],
                    "digests": (result[3] or []) if kind == "image" else [],
                    "created": result[2] if kind == "volume" else ""}
        except (ValueError, TypeError, IndexError, KeyError):
            raise Unsafe("resource identity response is unverifiable") from None


class Run:
    def __init__(self, path, data, docker, lease):
        self.path, self.data, self.docker, self.lease = path, data, docker, lease

    @classmethod
    def create(cls, root, parent, store=None, docker=None):
        root, parent = Path(root), Path(parent)
        store = registry_path(root) if store is None else Path(store)
        if not plain(root) or not plain(parent) or not parent.is_dir():
            raise Unsafe("source and scratch parent must be existing canonical directories")
        token = str(uuid.uuid4())
        scratch = parent / ("starter-test-" + token)
        for protected in (root, store.parent):
            if scratch.is_relative_to(protected) or protected.is_relative_to(scratch):
                raise Unsafe("scratch overlaps source or repository metadata")
        if not store.exists():
            store.mkdir(mode=0o700)
        private(store, directory=True)
        docker = docker or Docker(scratch / "home")
        daemon = docker.daemon()
        path = store / (token + ".json")
        lock = store / (token + ".lock")
        lease = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_RDWR, 0o600)
        fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
        data = {"version": 1, "run": token, "source": str(root), "registry": str(store),
                "endpoint": ENDPOINT, "daemon": daemon, "scratch": str(scratch), "inode": None,
                "project": "starter-lifecycle-" + token + "_devcontainer",
                "tag": "starter-lifecycle-" + token + "-img:0.1", "armed": False,
                "resources": {kind: {} for kind in KINDS}, "stage": "registered", "exit": None,
                "outcome": "pending", "test": "pending", "worker": 0}
        run = cls(path, data, docker, lease)
        try:
            run.save()  # Durable intent precedes sandbox or Docker mutation.
            scratch.mkdir(mode=0o700)
            marker = scratch / MARKER
            with marker.open("x") as stream:
                stream.write(token)
            marker.chmod(0o600)
            metadata = scratch.stat()
            data["inode"] = [metadata.st_dev, metadata.st_ino]
            run.save()
        except BaseException:
            run.close()
            raise
        return run

    @classmethod
    def open(cls, path, root, apply=False, docker=None):
        data = read_record(path, root)
        lease = None
        if apply:
            lock = path.with_suffix(".lock")
            private(lock)
            lease = os.open(lock, os.O_RDWR | os.O_NOFOLLOW)
            try:
                fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                os.close(lease)
                raise Unsafe("run is active; recovery refused") from None
        return cls(path, data, docker or Docker(Path(data["scratch"]) / "home"), lease)

    def close(self):
        if self.lease is not None:
            os.close(self.lease)
            self.lease = None

    def save(self):
        validate_record(self.data, self.path, Path(self.data["source"]))
        if len(json.dumps(self.data).encode()) > 131072:
            raise Unsafe("inventory exceeds the bounded record size")
        atomic(self.path, self.data)

    def stage(self, name, status=None):
        self.data.update(stage=name, exit=status)
        self.save()

    def finish(self, outcome):
        if outcome not in {"passed", "failed", "interrupted"}:
            raise Unsafe("invalid test outcome")
        self.data["test"] = outcome
        self.save()

    def produce(self, argv, cwd, env, stage):
        """Register a stopped producer before allowing it to create resources."""
        if self.lease is None or not self.data["armed"]:
            raise Unsafe("producer requires an armed run and exclusive lease")
        self.check_daemon()
        self.check_worker()
        self.stage(stage)
        handshake = "import os,sys; token=os.read(0,1); token == b'x' and os.execvpe(sys.argv[1], sys.argv[1:], os.environ)"
        log = Path(self.data["scratch"]) / "task.log"
        with log.open("w") as stream:
            process = subprocess.Popen([sys.executable, "-c", handshake, *argv], cwd=cwd, env=env,
                                       stdout=stream, stderr=stream, stdin=subprocess.PIPE,
                                       pass_fds=(self.lease,), start_new_session=True)
            try:
                self.data["worker"] = process.pid
                self.save()
                assert process.stdin is not None
                process.stdin.write(b"x")
                process.stdin.close()
                status = process.wait()
            except BaseException:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                raise
        self.stage(stage, status)
        if status:
            raise Unsafe(f"{stage} failed ({status}); private output withheld")
        self.capture()

    def expected(self, kind):
        labels = {LABEL: self.data["run"]}
        if kind != "image":
            labels["com.docker.compose.project"] = self.data["project"]
        return labels

    def check_daemon(self):
        if self.docker.daemon() != self.data["daemon"]:
            raise Unsafe("local daemon differs from the recorded execution")

    def discover(self, kind):
        filters = [f"label={LABEL}={self.data['run']}"]
        owned = self.docker.ids(kind, filters)
        if kind != "image":
            owned |= self.docker.ids(kind, ["label=com.docker.compose.project=" + self.data["project"]])
        return owned

    def arm(self):
        self.check_daemon()
        if any(self.discover(kind) for kind in KINDS):
            raise Unsafe("sandbox label/project collision")
        name = self.data["project"].removesuffix("_devcontainer") + "-run"
        if self.docker.ids("container", [f"name=^/{name}$"]) or any(
                self.docker.ids("image", ["reference=" + tag]) for tag in self.image_tags()):
            raise Unsafe("sandbox container/image name collision")
        self.data["armed"] = True
        self.save()

    def inspect_owned(self, kind, identity):
        resource = self.docker.inspect(kind, identity)
        if resource is not None and any(resource["labels"].get(k) != v for k, v in self.expected(kind).items()):
            raise Unsafe("resource labels conflict with recorded ownership")
        if resource is not None and kind == "volume":
            evidence = self.data["resources"][kind].get(identity)
            if not resource.get("created") or (evidence and evidence["created"] != resource["created"]):
                raise Unsafe("volume creation identity conflicts with recorded ownership")
        return resource

    def capture(self, persist=True):
        self.check_daemon()
        if not self.data["armed"]:
            return
        for kind in KINDS:
            for identity in self.discover(kind):
                resource = self.inspect_owned(kind, identity)
                if resource is not None:
                    previous = self.data["resources"][kind].get(identity)
                    tags = previous["tags"] if previous else resource["tags"]
                    self.data["resources"][kind][identity] = {"labels": self.expected(kind), "tags": tags,
                                                            "created": resource.get("created", "")}
                    if persist:
                        self.save()

    def check_worker(self):
        if self.data["worker"]:
            try:
                os.killpg(self.data["worker"], 0)
            except ProcessLookupError:
                return
            except PermissionError:
                pass
            raise Unsafe("recorded producer process group is still present; wait for it to stop")

    def check_scratch(self):
        path = Path(self.data["scratch"])
        if not plain(path):
            raise Unsafe("scratch path is symlinked or no longer canonical")
        if not path.exists():
            return None
        metadata = path.lstat()
        if [metadata.st_dev, metadata.st_ino] != self.data["inode"] or not path.is_dir():
            raise Unsafe("scratch filesystem identity differs from the recorded execution")
        marker = path / MARKER
        private(marker)
        if marker.stat().st_size > 64 or marker.read_text() != self.data["run"]:
            raise Unsafe("scratch ownership marker conflicts")
        return path

    def remove_scratch(self):
        path = self.check_scratch()
        if path is None:
            return
        if not shutil.rmtree.avoids_symlink_attacks:
            raise Unsafe("platform cannot safely remove sandbox directories")
        # Keep the marker until all potentially root-owned sandbox contents are gone.
        for child in path.iterdir():
            if child.name == MARKER:
                continue
            if child.is_dir() and not child.is_symlink():
                shutil.rmtree(child)
            else:
                child.unlink()
        self.check_scratch()
        (path / MARKER).unlink()
        path.rmdir()

    def image_tags(self):
        # Dev Containers 0.89.0: getFolderImageName + getRemoteUserUIDUpdateDetails.
        candidate = Path(self.data["scratch"]) / ("starter-lifecycle-" + self.data["run"])
        folder_hash = hashlib.sha256(str(candidate).encode()).hexdigest()
        return (self.data["tag"], f"vsc-{candidate.name}-{folder_hash}-uid:latest")

    def image_target(self, identity, resource):
        evidence = self.data["resources"]["image"][identity]
        tags = resource["tags"]
        if tags != evidence["tags"] or len(tags) > 1 or any(tag not in self.image_tags() for tag in tags):
            return None
        # Containerd can expose a local repository digest without a registry push.
        # Accept only the owned repository at this exact captured content identity.
        local_digests = {tag.rsplit(":", 1)[0] + "@" + identity for tag in tags}
        if any(digest not in local_digests for digest in resource["digests"]):
            return None
        if self.docker.ids("container", ["ancestor=" + identity]):
            return None
        if tags:
            if self.docker.ids("image", ["reference=" + tags[0]]) != {identity}:
                raise Unsafe("run image tag no longer resolves to the recorded image")
            return tags[0]
        return identity

    def cleanup(self, apply=False):
        result = {"removed": [], "retained": ["shared build cache (no dedicated builder)"], "failed": []}
        validated = False
        original = json.loads(json.dumps(self.data))
        try:
            # Re-read disk identity before any mutation; preview never repairs metadata.
            if read_record(self.path, Path(self.data["source"])) != self.data:
                raise Unsafe("inventory changed during execution")
            validated = True
            if apply and self.lease is None:
                raise Unsafe("cleanup requires an exclusive run lease")
            self.check_worker()
            self.check_scratch()
            self.capture(persist=apply)
            validate_record(self.data, self.path, Path(self.data["source"]))
            # Validate the entire known scope before the first destructive call.
            for kind in KINDS:
                for identity in self.data["resources"][kind]:
                    self.inspect_owned(kind, identity)
            for kind in KINDS:
                for identity in self.data["resources"][kind]:
                    self.check_daemon()
                    resource = self.inspect_owned(kind, identity)
                    if resource is None:
                        continue
                    target = self.image_target(identity, resource) if kind == "image" else identity
                    if target is None:
                        result["retained"].append("shared or unverifiable image " + identity)
                        continue
                    if apply:
                        args = ("rm", "-f", target) if kind == "container" else (kind, "rm", target)
                        if kind == "image":
                            args = ("image", "rm", "--no-prune", target)
                        self.docker(*args)
                        if self.docker.inspect(kind, identity) is not None:
                            raise Unsafe("resource removal could not be verified")
                    result["removed"].append(("removed and verified " if apply else "would remove ") + kind + " " + identity)
            if apply:
                if any(self.discover(kind) for kind in KINDS[:3]):
                    raise Unsafe("sandbox resources remain after cleanup")
                self.remove_scratch()
            result["removed"].append(("removed and verified " if apply else "would remove ") + "scratch " + self.data["scratch"])
        except Unsafe as error:
            result["failed"].append(str(error))
        except OSError:
            result["failed"].append("filesystem cleanup failed; keep the ownership marker and inspect permissions (no sudo fallback)")
        if result["failed"]:
            result["retained"].append("recovery inventory and scratch scope " + self.data["scratch"])
        if apply and validated:
            self.data["outcome"] = "unverifiable" if result["failed"] else ("retained" if len(result["retained"]) > 1 else "removed")
            try:
                self.save()
            except (Unsafe, OSError):
                result["failed"].append("could not persist cleanup outcome")
        if not apply:
            self.data = original
        return result

    def forget(self):
        if self.lease is None or self.data["outcome"] != "removed":
            raise Unsafe("only verified resource-free records can be forgotten")
        self.check_worker()
        self.check_daemon()
        if self.check_scratch() or any(self.discover(kind) for kind in KINDS):
            raise Unsafe("run resources remain; cannot forget recovery evidence")
        for kind in KINDS:
            if any(self.docker.inspect(kind, identity) is not None for identity in self.data["resources"][kind]):
                raise Unsafe("recorded resources remain")
        self.path.unlink()
        self.path.with_suffix(".lock").unlink()
