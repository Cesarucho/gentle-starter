#!/usr/bin/env bash
# Image-owned CLI; project initialization is an explicit user action.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"
devcontainer_load_tool_versions
: "${OPENSPEC_VERSION:=${LOCK_OPENSPEC_VERSION:?missing LOCK_OPENSPEC_VERSION}}"
[[ "${OPENSPEC_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
	devcontainer_log_error "OpenSpec requires an exact stable SemVer"
	exit 1
}
if [ "${1:-}" = --print-version-policy ]; then
	printf 'OPENSPEC_VERSION=%s\n' "${OPENSPEC_VERSION}"
	exit 0
fi
if devcontainer_is_runtime; then
	devcontainer_log_info "OpenSpec is image-owned; rebuild to install or update it."
	exit 0
fi
devcontainer_require_cmd npm "Enable core Node before OpenSpec."
devcontainer_require_cmd node "Enable core Node before OpenSpec."
node_version="$(node --version)"
node_version="${node_version#v}"
if [[ ! "${node_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
	[ "$(printf '%s\n%s\n' 20.19.0 "${node_version}" | sort -V | head -n 1)" != 20.19.0 ]; then
	devcontainer_log_error "OpenSpec requires Node >=20.19.0"
	exit 1
fi
installed_version="$(openspec --version 2>/dev/null || true)"
if [ "${installed_version}" = "${OPENSPEC_VERSION}" ]; then
	devcontainer_log_info "OpenSpec ${OPENSPEC_VERSION} already installed"
	exit 0
fi
devcontainer_run_as_root npm install -g "@fission-ai/openspec@${OPENSPEC_VERSION}"
installed_version="$(openspec --version)"
[ "${installed_version}" = "${OPENSPEC_VERSION}" ] || {
	devcontainer_log_error "OpenSpec executable version mismatch: ${installed_version}"
	exit 1
}
devcontainer_log_info "OpenSpec ${OPENSPEC_VERSION} installed; initialize projects manually."
