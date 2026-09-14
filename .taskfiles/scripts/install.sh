#!/usr/bin/env bash
# install.sh — task helpers for the .devcontainer/install/ layout.
#
# Used by .taskfiles/install.yml. Not intended to be run directly,
# but works fine that way too.
#
# The runtime groups carry a numeric prefix (01-foundation, 02-core-tools,
# 03-enabled, 04-hooks) as a visual hint of execution order. The prefix is not
# load-bearing for ordering: the Dockerfile iterates the groups
# explicitly, and within each group the Dockerfile sorts the entries
# by filename.
#
# Commands:
#   help                       Show this help
#   list                       List foundation, core tools, optional tools,
#                              hooks, and available/ scripts not active.
#   enable NAME                Activate NAME and missing required dependencies
#                              with canonical-named 03-enabled/ symlinks
#   disable NAME               Remove the 03-enabled/ symlink for NAME.sh
#   doctor                     Verify the install/ layout integrity
#   versions-validate          Validate the declarative tool-version policy
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INSTALL_DIR="${REPO_ROOT}/.devcontainer/install"
DEPENDENCIES_FILE="${INSTALL_DIR}/dependencies.conf"
# shellcheck source=/dev/null
source "${INSTALL_DIR}/lib/activation.sh"

usage() {
	cat <<'EOF'
Usage:
  install.sh <command> [args]

Commands:
  help                  Show this help
  list                  List foundation, mandatory core tools, optional tools, hooks
                        and available/ scripts not enabled.
  enable NAME           Activate NAME and required dependencies; reuse mandatory core
  disable NAME          Remove the optional 03-enabled/ symlink for NAME.sh
  doctor                Verify the install/ layout integrity
  versions-validate     Validate .devcontainer/tool-versions.conf
  volumes               Print desired bind mounts and potential owners from
                        the validated selected Compose manifest, not applied mounts
EOF
}

validate_installer_name() {
	case "$1" in
	*/* | . | ..)
		echo "ERROR: NAME must be a filename, not a path" >&2
		return 1
		;;
	esac
}

is_available_enabled() {
	local base="$1"
	devcontainer_install_is_active "${INSTALL_DIR}" "${INSTALL_DIR}/available/${base}"
}

validate_enabled_dependencies() {
	python3 "${INSTALL_DIR}/lib/selection.py" "${INSTALL_DIR}" validate
}

dependency_summary() {
	local wanted="$1" consumer kind dependency _command_name label separator=' — '
	[ -f "${DEPENDENCIES_FILE}" ] || return 0
	while IFS='|' read -r consumer kind dependency _command_name || [ -n "${consumer:-}" ]; do
		[ "${consumer}" = "${wanted}" ] || continue
		case "${kind}" in
		enabled) label='requires' ;;
		image) label='requires image' ;;
		companion) label='optional companion' ;;
		*) label="${kind}" ;;
		esac
		printf '%s%s: %s' "${separator}" "${label}" "${dependency}"
		separator='; '
	done <"${DEPENDENCIES_FILE}"
}

cmd_list() {
	if [ "$#" -ne 0 ]; then
		echo "ERROR: list accepts no arguments" >&2
		usage >&2
		exit 2
	fi

	echo "01-foundation (mandatory bootstrap):"
	if [ -d "${INSTALL_DIR}/01-foundation" ]; then
		find "${INSTALL_DIR}/01-foundation" -maxdepth 1 -type f | sort | sed 's|.*/|  |'
	else
		echo "  (directorio ausente)"
	fi

	local group
	for group in 02-core-tools 03-enabled; do
		echo ""
		if [ "${group}" = 02-core-tools ]; then
			echo "${group} (mandatory tools):"
		else
			echo "${group} (active optional tools):"
		fi
		if [ -d "${INSTALL_DIR}/${group}" ]; then
			find "${INSTALL_DIR}/${group}" -maxdepth 1 -type l -print | sort | while read -r link; do
				[ -L "${link}" ] || continue
				printf "  %s -> %s\n" "$(basename "${link}")" "$(readlink "${link}")"
			done
		else
			echo "  (directorio ausente)"
		fi
	done

	echo ""
	echo "available (not enabled):"
	if [ -d "${INSTALL_DIR}/available" ]; then
		find "${INSTALL_DIR}/available" -maxdepth 1 -type f -print | sort | {
			local remaining=0
			while read -r f; do
				name="$(basename "${f}")"
				is_available_enabled "${name}" && continue
				printf '  %s' "${name}"
				dependency_summary "${name}"
				printf '\n'
				remaining=$((remaining + 1))
			done
			if [ "${remaining}" -eq 0 ]; then
				echo "  (no tools available to enable)"
			fi
		}
	else
		echo "  (directorio ausente)"
	fi

	echo ""
	echo "04-hooks:"
	if [ -d "${INSTALL_DIR}/04-hooks" ]; then
		find "${INSTALL_DIR}/04-hooks" -maxdepth 1 -mindepth 1 | sort | sed 's|.*/|  |'
	else
		echo "  (directorio ausente)"
	fi
}

cmd_enable() {
	if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
		echo "ERROR: enable requires a NAME argument" >&2
		usage >&2
		exit 2
	fi
	validate_installer_name "$1" || exit 2
	python3 "${INSTALL_DIR}/lib/selection.py" "${INSTALL_DIR}" enable "$1" || return 1
	echo ""
	echo "Next step: task container:rebuild"
	echo "Note: install:enable changes the default tool set for future builds; it does not run the install script in the current container automatically."
}

cmd_disable() {
	if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
		echo "ERROR: disable requires a NAME argument" >&2
		usage >&2
		exit 2
	fi
	validate_installer_name "$1" || exit 2
	python3 "${INSTALL_DIR}/lib/selection.py" "${INSTALL_DIR}" disable "$1" || return 1

	echo ""
	echo "Next step: task container:rebuild"
	echo "Note: install:disable changes the active tool set for future builds and postCreate repairs; it does not uninstall packages or remove persisted state."
}

cmd_doctor() {
	local errors=0
	local warnings=0

	if [ ! -f "${INSTALL_DIR}/lib/common.sh" ]; then
		echo "FAIL: lib/common.sh missing"
		errors=$((errors + 1))
	else
		echo "ok: lib/common.sh present"
	fi

	if [ ! -f "${INSTALL_DIR}/templates/install-script.sh" ]; then
		echo "FAIL: templates/install-script.sh missing"
		errors=$((errors + 1))
	else
		echo "ok: templates/install-script.sh present"
	fi

	for required_dir in 01-foundation 02-core-tools available 03-enabled 04-hooks lib templates; do
		if [ ! -d "${INSTALL_DIR}/${required_dir}" ]; then
			echo "FAIL: directory ${required_dir}/ missing"
			errors=$((errors + 1))
		fi
	done

	local group link canonical available
	local -A seen=()
	available="$(readlink -f -- "${INSTALL_DIR}/available")"
	for group in 02-core-tools 03-enabled; do
		for link in "${INSTALL_DIR}/${group}/"*.sh; do
			[ -e "${link}" ] || [ -L "${link}" ] || continue
			if [ ! -L "${link}" ] || [ ! -f "${link}" ]; then
				echo "FAIL: invalid or broken symlink ${group}/${link##*/}"
				errors=$((errors + 1))
				continue
			fi
			canonical="$(readlink -f -- "${link}")"
			case "${canonical}" in
			"${available}/"*.sh) ;;
			*)
				echo "FAIL: ${group}/${link##*/} must target an available shell installer"
				errors=$((errors + 1))
				continue
				;;
			esac
			if [ -n "${seen[${canonical}]:-}" ]; then
				echo "FAIL: duplicate installer ${group}/${link##*/}; already active as ${seen[${canonical}]}"
				errors=$((errors + 1))
			fi
			seen["${canonical}"]="${group}/${link##*/}"
		done
	done
	if ! validate_enabled_dependencies; then
		errors=$((errors + 1))
	else
		echo "ok: enabled installer dependencies"
	fi

	if [ "${errors}" -eq 0 ]; then
		echo "ok: install layout"
		return 0
	fi

	echo "FAIL: ${errors} error(s), ${warnings} warning(s)"
	return 1
}

cmd_versions_validate() {
	local common_sh="${INSTALL_DIR}/lib/common.sh"
	local versions_file="${REPO_ROOT}/.devcontainer/tool-versions.conf"

	if [ ! -f "${common_sh}" ]; then
		echo "FAIL: install/lib/common.sh missing" >&2
		return 1
	fi

	# shellcheck source=/dev/null
	source "${common_sh}"
	DEVCONTAINER_TOOL_VERSIONS_FILE="${versions_file}" devcontainer_load_tool_versions
	DEPS_UPDATE_POLICY_FILE="${versions_file}" "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --validate >/dev/null
	echo "ok: ${versions_file}"
}

# Print the desired bind mounts from the validated selected Compose manifest,
# the potential installer owners of each target, and a step-by-step
# for adding a new stateful volume. Sources lifecycle/setup-volumes.sh for the
# two functions that own the contract (parse + map).
cmd_volumes() {
	local setup_volumes="${REPO_ROOT}/.devcontainer/lifecycle/setup-volumes.sh"
	local target_path
	local source_path
	local scripts=()

	if [ ! -f "${setup_volumes}" ]; then
		echo "ERROR: setup-volumes.sh not found at ${setup_volumes}" >&2
		return 1
	fi

	# Source the contract functions. WORKSPACE_DIR is read at call
	# time inside lifecycle/setup-volumes.sh; HOME and UID come from the
	# calling shell (UID is bash-readonly, can't be reassigned).
	# shellcheck disable=SC2034
	WORKSPACE_DIR="${REPO_ROOT}"
	# shellcheck source=/dev/null
	source "${setup_volumes}"
	local records_file
	records_file="$(mktemp)" || return 1
	if ! resolve_compose_volume_targets >"${records_file}"; then
		rm -f "${records_file}"
		return 1
	fi

	echo "=== install/ volume contract ==="
	echo ""
	echo "Desired bind mounts from the validated selected Compose manifest (not proof of applied mounts):"
	echo ""

	while IFS= read -r -d '' source_path && IFS= read -r -d '' target_path; do
		scripts=()
		compose_target_to_install_scripts "${target_path}" scripts
		if [ "${#scripts[@]}" -gt 0 ]; then
			printf "  %-25s -> %-30s owned by: %s\n" \
				"${source_path}" "${target_path}" "${scripts[*]}"
		else
			printf "  %-25s -> %-30s (no mapping yet)\n" \
				"${source_path}" "${target_path}"
		fi
	done <"${records_file}"
	rm -f "${records_file}"

	echo ""
	echo "The mapping declares potential owners. During postCreate, only owners"
	echo "with a valid symlink in install/02-core-tools or install/03-enabled are run with"
	echo "DEVCONTAINER_PHASE=runtime. Each script is idempotent."
	echo ""
	echo "To add a new stateful volume (e.g. PostgreSQL data dir):"
	echo "  1. Add the bind mount to a selected Compose file and recreate through Task."
	echo "  2. Add a case for the new target path in"
	echo "     compose_target_to_install_scripts in"
	echo "     .devcontainer/lifecycle/setup-volumes.sh, listing the install script's"
	echo "     base name (without the .sh extension)."
	echo "  3. Add the install script in .devcontainer/install/available/."
	echo "  4. Link it from .devcontainer/install/03-enabled/ if it should"
	echo "     run by default."
}

case "${1:-help}" in
help | --help | -h)
	usage
	;;
list)
	shift
	cmd_list "$@"
	;;
enable)
	shift
	cmd_enable "$@"
	;;
disable)
	shift
	cmd_disable "$@"
	;;
doctor)
	cmd_doctor
	;;
versions-validate)
	cmd_versions_validate
	;;
volumes)
	cmd_volumes
	;;
*)
	usage >&2
	exit 2
	;;
esac
