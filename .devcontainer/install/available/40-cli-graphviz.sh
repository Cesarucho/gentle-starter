#!/usr/bin/env bash
#
# 40-cli-graphviz.sh — install Graphviz from Ubuntu packages.
#
# Provides the `dot` command and the standard Graphviz layout/rendering tools.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${GRAPHVIZ_PACKAGE:=graphviz}"

if devcontainer_has_cmd dot; then
	devcontainer_log_info "Graphviz already installed: $(dot -V 2>&1)"
	exit 0
fi

devcontainer_log_info "Updating apt indexes for ${GRAPHVIZ_PACKAGE}"
devcontainer_run_as_root apt-get update

devcontainer_log_info "Installing ${GRAPHVIZ_PACKAGE}"
devcontainer_run_as_root apt-get install -y --no-install-recommends \
	"${GRAPHVIZ_PACKAGE}"

if ! devcontainer_has_cmd dot; then
	devcontainer_log_error "Graphviz install failed: dot not on PATH"
	exit 1
fi

devcontainer_log_info "Graphviz installed: $(dot -V 2>&1)"
