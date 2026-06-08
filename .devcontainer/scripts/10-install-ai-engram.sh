#!/usr/bin/env bash
set -euo pipefail

DEVCONTAINER_PHASE="${DEVCONTAINER_PHASE:-build}"
ENGRAM_VERSION="${ENGRAM_VERSION:-1.16.1}"
ENGRAM_INSTALL_DIR="${ENGRAM_INSTALL_DIR:-${HOME}/.local/bin}"
ENGRAM_DATA_DIR="${ENGRAM_DATA_DIR:-${HOME}/.engram}"
ENGRAM_PROFILE_FILE="${ENGRAM_PROFILE_FILE:-${HOME}/.bashrc}"
TARGET_OS="linux"

resolve_target_arch() {
	case "$(uname -m)" in
	x86_64)
		printf 'amd64'
		;;
	aarch64 | arm64)
		printf 'arm64'
		;;
	*)
		echo "Unsupported architecture: $(uname -m)" >&2
		exit 1
		;;
	esac
}

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

	echo "Downloading Engram ${ENGRAM_VERSION}: ${archive_url}"
	curl -fsSL -o "${tmp_dir}/${archive_name}" "${archive_url}"
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
		echo "Engram ${ENGRAM_VERSION} already installed at $(engram_binary)"
		return 0
	fi

	target_arch="$(resolve_target_arch)"
	tmp_dir="$(mktemp -d)"
	trap 'rm -rf "${tmp_dir}"' RETURN

	echo "Installing Engram ${ENGRAM_VERSION} into ${ENGRAM_INSTALL_DIR}"
	echo "Detected architecture: $(uname -m) -> ${target_arch}"

	download_engram "${target_arch}" "${tmp_dir}"
	downloaded_binary="$(find "${tmp_dir}" -type f -name engram | head -n 1)"

	if [ -z "${downloaded_binary}" ]; then
		echo "Engram binary not found inside downloaded archive" >&2
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
		echo "Preserving existing Engram database at ${ENGRAM_DATA_DIR}/engram.db"
	fi
}

setup_pi_integration() {
	local binary
	binary="$(engram_binary)"

	if [ "${ENGRAM_SETUP_PI:-1}" = "0" ]; then
		return 0
	fi

	"${binary}" setup pi
}

if [ "${DEVCONTAINER_PHASE}" = "build" ]; then
	echo "Skipping Engram user-local install during image build"
	exit 0
fi

install_engram
setup_engram_data_dir
setup_pi_integration
