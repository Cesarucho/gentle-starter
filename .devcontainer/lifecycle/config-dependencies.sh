#!/usr/bin/env bash
# Sourced by setup.sh; install only in the explicitly mapped runtime config tree.

install_config_dependencies() {
	local source_root="$1" target_root="$2" resolved_target resolved_home status
	[ -e "${source_root}/package.json" ] || return 0
	resolved_home="$(realpath -e -- "${HOME}")" || return 1
	resolved_target="$(realpath -e -- "${target_root}")" || return 1
	if [ -L "${source_root}/package.json" ] || [ -L "${target_root}" ] ||
		[ -L "${target_root}/package.json" ] || [ ! -f "${target_root}/package.json" ] ||
		[[ "${resolved_target}" != "${resolved_home}/"* ]] ||
		[ "$(stat -c %u -- "${resolved_target}")" != "$(id -u)" ] ||
		[ ! -w "${resolved_target}" ]; then
		printf '[setup:error] Unsafe config dependency target: %s\n' "${target_root}" >&2
		return 1
	fi
	if ! jq -se 'length == 1 and (.[0] | type == "object")' "${target_root}/package.json" >/dev/null 2>&1; then
		printf '[setup:error] Invalid config package.json: %s\n' "${target_root}" >&2
		return 1
	fi
	printf '[setup] Installing config dependencies: %s\n' "${target_root}"
	if (cd -- "${resolved_target}" && npm install --global=false --prefix "${resolved_target}" --ignore-scripts --no-audit --no-fund); then
		return 0
	else
		status=$?
		printf '[setup:error] Config dependency installation failed: %s (exit %s)\n' "${target_root}" "${status}" >&2
		return "${status}"
	fi
}

seed_config_with_dependencies() {
	seed_config_tree "$1" "$2" || return "$?"
	install_config_dependencies "$1" "$2"
}
