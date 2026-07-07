#!/usr/bin/env bash
#
# 40-cli-glow.sh — install Glow from the official Charm apt repository.
#
# Default-active CLI script for the install catalog. Adds the Charm apt
# repository keyring and installs the `glow` package.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${GLOW_APT_KEYRING:=/etc/apt/keyrings/charm.gpg}"
: "${GLOW_APT_LIST:=/etc/apt/sources.list.d/charm.list}"
: "${GLOW_APT_REPO:=deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *}"

if devcontainer_has_cmd glow; then
	devcontainer_log_info "glow already installed: $(glow --version | head -n 1)"
	exit 0
fi

devcontainer_log_info "Installing prerequisites for Charm apt repository"
devcontainer_run_as_root apt-get update
devcontainer_run_as_root apt-get install -y --no-install-recommends gnupg

devcontainer_log_info "Configuring Charm apt repository"
devcontainer_run_as_root mkdir -p /etc/apt/keyrings

devcontainer_run_as_root bash -lc "
set -euo pipefail
curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o \"\$1\"
printf '%s\\n' \"\$2\" > \"\$3\"
" -- "${GLOW_APT_KEYRING}" "${GLOW_APT_REPO}" "${GLOW_APT_LIST}"

devcontainer_log_info "Installing glow"
devcontainer_run_as_root apt-get update
devcontainer_run_as_root apt-get install -y --no-install-recommends glow

if ! devcontainer_has_cmd glow; then
	devcontainer_log_error "glow install failed: binary not on PATH"
	exit 1
fi

devcontainer_log_info "glow installed: $(glow --version | head -n 1)"
