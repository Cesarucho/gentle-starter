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

: "${VITEST_VERSION:=latest}"

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
