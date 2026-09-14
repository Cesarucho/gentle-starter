#!/usr/bin/env bash
#
# 2040-node-contracts.sh — install API contract tooling globally with npm.
#
# Provides Spectral, Redocly CLI, and AsyncAPI CLI. Requires Node.js/npm,
# normally provided by 2000-runtime-node.sh when enabled.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${SPECTRAL_VERSION:=${LOCK_SPECTRAL_VERSION:?missing LOCK_SPECTRAL_VERSION}}"
: "${REDOCLY_VERSION:=${LOCK_REDOCLY_VERSION:?missing LOCK_REDOCLY_VERSION}}"
: "${ASYNCAPI_VERSION:=${LOCK_ASYNCAPI_VERSION:?missing LOCK_ASYNCAPI_VERSION}}"

prepare_asyncapi_logger_directory() {
	local npm_root logger_parent logger_directory
	npm_root="$(devcontainer_run_as_root npm root -g)" || return 1
	logger_parent="${npm_root}/@asyncapi/cli/lib/utils"
	logger_directory="${logger_parent}/logs"
	if [[ "${npm_root}" != /* ]] || [ ! -d "${logger_parent}" ] ||
		[ -L "${logger_directory}" ] || { [ -e "${logger_directory}" ] && [ ! -d "${logger_directory}" ]; }; then
		devcontainer_log_error "Unsafe or missing AsyncAPI logger directory: ${logger_directory}"
		return 1
	fi
	# AsyncAPI 6.0.2 creates this directory on import despite using only console
	# transports. Seed it at install time; keep global package files root-owned.
	if [ ! -d "${logger_directory}" ]; then
		devcontainer_run_as_root mkdir -m 0755 "${logger_directory}"
	fi
}

if devcontainer_has_cmd spectral && devcontainer_has_cmd redocly && devcontainer_has_cmd asyncapi; then
	prepare_asyncapi_logger_directory
	devcontainer_log_info "API contract CLIs already installed"
	devcontainer_log_info "spectral $(spectral --version), redocly $(redocly --version), asyncapi $(asyncapi --version)"
	exit 0
fi

if ! devcontainer_has_cmd npm; then
	devcontainer_log_error "npm is required to install the API contract CLIs"
	devcontainer_log_error "Enable 2000-runtime-node.sh before this script"
	exit 1
fi

devcontainer_log_info "Installing API contract CLIs globally"
devcontainer_run_as_root npm install -g \
	"@stoplight/spectral-cli@${SPECTRAL_VERSION}" \
	"@redocly/cli@${REDOCLY_VERSION}" \
	"@asyncapi/cli@${ASYNCAPI_VERSION}"

prepare_asyncapi_logger_directory

for command_name in spectral redocly asyncapi; do
	if ! devcontainer_has_cmd "${command_name}"; then
		devcontainer_log_error "${command_name} install failed: binary not on PATH"
		exit 1
	fi
done

devcontainer_log_info "spectral $(spectral --version), redocly $(redocly --version), asyncapi $(asyncapi --version)"
