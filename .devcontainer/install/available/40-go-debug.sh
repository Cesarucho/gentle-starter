#!/usr/bin/env bash
#
# 40-go-debug.sh — Delve debugger for Go.
#
# REQUIRES: 20-runtime-go.sh (go must be installed first)
#
# Downloads the pre-built Delve binary from GitHub releases.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${DELVE_VERSION:=${TOOL_DELVE_VERSION:-v1.26.3}}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'DELVE_VERSION=%s\n' "${DELVE_VERSION}"
	exit 0
fi

# Guard: skip if go is not present (this tool depends on go being installed).
if ! devcontainer_has_cmd go; then
	devcontainer_log_warn "Skipping dlv: go is not installed. Run 'task install:enable -- 20-runtime-go' first."
	exit 0
fi

if devcontainer_has_cmd dlv; then
	devcontainer_log_info "dlv already installed: $(dlv version)"
	exit 0
fi

target_arch="$(devcontainer_arch)"

archive="dlv_${DELVE_VERSION#v}_linux_${target_arch}.tar.gz"
download_url="https://github.com/go-delve/delve/releases/download/${DELVE_VERSION}/${archive}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

devcontainer_log_info "Downloading Delve ${DELVE_VERSION} for linux/${target_arch}"
devcontainer_fetch "${download_url}" "${tmp_dir}/${archive}"

devcontainer_log_info "Installing dlv"
tar -xzf "${tmp_dir}/${archive}" -C "${tmp_dir}"
devcontainer_install_bin "${tmp_dir}/dlv"

devcontainer_log_info "dlv installed: $(dlv version)"
