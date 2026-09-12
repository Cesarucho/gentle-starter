#!/usr/bin/env bash

# Test-only selection: aliases are execution slots, not installer identities.
is_enabled_install() {
	local install_dir="${BATS_TEST_DIRNAME}/../../install"
	local expected link resolved
	expected="$(realpath -e "${install_dir}/available/$1")" || return 2
	for link in "${install_dir}/02-enabled/"*.sh; do
		[ -e "${link}" ] || [ -L "${link}" ] || continue
		resolved="$(realpath -e "${link}")" || return 2
		if [ "${resolved}" = "${expected}" ]; then
			return 0
		fi
	done
	return 1
}

skip_if_install_disabled() {
	local status=0
	is_enabled_install "$1" || status=$?
	case "${status}" in
	0) return 0 ;;
	1) skip "disabled install ($2)" ;;
	*) return "${status}" ;;
	esac
}
