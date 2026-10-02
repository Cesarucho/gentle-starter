#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	export PNPM_HOME="${TEST_ROOT}/home/.local/share/pnpm"
	export CALLS="${TEST_ROOT}/calls"
	mkdir -p "${TEST_ROOT}/install/available" "${TEST_ROOT}/install/lib"
	cp "${REPO_ROOT}/.devcontainer/install/available/2010-runtime-pnpm.sh" "${TEST_ROOT}/install/available/"
	cat >"${TEST_ROOT}/install/lib/common.sh" <<'SH'
devcontainer_load_tool_versions() { LOCK_PNPM_VERSION=12.3.4; }
devcontainer_require_cmd() { :; }
devcontainer_has_cmd() { [ "${REUSE:-0}" = 1 ]; }
devcontainer_log_info() { :; }
pnpm() { printf '12.3.4\n'; }
devcontainer_run_as_root() {
	printf '%s\n' "$*" >>"${CALLS}"
	if [ "$1" = npm ]; then return; fi
	"$@"
}
SH
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

assert_user_directories() {
	[ "$(stat -c '%U:%G:%a' "${PNPM_HOME}")" = ubuntu:ubuntu:755 ]
	[ "$(stat -c '%U:%G:%a' "${PNPM_HOME}/bin")" = ubuntu:ubuntu:755 ]
}

@test "pnpm: provision user globals before reusing the managed CLI" {
	run env REUSE=1 bash "${TEST_ROOT}/install/available/2010-runtime-pnpm.sh"
	[ "$status" -eq 0 ]
	assert_user_directories
	! grep -q '^npm ' "${CALLS}"
}

@test "pnpm: provision user globals on the npm installation path" {
	run env REUSE=0 bash "${TEST_ROOT}/install/available/2010-runtime-pnpm.sh"
	[ "$status" -eq 0 ]
	assert_user_directories
	grep -qx 'npm install --global pnpm@12.3.4' "${CALLS}"
}

@test "pnpm: repeated provisioning repairs directory modes without changing package contents" {
	mkdir -p "${PNPM_HOME}/bin"
	printf 'preserve\n' >"${PNPM_HOME}/bin/sentinel"
	chmod 0700 "${PNPM_HOME}" "${PNPM_HOME}/bin"
	chmod 0600 "${PNPM_HOME}/bin/sentinel"
	for attempt in 1 2; do
		run env REUSE=1 bash "${TEST_ROOT}/install/available/2010-runtime-pnpm.sh"
		[ "$status" -eq 0 ]
		assert_user_directories
		[ "$(stat -c '%a' "${PNPM_HOME}/bin/sentinel")" = 600 ]
		[ "$(cat "${PNPM_HOME}/bin/sentinel")" = preserve ]
	done
}

@test "pnpm: version policy inspection does not provision directories" {
	run bash "${TEST_ROOT}/install/available/2010-runtime-pnpm.sh" --print-version-policy
	[ "$status" -eq 0 ]
	[ "$output" = PNPM_VERSION=12.3.4 ]
	[ ! -e "${PNPM_HOME}" ]
	[ ! -e "${CALLS}" ]
}

@test "pnpm: image environment belongs to core and preserves managed CLI precedence" {
	run python3 - "${REPO_ROOT}/.devcontainer/Dockerfile" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
foundation, rest = text.split('FROM foundation AS core-tools', 1)
core, final = rest.split('FROM core-tools AS devcontainer', 1)
assert 'PNPM_HOME' not in foundation
assert 'ENV PNPM_HOME=/home/${UID_NAME}/.local/share/pnpm' in core
assert 'ENV SHELL=/bin/bash' in core
assert 'ENV PATH=${PATH}:${PNPM_HOME}/bin:${PNPM_HOME}' in core
assert core.index('ENV PNPM_HOME=') < core.index('RUN ')
assert 'ENV PATH=' not in final
PY
	[ "$status" -eq 0 ]
}
