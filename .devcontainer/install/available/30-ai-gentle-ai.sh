#!/usr/bin/env bash
#
# 30-ai-gentle-ai.sh — install the Gentle AI CLI from its official GitHub release.
#
# Installs only the CLI binary. It deliberately does not run `gentle-ai install`
# or `gentle-ai sync`, which manage user and agent configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${GENTLE_AI_VERSION:=${TOOL_GENTLE_AI_VERSION:-2.3.0}}"
: "${GENTLE_AI_SHA256_AMD64=${TOOL_GENTLE_AI_SHA256_AMD64:-}}"
: "${GENTLE_AI_SHA256_ARM64=${TOOL_GENTLE_AI_SHA256_ARM64:-}}"
: "${GENTLE_AI_INSTALL_DIR:=/usr/local/bin}"
: "${GENTLE_AI_FETCH_ATTEMPTS:=3}"
: "${GENTLE_AI_FETCH_RETRY_DELAY:=2}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'GENTLE_AI_VERSION=%s\n' "${GENTLE_AI_VERSION}"
	exit 0
fi

gentle_ai_version_from() {
	local binary="$1"
	local output
	output="$("${binary}" version 2>/dev/null || "${binary}" --version 2>/dev/null || true)"
	printf '%s\n' "${output}" |
		grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' |
		head -n 1 |
		sed 's/^v//'
}

download_archive() {
	local url="$1"
	local destination="$2"
	local attempt

	for ((attempt = 1; attempt <= GENTLE_AI_FETCH_ATTEMPTS; attempt += 1)); do
		if devcontainer_fetch "${url}" "${destination}"; then
			return 0
		fi
		if [ "${attempt}" -lt "${GENTLE_AI_FETCH_ATTEMPTS}" ]; then
			devcontainer_log_warn "Download attempt ${attempt} of ${GENTLE_AI_FETCH_ATTEMPTS} failed; retrying"
			sleep "$((GENTLE_AI_FETCH_RETRY_DELAY * attempt))"
		fi
	done

	devcontainer_log_error "Gentle AI download failed after ${GENTLE_AI_FETCH_ATTEMPTS} attempts"
	return 1
}

if [ "${GENTLE_AI_VERSION#v}" != "${GENTLE_AI_VERSION}" ]; then
	devcontainer_log_error "GENTLE_AI_VERSION must not include the v prefix: ${GENTLE_AI_VERSION}"
	exit 1
fi
if [[ ! "${GENTLE_AI_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	devcontainer_log_error "GENTLE_AI_VERSION must be an exact stable semantic version: ${GENTLE_AI_VERSION}"
	exit 1
fi
if [[ ! "${GENTLE_AI_FETCH_ATTEMPTS}" =~ ^[1-9][0-9]*$ ]]; then
	devcontainer_log_error "GENTLE_AI_FETCH_ATTEMPTS must be a positive integer"
	exit 1
fi
if [[ ! "${GENTLE_AI_FETCH_RETRY_DELAY}" =~ ^[0-9]+$ ]]; then
	devcontainer_log_error "GENTLE_AI_FETCH_RETRY_DELAY must be a non-negative integer"
	exit 1
fi

ARCH="$(devcontainer_arch)"
case "${ARCH}" in
amd64) EXPECTED_SHA="${GENTLE_AI_SHA256_AMD64}" ;;
arm64) EXPECTED_SHA="${GENTLE_AI_SHA256_ARM64}" ;;
*)
	devcontainer_log_error "Unsupported Gentle AI architecture: ${ARCH}"
	exit 1
	;;
esac
if [[ ! "${EXPECTED_SHA}" =~ ^[0-9a-f]{64}$ ]]; then
	devcontainer_log_error "Gentle AI ${ARCH} SHA-256 must be a 64-character lowercase digest"
	exit 1
fi

if devcontainer_has_cmd gentle-ai; then
	INSTALLED_VERSION="$(gentle_ai_version_from "$(command -v gentle-ai)" || true)"
	if [ "${INSTALLED_VERSION}" = "${GENTLE_AI_VERSION}" ]; then
		devcontainer_log_info "Gentle AI already installed: ${INSTALLED_VERSION}"
		exit 0
	fi
	devcontainer_log_info "Replacing Gentle AI ${INSTALLED_VERSION:-unknown} with ${GENTLE_AI_VERSION}"
fi

TMP_DIR="$(mktemp -d)"
STAGED_BINARY="${GENTLE_AI_INSTALL_DIR}/.gentle-ai.new.$$"
BACKUP_BINARY="${GENTLE_AI_INSTALL_DIR}/.gentle-ai.backup.$$"
TARGET_BINARY="${GENTLE_AI_INSTALL_DIR}/gentle-ai"
cleanup() {
	rm -rf "${TMP_DIR}"
	devcontainer_run_as_root rm -f "${STAGED_BINARY}" "${BACKUP_BINARY}" 2>/dev/null || true
}
trap cleanup EXIT

ARCHIVE_NAME="gentle-ai_${GENTLE_AI_VERSION}_linux_${ARCH}.tar.gz"
ARCHIVE_PATH="${TMP_DIR}/${ARCHIVE_NAME}"
RELEASE_URL="https://github.com/Gentleman-Programming/gentle-ai/releases/download/v${GENTLE_AI_VERSION}"

devcontainer_log_info "Downloading Gentle AI ${GENTLE_AI_VERSION} (${ARCH})"
download_archive "${RELEASE_URL}/${ARCHIVE_NAME}" "${ARCHIVE_PATH}"
devcontainer_verify_sha256 "${ARCHIVE_PATH}" "${EXPECTED_SHA}"
tar -xzf "${ARCHIVE_PATH}" -C "${TMP_DIR}" gentle-ai

EXTRACTED_VERSION="$(gentle_ai_version_from "${TMP_DIR}/gentle-ai" || true)"
if [ "${EXTRACTED_VERSION}" != "${GENTLE_AI_VERSION}" ]; then
	devcontainer_log_error "Gentle AI archive failed verification: expected ${GENTLE_AI_VERSION}, got ${EXTRACTED_VERSION:-unknown}"
	exit 1
fi

devcontainer_run_as_root mkdir -p "${GENTLE_AI_INSTALL_DIR}"
HAD_PREVIOUS_BINARY=0
if devcontainer_run_as_root test -f "${TARGET_BINARY}"; then
	HAD_PREVIOUS_BINARY=1
	devcontainer_run_as_root cp -p "${TARGET_BINARY}" "${BACKUP_BINARY}"
fi
devcontainer_run_as_root install -m 0755 "${TMP_DIR}/gentle-ai" "${STAGED_BINARY}"
devcontainer_run_as_root mv -f "${STAGED_BINARY}" "${TARGET_BINARY}"

INSTALLED_VERSION="$(gentle_ai_version_from "${TARGET_BINARY}" || true)"
if [ "${INSTALLED_VERSION}" != "${GENTLE_AI_VERSION}" ]; then
	if [ "${HAD_PREVIOUS_BINARY}" -eq 1 ]; then
		devcontainer_run_as_root mv -f "${BACKUP_BINARY}" "${TARGET_BINARY}"
		devcontainer_log_error "Gentle AI install verification failed; restored previous binary"
	else
		devcontainer_run_as_root rm -f "${TARGET_BINARY}"
		devcontainer_log_error "Gentle AI install verification failed; removed invalid binary"
	fi
	exit 1
fi

devcontainer_run_as_root rm -f "${BACKUP_BINARY}"
devcontainer_log_info "Gentle AI installed: ${INSTALLED_VERSION}"
