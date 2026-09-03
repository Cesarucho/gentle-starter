#!/usr/bin/env bash
#
# 30-ai-pi-coding.sh — install the @earendil-works/pi-coding-agent npm
# package globally. Provides the `pi` binary on PATH.
#
# Mirrors .devcontainer/scripts/07-install-ai-pi-coding.sh with the
# common.sh helpers. Runs in the image build (01-core / 02-enabled).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${PI_CODING_AGENT_VERSION:=${TOOL_PI_CODING_AGENT_VERSION:-0.80.2}}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'PI_CODING_AGENT_VERSION=%s\n' "${PI_CODING_AGENT_VERSION}"
	exit 0
fi

if devcontainer_has_cmd pi; then
	devcontainer_log_info "pi already installed: $(pi --version)"
	exit 0
fi

devcontainer_log_info "Installing @earendil-works/pi-coding-agent@${PI_CODING_AGENT_VERSION}"
devcontainer_run_as_root npm install -g --ignore-scripts \
	"@earendil-works/pi-coding-agent@${PI_CODING_AGENT_VERSION}"

devcontainer_log_info "pi installed: $(pi --version)"
