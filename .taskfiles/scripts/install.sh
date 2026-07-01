#!/usr/bin/env bash
# install.sh — task helpers for the .devcontainer/install/ layout.
#
# Used by .taskfiles/install.yml. Not intended to be run directly,
# but works fine that way too.
#
# The runtime groups carry a numeric prefix (01-core, 02-enabled,
# 03-hooks) as a visual hint of execution order. The prefix is not
# load-bearing for ordering: the Dockerfile iterates the groups
# explicitly, and within each group the Dockerfile sorts the entries
# by filename.
#
# Commands:
#   help                       Show this help
#   list [--presets]           List install scripts (01-core, 02-enabled,
#                              03-hooks) and the full available/ catalog
#                              with enabled/not enabled status. --presets
#                              is kept as a no-op compatibility alias.
#   enable NAME                Create an 02-enabled/ symlink to
#                              available/NAME.sh
#   disable NAME               Remove the 02-enabled/ symlink for NAME.sh
#   doctor                     Verify the install/ layout integrity
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INSTALL_DIR="${REPO_ROOT}/.devcontainer/install"

usage() {
	cat <<'EOF'
Usage:
  install.sh <command> [args]

Commands:
  help                  Show this help
  list [--presets]      List install scripts (01-core, 02-enabled, 03-hooks)
                        and the full available/ catalog with enabled/not enabled
                        status. --presets is kept as a no-op compatibility alias.
  enable NAME           Create an 02-enabled/ symlink to available/NAME.sh
  disable NAME          Remove the 02-enabled/ symlink for NAME.sh
  doctor                Verify the install/ layout integrity
  volumes               Print the live volume contract: bind mounts from
                        docker-compose.yml and the install scripts that
                        own each target
EOF
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
	40-node-markdownlint.sh) printf '45-markdownlint.sh\n' ;;
	20-tool-devcontainer-cli.sh) printf '50-devcontainer-cli.sh\n' ;;
	30-ai-engram.sh) printf '60-engram.sh\n' ;;
	30-ai-pi-coding.sh) printf '70-pi-coding.sh\n' ;;
	30-ai-pi-gentle.sh) printf '80-pi-gentle.sh\n' ;;
	30-ai-skills.sh) printf '90-skills.sh\n' ;;
	*) printf '%s\n' "${base}" ;;
	esac
}

enabled_link_names_for_base() {
	local base="$1"
	local link

	[ -d "${INSTALL_DIR}/02-enabled" ] || return 0

	for link in "${INSTALL_DIR}/02-enabled/"*; do
		[ -L "${link}" ] || continue
		if [ "$(basename "$(readlink "${link}")")" = "${base}" ]; then
			basename "${link}"
		fi
	done
}

is_available_enabled() {
	local base="$1"
	enabled_link_names_for_base "${base}" | grep -q .
}

cmd_list() {
	if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "${1}" != "--presets" ]; }; then
		echo "ERROR: list accepts no arguments or the legacy --presets alias" >&2
		usage >&2
		exit 2
	fi

	echo "01-core (obligatorio):"
	if [ -d "${INSTALL_DIR}/01-core" ]; then
		find "${INSTALL_DIR}/01-core" -maxdepth 1 -type f | sort | sed 's|.*/|  |'
	else
		echo "  (directorio ausente)"
	fi

	echo ""
	echo "02-enabled (opt-in activos):"
	if [ -d "${INSTALL_DIR}/02-enabled" ]; then
		find "${INSTALL_DIR}/02-enabled" -maxdepth 1 -type l -print | sort | while read -r link; do
			[ -L "${link}" ] || continue
			printf "  %s -> %s\n" "$(basename "${link}")" "$(readlink "${link}")"
		done
	else
		echo "  (directorio ausente)"
	fi

	echo ""
	echo "available (catálogo dinámico desde available/):"
	if [ -d "${INSTALL_DIR}/available" ]; then
		find "${INSTALL_DIR}/available" -maxdepth 1 -type f -print | sort | while read -r f; do
			name="$(basename "${f}")"
			if is_available_enabled "${name}"; then
				echo "  ${name} (enabled)"
			else
				echo "  ${name} (not enabled)"
			fi
		done
	else
		echo "  (directorio ausente)"
	fi

	echo ""
	echo "03-hooks:"
	if [ -d "${INSTALL_DIR}/03-hooks" ]; then
		find "${INSTALL_DIR}/03-hooks" -maxdepth 1 -mindepth 1 | sort | sed 's|.*/|  |'
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

	if ! source_path="$(resolve_available "${name}")"; then
		echo "ERROR: ${name} not found under available/" >&2
		exit 1
	fi

	local base
	base="$(basename "${source_path}")"

	local link_name
	link_name="$(preferred_enabled_name "${base}")"

	if is_available_enabled "${base}"; then
		echo "${base} is already enabled"
		return 0
	fi

	(
		cd "${INSTALL_DIR}/02-enabled"
		ln -sfn "../available/${base}" "${link_name}"
	)
	echo "Enabled: enabled/${link_name} -> available/${base}"
	echo ""
	echo "Next step: task container:rebuild"
	echo "Note: install:enable changes the default tool set for future builds; it does not run the install script in the current container automatically."
}

cmd_disable() {
	local name="$1"
	local removed=0

	if [ -z "${name}" ]; then
		echo "ERROR: disable requires a NAME argument" >&2
		usage >&2
		exit 2
	fi

	for candidate in "${name}" "${name}.sh"; do
		if [ -L "${INSTALL_DIR}/02-enabled/${candidate}" ]; then
			rm "${INSTALL_DIR}/02-enabled/${candidate}"
			echo "Disabled: ${candidate}"
			removed=$((removed + 1))
		fi
	done

	if source_path="$(resolve_available "${name}" 2>/dev/null)"; then
		while IFS= read -r enabled_name; do
			[ -n "${enabled_name}" ] || continue
			if [ -L "${INSTALL_DIR}/02-enabled/${enabled_name}" ]; then
				rm "${INSTALL_DIR}/02-enabled/${enabled_name}"
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
	echo "Note: install:disable changes the default tool set for future builds; existing tools in the current container remain until the environment is rebuilt."
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

	for required_dir in 01-core available 02-enabled 03-hooks lib templates; do
		if [ ! -d "${INSTALL_DIR}/${required_dir}" ]; then
			echo "FAIL: directory ${required_dir}/ missing"
			errors=$((errors + 1))
		fi
	done

	if [ -d "${INSTALL_DIR}/02-enabled" ]; then
		for link in "${INSTALL_DIR}/02-enabled/"*; do
			if [ -L "${link}" ] && [ ! -e "${link}" ]; then
				echo "FAIL: broken symlink 02-enabled/$(basename "${link}")"
				errors=$((errors + 1))
			fi
		done
	fi

	if [ "${errors}" -eq 0 ]; then
		echo "ok: install layout"
		return 0
	fi

	echo "FAIL: ${errors} error(s), ${warnings} warning(s)"
	return 1
}

# Print the live volume contract: the bind mounts docker-compose.yml
# declares, the install scripts that own each target, and a step-by-step
# for adding a new stateful volume. Sources setup-volumes.sh for the
# two functions that own the contract (parse + map).
cmd_volumes() {
	local setup_volumes="${REPO_ROOT}/.devcontainer/setup-volumes.sh"
	local target_path
	local source_path
	local scripts=()

	if [ ! -f "${setup_volumes}" ]; then
		echo "ERROR: setup-volumes.sh not found at ${setup_volumes}" >&2
		return 1
	fi

	# Source the contract functions. WORKSPACE_DIR is read at call
	# time inside setup-volumes.sh; HOME and UID come from the
	# calling shell (UID is bash-readonly, can't be reassigned).
	# shellcheck disable=SC2034
	WORKSPACE_DIR="${REPO_ROOT}"
	# shellcheck source=/dev/null
	source "${setup_volumes}"

	echo "=== install/ volume contract ==="
	echo ""
	echo "Bind mounts declared in .devcontainer/docker-compose.yml:"
	echo ""

	while IFS='|' read -r source_path target_path; do
		scripts=()
		compose_target_to_install_scripts "${target_path}" scripts
		if [ "${#scripts[@]}" -gt 0 ]; then
			printf "  %-25s -> %-30s owned by: %s\n" \
				"${source_path}" "${target_path}" "${scripts[*]}"
		else
			printf "  %-25s -> %-30s (no mapping yet)\n" \
				"${source_path}" "${target_path}"
		fi
	done < <(resolve_compose_volume_targets)

	echo ""
	echo "When postCreate runs, each target is re-populated by running"
	echo "the owning install script with DEVCONTAINER_PHASE=runtime. Each"
	echo "script is idempotent (skips itself when already installed)."
	echo ""
	echo "To add a new stateful volume (e.g. PostgreSQL data dir):"
	echo "  1. Add the bind mount to .devcontainer/docker-compose.yml."
	echo "  2. Add a case for the new target path in"
	echo "     compose_target_to_install_scripts in"
	echo "     .devcontainer/setup-volumes.sh, listing the install script's"
	echo "     base name (without the .sh extension)."
	echo "  3. Add the install script in .devcontainer/install/available/."
	echo "  4. Link it from .devcontainer/install/02-enabled/ if it should"
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
volumes)
	cmd_volumes
	;;
*)
	usage >&2
	exit 2
	;;
esac
