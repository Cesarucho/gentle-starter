#!/usr/bin/env python3
"""Build or cancel a local, filtered starter release candidate."""

import argparse
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import sys


script = Path(__file__).with_name("starter-distribution.py")
spec = importlib.util.spec_from_file_location("starter_distribution", script)
assert spec is not None and spec.loader is not None
distribution = importlib.util.module_from_spec(spec)
spec.loader.exec_module(distribution)
git = distribution.git
require = distribution.require
branch = distribution.branch
exists = distribution.exists

SOURCE = "Starter-Candidate-Source: "
BASE = "Starter-Candidate-Base: "
SUBJECT = "Prepare starter release candidate"
ZERO = "0" * 40


def identity(commit):
    message = git("show", "-s", "--format=%B", commit)
    match = re.fullmatch(
        rf"{SUBJECT}\n\n{SOURCE}([0-9a-f]{{40,64}})\n{BASE}([0-9a-f]{{40,64}})\n?",
        message,
    )
    require(match is not None, "candidate ref has no verified identity")
    assert match is not None
    source, base = match.groups()
    parents = git("show", "-s", "--format=%P", commit).split()
    require(len(parents) <= 1, "candidate must have at most one candidate parent")
    require(git("cat-file", "-t", source) == "commit", "invalid candidate source")
    require(git("cat-file", "-t", base) == "commit", "invalid candidate base")
    require(git("rev-parse", f"{commit}^{{tree}}") == distribution.filtered_tree(source),
            "candidate tree does not match committed source")
    return source, base, parents


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="dev", help="committed local source branch")
    parser.add_argument("--target", default="starter-rc", help="local candidate branch")
    parser.add_argument("--base", default="starter", help="local release branch")
    parser.add_argument("--cancel", action="store_true", help="delete only a verified candidate")
    args = parser.parse_args()
    source_ref, target_ref, base_ref = map(branch, (args.source, args.target, args.base))
    require(len({source_ref, target_ref, base_ref}) == 3, "source, candidate and base must differ")
    require(git("rev-parse", "--show-toplevel") == os.getcwd(), "run from the repository root")
    require(not git("status", "--porcelain", "--untracked-files=all"),
            "worktree and index must be clean")
    require(subprocess.run(["git", "symbolic-ref", "-q", target_ref],
                           capture_output=True).returncode == 1,
            "candidate target must not be a symbolic ref")
    require(not exists(target_ref) or git("symbolic-ref", "-q", "HEAD") != target_ref,
            "candidate branch must not be checked out")
    require(exists(base_ref), "release base must be an existing local branch")
    require(exists(source_ref), "source must be an existing local branch")
    base = git("rev-parse", base_ref)
    source = git("rev-parse", source_ref)
    prior = git("rev-parse", target_ref) if exists(target_ref) else None
    if prior:
        old_source, old_base, parents = identity(prior)
        require(old_base == base, "release base changed; refuse stale candidate")
        descendant_source = old_source
        while parents:
            parent_source, parent_base, parents = identity(parents[0])
            require(parent_base == base and
                    subprocess.run(["git", "merge-base", "--is-ancestor", parent_source, descendant_source]).returncode == 0,
                    "candidate parent has unexpected provenance")
            descendant_source = parent_source
        if args.cancel:
            git("update-ref", "-d", target_ref, prior)
            print(f"Canceled {args.target} at {prior}; release unchanged.")
            return
        require(subprocess.run(["git", "merge-base", "--is-ancestor", old_source, source]).returncode == 0,
                "source must advance candidate source; cancel before replacing")
        if source == old_source:
            print("Candidate already contains this source; nothing to update.")
            return
    else:
        require(not args.cancel, "no candidate to cancel")

    tree = distribution.filtered_tree(source)
    message = f"{SUBJECT}\n\n{SOURCE}{source}\n{BASE}{base}\n"
    commit = git("commit-tree", tree, *(["-p", prior] if prior else []), input=message.encode())
    git("update-ref", target_ref, commit, prior or ZERO)
    print(f"Candidate {args.target} at {commit}; source {source}; base {base}.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"starter candidate: {error}", file=sys.stderr)
        sys.exit(1)
