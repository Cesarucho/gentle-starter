#!/usr/bin/env bash
# setup-volumes.sh — volume-aware install repair.
#
# Sourced by setup.sh during the devcontainer postCreate hook. Validates
# the host-resolved selected Compose volume manifest and re-runs the
# install scripts that own mapped targets with DEVCONTAINER_PHASE=runtime.
# Passive mounts intentionally have no mapping and receive no repair.
# Each install script is idempotent (uses lib/common.sh's
# devcontainer_has_cmd guard at the top), so a re-run on a populated
# volume is a no-op.
#
# For an installer-owned target, the contract has four pieces, and
# they all have to agree for the repair to fire:
#
#   1. The bind mount itself: declared in long syntax under
#      the selected service's volumes, e.g.
#        - type: bind
#          source: ../.env.d/.postgresql
#          target: /home/ubuntu/.postgresql
#          bind: { create_host_path: false }
#
#   2. The target-to-script mapping: a case in
#      compose_target_to_install_scripts() below, e.g.
#        "/home/ubuntu/.postgresql")
#            scripts_ref+=("40-data-postgresql")
#            ;;
#
#   3. The install script itself: lives in
#      .devcontainer/install/available/40-data-postgresql.sh.
#
#   4. Active status: a valid symlink in install/02-core-tools/ or 03-enabled/
#      canonically resolves to that available script. The symlink name is
#      only an ordering alias and need not match the catalog basename.
#
# To add a new installer-owned stateful volume (e.g. PostgreSQL data dir):
#   a. Add the bind mount in a selected Compose file and recreate through Task.
#   b. Add a case for the new target path in
#      compose_target_to_install_scripts() below.
#   c. Add the install script in install/available/.
#   d. Link it from install/03-enabled/ if it should run by default.
#
# A passive state mount needs only the Compose entry. Leave it unmapped
# when the application itself owns and populates that state.
#
# Note: this file is meant to be sourced by setup.sh. It relies on
# WORKSPACE_DIR being set by the caller. Ownership paths use configured ubuntu,
# not the invoking host user's HOME or UID. Running it
# directly will not work.

LIFECYCLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${LIFECYCLE_DIR}/../install/lib/activation.sh"

# Emit NUL-terminated source and target fields for each bind mount.
resolve_compose_volume_targets() {
	local records
	records="$(python3 "${WORKSPACE_DIR}/.taskfiles/scripts/compose-manifest.py" records "${WORKSPACE_DIR}")" || return 1
	printf '%s' "${records}" | python3 "${LIFECYCLE_DIR}/compose-volume-records.py"
}

# Map a container-side target path to the install script base names
# (without the .sh extension) that own that volume. Passive targets
# intentionally return an empty array.
compose_target_to_install_scripts() {
	local target="$1"
	local -n scripts_ref="$2"

	scripts_ref=()
	case "${target}" in
	"/home/ubuntu/.pi")
		scripts_ref+=("3040-ai-pi-gentle")
		;;
	"/home/ubuntu/.engram")
		scripts_ref+=("3010-ai-engram")
		;;
	esac
}

# Return success when a valid core or optional ordering alias canonically
# resolves to the requested available installer. Broken links and links to
# other catalog entries do not activate the installer.
install_script_is_enabled() {
	devcontainer_install_is_active "${WORKSPACE_DIR}/.devcontainer/install" "$1"
}

# Iterate over validated, applied bind-mount volume targets and
# run the active install scripts that potentially own each mapped target,
# with DEVCONTAINER_PHASE=runtime. Passive targets and disabled owners are
# skipped. Each script is idempotent: it skips itself when the tool is already
# installed, so a re-run on a populated volume is a no-op.
repair_installed_volumes() {
	python3 "${WORKSPACE_DIR}/.taskfiles/scripts/compose-manifest.py" runtime "${WORKSPACE_DIR}" >/dev/null || return 1
	local install_root="${WORKSPACE_DIR}/.devcontainer/install/available"
	local records_file
	records_file="$(mktemp)" || return 1
	if ! resolve_compose_volume_targets >"${records_file}"; then
		rm -f "${records_file}"
		return 1
	fi
	local target_path
	local scripts=()
	local script
	local script_path
	local repair_status=0

	while IFS= read -r -d '' _ && IFS= read -r -d '' target_path; do
		compose_target_to_install_scripts "${target_path}" scripts

		for script in "${scripts[@]}"; do
			script_path="${install_root}/${script}.sh"
			if ! install_script_is_enabled "${script_path}"; then
				continue
			fi
			echo "Volume repair: ${target_path} -> ${script}.sh"
			if ! DEVCONTAINER_PHASE=runtime bash "${script_path}"; then
				repair_status=1
				break 2
			fi
		done
	done <"${records_file}"
	rm -f "${records_file}"
	return "${repair_status}"
}
