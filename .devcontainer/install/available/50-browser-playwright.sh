#!/usr/bin/env bash
#
# 50-browser-playwright.sh — Playwright + chromium browser installer.
#
# Installs both:
#   - playwright library + chromium (headless browser for programmatic use)
#   - @playwright/cli (CLI designed for coding agents with shell access)
#
# Opt in by linking from 03-enabled/: cd .devcontainer/install/03-enabled && ln -sfn ../available/50-browser-playwright.sh NN-browser-playwright.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${PLAYWRIGHT_VERSION:=${LOCK_PLAYWRIGHT_VERSION:?missing LOCK_PLAYWRIGHT_VERSION}}"
: "${PLAYWRIGHT_CLI_VERSION:=${LOCK_PLAYWRIGHT_CLI_VERSION:?missing LOCK_PLAYWRIGHT_CLI_VERSION}}"
: "${PLAYWRIGHT_BROWSERS_PATH:=/opt/ms-playwright}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'PLAYWRIGHT_VERSION=%s\n' "${PLAYWRIGHT_VERSION}"
	printf 'PLAYWRIGHT_CLI_VERSION=%s\n' "${PLAYWRIGHT_CLI_VERSION}"
	exit 0
fi

devcontainer_require_cmd npm "Enable 20-runtime-node.sh before Playwright." || exit 1
devcontainer_require_cmd npx "Enable 20-runtime-node.sh before Playwright." || exit 1
devcontainer_require_cmd sudo "Enable the foundation user setup before Playwright." || exit 1

: "${UID_NAME:=ubuntu}"
if ! user_record="$(getent passwd "${UID_NAME}")"; then
	devcontainer_log_error "Playwright requires the configured user ${UID_NAME}; run foundation setup first."
	exit 1
fi
IFS=: read -r _ _ user_id _ _ user_home _ <<<"${user_record}"
if [[ ! "${user_id}" =~ ^[1-9][0-9]*$ || "${user_home}" != /* || "${user_home}" = / ]] ||
	[ ! -d "${user_home}" ] || [ "$(realpath -e -- "${user_home}")" != "${user_home}" ]; then
	devcontainer_log_error "Playwright requires a non-root user with an existing canonical home: ${UID_NAME}."
	exit 1
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
	devcontainer_log_info "Installing @playwright/cli@${PLAYWRIGHT_CLI_VERSION}"
	devcontainer_run_as_root npm install -g "@playwright/cli@${PLAYWRIGHT_CLI_VERSION}"
fi

devcontainer_log_info "Preparing playwright-cli configuration and skills as ${UID_NAME}"
# The CLI writes relative to cwd, not just HOME. Never run user provisioning as root.
sudo -H -u "${UID_NAME}" bash -s -- "${user_home}" "${user_id}" <<'EOF'
set -euo pipefail
if [ "$(id -u)" != "$2" ] || [ "${HOME:-}" != "$1" ] || [ ! -w "${HOME}" ]; then
	printf 'ERROR: Playwright requires the configured user HOME to be writable: %s\n' "$1" >&2
	exit 1
fi
cd -- "${HOME}"

# Upstream copies skills recursively and may patch .gitignore; preserve existing state.
for directory in .playwright .claude .claude/skills .claude/skills/playwright-cli; do
	if [ -L "${directory}" ] || { [ -e "${directory}" ] && [ ! -d "${directory}" ]; }; then
		printf 'ERROR: Refusing unsafe Playwright provisioning directory: %s\n' "${directory}" >&2
		exit 1
	fi
done
config=.playwright/cli.config.json
if [ -L "${config}" ] || { [ -e "${config}" ] && [ ! -f "${config}" ]; }; then
	printf 'ERROR: Refusing unsafe Playwright configuration: %s\n' "${config}" >&2
	exit 1
fi
if [ -f "${config}" ] && [ -d .claude/skills/playwright-cli ]; then
	printf 'Preserving existing Playwright configuration and skills.\n'
	exit 0
fi
if [ -e .git ] || [ -L .git ]; then
	printf 'ERROR: Refusing Playwright provisioning in a home that is a Git workspace.\n' >&2
	exit 1
fi
if [ -d .claude/skills/playwright-cli ]; then
	playwright-cli install
else
	playwright-cli install --skills
fi
EOF
