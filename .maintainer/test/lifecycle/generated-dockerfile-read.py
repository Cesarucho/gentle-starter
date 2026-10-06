#!/usr/bin/env python3
"""Opt-in cooperative Bake adapter. Importing performs no I/O or delegation."""

import hashlib
import fcntl
import json
import os
from pathlib import Path
import re
import pwd
import stat
import sys
import tempfile
import time
import uuid

from test_resources import Docker, ENDPOINT, LABEL, Run, Unsafe, private, process_status, producer_identity, read_record

LIMIT = 262144
NATIVE_DIRECTORIES = ("/usr/libexec/docker/cli-plugins", "/usr/lib/docker/cli-plugins")
NATIVE_LIMIT = 134217728
METADATA_DIRECTORY = Path("/tmp")
PREFIX = b"\n    ARG _DEV_CONTAINERS_BASE_IMAGE=scratch\n"
SUFFIX = (b'\n\nFROM $_DEV_CONTAINERS_BASE_IMAGE AS dev_containers_target_stage\n'
          b'LABEL devcontainer.metadata="[ \\\n'
          b'{\\"postCreateCommand\\":\\"bash \\${containerWorkspaceFolder}/.devcontainer/setup.sh\\",'
          b'\\"mounts\\":[\\"source=\\${localWorkspaceFolder},target=/home/ubuntu/\\${localEnv:APP_NAME},type=bind\\"],'
          b'\\"remoteUser\\":\\"ubuntu\\",\\"overrideCommand\\":true} \\\n'
          b']"\n')


def require(condition, reason):
    if not condition:
        raise Unsafe(reason)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate JSON key")
        result[key] = value
    return result


def decode(payload):
    require(len(payload) <= LIMIT, "input exceeds size bound")
    try:
        return json.loads(payload, object_pairs_hook=unique_object,
                          parse_constant=lambda _: (_ for _ in ()).throw(Unsafe("nonfinite JSON")))
    except (ValueError, UnicodeError, RecursionError):
        raise Unsafe("malformed bounded JSON") from None


def identity(metadata):
    return [metadata.st_dev, metadata.st_ino, metadata.st_uid, metadata.st_gid,
            metadata.st_mode, metadata.st_size, metadata.st_mtime_ns, metadata.st_ctime_ns]


class Inputs:
    """Descriptor reads and pathname/ancestor snapshots, rechecked before exec."""

    def __init__(self):
        self.files = {}
        self.directories = {}

    def parents(self, path):
        require(path.is_absolute() and path.resolve() == path, "noncanonical input")
        for parent in path.parents:
            metadata = parent.lstat()
            sticky_tmp = parent == Path("/tmp") and metadata.st_uid == 0 and metadata.st_mode & stat.S_ISVTX
            require(stat.S_ISDIR(metadata.st_mode) and metadata.st_uid in {0, os.getuid()}
                    and (not metadata.st_mode & 0o022 or sticky_tmp), "unsafe input directory")
            # Directory mtime changes when sibling files are created; inode/mode do not.
            value = identity(metadata)[:5]
            require(parent not in self.directories or self.directories[parent] == value, "directory replaced")
            self.directories[parent] = value

    def read(self, path, native=False):
        path = Path(path)
        self.parents(path)
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        try:
            metadata = os.fstat(descriptor)
            require(stat.S_ISREG(metadata.st_mode) and not metadata.st_mode & 0o022
                    and metadata.st_uid in ({0, os.getuid()} if native else {os.getuid()}), "unsafe file owner/type/mode")
            require(not native or metadata.st_mode & 0o111, "native plugin is not executable")
            bound = 134217728 if native else LIMIT
            require(metadata.st_size <= bound, "file exceeds size bound")
            chunks = []
            total = 0
            while True:
                chunk = os.read(descriptor, min(65536, bound + 1 - total))
                if not chunk:
                    break
                chunks.append(chunk)
                total += len(chunk)
                require(total <= bound, "file exceeds size bound")
            payload = b"".join(chunks)
            require(identity(os.fstat(descriptor)) == identity(metadata)
                    and identity(path.lstat()) == identity(metadata), "file changed while reading")
        finally:
            os.close(descriptor)
        value = [identity(metadata), hashlib.sha256(payload).hexdigest(), native]
        require(path not in self.files or self.files[path] == value, "input changed")
        self.files[path] = value
        return payload

    def recheck(self):
        for path in list(self.files):
            self.read(path, native=self.files[path][2])
        for path, value in self.directories.items():
            require(identity(path.lstat())[:5] == value, "directory changed")


def bounded_native_read(descriptor):
    chunks, total = [], 0
    while True:
        chunk = os.read(descriptor, min(65536, NATIVE_LIMIT + 1 - total))
        if not chunk:
            return b"".join(chunks)
        total += len(chunk)
        require(total <= NATIVE_LIMIT, "native snapshot exceeds size bound")
        chunks.append(chunk)


class NativeSnapshot:
    """Accepted local bytes, not vendor authentication; holds origin descriptors."""

    def __init__(self, path):
        self.path = Path(path)
        self.descriptors = []
        self.ancestry = []
        self.file = None
        require(self.path.is_absolute() and str(self.path.parent) in NATIVE_DIRECTORIES
                and self.path.name in {"docker-compose", "docker-buildx"}
                and ".." not in self.path.parts, "foreign snapshot origin")

    def __enter__(self):
        try:
            root = os.open("/", os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
            self.descriptors.append(root)
            root_metadata = os.fstat(root)
            require(root_metadata.st_uid == 0 and not root_metadata.st_mode & 0o022,
                    "unsafe snapshot root")
            self.root_identity = identity(root_metadata)[:5]
            parent = root
            traversed = Path("/")
            for component in self.path.parent.parts[1:]:
                descriptor = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                                     dir_fd=parent)
                self.descriptors.append(descriptor)
                metadata = os.fstat(descriptor)
                traversed /= component
                sticky_tmp = (traversed == Path("/tmp") and metadata.st_uid == 0
                              and metadata.st_mode & stat.S_ISVTX)
                require(metadata.st_uid in {0, os.getuid()}
                        and (not metadata.st_mode & 0o002 or sticky_tmp),
                        "unsafe snapshot directory")
                self.ancestry.append((parent, component, descriptor, identity(metadata)[:5]))
                parent = descriptor
            self.parent = parent
            self.file = os.open(self.path.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                                dir_fd=parent)
            self.metadata = os.fstat(self.file)
            require(stat.S_ISREG(self.metadata.st_mode)
                    and self.metadata.st_uid in {0, os.getuid()}
                    and not self.metadata.st_mode & 0o002 and self.metadata.st_mode & 0o111,
                    "unsafe snapshot owner/type/mode")
            require(self.metadata.st_size <= NATIVE_LIMIT, "native snapshot exceeds size bound")
            self.payload = bounded_native_read(self.file)
            self.recheck()
            return self
        except BaseException:
            self.close()
            raise

    def recheck(self):
        assert self.file is not None
        require(identity(os.fstat(self.descriptors[0]))[:5] == self.root_identity,
                "snapshot root changed")
        for parent, name, descriptor, expected in self.ancestry:
            require(identity(os.fstat(descriptor))[:5] == expected
                    and identity(os.stat(name, dir_fd=parent, follow_symlinks=False))[:5] == expected,
                    "snapshot ancestry replaced")
        expected = identity(self.metadata)
        require(identity(os.fstat(self.file)) == expected
                and identity(os.stat(self.path.name, dir_fd=self.parent,
                                     follow_symlinks=False)) == expected,
                "snapshot source changed")

    def close(self):
        if self.file is not None:
            os.close(self.file)
            self.file = None
        for descriptor in reversed(self.descriptors):
            os.close(descriptor)
        self.descriptors.clear()

    def __exit__(self, *_):
        self.close()


def verify_snapshot_destination(parent, name, payload):
    """Independently read the staged inode, never trust the write operation alone."""
    descriptor = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
    try:
        metadata = os.fstat(descriptor)
        require(stat.S_ISREG(metadata.st_mode) and metadata.st_uid == os.getuid()
                and stat.S_IMODE(metadata.st_mode) == 0o500
                and metadata.st_size <= NATIVE_LIMIT, "unsafe private snapshot")
        copied = bounded_native_read(descriptor)
        require(identity(os.fstat(descriptor)) == identity(metadata)
                and identity(os.stat(name, dir_fd=parent, follow_symlinks=False)) == identity(metadata),
                "private snapshot changed")
        require(hashlib.sha256(copied).digest() == hashlib.sha256(payload).digest(),
                "private snapshot hash mismatch")
        return metadata
    finally:
        os.close(descriptor)


def publish_native_snapshot(source, private_parent, name):
    """Future preparation supplies its checked owned parent; never called on import.

    Publication is exclusive and cooperative, not protection from same-user races.
    This helper does not register ownership or publish environment/binding state.
    """
    require(name in {"docker-compose", "docker-buildx"}, "foreign snapshot destination")
    private_parent = Path(private_parent)
    inputs = Inputs()
    inputs.parents(private_parent / name)
    private(private_parent, directory=True)
    descriptor = os.open(private_parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    staged = ".snapshot-" + uuid.uuid4().hex
    created = None
    try:
        directory = os.fstat(descriptor)
        require(stat.S_IMODE(directory.st_mode) == 0o700 and directory.st_uid == os.getuid(),
                "unsafe private snapshot directory")
        with NativeSnapshot(source) as snapshot:
            require(snapshot.path.name == name, "snapshot name mismatch")
            writer = os.open(staged, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                             0o600, dir_fd=descriptor)
            try:
                created = identity(os.fstat(writer))[:2]
                view = memoryview(snapshot.payload)
                while view:
                    count = os.write(writer, view)
                    require(count > 0, "snapshot write made no progress")
                    view = view[count:]
                os.fchmod(writer, 0o500)
                os.fsync(writer)
            finally:
                os.close(writer)
            copied = verify_snapshot_destination(descriptor, staged, snapshot.payload)
            require(identity(copied)[:2] == created, "private staging replaced")
            snapshot.recheck()
            inputs.recheck()
            require(identity(private_parent.lstat())[:5] == identity(directory)[:5],
                    "private snapshot directory replaced")
            # linkat publishes without replacing an existing file or dangling link.
            os.link(staged, name, src_dir_fd=descriptor, dst_dir_fd=descriptor,
                    follow_symlinks=False)
            os.fsync(descriptor)
        return private_parent / name
    finally:
        try:
            if created is not None:
                metadata = os.stat(staged, dir_fd=descriptor, follow_symlinks=False)
                if stat.S_ISREG(metadata.st_mode) and identity(metadata)[:2] == created:
                    os.unlink(staged, dir_fd=descriptor)
        finally:
            os.close(descriptor)


def find_native(name):
    for directory in NATIVE_DIRECTORIES:
        path = Path(directory) / name
        if path.exists():
            return path
    raise Unsafe("native plugin unavailable; no installation attempted")


BOOTSTRAP = r'''#!/usr/bin/python3
"""Private cooperative bootstrap; load only descriptor-validated source bytes."""
import hashlib, json, os, stat, sys, types
from pathlib import Path
sys.dont_write_bytecode = True
STARTUP = json.loads(__STARTUP__)

def check(condition):
    if not condition:
        raise RuntimeError("private bootstrap input refused")

def ident(s):
    return [s.st_dev, s.st_ino, s.st_uid, s.st_gid, s.st_mode,
            s.st_size, s.st_mtime_ns, s.st_ctime_ns]

def verified(path, pin):
    path = Path(path)
    check(path.is_absolute() and ".." not in path.parts)
    descriptors, chain = [], []
    try:
        parent = os.open("/", os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        descriptors.append(parent)
        for component in (None, *path.parent.parts[1:]):
            if component is not None:
                child = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
                descriptors.append(child)
                chain.append((parent, component, child, ident(os.fstat(child))[:5]))
                parent = child
            s = os.fstat(parent)
            sticky_tmp = (component == "tmp" and len(chain) == 1 and s.st_uid == 0
                          and s.st_mode & stat.S_ISVTX)
            check(s.st_uid in {0, os.getuid()} and (not s.st_mode & 0o022 or sticky_tmp))
        fd = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
        descriptors.append(fd)
        s = os.fstat(fd)
        check(stat.S_ISREG(s.st_mode) and s.st_uid == os.getuid()
              and not s.st_mode & 0o022 and s.st_size <= 262144 and ident(s) == pin[0])
        chunks, total = [], 0
        while True:
            chunk = os.read(fd, min(65536, 262145-total))
            if not chunk:
                break
            total += len(chunk)
            check(total <= 262144)
            chunks.append(chunk)
        payload = b"".join(chunks)
        check(ident(os.fstat(fd)) == pin[0]
              and ident(os.stat(path.name, dir_fd=parent, follow_symlinks=False)) == pin[0]
              and hashlib.sha256(payload).hexdigest() == pin[1] and pin[2] is False)
        for ancestor, name, child, expected in chain:
            check(ident(os.fstat(child))[:5] == expected
                  and ident(os.stat(name, dir_fd=ancestor, follow_symlinks=False))[:5] == expected)
        return payload
    finally:
        for fd in reversed(descriptors):
            os.close(fd)

def bootstrap():
    environment = dict(os.environ)
    check(environment.get("HGDR_BINDING", STARTUP["binding"]) == STARTUP["binding"])
    environment["HGDR_BINDING"] = STARTUP["binding"]
    # Freeze BOTH modules before executing either; never reread their pathnames.
    payloads = {name: verified(item[0], item[1]) for name, item in STARTUP["modules"].items()}
    previous = sys.modules.get("test_resources")
    try:
        modules = {}
        for name in ("test_resources", "generated_read"):
            module = types.ModuleType(name)
            module.__file__ = STARTUP["modules"][name][0]
            if name == "test_resources":
                sys.modules[name] = module
            exec(compile(payloads[name], module.__file__, "exec"), module.__dict__)
            modules[name] = module
        adapter = modules["generated_read"]
        adapter.delegate(sys.argv[1:], environment, sys.stdin.buffer)
    finally:
        if previous is None:
            sys.modules.pop("test_resources", None)
        else:
            sys.modules["test_resources"] = previous

if __name__ == "__main__":
    try:
        bootstrap()
    except Exception:
        print("Private Buildx bootstrap refused unverifiable input", file=sys.stderr)
        sys.exit(1)
'''


def selection_paths(data, config):
    context = Path(data["scratch"]) / ("starter-lifecycle-" + data["run"]) / ".devcontainer"
    here = Path(__file__).absolute().parent
    return {"compose": config / "plugins/docker-compose", "buildx": config / "native/docker-buildx",
            "launcher": config / "plugins/docker-buildx", "config": config / "config.json",
            "adapter": here / "generated-dockerfile-read.py", "helper": here / "test_resources.py",
            "dockerfile": context / "Dockerfile", "base": context / "docker-compose.yml",
            "core": context / "config/compose/docker-compose-core-tools.yml"}


def launcher_bytes(binding_path, paths, pins):
    startup = {"binding": str(binding_path), "modules": {
        "test_resources": [str(paths["helper"]), pins[str(paths["helper"])]],
        "generated_read": [str(paths["adapter"]), pins[str(paths["adapter"])]]}}
    return BOOTSTRAP.replace("__STARTUP__", repr(json.dumps(startup, sort_keys=True))).encode()


def exact_private(path, mode, directory=False):
    private(path, directory=directory)
    require(stat.S_IMODE(path.lstat().st_mode) == mode, "wrong private selection mode")


def write_private(path, payload, mode):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, mode)
    with os.fdopen(descriptor, "wb") as stream:
        os.fchmod(stream.fileno(), mode)
        stream.write(payload)
        stream.flush()
        os.fsync(stream.fileno())


def owned_selection(inputs, record, root):
    data = decode(inputs.read(record))
    require(data == read_record(record, root), "inventory changed")
    require(data.get("variant", "base") == "base", "foreign selection variant")
    owner = Run(record, data, None, None)
    require(owner.check_scratch() is not None, "missing selection scratch")
    inputs.read(Path(data["scratch"]) / ".starter-test-owner")
    return data


def prepare(lifecycle):
    """Future authorized live run only; validation never calls Docker here."""
    inputs = Inputs()
    data = owned_selection(inputs, lifecycle.ownership.path, lifecycle.root)
    require(data == lifecycle.ownership.data and data["armed"]
            and lifecycle.ownership.lease is not None, "preparation needs owned lease")
    lock = lifecycle.ownership.path.with_suffix(".lock")
    private(lock)
    lease = lifecycle.ownership.lease
    assert lease is not None
    require(identity(os.fstat(lease))[:5] == identity(lock.lstat())[:5],
            "foreign preparation lease")
    probe = os.open(lock, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        try:
            fcntl.flock(probe, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            pass
        else:
            raise Unsafe("preparation lease is not held")
    finally:
        os.close(probe)
    home = Path(data["scratch"]) / "home"
    candidate = Path(data["scratch"]) / ("starter-lifecycle-" + data["run"])
    require(lifecycle.home == home and lifecycle.candidate == candidate, "foreign preparation root")
    exact_private(home, 0o700, directory=True)
    config = home / ".docker"
    config.mkdir(mode=0o700)
    for directory in (config, config / "plugins", config / "native"):
        if directory != config:
            directory.mkdir(mode=0o700)
        exact_private(directory, 0o700, directory=True)
    paths = selection_paths(data, config)
    for name in ("adapter", "helper", "dockerfile", "base", "core"):
        inputs.read(paths[name])
    for name in ("compose", "buildx"):
        publish_native_snapshot(find_native("docker-" + name), paths[name].parent, paths[name].name)
        inputs.read(paths[name], native=True)
    configuration = {"cliPluginsExtraDirs": [str(config / "plugins")]}
    write_private(paths["config"], json.dumps(configuration, sort_keys=True).encode(), 0o600)
    inputs.read(paths["config"])
    binding_path = config / "generated-read.json"
    pins = {str(path): value for path, value in inputs.files.items() if path in paths.values()}
    write_private(paths["launcher"], launcher_bytes(binding_path, paths, pins), 0o500)
    inputs.read(paths["launcher"])
    value = {"record": str(lifecycle.ownership.path), "source": str(lifecycle.root),
             "native": {name: str(paths[name]) for name in ("compose", "buildx")},
             "pins": {str(path): inputs.files[path] for path in paths.values()}}
    write_private(binding_path, json.dumps(value, sort_keys=True).encode(), 0o600)
    environment = {**lifecycle.env, "HOME": str(home), "DOCKER_CONFIG": str(config),
                   "HGDR_BINDING": str(binding_path)}
    validate_selection(environment)
    inputs.recheck()
    lifecycle.env.update(DOCKER_CONFIG=str(config), HGDR_BINDING=str(binding_path))


def binding(inputs, environment):
    path = Path(environment.get("HGDR_BINDING", ""))
    require(path.is_absolute(), "missing adapter binding")
    exact_private(path, 0o600)
    require(path.parent == Path(environment.get("HOME", "")) / ".docker"
            and environment.get("DOCKER_CONFIG") == str(path.parent), "foreign Docker config")
    value = decode(inputs.read(path))
    require(isinstance(value, dict) and set(value) == {"record", "source", "native", "pins"}, "invalid binding")
    data = owned_selection(inputs, Path(value["record"]), Path(value["source"]))
    home = Path(data["scratch"]) / "home"
    require(environment.get("HOME") == str(home) and path == home / ".docker/generated-read.json",
            "foreign selection home")
    for directory in (home, path.parent, path.parent / "plugins", path.parent / "native"):
        exact_private(directory, 0o700, directory=True)
    paths = selection_paths(data, path.parent)
    require(value["native"] == {name: str(paths[name]) for name in ("compose", "buildx")}
            and isinstance(value["pins"], dict) and set(value["pins"]) == {str(p) for p in paths.values()},
            "foreign selection paths or pins")
    for name, selected in paths.items():
        pin = value["pins"][str(selected)]
        require(isinstance(pin, list) and len(pin) == 3 and isinstance(pin[0], list)
                and len(pin[0]) == 8 and all(type(part) is int for part in pin[0])
                and isinstance(pin[1], str) and re.fullmatch(r"[0-9a-f]{64}", pin[1])
                and pin[2] is (name in {"compose", "buildx"}), "invalid selection pin")
        require(pin[0][2] == os.getuid() and stat.S_ISREG(pin[0][4])
                and not pin[0][4] & 0o022 and 0 <= pin[0][5] <= (NATIVE_LIMIT if pin[2] else LIMIT),
                "unsafe declared selection pin")
        if name in {"dockerfile", "base", "core"}:
            continue  # Current desired attachment drift is not private-selection drift.
        if name in {"compose", "buildx", "launcher", "config"}:
            exact_private(selected, 0o600 if name == "config" else 0o500)
        inputs.read(selected, native=name in {"compose", "buildx"})
        require(inputs.files[selected] == pin, "private selection replaced")
    require(decode(inputs.read(paths["config"])) == {"cliPluginsExtraDirs": [str(path.parent / "plugins")]},
            "foreign plugin discovery configuration")
    require(inputs.read(paths["launcher"]) == launcher_bytes(path, paths, value["pins"]),
            "foreign private launcher")
    return value


def validate_selection(environment):
    """Read-only private selection guard; no daemon, producer or desired-core check."""
    inputs = Inputs()
    value = binding(inputs, environment)
    inputs.recheck()
    return value


def active_run(inputs, value, environment):
    path, root = Path(value["record"]), Path(value["source"])
    data = decode(inputs.read(path))
    require(data == read_record(path, root), "inventory changed")
    require(data.get("variant", "base") == "base" and data["armed"]
            and data["outcome"] == data["test"] == "pending" and data["exit"] is None
            and data["stage"] in {"build", "up", "recreate", "verify"}
            and data.get("producer") is not None, "inactive or legacy producer")
    require(environment.get("DOCKER_HOST") == ENDPOINT, "nonlocal endpoint")
    owner = Run(path, data, Docker(Path(data["scratch"]) / "home"), None)
    owner.check_daemon()  # Existing local-daemon primitive; never executed by unit tests.
    require(owner.check_scratch() is not None, "missing scratch")
    scratch = Path(data["scratch"])
    require(environment.get("HOME") == str(scratch / "home"), "foreign run home")
    inputs.read(scratch / ".starter-test-owner")
    lock = path.with_suffix(".lock")
    private(lock)
    inputs.read(lock)
    descriptor = os.open(lock, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            pass
        else:
            raise Unsafe("producer has no active ownership lease")
    finally:
        os.close(descriptor)
    require(producer_identity(data["worker"]) == data["producer"], "producer replaced")
    return data


def ancestry(data):
    pid = os.getppid()
    chain = []
    for _ in range(64):
        anchor, parent, _ = process_status(pid)
        require(anchor["session"] == data["worker"], "foreign producer session")
        chain.append((anchor, parent))
        if pid == data["worker"]:
            require(anchor == data["producer"], "producer ancestry replaced")
            return chain
        require(parent > 1 and parent != pid, "unrelated producer parent")
        pid = parent
    raise Unsafe("producer ancestry exceeds bound")


def compose_process():
    parent = Path(f"/proc/{os.getppid()}")
    with (parent / "cmdline").open("rb") as stream:
        raw = stream.read(LIMIT + 1)
    require(len(raw) <= LIMIT, "parent argv exceeds bound")
    return Path(os.readlink(parent / "exe")), raw


def compose_override(inputs, value, data, generated):
    executable, raw = compose_process()
    require(executable == Path(value["native"]["compose"]), "parent is not pinned Compose")
    argv = [part.decode() for part in raw.rstrip(b"\0").split(b"\0")]
    # Docker CLI PluginRunCommand preserves the original "compose" token;
    # direct Compose execution has no token in the kernel's original cmdline.
    if argv[1:2] == ["compose"]:
        argv = [argv[0], *argv[2:]]
    context = Path(data["scratch"]) / ("starter-lifecycle-" + data["run"]) / ".devcontainer"
    base, core = context / "docker-compose.yml", context / "config/compose/docker-compose-core-tools.yml"
    require(len(argv) in {10, 11} and argv[1:7] == ["--project-name", data["project"], "-f", str(base), "-f", str(core)]
            and argv[7] == "-f" and argv[9:] in (["build"], ["build", "container-svc"]), "unsupported Compose parent argv")
    override = Path(argv[8])
    root = generated_directory(generated)
    require(override.parent == root / "docker-compose"
            and re.fullmatch(r"docker-compose\.devcontainer\.build-[0-9]+\.yml", override.name), "foreign generated override")
    metadata = override.parent.lstat()
    require(override.parent.resolve() == override.parent and stat.S_ISDIR(metadata.st_mode)
            and metadata.st_uid == os.getuid() and not metadata.st_mode & 0o022, "unsafe generated override directory")
    expected = ("services:\n  container-svc:\n    build:\n      dockerfile: " + str(generated)
                + "\n      args:\n        - BUILDKIT_INLINE_CACHE=1\n        - _DEV_CONTAINERS_BASE_IMAGE=devcontainer\n\n")
    require(inputs.read(override) == expected.encode(), "unsupported build override")
    started = producer_started_ns(data["producer"])
    for path in (override, generated):
        metadata = path.lstat()
        require(metadata.st_mtime_ns >= started and metadata.st_ctime_ns >= started, "stale generated producer input")
    for path in (base, core, context / "Dockerfile"):
        inputs.read(path)
        pin = value["pins"].get(str(path))
        current = inputs.files[path]
        # Attachment fixtures restore core bytes between scenarios. Preserve the
        # startup bytes/owner/mode contract, then pin full identity per invocation.
        require(isinstance(pin, list) and len(pin) == 3 and current[1:] == pin[1:]
                and current[0][2:5] == pin[0][2:5], "candidate input changed")
    return raw


def generated_root():
    return Path("/tmp/devcontainercli-" + pwd.getpwuid(os.getuid()).pw_name)


def producer_started_ns(anchor):
    # Both kernel process start ticks and CLOCK_BOOTTIME include suspend time.
    return (time.time_ns() - time.clock_gettime_ns(time.CLOCK_BOOTTIME)
            + anchor["start"] * 1000000000 // os.sysconf("SC_CLK_TCK"))


def generated_directory(generated):
    root = generated_root()
    require(generated.is_absolute() and generated.parent.parent == root / "container-features"
            and re.fullmatch(r"0\.89\.0-[0-9]+", generated.parent.name)
            and generated.name == "Dockerfile-with-features", "foreign generated directory")
    for directory in (root, root / "container-features", generated.parent):
        metadata = directory.lstat()
        require(directory.resolve() == directory and stat.S_ISDIR(metadata.st_mode)
                and metadata.st_uid == os.getuid() and not metadata.st_mode & 0o022, "unsafe generated directory")
    return root


def bake_argv(inputs, data, args):
    context = Path(data["scratch"]) / ("starter-lifecycle-" + data["run"]) / ".devcontainer"
    # Compose 5.5.1 bakeArgs emits this exact order for the reduced base build.
    require(len(args) == 9 and args[:6] == ["bake", "--file", "-", "--progress", "rawjson", "--metadata-file"]
            and args[7:] == ["--allow", "fs.read=" + str(context)], "unsupported Bake argv or permissions")
    metadata = Path(args[6])
    match = re.fullmatch(r"compose-build-metadataFile-([0-9a-f-]{36})\.json", metadata.name)
    require(metadata.parent == METADATA_DIRECTORY and match is not None, "foreign Bake metadata output")
    assert match is not None
    token = uuid.UUID(match[1])
    require(str(token) == match[1] and token.version == 4 and token.variant == uuid.RFC_4122, "invalid metadata UUID")
    inputs.parents(metadata)
    try:
        metadata.lstat()
    except FileNotFoundError:
        return metadata
    raise Unsafe("Bake metadata output already exists")


def bake_input(inputs, data, payload, args):
    context = Path(data["scratch"]) / ("starter-lifecycle-" + data["run"]) / ".devcontainer"
    bake_argv(inputs, data, args)
    document = decode(payload)
    require(isinstance(document, dict) and set(document) == {"group", "target"}
            and document["group"] == {"default": {"targets": ["container-svc"]}}
            and isinstance(document["target"], dict) and set(document["target"]) == {"container-svc"}, "unsupported Bake targets/groups")
    target = document["target"]["container-svc"]
    required = {"context", "dockerfile", "args", "labels", "tags", "output"}
    require(isinstance(target, dict) and set(target) in (required, required | {"target"}), "unsupported Bake fields")
    require(target["output"] == ["type=docker"]
            and ("target" not in target or target["target"] == "dev_containers_target_stage"), "unsupported Bake output/stage")
    require(target["context"] == str(context) and target["tags"] == [data["tag"]]
            and target["labels"] == {LABEL: data["run"], "com.docker.compose.project": data["project"],
                                     "com.docker.compose.service": "container-svc", "com.docker.compose.version": "5.5.1"},
            "foreign Bake context/image/labels")
    require(target["args"] == {"APP_NAME": context.parent.name, "LOCALE": "en_GB.UTF-8", "TZ": "Europe/Madrid",
                               "BUILDKIT_INLINE_CACHE": "1", "_DEV_CONTAINERS_BASE_IMAGE": "devcontainer"}, "unsupported Bake build arguments")
    generated = Path(target["dockerfile"])
    generated_directory(generated)  # Reject arbitrary paths before any file read.
    base = inputs.read(context / "Dockerfile")
    require(base and base.endswith(b"\n") and base.count(b"_DEV_CONTAINERS_BASE_IMAGE") == 0
            and re.findall(rb"(?im)^FROM\s+[^\r\n]+\s+AS\s+(\S+)\s*$", base)[-1:] == [b"devcontainer"], "unsupported base stage")
    generated_bytes = inputs.read(generated)
    require(generated_bytes == PREFIX + base + SUFFIX and generated_bytes.count(base) == 1,
            "unsupported generated Dockerfile layout")
    return generated


def delegate(argv, environment, stream):
    inputs = Inputs()
    value = binding(inputs, environment)
    native = value["native"]["buildx"]
    args = argv[1:] if argv[:1] == ["buildx"] else argv
    if args[:1] != ["bake"]:
        inputs.recheck()
        os.execvpe(native, [native, *argv], environment)
        return
    require(bool(environment.get("DOCKER_CLI_PLUGIN_ORIGINAL_CLI_COMMAND")) == (argv[:1] == ["buildx"]),
            "unsupported Buildx standalone/plugin prefix")
    require(environment.get("DOCKER_CONTEXT") in (None, "", "default")
            and not any(environment.get(key) for key in ("DOCKER_TLS", "DOCKER_TLS_VERIFY", "DOCKER_CERT_PATH")),
            "unsupported native endpoint override")
    data = active_run(inputs, value, environment)
    chain = ancestry(data)
    payload = stream.read(LIMIT + 1)
    generated = bake_input(inputs, data, payload, args)
    parent_argv = compose_override(inputs, value, data, generated)
    # TemporaryFile is an unlinked local descriptor; no native stdin/path reread.
    with tempfile.TemporaryFile() as frozen:
        frozen.write(payload)
        frozen.seek(0)
        require(active_run(inputs, value, environment) == data and ancestry(data) == chain, "producer changed before exec")
        require(compose_override(inputs, value, data, generated) == parent_argv, "parent argv changed")
        inputs.recheck()
        require(read_record(Path(value["record"]), Path(value["source"])) == data
                and producer_identity(data["worker"]) == data["producer"] and ancestry(data) == chain,
                "producer or inventory changed immediately before exec")
        bake_argv(inputs, data, args)  # The native metadata output must still be absent.
        os.dup2(frozen.fileno(), 0)
        os.execvpe(native, [native, *argv, "--allow", "fs.read=" + str(generated)], environment)


def main():
    try:
        delegate(sys.argv[1:], dict(os.environ), sys.stdin.buffer)
    except (Unsafe, OSError, ValueError, TypeError, KeyError, UnicodeError) as error:
        print("Generated Dockerfile adapter refused: " + (str(error) if isinstance(error, Unsafe) else "unverifiable input"), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
