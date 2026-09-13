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
#   enable NAME                Create a 03-enabled/ symlink to
#                              available/NAME.sh
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
  enable NAME           Create an optional 03-enabled/ symlink to available/NAME.sh
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

# Resolve a script name (with or without .sh suffix) to its
# absolute path under available/. Echoes the path; returns 1 if not
# found. Accepts NAME or NAME.sh.
resolve_available() {
	local name="$1"

	for candidate in "${name}" "${name}.sh"; do
		if [ -f "${INSTALL_DIR}/available/${candidate}" ]; then
			printf '%s\n' "${INSTALL_DIR}/available/${candidate}"
			return 0
		fi
	done

	return 1
}

preferred_enabled_name() {
	local base="$1"

	case "${base}" in
	10-bats.sh) printf '10-bats.sh\n' ;;
	20-runtime-go.sh) printf '20-go.sh\n' ;;
	20-runtime-node.sh) printf '30-node.sh\n' ;;
	20-runtime-pnpm.sh) printf '40-pnpm.sh\n' ;;
	40-php-lang.sh) printf '40-php-lang.sh\n' ;;
	40-php-debug.sh) printf '41-php-debug.sh\n' ;;
	40-php-test.sh) printf '42-php-test.sh\n' ;;
	40-node-markdownlint.sh) printf '45-markdownlint.sh\n' ;;
	40-cli-glow.sh) printf '46-glow.sh\n' ;;
	20-tool-devcontainer-cli.sh) printf '50-devcontainer-cli.sh\n' ;;
	30-ai-opencode.sh) printf '55-opencode.sh\n' ;;
	30-ai-engram.sh) printf '60-engram.sh\n' ;;
	30-ai-pi-coding.sh) printf '70-pi-coding.sh\n' ;;
	30-ai-pi-gentle.sh) printf '80-pi-gentle.sh\n' ;;
	30-ai-gentle-ai.sh) printf '81-gentle-ai.sh\n' ;;
	30-ai-skills.sh) printf '90-skills.sh\n' ;;
	*) printf '%s\n' "${base}" ;;
	esac
}

enabled_link_names_for_base() {
	local alias
	while IFS= read -r alias; do
		printf '%s\n' "${alias##*/}"
	done < <(devcontainer_active_aliases "${INSTALL_DIR}" "${INSTALL_DIR}/available/$1" 03-enabled)
}

is_available_enabled() {
	local base="$1"
	devcontainer_install_is_active "${INSTALL_DIR}" "${INSTALL_DIR}/available/${base}"
}

enabled_alias_for_base() {
	devcontainer_active_aliases "${INSTALL_DIR}" "${INSTALL_DIR}/available/$1" | sort | head -n 1
}

refuse_core_change() {
	if devcontainer_install_is_active "${INSTALL_DIR}" "$1" 02-core-tools; then
		echo "ERROR: ${1##*/} belongs to mandatory 02-core-tools; enable/disable changes only 03-enabled. To customize the base, edit the core aliases and matching Dockerfile COPY inputs intentionally." >&2
		return 1
	fi
}

validate_enabled_dependencies() {
	local errors=0 consumer kind dependency command_name consumer_alias dependency_alias
	[ -f "${DEPENDENCIES_FILE}" ] || return 0
	while IFS='|' read -r consumer kind dependency command_name || [ -n "${consumer:-}" ]; do
		[[ "${consumer}" =~ ^[[:space:]]*(#|$) ]] && continue
		[ "${kind}" = "enabled" ] || continue
		is_available_enabled "${consumer}" || continue
		if ! is_available_enabled "${dependency}"; then
			echo "FAIL: ${consumer} requires enabled installer ${dependency} (${command_name})" >&2
			errors=$((errors + 1))
			continue
		fi
		consumer_alias="$(enabled_alias_for_base "${consumer}")"
		dependency_alias="$(enabled_alias_for_base "${dependency}")"
		if [[ "${dependency_alias}" > "${consumer_alias}" ]]; then
			echo "FAIL: ${dependency} must run before ${consumer} (${dependency_alias} sorts after ${consumer_alias})" >&2
			errors=$((errors + 1))
		fi
	done <"${DEPENDENCIES_FILE}"
	[ "${errors}" -eq 0 ]
}

dependency_summary() {
	local wanted="$1" consumer kind dependency command_name label separator=' — '
	[ -f "${DEPENDENCIES_FILE}" ] || return 0
	while IFS='|' read -r consumer kind dependency command_name || [ -n "${consumer:-}" ]; do
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

enabled_dependents_for() {
	local wanted="$1" consumer kind dependency command_name
	[ -f "${DEPENDENCIES_FILE}" ] || return 0
	while IFS='|' read -r consumer kind dependency command_name || [ -n "${consumer:-}" ]; do
		if [ "${kind}" != "enabled" ] || [ "${dependency}" != "${wanted}" ]; then
			continue
		fi
		is_available_enabled "${consumer}" && printf '%s\n' "${consumer}"
	done <"${DEPENDENCIES_FILE}"
}

resolve_disable_target() {
	local name="$1" candidate canonical group
	if resolve_available "${name}"; then
		return 0
	fi
	for group in 02-core-tools 03-enabled; do
		for candidate in "${name}" "${name}.sh"; do
			candidate="${INSTALL_DIR}/${group}/${candidate}"
			if [ ! -L "${candidate}" ] || [ ! -e "${candidate}" ]; then
				continue
			fi
			canonical="$(readlink -f -- "${candidate}")" || continue
			case "${canonical}" in
			"${INSTALL_DIR}/available/"*.sh)
				[ -f "${canonical}" ] && printf '%s\n' "${canonical}" && return 0
				;;
			esac
		done
	done
	return 1
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
	local name="$1"
	local source_path

	if [ -z "${name}" ]; then
		echo "ERROR: enable requires a NAME argument" >&2
		usage >&2
		exit 2
	fi
	validate_installer_name "${name}" || exit 2

	if ! source_path="$(resolve_available "${name}")"; then
		echo "ERROR: ${name} not found under available/" >&2
		exit 1
	fi

	local base
	base="$(basename "${source_path}")"
	refuse_core_change "${source_path}" || exit 1

	local link_name
	link_name="$(preferred_enabled_name "${base}")"

	if is_available_enabled "${base}"; then
		echo "${base} is already enabled"
		return 0
	fi

	(
		cd "${INSTALL_DIR}/03-enabled"
		ln -sfn "../available/${base}" "${link_name}"
	)
	if ! validate_enabled_dependencies; then
		rm -f "${INSTALL_DIR}/03-enabled/${link_name}"
		echo "ERROR: enable rolled back because installer dependencies are not satisfied" >&2
		exit 1
	fi
	echo "Enabled: enabled/${link_name} -> available/${base}"
	echo ""
	echo "Next step: task container:rebuild"
	echo "Note: install:enable changes the default tool set for future builds; it does not run the install script in the current container automatically."
}

cmd_disable() {
	local name="$1"
	local removed=0
	local source_path base dependents

	if [ -z "${name}" ]; then
		echo "ERROR: disable requires a NAME argument" >&2
		usage >&2
		exit 2
	fi
	validate_installer_name "${name}" || exit 2

	if source_path="$(resolve_disable_target "${name}" 2>/dev/null)"; then
		refuse_core_change "${source_path}" || exit 1
		base="$(basename "${source_path}")"
		dependents="$(enabled_dependents_for "${base}")"
		if [ -n "${dependents}" ]; then
			echo "ERROR: cannot disable ${base}; required by enabled installer(s): ${dependents//$'\n'/, }" >&2
			exit 1
		fi
	fi

	for candidate in "${name}" "${name}.sh"; do
		if [ -L "${INSTALL_DIR}/03-enabled/${candidate}" ]; then
			rm "${INSTALL_DIR}/03-enabled/${candidate}"
			echo "Disabled: ${candidate}"
			removed=$((removed + 1))
		fi
	done

	if source_path="$(resolve_available "${name}" 2>/dev/null)"; then
		while IFS= read -r enabled_name; do
			[ -n "${enabled_name}" ] || continue
			if [ -L "${INSTALL_DIR}/03-enabled/${enabled_name}" ]; then
				rm "${INSTALL_DIR}/03-enabled/${enabled_name}"
				echo "Disabled: ${enabled_name}"
				removed=$((removed + 1))
			fi
		done < <(enabled_link_names_for_base "$(basename "${source_path}")")
	fi

	if [ "${removed}" -eq 0 ]; then
		echo "${name} is not enabled"
		return 0
	fi

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
	DEPS_UPDATE_POLICY_FILE="${versions_file}" "${REPO_ROOT}/.taskfiles/scripts/deps-update.sh" --validate >/dev/null
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
