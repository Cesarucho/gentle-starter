#!/usr/bin/env bash
# Replace EXAMPLE_* values and URL/artifact rules before enabling this installer.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions
: "${EXAMPLE_VERSION:=${TOOL_EXAMPLE_VERSION:-}}"
: "${EXAMPLE_SHA256_AMD64:=${TOOL_EXAMPLE_SHA256_AMD64:-}}"
: "${EXAMPLE_SHA256_ARM64:=${TOOL_EXAMPLE_SHA256_ARM64:-}}"
: "${EXAMPLE_INSTALL_DIR:=/usr/local/bin}"
: "${EXAMPLE_FETCH_ATTEMPTS:=3}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'EXAMPLE_VERSION=%s\n' "${EXAMPLE_VERSION}"
	exit 0
fi

fail() {
	devcontainer_log_error "$*"
	exit 1
}
example_version_from() {
	"$1" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1
}

[[ "${EXAMPLE_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "EXAMPLE_VERSION must be exact stable SemVer"
[[ "${EXAMPLE_FETCH_ATTEMPTS}" =~ ^[1-9][0-9]*$ ]] || fail "EXAMPLE_FETCH_ATTEMPTS must be positive"

arch="$(devcontainer_arch)"
case "${arch}" in
amd64) expected_sha="${EXAMPLE_SHA256_AMD64}" ;;
arm64) expected_sha="${EXAMPLE_SHA256_ARM64}" ;;
*) fail "Unsupported architecture: ${arch}" ;;
esac
[[ "${expected_sha}" =~ ^[0-9a-f]{64}$ ]] || fail "Missing valid ${arch} SHA-256"

target="${EXAMPLE_INSTALL_DIR}/example"
if [ -x "${target}" ] && [ "$(example_version_from "${target}" || true)" = "${EXAMPLE_VERSION}" ]; then
	devcontainer_log_info "example already installed: ${EXAMPLE_VERSION}"
	exit 0
fi

tmp="$(mktemp -d)"
staged="${EXAMPLE_INSTALL_DIR}/.example.new.$$"
backup="${EXAMPLE_INSTALL_DIR}/.example.backup.$$"
had_previous=0
target_replaced=0
install_verified=0
cleanup() {
	local status=$?
	local preserve_backup=0
	trap - EXIT
	if [ "${target_replaced}" -eq 1 ] && [ "${install_verified}" -eq 0 ]; then
		if [ "${had_previous}" -eq 1 ]; then
			if devcontainer_run_as_root mv -f "${backup}" "${target}"; then
				devcontainer_log_warn "Interrupted or failed install; restored previous binary"
			else
				preserve_backup=1
				status=1
				devcontainer_log_error "Rollback failed; previous binary preserved at ${backup}"
			fi
		elif devcontainer_run_as_root rm -f "${target}"; then
			devcontainer_log_warn "Interrupted or failed install; removed unverified binary"
		else
			status=1
			devcontainer_log_error "Rollback failed; unverified binary remains at ${target}"
		fi
	fi
	rm -rf "${tmp}"
	devcontainer_run_as_root rm -f "${staged}" 2>/dev/null || true
	if [ "${preserve_backup}" -eq 0 ]; then
		devcontainer_run_as_root rm -f "${backup}" 2>/dev/null || true
	fi
	exit "${status}"
}
trap cleanup EXIT

# TODO: replace URL and archive/extraction rules with verified upstream facts.
url="https://example.invalid/releases/v${EXAMPLE_VERSION}/example_linux_${arch}.tar.gz"
archive="${tmp}/artifact.tar.gz"
for ((attempt = 1; attempt <= EXAMPLE_FETCH_ATTEMPTS; attempt++)); do
	devcontainer_fetch "${url}" "${archive}" && break
	[ "${attempt}" -lt "${EXAMPLE_FETCH_ATTEMPTS}" ] || fail "Download failed after ${attempt} attempts"
	sleep "${attempt}"
done
devcontainer_verify_sha256 "${archive}" "${expected_sha}"
tar -xzf "${archive}" -C "${tmp}" example
[ "$(example_version_from "${tmp}/example" || true)" = "${EXAMPLE_VERSION}" ] || fail "Staged binary version mismatch"

devcontainer_run_as_root mkdir -p "${EXAMPLE_INSTALL_DIR}"
if devcontainer_run_as_root test -f "${target}"; then
	had_previous=1
	devcontainer_run_as_root cp -p "${target}" "${backup}"
fi
devcontainer_run_as_root install -m 0755 "${tmp}/example" "${staged}"
target_replaced=1
devcontainer_run_as_root mv -f "${staged}" "${target}"
if [ "$(example_version_from "${target}" || true)" != "${EXAMPLE_VERSION}" ]; then
	fail "Final verification failed"
fi
install_verified=1
devcontainer_run_as_root rm -f "${backup}"
devcontainer_log_info "example installed: ${EXAMPLE_VERSION}"
