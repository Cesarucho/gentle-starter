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
	SETUP_WORKSPACE="${TEST_ROOT}/workspace"
	SETUP_CALLS_FILE="${TEST_ROOT}/setup-opencode-calls"
	SETUP_DOWNLOADS_FILE="${TEST_ROOT}/setup-opencode-downloads"
	mkdir -p "${HOME_DIR}" "${BIN_DIR}"
	: >"${CALLS_FILE}"
	export REPO_ROOT INSTALLER TEST_ROOT HOME_DIR BIN_DIR PROFILE_FILE CALLS_FILE PATH_RESULT_FILE
	export SETUP_WORKSPACE SETUP_CALLS_FILE SETUP_DOWNLOADS_FILE
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

prepare_setup_sandbox() {
	mkdir -p "${SETUP_WORKSPACE}/.devcontainer/install/available" \
		"${SETUP_WORKSPACE}/.devcontainer/install/02-enabled" \
		"${HOME_DIR}/.gitconfig-volume"
	cp "${REPO_ROOT}/.devcontainer/setup.sh" "${SETUP_WORKSPACE}/.devcontainer/setup.sh"
	cp "${REPO_ROOT}/.devcontainer/setup-volumes.sh" "${SETUP_WORKSPACE}/.devcontainer/setup-volumes.sh"
	touch "${SETUP_WORKSPACE}/.devcontainer/docker-compose.yml"
	cat >"${SETUP_WORKSPACE}/.devcontainer/install/available/30-ai-opencode.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${DEVCONTAINER_PHASE}" >>"${OPENCODE_SETUP_CALLS_FILE}"
if [ ! -x "${HOME}/.opencode/bin/opencode" ]; then
	printf 'download\n' >>"${OPENCODE_SETUP_DOWNLOADS_FILE}"
	mkdir -p "${HOME}/.opencode/bin"
	touch "${HOME}/.opencode/bin/opencode"
	chmod +x "${HOME}/.opencode/bin/opencode"
fi
EOF
	chmod +x "${SETUP_WORKSPACE}/.devcontainer/install/available/30-ai-opencode.sh"
	: >"${SETUP_CALLS_FILE}"
	: >"${SETUP_DOWNLOADS_FILE}"
	write_setup_command_stubs
}

write_setup_command_stubs() {
	cat >"${BIN_DIR}/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
	cat >"${BIN_DIR}/chown" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
	cat >"${BIN_DIR}/find" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
	cat >"${BIN_DIR}/git" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *" --get-all "* ]]; then
	exit 1
fi
exit 0
EOF
	cat >"${BIN_DIR}/jq" <<'EOF'
#!/usr/bin/env bash
printf '{}\n'
EOF
	cat >"${BIN_DIR}/yq" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
	chmod +x "${BIN_DIR}/sudo" "${BIN_DIR}/chown" "${BIN_DIR}/find" \
		"${BIN_DIR}/git" "${BIN_DIR}/jq" "${BIN_DIR}/yq"
}

run_setup() {
	run env HOME="${HOME_DIR}" \
		PATH="${BIN_DIR}:/usr/bin:/bin" \
		OPENCODE_SETUP_CALLS_FILE="${SETUP_CALLS_FILE}" \
		OPENCODE_SETUP_DOWNLOADS_FILE="${SETUP_DOWNLOADS_FILE}" \
		bash "${SETUP_WORKSPACE}/.devcontainer/setup.sh"
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

@test "setup skips OpenCode when its canonical installer is not enabled" {
	prepare_setup_sandbox
	ln -s ../available/unrelated.sh "${SETUP_WORKSPACE}/.devcontainer/install/02-enabled/10-unrelated.sh"

	run_setup

	[ "${status}" -eq 0 ]
	[ ! -s "${SETUP_CALLS_FILE}" ]
}

@test "setup invokes enabled OpenCode through an arbitrary ordered alias and preserves installer idempotency" {
	prepare_setup_sandbox
	ln -s ../available/30-ai-opencode.sh "${SETUP_WORKSPACE}/.devcontainer/install/02-enabled/47-custom-slot.sh"
	ln -s ../available/missing.sh "${SETUP_WORKSPACE}/.devcontainer/install/02-enabled/48-broken.sh"
	ln -s ../available/unrelated.sh "${SETUP_WORKSPACE}/.devcontainer/install/02-enabled/49-unrelated.sh"

	run_setup

	[ "${status}" -eq 0 ]
	[ "$(cat "${SETUP_CALLS_FILE}")" = "runtime" ]
	[ "$(wc -l <"${SETUP_DOWNLOADS_FILE}")" -eq 1 ]

	run_setup

	[ "${status}" -eq 0 ]
	[ "$(wc -l <"${SETUP_CALLS_FILE}")" -eq 2 ]
	[ "$(wc -l <"${SETUP_DOWNLOADS_FILE}")" -eq 1 ]
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
