#!/usr/bin/env bash
#
# 3010-ai-engram.sh — install the image-owned Engram binary during build,
# then initialize user data and optional Pi integration at runtime.
# Architecture detection uses devcontainer_arch.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/tar-archive.sh"

devcontainer_load_tool_versions

: "${ENGRAM_VERSION:=${LOCK_ENGRAM_VERSION:?missing LOCK_ENGRAM_VERSION}}"
: "${ENGRAM_INSTALL_DIR:=/usr/local/bin}"
: "${ENGRAM_DATA_DIR:=${HOME}/.engram}"
: "${ENGRAM_PROFILE_FILE:=${HOME}/.bashrc}"
: "${ENGRAM_SETUP_PI:=0}"
: "${ENGRAM_PI_COMMAND:=pi}"
TARGET_OS="linux"
ENGRAM_TEMP_DIR=""
ENGRAM_STAGED_BINARY=""

cleanup_engram_install() {
	[ -z "${ENGRAM_STAGED_BINARY}" ] || rm -f "${ENGRAM_STAGED_BINARY}"
	[ -z "${ENGRAM_TEMP_DIR}" ] || rm -rf "${ENGRAM_TEMP_DIR}"
}

abort_engram_install() {
	cleanup_engram_install
	exit 1
}

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'ENGRAM_VERSION=%s\n' "${ENGRAM_VERSION}"
	exit 0
fi

engram_binary() {
	printf '%s/engram' "${ENGRAM_INSTALL_DIR}"
}

installed_engram_version() {
	local binary
	binary="$(engram_binary)"

	if [ ! -x "${binary}" ]; then
		return 1
	fi

	"${binary}" version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1
}

download_engram() {
	local target_arch="$1"
	local tmp_dir="$2"
	local archive_name
	local archive_url

	archive_name="engram_${ENGRAM_VERSION}_${TARGET_OS}_${target_arch}.tar.gz"
	archive_url="https://github.com/Gentleman-Programming/engram/releases/download/v${ENGRAM_VERSION}/${archive_name}"

	devcontainer_log_info "Downloading Engram ${ENGRAM_VERSION}: ${archive_url}"
	devcontainer_fetch "${archive_url}" "${tmp_dir}/${archive_name}"
	local digest_variable="LOCK_ENGRAM_SHA256_${target_arch^^}"
	local digest="${!digest_variable:-}"
	[[ "${digest}" =~ ^[0-9a-f]{64}$ ]] || {
		devcontainer_log_error "Invalid Engram SHA-256 for ${target_arch}"
		return 1
	}
	printf '%s  %s\n' "${digest}" "${tmp_dir}/${archive_name}" | sha256sum -c -
	devcontainer_validate_engram_tar "${tmp_dir}/${archive_name}" "${tmp_dir}/extract"
}

install_engram() {
	local target_arch
	local current_version=""
	local tmp_dir
	local downloaded_binary
	local target_binary

	current_version="$(installed_engram_version 2>/dev/null || true)"
	if [ "${current_version}" = "${ENGRAM_VERSION}" ]; then
		devcontainer_log_info "Engram ${ENGRAM_VERSION} already installed at $(engram_binary)"
		return 0
	fi

	target_arch="$(devcontainer_arch)"
	tmp_dir="$(mktemp -d)"
	ENGRAM_TEMP_DIR="${tmp_dir}"
	trap cleanup_engram_install EXIT
	trap abort_engram_install HUP INT TERM

	devcontainer_log_info "Installing Engram ${ENGRAM_VERSION} into ${ENGRAM_INSTALL_DIR}"

	download_engram "${target_arch}" "${tmp_dir}"
	downloaded_binary="${tmp_dir}/extract/engram"

	if [ -z "${downloaded_binary}" ]; then
		devcontainer_log_error "Engram binary not found inside downloaded archive"
		find "${tmp_dir}" -maxdepth 3 -type f -print >&2
		exit 1
	fi

	target_binary="$(engram_binary)"
	install -d -m 0755 "${ENGRAM_INSTALL_DIR}"
	ENGRAM_STAGED_BINARY="${target_binary}.new"
	install -m 0755 "${downloaded_binary}" "${ENGRAM_STAGED_BINARY}"
	if [ "$("${ENGRAM_STAGED_BINARY}" version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)" != "${ENGRAM_VERSION}" ]; then
		return 1
	fi
	mv -f "${ENGRAM_STAGED_BINARY}" "${target_binary}"
	ENGRAM_STAGED_BINARY=""
	cleanup_engram_install
	ENGRAM_TEMP_DIR=""
	trap - EXIT HUP INT TERM
}

setup_engram_data_dir() {
	mkdir -p "${ENGRAM_DATA_DIR}"

	if [ -f "${ENGRAM_DATA_DIR}/engram.db" ]; then
		devcontainer_log_info "Preserving existing Engram database at ${ENGRAM_DATA_DIR}/engram.db"
	fi
}

setup_pi_integration() {
	local binary
	binary="$(engram_binary)"

	if [ "${ENGRAM_SETUP_PI}" = "0" ]; then
		devcontainer_log_info "Skipping Engram Pi integration (ENGRAM_SETUP_PI=0)"
		return 0
	fi
	if ! devcontainer_has_cmd "${ENGRAM_PI_COMMAND}"; then
		devcontainer_log_warn "Pi is not installed; Engram is ready for standalone use and Pi integration was skipped"
		return 0
	fi

	"${binary}" setup pi
}

if devcontainer_is_build; then
	install_engram
	exit 0
fi

setup_engram_data_dir
setup_pi_integration
