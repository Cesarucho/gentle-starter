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
DEVCONTAINER = ".devcontainer/devcontainer.json"
LEGACY_COMPOSE = (
    "./docker-compose.yml",
    "./config/compose/docker-compose-core-tools.yml",
)
CURRENT_COMPOSE_POLICY = "2"
COMPOSE_POLICY_HEADER = "Starter-Compose-Policy: "
REQUIRED_COMPOSE = LEGACY_COMPOSE + (
    "./config/compose/docker-compose.pi.yml",
    "./config/compose/docker-compose.gentle-shell.yml",
)


def compose_selection(policy):
    require(policy in (None, CURRENT_COMPOSE_POLICY), "unknown Compose selection policy")
    return LEGACY_COMPOSE if policy is None else REQUIRED_COMPOSE


def identity_metadata(message, subject, headers):
    fields = "".join(re.escape(header) + r"([0-9a-f]{40,64})\n" for header in headers)
    marker = re.escape(COMPOSE_POLICY_HEADER) + r"([^\n]+)\n"
    match = re.fullmatch(re.escape(subject) + r"\n\n" + fields + "(?:" + marker + ")?", message + "\n")
    require(match is not None, "invalid starter identity metadata")
    assert match is not None
    *values, policy = match.groups()
    compose_selection(policy)
    return (*values, policy)


JSONC_TOKEN = re.compile(
    r'\s+|//[^\r\n]*|/\*[\s\S]*?\*/|"(?:\\[\s\S]|[^"\\])*"|'
    r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|'
    r'true|false|null|[{}\[\]:,]'
)
COMPOSE_ENTRY = re.compile(r'(?P<indent>[ \t]*)(?P<comment>//[ \t]*)?'
                           r'(?P<comma>,[ \t]*)?(?P<value>"(?:\\.|[^"\\])*")'
                           r'[ \t]*')


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


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate JSONC property")
        result[key] = value
    return result


def jsonc_tokens(text):
    tokens = []
    cleaned = list(text)
    position = 0
    while position < len(text):
        match = JSONC_TOKEN.match(text, position)
        require(match is not None, "invalid devcontainer JSONC token")
        assert match is not None
        token = match.group()
        if token.startswith("//") or token.startswith("/*"):
            for index in range(position, match.end()):
                if cleaned[index] not in "\r\n":
                    cleaned[index] = " "
        elif not token.isspace():
            tokens.append((token, position, match.end()))
        position = match.end()
    return tokens, "".join(cleaned)


def compose_defaults(blob, policy=CURRENT_COMPOSE_POLICY):
    required = compose_selection(policy)
    try:
        text = blob.decode("utf-8")
        tokens, cleaned = jsonc_tokens(text)
        document = json.loads(cleaned, object_pairs_hook=unique_object)
        require(isinstance(document, dict), "devcontainer JSONC must be an object")
        require(isinstance(document.get("dockerComposeFile"), list),
                "dockerComposeFile must be an array")
        depth = 0
        locations = []
        for index, (token, start, end) in enumerate(tokens):
            if depth == 1 and token == '"dockerComposeFile"':
                require(index + 2 < len(tokens) and tokens[index + 1][0] == ":" and
                        tokens[index + 2][0] == "[", "ambiguous dockerComposeFile property")
                locations.append((start, tokens[index + 2][2]))
            if token in ("{", "["):
                depth += 1
            elif token in ("}", "]"):
                depth -= 1
        require(len(locations) == 1, "expected one top-level dockerComposeFile")
        start, opening = locations[0]
        lines = text.splitlines(keepends=True)
        prefix = text[:start]
        first = prefix.count("\n")
        require(re.fullmatch(r'[ \t]*"dockerComposeFile"[ \t]*:[ \t]*\[[ \t]*',
                             lines[first].rstrip("\r\n")), "unsupported dockerComposeFile layout")
        closing = next((index for index in range(first + 1, len(lines))
                        if re.fullmatch(r'[ \t]*\][ \t]*,?[ \t]*',
                                        lines[index].rstrip("\r\n"))), None)
        require(closing is not None, "missing dockerComposeFile closing line")
        assert closing is not None
        closing_position = sum(len(line) for line in lines[:closing]) + len(lines[closing]) - len(lines[closing].lstrip())
        require(any(token == "]" and position == closing_position for token, position, _ in tokens)
                and opening < closing_position, "ambiguous compose array closing line")
        seen = []
        active = []
        output = lines[:]
        for index in range(first + 1, closing):
            line = lines[index].rstrip("\r\n")
            require(bool(line.strip()), "unsupported empty compose entry line")
            match = COMPOSE_ENTRY.fullmatch(line)
            require(match is not None, "unsupported compose entry layout")
            assert match is not None
            value = json.loads(match["value"])
            require(isinstance(value, str) and value and value not in seen,
                    "duplicate or empty compose path")
            seen.append(value)
            if match["comment"] is None:
                active.append(value)
            if value in required:
                require(match["comment"] is None, "mandatory compose path is commented")
            elif match["comment"] is None:
                output[index] = (match["indent"] + "// " + line[len(match["indent"]):] +
                                 lines[index][len(line):])
        require(tuple(seen[:len(required)]) == required and
                all(seen.count(path) == 1 for path in required),
                "mandatory compose paths must be first and unique")
        require(document["dockerComposeFile"] == active,
                "ambiguous compose entries")
        result = "".join(output)
        _, cleaned_result = jsonc_tokens(result)
        published = json.loads(cleaned_result, object_pairs_hook=unique_object)
        require(published["dockerComposeFile"] == list(required),
                "published compose selection is not the required selection")
        return result.encode("utf-8")
    except (UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"invalid devcontainer JSONC: {error}") from error


def filtered_tree(source, policy=CURRENT_COMPOSE_POLICY):
    catalog = recommendations(source)
    compose = compose_defaults(subprocess.run(
        ["git", "show", f"{source}:{DEVCONTAINER}"], stdout=subprocess.PIPE,
        check=True,
    ).stdout, policy)
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
        blob = git("hash-object", "-w", "--stdin", input=compose)
        git("update-index", "--add", "--cacheinfo", "100644", blob, DEVCONTAINER, env=env)
        return git("write-tree", env=env)
