#!/usr/bin/env bash
#
# 40-php-lang.sh — PHP 8.x + Composer.
#
# Installs PHP from the Ondrej Sury PPA (the standard for Debian/Ubuntu)
# and Composer as the package manager.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${PHP_VERSION:=8.4}"

if devcontainer_has_cmd php; then
	devcontainer_log_info "php already installed: $(php --version | head -1)"
	exit 0
fi

devcontainer_log_info "Adding Ondrej Sury PHP PPA (php${PHP_VERSION})"
devcontainer_run_as_root apt-get update -qq
devcontainer_run_as_root apt-get install -y --no-install-recommends \
	software-properties-common

add-apt-repository -y ppa:ondrej/php >/dev/null 2>&1 || true
devcontainer_run_as_root apt-get update -qq

devcontainer_log_info "Installing php${PHP_VERSION}-cli and php${PHP_VERSION}-curl"
devcontainer_run_as_root apt-get install -y --no-install-recommends \
	"php${PHP_VERSION}-cli" \
	"php${PHP_VERSION}-curl" \
	"php${PHP_VERSION}-mbstring" \
	"php${PHP_VERSION}-xml" \
	"php${PHP_VERSION}-zip"

# Install Composer (official installer).
devcontainer_log_info "Installing Composer"
composer_installer="/tmp/composer-setup.php"
devcontainer_fetch "https://getcomposer.org/installer" "${composer_installer}"
devcontainer_run_as_root php "${composer_installer}" -- --install-dir=/usr/local/bin --filename=composer
rm -f "${composer_installer}"

devcontainer_log_info "php $(php --version | head -1), composer $(composer --version | head -1)"
