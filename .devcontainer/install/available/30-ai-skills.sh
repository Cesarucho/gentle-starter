#!/usr/bin/env bash
#
# 30-ai-skills.sh — install the `skills` npm package globally. Provides
# the `skills` CLI on PATH for managing agent skill packages.
#
# Mirrors .devcontainer/scripts/06-install-ai-skills.sh with the
# common.sh helpers. Requires pi to be present (provided by
# 30-ai-pi-coding.sh when linked from enabled/).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${SKILLS_VERSION:=1.5.10}"

if devcontainer_has_cmd skills; then
	devcontainer_log_info "skills already installed"
	exit 0
fi

devcontainer_log_info "Installing skills@${SKILLS_VERSION}"
devcontainer_run_as_root npm install -g "skills@${SKILLS_VERSION}"

devcontainer_log_info "skills installed"
