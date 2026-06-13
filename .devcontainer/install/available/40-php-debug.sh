#!/usr/bin/env bash
#
# 40-php-debug.sh — Xdebug for PHP debugging.
#
# REQUIRES: 40-php-lang.sh (php must be installed first)
#
# Installs and configures Xdebug as a PHP extension.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

# Guard: skip if php is not present (this tool depends on php being installed).
if ! devcontainer_has_cmd php; then
    devcontainer_log_warn "Skipping Xdebug: php is not installed. Run 'task install:enable -- 40-php-lang' first."
    exit 0
fi

PHP_MAJOR="$(php -r 'echo PHP_MAJOR_VERSION;')"
PHP_MINOR="$(php -r 'echo PHP_MINOR_VERSION;')"
PHP_VERSION="${PHP_MAJOR}.${PHP_MINOR}"

# Check if xdebug is already loaded.
if php -m 2>/dev/null | grep -qi xdebug; then
    devcontainer_log_info "Xdebug already loaded in PHP ${PHP_VERSION}"
    exit 0
fi

devcontainer_log_info "Installing php${PHP_VERSION}-xdebug from Ondrej Sury PPA"
devcontainer_run_as_root apt-get update -qq
devcontainer_run_as_root apt-get install -y --no-install-recommends "php${PHP_VERSION}-xdebug"

# Configure Xdebug for development: mode=debug + start_with_request=yes.
XDEBUG_INI="/etc/php/${PHP_VERSION}/mods-available/xdebug.ini"
if [ -f "${XDEBUG_INI}" ]; then
    devcontainer_log_info "Configuring Xdebug in ${XDEBUG_INI}"
    cat >"${XDEBUG_INI}" <<'XDEBUG_CONF'
zend_extension=xdebug
xdebug.mode=debug
xdebug.start_with_request=yes
xdebug.client_host=host.docker.internal
xdebug.discover_client_host=true
XDEBUG_CONF
else
    devcontainer_log_warn "Xdebug INI not found at ${XDEBUG_INI}; please configure manually"
fi

if php -m 2>/dev/null | grep -qi xdebug; then
    devcontainer_log_info "Xdebug loaded: $(php -m | grep -i xdebug)"
else
    devcontainer_log_error "Xdebug install failed: module not loaded after apt install"
    exit 1
fi
