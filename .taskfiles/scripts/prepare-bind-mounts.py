#!/usr/bin/env python3
import json
import os
import stat
import sys


CREATED_MODE = 0o755


def managed_bind_sources(volumes, workspace):
    managed_root = os.path.normpath(os.path.abspath(os.path.join(workspace, ".env.d")))
    for volume in volumes:
        if not isinstance(volume, dict):
            continue
        source = volume.get("source", "")
        bind = volume.get("bind")
        if (
            volume.get("type") != "bind"
            or not isinstance(source, str)
            or not isinstance(bind, dict)
            or bind.get("create_host_path") is not False
            or not source
            or "$" in source
            or os.path.isabs(source)
            or "\0" in source
        ):
            print(f"[bind-prep] externally managed: {source}")
            continue

        candidate = os.path.normpath(
            os.path.abspath(os.path.join(workspace, ".devcontainer", source))
        )
        try:
            contained = os.path.commonpath((managed_root, candidate)) == managed_root
        except ValueError:
            contained = False
        if contained:
            yield candidate
        else:
            print(f"[bind-prep] externally managed: {source}")


def required_components(paths, workspace):
    components = set()
    for managed_path in paths:
        relative = os.path.relpath(managed_path, workspace)
        current = workspace
        for part in relative.split(os.sep):
            current = os.path.join(current, part)
            components.add(current)
    return sorted(components, key=lambda item: (item.count(os.sep), item))


def prepare_directory(path, expected_owner):
    created = False
    try:
        before = os.lstat(path)
    except FileNotFoundError:
        try:
            os.mkdir(path, CREATED_MODE)
        except OSError as error:
            raise SystemExit(f"[bind-prep:error] could not create {path}: {error}")
        before = os.lstat(path)
        created = True

    if stat.S_ISLNK(before.st_mode):
        raise SystemExit(f"[bind-prep:error] managed path is a symlink: {path}")
    if not stat.S_ISDIR(before.st_mode):
        raise SystemExit(f"[bind-prep:error] managed path is not a directory: {path}")
    if created:
        set_exact_created_mode(path)
        before = os.lstat(path)
    if (before.st_uid, before.st_gid) != expected_owner:
        uid, gid = expected_owner
        raise SystemExit(
            f"[bind-prep:error] managed directory has wrong owner: {path}; "
            f"remediate this exact path only: sudo chown {uid}:{gid} '{path}'"
        )
    if created and stat.S_IMODE(before.st_mode) != CREATED_MODE:
        raise SystemExit(f"[bind-prep:error] managed directory mode verification failed: {path}")

    after = os.lstat(path)
    identity = lambda value: (value.st_dev, value.st_ino, value.st_mode, value.st_uid, value.st_gid)
    if identity(before) != identity(after):
        raise SystemExit(f"[bind-prep:error] managed directory changed during verification: {path}")


def set_exact_created_mode(path):
    descriptor = None
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        os.fchmod(descriptor, CREATED_MODE)
    except OSError as error:
        raise SystemExit(f"[bind-prep:error] could not set exact mode on {path}: {error}")
    finally:
        if descriptor is not None:
            os.close(descriptor)


def main():
    workspace = os.path.normpath(os.path.abspath(sys.argv[1]))
    expected_owner = (int(sys.argv[2]), int(sys.argv[3]))
    try:
        volumes = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise SystemExit(f"[bind-prep:error] invalid Compose volume JSON: {error}")
    if not isinstance(volumes, list):
        raise SystemExit("[bind-prep:error] Compose volumes must be a JSON array")

    paths = set(managed_bind_sources(volumes, workspace))
    for path in required_components(paths, workspace):
        prepare_directory(path, expected_owner)


if __name__ == "__main__":
    main()
