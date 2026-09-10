#!/usr/bin/env bash
#
# 40-node-archify.sh — install Archify from its official release ZIP.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/archify-archive.sh"

devcontainer_load_tool_versions

: "${ARCHIFY_VERSION:=${LOCK_ARCHIFY_VERSION:?missing LOCK_ARCHIFY_VERSION}}"
: "${ARCHIFY_SHA256:=${LOCK_ARCHIFY_SHA256:?missing LOCK_ARCHIFY_SHA256}}"
: "${ARCHIFY_INSTALL_ROOT:=/opt/archify}"
: "${ARCHIFY_BIN:=/usr/local/bin/archify}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'ARCHIFY_VERSION=%s\nARCHIFY_SHA256=%s\n' "${ARCHIFY_VERSION}" "${ARCHIFY_SHA256}"
	exit 0
fi

fail() {
	devcontainer_log_error "$*"
	exit 1
}

archify_doctor() {
	"$1" doctor >/dev/null 2>&1
}

write_wrapper() {
	local destination="$1"
	cat >"${destination}" <<EOF
#!/usr/bin/env bash
export ARCHIFY_UPDATE_CHECK_DISABLED=1
exec node "${ARCHIFY_INSTALL_ROOT}/bin/archify.mjs" "\$@"
EOF
}

wrapper_is_managed() {
	local expected
	expected="$(mktemp)"
	write_wrapper "${expected}"
	cmp -s "${expected}" "${ARCHIFY_BIN}" && [ "$(stat -c '%a' "${ARCHIFY_BIN}" 2>/dev/null)" = 755 ]
	local result=$?
	rm -f "${expected}"
	return "${result}"
}

[[ "${ARCHIFY_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
	fail "ARCHIFY_VERSION must be an exact stable semantic version: ${ARCHIFY_VERSION}"
[[ "${ARCHIFY_SHA256}" =~ ^[0-9a-f]{64}$ ]] ||
	fail "ARCHIFY_SHA256 must be a 64-character lowercase digest"

case "$(devcontainer_arch)" in
amd64 | arm64) ;;
*) fail "Unsupported Archify architecture" ;;
esac

devcontainer_has_cmd node || fail "Node.js >=18 is required to install Archify"
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)"
if [[ ! "${NODE_MAJOR}" =~ ^[0-9]+$ ]] || [ "${NODE_MAJOR}" -lt 18 ]; then
	fail "Node.js >=18 is required to install Archify"
fi
devcontainer_has_cmd unzip || fail "unzip is required to install Archify"

if [ -f "${ARCHIFY_INSTALL_ROOT}/.archify-version" ] &&
	[ "$(<"${ARCHIFY_INSTALL_ROOT}/.archify-version")" = "${ARCHIFY_VERSION}" ] &&
	[ -f "${ARCHIFY_INSTALL_ROOT}/.archify-sha256" ] &&
	[ "$(<"${ARCHIFY_INSTALL_ROOT}/.archify-sha256")" = "${ARCHIFY_SHA256}" ] &&
	wrapper_is_managed && archify_doctor "${ARCHIFY_BIN}"; then
	devcontainer_log_info "Archify already installed and healthy: ${ARCHIFY_VERSION}"
	exit 0
fi

TMP_DIR="$(mktemp -d)"
INSTALL_PARENT="$(dirname "${ARCHIFY_INSTALL_ROOT}")"
STAGED_ROOT="${INSTALL_PARENT}/.archify.new.$$"
BACKUP_ROOT="${INSTALL_PARENT}/.archify.backup.$$"
STAGED_BIN="$(dirname "${ARCHIFY_BIN}")/.archify.new.$$"
BACKUP_BIN="$(dirname "${ARCHIFY_BIN}")/.archify.backup.$$"
cleanup() {
	rm -rf "${TMP_DIR}"
	if [ "${TRANSACTION_ACTIVE:-0}" -eq 1 ]; then
		set +e
		[ "${ROOT_ACTIVATED:-0}" -eq 0 ] || devcontainer_run_as_root rm -rf "${ARCHIFY_INSTALL_ROOT}"
		[ "${BIN_ACTIVATED:-0}" -eq 0 ] || devcontainer_run_as_root rm -rf "${ARCHIFY_BIN}"
		[ "${HAD_ROOT:-0}" -eq 0 ] || devcontainer_run_as_root mv "${BACKUP_ROOT}" "${ARCHIFY_INSTALL_ROOT}"
		[ "${HAD_BIN:-0}" -eq 0 ] || devcontainer_run_as_root mv "${BACKUP_BIN}" "${ARCHIFY_BIN}"
		set -e
	fi
	devcontainer_run_as_root rm -rf "${STAGED_ROOT}" "${STAGED_BIN}" 2>/dev/null || true
}
trap cleanup EXIT

ARCHIVE="${TMP_DIR}/archify.zip"
URL="https://github.com/tt-a1i/archify/releases/download/v${ARCHIFY_VERSION}/archify.zip"
devcontainer_log_info "Downloading Archify ${ARCHIFY_VERSION}"
devcontainer_fetch "${URL}" "${ARCHIVE}"
devcontainer_validate_archify_archive "${ARCHIVE}" "${ARCHIFY_VERSION}" "${ARCHIFY_SHA256}" "${TMP_DIR}/extracted" ||
	fail "Archify archive validation failed"
PACKAGE_ROOT="${TMP_DIR}/extracted/archify"

ARCHIFY_UPDATE_CHECK_DISABLED=1 node "${PACKAGE_ROOT}/bin/archify.mjs" doctor >/dev/null 2>&1 || fail "Archify staged doctor failed"

printf '%s\n' "${ARCHIFY_VERSION}" >"${PACKAGE_ROOT}/.archify-version"
printf '%s\n' "${ARCHIFY_SHA256}" >"${PACKAGE_ROOT}/.archify-sha256"
devcontainer_run_as_root mkdir -p "${INSTALL_PARENT}" "$(dirname "${ARCHIFY_BIN}")"
devcontainer_run_as_root cp -R "${PACKAGE_ROOT}" "${STAGED_ROOT}"
devcontainer_run_as_root chown -R root:root "${STAGED_ROOT}"
devcontainer_run_as_root find "${STAGED_ROOT}" -type d -exec chmod 0755 {} +
devcontainer_run_as_root find "${STAGED_ROOT}" -type f -exec chmod 0644 {} +
devcontainer_run_as_root chmod 0755 "${STAGED_ROOT}/bin/archify.mjs"
write_wrapper "${TMP_DIR}/archify-wrapper"
chmod 0755 "${TMP_DIR}/archify-wrapper"
devcontainer_run_as_root install -m 0755 "${TMP_DIR}/archify-wrapper" "${STAGED_BIN}"

HAD_ROOT=0
HAD_BIN=0
ROOT_ACTIVATED=0
BIN_ACTIVATED=0
TRANSACTION_ACTIVE=1
if devcontainer_run_as_root test -e "${ARCHIFY_INSTALL_ROOT}"; then
	devcontainer_run_as_root mv "${ARCHIFY_INSTALL_ROOT}" "${BACKUP_ROOT}"
	HAD_ROOT=1
fi
if devcontainer_run_as_root test -e "${ARCHIFY_BIN}" || devcontainer_run_as_root test -L "${ARCHIFY_BIN}"; then
	devcontainer_run_as_root mv "${ARCHIFY_BIN}" "${BACKUP_BIN}"
	HAD_BIN=1
fi
devcontainer_run_as_root mv "${STAGED_ROOT}" "${ARCHIFY_INSTALL_ROOT}"
ROOT_ACTIVATED=1
devcontainer_run_as_root mv "${STAGED_BIN}" "${ARCHIFY_BIN}"
BIN_ACTIVATED=1

if ! wrapper_is_managed || ! archify_doctor "${ARCHIFY_BIN}"; then
	fail "Archify install verification failed; restored previous installation"
fi

TRANSACTION_ACTIVE=0
devcontainer_run_as_root rm -rf "${BACKUP_ROOT}" "${BACKUP_BIN}"
devcontainer_log_info "Archify installed: ${ARCHIFY_VERSION}"
