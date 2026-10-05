# Trusted synthetic adapters; never execute a Python environment or package manager.
# shellcheck source=/dev/null
source "${APT_FIXTURE_RUNTIME:?}"
GRAPHIFY_STAGE=0

graphify_vector_is() {
	local count=$1 index
	shift
	local -a actual=("${@:1:count}") expected=("${@:count+1}")
	[ "${#actual[@]}" -eq "${#expected[@]}" ] || return 98
	for ((index = 0; index < ${#actual[@]}; index++)); do
		[ "${actual[index]}" = "${expected[index]}" ] || return 98
	done
}

graphify_paths_are_local() {
	case "${GRAPHIFY_INSTALL_DIR:?}:${GRAPHIFY_BIN_DIR:?}" in
	"${APT_FIXTURE_ROOT}/venv:${APT_FIXTURE_ROOT}/prefix" | "${APT_FIXTURE_ROOT}/custom-venv:${APT_FIXTURE_ROOT}/custom-prefix") ;;
	*) return 98 ;;
	esac
	[ ! -L "$APT_FIXTURE_ROOT" ] || return 98
	[ -d "${APT_FIXTURE_ROOT}/synthetic" ] && [ ! -L "${APT_FIXTURE_ROOT}/synthetic" ] || return 98
	[ ! -L "${APT_FIXTURE_ROOT}/synthetic/graphify" ] && [ ! -L "${APT_FIXTURE_ROOT}/synthetic/graphify-mcp" ] || return 98
}

graphify_validate_apt() {
	case "$GRAPHIFY_STAGE" in
	0) graphify_vector_is "$#" "$@" update ;;
	1) graphify_vector_is "$#" "$@" install -y --no-install-recommends python3-venv ;;
	*) return 98 ;;
	esac
}

devcontainer_run_as_root() {
	graphify_paths_are_local || return 98
	case "$GRAPHIFY_STAGE" in
	0 | 1)
		[ "${1:-}" = apt-get ] || return 98
		graphify_validate_apt "${@:2}" || return 98
		;;
	2) graphify_vector_is "$#" "$@" rm -rf "$GRAPHIFY_INSTALL_DIR" || return 98 ;;
	3) graphify_vector_is "$#" "$@" python3 -m venv "$GRAPHIFY_INSTALL_DIR" || return 98 ;;
	4) graphify_vector_is "$#" "$@" "$GRAPHIFY_INSTALL_DIR/bin/pip" install --no-cache-dir "graphifyy==${GRAPHIFY_VERSION:?}" || return 98 ;;
	5) graphify_vector_is "$#" "$@" ln -sfn "$GRAPHIFY_INSTALL_DIR/bin/graphify" "$GRAPHIFY_BIN_DIR/graphify" || return 98 ;;
	6) graphify_vector_is "$#" "$@" ln -sfn "$GRAPHIFY_INSTALL_DIR/bin/graphify-mcp" "$GRAPHIFY_BIN_DIR/graphify-mcp" || return 98 ;;
	*) return 98 ;;
	esac
	printf '%s\0' "$@" >"${APT_FIXTURE_ROOT}/root-$((GRAPHIFY_STAGE + 1))"
	if [ "$GRAPHIFY_STAGE" -lt 2 ]; then
		shift
		apt-get "$@"
	else
		graphify_complete_stage
	fi
}

graphify_complete_stage() {
	GRAPHIFY_STAGE=$((GRAPHIFY_STAGE + 1))
	[ "$GRAPHIFY_STAGE" -ne "${FAIL_STAGE:?}" ] || return "$((40 + GRAPHIFY_STAGE))"
	# Destructive operations, venv creation, pip and links are inert requests only.
	: >"${APT_FIXTURE_ROOT}/stage-${GRAPHIFY_STAGE}"
	if [ "$GRAPHIFY_STAGE" -eq 5 ]; then
		graphify_create_synthetic_clis
	fi
}

graphify_create_synthetic_clis() {
	local command
	for command in graphify graphify-mcp; do
		[ "${POST_MISSING:?}" != "$command" ] || continue
		# This exact fixture-local callback replaces package-generated executables.
		# Expand callback variables only in its isolated child process.
		# shellcheck disable=SC2016
		printf '%s\n' '#!/bin/bash' \
			'[ "$#" -eq 1 ] && [ "$1" = --version ] || exit 98' \
			'printf "%s\0" "$@" >>"${APT_FIXTURE_ROOT}/cli-probes"' \
			'[ "${CLI_STATUS:?}" -eq 0 ] || exit "$CLI_STATUS"' \
			'printf "Graphify fixture\n"' >"${APT_FIXTURE_ROOT}/synthetic/${command}"
		/usr/bin/chmod +x "${APT_FIXTURE_ROOT}/synthetic/${command}"
	done
}

apt_fixture_dispatch() {
	graphify_validate_apt "$@" || return 98
	graphify_complete_stage
}

devcontainer_load_tool_versions() {
	[ "$#" -eq 0 ] || return 98
	[ "${POLICY_STATUS:?}" -eq 0 ] || return "$POLICY_STATUS"
	# Installer-consumed lock state; central policy parsing has separate tests.
	# shellcheck disable=SC2034
	[ "${MISSING_LOCK:?}" -eq 1 ] || LOCK_GRAPHIFY_VERSION=0.9.5
}

devcontainer_has_cmd() {
	[ "$#" -eq 1 ] || return 98
	case "$1" in
	python3) [ "${PYTHON_PRESENT:?}" -eq 1 ] ;;
	graphify | graphify-mcp)
		if [ -f "${APT_FIXTURE_ROOT}/stage-7" ]; then
			[ -x "${APT_FIXTURE_ROOT}/synthetic/$1" ]
		elif [ "$1" = graphify ]; then
			[ "${EXISTING_GRAPHIFY:?}" -eq 1 ]
		else
			[ "${EXISTING_MCP:?}" -eq 1 ]
		fi
		;;
	*) return 98 ;;
	esac
}

python3() {
	if graphify_vector_is "$#" "$@" -c 'import sys; raise SystemExit(sys.version_info < (3, 10))'; then
		printf '%s\0' "$@" >>"${APT_FIXTURE_ROOT}/python-probes"
		return "${PYTHON_STATUS:?}"
	fi
	graphify_vector_is "$#" "$@" --version || return 98
	printf '%s\0' "$@" >>"${APT_FIXTURE_ROOT}/python-probes"
	printf 'Python fixture\n'
	return "${PYTHON_VERSION_STATUS:?}"
}

graphify() {
	graphify_vector_is "$#" "$@" --version || return 98
	if [ -f "${APT_FIXTURE_ROOT}/stage-7" ]; then
		[ -x "${APT_FIXTURE_ROOT}/synthetic/graphify" ] || return 127
		"${APT_FIXTURE_ROOT}/synthetic/graphify" "$@"
		return
	fi
	printf '%s\0' "$@" >>"${APT_FIXTURE_ROOT}/cli-probes"
	[ "${CLI_STATUS:?}" -eq 0 ] || return "$CLI_STATUS"
	printf 'Graphify fixture\n'
}

devcontainer_log_info() { printf '%s\n' "$*"; }
devcontainer_log_error() { printf '%s\n' "$*" >&2; }
