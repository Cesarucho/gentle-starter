#!/usr/bin/env bash
#
# 2320-php-test.sh — PHPUnit for PHP testing.
#
# REQUIRES: 2300-php-lang.sh (php must be installed first)
#
# Installs image-managed PHPUnit via Composer in a shared, root-owned prefix.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${PHPUNIT_VERSION:=${LOCK_PHPUNIT_VERSION:?missing LOCK_PHPUNIT_VERSION}}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'PHPUNIT_VERSION=%s\n' "${PHPUNIT_VERSION}"
	exit 0
fi

# Guard: skip if php is not present (this tool depends on php being installed).
devcontainer_require_cmd php "Enable 2300-php-lang.sh before PHPUnit." || exit 1
devcontainer_require_cmd composer "Enable 2300-php-lang.sh before PHPUnit." || exit 1

if devcontainer_has_cmd phpunit; then
	devcontainer_log_info "phpunit already installed: $(phpunit --version)"
	exit 0
fi

devcontainer_log_info "Installing phpunit/phpunit:${PHPUNIT_VERSION} globally via composer"
# Do not link into the build user's private HOME or modify user Composer config.
PHPUNIT_COMPOSER_HOME="/usr/local/share/phpunit"
(
	umask 022
	devcontainer_run_as_root env COMPOSER_HOME="${PHPUNIT_COMPOSER_HOME}" \
		composer global require --quiet "phpunit/phpunit:${PHPUNIT_VERSION}"
)
COMPOSER_BIN="$(devcontainer_run_as_root env COMPOSER_HOME="${PHPUNIT_COMPOSER_HOME}" \
	composer global config bin-dir --absolute)"
[ -x "${COMPOSER_BIN}/phpunit" ] || {
	devcontainer_log_error "phpunit install failed: binary missing from Composer bin-dir"
	exit 1
}
devcontainer_run_as_root ln -sfn "${COMPOSER_BIN}/phpunit" /usr/local/bin/phpunit

if devcontainer_has_cmd phpunit; then
	devcontainer_log_info "phpunit installed: $(phpunit --version)"
else
	devcontainer_log_error "phpunit install failed: binary not on PATH after composer global require"
	exit 1
fi
