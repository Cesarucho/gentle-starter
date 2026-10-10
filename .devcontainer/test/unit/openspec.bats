#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	INSTALLER="${REPO_ROOT}/.devcontainer/install/available/3080-ai-openspec.sh"
	export DEVCONTAINER_TOOL_VERSIONS_FILE="${BATS_TEST_TMPDIR}/policy"
	export OPENSPEC_CALLS="${BATS_TEST_TMPDIR}/calls" OPENSPEC_INSTALLED="${BATS_TEST_TMPDIR}/version"
	printf 'LOCK_OPENSPEC_VERSION="1.2.3"\n' >"${DEVCONTAINER_TOOL_VERSIONS_FILE}"
	: >"${OPENSPEC_CALLS}"
	mkdir "${BATS_TEST_TMPDIR}/bin"
	cat >"${BATS_TEST_TMPDIR}/bin/npm" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${OPENSPEC_CALLS}"
[ "${NPM_FAIL:-0}" = 0 ] || exit 42
printf '%s\n' "${INSTALL_VERSION:-1.2.3}" >"${OPENSPEC_INSTALLED}"
SH
	cat >"${BATS_TEST_TMPDIR}/bin/openspec" <<'SH'
#!/usr/bin/env bash
cat "${OPENSPEC_INSTALLED}" 2>/dev/null
SH
	cat >"${BATS_TEST_TMPDIR}/bin/node" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "${NODE_VERSION:-v26.0.0}"
SH
	chmod +x "${BATS_TEST_TMPDIR}/bin/"*
	export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
	printf 'source "%s/.devcontainer/install/lib/common.sh"\ndevcontainer_run_as_root() { "$@"; }\ndevcontainer_has_cmd() { [ "$1" != "${MISSING_COMMAND:-}" ] && command -v "$1" >/dev/null 2>&1; }\n' "${REPO_ROOT}" >"${BATS_TEST_TMPDIR}/env"
	export BASH_ENV="${BATS_TEST_TMPDIR}/env"
	unset OPENSPEC_VERSION DEVCONTAINER_PHASE
}

@test "openspec installs exact lock and reuses only verified matching version" {
	run bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	[ "$(cat "${OPENSPEC_CALLS}")" = 'install -g @fission-ai/openspec@1.2.3' ]
	run bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	[ "$(wc -l <"${OPENSPEC_CALLS}")" -eq 1 ]
	printf '1.1.0\n' >"${OPENSPEC_INSTALLED}"
	run bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	[ "$(wc -l <"${OPENSPEC_CALLS}")" -eq 2 ]
}

@test "openspec runtime and print-policy never invoke npm" {
	run bash "${INSTALLER}" --print-version-policy
	[ "$status" -eq 0 ]
	[ "$output" = 'OPENSPEC_VERSION=1.2.3' ]
	run env DEVCONTAINER_PHASE=runtime bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	[ ! -s "${OPENSPEC_CALLS}" ]
}

@test "openspec rejects invalid locks and missing lock" {
	for version in latest 1 1.2.3-beta.1; do
		printf 'LOCK_OPENSPEC_VERSION="%s"\n' "${version}" >"${DEVCONTAINER_TOOL_VERSIONS_FILE}"
		run bash "${INSTALLER}"
		[ "$status" -ne 0 ]
	done
	: >"${DEVCONTAINER_TOOL_VERSIONS_FILE}"
	run bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	[ ! -s "${OPENSPEC_CALLS}" ]
}

@test "openspec fails on old Node, npm failure, and post-install version mismatch" {
	run env NODE_VERSION=v20.18.9 bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	[ ! -s "${OPENSPEC_CALLS}" ]
	run env NPM_FAIL=1 bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	run env INSTALL_VERSION=1.2.2 bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	[[ "$output" == *'version mismatch'* ]]
	run env NODE_VERSION=v20.19.0 bash "${INSTALLER}"
	[ "$status" -eq 0 ]
}

@test "openspec requires npm and node before installation" {
	for command in npm node; do
		run env MISSING_COMMAND="${command}" bash "${INSTALLER}"
		[ "$status" -ne 0 ]
		[[ "$output" == *"Required command not found: ${command}"* ]]
	done
	[ ! -s "${OPENSPEC_CALLS}" ]
}

@test "openspec catalog declares core npm dependency and executable installer" {
	grep -Fxq '3080-ai-openspec.sh|enabled|2000-runtime-node.sh|npm' "${REPO_ROOT}/.devcontainer/install/dependencies.conf"
	[ "$(stat -c %a "${INSTALLER}")" = 755 ]
}
