#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	WORKSPACE="${TEST_ROOT}/workspace"
	HOME_DIR="${TEST_ROOT}/home"
	CALLS_FILE="${TEST_ROOT}/calls"

	mkdir -p "${WORKSPACE}/.devcontainer/lifecycle" \
		"${WORKSPACE}/.devcontainer/install/available" \
		"${WORKSPACE}/.devcontainer/install/01-foundation" \
		"${WORKSPACE}/.devcontainer/install/03-enabled" \
		"${WORKSPACE}/.devcontainer/install/02-core-tools" \
		"${WORKSPACE}/.devcontainer/install/lib" \
		"${WORKSPACE}/.taskfiles/scripts" \
		"${HOME_DIR}"
	cp "${REPO_ROOT}/.devcontainer/lifecycle/setup-volumes.sh" \
		"${WORKSPACE}/.devcontainer/lifecycle/setup-volumes.sh"
	cp "${REPO_ROOT}/.devcontainer/install/lib/activation.sh" "${WORKSPACE}/.devcontainer/install/lib/"
	cp "${REPO_ROOT}/.devcontainer/install/lib/selection.py" "${WORKSPACE}/.devcontainer/install/lib/"
	printf 'FROM foundation AS core-tools\nCOPY install/02-core-tools/ /install/02-core-tools/\nFROM core-tools AS devcontainer\n' >"${WORKSPACE}/.devcontainer/Dockerfile"
	touch "${WORKSPACE}/.devcontainer/install/dependencies.conf"
	cp "${REPO_ROOT}/.devcontainer/lifecycle/compose-volume-records.py" \
		"${WORKSPACE}/.devcontainer/lifecycle/compose-volume-records.py"
	cp "${REPO_ROOT}/.taskfiles/scripts/install.sh" \
		"${WORKSPACE}/.taskfiles/scripts/install.sh"
	cp "${REPO_ROOT}/.taskfiles/install.yml" "${WORKSPACE}/.taskfiles/"
	printf 'version: "3"\nincludes:\n  install: ./.taskfiles/install.yml\n' >"${WORKSPACE}/Taskfile.yml"
	cp "${REPO_ROOT}/.taskfiles/scripts/yq-compatibility.sh" \
		"${WORKSPACE}/.taskfiles/scripts/yq-compatibility.sh"
	cp "${REPO_ROOT}/.taskfiles/scripts/compose-manifest.py" "${WORKSPACE}/.taskfiles/scripts/"
	printf '%s\n' '{"service":"container-svc","dockerComposeFile":"docker-compose.yml"}' >"${WORKSPACE}/.devcontainer/devcontainer.json"
	printf '%s\n' 'services: {container-svc: {volumes: [{type: bind, source: ../.env.d/.pi, target: /home/ubuntu/.pi, bind: {create_host_path: false}}]}}' >"${WORKSPACE}/.devcontainer/docker-compose.yml"
	publish_manifest
	: >"${CALLS_FILE}"

	write_installer "3030-ai-pi-coding"
	write_installer "3040-ai-pi-gentle"
}

publish_manifest() {
	GENTLE_VOLUME_MANIFEST_ID="$(yq '.services."container-svc".volumes' "${WORKSPACE}/.devcontainer/docker-compose.yml" |
		PYTHONDONTWRITEBYTECODE=1 python3 "${REPO_ROOT}/.devcontainer/test/unit/manifest-fixture.py" "${WORKSPACE}")"
	export GENTLE_VOLUME_MANIFEST_ID PYTHONDONTWRITEBYTECODE=1
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
		"${WORKSPACE}/.devcontainer/install/03-enabled/${alias}"
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
				printf ".env.d/.pi\0/home/ubuntu/.pi\0"
			}
			repair_installed_volumes
		' _ "${WORKSPACE}/.devcontainer/lifecycle/setup-volumes.sh"
}

@test "core activation resolves custom canonical aliases" {
	write_installer "3000-ai-opencode"
	local link="${WORKSPACE}/.devcontainer/install/02-core-tools/47-custom.sh"
	ln -s ../available/3000-ai-opencode.sh "${link}"

	[ -L "${link}" ]
	[ "$(readlink "${link}")" = "../available/3000-ai-opencode.sh" ]
	[ -f "${link}" ]
	run env WORKSPACE_DIR="${WORKSPACE}" bash -c '
		source "$1"
		install_script_is_enabled "$2"
	' _ "${WORKSPACE}/.devcontainer/lifecycle/setup-volumes.sh" "${link}"
	[ "${status}" -eq 0 ]
}

@test "CodeGraph project database remains passive with its installer enabled" {
	write_installer "3060-ai-codegraph"
	enable_installer_as "3060-ai-codegraph" "3060-ai-codegraph.sh"
	printf '%s\n' 'services: {container-svc: {volumes: [{type: bind, source: ../.env.d/.codegraph, target: /home/ubuntu/project/.codegraph, bind: {create_host_path: false}}]}}' >"${WORKSPACE}/.devcontainer/docker-compose.yml"
	publish_manifest
	run env WORKSPACE_DIR="${WORKSPACE}" VOLUME_REPAIR_CALLS_FILE="${CALLS_FILE}" \
		bash -c 'source "$1"; repair_installed_volumes' _ "${WORKSPACE}/.devcontainer/lifecycle/setup-volumes.sh"
	[ "$status" -eq 0 ]
	[ ! -s "${CALLS_FILE}" ]
}

@test "enabling an optional fixture uses its canonical basename" {
	write_installer "3000-ai-opencode"

	run bash "${WORKSPACE}/.taskfiles/scripts/install.sh" enable 3000-ai-opencode

	[ "${status}" -eq 0 ]
	[ -L "${WORKSPACE}/.devcontainer/install/03-enabled/3000-ai-opencode.sh" ]
	[ "$(readlink "${WORKSPACE}/.devcontainer/install/03-enabled/3000-ai-opencode.sh")" = "../available/3000-ai-opencode.sh" ]
}

@test "runtime activation rejects a broken alias with a matching textual target basename" {
	ln -s /does/not/exist/3040-ai-pi-gentle.sh \
		"${WORKSPACE}/.devcontainer/install/03-enabled/79-broken-gentle.sh"

	run env WORKSPACE_DIR="${WORKSPACE}" bash -c '
		source "$1"
		install_script_is_enabled "$2"
	' _ "${WORKSPACE}/.devcontainer/lifecycle/setup-volumes.sh" \
		"${WORKSPACE}/.devcontainer/install/available/3040-ai-pi-gentle.sh"
	[ "${status}" -ne 0 ]
}

@test "disabling Pi Gentle preserves persisted Pi state" {
	local sentinel="${WORKSPACE}/.env.d/.pi/agent/npm/persisted-package"
	mkdir -p "$(dirname "${sentinel}")"
	printf 'keep\n' >"${sentinel}"
	enable_installer_as "3040-ai-pi-gentle" "80-pi-gentle.sh"

	run bash "${WORKSPACE}/.taskfiles/scripts/install.sh" disable 3040-ai-pi-gentle

	[ "${status}" -eq 0 ]
	[ ! -L "${WORKSPACE}/.devcontainer/install/03-enabled/80-pi-gentle.sh" ]
	[ "$(cat "${sentinel}")" = "keep" ]
}

@test "potential owner mapping remains independent from activation" {
	local scripts=()
	# shellcheck source=/dev/null
	WORKSPACE_DIR="${WORKSPACE}"
	source "${WORKSPACE}/.devcontainer/lifecycle/setup-volumes.sh"

	compose_target_to_install_scripts "/home/ubuntu/.pi" scripts

	[ "${scripts[*]}" = "3040-ai-pi-gentle" ]
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
	publish_manifest

	run env HOME="${HOME_DIR}" WORKSPACE_DIR="${WORKSPACE}" bash -c '
		source "$1"
		while IFS= read -r -d "" source && IFS= read -r -d "" target; do
			printf "%s|%s\n" "$source" "$target"
		done < <(resolve_compose_volume_targets)
	' _ "${WORKSPACE}/.devcontainer/lifecycle/setup-volumes.sh"

	[ "${status}" -eq 0 ]
	[ "${output}" = ".env.d/.pi|/home/ubuntu/.pi" ]
}

@test "volume parser transports odd long-syntax paths without delimiters or base64" {
	cat >"${WORKSPACE}/.devcontainer/docker-compose.yml" <<YAML
services:
  container-svc:
    volumes:
      - {type: bind, source: "../.env.d/a|b c", target: "${HOME_DIR}/.pi", bind: {create_host_path: false}}
YAML
	publish_manifest

	run env HOME="${HOME_DIR}" WORKSPACE_DIR="${WORKSPACE}" bash -c '
		source "$1"
		while IFS= read -r -d "" source && IFS= read -r -d "" target; do
			printf "source=<%s> target=<%s>\n" "$source" "$target"
		done < <(resolve_compose_volume_targets)
	' _ "${WORKSPACE}/.devcontainer/lifecycle/setup-volumes.sh"

	[ "${status}" -eq 0 ]
	[ "${output}" = "source=<.env.d/a|b c> target=<${HOME_DIR}/.pi>" ]
}

@test "install volume report preserves odd paths from structured transport" {
	cat >"${WORKSPACE}/.devcontainer/docker-compose.yml" <<YAML
services:
  container-svc:
    volumes:
      - {type: bind, source: "../.env.d/a|b c", target: "/home/ubuntu/.pi", bind: {create_host_path: false}}
YAML
	publish_manifest

	run env HOME="${HOME_DIR}" bash "${WORKSPACE}/.taskfiles/scripts/install.sh" volumes

	[ "${status}" -eq 0 ]
	[[ "${output}" == *".env.d/a|b c"* ]]
	[[ "${output}" == *"/home/ubuntu/.pi"* ]]
	[[ "${output}" == *"3040-ai-pi-gentle"* ]]
}

@test "volume repair accepts an arbitrary enabled alias" {
	enable_installer_as "3040-ai-pi-gentle" "47-custom-gentle.sh"

	run_pi_volume_repair

	[ "${status}" -eq 0 ]
	[ "$(cat "${CALLS_FILE}")" = "3040-ai-pi-gentle|runtime" ]
}

@test "volume repair skips a disabled mapped installer" {
	run_pi_volume_repair

	[ "${status}" -eq 0 ]
	[ ! -s "${CALLS_FILE}" ]
	[[ "${output}" != *"3040-ai-pi-gentle.sh"* ]]
}

@test "core Engram owner is repaired with Pi disabled" {
	write_installer "3010-ai-engram"
	ln -s ../available/3010-ai-engram.sh "${WORKSPACE}/.devcontainer/install/02-core-tools/47-memory.sh"
	printf '%s\n' 'services: {container-svc: {volumes: [{type: bind, source: ../.env.d/.engram, target: /home/ubuntu/.engram, bind: {create_host_path: false}}]}}' >"${WORKSPACE}/.devcontainer/docker-compose.yml"
	publish_manifest
	run env WORKSPACE_DIR="${WORKSPACE}" VOLUME_REPAIR_CALLS_FILE="${CALLS_FILE}" bash -c '
		source "$1"
		repair_installed_volumes
	' _ "${WORKSPACE}/.devcontainer/lifecycle/setup-volumes.sh"
	[ "${status}" -eq 0 ]
	[ "$(cat "${CALLS_FILE}")" = "3010-ai-engram|runtime" ]
}

@test "broken enabled symlinks do not activate mapped installers" {
	ln -s ../available/missing.sh \
		"${WORKSPACE}/.devcontainer/install/03-enabled/48-broken.sh"

	run_pi_volume_repair

	[ "${status}" -eq 0 ]
	[ ! -s "${CALLS_FILE}" ]
}

@test "Pi Coding is image-owned and never dispatched for runtime volume repair" {
	enable_installer_as "3030-ai-pi-coding" "70-pi-coding.sh"

	run_pi_volume_repair

	[ "${status}" -eq 0 ]
	[ ! -s "${CALLS_FILE}" ]
	[[ "${output}" != *"3030-ai-pi-coding.sh"* ]]
	[[ "${output}" != *"3040-ai-pi-gentle.sh"* ]]
}

@test "Task volumes reports selected desired Engram ownership without dispatch" {
	write_installer "3010-ai-engram"
	ln -s ../available/3010-ai-engram.sh "${WORKSPACE}/.devcontainer/install/02-core-tools/60-engram.sh"
	printf '%s\n' '{"service":"container-svc","dockerComposeFile":["docker-compose.yml","optional.yml"]}' >"${WORKSPACE}/.devcontainer/devcontainer.json"
	printf '%s\n' 'services: {}' >"${WORKSPACE}/.devcontainer/optional.yml"
	printf '%s\n' 'services: {container-svc: {volumes: [{type: bind, source: ../.env.d/.engram, target: /home/ubuntu/.engram, bind: {create_host_path: false}}]}}' >"${WORKSPACE}/.devcontainer/docker-compose.yml"
	publish_manifest
	run env -u GENTLE_VOLUME_MANIFEST_ID task --dir "${WORKSPACE}" install:volumes
	[ "$status" -eq 0 ]
	[[ "$output" == *"not proof of applied mounts"* ]]
	[[ "$output" == *"owned by: 3010-ai-engram"* ]]
	[[ "$output" == *"a selected Compose file"* ]]
	[ ! -s "${CALLS_FILE}" ]
}

@test "Task volumes fails before reporting a missing or stale manifest" {
	printf '\n# changed selected input\n' >>"${WORKSPACE}/.devcontainer/docker-compose.yml"
	run task --dir "${WORKSPACE}" install:volumes
	[ "$status" -ne 0 ]
	[[ "$output" == *"Stale volume manifest"* ]]
	[[ "$output" != *"=== install/ volume contract ==="* ]]
	rm "${WORKSPACE}/.devcontainer/.volume-manifest.json"
	run task --dir "${WORKSPACE}" install:volumes
	[ "$status" -ne 0 ]
	[[ "$output" != *"=== install/ volume contract ==="* ]]
	[ ! -s "${CALLS_FILE}" ]
}
