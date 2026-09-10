#!/usr/bin/env bash
#
# 40-node-test.sh — vitest for Node.js testing.
#
# REQUIRES: 20-runtime-node.sh (node must be installed first)
#
# Installs vitest globally via npm.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${VITEST_VERSION:=${LOCK_VITEST_VERSION:?missing LOCK_VITEST_VERSION}}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'VITEST_VERSION=%s\n' "${VITEST_VERSION}"
	exit 0
fi

devcontainer_require_cmd npm "Enable 20-runtime-node.sh before Vitest." || exit 1

# Guard: skip if node is not present (this tool depends on node being installed).
if ! devcontainer_has_cmd node; then
	devcontainer_log_warn "Skipping vitest: node is not installed. Run 'task install:enable -- 20-runtime-node' first."
	exit 0
fi

if devcontainer_has_cmd vitest; then
	devcontainer_log_info "vitest already installed: $(vitest --version)"
	exit 0
fi

devcontainer_log_info "Installing vitest@${VITEST_VERSION} globally via npm"
npm install -g "vitest@${VITEST_VERSION}"

devcontainer_log_info "vitest installed: $(vitest --version)"
