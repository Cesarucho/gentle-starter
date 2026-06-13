#!/usr/bin/env bash
#
# 50-browser-playwright.sh — Playwright + chromium browser installer (currently not enabled).
#
# Opt in by linking from 02-enabled/: cd .devcontainer/install/02-enabled && ln -sfn ../available/50-browser-playwright.sh 50-browser-playwright.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${PLAYWRIGHT_VERSION:=1.60.0}"
: "${PLAYWRIGHT_BROWSERS_PATH:=/opt/ms-playwright}"

if devcontainer_has_cmd playwright; then
    devcontainer_log_info "playwright already installed"
    exit 0
fi

devcontainer_log_info "Preparing playwright browsers path at ${PLAYWRIGHT_BROWSERS_PATH}"
devcontainer_run_as_root mkdir -p "${PLAYWRIGHT_BROWSERS_PATH}"
devcontainer_run_as_root chmod 0755 "${PLAYWRIGHT_BROWSERS_PATH}"

devcontainer_log_info "Installing playwright@${PLAYWRIGHT_VERSION}"
devcontainer_run_as_root npm install -g "playwright@${PLAYWRIGHT_VERSION}"

devcontainer_log_info "Installing chromium browser with system dependencies"
PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH}" \
    npx -y "playwright@${PLAYWRIGHT_VERSION}" install chromium --with-deps
