# shellcheck source=/dev/null
source "${APT_FIXTURE_RUNTIME:?}"
PHP_STAGE=0

php_vector_is() {
	local count=$1 index
	shift
	local -a actual=("${@:1:count}") expected=("${@:count+1}")
	[ "${#actual[@]}" -eq "${#expected[@]}" ] || return 98
	for ((index = 0; index < ${#actual[@]}; index++)); do
		[ "${actual[index]}" = "${expected[index]}" ] || return 98
	done
}

php_complete_stage() {
	PHP_STAGE=$((PHP_STAGE + 1))
	[ "$PHP_STAGE" -ne "${FAIL_STAGE:?}" ] || return "$((40 + PHP_STAGE))"
	: >"${APT_FIXTURE_ROOT}/stage-${PHP_STAGE}"
}

php_validate_apt() {
	case "$1" in
	1 | 4)
		shift
		php_vector_is "$#" "$@" update -qq
		;;
	2)
		shift
		php_vector_is "$#" "$@" install -y --no-install-recommends software-properties-common
		;;
	5)
		shift
		php_vector_is "$#" "$@" install -y --no-install-recommends \
			"php${EXPECT_SERIES:?}-cli" "php${EXPECT_SERIES}-curl" \
			"php${EXPECT_SERIES}-mbstring" "php${EXPECT_SERIES}-xml" "php${EXPECT_SERIES}-zip"
		;;
	*) return 98 ;;
	esac
}

devcontainer_run_as_root() {
	local next=$((PHP_STAGE + 1))
	case "$next" in
	1 | 2 | 4 | 5)
		[ "${1:-}" = apt-get ] || return 98
		php_validate_apt "$next" "${@:2}" || return 98
		;;
	7)
		php_vector_is "$#" "$@" php /tmp/composer-setup.php -- --install-dir=/usr/local/bin --filename=composer || return 98
		[ -f "${APT_FIXTURE_ROOT}/tmp/composer-setup.php" ] || return 98
		;;
	*) return 98 ;;
	esac
	printf '%s\0' "$@" >"${APT_FIXTURE_ROOT}/root-${next}"
	if [ "$next" -eq 7 ]; then
		# Downloaded bytes remain data: never invoke PHP or install into /usr.
		php_complete_stage
	else
		shift
		apt-get "$@"
	fi
}

apt_fixture_dispatch() {
	php_validate_apt "$((PHP_STAGE + 1))" "$@" || return 98
	php_complete_stage
}

add-apt-repository() {
	[ "$PHP_STAGE" -eq 2 ] || return 98
	php_vector_is "$#" "$@" -y ppa:ondrej/php || return 98
	printf '%s\0' "$@" >"${APT_FIXTURE_ROOT}/ppa"
	php_complete_stage || return "$?"
	return "${PPA_STATUS:?}"
}

devcontainer_fetch() {
	php_vector_is "$#" "$@" https://getcomposer.org/installer /tmp/composer-setup.php || return 98
	curl -fsSL -o "$2" "$1"
}

curl() {
	[ "$PHP_STAGE" -eq 5 ] || return 98
	php_vector_is "$#" "$@" -fsSL -o /tmp/composer-setup.php https://getcomposer.org/installer || return 98
	printf '%s\0' "$@" >"${APT_FIXTURE_ROOT}/download"
	php_complete_stage || return "$?"
	# Deliberately executable-looking marker; root adapter must never run it.
	# shellcheck disable=SC2016
	printf '%s\n' ': >"${APT_FIXTURE_ROOT}/download-executed"' >"${APT_FIXTURE_ROOT}/tmp/composer-setup.php"
}

rm() {
	[ "$PHP_STAGE" -eq 7 ] || return 98
	php_vector_is "$#" "$@" -f /tmp/composer-setup.php || return 98
	printf '%s\0' "$@" >"${APT_FIXTURE_ROOT}/cleanup"
	# Exact fixed operand maps only to this fixture; no absolute-path fallthrough.
	/usr/bin/rm -f "${APT_FIXTURE_ROOT}/tmp/composer-setup.php"
}

devcontainer_load_tool_versions() {
	[ "${POLICY_STATUS:?}" -eq 0 ] || return "$POLICY_STATUS"
	if [ "${MISSING_LOCK:?}" -eq 0 ]; then
		# shellcheck disable=SC2034
		LOCK_PHP_SERIES=8.4
	fi
}

devcontainer_has_cmd() {
	php_vector_is "$#" "$@" php || return 98
	[ "${EXISTING:?}" -eq 1 ]
}

php() {
	php_vector_is "$#" "$@" --version || return 98
	printf 'php\n' >>"${APT_FIXTURE_ROOT}/probes"
	[ "${PHP_PROBE_STATUS:?}" -eq 0 ] || return "$PHP_PROBE_STATUS"
	printf 'PHP fixture\nignored PHP line\n'
}

composer() {
	php_vector_is "$#" "$@" --version || return 98
	printf 'composer\n' >>"${APT_FIXTURE_ROOT}/probes"
	[ "${COMPOSER_PROBE_STATUS:?}" -eq 0 ] || return "$COMPOSER_PROBE_STATUS"
	[ "${COMPOSER_EXISTING:?}" -eq 1 ] || [ -e "${APT_FIXTURE_ROOT}/stage-7" ] || return 127
	printf 'Composer fixture\nignored Composer line\n'
}

head() {
	php_vector_is "$#" "$@" -1 || return 98
	local line first=1
	while IFS= read -r line; do
		if [ "$first" -eq 1 ]; then
			printf '%s\n' "$line"
			first=0
		fi
	done
}

devcontainer_log_info() { printf '%s\n' "$*"; }
