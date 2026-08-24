#!/usr/bin/env bash
#
# 40-python-graphify.sh — install Graphify in an isolated Python environment.
#
# The PyPI distribution is currently named `graphifyy`; it provides the
# `graphify` and `graphify-mcp` commands.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${GRAPHIFY_VERSION:=0.9.48}"
: "${GRAPHIFY_INSTALL_DIR:=/opt/graphify}"
: "${GRAPHIFY_BIN_DIR:=/usr/local/bin}"

if devcontainer_has_cmd graphify && devcontainer_has_cmd graphify-mcp; then
	devcontainer_log_info "Graphify and Graphify MCP already installed: $(graphify --version)"
	exit 0
fi

if ! devcontainer_has_cmd python3; then
	devcontainer_log_error "Python 3.10 or newer is required to install Graphify"
	exit 1
fi
if ! python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 10))'; then
	devcontainer_log_error "Graphify requires Python 3.10 or newer: $(python3 --version)"
	exit 1
fi

devcontainer_log_info "Installing Python venv support"
devcontainer_run_as_root apt-get update
devcontainer_run_as_root apt-get install -y --no-install-recommends python3-venv

devcontainer_log_info "Creating isolated Graphify environment at ${GRAPHIFY_INSTALL_DIR}"
devcontainer_run_as_root rm -rf "${GRAPHIFY_INSTALL_DIR}"
devcontainer_run_as_root python3 -m venv "${GRAPHIFY_INSTALL_DIR}"
devcontainer_run_as_root "${GRAPHIFY_INSTALL_DIR}/bin/pip" install \
	--no-cache-dir "graphifyy==${GRAPHIFY_VERSION}"

devcontainer_run_as_root ln -sfn "${GRAPHIFY_INSTALL_DIR}/bin/graphify" \
	"${GRAPHIFY_BIN_DIR}/graphify"
devcontainer_run_as_root ln -sfn "${GRAPHIFY_INSTALL_DIR}/bin/graphify-mcp" \
	"${GRAPHIFY_BIN_DIR}/graphify-mcp"

if ! devcontainer_has_cmd graphify || ! devcontainer_has_cmd graphify-mcp; then
	devcontainer_log_error "Graphify install failed: expected commands not on PATH"
	exit 1
fi

devcontainer_log_info "Graphify installed: $(graphify --version)"
