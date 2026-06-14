#!/usr/bin/env bash
#
# 20-runtime-go.sh — install Go from the official tarball.
#
# Mirrors .devcontainer/scripts/11-install-go.sh with the common.sh
# helpers. Architecture resolution uses devcontainer_arch.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${GO_VERSION:=latest}"

if devcontainer_has_cmd go; then
	devcontainer_log_info "go already installed: $(go version)"
	exit 0
fi

target_arch="$(devcontainer_arch)"

if [ "${GO_VERSION}" = "latest" ]; then
	devcontainer_log_info "Resolving latest stable Go version from go.dev"
	GO_VERSION="$(curl -fsSL "https://go.dev/dl/?mode=json" | jq -r '.[0].version')"
fi

archive="${GO_VERSION}.linux-${target_arch}.tar.gz"
download_url="https://go.dev/dl/${archive}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

devcontainer_log_info "Downloading Go ${GO_VERSION} (${target_arch})"
devcontainer_fetch "${download_url}" "${tmp_dir}/${archive}"

devcontainer_run_as_root rm -rf /usr/local/go
devcontainer_run_as_root tar -C /usr/local -xzf "${tmp_dir}/${archive}"
devcontainer_run_as_root ln -sfn /usr/local/go/bin/go /usr/local/bin/go
devcontainer_run_as_root ln -sfn /usr/local/go/bin/gofmt /usr/local/bin/gofmt

devcontainer_log_info "go installed: $(go version)"
