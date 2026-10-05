# shellcheck source=/dev/null
source "${APT_FIXTURE_RUNTIME:?}"

devcontainer_run_as_root() {
	[ "$#" -ge 1 ] && [ "$1" = apt-get ] || return 98
	shift
	apt-get "$@"
}

apt_fixture_dispatch() {
	[ "${DEVCONTAINER_PHASE:?}" = build ] || return 98
	if [ "$#" -eq 2 ] && [ "$1" = update ] && [ "$2" = -qq ]; then
		[ ! -e "${APT_FIXTURE_ROOT}/updated" ] || return 98
		[ "${UPDATE_FAILURE:?}" -eq 0 ] || return "$UPDATE_FAILURE"
		: >"${APT_FIXTURE_ROOT}/updated"
		return 0
	fi
	[ "$#" -eq 4 ] && [ "$1" = install ] && [ "$2" = -y ] &&
		[ "$3" = -qq ] && [ "$4" = "${PACKAGE:?}" ] || return 98
	[ -e "${APT_FIXTURE_ROOT}/updated" ] &&
		[ ! -e "${APT_FIXTURE_ROOT}/installed" ] || return 98
	[ "${INSTALL_FAILURE:?}" -eq 0 ] || return "$INSTALL_FAILURE"
	: >"${APT_FIXTURE_ROOT}/installed"
}

devcontainer_is_build() {
	[ "$#" -eq 0 ] || return 98
	[ "${DEVCONTAINER_PHASE:?}" = build ]
}

# The server runtime branch is deliberately outside this consumer's contract.
devcontainer_is_runtime() {
	: >"${APT_FIXTURE_ROOT}/runtime-request"
	return 98
}
devcontainer_log_info() { printf '%s\n' "$*"; }
