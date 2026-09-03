#!/usr/bin/env bash
#
# 20-runtime-node.sh — install Node.js via the NodeSource apt repo.
#
# Mirrors .devcontainer/scripts/03-install-node.sh with the common.sh
# helpers. Lives in available/; opt in by linking it from enabled/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${NODE_MAJOR:=${TOOL_NODE_MAJOR:-26}}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'NODE_MAJOR=%s\n' "${NODE_MAJOR}"
	exit 0
fi

if devcontainer_has_cmd node; then
	devcontainer_log_info "node already installed: $(node --version)"
	exit 0
fi

devcontainer_log_info "Adding NodeSource apt repo (major ${NODE_MAJOR})"
curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" |
	devcontainer_run_as_root bash -

devcontainer_log_info "Installing nodejs package"
devcontainer_run_as_root apt-get install -y --no-install-recommends nodejs

devcontainer_log_info "node $(node --version), npm $(npm --version)"
