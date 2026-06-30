#!/usr/bin/env bash
#
# 40-node-markdownlint.sh — install markdownlint-cli2 globally.
#
# Provides the `markdownlint-cli2` CLI for deterministic Markdown linting.
# Requires Node.js/npm, normally provided by 20-runtime-node.sh when linked
# from enabled/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${MARKDOWNLINT_CLI2_VERSION:=0.22.1}"

markdownlint_cli2_version() {
	markdownlint-cli2 --help | sed -n '1p'
}

if devcontainer_has_cmd markdownlint-cli2; then
	devcontainer_log_info "markdownlint-cli2 already installed: $(markdownlint_cli2_version)"
	exit 0
fi

if ! devcontainer_has_cmd npm; then
	devcontainer_log_error "npm is required to install markdownlint-cli2"
	devcontainer_log_error "Enable 20-runtime-node.sh before this script"
	exit 1
fi

devcontainer_log_info "Installing markdownlint-cli2@${MARKDOWNLINT_CLI2_VERSION}"
devcontainer_run_as_root npm install -g \
	"markdownlint-cli2@${MARKDOWNLINT_CLI2_VERSION}"

devcontainer_log_info "markdownlint-cli2 installed: $(markdownlint_cli2_version)"
