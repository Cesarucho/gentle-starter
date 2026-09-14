#!/usr/bin/env bash
set -euo pipefail

install_directory="${1:?installer directory is required}"
installer_list=""
declare -a installers=()

cleanup_installer_list() {
	[ -z "${installer_list}" ] || rm -f "${installer_list}"
}

[ -d "${install_directory}" ] || {
	printf 'Installer directory does not exist: %s\n' "${install_directory}" >&2
	exit 1
}

installer_list="$(mktemp)"
trap cleanup_installer_list EXIT HUP INT TERM
# Match the selection planner's bytewise filename order in every image locale.
find -L "${install_directory}" -maxdepth 1 -type f -name '*.sh' -print0 | LC_ALL=C sort -z >"${installer_list}"
mapfile -d '' installers <"${installer_list}"
cleanup_installer_list
installer_list=""
trap - EXIT HUP INT TERM

for installer in "${installers[@]}"; do
	printf '\n============================================================\n'
	printf 'Running: %s\n' "${installer}"
	printf '============================================================\n'
	DEVCONTAINER_PHASE=build bash "${installer}"
done
