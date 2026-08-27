#!/usr/bin/env bash
#
# 30-ai-opencode.sh — OpenCode installer (enabled by default).
#
# Its ordered alias lives in 02-enabled/ and can be managed with the install tasks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${OPENCODE_INSTALL_DIR:=${HOME}/.opencode/bin}"
: "${OPENCODE_PROFILE_FILE:=${HOME}/.bashrc}"
: "${OPENCODE_AUTO_UPDATE:=0}"
: "${OPENCODE_INSTALL_URL:=https://opencode.ai/install}"

opencode_binary() {
	printf '%s/opencode' "${OPENCODE_INSTALL_DIR}"
}

installed_opencode_version() {
	local binary
	binary="$(opencode_binary)"

	if [ ! -x "${binary}" ]; then
		return 1
	fi

	"${binary}" --version 2>/dev/null | awk '{print $NF}' | sed 's/^v//'
}

ensure_install_dir_on_path() {
	local path_line
	path_line="export PATH=\"${OPENCODE_INSTALL_DIR}:\$PATH\""

	mkdir -p "${OPENCODE_INSTALL_DIR}"
	touch "${OPENCODE_PROFILE_FILE}"

	if ! grep -Fq "${OPENCODE_INSTALL_DIR}" "${OPENCODE_PROFILE_FILE}"; then
		{
			echo ""
			echo "# User-local CLI tools"
			echo "${path_line}"
		} >>"${OPENCODE_PROFILE_FILE}"
	fi

	export PATH="${OPENCODE_INSTALL_DIR}:${PATH}"
}

should_install_opencode() {
	local current_version=""

	current_version="$(installed_opencode_version 2>/dev/null || true)"

	if [ -z "${current_version}" ]; then
		return 0
	fi

	case "${OPENCODE_AUTO_UPDATE}" in
	1 | true | TRUE | yes | YES)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

install_opencode() {
	ensure_install_dir_on_path

	if ! should_install_opencode; then
		devcontainer_log_info "opencode already installed; auto-update disabled"
		return 0
	fi

	devcontainer_log_info "Installing opencode from ${OPENCODE_INSTALL_URL}"
	curl -fsSL "${OPENCODE_INSTALL_URL}" | bash

	if [ ! -x "$(opencode_binary)" ]; then
		devcontainer_log_warn "opencode installation completed but binary was not found at ${OPENCODE_INSTALL_DIR}"
	fi
}

# Build phase: skip. opencode is user-scoped and integrates with the
# user's home directory.
if devcontainer_is_build; then
	devcontainer_log_info "Skipping opencode user-local install during image build"
	exit 0
fi

# Runtime phase: must run as the final non-root user.
if [ "$(id -u)" -eq 0 ]; then
	devcontainer_log_error "This script must run as the final non-root user during runtime"
	exit 1
fi

install_opencode
