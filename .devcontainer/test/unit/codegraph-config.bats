#!/usr/bin/env bats

load install-fixture

setup_codegraph() {
	printf '#!/usr/bin/env bash\nexit 99\n' >"${INSTALL}/available/3060-ai-codegraph.sh"
}

@test "CodeGraph enable seeds defaults and repairs missing config on repeated enable" {
	setup_codegraph
	activate enable 3060-ai-codegraph
	[ "$status" -eq 0 ]
	[ -L "${INSTALL}/03-enabled/3060-ai-codegraph.sh" ]
	python3 -c 'import json,sys; assert json.load(open(sys.argv[1])) == {"exclude": [".taskfiles/", ".devcontainer/", ".agents/"]}' "${FIXTURE}/codegraph.json"
	rm "${FIXTURE}/codegraph.json"
	activate enable 3060-ai-codegraph.sh
	[ "$status" -eq 0 ]
	[ -f "${FIXTURE}/codegraph.json" ]
}

@test "CodeGraph enable preserves existing files directories and symlinks" {
	setup_codegraph
	printf 'custom configuration\n' >"${FIXTURE}/codegraph.json"
	chmod 0600 "${FIXTURE}/codegraph.json"
	activate enable 3060-ai-codegraph
	[ "$status" -eq 0 ]
	[ "$(cat "${FIXTURE}/codegraph.json")" = 'custom configuration' ]
	[ "$(stat -c %a "${FIXTURE}/codegraph.json")" = 600 ]
	rm "${FIXTURE}/codegraph.json"
	mkdir "${FIXTURE}/codegraph.json"
	activate enable 3060-ai-codegraph
	[ "$status" -eq 0 ]
	[ -d "${FIXTURE}/codegraph.json" ]
	rmdir "${FIXTURE}/codegraph.json"
	ln -s missing "${FIXTURE}/codegraph.json"
	activate enable 3060-ai-codegraph
	[ "$status" -eq 0 ]
	[ "$(readlink "${FIXTURE}/codegraph.json")" = missing ]
	[ ! -e "${FIXTURE}/missing" ]
}

@test "Other activation and rejected CodeGraph activation do not seed config" {
	activate enable 1000-runtime-base
	[ "$status" -eq 0 ]
	[ ! -e "${FIXTURE}/codegraph.json" ]
	activate enable 3060-ai-codegraph
	[ "$status" -ne 0 ]
	[ ! -e "${FIXTURE}/codegraph.json" ]
}

@test "CodeGraph config write failure rolls back new activation" {
	setup_codegraph
	run python3 - "${FIXTURE}" <<'PY'
from pathlib import Path
import resource
import subprocess
import sys

root = Path(sys.argv[1])

def limit():
    resource.setrlimit(resource.RLIMIT_FSIZE, (0, 0))

result = subprocess.run(
    ["bash", str(root / ".taskfiles/scripts/install.sh"), "enable", "3060-ai-codegraph"],
    capture_output=True, preexec_fn=limit,
)
assert result.returncode == 1
assert result.stdout == b""
assert b"File too large" in result.stderr
assert not (root / "codegraph.json").exists()
assert not list((root / ".devcontainer/install/03-enabled").iterdir())
PY
	[ "$status" -eq 0 ]
}
