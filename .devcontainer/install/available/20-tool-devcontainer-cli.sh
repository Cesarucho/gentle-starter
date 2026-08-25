#!/usr/bin/env bash
#
# 20-tool-devcontainer-cli.sh — install the devcontainer CLI.
#
# The devcontainer CLI (devcontainer open / build / logs / etc.) is the
# project's interface for managing the devcontainer lifecycle from the
# host. It is a global npm package and a core dependency — every rebuild
# of the devcontainer image needs it available without requiring a
# separate host-side install step. Runs as part of core/ during image
# build, after 15-task.sh has refreshed the apt indexes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${DEVCONTAINER_CLI_VERSION:=${TOOL_DEVCONTAINER_CLI_VERSION:-latest}}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'DEVCONTAINER_CLI_VERSION=%s\n' "${DEVCONTAINER_CLI_VERSION}"
	exit 0
fi

if devcontainer_has_cmd devcontainer; then
	devcontainer_log_info "devcontainer CLI already installed: $(devcontainer --version 2>/dev/null || command -v devcontainer)"
	exit 0
fi

devcontainer_log_info "Installing @devcontainers/cli@${DEVCONTAINER_CLI_VERSION} globally via npm"
devcontainer_run_as_root npm install -g "@devcontainers/cli@${DEVCONTAINER_CLI_VERSION}"

if ! devcontainer_has_cmd devcontainer; then
	devcontainer_log_error "devcontainer CLI install failed: binary not on PATH"
	exit 1
fi

devcontainer_log_info "devcontainer CLI installed: $(command -v devcontainer)"
