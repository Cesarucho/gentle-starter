#!/usr/bin/env bats

load ../helpers/npm-fixture.bash

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="${BATS_TEST_TMPDIR}/pnpm sandbox"
	setup_npm_fixture "${TEST_ROOT}"
	export PNPM_HOME="${TEST_ROOT}/home/.local/share/pnpm"
	export CALLS="${TEST_ROOT}/calls"
	[ "$(id -u):$(id -g)" = "$(id -u ubuntu):$(id -g ubuntu)" ] || skip "pnpm ownership fixture requires the ubuntu identity"
	mkdir -p "${TEST_ROOT}/install/available" "${TEST_ROOT}/install/lib"
	cp "${REPO_ROOT}/.devcontainer/install/available/2010-runtime-pnpm.sh" "${TEST_ROOT}/install/available/"
	INSTALLER="${TEST_ROOT}/install/available/2010-runtime-pnpm.sh"
	PNPM_ENTRY="${TEST_ROOT}/entry.sh"
	cat >"${PNPM_ENTRY}" <<'SH'
if [ "${PRINT_POLICY:-0}" = 1 ]; then set -- --print-version-policy; fi
exec bash "${PNPM_INSTALLER}" "$@"
SH
	cat >"${TEST_ROOT}/install/lib/common.sh" <<'SH'
source "${NPM_FIXTURE_RUNTIME}"
devcontainer_load_tool_versions() { LOCK_PNPM_VERSION=12.3.4; }
devcontainer_require_cmd() { :; }
devcontainer_has_cmd() { [ "${REUSE:-0}" = 1 ]; }
devcontainer_log_info() { :; }
pnpm() { printf '12.3.4\n'; }
npm_fixture_dispatch() {
	[ "$#" -eq 3 ] && [ "$1" = install ] && [ "$2" = --global ] &&
		[ "$3" = pnpm@12.3.4 ] || return 98
}
devcontainer_run_as_root() {
	printf '%s\n' "$*" >>"${CALLS}"
	if [ "$1" = npm ]; then
		shift
		npm "$@"
		return
	fi
	[ "$#" -eq 10 ] && [ "${*:1:8}" = 'install -d -m 0755 -o ubuntu -g ubuntu' ] || return 98
	[ "$9" = "${PNPM_HOME}" ] && [ "${10}" = "${PNPM_HOME}/bin" ] || return 98
	[ "${PNPM_HOME}" = "${NPM_FIXTURE_ROOT}/home/.local/share/pnpm" ] || return 98
	[ "$(realpath -m -- "${PNPM_HOME}/bin")" = "${PNPM_HOME}/bin" ] || return 98
	"$@"
}
SH
}

run_pnpm_fixture() {
	run_npm_fixture "${PNPM_ENTRY}" "${NPM_FIXTURE_RUNTIME}" \
		REUSE=0 PNPM_HOME="${PNPM_HOME}" UID_NAME=ubuntu CALLS="${CALLS}" \
		PNPM_INSTALLER="${INSTALLER}" "$@"
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

assert_user_directories() {
	[ "$(stat -c '%U:%G:%a' "${PNPM_HOME}")" = ubuntu:ubuntu:755 ]
	[ "$(stat -c '%U:%G:%a' "${PNPM_HOME}/bin")" = ubuntu:ubuntu:755 ]
}

@test "pnpm: provision user globals before reusing the managed CLI" {
	run_pnpm_fixture REUSE=1
	[ "$status" -eq 0 ]
	assert_user_directories
	! grep -q '^npm ' "${CALLS}"
	[ ! -e "${NPM_FIXTURE_CALLS}/1" ]
}

@test "pnpm: provision user globals on the npm installation path" {
	run_pnpm_fixture REUSE=0
	[ "$status" -eq 0 ]
	assert_user_directories
	grep -qx 'npm install --global pnpm@12.3.4' "${CALLS}"
	[ -f "${TEST_ROOT}/npm-calls/1" ]
	local argv
	mapfile -d '' -t argv <"${TEST_ROOT}/npm-calls/1"
	[ "${#argv[@]}" -eq 3 ]
	[ "${argv[0]}" = install ]
	[ "${argv[1]}" = --global ]
	[ "${argv[2]}" = pnpm@12.3.4 ]
}

@test "pnpm: npm dispatcher rejects unexpected commands" {
	printf 'source "%s/install/lib/common.sh"\ndevcontainer_run_as_root npm unexpected\n' "${TEST_ROOT}" >"${TEST_ROOT}/unexpected.sh"
	run_pnpm_fixture PNPM_INSTALLER="${TEST_ROOT}/unexpected.sh"
	[ "$status" -eq 98 ]
	local argv
	mapfile -d '' -t argv <"${NPM_FIXTURE_CALLS}/1"
	[ "${#argv[@]}" -eq 1 ]
	[ "${argv[0]}" = unexpected ]
}

@test "pnpm: repeated provisioning repairs directory modes without changing package contents" {
	mkdir -p "${PNPM_HOME}/bin"
	printf 'preserve\n' >"${PNPM_HOME}/bin/sentinel"
	chmod 0700 "${PNPM_HOME}" "${PNPM_HOME}/bin"
	chmod 0600 "${PNPM_HOME}/bin/sentinel"
	for attempt in 1 2; do
		run_pnpm_fixture REUSE=1
		[ "$status" -eq 0 ]
		assert_user_directories
		[ "$(stat -c '%a' "${PNPM_HOME}/bin/sentinel")" = 600 ]
		[ "$(cat "${PNPM_HOME}/bin/sentinel")" = preserve ]
		[ ! -e "${NPM_FIXTURE_CALLS}/1" ]
	done
}

@test "pnpm: version policy inspection does not provision directories" {
	run_pnpm_fixture PRINT_POLICY=1
	[ "$status" -eq 0 ]
	[ "$output" = PNPM_VERSION=12.3.4 ]
	[ ! -e "${PNPM_HOME}" ]
	[ ! -e "${CALLS}" ]
	[ ! -e "${NPM_FIXTURE_CALLS}/1" ]
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
