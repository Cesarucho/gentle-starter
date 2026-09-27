#!/usr/bin/env python3
"""Capture and compare deterministic metadata for a Git-tracked path manifest."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import sys


def read_manifest(path: Path) -> list[tuple[str, bytes]]:
    entries = []
    for entry in path.read_bytes().split(b"\0"):
        if not entry:
            continue
        metadata, tracked_path = entry.split(b"\t", 1)
        mode = metadata.split(b" ", 1)[0].decode("ascii")
        entries.append((mode, tracked_path))
    return entries


def display_path(path: bytes) -> str:
    return path.decode("utf-8", "backslashreplace").encode("unicode_escape").decode("ascii")


def capture(manifest: Path, root: Path, output: Path) -> None:
    records = []
    root_bytes = os.fsencode(root)
    for index_mode, tracked_path in read_manifest(manifest):
        full_path = os.path.join(root_bytes, tracked_path)
        record = {"path": display_path(tracked_path), "index_mode": index_mode}
        try:
            metadata = os.lstat(full_path)
        except FileNotFoundError:
            record["type"] = "missing"
        else:
            if stat.S_ISREG(metadata.st_mode):
                record["type"] = "file"
                record["worktree_mode"] = "100755" if metadata.st_mode & stat.S_IXUSR else "100644"
                with open(full_path, "rb") as tracked_file:
                    record["sha256"] = hashlib.file_digest(tracked_file, "sha256").hexdigest()
            elif stat.S_ISLNK(metadata.st_mode):
                record["type"] = "symlink"
                record["target"] = os.fsdecode(os.readlink(full_path))
            else:
                record["type"] = "other"
                record["worktree_mode"] = format(stat.S_IMODE(metadata.st_mode), "04o")
        records.append(record)
    output.write_text("".join(json.dumps(record, sort_keys=True) + "\n" for record in records))


def compare(before: Path, after: Path, limit: int) -> int:
    before_records = {record["path"]: record for record in map(json.loads, before.read_text().splitlines())}
    after_records = {record["path"]: record for record in map(json.loads, after.read_text().splitlines())}
    changed = sorted(
        path for path in before_records.keys() | after_records.keys()
        if before_records.get(path) != after_records.get(path)
    )
    for path in changed[:limit]:
        print(f"[starter-lifecycle:error] changed tracked path: {path}", file=sys.stderr)
    if len(changed) > limit:
        print(f"[starter-lifecycle:error] {len(changed) - limit} additional changed tracked path(s) omitted", file=sys.stderr)
    return bool(changed)


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    capture_parser = subparsers.add_parser("capture")
    capture_parser.add_argument("manifest", type=Path)
    capture_parser.add_argument("root", type=Path)
    capture_parser.add_argument("output", type=Path)
    compare_parser = subparsers.add_parser("compare")
    compare_parser.add_argument("before", type=Path)
    compare_parser.add_argument("after", type=Path)
    compare_parser.add_argument("--limit", type=int, default=20)
    args = parser.parse_args()
    if args.command == "capture":
        capture(args.manifest, args.root, args.output)
        return 0
    return compare(args.before, args.after, args.limit)


if __name__ == "__main__":
    raise SystemExit(main())
