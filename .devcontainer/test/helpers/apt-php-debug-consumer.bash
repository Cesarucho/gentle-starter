# Trusted consumer adapters, not a hostile-code sandbox.
# shellcheck source=/dev/null
source "${APT_FIXTURE_RUNTIME:?}"
DEBUG_STAGE=0

debug_vector_is() {
	local count=$1 index
	shift
	local -a actual=("${@:1:count}") expected=("${@:count+1}")
	[ "${#actual[@]}" -eq "${#expected[@]}" ] || return 98
	for ((index = 0; index < ${#actual[@]}; index++)); do
		[ "${actual[index]}" = "${expected[index]}" ] || return 98
	done
}

debug_validate_apt() {
	case "$DEBUG_STAGE" in
	0) debug_vector_is "$#" "$@" update -qq ;;
	1) debug_vector_is "$#" "$@" install -y --no-install-recommends "php${MAJOR:?}.${MINOR:?}-xdebug" ;;
	*) return 98 ;;
	esac
}

devcontainer_run_as_root() {
	[ "${1:-}" = apt-get ] || return 98
	debug_validate_apt "${@:2}" || return 98
	printf '%s\0' "$@" >"${APT_FIXTURE_ROOT}/root-$((DEBUG_STAGE + 1))"
	shift
	apt-get "$@"
}

apt_fixture_dispatch() {
	debug_validate_apt "$@" || return 98
	DEBUG_STAGE=$((DEBUG_STAGE + 1))
	[ "$DEBUG_STAGE" -ne "${FAIL_STAGE:?}" ] || return "$((40 + DEBUG_STAGE))"
	: >"${APT_FIXTURE_ROOT}/stage-${DEBUG_STAGE}"
}

devcontainer_has_cmd() {
	debug_vector_is "$#" "$@" php || return 98
	[ "${PHP_PRESENT:?}" -eq 1 ]
}

devcontainer_require_cmd() {
	debug_vector_is "$#" "$@" php 'Enable 2300-php-lang.sh before Xdebug.' || return 98
	if ! devcontainer_has_cmd php; then
		devcontainer_log_error 'Required command not found: php. Enable 2300-php-lang.sh before Xdebug.'
		return 1
	fi
}

php() {
	[[ "${MAJOR:?}" =~ ^[0-9]+$ && "${MINOR:?}" =~ ^[0-9]+$ ]] || return 98
	printf '%s\0' "$@" >>"${APT_FIXTURE_ROOT}/php-probes"
	if debug_vector_is "$#" "$@" -r 'echo PHP_MAJOR_VERSION;'; then
		[ "${MAJOR_STATUS:?}" -eq 0 ] || return "$MAJOR_STATUS"
		printf '%s' "${MAJOR:?}"
	elif debug_vector_is "$#" "$@" -r 'echo PHP_MINOR_VERSION;'; then
		[ "${MINOR_STATUS:?}" -eq 0 ] || return "$MINOR_STATUS"
		printf '%s' "${MINOR:?}"
	else
		debug_vector_is "$#" "$@" -m || return 98
		local count=0
		[ ! -f "${APT_FIXTURE_ROOT}/module-count" ] || read -r count <"${APT_FIXTURE_ROOT}/module-count"
		count=$((count + 1))
		printf '%s\n' "$count" >"${APT_FIXTURE_ROOT}/module-count"
		if [ "$count" -ge 3 ]; then
			[ "${LOG_STATUS:?}" -eq 0 ] || return "$LOG_STATUS"
		else
			[ "${MODULE_STATUS:?}" -eq 0 ] || return "$MODULE_STATUS"
		fi
		printf 'Core\n'
		if [ "${LOADED:?}" -eq 1 ] || { [ -f "${APT_FIXTURE_ROOT}/stage-2" ] && [ "${POST_LOADED:?}" -eq 1 ]; }; then
			printf 'XdEbUg\n'
		fi
	fi
}

grep() {
	if debug_vector_is "$#" "$@" -qi xdebug || debug_vector_is "$#" "$@" -i xdebug; then
		/usr/bin/grep "$@"
	else
		return 98
	fi
}

cat() {
	[ "$#" -eq 0 ] || return 98
	[ -f "${APT_FIXTURE_ROOT}/stage-2" ] || return 98
	# The verified remapped shell performs the redirection; preserve literal stdin.
	/usr/bin/cat
}

mkdir() { return 98; }
devcontainer_log_info() { printf '%s\n' "$*"; }
devcontainer_log_warn() { printf '%s\n' "$*"; }
devcontainer_log_error() { printf '%s\n' "$*" >&2; }
