#!/usr/bin/env python3
"""Safely compare and export selected runtime configuration files."""

from __future__ import annotations

import argparse
import json
import os
import stat
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath
from typing import Iterator


EXIT_DIFFERENT = 1
EXIT_ERROR = 2
MAX_REPORTED_CANDIDATES = 50


class ConfigError(Exception):
    """An invalid manifest, unsafe path, or I/O failure."""


@dataclass(frozen=True)
class Tree:
    name: str
    runtime: Path
    seed: Path
    managed: tuple[str, ...]
    excluded: tuple[str, ...]


@dataclass
class Report:
    tree_name: str
    unchanged: list[str] = field(default_factory=list)
    modified: list[str] = field(default_factory=list)
    new: list[str] = field(default_factory=list)
    missing_runtime: list[str] = field(default_factory=list)
    candidates: list[tuple[str, str]] = field(default_factory=list)
    candidate_count: int = 0
    excluded_files: int = 0
    excluded_directories: int = 0

    def differs(self) -> bool:
        return bool(self.modified or self.new or self.missing_runtime or self.candidate_count)

    def add_candidate(self, path: str, path_type: str) -> None:
        self.candidate_count += 1
        if len(self.candidates) < MAX_REPORTED_CANDIDATES:
            self.candidates.append((path, path_type))


@dataclass(frozen=True)
class PlannedCopy:
    tree_name: str
    source: Path
    destination: Path
    seed_root: Path


def safe_relative(value: object, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise ConfigError(f"{label} must be a non-empty relative path")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or "\\" in value:
        raise ConfigError(f"unsafe {label}: {value}")
    return value


def pattern_matches(path: str, pattern: str) -> bool:
    if pattern.endswith("/**"):
        prefix = pattern[:-3].rstrip("/")
        return path == prefix or path.startswith(prefix + "/")
    return PurePosixPath(path).match(pattern)


def classification(relative: str, tree: Tree) -> str:
    if any(pattern_matches(relative, pattern) for pattern in tree.excluded):
        return "excluded"
    if any(pattern_matches(relative, pattern) for pattern in tree.managed):
        return "managed"
    return "candidate"


def is_manifest_container(relative: str, tree: Tree) -> bool:
    prefix = relative + "/"
    return any(pattern.startswith(prefix) for pattern in tree.managed + tree.excluded)


def validate_component_chain(path: Path, stop: Path, label: str) -> None:
    try:
        relative = path.relative_to(stop)
    except ValueError as error:
        raise ConfigError(f"{label} escapes its root: {path}") from error
    current = stop
    for part in relative.parts:
        current /= part
        try:
            mode = current.lstat().st_mode
        except FileNotFoundError:
            return
        if stat.S_ISLNK(mode):
            raise ConfigError(f"symlink is not allowed in {label}: {current}")


def validate_root(path: Path, anchor: Path, label: str) -> None:
    validate_component_chain(path, anchor, label)
    if path.exists() and not path.is_dir():
        raise ConfigError(f"{label} is not a directory: {path}")


def walk_tree(root: Path, tree: Tree, report: Report) -> Iterator[tuple[str, Path, str]]:
    if not root.exists():
        return
    pending = [root]
    while pending:
        directory = pending.pop()
        try:
            entries = sorted(os.scandir(directory), key=lambda entry: entry.name, reverse=True)
        except OSError as error:
            raise ConfigError(f"cannot read directory {directory}: {error}") from error
        for entry in entries:
            path = Path(entry.path)
            relative = path.relative_to(root).as_posix()
            kind = classification(relative, tree)
            if kind == "excluded":
                if entry.is_dir(follow_symlinks=False):
                    report.excluded_directories += 1
                else:
                    report.excluded_files += 1
                continue
            if entry.is_symlink():
                raise ConfigError(f"symlink is not allowed in {tree.name}: {relative}")
            if entry.is_dir(follow_symlinks=False):
                if kind == "candidate" and not is_manifest_container(relative, tree):
                    report.add_candidate(relative, "directory")
                    continue
                pending.append(path)
                continue
            if not entry.is_file(follow_symlinks=False):
                raise ConfigError(f"non-regular file is not allowed in {tree.name}: {relative}")
            yield relative, path, kind


def files_equal(source: Path, destination: Path) -> bool:
    try:
        if source.stat().st_size != destination.stat().st_size:
            return False
        with source.open("rb") as left, destination.open("rb") as right:
            while True:
                left_chunk = left.read(65536)
                right_chunk = right.read(65536)
                if left_chunk != right_chunk:
                    return False
                if not left_chunk:
                    return True
    except OSError as error:
        raise ConfigError(f"cannot compare {source} and {destination}: {error}") from error


def inspect_tree(tree: Tree, home: Path, repo: Path) -> tuple[Report, list[PlannedCopy]]:
    report = Report(tree.name)
    runtime_files: dict[str, Path] = {}
    seed_files: dict[str, Path] = {}
    validate_root(tree.runtime, home, f"{tree.name} runtime root")
    validate_root(tree.seed, repo, f"{tree.name} seed root")

    for relative, path, kind in walk_tree(tree.runtime, tree, report):
        if kind == "candidate":
            report.add_candidate(relative, "file")
        else:
            runtime_files[relative] = path
    for relative, path, kind in walk_tree(tree.seed, tree, report):
        if kind == "managed":
            seed_files[relative] = path

    copies: list[PlannedCopy] = []
    for relative in sorted(runtime_files.keys() | seed_files.keys()):
        source = runtime_files.get(relative)
        destination = seed_files.get(relative)
        display = f"{tree.name}: {relative}"
        if source is None:
            report.missing_runtime.append(display)
        elif destination is None:
            report.new.append(display)
            copies.append(PlannedCopy(tree.name, source, tree.seed / relative, tree.seed))
        elif files_equal(source, destination):
            report.unchanged.append(display)
        else:
            report.modified.append(display)
            copies.append(PlannedCopy(tree.name, source, destination, tree.seed))
    return report, copies


def validate_destination_plan(copies: list[PlannedCopy]) -> None:
    destinations: dict[Path, PlannedCopy] = {}
    for copy in copies:
        if copy.destination in destinations:
            raise ConfigError(f"destination collision: {copy.destination}")
        destinations[copy.destination] = copy

    for copy in copies:
        validate_destination(copy)
        parent = copy.destination.parent
        while parent != copy.seed_root:
            if parent in destinations:
                raise ConfigError(f"planned destination blocks directory creation: {parent}")
            parent = parent.parent


def validate_destination(copy: PlannedCopy) -> None:
    try:
        relative = copy.destination.relative_to(copy.seed_root)
    except ValueError as error:
        raise ConfigError(f"destination escapes seed root: {copy.destination}") from error

    current = copy.seed_root
    for part in relative.parts[:-1]:
        current /= part
        try:
            mode = current.lstat().st_mode
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(mode) or not stat.S_ISDIR(mode):
            raise ConfigError(f"destination ancestor is not a real directory: {current}")

    try:
        destination_mode = copy.destination.lstat().st_mode
    except FileNotFoundError:
        return
    if stat.S_ISLNK(destination_mode) or not stat.S_ISREG(destination_mode):
        raise ConfigError(f"destination is not a regular non-symlink file: {copy.destination}")


def parse_manifest(path: Path, home: Path, repo: Path) -> list[Tree]:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ConfigError(f"cannot read manifest {path}: {error}") from error
    if not isinstance(document, dict) or document.get("version") != 1:
        raise ConfigError("manifest version must be 1")
    raw_trees = document.get("trees")
    if not isinstance(raw_trees, list) or not raw_trees:
        raise ConfigError("manifest trees must be a non-empty list")
    trees = []
    for index, raw in enumerate(raw_trees):
        if not isinstance(raw, dict):
            raise ConfigError(f"tree {index} must be an object")
        name = raw.get("name")
        if not isinstance(name, str) or not name:
            raise ConfigError(f"tree {index} has an invalid name")
        runtime = safe_relative(raw.get("runtime"), f"{name} runtime")
        seed = safe_relative(raw.get("seed"), f"{name} seed")
        managed = raw.get("managed")
        excluded = raw.get("excluded")
        if not isinstance(managed, list) or not isinstance(excluded, list):
            raise ConfigError(f"{name} managed and excluded values must be lists")
        safe_managed = tuple(safe_relative(value, f"{name} managed pattern") for value in managed)
        safe_excluded = tuple(safe_relative(value, f"{name} excluded pattern") for value in excluded)
        trees.append(Tree(name, home / runtime, repo / seed, safe_managed, safe_excluded))
    return trees


def seed_is_dirty(repo: Path, trees: list[Tree]) -> bool:
    paths = [str(tree.seed.relative_to(repo)) for tree in trees]
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), "status", "--porcelain=v1", "-z", "--", *paths],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except OSError as error:
        raise ConfigError(f"cannot run Git dirty check: {error}") from error
    if result.returncode != 0:
        message = result.stderr.decode("utf-8", errors="replace").strip()
        raise ConfigError(f"Git dirty check failed: {message}")
    return bool(result.stdout)


def atomic_copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(destination.stat().st_mode) if destination.exists() else 0o644
    temporary_name: str | None = None
    try:
        source_descriptor = os.open(source, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        with os.fdopen(source_descriptor, "rb") as source_file:
            if not stat.S_ISREG(os.fstat(source_file.fileno()).st_mode):
                raise ConfigError(f"source is no longer a regular file: {source}")
            with tempfile.NamedTemporaryFile(dir=destination.parent, prefix=".config-export-", delete=False) as temporary:
                temporary_name = temporary.name
                while chunk := source_file.read(65536):
                    temporary.write(chunk)
                temporary.flush()
                os.fsync(temporary.fileno())
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, destination)
        temporary_name = None
    except OSError as error:
        raise ConfigError(f"cannot export {source} to {destination}: {error}") from error
    finally:
        if temporary_name:
            try:
                os.unlink(temporary_name)
            except FileNotFoundError:
                pass


def print_report(reports: list[Report]) -> None:
    labels = (
        ("modified", "modified"),
        ("new", "new"),
        ("missing-runtime", "missing_runtime"),
    )
    for label, attribute in labels:
        for item in (entry for report in reports for entry in getattr(report, attribute)):
            print(f"{label}: {item}")
    for report in reports:
        for path, path_type in report.candidates:
            print(f"candidate: {report.tree_name}: {path} ({path_type})")
    totals = {field: sum(len(getattr(report, field)) for report in reports) for field in ("unchanged", "modified", "new", "missing_runtime")}
    totals["candidates"] = sum(report.candidate_count for report in reports)
    excluded_files = sum(report.excluded_files for report in reports)
    excluded_directories = sum(report.excluded_directories for report in reports)
    print(
        "Summary: "
        f"unchanged={totals['unchanged']} modified={totals['modified']} new={totals['new']} "
        f"missing-runtime={totals['missing_runtime']} candidates={totals['candidates']} "
        f"excluded-files={excluded_files} excluded-directories={excluded_directories}"
    )
    if totals["candidates"] > sum(len(report.candidates) for report in reports):
        print(f"Candidate output limited to {MAX_REPORTED_CANDIDATES} paths per tree")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("diff", "export"))
    parser.add_argument("--repo", type=Path)
    parser.add_argument("--home", type=Path)
    parser.add_argument("--manifest", type=Path)
    arguments = parser.parse_args()
    repo = (arguments.repo or Path(__file__).resolve().parents[2]).resolve()
    home = (arguments.home or Path.home()).resolve()
    manifest = arguments.manifest or repo / ".devcontainer/config-export.json"

    try:
        trees = parse_manifest(manifest, home, repo)
        if arguments.command == "export" and seed_is_dirty(repo, trees):
            raise ConfigError("export refused: a seed tree has pending Git worktree or index changes")
        inspected = [inspect_tree(tree, home, repo) for tree in trees]
        reports = [item[0] for item in inspected]
        copies = [copy for item in inspected for copy in item[1]]
        if arguments.command == "export":
            validate_destination_plan(copies)
        print_report(reports)
        if arguments.command == "diff":
            return EXIT_DIFFERENT if any(report.differs() for report in reports) else 0
        for copy in copies:
            atomic_copy(copy.source, copy.destination)
        print(f"Exported: files={len(copies)}")
        print("Review: git diff -- .devcontainer/opencode-config .devcontainer/pi-config")
        return 0
    except ConfigError as error:
        print(f"config-export: error: {error}", file=sys.stderr)
        return EXIT_ERROR
    except (OSError, ValueError) as error:
        print(f"config-export: error: {error}", file=sys.stderr)
        return EXIT_ERROR


if __name__ == "__main__":
    sys.exit(main())
