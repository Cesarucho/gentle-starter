#!/usr/bin/env python3
"""Build or cancel a local, filtered starter release candidate."""

import argparse
import importlib.util
import os
from pathlib import Path
import subprocess
import sys


script = Path(__file__).with_name("starter-source.py")
spec = importlib.util.spec_from_file_location("starter_source", script)
assert spec is not None and spec.loader is not None
source_tree = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source_tree)
git = source_tree.git
require = source_tree.require
branch = source_tree.branch
exists = source_tree.exists

SOURCE = "Starter-Candidate-Source: "
BASE = "Starter-Candidate-Base: "
SUBJECT = "Prepare starter release candidate"
RELEASE_SUBJECT = "Publish consumer starter"
RELEASE_SOURCE = "Starter-Release-Source: "
ZERO = "0" * 40


def checked_out(ref):
    return any(line == f"branch {ref}" for line in git("worktree", "list", "--porcelain").splitlines())


def identity(commit):
    message = git("show", "-s", "--format=%B", commit)
    source, base, policy = source_tree.identity_metadata(message, SUBJECT, (SOURCE, BASE))
    parents = git("show", "-s", "--format=%P", commit).split()
    require(len(parents) <= 1, "candidate must have at most one candidate parent")
    require(git("cat-file", "-t", source) == "commit", "invalid candidate source")
    require(base == ZERO or git("cat-file", "-t", base) == "commit", "invalid candidate base")
    require(git("rev-parse", f"{commit}^{{tree}}") == source_tree.filtered_tree(source, policy),
            "candidate tree does not match committed source")
    return source, base, parents, policy


def published_candidate(release, prior, source, pinned_base, policy):
    message = git("show", "-s", "--format=%B", release)
    release_source, release_policy = source_tree.identity_metadata(message, RELEASE_SUBJECT, (RELEASE_SOURCE,))
    require((release_source, release_policy) == (source, policy),
            "release is not a publication of the candidate")
    parents = git("show", "-s", "--format=%P", release).split()
    require(parents == ([] if pinned_base == ZERO else [pinned_base]),
            "release does not descend directly from candidate base")
    require(git("rev-parse", f"{release}^{{tree}}") == git("rev-parse", f"{prior}^{{tree}}"),
            "release tree differs from candidate")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="dev", help="committed local source branch")
    parser.add_argument("--target", default="starter-rc", help="local candidate branch")
    parser.add_argument("--base", default="starter", help="local release branch")
    parser.add_argument("--base-absent", action="store_true", help="pin an absent release branch for an initial root release")
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
    require(not checked_out(target_ref),
            "candidate branch must not be checked out")
    require(exists(base_ref) != args.base_absent,
            "release base presence does not match --base-absent")
    base = ZERO if args.base_absent else git("rev-parse", base_ref)
    require(exists(source_ref) or args.cancel, "source must be an existing local branch")
    source = git("rev-parse", source_ref) if exists(source_ref) else None
    prior = git("rev-parse", target_ref) if exists(target_ref) else None
    if prior:
        old_source, old_base, parents, old_policy = identity(prior)
        if old_base != base:
            require(args.cancel and base != ZERO,
                    "release base changed; refuse stale candidate")
            published_candidate(base, prior, old_source, old_base, old_policy)
        descendant_source = old_source
        while parents:
            parent_source, parent_base, parents, _ = identity(parents[0])
            require(parent_base == old_base and
                    subprocess.run(["git", "merge-base", "--is-ancestor", parent_source, descendant_source]).returncode == 0,
                    "candidate parent has unexpected provenance")
            descendant_source = parent_source
        if args.cancel:
            git("update-ref", "-d", target_ref, prior)
            print(f"Canceled {args.target} at {prior}; release unchanged.")
            return
        require(source is not None, "source must be an existing local branch")
        assert source is not None
        require(subprocess.run(["git", "merge-base", "--is-ancestor", old_source, source]).returncode == 0,
                "source must advance candidate source; cancel before replacing")
        if source == old_source and old_policy == source_tree.CURRENT_COMPOSE_POLICY:
            print("Candidate already contains this source; nothing to update.")
            return
    else:
        require(not args.cancel, "no candidate to cancel")
    require(source is not None, "source must be an existing local branch")

    try:
        tree = source_tree.filtered_tree(source)
    except ValueError as error:
        raise ValueError(f"new candidate requires a committed source with four active Compose defaults: {error}") from error
    message = (f"{SUBJECT}\n\n{SOURCE}{source}\n{BASE}{base}\n"
               f"{source_tree.COMPOSE_POLICY_HEADER}{source_tree.CURRENT_COMPOSE_POLICY}\n")
    commit = git("commit-tree", tree, *(["-p", prior] if prior else []), input=message.encode())
    git("update-ref", target_ref, commit, prior or ZERO)
    print(f"Candidate {args.target} at {commit}; source {source}; base {base}.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"starter candidate: {error}", file=sys.stderr)
        sys.exit(1)
