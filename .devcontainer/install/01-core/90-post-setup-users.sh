#!/usr/bin/env bash
#
# 90-post-setup-users.sh — provision host-mapped user and sudoers entries.
#
# Mirrors the legacy .devcontainer/scripts/90-create-users.sh with the
# common.sh helpers. Runs as part of core/ during image build.
#
# Params: HOST_UID, HOST_GID (defaults 1001/1001 to match legacy behavior).
# The devuser account is only created when HOST_UID differs from 1000 to
# preserve backward compatibility with the existing image.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${HOST_UID:=1001}"
: "${HOST_GID:=1001}"

if [ "${HOST_UID}" != "1000" ]; then
	devcontainer_log_info "Creating devuser (uid=${HOST_UID}, gid=${HOST_GID})"
	devcontainer_run_as_root groupadd -g "${HOST_GID}" devuser 2>/dev/null || true

	if ! devcontainer_run_as_root id -u devuser >/dev/null 2>&1; then
		devcontainer_run_as_root useradd -u "${HOST_UID}" -g "${HOST_GID}" -m -s /bin/bash devuser 2>/dev/null || true
	fi

	devcontainer_run_as_root tee /etc/sudoers.d/90-devuser >/dev/null <<<'devuser ALL=(ALL) NOPASSWD:ALL'
	devcontainer_run_as_root chmod 0440 /etc/sudoers.d/90-devuser
fi

devcontainer_log_info "Ensuring ubuntu sudoers entry"
devcontainer_run_as_root tee /etc/sudoers.d/95-ubuntu >/dev/null <<<'ubuntu ALL=(ALL) NOPASSWD:ALL'
devcontainer_run_as_root chmod 0440 /etc/sudoers.d/95-ubuntu

devcontainer_log_info "Post-setup users configured"
