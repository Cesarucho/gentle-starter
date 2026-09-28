#!/usr/bin/env python3
"""Update an existing consumer branch in a temporary worktree; never publish it."""

import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True)
    parser.add_argument("--target", required=True)
    args = parser.parse_args()

    # Validate before creating anything. The direct distribution command remains
    # responsible for ancestry, marker and merge policy in the isolated checkout.
    script = Path(__file__).resolve().with_name("starter-distribution.py")
    if git("rev-parse", "--show-toplevel") != os.getcwd():
        raise ValueError("run from the repository root")
    if git("status", "--porcelain", "--untracked-files=all"):
        raise ValueError("worktree and index must be clean")
    if git("symbolic-ref", "-q", "HEAD") == f"refs/heads/{args.target}":
        raise ValueError("run from the producer branch, not the target")
    subprocess.run(["git", "check-ref-format", "--branch", args.target], check=True,
                   capture_output=True)
    subprocess.run(["git", "show-ref", "--verify", f"refs/heads/{args.target}"],
                   check=True, capture_output=True)
    target_before = git("rev-parse", f"refs/heads/{args.target}")
    temp = tempfile.mkdtemp(prefix="starter-producer-")
    checkout = os.path.join(temp, "checkout")
    failure = None
    cleanup_errors = []
    try:
        try:
            git("worktree", "add", "--quiet", checkout, args.target)
            result = subprocess.run(
                [sys.executable, str(script), "--source", args.source,
                 "--target", args.target], cwd=checkout, text=True,
                capture_output=True,
            )
            if result.returncode:
                print(result.stdout + result.stderr, file=sys.stderr)
                # Conflict state is confined to the temporary checkout. Abort it
                # before removal; the consumer branch HEAD remains unchanged.
                if subprocess.run(["git", "-C", checkout, "rev-parse", "-q",
                                   "--verify", "MERGE_HEAD"], capture_output=True).returncode == 0:
                    subprocess.run(["git", "-C", checkout, "merge", "--abort"], check=True)
                raise ValueError("preparation failed")
            print(result.stdout, end="")
        except (ValueError, subprocess.CalledProcessError) as error:
            failure = error
    finally:
        try:
            registered = any(
                line == f"worktree {checkout}"
                for line in git("worktree", "list", "--porcelain").splitlines()
            )
            if registered:
                git("worktree", "remove", checkout)
            elif os.path.lexists(checkout):
                raise ValueError("unregistered checkout remains")
            os.rmdir(temp)
        except (ValueError, OSError, subprocess.CalledProcessError) as error:
            cleanup_errors.append(str(error))
    if failure:
        detail = f": {failure.stderr.strip()}" if isinstance(failure, subprocess.CalledProcessError) and failure.stderr else ""
        print(f"starter producer: {failure}{detail}", file=sys.stderr)
    for error in cleanup_errors:
        print(f"starter producer: cleanup uncertain at {checkout}: {error}", file=sys.stderr)
    if failure or cleanup_errors:
        try:
            unchanged = git("rev-parse", f"refs/heads/{args.target}") == target_before
        except subprocess.CalledProcessError:
            unchanged = False
        if unchanged:
            print("starter producer: target HEAD unchanged", file=sys.stderr)
        else:
            print("starter producer: target HEAD changed or could not be verified", file=sys.stderr)
        raise ValueError("preparation or cleanup failed")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"starter producer: {error}", file=sys.stderr)
        sys.exit(1)
