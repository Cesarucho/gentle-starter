# Closed APT plumbing for trusted consumer callbacks, not a security sandbox.
setup_apt_fixture() {
	case "$1" in
	"${BATS_TEST_TMPDIR:?}/"*) ;;
	*)
		printf 'APT fixture must be inside BATS_TEST_TMPDIR\n' >&2
		return 1
		;;
	esac
	[[ "$1" != *'/../'* && "$1" != */.. ]] || return 1
	APT_FIXTURE_ROOT="$1"
	APT_FIXTURE_CALLS="$1/apt-calls"
	APT_FIXTURE_RUNTIME="$1/apt-runtime.bash"
	mkdir -p "$1/home" "$1/tmp" "$1/bin" "$APT_FIXTURE_CALLS"
	# Only these read-only utilities are required by the unchanged installers.
	ln -s /usr/bin/dirname "$1/bin/dirname"
	local name
	for name in apt-get sudo; do
		cat >"$1/bin/$name" <<'SH'
#!/bin/bash
printf 'APT fixture dispatcher not loaded\n' >&2
exit 93
SH
		chmod +x "$1/bin/$name"
	done
	cat >"$APT_FIXTURE_RUNTIME" <<'SH'
apt-get() {
    local number=1
    while [ -e "${APT_FIXTURE_CALLS}/${number}" ]; do
        number=$((number + 1))
    done
    : >"${APT_FIXTURE_CALLS}/${number}"
    if [ "$#" -gt 0 ]; then
        printf '%s\0' "$@" >"${APT_FIXTURE_CALLS}/${number}"
    fi
    declare -F apt_fixture_dispatch >/dev/null || return 93
    apt_fixture_dispatch "$@"
}
SH
}

run_apt_fixture() {
	local installer="$1" consumer_env="$2" assignment
	shift 2
	for assignment in "$@"; do
		[[ "$assignment" =~ ^[a-zA-Z_][a-zA-Z_0-9]*= ]] || return 1
		case "${assignment%%=*}" in
		HOME | TMPDIR | PATH | BASH_ENV | ENV | SHELLOPTS | BASHOPTS | APT_FIXTURE_*)
			printf 'Reserved APT fixture environment key\n' >&2
			return 1
			;;
		esac
	done
	run /usr/bin/env -i PATH="${APT_FIXTURE_ROOT}/bin" \
		HOME="${APT_FIXTURE_ROOT}/home" TMPDIR="${APT_FIXTURE_ROOT}/tmp" \
		APT_FIXTURE_ROOT="$APT_FIXTURE_ROOT" \
		APT_FIXTURE_CALLS="$APT_FIXTURE_CALLS" \
		APT_FIXTURE_RUNTIME="$APT_FIXTURE_RUNTIME" \
		BASH_ENV="$consumer_env" "$@" /bin/bash "$installer"
}
