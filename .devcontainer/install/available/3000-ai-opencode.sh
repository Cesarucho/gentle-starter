#!/usr/bin/env bash
#
# 3000-ai-opencode.sh — install a verified OpenCode release into the image.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/tar-archive.sh"

devcontainer_load_tool_versions

: "${OPENCODE_VERSION:=${LOCK_OPENCODE_VERSION:?missing LOCK_OPENCODE_VERSION}}"
: "${OPENCODE_INSTALL_DIR:=/usr/local/bin}"
OPENCODE_TEMP_DIR=""
OPENCODE_STAGED_BINARY=""

cleanup_opencode_install() {
	[ -z "${OPENCODE_STAGED_BINARY}" ] || rm -f "${OPENCODE_STAGED_BINARY}"
	[ -z "${OPENCODE_TEMP_DIR}" ] || rm -rf "${OPENCODE_TEMP_DIR}"
}

abort_opencode_install() {
	cleanup_opencode_install
	exit 1
}

opencode_binary() {
	printf '%s/opencode' "${OPENCODE_INSTALL_DIR}"
}

installed_opencode_version() {
	local binary
	binary="$(opencode_binary)"

	if [ ! -x "${binary}" ]; then
		return 1
	fi

	"${binary}" --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1
}

install_opencode() {
	local architecture asset_arch digest archive_url tmp_dir archive extracted
	architecture="$(devcontainer_arch)"
	case "${architecture}" in
	amd64)
		asset_arch=x64
		digest="${LOCK_OPENCODE_SHA256_AMD64:?missing LOCK_OPENCODE_SHA256_AMD64}"
		;;
	arm64)
		asset_arch=arm64
		digest="${LOCK_OPENCODE_SHA256_ARM64:?missing LOCK_OPENCODE_SHA256_ARM64}"
		;;
	*)
		devcontainer_log_error "Unsupported OpenCode architecture: ${architecture}"
		return 1
		;;
	esac
	[[ "${digest}" =~ ^[0-9a-f]{64}$ ]] || {
		devcontainer_log_error "Invalid OpenCode SHA-256 for ${architecture}"
		return 1
	}
	if [ "$(installed_opencode_version 2>/dev/null || true)" = "${OPENCODE_VERSION}" ]; then
		devcontainer_log_info "OpenCode ${OPENCODE_VERSION} already installed"
		return 0
	fi
	tmp_dir="$(mktemp -d)"
	OPENCODE_TEMP_DIR="${tmp_dir}"
	trap cleanup_opencode_install EXIT
	trap abort_opencode_install HUP INT TERM
	archive="${tmp_dir}/opencode.tar.gz"
	archive_url="https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-${asset_arch}.tar.gz"
	devcontainer_fetch "${archive_url}" "${archive}"
	printf '%s  %s\n' "${digest}" "${archive}" | sha256sum -c -
	mkdir "${tmp_dir}/extract"
	devcontainer_validate_single_binary_tar "${archive}" opencode "${tmp_dir}/extract"
	extracted="${tmp_dir}/extract/opencode"
	install -d -m 0755 "${OPENCODE_INSTALL_DIR}"
	OPENCODE_STAGED_BINARY="$(opencode_binary).new"
	install -m 0755 "${extracted}" "${OPENCODE_STAGED_BINARY}"
	if [ "$("${OPENCODE_STAGED_BINARY}" --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)" != "${OPENCODE_VERSION}" ]; then
		return 1
	fi
	mv -f "${OPENCODE_STAGED_BINARY}" "$(opencode_binary)"
	OPENCODE_STAGED_BINARY=""
	cleanup_opencode_install
	OPENCODE_TEMP_DIR=""
	trap - EXIT HUP INT TERM
}

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'OPENCODE_VERSION=%s\n' "${OPENCODE_VERSION}"
	exit 0
fi

if devcontainer_is_runtime; then
	devcontainer_log_info "OpenCode binary is image-owned; runtime installation is skipped"
	exit 0
fi

install_opencode
