#!/usr/bin/env bash
#
# 40-cli-ansible.sh — install Ansible Core from Ubuntu packages.
#
# Opt-in CLI script for the install catalog. Enable it from 02-enabled/ when a
# project needs Ansible in the default tool set.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${ANSIBLE_PACKAGE:=ansible-core}"

ansible_version_line() {
	local output
	output="$(ansible --version)"
	printf '%s\n' "${output%%$'\n'*}"
}

if devcontainer_has_cmd ansible; then
	devcontainer_log_info "ansible already installed: $(ansible_version_line)"
	exit 0
fi

devcontainer_log_info "Updating apt indexes for ${ANSIBLE_PACKAGE}"
devcontainer_run_as_root apt-get update

devcontainer_log_info "Installing ${ANSIBLE_PACKAGE}"
devcontainer_run_as_root apt-get install -y --no-install-recommends "${ANSIBLE_PACKAGE}"

if ! devcontainer_has_cmd ansible; then
	devcontainer_log_error "ansible install failed: binary not on PATH"
	exit 1
fi

devcontainer_log_info "ansible installed: $(ansible_version_line)"
