#!/usr/bin/env bats

@test "relocated environment guides resolve local links without maintainer docs" {
	local root
	root="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	run python3 - "${root}/.devcontainer" <<'PY'
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

root = Path(sys.argv[1])
documents = [root / "README.md", *sorted((root / "docs").glob("*.md"))]
assert len(documents) == 7, documents
for document in documents:
    for target in re.findall(r"\]\(([^\s)]+)\)", document.read_text()):
        link = urlsplit(target)
        if link.scheme or link.netloc or not link.path:
            continue
        destination = (document.parent / unquote(link.path)).resolve()
        assert destination.is_relative_to(root), f"{document}: link escapes devcontainer: {target}"
        assert destination.is_file(), f"{document}: missing {target}"
PY
	[ "${status}" -eq 0 ] || printf '%s\n' "${output}" >&3
}
