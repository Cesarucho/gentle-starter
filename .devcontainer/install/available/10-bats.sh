#!/usr/bin/env bash
#
# 10-bats.sh — install BATS (Bash Automated Testing System).
#
# Lifecycle:
#   * DEVCONTAINER_PHASE=build   during image build (Dockerfile RUN loop)
#   * DEVCONTAINER_PHASE=runtime during container start (setup.sh)
#
# This script is idempotent: it skips if BATS is already on PATH.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${BATS_VERSION:=latest}"
BATS_INSTALL_DIR="/usr/local"

# Only run during build (BATS is a dev tool, not needed at runtime).
if ! devcontainer_is_build; then
    devcontainer_log_info "Skipping BATS: not in build phase"
    exit 0
fi

# Idempotency: skip if BATS is already installed.
if devcontainer_has_cmd bats; then
    devcontainer_log_info "BATS already installed: $(command -v bats)"
    exit 0
fi

devcontainer_log_info "Installing BATS ${BATS_VERSION}"

# Clone BATS into a temporary directory.
BATS_TMPDIR="$(mktemp -d)"
git clone --depth 1 "https://github.com/bats-core/bats-core.git" "${BATS_TMPDIR}"

# Run BATS' own install.sh to place files under /usr/local.
# Use devcontainer_run_as_root because install.sh writes to /usr/local.
devcontainer_run_as_root "${BATS_TMPDIR}/install.sh" "${BATS_INSTALL_DIR}"

# Clean up.
rm -rf "${BATS_TMPDIR}"

# Verify.
if ! devcontainer_has_cmd bats; then
    devcontainer_log_error "BATS install failed: bats not on PATH after install"
    exit 1
fi

devcontainer_log_info "BATS installed at $(command -v bats)"
