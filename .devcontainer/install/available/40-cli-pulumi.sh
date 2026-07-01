#!/usr/bin/env bash
#
# 40-cli-pulumi.sh — install Pulumi from the official GitHub release.
#
# Opt-in CLI script for the install catalog. Enable it from 02-enabled/ when a
# project needs Pulumi in the default tool set.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${PULUMI_VERSION:=3.248.0}"
: "${PULUMI_INSTALL_DIR:=/usr/local/bin}"

pulumi_version_line() {
	local output
	output="$(pulumi version)"
	printf '%s\n' "${output%%$'\n'*}"
}

if devcontainer_has_cmd pulumi; then
	devcontainer_log_info "pulumi already installed: $(pulumi_version_line)"
	exit 0
fi

ARCH="$(devcontainer_arch)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

case "${ARCH}" in
amd64)
	PULUMI_ARCH="x64"
	;;
arm64)
	PULUMI_ARCH="arm64"
	;;
esac

ARCHIVE_NAME="pulumi-v${PULUMI_VERSION}-linux-${PULUMI_ARCH}.tar.gz"
ARCHIVE_PATH="${TMP_DIR}/${ARCHIVE_NAME}"
CHECKSUMS_PATH="${TMP_DIR}/pulumi-${PULUMI_VERSION}-checksums.txt"
ARCHIVE_URL="https://github.com/pulumi/pulumi/releases/download/v${PULUMI_VERSION}/${ARCHIVE_NAME}"
CHECKSUMS_URL="https://github.com/pulumi/pulumi/releases/download/v${PULUMI_VERSION}/pulumi-${PULUMI_VERSION}-checksums.txt"
UNPACK_DIR="${TMP_DIR}/unpack"
EXPECTED_SHA=""

if [ "${PULUMI_VERSION#v}" != "${PULUMI_VERSION}" ]; then
	devcontainer_log_error "PULUMI_VERSION must not include the v prefix: ${PULUMI_VERSION}"
	exit 1
fi

devcontainer_log_info "Downloading Pulumi ${PULUMI_VERSION} (${PULUMI_ARCH})"
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
tar -xzf "${ARCHIVE_PATH}" -C "${UNPACK_DIR}"

if [ ! -d "${UNPACK_DIR}/pulumi" ]; then
	devcontainer_log_error "Pulumi archive layout changed: pulumi/ directory missing"
	exit 1
fi

find "${UNPACK_DIR}/pulumi" -maxdepth 1 -type f -perm /111 -print | while read -r bin; do
	devcontainer_run_as_root install -m 0755 "${bin}" \
		"${PULUMI_INSTALL_DIR}/$(basename "${bin}")"
done

if ! devcontainer_has_cmd pulumi; then
	devcontainer_log_error "pulumi install failed: binary not on PATH"
	exit 1
fi

devcontainer_log_info "pulumi installed: $(pulumi_version_line)"
