#!/usr/bin/env bash
#
# 20-runtime-pnpm.sh — install pnpm via npm global.
#
# Mirrors .devcontainer/scripts/13-install-pnpm.sh with the common.sh
# helpers. Requires node/npm to be present (provided by
# 20-runtime-node.sh when linked from enabled/).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${PNPM_VERSION:=latest}"

if devcontainer_has_cmd pnpm; then
    devcontainer_log_info "pnpm already installed: $(pnpm --version)"
    exit 0
fi

devcontainer_log_info "Installing pnpm@${PNPM_VERSION} via npm"
devcontainer_run_as_root npm install --global "pnpm@${PNPM_VERSION}"

devcontainer_log_info "pnpm installed: $(pnpm --version)"
