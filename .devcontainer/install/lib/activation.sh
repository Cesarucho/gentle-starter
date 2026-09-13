#!/usr/bin/env bash
# Canonical activation shared by host helpers, runtime setup, and tests.
# Results include the group so lexical comparison preserves build-stage order.
devcontainer_active_aliases() {
	local install_root="$1" script_path="$2"
	shift 2
	local canonical_script canonical_available group link canonical_link
	[ -f "${script_path}" ] || return 0
	canonical_available="$(readlink -f -- "${install_root}/available")" || return 0
	canonical_script="$(readlink -f -- "${script_path}")" || return 0
	case "${canonical_script}" in
	"${canonical_available}/"*.sh) ;;
	*) return 0 ;;
	esac
	if [ "$#" -eq 0 ]; then
		set -- 02-core-tools 03-enabled
	fi
	for group in "$@"; do
		for link in "${install_root}/${group}/"*.sh; do
			if [ ! -L "${link}" ] || [ ! -f "${link}" ]; then
				continue
			fi
			canonical_link="$(readlink -f -- "${link}")" || continue
			if [ "${canonical_link}" = "${canonical_script}" ]; then
				printf '%s/%s\n' "${group}" "${link##*/}"
			fi
		done
	done
}

devcontainer_install_is_active() {
	local aliases
	aliases="$(devcontainer_active_aliases "$@")" || return 1
	[ -n "${aliases}" ]
}
