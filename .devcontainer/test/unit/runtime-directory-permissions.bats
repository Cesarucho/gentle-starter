#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"

@test "runtime permission setup and helper contracts pass without privileged operations" {
	run python3 "${REPO_ROOT}/.devcontainer/test/unit/runtime-directory-permissions-test.py" -v
	printf '%s\n' "${output}"
	[ "${status}" -eq 0 ]
}

@test "Dev Container applies runtime permissions only through postCreate setup" {
	run python3 - "${REPO_ROOT}" <<'PY'
from pathlib import Path
import sys
text = (Path(sys.argv[1]) / '.devcontainer/devcontainer.json').read_text()
assert '"postCreateCommand": "bash ${containerWorkspaceFolder}/.devcontainer/setup.sh"' in text
assert '"postStartCommand"' not in text
PY
	[ "${status}" -eq 0 ]
}
