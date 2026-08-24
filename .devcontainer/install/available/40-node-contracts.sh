#!/usr/bin/env bash
#
# 40-node-contracts.sh — install API contract tooling globally with npm.
#
# Provides Spectral, Redocly CLI, and AsyncAPI CLI. Requires Node.js/npm,
# normally provided by 20-runtime-node.sh when enabled.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${SPECTRAL_VERSION:=6.16.3}"
: "${REDOCLY_VERSION:=2.47.0}"
: "${ASYNCAPI_VERSION:=6.0.2}"

if devcontainer_has_cmd spectral && devcontainer_has_cmd redocly && devcontainer_has_cmd asyncapi; then
	devcontainer_log_info "API contract CLIs already installed"
	devcontainer_log_info "spectral $(spectral --version), redocly $(redocly --version), asyncapi $(asyncapi --version)"
	exit 0
fi

if ! devcontainer_has_cmd npm; then
	devcontainer_log_error "npm is required to install the API contract CLIs"
	devcontainer_log_error "Enable 20-runtime-node.sh before this script"
	exit 1
fi

devcontainer_log_info "Installing API contract CLIs globally"
devcontainer_run_as_root npm install -g \
	"@stoplight/spectral-cli@${SPECTRAL_VERSION}" \
	"@redocly/cli@${REDOCLY_VERSION}" \
	"@asyncapi/cli@${ASYNCAPI_VERSION}"

for command_name in spectral redocly asyncapi; do
	if ! devcontainer_has_cmd "${command_name}"; then
		devcontainer_log_error "${command_name} install failed: binary not on PATH"
		exit 1
	fi
done

devcontainer_log_info "spectral $(spectral --version), redocly $(redocly --version), asyncapi $(asyncapi --version)"
