#!/usr/bin/env python3
"""Publish an explicitly approved candidate as one linear local release commit."""

import argparse
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import sys

spec = importlib.util.spec_from_file_location("starter_candidate", Path(__file__).with_name("starter-candidate.py"))
assert spec is not None and spec.loader is not None
candidate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(candidate)

git = candidate.git
require = candidate.require
branch = candidate.branch
exists = candidate.exists
ZERO = candidate.ZERO
SOURCE = "Starter-Release-Source: "
SUBJECT = "Publish consumer starter"


def ancestor(older, newer):
    return subprocess.run(["git", "merge-base", "--is-ancestor", older, newer],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def oid(value):
    require(re.fullmatch(r"[0-9a-f]{40,64}", value) is not None, "expected full hexadecimal object ID")
    return value


def release_source(base):
    message = git("show", "-s", "--format=%B", base)
    source, policy, normalization = candidate.source_tree.identity_metadata(message, SUBJECT, (SOURCE,))
    parents = git("show", "-s", "--format=%P", base).split()
    require(len(parents) <= 1, "release base has unexpected ancestry")
    require(git("cat-file", "-t", source) == "commit", "release source is missing")
    require(git("rev-parse", f"{base}^{{tree}}") == candidate.source_tree.filtered_tree(source, policy, normalization),
            "release tree does not match committed source")
    if parents:
        require(ancestor(release_source(parents[0]), source), "release source ancestry diverged")
    return source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", default="starter-rc")
    parser.add_argument("--target", default="starter")
    parser.add_argument("--approved-rc", required=True, type=oid)
    parser.add_argument("--expected-tree", required=True, type=oid)
    parser.add_argument("--expected-base", required=True, help="full release SHA or 'absent' for a new root")
    parser.add_argument("--expected-source", required=True, type=oid)
    args = parser.parse_args()
    rc_ref, target_ref = branch(args.candidate), branch(args.target)
    require(rc_ref != target_ref, "candidate and release branch must differ")
    require(git("rev-parse", "--show-toplevel") == os.getcwd(), "run from the repository root")
    require(not git("status", "--porcelain", "--untracked-files=all"), "worktree and index must be clean")
    require(not candidate.checked_out(target_ref), "release branch is checked out in a worktree")
    for ref in (rc_ref, target_ref):
        require(subprocess.run(["git", "symbolic-ref", "-q", ref],
                               capture_output=True).returncode == 1, "symbolic release or candidate ref")
    require(exists(rc_ref), "candidate was canceled or is missing")
    require(git("rev-parse", rc_ref) == args.approved_rc, "candidate moved since approval")
    base = ZERO if args.expected_base == "absent" else oid(args.expected_base)
    require(exists(target_ref) == (base != ZERO), "release ref presence does not match expected base")
    if base != ZERO:
        require(git("rev-parse", target_ref) == base, "release base moved")
        previous_source = release_source(base)
    else:
        previous_source = None

    current = args.approved_rc
    descendant_source = None
    while True:
        source, pinned_base, parents, policy, normalization = candidate.identity(current)
        if current == args.approved_rc:
            require(policy == candidate.source_tree.CURRENT_COMPOSE_POLICY,
                     "new publication requires a current four-default candidate")
            require(normalization == candidate.source_tree.CURRENT_TOOLS_NORMALIZATION,
                    "new publication requires a normalized tool-list candidate")
        require(pinned_base == base, "candidate base differs from expected release base")
        require(descendant_source is None or ancestor(source, descendant_source),
                "candidate source ancestry diverged")
        descendant_source = source
        if not parents:
            require(previous_source is None or ancestor(previous_source, source),
                    "candidate does not descend from previous release source")
            break
        current = parents[0]
    require(git("rev-parse", f"{args.approved_rc}^{{tree}}") == args.expected_tree,
            "candidate tree differs from approval")
    approved_source, _, _, _, _ = candidate.identity(args.approved_rc)
    require(approved_source == args.expected_source, "candidate source differs from approval")
    message = (f"{SUBJECT}\n\n{SOURCE}{approved_source}\n"
               f"{candidate.source_tree.COMPOSE_POLICY_HEADER}{candidate.source_tree.CURRENT_COMPOSE_POLICY}\n"
               f"{candidate.source_tree.TOOLS_NORMALIZATION_HEADER}{candidate.source_tree.CURRENT_TOOLS_NORMALIZATION}\n")
    commit = git("commit-tree", args.expected_tree, *(["-p", base] if base != ZERO else []),
                 input=message.encode())
    git("update-ref", target_ref, commit, base)
    print(f"Published {args.target} at {commit}; candidate {args.approved_rc} unchanged.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"starter promote: {error}", file=sys.stderr)
        sys.exit(1)
