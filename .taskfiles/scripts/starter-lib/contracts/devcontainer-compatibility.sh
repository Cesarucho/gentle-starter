#!/usr/bin/env bash
# Read-only compatibility gate for managed lock advancement.

YQ_COMPATIBILITY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/yq-compatibility.sh"
# shellcheck source=.taskfiles/scripts/starter-lib/contracts/yq-compatibility.sh
source "${YQ_COMPATIBILITY_PATH}"

starter_devcontainer_compatibility_validate() {
	local root="$1" config compose lock dockerfile tool_policy service configured_features locked_features
	config="${root}/.devcontainer/devcontainer.json"
	compose="${root}/.devcontainer/docker-compose.yml"
	lock="${root}/.devcontainer/devcontainer-lock.json"
	dockerfile="${root}/.devcontainer/Dockerfile"
	tool_policy="${root}/.devcontainer/tool-versions.conf"
	for path in "${config}" "${compose}" "${lock}" "${dockerfile}" "${tool_policy}"; do
		[ -f "${path}" ] && [ ! -L "${path}" ] || return 1
	done
	service="$(sed '/^[[:space:]]*\/\//d' "${config}" | jq -r '.service')" || return 1
	yq_compatibility_service_is_object "${service}" "${compose}" || return 1
	[ "$(yq_compatibility_service_dockerfile "${service}" "${compose}")" = ./Dockerfile ] || return 1
	configured_features="$(sed '/^[[:space:]]*\/\//d' "${config}" | jq -cS '.features | keys')" || return 1
	locked_features="$(jq -cS '.features | keys' "${lock}")"
	[ "${configured_features}" = "${locked_features}" ] || {
		printf 'starter compatibility: devcontainer feature lock does not match project configuration\n' >&2
		return 1
	}
}
