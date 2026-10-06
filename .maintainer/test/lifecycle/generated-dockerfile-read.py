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


def find_native(name):
    for directory in NATIVE_DIRECTORIES:
        path = Path(directory) / name
        if path.exists():
            return path
    raise Unsafe("native plugin unavailable; no installation attempted")


def prepare(lifecycle):
    """Called only by a separately authorized opt-in run, after candidate labeling."""
    home = lifecycle.home
    private(home, directory=True)
    config = home / ".docker"
    config.mkdir(mode=0o700)
    private(config, directory=True)
    inputs = Inputs()
    native = {name: str(find_native("docker-" + name)) for name in ("buildx", "compose")}
    for path in native.values():
        inputs.read(path, native=True)
    context = lifecycle.candidate / ".devcontainer"
    for path in (context / "Dockerfile", context / "docker-compose.yml",
                 context / "config/compose/docker-compose-core-tools.yml"):
        inputs.read(path)
    binding = {"record": str(lifecycle.ownership.path), "source": str(lifecycle.root),
               "native": native, "pins": {str(path): value for path, value in inputs.files.items()}}
    binding_path = config / "generated-read.json"
    for path, value in ((binding_path, binding), (config / "config.json", {
            "cliPluginsExtraDirs": [str(Path(__file__).parent / "narrow-plugins")]})):
        with path.open("x") as stream:
            os.chmod(stream.fileno(), 0o600)
            json.dump(value, stream)
    lifecycle.env.update(DOCKER_CONFIG=str(config), HGDR_BINDING=str(binding_path))


def binding(inputs, environment):
    path = Path(environment.get("HGDR_BINDING", ""))
    require(path.is_absolute(), "missing adapter binding")
    private(path)
    private(path.parent, directory=True)
    require(path.parent == Path(environment.get("HOME", "")) / ".docker"
            and environment.get("DOCKER_CONFIG") == str(path.parent), "foreign Docker config")
    value = decode(inputs.read(path))
    require(isinstance(value, dict) and set(value) == {"record", "source", "native", "pins"}, "invalid binding")
    require(isinstance(value["native"], dict) and set(value["native"]) == {"buildx", "compose"}
            and isinstance(value["pins"], dict) and len(value["pins"]) == 5, "invalid native pins")
    for name in ("buildx", "compose"):
        native = Path(value["native"][name])
        require(native.name == "docker-" + name and str(native.parent) in NATIVE_DIRECTORIES, "foreign native plugin")
        inputs.read(native, native=True)
        require(inputs.files[native] == value["pins"].get(str(native)), "native plugin replaced")
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
