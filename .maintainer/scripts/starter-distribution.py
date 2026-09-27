#!/usr/bin/env python3
"""Prepare a filtered starter branch without rewriting or cleaning consumer files."""

import argparse
import os
import re
import subprocess
import sys
import tempfile


EXCLUDED = (
    "README.md", "AGENTS.md", "AGENTS.md.TEMPLATE", "AGENTS.md.TEMPLATE.EXAMPLE",
    "CHANGELOG.md", "docs", ".github", "odd", "openspec", ".maintainer",
)
MARKER = "Starter-Distribution-Source: "


def git(*args, env=None, input=None):
    return subprocess.run(
        ["git", *args], env=env, input=input, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, check=True,
    ).stdout.decode().strip()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def branch(name):
    require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]*", name) is not None,
            "branch must be an explicit local name")
    require(subprocess.run(["git", "check-ref-format", "--branch", name],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0,
            "invalid branch name")
    return "refs/heads/" + name


def exists(ref):
    return subprocess.run(["git", "show-ref", "--verify", "--quiet", ref]).returncode == 0


def previous_release(target):
    for commit in git("log", "--format=%H", target).splitlines():
        message = git("show", "-s", "--format=%B", commit)
        if message.startswith("Prepare consumer starter\n\n" + MARKER):
            source = message.split(MARKER, 1)[1].splitlines()[0]
            require(re.fullmatch(r"[0-9a-f]{40,64}", source) is not None,
                    "invalid distribution marker")
            parents = git("show", "-s", "--format=%P", commit).split()
            require(source in parents, "distribution source parent does not match marker")
            return commit, source
    raise ValueError("target has no verified distribution commit; refusing unrelated history")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="local committed source branch")
    parser.add_argument("--target", required=True, help="local consumer branch")
    args = parser.parse_args()
    source_ref, target_ref = branch(args.source), branch(args.target)
    require(source_ref != target_ref, "source and target must differ")
    require(git("rev-parse", "--show-toplevel") == os.getcwd(),
            "run from the repository root")
    require(not git("status", "--porcelain", "--untracked-files=all"),
            "worktree and index must be clean")
    require(not os.path.exists(git("rev-parse", "--git-path", "MERGE_HEAD")),
            "resolve the existing merge first")
    require(exists(source_ref), "source must be an existing local branch")
    source = git("rev-parse", source_ref)
    updating = exists(target_ref)
    prior = None
    if updating:
        require(git("symbolic-ref", "-q", "HEAD") == target_ref,
                "check out the target branch before updating")
        prior, old_source = previous_release(target_ref)
        require(subprocess.run(["git", "merge-base", "--is-ancestor", old_source, source]).returncode == 0,
                "source must advance the previous distribution source")
        if old_source == source:
            print("Target already contains this source; nothing to update.")
            return

    # A private index builds the tree entirely from committed source files. Never
    # walk or remove worktree paths: excluded directories may contain symlinks.
    with tempfile.TemporaryDirectory(prefix="starter-index-") as temp:
        env = dict(os.environ, GIT_INDEX_FILE=os.path.join(temp, "index"))
        git("read-tree", source, env=env)
        paths = subprocess.run(
            ["git", "ls-files", "-z", "--", *EXCLUDED], env=env,
            stdout=subprocess.PIPE, check=True,
        ).stdout.split(b"\0")
        paths = [os.fsdecode(path) for path in paths if path]
        if paths:
            git("update-index", "--force-remove", "-z", "--stdin", env=env,
                input=b"\0".join(os.fsencode(path) for path in paths) + b"\0")
        tree = git("write-tree", env=env)

    # Even when the sanitized tree is unchanged, the new source parent and
    # marker must be recorded so the next update starts from this source.
    parents = [prior, source] if prior else [source]
    commit = git("commit-tree", tree, *(option for parent in parents for option in ("-p", parent)),
                 input=("Prepare consumer starter\n\n" + MARKER + source + "\n").encode())
    if not updating:
        git("branch", args.target, commit)
        print(f"Created {args.target} at {commit}; source branch and worktree unchanged.")
    else:
        try:
            git("merge", "--no-edit", commit)
        except subprocess.CalledProcessError as error:
            print(error.stdout.decode() + error.stderr.decode(), file=sys.stderr)
            raise ValueError("merge stopped; resolve conflicts and commit manually, or abort with git merge --abort")
        print(f"Merged distributable changes into {args.target}.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"starter distribution: {error}", file=sys.stderr)
        sys.exit(1)
