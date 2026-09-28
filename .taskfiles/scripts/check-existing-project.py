#!/usr/bin/env python3
"""Read-only host preflight for importing starter into an existing project."""

import argparse
import os
from pathlib import Path
import stat
import subprocess
import sys


COMPATIBLE = 0
MANUAL = 1
ERROR = 2
RESERVED_TREES = (".agents/skills/add-tool", ".devcontainer", ".taskfiles")
RESERVED_FILES = (".markdownlint-cli2.yaml", "Taskfile.yml")


def git(root, *args):
    environment = os.environ.copy()
    environment["GIT_OPTIONAL_LOCKS"] = "0"
    result = subprocess.run(
        ["git", "--no-optional-locks", "-c", "core.fsmonitor=false", "-C", str(root), *args],
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        raise ValueError(f"Git could not verify repository state ({' '.join(args)}): {result.stderr.decode(errors='replace').strip()}")
    return result.stdout


def validate_repository(root):
    if not root.is_absolute() or not root.is_dir() or root.is_symlink():
        raise ValueError("PROJECT must be an absolute, existing, non-symlink directory")
    if Path(os.fsdecode(git(root, "rev-parse", "--show-toplevel").strip())).resolve() != root.resolve():
        raise ValueError("PROJECT must be the Git repository root, not a subdirectory")
    if git(root, "rev-parse", "--is-bare-repository").strip() != b"false":
        raise ValueError("PROJECT must be a non-bare repository")
    git(root, "rev-parse", "--verify", "HEAD")
    for state in ("MERGE_HEAD", "REBASE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "BISECT_LOG", "BISECT_START"):
        path = Path(os.fsdecode(git(root, "rev-parse", "--git-path", state).strip()))
        if not path.is_absolute():
            path = root / path
        if path.exists() or path.is_symlink():
            raise ValueError(f"Git operation in progress: {state}")
    for state in ("rebase-merge", "rebase-apply", "sequencer"):
        path = Path(os.fsdecode(git(root, "rev-parse", "--git-path", state).strip()))
        if not path.is_absolute():
            path = root / path
        if path.exists() or path.is_symlink():
            raise ValueError(f"Git operation in progress: {state}")


def validate_clean_worktree(root):
    if git(root, "status", "--porcelain=v1", "-z", "--untracked-files=all"):
        raise ValueError("PROJECT has tracked or untracked changes; clean it before preflight")


def path_kind(path):
    try:
        mode = path.lstat().st_mode
    except FileNotFoundError:
        return "missing"
    if stat.S_ISLNK(mode):
        return "symlink"
    if stat.S_ISDIR(mode):
        return "directory"
    if stat.S_ISREG(mode):
        return "file"
    return "unusual path type"


def collisions(root):
    found = []
    for relative in (*RESERVED_TREES, *RESERVED_FILES):
        parts = Path(relative).parts
        for depth in range(1, len(parts) + 1):
            candidate = Path(*parts[:depth])
            kind = path_kind(root / candidate)
            if kind == "missing":
                break
            if depth == len(parts) or kind != "directory":
                found.append(f"{candidate} ({kind})")
                break
    return found


def tracked_collisions(root):
    found = []
    tracked_paths = git(root, "ls-files", "--cached", "-z").split(b"\0")
    for raw_path in tracked_paths:
        if not raw_path:
            continue
        path = os.fsdecode(raw_path)
        if any(path == tree or path.startswith(tree + "/") or tree.startswith(path + "/") for tree in RESERVED_TREES) or path in RESERVED_FILES:
            found.append(f"{path} (tracked)")
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", metavar="PROJECT", help="absolute path to an existing project Git root")
    args = parser.parse_args()
    root = Path(args.project)
    try:
        validate_repository(root)
        found = collisions(root) + tracked_collisions(root)
        if found:
            print("MANUAL INTEGRATION: reserved paths exist: " + ", ".join(found))
            return MANUAL
        validate_clean_worktree(root)
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return ERROR
    print("COMPATIBLE for a reviewed integration preflight only; this does not guarantee a conflict-free merge.")
    print("Preserve README.md, LICENSE, AGENTS.md, skills-lock.json, .env.example, and project skills; manually merge .gitignore.")
    print("No ancestry, remote, or merge result was verified. Review the two-parent merge yourself.")
    return COMPATIBLE


if __name__ == "__main__":
    sys.exit(main())
