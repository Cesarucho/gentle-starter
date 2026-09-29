"""Build the distributable tree solely from committed source objects."""

import json
import os
import re
import subprocess
import tempfile


EXCLUDED = (
    "README.md", "AGENTS.md", "AGENTS.md.TEMPLATE", "AGENTS.md.TEMPLATE.EXAMPLE",
    "CHANGELOG.md", "docs", ".github", "odd", "openspec", ".maintainer",
    "skills-lock.json",
)
CATALOG = ".devcontainer/skills/recommended.json"


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


def recommendations(source):
    lock = json.loads(git("show", f"{source}:skills-lock.json"))
    require(lock.get("version") == 1 and isinstance(lock.get("skills"), dict),
            "unsupported source skills lock")
    skills = {}
    for name, entry in sorted(lock["skills"].items()):
        require(isinstance(name, str) and name != "add-tool" and isinstance(entry, dict),
                "invalid external skill entry")
        require(isinstance(entry.get("source"), str) and entry["source"] and
                isinstance(entry.get("skillPath"), str) and entry["skillPath"],
                "external skill requires source and skillPath")
        skills[name] = {"source": entry["source"], "skillPath": entry["skillPath"]}
    return (json.dumps({"version": 1, "skills": skills}, indent=2) + "\n").encode()


def filtered_tree(source):
    catalog = recommendations(source)
    # A private index builds the tree entirely from committed source files. Never
    # walk or remove worktree paths: excluded directories may contain symlinks.
    with tempfile.TemporaryDirectory(prefix="starter-index-") as temp:
        env = dict(os.environ, GIT_INDEX_FILE=os.path.join(temp, "index"))
        git("read-tree", source, env=env)
        paths = subprocess.run(
            ["git", "ls-files", "-z", "--", *EXCLUDED, ".agents/skills"], env=env,
            stdout=subprocess.PIPE, check=True,
        ).stdout.split(b"\0")
        paths = [os.fsdecode(path) for path in paths if path and
                 (not path.startswith(b".agents/skills/") or
                  not path.startswith(b".agents/skills/add-tool/"))]
        if paths:
            git("update-index", "--force-remove", "-z", "--stdin", env=env,
                input=b"\0".join(os.fsencode(path) for path in paths) + b"\0")
        blob = git("hash-object", "-w", "--stdin", input=catalog)
        git("update-index", "--add", "--cacheinfo", "100644", blob, CATALOG, env=env)
        return git("write-tree", env=env)
