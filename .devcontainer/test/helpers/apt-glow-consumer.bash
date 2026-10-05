# shellcheck source=/dev/null
source "${APT_FIXTURE_RUNTIME:?}"

# Independently authored literal oracle; this text is never executed.
# shellcheck disable=SC2016
GLOW_REPOSITORY_SCRIPT='
set -euo pipefail
curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o "$1"
printf '\''%s\n'\'' "$2" > "$3"
'
GLOW_STAGE=0

glow_vector_is() {
	local separator=$1
	shift
	local -a actual=("${@:1:separator}") expected=("${@:separator+1}")
	[ "${#actual[@]}" -eq "${#expected[@]}" ] || return 98
	local index
	for ((index = 0; index < ${#actual[@]}; index++)); do
		[ "${actual[index]}" = "${expected[index]}" ] || return 98
	done
}

glow_validate_root() {
	case "$((GLOW_STAGE + 1))" in
	1 | 5) glow_vector_is "$#" "$@" apt-get update ;;
	2) glow_vector_is "$#" "$@" apt-get install -y --no-install-recommends gnupg ;;
	3) glow_vector_is "$#" "$@" mkdir -p /etc/apt/keyrings ;;
	4) glow_vector_is "$#" "$@" bash -lc "$GLOW_REPOSITORY_SCRIPT" -- "${EXPECT_KEY:?}" "${EXPECT_REPO:?}" "${EXPECT_LIST:?}" ;;
	6) glow_vector_is "$#" "$@" apt-get install -y --no-install-recommends glow ;;
	*) return 98 ;;
	esac
}

devcontainer_run_as_root() {
	glow_validate_root "$@" || return 98
	GLOW_STAGE=$((GLOW_STAGE + 1))
	printf '%s\0' "$@" >"${APT_FIXTURE_ROOT}/root-${GLOW_STAGE}"
	if [ "$1" = apt-get ]; then
		shift
		apt-get "$@"
	else
		glow_complete_stage
	fi
}

glow_complete_stage() {
	[ "$GLOW_STAGE" -ne "${FAIL_STAGE:?}" ] || return "$((40 + GLOW_STAGE))"
	: >"${APT_FIXTURE_ROOT}/stage-${GLOW_STAGE}"
}

apt_fixture_dispatch() {
	case "$GLOW_STAGE" in
	1 | 5) glow_vector_is "$#" "$@" update ;;
	2) glow_vector_is "$#" "$@" install -y --no-install-recommends gnupg ;;
	6) glow_vector_is "$#" "$@" install -y --no-install-recommends glow ;;
	*) return 98 ;;
	esac || return 98
	[ ! -e "${APT_FIXTURE_ROOT}/stage-${GLOW_STAGE}" ] || return 98
	glow_complete_stage
}

devcontainer_has_cmd() {
	glow_vector_is "$#" "$@" glow || return 98
	[ "${EXISTING:?}" -eq 1 ] || {
		[ "${OMIT_CLI:?}" -eq 0 ] && [ -e "${APT_FIXTURE_ROOT}/stage-6" ]
	}
}

glow() {
	glow_vector_is "$#" "$@" --version || return 98
	printf 'probe\n' >>"${APT_FIXTURE_ROOT}/probes"
	[ "${PROBE_FAILURE:?}" -eq 0 ] || return "$PROBE_FAILURE"
	printf 'glow 2.0.0\nignored second line\n'
}

head() {
	glow_vector_is "$#" "$@" -n 1 || return 98
	local line first=1
	while IFS= read -r line; do
		if [ "$first" -eq 1 ]; then
			printf '%s\n' "$line"
			first=0
		fi
	done
}

devcontainer_log_info() { printf '%s\n' "$*"; }
devcontainer_log_error() { printf '%s\n' "$*" >&2; }
