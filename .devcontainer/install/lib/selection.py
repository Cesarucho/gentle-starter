#!/usr/bin/env python3
"""Validate and change installer selection without executing any installer."""

import fcntl
import os
from pathlib import Path
import re
import shlex
import signal
import sys
import time
from contextlib import contextmanager


GROUPS = ("02-core-tools", "03-enabled")
CATALOG_NAME = re.compile(r"[0-9]{4}-[a-z0-9]+-[a-z0-9]+(?:-[a-z0-9]+)*\.sh\Z")
ALIAS_NAME = re.compile(r"[0-9]+-[a-z0-9]+(?:-[a-z0-9]+)*\.sh\Z")


class InvalidSelection(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise InvalidSelection(message)


@contextmanager
def selection_lock(install):
    # Lock the stable directory inode, not a removable lockfile. Both mutations
    # hold this same lock from inspection through rollback; no stale lock cleanup.
    fd = os.open(install, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        deadline = time.monotonic() + 10
        while True:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                require(time.monotonic() < deadline, "installer selection is locked; retry later")
                time.sleep(0.05)
        yield
    finally:
        os.close(fd)


def read_catalog(install):
    catalog = {}
    prefixes = set()
    for path in sorted((install / "available").iterdir()):
        require(CATALOG_NAME.fullmatch(path.name), f"invalid BBPP-category-tool.sh name: {path.name}")
        require(path.is_file() and not path.is_symlink(), f"unsafe catalog installer: {path.name}")
        prefix = path.name[:4]
        require(prefix not in prefixes, f"duplicate catalog prefix: {prefix}")
        prefixes.add(prefix)
        catalog[path.name] = path
    return catalog


def read_selection(install, catalog):
    selection = {}
    for group in GROUPS:
        prefixes = set()
        for link in sorted((install / group).iterdir()):
            if link.name == ".gitkeep" and link.is_file() and not link.is_symlink():
                continue
            require(ALIAS_NAME.fullmatch(link.name), f"invalid alias filename: {group}/{link.name}")
            require(link.is_symlink() and link.is_file(), f"invalid or broken symlink {group}/{link.name}")
            target = link.resolve(strict=True)
            require(target.parent == install / "available" and target.name in catalog,
                    f"{group}/{link.name} must target an available shell installer")
            require(link.name not in catalog or link.name == target.name,
                    f"alias collision with catalog identity: {group}/{link.name}")
            require(target.name not in selection, f"duplicate installer: {target.name}")
            prefix = link.name.split("-", 1)[0]
            require(prefix not in prefixes, f"duplicate alias prefix: {group}/{prefix}")
            prefixes.add(prefix)
            selection[target.name] = f"{group}/{link.name}"
    return selection


def validate_core(install, catalog, selection):
    dockerfile = install.parent / "Dockerfile"
    require(dockerfile.is_file() and not dockerfile.is_symlink(), "missing or unsafe Dockerfile core authority")
    text = dockerfile.read_text().replace("\\\n", " ")
    sources = set()
    in_core = False
    found_core = False
    for line in text.splitlines():
        words = shlex.split(line, comments=True)
        if not words:
            continue
        if words[0].upper() == "FROM":
            in_core = len(words) >= 4 and words[-2].upper() == "AS" and words[-1] == "core-tools"
            found_core |= in_core
        elif in_core and words[0].upper() == "COPY":
            for source in words[1:-1]:
                if source.startswith("install/available/"):
                    name = source.removeprefix("install/available/")
                    require(name in catalog, f"invalid selective core COPY input: {source}")
                    require(name not in sources, f"duplicate core COPY input: {source}")
                    sources.add(name)
    require(found_core, "Dockerfile core-tools stage missing")
    active_core = {name for name, alias in selection.items() if alias.startswith("02-core-tools/")}
    require(sources == active_core,
            "mandatory core aliases and selective Dockerfile COPY inputs disagree: "
            + ", ".join(sorted(sources ^ active_core)))


def read_graph(install, catalog, selection):
    graph = {name: [] for name in catalog}
    edges = set()
    dependencies = install / "dependencies.conf"
    require(dependencies.is_file() and not dependencies.is_symlink(), "missing or unsafe dependencies.conf")
    for number, line in enumerate(dependencies.read_text().splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split("|")
        require(len(fields) == 4 and all(fields), f"invalid dependency record at line {number}")
        consumer, kind, dependency, command = fields
        require(consumer in catalog, f"unknown graph consumer: {consumer}")
        require(re.fullmatch(r"[a-zA-Z0-9_.+-]+", command), f"invalid dependency command: {command}")
        edge = (consumer, kind, dependency)
        require(edge not in edges, f"duplicate dependency record: {line}")
        edges.add(edge)
        require(kind in ("enabled", "companion", "image"), f"unknown dependency kind: {kind}")
        if kind == "image":
            parts = dependency.split("/")
            require(len(parts) == 2 and parts[0] in ("01-foundation", "02-core-tools")
                    and ALIAS_NAME.fullmatch(parts[1]), f"unsafe image dependency: {dependency}")
            path = install / dependency
            if parts[0] == "01-foundation":
                require(path.is_file() and not path.is_symlink(), f"missing or unsafe image dependency: {dependency}")
            else:
                require(dependency in selection.values(), f"missing core image dependency: {dependency}")
            if consumer in selection:
                require(dependency < selection[consumer], f"image dependency must run before {consumer}")
        else:
            require(dependency in catalog, f"unknown graph dependency: {dependency}")
            if kind == "enabled":
                graph[consumer].append(dependency)
    validate_acyclic(graph)
    return graph


def validate_acyclic(graph):
    visiting, visited = set(), set()

    def visit(node):
        require(node not in visiting, f"dependency cycle at {node}")
        if node in visited:
            return
        visiting.add(node)
        for dependency in graph[node]:
            visit(dependency)
        visiting.remove(node)
        visited.add(node)

    for node in graph:
        visit(node)


def validate_order(selection, graph):
    prefixes = set()
    aliases = set()
    for consumer, alias in selection.items():
        require(alias not in aliases, f"alias collision: {alias}")
        aliases.add(alias)
        group, name = alias.split("/")
        prefix = (group, name.split("-", 1)[0])
        require(prefix not in prefixes, f"duplicate alias prefix: {group}/{prefix[1]}")
        prefixes.add(prefix)
        for dependency in graph[consumer]:
            require(dependency in selection, f"{consumer} requires enabled installer {dependency}")
            require(selection[dependency] < alias,
                    f"{dependency} must run before {consumer} ({selection[dependency]} sorts after {alias})")


def plan_enable(wanted, selection, graph):
    projected = dict(selection)
    visited = set()

    def include(node):
        if node in visited:
            return
        visited.add(node)
        for dependency in graph[node]:
            include(dependency)
        projected.setdefault(node, f"03-enabled/{node}")

    include(wanted)
    validate_order(projected, graph)
    return sorted((alias, name) for name, alias in projected.items() if name not in selection)


def apply_enable(install, plan, catalog, graph):
    created = []
    try:
        for alias, name in plan:
            link = install / alias
            target = f"../available/{name}"
            # Never force replacement: EEXIST is a failure, including broken links.
            # Defer handled signals until ownership is recorded for rollback.
            previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGINT, signal.SIGTERM, signal.SIGHUP})
            try:
                link.symlink_to(target)
                identity = link.lstat()
                created.append((link, target, identity.st_dev, identity.st_ino))
            finally:
                signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        validate_order(read_selection(install, catalog), graph)
    except BaseException:
        for link, target, device, inode in reversed(created):
            try:
                current = link.lstat()
                if (current.st_dev, current.st_ino) == (device, inode) and link.is_symlink() and os.readlink(link) == target:
                    link.unlink()
            except FileNotFoundError:
                pass
        raise
    for alias, name in plan:
        print(f"Enabled: {alias} -> available/{name}")


def change_selection(install, operation, wanted):
    catalog = read_catalog(install)
    selection = read_selection(install, catalog)
    validate_core(install, catalog, selection)
    graph = read_graph(install, catalog, selection)
    if operation == "validate":
        validate_order(selection, graph)
        return
    require(wanted and "/" not in wanted and wanted not in (".", ".."), "NAME must be a filename, not a path")
    name = wanted if wanted.endswith(".sh") else wanted + ".sh"
    if operation == "disable" and name not in catalog:
        name = next((node for node, alias in selection.items() if alias.split("/")[1] == name), name)
    require(name in catalog, f"{wanted} not found under available/")
    require(not selection.get(name, "").startswith("02-core-tools/"), f"{name} belongs to mandatory 02-core-tools")
    if operation == "enable":
        plan = plan_enable(name, selection, graph)
        apply_enable(install, plan, catalog, graph)
        if not plan:
            print(f"{name} is already enabled")
    else:
        dependents = [node for node in selection if name in graph[node]]
        require(not dependents, f"cannot disable {name}; required by enabled installer(s): {', '.join(dependents)}")
        projected = {node: alias for node, alias in selection.items() if node != name}
        validate_order(projected, graph)
        if name in selection:
            (install / selection[name]).unlink()
            print(f"Disabled: {selection[name]}")
        else:
            print(f"{name} is not enabled")


def interrupted(signum, _frame):
    raise InterruptedError(f"selection interrupted by signal {signum}")


def main():
    install = Path(sys.argv[1]).absolute()
    for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(signum, interrupted)
    with selection_lock(install):
        for directory in (install.parent, install, install / "available", *(install / group for group in GROUPS), install / "01-foundation"):
            require(directory.is_dir() and not directory.is_symlink(), f"unsafe install directory: {directory}")
        change_selection(install, sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")


if __name__ == "__main__":
    try:
        main()
    except (InvalidSelection, OSError, RuntimeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
