#!/usr/bin/env bash
#
# 30-ai-opencode.sh — opencode installer (currently not enabled).
#
# Opt in by linking from 02-enabled/: cd .devcontainer/install/02-enabled && ln -sfn ../available/30-ai-opencode.sh 30-ai-opencode.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${OPENCODE_INSTALL_DIR:=${HOME}/.local/bin}"
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
		if devcontainer_has_cmd opencode; then
			binary="$(command -v opencode)"
		else
			return 1
		fi
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

	if ! devcontainer_has_cmd opencode; then
		devcontainer_log_warn "opencode installation completed but binary is not on PATH (expected ${OPENCODE_INSTALL_DIR})"
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
