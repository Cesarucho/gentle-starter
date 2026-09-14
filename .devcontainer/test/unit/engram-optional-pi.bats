#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	INSTALL_DIR="${TEST_ROOT}/bin"
	CALLS_FILE="${TEST_ROOT}/calls"
	mkdir -p "${INSTALL_DIR}" "${TEST_ROOT}/install/available" "${TEST_ROOT}/install/lib"
	cp "${REPO_ROOT}/.devcontainer/install/available/3010-ai-engram.sh" "${TEST_ROOT}/install/available/"
	cp "${REPO_ROOT}/.devcontainer/install/lib/common.sh" "${TEST_ROOT}/install/lib/"
	cp "${REPO_ROOT}/.devcontainer/install/lib/tar-archive.sh" "${TEST_ROOT}/install/lib/"
	cp "${REPO_ROOT}/.devcontainer/tool-versions.conf" "${TEST_ROOT}/tool-versions.conf"
	cat >"${INSTALL_DIR}/engram" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = version ]; then printf 'engram version 1.20.0\n'; exit 0; fi
printf '%s\n' "$*" >>"${ENGRAM_CALLS_FILE}"
[ "${ENGRAM_SETUP_FAIL:-0}" = 0 ] || exit 42
EOF
	chmod +x "${INSTALL_DIR}/engram"
}

teardown() { rm -rf "${TEST_ROOT}"; }

run_installer() {
	local setup_pi="${1:-0}"
	run env HOME="${TEST_ROOT}/home" PATH="${TEST_ROOT}/path:/usr/bin:/bin" \
		DEVCONTAINER_PHASE=runtime ENGRAM_INSTALL_DIR="${INSTALL_DIR}" \
		ENGRAM_SETUP_PI="${setup_pi}" \
		ENGRAM_PROFILE_FILE="${TEST_ROOT}/profile" ENGRAM_DATA_DIR="${TEST_ROOT}/data" \
		ENGRAM_CALLS_FILE="${CALLS_FILE}" \
		DEVCONTAINER_TOOL_VERSIONS_FILE="${TEST_ROOT}/tool-versions.conf" \
		bash "${TEST_ROOT}/install/available/3010-ai-engram.sh"
}

@test "explicit Engram Pi setup succeeds standalone and warns when Pi is absent" {
	mkdir -p "${TEST_ROOT}/home" "${TEST_ROOT}/path"
	run env HOME="${TEST_ROOT}/home" PATH="${TEST_ROOT}/path:/usr/bin:/bin" DEVCONTAINER_PHASE=runtime \
		ENGRAM_SETUP_PI=1 ENGRAM_PI_COMMAND=missing-pi \
		ENGRAM_INSTALL_DIR="${INSTALL_DIR}" ENGRAM_PROFILE_FILE="${TEST_ROOT}/profile" \
		ENGRAM_DATA_DIR="${TEST_ROOT}/data" ENGRAM_CALLS_FILE="${CALLS_FILE}" \
		DEVCONTAINER_TOOL_VERSIONS_FILE="${TEST_ROOT}/tool-versions.conf" \
		/usr/bin/bash "${TEST_ROOT}/install/available/3010-ai-engram.sh"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Engram is ready for standalone use"* ]]
	[ ! -e "${CALLS_FILE}" ]
}

@test "explicit Engram Pi setup configures Pi and preserves integration failures" {
	mkdir -p "${TEST_ROOT}/home" "${TEST_ROOT}/path"
	printf '#!/usr/bin/env bash\nexit 0\n' >"${TEST_ROOT}/path/pi"
	chmod +x "${TEST_ROOT}/path/pi"
	run_installer 1
	[ "$status" -eq 0 ]
	[ "$(cat "${CALLS_FILE}")" = "setup pi" ]

	: >"${CALLS_FILE}"
	run env HOME="${TEST_ROOT}/home" PATH="${TEST_ROOT}/path:/usr/bin:/bin" DEVCONTAINER_PHASE=runtime \
		ENGRAM_SETUP_PI=1 ENGRAM_INSTALL_DIR="${INSTALL_DIR}" ENGRAM_PROFILE_FILE="${TEST_ROOT}/profile" \
		ENGRAM_DATA_DIR="${TEST_ROOT}/data" ENGRAM_CALLS_FILE="${CALLS_FILE}" ENGRAM_SETUP_FAIL=1 \
		DEVCONTAINER_TOOL_VERSIONS_FILE="${TEST_ROOT}/tool-versions.conf" \
		bash "${TEST_ROOT}/install/available/3010-ai-engram.sh"
	[ "$status" -eq 42 ]
}

@test "Engram leaves Pi package state to the Pi installer by default" {
	mkdir -p "${TEST_ROOT}/home" "${TEST_ROOT}/path"
	printf '#!/usr/bin/env bash\nexit 0\n' >"${TEST_ROOT}/path/pi"
	chmod +x "${TEST_ROOT}/path/pi"
	run_installer
	[ "$status" -eq 0 ]
	[[ "$output" == *"ENGRAM_SETUP_PI=0"* ]]
	[ ! -e "${CALLS_FILE}" ]
}
