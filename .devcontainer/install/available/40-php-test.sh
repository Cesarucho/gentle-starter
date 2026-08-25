#!/usr/bin/env bash
#
# 40-php-test.sh — PHPUnit for PHP testing.
#
# REQUIRES: 40-php-lang.sh (php must be installed first)
#
# Installs PHPUnit globally via Composer.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${PHPUNIT_VERSION:=${TOOL_PHPUNIT_VERSION:-10}}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'PHPUNIT_VERSION=%s\n' "${PHPUNIT_VERSION}"
	exit 0
fi

# Guard: skip if php is not present (this tool depends on php being installed).
if ! devcontainer_has_cmd php; then
	devcontainer_log_warn "Skipping PHPUnit: php is not installed. Run 'task install:enable -- 40-php-lang' first."
	exit 0
fi

if devcontainer_has_cmd phpunit; then
	devcontainer_log_info "phpunit already installed: $(phpunit --version)"
	exit 0
fi

devcontainer_log_info "Installing phpunit/phpunit@${PHPUNIT_VERSION} globally via composer"
composer global require --quiet "phpunit/phpunit@${PHPUNIT_VERSION}"

# Ensure composer's global bin dir is on PATH for the current user.
# The installer prints the path; we use the conventional location.
COMPOSER_BIN="${HOME}/.config/composer/vendor/bin"
if [ -d "${COMPOSER_BIN}" ] && [ ! -L "/usr/local/bin/phpunit" ]; then
	devcontainer_run_as_root ln -sfn "${COMPOSER_BIN}/phpunit" /usr/local/bin/phpunit
fi

if devcontainer_has_cmd phpunit; then
	devcontainer_log_info "phpunit installed: $(phpunit --version)"
else
	devcontainer_log_error "phpunit install failed: binary not on PATH after composer global require"
	exit 1
fi
