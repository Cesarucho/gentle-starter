#!/usr/bin/env bash
#
# 50-browser-playwright.sh — Playwright + chromium browser installer.
#
# Installs both:
#   - playwright library + chromium (headless browser for programmatic use)
#   - @playwright/cli (CLI designed for coding agents with shell access)
#
# Opt in by linking from 02-enabled/: cd .devcontainer/install/02-enabled && ln -sfn ../available/50-browser-playwright.sh NN-browser-playwright.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${PLAYWRIGHT_VERSION:=${TOOL_PLAYWRIGHT_VERSION:-1.60.0}}"
: "${PLAYWRIGHT_BROWSERS_PATH:=/opt/ms-playwright}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'PLAYWRIGHT_VERSION=%s\n' "${PLAYWRIGHT_VERSION}"
	exit 0
fi

devcontainer_log_info "Preparing playwright browsers path at ${PLAYWRIGHT_BROWSERS_PATH}"
devcontainer_run_as_root mkdir -p "${PLAYWRIGHT_BROWSERS_PATH}"
devcontainer_run_as_root chmod 0755 "${PLAYWRIGHT_BROWSERS_PATH}"

# --- playwright library + chromium ---
if devcontainer_has_cmd playwright; then
	devcontainer_log_info "playwright already installed, skipping library"
else
	devcontainer_log_info "Installing playwright@${PLAYWRIGHT_VERSION}"
	devcontainer_run_as_root npm install -g "playwright@${PLAYWRIGHT_VERSION}"
fi

devcontainer_log_info "Installing chromium browser with system dependencies"
PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH}" \
	npx -y "playwright@${PLAYWRIGHT_VERSION}" install chromium --with-deps

# --- @playwright/cli (CLI for coding agents) ---
if devcontainer_has_cmd playwright-cli; then
	devcontainer_log_info "playwright-cli already installed, skipping CLI"
else
	devcontainer_log_info "Installing @playwright/cli"
	devcontainer_run_as_root npm install -g @playwright/cli@latest
fi

devcontainer_log_info "Installing playwright-cli skills"
playwright-cli install --skills
