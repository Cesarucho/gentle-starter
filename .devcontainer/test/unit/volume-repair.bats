#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	WORKSPACE="${TEST_ROOT}/workspace"
	HOME_DIR="${TEST_ROOT}/home"
	CALLS_FILE="${TEST_ROOT}/calls"

	mkdir -p "${WORKSPACE}/.devcontainer/install/available" \
		"${WORKSPACE}/.devcontainer/install/02-enabled" \
		"${WORKSPACE}/.taskfiles/scripts" \
		"${HOME_DIR}"
	cp "${REPO_ROOT}/.devcontainer/setup-volumes.sh" \
		"${WORKSPACE}/.devcontainer/setup-volumes.sh"
	cp "${REPO_ROOT}/.devcontainer/compose-volume-records.py" \
		"${WORKSPACE}/.devcontainer/compose-volume-records.py"
	cp "${REPO_ROOT}/.taskfiles/scripts/install.sh" \
		"${WORKSPACE}/.taskfiles/scripts/install.sh"
	cp "${REPO_ROOT}/.taskfiles/scripts/yq-compatibility.sh" \
		"${WORKSPACE}/.taskfiles/scripts/yq-compatibility.sh"
	: >"${CALLS_FILE}"

	write_installer "30-ai-pi-coding"
	write_installer "30-ai-pi-gentle"
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

write_installer() {
	local name="$1"
	cat >"${WORKSPACE}/.devcontainer/install/available/${name}.sh" <<EOF
#!/usr/bin/env bash
printf '%s|%s\n' '${name}' "\${DEVCONTAINER_PHASE}" >>"\${VOLUME_REPAIR_CALLS_FILE}"
EOF
	chmod +x "${WORKSPACE}/.devcontainer/install/available/${name}.sh"
}

enable_installer_as() {
	local name="$1"
	local alias="$2"
	ln -s "../available/${name}.sh" \
		"${WORKSPACE}/.devcontainer/install/02-enabled/${alias}"
}

run_pi_volume_repair() {
	# Variables expand inside the child shell.
	# shellcheck disable=SC2016
	run env HOME="${HOME_DIR}" \
		WORKSPACE_DIR="${WORKSPACE}" \
		VOLUME_REPAIR_CALLS_FILE="${CALLS_FILE}" \
		bash -c '
			source "$1"
			resolve_compose_volume_targets() {
				printf "../.env.d/.pi\0%s/.pi\0" "${HOME}"
			}
			repair_installed_volumes
		' _ "${WORKSPACE}/.devcontainer/setup-volumes.sh"
}

@test "OpenCode is enabled by default in ordered slot 55" {
	local link="${REPO_ROOT}/.devcontainer/install/02-enabled/55-opencode.sh"

	[ -L "${link}" ]
	[ "$(readlink "${link}")" = "../available/30-ai-opencode.sh" ]
	[ -f "${link}" ]
}

@test "enabling OpenCode recreates ordered slot 55" {
	write_installer "30-ai-opencode"

	run bash "${WORKSPACE}/.taskfiles/scripts/install.sh" enable 30-ai-opencode

	[ "${status}" -eq 0 ]
	[ -L "${WORKSPACE}/.devcontainer/install/02-enabled/55-opencode.sh" ]
	[ "$(readlink "${WORKSPACE}/.devcontainer/install/02-enabled/55-opencode.sh")" = "../available/30-ai-opencode.sh" ]
}

@test "enabling repairs a broken alias with a matching textual target basename" {
	ln -s /does/not/exist/30-ai-pi-gentle.sh \
		"${WORKSPACE}/.devcontainer/install/02-enabled/79-broken-gentle.sh"

	run bash "${WORKSPACE}/.taskfiles/scripts/install.sh" enable 30-ai-pi-gentle

	[ "${status}" -eq 0 ]
	[ -L "${WORKSPACE}/.devcontainer/install/02-enabled/80-pi-gentle.sh" ]
	[ "$(readlink "${WORKSPACE}/.devcontainer/install/02-enabled/80-pi-gentle.sh")" = "../available/30-ai-pi-gentle.sh" ]
	run env WORKSPACE_DIR="${WORKSPACE}" bash -c '
		source "$1"
		install_script_is_enabled "$2"
	' _ "${WORKSPACE}/.devcontainer/setup-volumes.sh" \
		"${WORKSPACE}/.devcontainer/install/available/30-ai-pi-gentle.sh"
	[ "${status}" -eq 0 ]
}

@test "disabling Pi Gentle preserves persisted Pi state" {
	local sentinel="${WORKSPACE}/.env.d/.pi/agent/npm/persisted-package"
	mkdir -p "$(dirname "${sentinel}")"
	printf 'keep\n' >"${sentinel}"
	enable_installer_as "30-ai-pi-gentle" "80-pi-gentle.sh"

	run bash "${WORKSPACE}/.taskfiles/scripts/install.sh" disable 30-ai-pi-gentle

	[ "${status}" -eq 0 ]
	[ ! -L "${WORKSPACE}/.devcontainer/install/02-enabled/80-pi-gentle.sh" ]
	[ "$(cat "${sentinel}")" = "keep" ]
}

@test "potential owner mapping remains independent from activation" {
	local scripts=()
	# shellcheck source=/dev/null
	WORKSPACE_DIR="${WORKSPACE}"
	source "${WORKSPACE}/.devcontainer/setup-volumes.sh"

	compose_target_to_install_scripts "/home/${UID}/.pi" scripts

	[ "${scripts[*]}" = "30-ai-pi-coding 30-ai-pi-gentle" ]
}

@test "volume parser supports long syntax and ignores long-syntax named volumes" {
	cat >"${WORKSPACE}/.devcontainer/docker-compose.yml" <<'YAML'
services:
  container-svc:
    volumes:
      - type: bind
        source: ../.env.d/.pi
        target: /home/ubuntu/.pi
        bind:
          create_host_path: false
      - type: volume
        source: named-state
        target: /var/lib/state
YAML

	run env HOME="${HOME_DIR}" WORKSPACE_DIR="${WORKSPACE}" bash -c '
		source "$1"
		while IFS= read -r -d "" source && IFS= read -r -d "" target; do
			printf "%s|%s\n" "$source" "$target"
		done < <(resolve_compose_volume_targets)
	' _ "${WORKSPACE}/.devcontainer/setup-volumes.sh"

	[ "${status}" -eq 0 ]
	[ "${output}" = "../.env.d/.pi|/home/ubuntu/.pi" ]
}

@test "volume parser transports odd long-syntax paths without delimiters or base64" {
	cat >"${WORKSPACE}/.devcontainer/docker-compose.yml" <<YAML
services:
  container-svc:
    volumes:
      - {type: bind, source: "../.env.d/a|b c", target: "${HOME_DIR}/.pi", bind: {create_host_path: false}}
YAML

	run env HOME="${HOME_DIR}" WORKSPACE_DIR="${WORKSPACE}" bash -c '
		source "$1"
		while IFS= read -r -d "" source && IFS= read -r -d "" target; do
			printf "source=<%s> target=<%s>\n" "$source" "$target"
		done < <(resolve_compose_volume_targets)
	' _ "${WORKSPACE}/.devcontainer/setup-volumes.sh"

	[ "${status}" -eq 0 ]
	[ "${output}" = "source=<../.env.d/a|b c> target=<${HOME_DIR}/.pi>" ]
}

@test "install volume report preserves odd paths from structured transport" {
	cat >"${WORKSPACE}/.devcontainer/docker-compose.yml" <<YAML
services:
  container-svc:
    volumes:
      - {type: bind, source: "../.env.d/a|b c", target: "${HOME_DIR}/.pi", bind: {create_host_path: false}}
YAML

	run env HOME="${HOME_DIR}" bash "${WORKSPACE}/.taskfiles/scripts/install.sh" volumes

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"../.env.d/a|b c"* ]]
	[[ "${output}" == *"${HOME_DIR}/.pi"* ]]
	[[ "${output}" == *"30-ai-pi-coding 30-ai-pi-gentle"* ]]
}

@test "volume repair accepts an arbitrary enabled alias" {
	enable_installer_as "30-ai-pi-gentle" "47-custom-gentle.sh"

	run_pi_volume_repair

	[ "${status}" -eq 0 ]
	[ "$(cat "${CALLS_FILE}")" = "30-ai-pi-gentle|runtime" ]
}

@test "volume repair skips a disabled mapped installer" {
	run_pi_volume_repair

	[ "${status}" -eq 0 ]
	[ ! -s "${CALLS_FILE}" ]
	[[ "${output}" != *"30-ai-pi-gentle.sh"* ]]
}

@test "broken enabled symlinks do not activate mapped installers" {
	ln -s ../available/missing.sh \
		"${WORKSPACE}/.devcontainer/install/02-enabled/48-broken.sh"

	run_pi_volume_repair

	[ "${status}" -eq 0 ]
	[ ! -s "${CALLS_FILE}" ]
}

@test "Pi Coding still repairs when Pi Gentle is disabled" {
	enable_installer_as "30-ai-pi-coding" "70-pi-coding.sh"

	run_pi_volume_repair

	[ "${status}" -eq 0 ]
	[ "$(cat "${CALLS_FILE}")" = "30-ai-pi-coding|runtime" ]
	[[ "${output}" == *"30-ai-pi-coding.sh"* ]]
	[[ "${output}" != *"30-ai-pi-gentle.sh"* ]]
}
