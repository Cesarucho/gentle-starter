#!/usr/bin/env bash
#
# install-script.sh — template for .devcontainer/install/available/*.sh
#
# Lifecycle:
#   * DEVCONTAINER_PHASE=build   during image build (Dockerfile RUN loop)
#   * DEVCONTAINER_PHASE=runtime during container start (setup.sh)
#
# How to use this template:
#   1. Copy it to .devcontainer/install/available/NN-categoria-tool.sh,
#      where NN is the global phase prefix (00-99) and the file name
#      describes what gets installed.
#   2. Fill the variables, idempotency check, install, and verify blocks
#      with the real steps.
#   3. If the script should run by default, create a symlink in
#      .devcontainer/install/enabled/ pointing to it. Otherwise leave
#      it in available/ and opt in with `task install:enable -- NAME`.
#
# Strict mode:
#   The default is `set -euo pipefail`. Drop `-u` only inside subshells
#   that source SDKMAN (see Fase 7 notes for the Java script).
#
# shellcheck shell=bash

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve script directory and source shared helpers.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Variables: override via environment (Compose, Dockerfile ARG, or setup.sh).
# Use the `: "${VAR:=default}"` pattern so an unset var triggers the default
# even under `set -u`.
# ---------------------------------------------------------------------------
: "${TOOL_NAME:=example}"
: "${TOOL_VERSION:=1.0.0}"
: "${TOOL_INSTALL_DIR:=/usr/local/bin}"

# ---------------------------------------------------------------------------
# Idempotency: skip the rest of the script if the tool is already installed.
# Replace this with a version-aware check when the tool exposes one
# (e.g. `${TOOL_NAME} --version`).
# ---------------------------------------------------------------------------
if devcontainer_has_cmd "${TOOL_NAME}"; then
	devcontainer_log_info "${TOOL_NAME} already installed: $(command -v "${TOOL_NAME}")"
	exit 0
fi

# ---------------------------------------------------------------------------
# Install: implement the actual install steps here.
# Keep them idempotent: re-running this script on an existing install
# should be a no-op, not a destructive overwrite.
# ---------------------------------------------------------------------------
devcontainer_log_info "Installing ${TOOL_NAME} ${TOOL_VERSION} into ${TOOL_INSTALL_DIR}"
# TODO: download, extract, and place the tool into ${TOOL_INSTALL_DIR}.

# ---------------------------------------------------------------------------
# Verify: confirm the install landed. Fail loud when it didn't.
# ---------------------------------------------------------------------------
if ! devcontainer_has_cmd "${TOOL_NAME}"; then
	devcontainer_log_error "${TOOL_NAME} install failed: binary not on PATH"
	exit 1
fi

devcontainer_log_info "${TOOL_NAME} ${TOOL_VERSION} installed at $(command -v "${TOOL_NAME}")"
