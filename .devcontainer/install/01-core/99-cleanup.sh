#!/usr/bin/env bash
#
# 99-cleanup.sh — final cleanup of caches and temp directories.
#
# Mirrors the legacy .devcontainer/scripts/99-clean-setup.sh with the
# common.sh helpers. Runs as part of core/ at the end of image build.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_log_info "Cleaning apt and npm caches"
devcontainer_run_as_root apt-get clean

if devcontainer_has_cmd npm; then
    devcontainer_run_as_root npm cache clean --force
fi

devcontainer_log_info "Removing cache and temp directories"
devcontainer_run_as_root rm -rf /root/.npm
devcontainer_run_as_root rm -rf /usr/local/lib/node_modules/.cache
devcontainer_run_as_root rm -rf /var/lib/apt/lists/*
devcontainer_run_as_root rm -rf /tmp/*

devcontainer_log_info "Cleanup complete"
