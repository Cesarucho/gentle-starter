#!/usr/bin/env bash
#
# 3050-ai-skills.sh — install the `skills` npm package globally. Provides
# the `skills` CLI on PATH for managing agent skill packages.
#
# Mirrors .devcontainer/scripts/06-install-ai-skills.sh with the
# common.sh helpers. Requires Node/npm; it does not require Pi.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${SKILLS_VERSION:=${LOCK_SKILLS_VERSION:?missing LOCK_SKILLS_VERSION}}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'SKILLS_VERSION=%s\n' "${SKILLS_VERSION}"
	exit 0
fi

devcontainer_require_cmd npm "Enable 2000-runtime-node.sh before Skills." || exit 1

if devcontainer_has_cmd skills; then
	devcontainer_log_info "skills already installed"
	exit 0
fi

devcontainer_log_info "Installing skills@${SKILLS_VERSION}"
devcontainer_run_as_root npm install -g "skills@${SKILLS_VERSION}"

devcontainer_log_info "skills installed"
