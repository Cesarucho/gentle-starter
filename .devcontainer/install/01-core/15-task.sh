#!/usr/bin/env bash
#
# 15-task.sh — install go-task, the task runner used by Taskfile.yml.
#
# External APT-managed core bootstrap: Cloudsmith selects and authenticates the
# package through its signed APT repository. The initial repository setup script
# is trusted through HTTPS/provider delivery, not authenticated by APT itself.
# Task intentionally stays outside TOOL/LOCK policy to preserve the foundation
# cache boundary. Runs after 10-system.sh and before 90-post-setup-users.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

if devcontainer_has_cmd task; then
	devcontainer_log_info "task already installed: $(task --version)"
	exit 0
fi

devcontainer_log_info "Adding official go-task Cloudsmith APT repository"
curl -1sLf "https://dl.cloudsmith.io/public/task/task/setup.deb.sh" |
	devcontainer_run_as_root bash -

devcontainer_log_info "Installing task package"
devcontainer_run_as_root apt-get install -y --no-install-recommends task

devcontainer_log_info "task installed: $(task --version)"
