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
	SETUP_EVENTS_FILE="${TEST_ROOT}/setup-events"
	WORKSPACE_REPAIR_EVENTS_FILE="${TEST_ROOT}/workspace-repair-events"
	CHOWN_LOG_FILE="${TEST_ROOT}/chown.log"
	PI_OWNER_FILE="${TEST_ROOT}/pi-owner"
	ENGRAM_OWNER_FILE="${TEST_ROOT}/engram-owner"
	GITCONFIG_OWNER_FILE="${TEST_ROOT}/gitconfig-owner"
	LOCAL_OWNER_FILE="${TEST_ROOT}/local-owner"
	SHARE_OWNER_FILE="${TEST_ROOT}/share-owner"
	OPENCODE_OWNER_FILE="${TEST_ROOT}/opencode-owner"
	OPENCODE_SENTINEL="${HOME_DIR}/.local/share/opencode/sentinel"
	mkdir -p "${HOME_DIR}" "${BIN_DIR}"
	: >"${CALLS_FILE}"
	export REPO_ROOT INSTALLER TEST_ROOT HOME_DIR BIN_DIR PROFILE_FILE CALLS_FILE PATH_RESULT_FILE
	export SETUP_WORKSPACE SETUP_CALLS_FILE SETUP_DOWNLOADS_FILE SETUP_EVENTS_FILE
	export WORKSPACE_REPAIR_EVENTS_FILE CHOWN_LOG_FILE
	export PI_OWNER_FILE ENGRAM_OWNER_FILE GITCONFIG_OWNER_FILE
	export LOCAL_OWNER_FILE SHARE_OWNER_FILE OPENCODE_OWNER_FILE OPENCODE_SENTINEL
	write_id_stub
	write_curl_stub
}

teardown() {
	sudo rm -rf "${TEST_ROOT}"
}

write_id_stub() {
	cat >"${BIN_DIR}/id" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
-u) printf '%s\n' "${TEST_RUNTIME_UID:-1000}" ;;
-g) printf '%s\n' "${TEST_RUNTIME_GID:-1000}" ;;
*) exec /usr/bin/id "$@" ;;
esac
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
		"${SETUP_WORKSPACE}/.devcontainer/opencode-config/nested" \
		"${SETUP_WORKSPACE}/.taskfiles/scripts" \
		"${HOME_DIR}/.config/opencode" \
		"${HOME_DIR}/.pi" \
		"${HOME_DIR}/.engram" \
		"${HOME_DIR}/.gitconfig-volume" \
		"${HOME_DIR}/.local/share/opencode"
	cp "${REPO_ROOT}/.devcontainer/setup.sh" "${SETUP_WORKSPACE}/.devcontainer/setup.sh"
	cp "${REPO_ROOT}/.devcontainer/setup-volumes.sh" "${SETUP_WORKSPACE}/.devcontainer/setup-volumes.sh"
	cp "${REPO_ROOT}/.taskfiles/scripts/yq-compatibility.sh" \
		"${SETUP_WORKSPACE}/.taskfiles/scripts/yq-compatibility.sh"
	printf 'project baseline\n' >"${SETUP_WORKSPACE}/.devcontainer/opencode-config/opencode.json"
	printf 'nested baseline\n' >"${SETUP_WORKSPACE}/.devcontainer/opencode-config/nested/agent.md"
	printf 'user customisation\n' >"${HOME_DIR}/.config/opencode/opencode.json"
	printf 'child payload\n' >"${OPENCODE_SENTINEL}"
	printf '0:0\n' >"${PI_OWNER_FILE}"
	printf '0:0\n' >"${ENGRAM_OWNER_FILE}"
	printf '0:0\n' >"${GITCONFIG_OWNER_FILE}"
	printf '0:0\n' >"${LOCAL_OWNER_FILE}"
	printf '0:0\n' >"${SHARE_OWNER_FILE}"
	printf '0:0\n' >"${OPENCODE_OWNER_FILE}"
	: >"${SETUP_EVENTS_FILE}"
	: >"${WORKSPACE_REPAIR_EVENTS_FILE}"
	: >"${CHOWN_LOG_FILE}"
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
	cat >"${SETUP_WORKSPACE}/.devcontainer/install/available/30-ai-engram.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${SETUP_VOLUME_TARGET}" in
"${HOME}/.engram")
	expected_owner="${TEST_RUNTIME_UID}:${TEST_RUNTIME_GID}"
	[ "$(cat "${ENGRAM_OWNER_FILE}")" = "${expected_owner}" ]
	[ "$(stat -c '%u:%g' -- "${HOME}/.engram")" = "${expected_owner}" ]
	;;
"${HOME}/.local")
	[ "$(cat "${LOCAL_OWNER_FILE}")" = "1234:2345" ]
	[ "$(cat "${SHARE_OWNER_FILE}")" = "1234:2345" ]
	[ "$(cat "${OPENCODE_OWNER_FILE}")" = "1234:2345" ]
	[ "$(cat "${OPENCODE_SENTINEL}")" = "child payload" ]
	;;
esac
printf 'engram-repair\n' >>"${SETUP_EVENTS_FILE}"
EOF
	chmod +x "${SETUP_WORKSPACE}/.devcontainer/install/available/30-ai-engram.sh"
	ln -s ../available/30-ai-engram.sh \
		"${SETUP_WORKSPACE}/.devcontainer/install/02-enabled/60-engram.sh"
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
set -euo pipefail
printf 'chown' >>"${CHOWN_LOG_FILE}"
printf ' %q' "$@" >>"${CHOWN_LOG_FILE}"
printf '\n' >>"${CHOWN_LOG_FILE}"
if printf '%s\n' "$@" | grep -Fqx "${SETUP_WORKSPACE}" ||
	printf '%s\n' "$@" | grep -Fq "${SETUP_WORKSPACE}/"; then
	printf 'workspace-chown\n' >>"${WORKSPACE_REPAIR_EVENTS_FILE}"
fi
exec /usr/bin/sudo -n /usr/bin/chown "$@"
EOF
	cat >"${BIN_DIR}/find" <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/find "$@"
EOF
	cat >"${BIN_DIR}/python3" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "${1:-}" = "-" ]
cat >/dev/null
path="$2"
owner="$3:$4"
mode="$5"
case "${path}" in
"${HOME_DIR}/.pi")
	printf '%s\n' "${owner}" >"${PI_OWNER_FILE}"
	printf 'repair-pi\n' >>"${SETUP_EVENTS_FILE}"
	if [ "$(/usr/bin/stat -c '%u' -- "${path}")" -eq 0 ]; then
		/usr/bin/sudo -n /bin/chown "${owner}" "${path}"
	fi
	;;
"${HOME_DIR}/.engram")
	printf '%s\n' "${owner}" >"${ENGRAM_OWNER_FILE}"
	printf 'repair-engram\n' >>"${SETUP_EVENTS_FILE}"
	if [ "$(/usr/bin/stat -c '%u' -- "${path}")" -eq 0 ]; then
		/usr/bin/sudo -n /bin/chown "${owner}" "${path}"
	fi
	;;
"${HOME_DIR}/.gitconfig-volume")
	printf '%s\n' "${owner}" >"${GITCONFIG_OWNER_FILE}"
	printf 'repair-gitconfig\n' >>"${SETUP_EVENTS_FILE}"
	if [ "$(/usr/bin/stat -c '%u' -- "${path}")" -eq 0 ]; then
		/usr/bin/sudo -n /bin/chown "${owner}" "${path}"
	fi
	;;
"${HOME_DIR}/.local")
	printf '%s\n' "${owner}" >"${LOCAL_OWNER_FILE}"
	printf 'repair-local\n' >>"${SETUP_EVENTS_FILE}"
	;;
"${HOME_DIR}/.local/share")
	printf '%s\n' "${owner}" >"${SHARE_OWNER_FILE}"
	printf 'repair-share\n' >>"${SETUP_EVENTS_FILE}"
	;;
"${HOME_DIR}/.local/share/opencode")
	printf '%s\n' "${owner}" >"${OPENCODE_OWNER_FILE}"
	printf 'repair-opencode\n' >>"${SETUP_EVENTS_FILE}"
	;;
*) exit 2 ;;
esac
/bin/chmod "${mode}" "${path}"
EOF
	cat >"${BIN_DIR}/cp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "${SETUP_WORKSPACE}/.devcontainer/pi-config/nested/seed.txt" ]; then
	expected_owner="${TEST_RUNTIME_UID}:${TEST_RUNTIME_GID}"
	[ "$(cat "${PI_OWNER_FILE}")" = "${expected_owner}" ]
	[ "$(cat "${GITCONFIG_OWNER_FILE}")" = "${expected_owner}" ]
	[ "$(stat -c '%u:%g' -- "${HOME_DIR}/.pi")" = "${expected_owner}" ]
	[ "$(stat -c '%u:%g' -- "${HOME_DIR}/.gitconfig-volume")" = "${expected_owner}" ]
	printf 'seed-pi\n' >>"${SETUP_EVENTS_FILE}"
fi
exec /bin/cp "$@"
EOF
	cat >"${BIN_DIR}/stat" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -eq 4 ] && [ "$1" = "-c" ] && [ "$2" = "%u:%g:%a" ] && [ "$3" = "--" ]; then
	case "$4" in
	"${HOME_DIR}/.local")
		printf '%s:%s\n' "$(cat "${LOCAL_OWNER_FILE}")" "$(/usr/bin/stat -c '%a' -- "$4")"
		exit 0
		;;
	"${HOME_DIR}/.local/share")
		printf '%s:%s\n' "$(cat "${SHARE_OWNER_FILE}")" "$(/usr/bin/stat -c '%a' -- "$4")"
		exit 0
		;;
	"${HOME_DIR}/.local/share/opencode")
		printf '%s:%s\n' "$(cat "${OPENCODE_OWNER_FILE}")" "$(/usr/bin/stat -c '%a' -- "$4")"
		exit 0
		;;
	esac
fi
exec /usr/bin/stat "$@"
EOF
	cat >"${BIN_DIR}/git" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *" ls-files "* ]] && [[ " $* " == *" --ignored "* ]]; then
	printf 'gitignore-prune\n' >>"${WORKSPACE_REPAIR_EVENTS_FILE}"
	if [ -d "${SETUP_WORKSPACE}/.env.d" ]; then
		printf '.env.d/\0'
	fi
	exit 0
fi
if [[ " $* " == *" ls-files "* ]] && [[ " $* " == *" --stage "* ]]; then
	if [ -f "${SETUP_WORKSPACE}/regression.bats" ]; then
		printf '100755 %040d 0\tregression.bats\0' 0
	fi
	if [ -e "${SETUP_WORKSPACE}/module.sh" ]; then
		printf '100644 %040d 0\tmodule.sh\0' 0
	fi
	if [ -e "${SETUP_WORKSPACE}/tracked-link.sh" ]; then
		printf '100644 %040d 0\ttracked-link.sh\0' 0
	fi
	exit 0
fi
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
if [ "${1:-}" = --version ]; then
	printf 'yq 0.0.0\n'
	exit 0
fi
if [ "${1:-}" = --help ]; then
	printf 'yq: jq wrapper for YAML documents\n  --yaml-output\n'
	exit 0
fi
if [ -n "${SETUP_VOLUME_TARGET:-}" ]; then
	printf '../.env.d/.local:%s\n' "${SETUP_VOLUME_TARGET}"
fi
EOF
	chmod +x "${BIN_DIR}/sudo" "${BIN_DIR}/chown" "${BIN_DIR}/find" "${BIN_DIR}/python3" \
		"${BIN_DIR}/cp" "${BIN_DIR}/stat" "${BIN_DIR}/git" "${BIN_DIR}/jq" "${BIN_DIR}/yq"
}

run_setup() {
	run env HOME="${HOME_DIR}" \
		PATH="${BIN_DIR}:/usr/bin:/bin" \
		TEST_RUNTIME_UID="${TEST_RUNTIME_UID:-1000}" \
		TEST_RUNTIME_GID="${TEST_RUNTIME_GID:-1000}" \
		SETUP_VOLUME_TARGET="${SETUP_VOLUME_TARGET:-}" \
		SETUP_EVENTS_FILE="${SETUP_EVENTS_FILE}" \
		PI_OWNER_FILE="${PI_OWNER_FILE}" \
		ENGRAM_OWNER_FILE="${ENGRAM_OWNER_FILE}" \
		GITCONFIG_OWNER_FILE="${GITCONFIG_OWNER_FILE}" \
		LOCAL_OWNER_FILE="${LOCAL_OWNER_FILE}" \
		SHARE_OWNER_FILE="${SHARE_OWNER_FILE}" \
		OPENCODE_OWNER_FILE="${OPENCODE_OWNER_FILE}" \
		OPENCODE_SENTINEL="${OPENCODE_SENTINEL}" \
		OPENCODE_SETUP_CALLS_FILE="${SETUP_CALLS_FILE}" \
		OPENCODE_SETUP_DOWNLOADS_FILE="${SETUP_DOWNLOADS_FILE}" \
		bash "${SETUP_WORKSPACE}/.devcontainer/setup.sh"
}

path_metadata() {
	stat -c '%u:%g:%a' "$1"
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

@test "install enable repairs a broken alias with a matching textual target basename" {
	local cli_workspace="${TEST_ROOT}/install-cli-workspace"
	mkdir -p "${cli_workspace}/.devcontainer/install/available" \
		"${cli_workspace}/.devcontainer/install/02-enabled" \
		"${cli_workspace}/.taskfiles/scripts"
	cp "${REPO_ROOT}/.taskfiles/scripts/install.sh" \
		"${cli_workspace}/.taskfiles/scripts/install.sh"
	printf '#!/usr/bin/env bash\n' \
		>"${cli_workspace}/.devcontainer/install/available/30-ai-pi-gentle.sh"
	ln -s /does/not/exist/30-ai-pi-gentle.sh \
		"${cli_workspace}/.devcontainer/install/02-enabled/79-broken-gentle.sh"

	run bash "${cli_workspace}/.taskfiles/scripts/install.sh" enable 30-ai-pi-gentle

	[ "${status}" -eq 0 ]
	[ -L "${cli_workspace}/.devcontainer/install/02-enabled/80-pi-gentle.sh" ]
	[ "$(readlink "${cli_workspace}/.devcontainer/install/02-enabled/80-pi-gentle.sh")" = \
		"../available/30-ai-pi-gentle.sh" ]
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

@test "workspace repair fixes tracked paths while preserving ignored descendants and symlink targets" {
	prepare_setup_sandbox
	local tracked_dir="${SETUP_WORKSPACE}/tracked"
	local tracked_file="${tracked_dir}/tracked.txt"
	local ignored_dir="${SETUP_WORKSPACE}/.env.d"
	local ignored_share="${ignored_dir}/.opencode/share"
	local ignored_sentinel="${ignored_share}/sentinel"
	local symlink_target="${TEST_ROOT}/symlink-target"
	local workspace_link="${SETUP_WORKSPACE}/tracked-link"
	mkdir -p "${tracked_dir}" "${ignored_share}" "${symlink_target}"
	printf '.env.d/\n' >"${SETUP_WORKSPACE}/.gitignore"
	printf 'tracked payload\n' >"${tracked_file}"
	printf 'ignored payload\n' >"${ignored_sentinel}"
	printf 'target payload\n' >"${symlink_target}/sentinel"
	ln -s "${symlink_target}" "${workspace_link}"
	sudo chown -R 0:0 "${tracked_dir}" "${ignored_dir}" "${symlink_target}"
	sudo chown -h 0:0 "${workspace_link}"
	sudo chmod 0755 "${tracked_dir}"
	sudo chmod 0600 "${tracked_file}"
	sudo chmod 0711 "${ignored_dir}" "${ignored_dir}/.opencode" "${ignored_share}" "${symlink_target}"
	sudo chmod 0600 "${ignored_sentinel}" "${symlink_target}/sentinel"
	local ignored_before target_before
	ignored_before="$(path_metadata "${ignored_dir}")|$(path_metadata "${ignored_dir}/.opencode")|$(path_metadata "${ignored_share}")|$(path_metadata "${ignored_sentinel}")|$(sudo cat "${ignored_sentinel}")"
	target_before="$(path_metadata "${symlink_target}")|$(path_metadata "${symlink_target}/sentinel")|$(sudo cat "${symlink_target}/sentinel")"

	run_setup

	[ "${status}" -eq 0 ]
	[ "$(path_metadata "${tracked_dir}")" = "1000:1000:755" ]
	[ "$(path_metadata "${tracked_file}")" = "1000:1000:644" ]
	[ "$(cat "${tracked_file}")" = "tracked payload" ]
	[ "$(path_metadata "${ignored_dir}")|$(path_metadata "${ignored_dir}/.opencode")|$(path_metadata "${ignored_share}")|$(path_metadata "${ignored_sentinel}")|$(sudo cat "${ignored_sentinel}")" = "${ignored_before}" ]
	[ "$(path_metadata "${symlink_target}")|$(path_metadata "${symlink_target}/sentinel")|$(sudo cat "${symlink_target}/sentinel")" = "${target_before}" ]
	[ -L "${workspace_link}" ]
	[ "$(readlink "${workspace_link}")" = "${symlink_target}" ]
	[ "$(sed -n '1p' "${WORKSPACE_REPAIR_EVENTS_FILE}")" = "gitignore-prune" ]
	[ "$(sed -n '2p' "${WORKSPACE_REPAIR_EVENTS_FILE}")" = "workspace-chown" ]
	grep -Fq "${tracked_file}" "${CHOWN_LOG_FILE}"
	! grep -Fq "${ignored_dir}" "${CHOWN_LOG_FILE}"
}

@test "workspace repair restores mixed Git-index file modes without following symlinks" {
	prepare_setup_sandbox
	local bats_file="${SETUP_WORKSPACE}/regression.bats"
	local shell_module="${SETUP_WORKSPACE}/module.sh"
	local ordinary_file="${SETUP_WORKSPACE}/notes.txt"
	local symlink_target="${TEST_ROOT}/tracked-link-target"
	local tracked_link="${SETUP_WORKSPACE}/tracked-link.sh"
	printf '#!/usr/bin/env bats\n' >"${bats_file}"
	printf 'shell module\n' >"${shell_module}"
	printf 'ordinary payload\n' >"${ordinary_file}"
	printf 'external payload\n' >"${symlink_target}"
	ln -s "${symlink_target}" "${tracked_link}"
	chmod 0600 "${bats_file}" "${shell_module}" "${ordinary_file}" "${symlink_target}"

	run_setup

	[ "${status}" -eq 0 ]
	[ "$(stat -c '%a' "${bats_file}")" = "755" ]
	[ "$(stat -c '%a' "${shell_module}")" = "644" ]
	[ "$(stat -c '%a' "${ordinary_file}")" = "644" ]
	[ -L "${tracked_link}" ]
	[ "$(stat -c '%a' "${symlink_target}")" = "600" ]
}

@test "workspace chown builds prune args first and uses no-follow semantics" {
	local implementation build_line chown_line
	implementation="$(sed -n '/^# Fix project file permissions/,/^# Copy the file tree/p' "${REPO_ROOT}/.devcontainer/setup.sh")"
	build_line="$(grep -nF 'build_gitignore_prune_args gitignore_prune_args' <<<"${implementation}" | cut -d: -f1)"
	chown_line="$(grep -nF 'sudo find -P "${WORKSPACE_DIR}" "${gitignore_prune_args[@]}" -exec chown --no-dereference "${UID}:${UID}" -- {} +' <<<"${implementation}" | cut -d: -f1)"

	[ -n "${build_line}" ]
	[ -n "${chown_line}" ]
	[ "${build_line}" -lt "${chown_line}" ]
	[[ "${implementation}" != *'sudo chown -R "${UID}:${UID}" "${WORKSPACE_DIR}"'* ]]
}

@test "setup seeds missing OpenCode config recursively and preserves existing user config" {
	prepare_setup_sandbox

	run_setup

	[ "${status}" -eq 0 ]
	[ "$(cat "${HOME_DIR}/.config/opencode/nested/agent.md")" = "nested baseline" ]
	[ "$(cat "${HOME_DIR}/.config/opencode/opencode.json")" = "user customisation" ]

	run_setup

	[ "${status}" -eq 0 ]
	[ "$(cat "${HOME_DIR}/.config/opencode/nested/agent.md")" = "nested baseline" ]
	[ "$(cat "${HOME_DIR}/.config/opencode/opencode.json")" = "user customisation" ]
}

@test "seeded OpenCode plugins use the split review and SDD implementations" {
	local plugins_dir="${REPO_ROOT}/.devcontainer/opencode-config/plugins"
	local sdd_plugin="${plugins_dir}/sdd-task-result-artifacts.ts"

	[ -f "${plugins_dir}/opencode-review-transport.ts" ]
	[ -f "${sdd_plugin}" ]
	[ ! -e "${plugins_dir}/review-result-artifacts.ts" ]
	grep -Eq '^const SDD_PHASES = \[.*"sdd-research".*\]$' "${sdd_plugin}"
}

@test "OpenCode share state is passive and has no repair installer mapping" {
	local scripts=("sentinel")
	WORKSPACE_DIR="${REPO_ROOT}"
	# shellcheck source=/dev/null
	source "${REPO_ROOT}/.devcontainer/setup-volumes.sh"

	compose_target_to_install_scripts "/home/ubuntu/.local/share/opencode" scripts

	[ "${#scripts[@]}" -eq 0 ]
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
