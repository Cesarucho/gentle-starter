#!/usr/bin/env bash
#
# 00-pre-apt.sh — configure timezone and locale before any apt work.
#
# Mirrors the legacy .devcontainer/scripts/02-configure-tz-locale.sh with
# the common.sh helpers. Runs as part of core/ during image build.
#
# Override via env: TZ, LOCALE.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${TZ:=America/Mexico_City}"
: "${LOCALE:=es_MX.UTF-8}"

# Timezone --------------------------------------------------------------------
devcontainer_log_info "Configuring timezone: ${TZ}"
devcontainer_run_as_root ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
devcontainer_run_as_root tee /etc/timezone >/dev/null <<<"${TZ}"
devcontainer_run_as_root dpkg-reconfigure -f noninteractive tzdata

# Locale ----------------------------------------------------------------------
devcontainer_log_info "Configuring locale: ${LOCALE}"
devcontainer_run_as_root bash -c "
if grep -q '^# ${LOCALE} UTF-8' /etc/locale.gen; then
    sed -i 's/^# ${LOCALE} UTF-8/${LOCALE} UTF-8/' /etc/locale.gen
elif ! grep -q '^${LOCALE} UTF-8' /etc/locale.gen; then
    echo '${LOCALE} UTF-8' >>/etc/locale.gen
fi
"
devcontainer_run_as_root locale-gen "${LOCALE}"
devcontainer_run_as_root update-locale LANG="${LOCALE}" LANGUAGE="${LOCALE}" LC_ALL="${LOCALE}"

devcontainer_log_info "Pre-apt configuration complete (TZ=${TZ}, LOCALE=${LOCALE})"
