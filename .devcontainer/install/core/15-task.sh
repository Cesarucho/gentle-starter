#!/usr/bin/env bash
#
# 15-task.sh — install go-task, the task runner used by Taskfile.yml.
#
# go-task is a single static binary but the project installs it via the
# official apt repo so future updates land through apt. Runs as part of
# core/ during image build, after 10-system.sh has refreshed the apt
# indexes and before 90-post-setup-users.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

if devcontainer_has_cmd task; then
	devcontainer_log_info "task already installed: $(task --version)"
	exit 0
fi

devcontainer_log_info "Adding go-task apt repo (cloudsmith)"
curl -1sLf "https://dl.cloudsmith.io/public/task/task/setup.deb.sh" \
	| devcontainer_run_as_root bash -

devcontainer_log_info "Installing task package"
devcontainer_run_as_root apt-get install -y --no-install-recommends task

devcontainer_log_info "task installed: $(task --version)"
