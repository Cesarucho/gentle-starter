#!/usr/bin/env bash
# Read-only compatibility gate for managed lock advancement.

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
	# $service below is a jq variable supplied by --arg.
	# shellcheck disable=SC2016
	yq -e --arg service "${service}" '.services[$service] | type == "object"' "${compose}" >/dev/null || return 1
	# $service below is a jq variable supplied by --arg.
	# shellcheck disable=SC2016
	[ "$(yq -r --arg service "${service}" '.services[$service].build.dockerfile' "${compose}")" = ./Dockerfile ] || return 1
	configured_features="$(sed '/^[[:space:]]*\/\//d' "${config}" | jq -cS '.features | keys')" || return 1
	locked_features="$(jq -cS '.features | keys' "${lock}")"
	[ "${configured_features}" = "${locked_features}" ] || {
		printf 'starter compatibility: devcontainer feature lock does not match project configuration\n' >&2
		return 1
	}
}
