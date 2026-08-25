#!/usr/bin/env bash
#
# 40-cli-gitleaks.sh — install Gitleaks from the official GitHub release.
#
# Downloads the architecture-specific release archive and verifies it against
# the checksums published with the same release.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${GITLEAKS_VERSION:=${TOOL_GITLEAKS_VERSION:-8.30.1}}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'GITLEAKS_VERSION=%s\n' "${GITLEAKS_VERSION}"
	exit 0
fi
: "${GITLEAKS_INSTALL_DIR:=/usr/local/bin}"

if devcontainer_has_cmd gitleaks; then
	devcontainer_log_info "Gitleaks already installed: $(gitleaks version)"
	exit 0
fi

if [ "${GITLEAKS_VERSION#v}" != "${GITLEAKS_VERSION}" ]; then
	devcontainer_log_error "GITLEAKS_VERSION must not include the v prefix: ${GITLEAKS_VERSION}"
	exit 1
fi

case "$(devcontainer_arch)" in
amd64)
	GITLEAKS_ARCH="x64"
	;;
arm64)
	GITLEAKS_ARCH="arm64"
	;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

ARCHIVE_NAME="gitleaks_${GITLEAKS_VERSION}_linux_${GITLEAKS_ARCH}.tar.gz"
ARCHIVE_PATH="${TMP_DIR}/${ARCHIVE_NAME}"
CHECKSUMS_PATH="${TMP_DIR}/gitleaks_${GITLEAKS_VERSION}_checksums.txt"
RELEASE_URL="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}"
EXPECTED_SHA=""

devcontainer_log_info "Downloading Gitleaks ${GITLEAKS_VERSION} (${GITLEAKS_ARCH})"
devcontainer_fetch "${RELEASE_URL}/${ARCHIVE_NAME}" "${ARCHIVE_PATH}"
devcontainer_fetch "${RELEASE_URL}/gitleaks_${GITLEAKS_VERSION}_checksums.txt" \
	"${CHECKSUMS_PATH}"

EXPECTED_SHA="$({
	awk -v target="${ARCHIVE_NAME}" '$2 == target || $2 == "*" target { print $1; exit }' \
		"${CHECKSUMS_PATH}"
})"
if [ -z "${EXPECTED_SHA}" ]; then
	devcontainer_log_error "Could not find checksum for ${ARCHIVE_NAME}"
	exit 1
fi

devcontainer_verify_sha256 "${ARCHIVE_PATH}" "${EXPECTED_SHA}"
tar -xzf "${ARCHIVE_PATH}" -C "${TMP_DIR}" gitleaks

devcontainer_run_as_root install -m 0755 "${TMP_DIR}/gitleaks" \
	"${GITLEAKS_INSTALL_DIR}/gitleaks"

if ! devcontainer_has_cmd gitleaks; then
	devcontainer_log_error "Gitleaks install failed: binary not on PATH"
	exit 1
fi

devcontainer_log_info "Gitleaks installed: $(gitleaks version)"
