#!/usr/bin/env bash
#
# 40-cli-terragrunt.sh — install Terragrunt from the official GitHub release.
#
# Opt-in CLI script for the install catalog. Enable it from 02-enabled/ when a
# project needs Terragrunt in the default tool set.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${TERRAGRUNT_VERSION:=1.0.8}"
: "${TERRAGRUNT_INSTALL_DIR:=/usr/local/bin}"

terragrunt_version_line() {
	local output
	output="$(terragrunt --version)"
	printf '%s\n' "${output%%$'\n'*}"
}

if devcontainer_has_cmd terragrunt; then
	devcontainer_log_info "terragrunt already installed: $(terragrunt_version_line)"
	exit 0
fi

ARCH="$(devcontainer_arch)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

BINARY_NAME="terragrunt_linux_${ARCH}"
BINARY_PATH="${TMP_DIR}/${BINARY_NAME}"
CHECKSUMS_PATH="${TMP_DIR}/SHA256SUMS"
BINARY_URL="https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/${BINARY_NAME}"
CHECKSUMS_URL="https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/SHA256SUMS"
EXPECTED_SHA=""

if [ "${TERRAGRUNT_VERSION#v}" != "${TERRAGRUNT_VERSION}" ]; then
	devcontainer_log_error "TERRAGRUNT_VERSION must not include the v prefix: ${TERRAGRUNT_VERSION}"
	exit 1
fi

devcontainer_log_info "Downloading Terragrunt ${TERRAGRUNT_VERSION} (${ARCH})"
devcontainer_fetch "${BINARY_URL}" "${BINARY_PATH}"
devcontainer_fetch "${CHECKSUMS_URL}" "${CHECKSUMS_PATH}"

EXPECTED_SHA="$({
	awk -v target="${BINARY_NAME}" '$2 == target || $2 == "*" target { print $1; exit }' \
		"${CHECKSUMS_PATH}"
})"
if [ -z "${EXPECTED_SHA}" ]; then
	devcontainer_log_error "Could not find checksum for ${BINARY_NAME}"
	exit 1
fi

devcontainer_verify_sha256 "${BINARY_PATH}" "${EXPECTED_SHA}"

devcontainer_run_as_root install -m 0755 "${BINARY_PATH}" \
	"${TERRAGRUNT_INSTALL_DIR}/terragrunt"

if ! devcontainer_has_cmd terragrunt; then
	devcontainer_log_error "terragrunt install failed: binary not on PATH"
	exit 1
fi

devcontainer_log_info "terragrunt installed: $(terragrunt_version_line)"
