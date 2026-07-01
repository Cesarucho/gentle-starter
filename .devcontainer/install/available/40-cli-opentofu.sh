#!/usr/bin/env bash
#
# 40-cli-opentofu.sh — install OpenTofu from the official GitHub release.
#
# Opt-in CLI script for the install catalog. Enable it from 02-enabled/ when a
# project needs OpenTofu in the default tool set.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${OPENTOFU_VERSION:=1.12.3}"
: "${OPENTOFU_INSTALL_DIR:=/usr/local/bin}"

tofu_version_line() {
	local output
	output="$(tofu version)"
	printf '%s\n' "${output%%$'\n'*}"
}

if devcontainer_has_cmd tofu; then
	devcontainer_log_info "tofu already installed: $(tofu_version_line)"
	exit 0
fi

ARCH="$(devcontainer_arch)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

ARCHIVE_NAME="tofu_${OPENTOFU_VERSION}_linux_${ARCH}.zip"
ARCHIVE_PATH="${TMP_DIR}/${ARCHIVE_NAME}"
CHECKSUMS_PATH="${TMP_DIR}/tofu_${OPENTOFU_VERSION}_SHA256SUMS"
ARCHIVE_URL="https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/${ARCHIVE_NAME}"
CHECKSUMS_URL="https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_SHA256SUMS"
UNPACK_DIR="${TMP_DIR}/unpack"
EXPECTED_SHA=""

if [ "${OPENTOFU_VERSION#v}" != "${OPENTOFU_VERSION}" ]; then
	devcontainer_log_error "OPENTOFU_VERSION must not include the v prefix: ${OPENTOFU_VERSION}"
	exit 1
fi

devcontainer_log_info "Downloading OpenTofu ${OPENTOFU_VERSION} (${ARCH})"
devcontainer_fetch "${ARCHIVE_URL}" "${ARCHIVE_PATH}"
devcontainer_fetch "${CHECKSUMS_URL}" "${CHECKSUMS_PATH}"

EXPECTED_SHA="$({
	awk -v target="${ARCHIVE_NAME}" '$2 == target || $2 == "*" target { print $1; exit }' \
		"${CHECKSUMS_PATH}"
})"
if [ -z "${EXPECTED_SHA}" ]; then
	devcontainer_log_error "Could not find checksum for ${ARCHIVE_NAME}"
	exit 1
fi

devcontainer_verify_sha256 "${ARCHIVE_PATH}" "${EXPECTED_SHA}"

mkdir -p "${UNPACK_DIR}"
unzip -q "${ARCHIVE_PATH}" -d "${UNPACK_DIR}"
devcontainer_run_as_root install -m 0755 "${UNPACK_DIR}/tofu" \
	"${OPENTOFU_INSTALL_DIR}/tofu"

if ! devcontainer_has_cmd tofu; then
	devcontainer_log_error "tofu install failed: binary not on PATH"
	exit 1
fi

devcontainer_log_info "tofu installed: $(tofu_version_line)"
