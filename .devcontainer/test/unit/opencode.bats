#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	INSTALLER="${REPO_ROOT}/.devcontainer/install/available/30-ai-opencode.sh"
	TEST_ROOT="$(mktemp -d)"
	HOME_DIR="${TEST_ROOT}/home"
	BIN_DIR="${TEST_ROOT}/bin"
	PROFILE_FILE="${HOME_DIR}/.bashrc"
	CALLS_FILE="${TEST_ROOT}/calls"
	PATH_RESULT_FILE="${TEST_ROOT}/opencode-path"
	mkdir -p "${HOME_DIR}" "${BIN_DIR}"
	: >"${CALLS_FILE}"
	export REPO_ROOT INSTALLER TEST_ROOT HOME_DIR BIN_DIR PROFILE_FILE CALLS_FILE PATH_RESULT_FILE
	write_id_stub
	write_curl_stub
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

write_id_stub() {
	cat >"${BIN_DIR}/id" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 1000
EOF
	chmod +x "${BIN_DIR}/id"
}

write_curl_stub() {
	cat >"${BIN_DIR}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl %s\n' "$*" >>"${CALLS_FILE}"
cat <<'INSTALLER'
#!/usr/bin/env bash
set -euo pipefail
install_dir="${OPENCODE_INSTALL_DIR:-${HOME}/.opencode/bin}"
mkdir -p "${install_dir}"
cat >"${install_dir}/opencode" <<'BINARY'
#!/usr/bin/env bash
printf 'opencode v1.2.3\n'
BINARY
chmod +x "${install_dir}/opencode"
command -v opencode >"${PATH_RESULT_FILE}"
INSTALLER
EOF
	chmod +x "${BIN_DIR}/curl"
}

run_installer() {
	run env HOME="${HOME_DIR}" \
		PATH="${BIN_DIR}:/usr/bin:/bin" \
		DEVCONTAINER_PHASE=runtime \
		OPENCODE_PROFILE_FILE="${PROFILE_FILE}" \
		CALLS_FILE="${CALLS_FILE}" \
		PATH_RESULT_FILE="${PATH_RESULT_FILE}" \
		bash "${INSTALLER}"
}

@test "installs at the official path, exposes it immediately, and skips reinstall on rerun" {
	run_installer

	[ "${status}" -eq 0 ]
	[ -x "${HOME_DIR}/.opencode/bin/opencode" ]
	[ "$("${HOME_DIR}/.opencode/bin/opencode" --version)" = "opencode v1.2.3" ]
	[ "$(cat "${PATH_RESULT_FILE}")" = "${HOME_DIR}/.opencode/bin/opencode" ]
	[[ "${output}" != *"binary was not found at"* ]]
	grep -Fqx "export PATH=\"${HOME_DIR}/.opencode/bin:\$PATH\"" "${PROFILE_FILE}"
	[ "$(grep -c '^curl ' "${CALLS_FILE}")" -eq 1 ]

	run_installer

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"already installed; auto-update disabled"* ]]
	[[ "${output}" != *"binary was not found at"* ]]
	[ "$(grep -c '^curl ' "${CALLS_FILE}")" -eq 1 ]
}

@test "honors an explicit install directory override when checking an existing binary" {
	custom_dir="${HOME_DIR}/custom-bin"
	mkdir -p "${custom_dir}"
	cat >"${custom_dir}/opencode" <<'EOF'
#!/usr/bin/env bash
printf 'opencode v9.9.9\n'
EOF
	chmod +x "${custom_dir}/opencode"

	run env HOME="${HOME_DIR}" \
		PATH="${BIN_DIR}:/usr/bin:/bin" \
		DEVCONTAINER_PHASE=runtime \
		OPENCODE_INSTALL_DIR="${custom_dir}" \
		OPENCODE_PROFILE_FILE="${PROFILE_FILE}" \
		CALLS_FILE="${CALLS_FILE}" \
		bash "${INSTALLER}"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"already installed; auto-update disabled"* ]]
	[[ "${output}" != *"binary was not found at"* ]]
	[ ! -s "${CALLS_FILE}" ]
	grep -Fqx "export PATH=\"${custom_dir}:\$PATH\"" "${PROFILE_FILE}"
}

@test "installs at the configured target despite a global opencode on PATH" {
	cat >"${BIN_DIR}/opencode" <<'EOF'
#!/usr/bin/env bash
printf 'opencode v0.0.1\n'
EOF
	chmod +x "${BIN_DIR}/opencode"

	run_installer

	[ "${status}" -eq 0 ]
	[ -x "${HOME_DIR}/.opencode/bin/opencode" ]
	[ "$("${HOME_DIR}/.opencode/bin/opencode" --version)" = "opencode v1.2.3" ]
	[ "$(grep -c '^curl ' "${CALLS_FILE}")" -eq 1 ]
	[[ "${output}" != *"binary was not found at"* ]]
}

@test "honors an explicit install directory override on first install" {
	custom_dir="${HOME_DIR}/custom-bin"

	run env HOME="${HOME_DIR}" \
		PATH="${BIN_DIR}:/usr/bin:/bin" \
		DEVCONTAINER_PHASE=runtime \
		OPENCODE_INSTALL_DIR="${custom_dir}" \
		OPENCODE_PROFILE_FILE="${PROFILE_FILE}" \
		CALLS_FILE="${CALLS_FILE}" \
		PATH_RESULT_FILE="${PATH_RESULT_FILE}" \
		bash "${INSTALLER}"

	[ "${status}" -eq 0 ]
	[ -x "${custom_dir}/opencode" ]
	[ "$(cat "${PATH_RESULT_FILE}")" = "${custom_dir}/opencode" ]
	[ "$(grep -c '^curl ' "${CALLS_FILE}")" -eq 1 ]
	[[ "${output}" != *"binary was not found at"* ]]
	grep -Fqx "export PATH=\"${custom_dir}:\$PATH\"" "${PROFILE_FILE}"
}
