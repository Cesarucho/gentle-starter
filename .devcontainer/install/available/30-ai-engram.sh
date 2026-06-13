#!/usr/bin/env bash
#
# 30-ai-engram.sh — install the Engram memory server into the user's
# local bin directory, register ~/.local/bin on PATH via ~/.bashrc, and
# run the Pi integration step.
#
# Mirrors .devcontainer/scripts/10-install-ai-engram.sh with the
# common.sh helpers. Architecture detection uses devcontainer_arch.
# Skips during image build; intended to run during container start as
# the final non-root user.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${ENGRAM_VERSION:=1.16.3}"
: "${ENGRAM_INSTALL_DIR:=${HOME}/.local/bin}"
: "${ENGRAM_DATA_DIR:=${HOME}/.engram}"
: "${ENGRAM_PROFILE_FILE:=${HOME}/.bashrc}"
: "${ENGRAM_SETUP_PI:=1}"
TARGET_OS="linux"

engram_binary() {
    printf '%s/engram' "${ENGRAM_INSTALL_DIR}"
}

installed_engram_version() {
    local binary
    binary="$(engram_binary)"

    if [ ! -x "${binary}" ]; then
        return 1
    fi

    "${binary}" version | awk '{print $NF}' | sed 's/^v//'
}

ensure_local_bin_on_path() {
    local path_line
    path_line="export PATH=\"${ENGRAM_INSTALL_DIR}:\$PATH\""

    mkdir -p "${ENGRAM_INSTALL_DIR}"
    touch "${ENGRAM_PROFILE_FILE}"

    if ! grep -Fq "${ENGRAM_INSTALL_DIR}" "${ENGRAM_PROFILE_FILE}"; then
        {
            echo ""
            echo "# User-local CLI tools"
            echo "${path_line}"
        } >>"${ENGRAM_PROFILE_FILE}"
    fi

    export PATH="${ENGRAM_INSTALL_DIR}:${PATH}"
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
    tar -xzf "${tmp_dir}/${archive_name}" -C "${tmp_dir}"
}

install_engram() {
    local target_arch
    local current_version=""
    local tmp_dir
    local downloaded_binary
    local target_binary

    ensure_local_bin_on_path

    current_version="$(installed_engram_version 2>/dev/null || true)"
    if [ "${current_version}" = "${ENGRAM_VERSION}" ]; then
        devcontainer_log_info "Engram ${ENGRAM_VERSION} already installed at $(engram_binary)"
        return 0
    fi

    target_arch="$(devcontainer_arch)"
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "${tmp_dir}"' RETURN

    devcontainer_log_info "Installing Engram ${ENGRAM_VERSION} into ${ENGRAM_INSTALL_DIR}"

    download_engram "${target_arch}" "${tmp_dir}"
    downloaded_binary="$(find "${tmp_dir}" -type f -name engram | head -n 1)"

    if [ -z "${downloaded_binary}" ]; then
        devcontainer_log_error "Engram binary not found inside downloaded archive"
        find "${tmp_dir}" -maxdepth 3 -type f -print >&2
        exit 1
    fi

    target_binary="$(engram_binary)"
    install -m 0755 "${downloaded_binary}" "${target_binary}"
    "${target_binary}" version
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
        return 0
    fi

    "${binary}" setup pi
}

# Build phase: skip. Engram is user-scoped and integrates with the
# user's home directory; it lands cleanly at runtime.
if devcontainer_is_build; then
    devcontainer_log_info "Skipping Engram user-local install during image build"
    exit 0
fi

install_engram
setup_engram_data_dir
setup_pi_integration
