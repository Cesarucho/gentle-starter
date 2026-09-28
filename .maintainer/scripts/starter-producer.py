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
    with tempfile.TemporaryDirectory(prefix="starter-producer-") as temp:
        checkout = os.path.join(temp, "checkout")
        git("worktree", "add", "--quiet", checkout, args.target)
        try:
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
                raise ValueError("preparation failed; target unchanged")
            print(result.stdout, end="")
        finally:
            git("worktree", "remove", checkout)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"starter producer: {error}", file=sys.stderr)
        sys.exit(1)
