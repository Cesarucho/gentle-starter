#!/usr/bin/env bash
#
# 40-cli-kubectl.sh — install kubectl from the official Kubernetes release.
#
# Opt-in CLI script for the install catalog. Enable it from 02-enabled/ when a
# project needs kubectl in the default tool set.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${KUBECTL_VERSION:=1.36.2}"
: "${KUBECTL_INSTALL_DIR:=/usr/local/bin}"

kubectl_client_version() {
	local output
	output="$(kubectl version --client 2>/dev/null)"
	printf '%s\n' "${output%%$'\n'*}"
}

if devcontainer_has_cmd kubectl; then
	devcontainer_log_info "kubectl already installed: $(kubectl_client_version)"
	exit 0
fi

ARCH="$(devcontainer_arch)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

BINARY_PATH="${TMP_DIR}/kubectl"
CHECKSUM_PATH="${TMP_DIR}/kubectl.sha256"
BINARY_URL="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
CHECKSUM_URL="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl.sha256"

if [ "${KUBECTL_VERSION#v}" != "${KUBECTL_VERSION}" ]; then
	devcontainer_log_error "KUBECTL_VERSION must not include the v prefix: ${KUBECTL_VERSION}"
	exit 1
fi

devcontainer_log_info "Downloading kubectl ${KUBECTL_VERSION} (${ARCH})"
devcontainer_fetch "${BINARY_URL}" "${BINARY_PATH}"
devcontainer_fetch "${CHECKSUM_URL}" "${CHECKSUM_PATH}"

devcontainer_verify_sha256 "${BINARY_PATH}" "$(tr -d '[:space:]' <"${CHECKSUM_PATH}")"

devcontainer_run_as_root install -m 0755 "${BINARY_PATH}" \
	"${KUBECTL_INSTALL_DIR}/kubectl"

if ! devcontainer_has_cmd kubectl; then
	devcontainer_log_error "kubectl install failed: binary not on PATH"
	exit 1
fi

devcontainer_log_info "kubectl installed: $(kubectl_client_version)"
