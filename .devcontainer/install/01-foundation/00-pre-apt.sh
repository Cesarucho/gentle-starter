#!/usr/bin/env bash
#
# 00-pre-apt.sh — seed noninteractive timezone configuration before apt work.
#
# Mirrors the legacy .devcontainer/scripts/02-configure-tz-locale.sh with
# the common.sh helpers. Runs as part of core/ during image build.
#
# Locale generation runs after the locales package is installed by 10-system.sh.
# Override the timezone via env: TZ.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${TZ:=America/Mexico_City}"
# Timezone --------------------------------------------------------------------
devcontainer_log_info "Configuring timezone: ${TZ}"
devcontainer_run_as_root ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
devcontainer_run_as_root tee /etc/timezone >/dev/null <<<"${TZ}"

devcontainer_log_info "Pre-apt configuration complete (TZ=${TZ})"
