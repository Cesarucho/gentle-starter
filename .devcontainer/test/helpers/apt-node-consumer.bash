# shellcheck source=/dev/null
source "${APT_FIXTURE_RUNTIME:?}"

devcontainer_load_tool_versions() {
	[ "$#" -eq 0 ] || return 98
	[ "${POLICY_FAILURE:?}" -eq 0 ] || return "$POLICY_FAILURE"
	# Consumed by the unchanged installer after the policy callback returns.
	# shellcheck disable=SC2034
	LOCK_NODE_MAJOR="${LOCK_VALUE:?}"
}

devcontainer_has_cmd() {
	[ "$#" -eq 1 ] && [ "$1" = node ] || return 98
	[ "${EXISTING:?}" -eq 1 ]
}

devcontainer_log_info() { printf '%s\n' "$*"; }

curl() {
	[ "$#" -eq 2 ] && [ "$1" = -fsSL ] &&
		[ "$2" = "https://deb.nodesource.com/setup_${LOCK_VALUE:?}.x" ] || return 98
	printf '%s\0' "$@" >"${APT_FIXTURE_ROOT}/curl-args"
	[ "${CURL_FAILURE:?}" -eq 0 ] || return "$CURL_FAILURE"
	# This payload must be consumed as data, never passed to an actual shell.
	# shellcheck disable=SC2016
	printf ': >"${APT_FIXTURE_ROOT}/download-executed"\n'
}

devcontainer_run_as_root() {
	[ "$#" -ge 1 ] || return 98
	case "$1" in
	bash)
		[ "$#" -eq 2 ] && [ "$2" = - ] || return 98
		printf '%s\0' "$@" >"${APT_FIXTURE_ROOT}/bootstrap-args"
		local payload
		IFS= read -r payload || return 98
		# Match literal shell text without expanding or evaluating it.
		# shellcheck disable=SC2016
		[ "$payload" = ': >"${APT_FIXTURE_ROOT}/download-executed"' ] || return 98
		[ "${BOOTSTRAP_FAILURE:?}" -eq 0 ] || return "$BOOTSTRAP_FAILURE"
		: >"${APT_FIXTURE_ROOT}/bootstrapped"
		;;
	apt-get)
		shift
		apt-get "$@"
		;;
	*) return 98 ;;
	esac
}

apt_fixture_dispatch() {
	[ "$#" -eq 4 ] && [ "$1" = install ] && [ "$2" = -y ] &&
		[ "$3" = --no-install-recommends ] && [ "$4" = nodejs ] || return 98
	[ -e "${APT_FIXTURE_ROOT}/bootstrapped" ] &&
		[ ! -e "${APT_FIXTURE_ROOT}/installed" ] || return 98
	[ "${INSTALL_FAILURE:?}" -eq 0 ] || return "$INSTALL_FAILURE"
	: >"${APT_FIXTURE_ROOT}/installed"
}

node() {
	[ "$#" -eq 1 ] && [ "$1" = --version ] || return 98
	[ "${EXISTING:?}" -eq 1 ] || [ -e "${APT_FIXTURE_ROOT}/installed" ] || return 127
	[ "${NODE_FAILURE:?}" -eq 0 ] || return "$NODE_FAILURE"
	printf '%s\n' "${NODE_VERSION:?}"
}

npm() {
	if [ "$#" -gt 0 ]; then
		printf '%s\0' "$@" >>"${APT_FIXTURE_ROOT}/npm-args"
	else
		: >>"${APT_FIXTURE_ROOT}/npm-args"
	fi
	[ "$#" -eq 1 ] && [ "$1" = --version ] || return 98
	[ -e "${APT_FIXTURE_ROOT}/installed" ] || return 127
	[ "${NPM_FAILURE:?}" -eq 0 ] || return "$NPM_FAILURE"
	printf '10.1.0\n'
}
