#!/usr/bin/env bash
# Image-owned CLI only; browser setup and project configuration remain explicit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"
devcontainer_load_tool_versions
: "${LIKEC4_VERSION:=${LOCK_LIKEC4_VERSION:?missing LOCK_LIKEC4_VERSION}}"
[[ "${LIKEC4_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
	devcontainer_log_error "LikeC4 requires an exact stable SemVer"
	exit 1
}
if [ "${1:-}" = --print-version-policy ]; then
	printf 'LIKEC4_VERSION=%s\n' "${LIKEC4_VERSION}"
	exit 0
fi
if devcontainer_is_runtime; then
	devcontainer_log_info "LikeC4 is image-owned; rebuild to install or update it."
	exit 0
fi
devcontainer_require_cmd npm "Enable core Node before LikeC4."
devcontainer_require_cmd node "Enable core Node before LikeC4."
node_version="$(node --version)"
node_version="${node_version#v}"
if [[ ! "${node_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
	[ "$(printf '%s\n%s\n' 22.22.3 "${node_version}" | sort -V | head -n 1)" != 22.22.3 ]; then
	devcontainer_log_error "LikeC4 requires Node >=22.22.3"
	exit 1
fi
installed_version="$(likec4 --version 2>/dev/null || true)"
if [ "${installed_version}" = "${LIKEC4_VERSION}" ]; then
	devcontainer_log_info "LikeC4 ${LIKEC4_VERSION} already installed"
	exit 0
fi
# npm registry integrity is provider-delegated. Do not run dependency lifecycle
# scripts or download/configure browsers during CLI installation.
devcontainer_run_as_root npm install -g --ignore-scripts "likec4@${LIKEC4_VERSION}"
installed_version="$(likec4 --version)"
[ "${installed_version}" = "${LIKEC4_VERSION}" ] || {
	devcontainer_log_error "LikeC4 executable version mismatch: ${installed_version}"
	exit 1
}
devcontainer_log_info "LikeC4 ${LIKEC4_VERSION} installed; configure rendering separately."
