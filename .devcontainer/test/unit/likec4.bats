#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	INSTALLER="${REPO_ROOT}/.devcontainer/install/available/2090-node-likec4.sh"
	export DEVCONTAINER_TOOL_VERSIONS_FILE="${BATS_TEST_TMPDIR}/policy"
	export LIKEC4_CALLS="${BATS_TEST_TMPDIR}/calls" LIKEC4_INSTALLED="${BATS_TEST_TMPDIR}/version"
	printf 'LOCK_LIKEC4_VERSION="1.60.0"\n' >"${DEVCONTAINER_TOOL_VERSIONS_FILE}"
	: >"${LIKEC4_CALLS}"
	mkdir "${BATS_TEST_TMPDIR}/bin"
	cat >"${BATS_TEST_TMPDIR}/bin/npm" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${LIKEC4_CALLS}"
[ "${NPM_FAIL:-0}" = 0 ] || exit 42
printf '%s\n' "${INSTALL_VERSION:-1.60.0}" >"${LIKEC4_INSTALLED}"
SH
	cat >"${BATS_TEST_TMPDIR}/bin/likec4" <<'SH'
#!/usr/bin/env bash
cat "${LIKEC4_INSTALLED}" 2>/dev/null
SH
	cat >"${BATS_TEST_TMPDIR}/bin/node" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "${NODE_VERSION:-v26.0.0}"
SH
	chmod +x "${BATS_TEST_TMPDIR}/bin/"*
	export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
	printf 'source "%s/.devcontainer/install/lib/common.sh"\ndevcontainer_run_as_root() { "$@"; }\n' "${REPO_ROOT}" >"${BATS_TEST_TMPDIR}/env"
	export BASH_ENV="${BATS_TEST_TMPDIR}/env"
	unset LIKEC4_VERSION DEVCONTAINER_PHASE
}

@test "likec4 installs exact lock without lifecycle scripts and checks installed version" {
	run bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	[ "$(cat "${LIKEC4_CALLS}")" = 'install -g --ignore-scripts likec4@1.60.0' ]
	run bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	[ "$(wc -l <"${LIKEC4_CALLS}")" -eq 1 ]
	printf '1.59.0\n' >"${LIKEC4_INSTALLED}"
	run bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	[ "$(wc -l <"${LIKEC4_CALLS}")" -eq 2 ]
}

@test "likec4 runtime and policy inspection never install or initialize projects" {
	run bash "${INSTALLER}" --print-version-policy
	[ "$status" -eq 0 ]
	[ "$output" = 'LIKEC4_VERSION=1.60.0' ]
	run env DEVCONTAINER_PHASE=runtime bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	[ ! -s "${LIKEC4_CALLS}" ]
}

@test "likec4 rejects missing invalid locks old Node and failed installation" {
	for version in latest 1 1.2.3-beta.1; do
		printf 'LOCK_LIKEC4_VERSION="%s"\n' "${version}" >"${DEVCONTAINER_TOOL_VERSIONS_FILE}"
		run bash "${INSTALLER}"
		[ "$status" -ne 0 ]
	done
	: >"${DEVCONTAINER_TOOL_VERSIONS_FILE}"
	run bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	[ ! -s "${LIKEC4_CALLS}" ]
	printf 'LOCK_LIKEC4_VERSION="1.60.0"\n' >"${DEVCONTAINER_TOOL_VERSIONS_FILE}"
	run env NODE_VERSION=v22.22.2 bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	[ ! -s "${LIKEC4_CALLS}" ]
	run env NPM_FAIL=1 bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	run env INSTALL_VERSION=1.59.0 bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	[[ "$output" == *'version mismatch'* ]]
	run env NODE_VERSION=v22.22.3 bash "${INSTALLER}"
	[ "$status" -eq 0 ]
}

@test "likec4 catalog declares Node dependency and executable installer" {
	grep -Fxq '2090-node-likec4.sh|enabled|2000-runtime-node.sh|npm' "${REPO_ROOT}/.devcontainer/install/dependencies.conf"
	[ "$(stat -c %a "${INSTALLER}")" = 755 ]
}
