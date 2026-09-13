#!/usr/bin/env bash
#
# 30-ai-pi-coding.sh — install the @earendil-works/pi-coding-agent npm
# package globally. Provides the `pi` binary on PATH.
#
# Mirrors .devcontainer/scripts/07-install-ai-pi-coding.sh with the
# common.sh helpers. Runs in the optional image-build group (03-enabled).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${PI_CODING_AGENT_VERSION:=${LOCK_PI_CODING_AGENT_VERSION:?missing LOCK_PI_CODING_AGENT_VERSION}}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'PI_CODING_AGENT_VERSION=%s\n' "${PI_CODING_AGENT_VERSION}"
	exit 0
fi

devcontainer_require_cmd npm "Enable 20-runtime-node.sh before Pi Coding." || exit 1

if devcontainer_has_cmd pi; then
	devcontainer_log_info "pi already installed: $(pi --version)"
	exit 0
fi

devcontainer_log_info "Installing @earendil-works/pi-coding-agent@${PI_CODING_AGENT_VERSION}"
devcontainer_run_as_root npm install -g --ignore-scripts \
	"@earendil-works/pi-coding-agent@${PI_CODING_AGENT_VERSION}"

devcontainer_log_info "pi installed: $(pi --version)"
