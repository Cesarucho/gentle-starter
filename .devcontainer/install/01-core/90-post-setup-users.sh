#!/usr/bin/env bash
#
# 90-post-setup-users.sh — ensure the ubuntu user has passwordless sudo.
#
# Runs as part of 01-core/ during image build. The legacy version of
# this script (and its ARG-driven HOST_UID/HOST_GID plumbing) also
# provisioned a host-mapped 'devuser'. That path was removed when the
# project settled on the 'ubuntu' user as the single devcontainer
# identity. If a future need brings devuser back, fork this script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${UID_NAME:=ubuntu}"
: "${DEVCONTAINER_USER_HOME:=/home/${UID_NAME}}"

devcontainer_log_info "Ensuring ubuntu sudoers entry"
devcontainer_run_as_root tee /etc/sudoers.d/95-ubuntu >/dev/null <<<'ubuntu ALL=(ALL) NOPASSWD:ALL'
devcontainer_run_as_root chmod 0440 /etc/sudoers.d/95-ubuntu

devcontainer_log_info "Ensuring ubuntu user-local executable directories"
devcontainer_run_as_root install -d -m 0755 -o "${UID_NAME}" -g "${UID_NAME}" \
	"${DEVCONTAINER_USER_HOME}/.local" \
	"${DEVCONTAINER_USER_HOME}/.local/bin"

devcontainer_log_info "Post-setup users configured"
