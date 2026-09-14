#!/usr/bin/env bash
#
# install-script.sh — template for .devcontainer/install/available/*.sh
#
# Lifecycle:
#   * DEVCONTAINER_PHASE=build   during image build (Dockerfile RUN loop)
#   * DEVCONTAINER_PHASE=runtime during container start (setup.sh)
#
# How to use this template:
#   1. Copy it to .devcontainer/install/available/BBPP-category-tool.sh,
#      where NN is the global phase prefix (00-99) and the file name
#      describes what gets installed.
#   2. Fill the variables, idempotency check, install, and verify blocks
#      with the real steps.
#   3. If the script should run by default, create a symlink in
#      .devcontainer/install/03-enabled/ pointing to it. Otherwise leave
#      it in available/ and opt in with `task install:enable -- NAME`.
#   4. Ensure the file ends with a single newline character. shfmt expects
#      POSIX text files, so a missing trailing newline causes quality:format
#      to fail. Verify with
#      `tail -c 1 FILE` (empty output = OK) or fix with `echo >> FILE`.
#   5. Register one editable TOOL_*_VERSION intent, an explicit provider
#      strategy, and generated LOCK_* outputs in deps-update.sh.
#      Installers and builds MUST NOT resolve latest or rewrite policy.
#
# State and volumes:
#   If your script OWNS a bind-mounted volume (e.g. a database, a
#   local service data dir, an index/cache), it has to participate
#   in the postCreate volume contract. Three pieces must agree:
#     a. Add the bind mount in .devcontainer/docker-compose.yml.
#     b. Add a case for the new target path in
#        compose_target_to_install_scripts in
#        .devcontainer/lifecycle/setup-volumes.sh, listing this script's
#        base name (without the .sh extension).
#     c. Keep this script idempotent (use devcontainer_has_cmd at
#        the top, return 0 if already present) so the repair
#        re-run on a populated volume is a no-op.
#   Run `task install:volumes` to see the live contract.
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
# Variables: environment overrides may replace generated policy resolutions.
# Never add installer-local version or checksum defaults.
# ---------------------------------------------------------------------------
: "${TOOL_NAME:=example}"
: "${TOOL_VERSION:=${LOCK_EXAMPLE_VERSION:?missing LOCK_EXAMPLE_VERSION}}"
: "${TOOL_INSTALL_DIR:=/usr/local/bin}"

# ---------------------------------------------------------------------------
# Idempotency: skip the rest of the script if the tool is already installed.
# Replace this with a version-aware check when the tool exposes one
# (e.g. `${TOOL_NAME} --version`).
# ---------------------------------------------------------------------------
if devcontainer_check_tool "${TOOL_NAME}" "${TOOL_VERSION}"; then
	devcontainer_log_info "${TOOL_NAME} ${TOOL_VERSION} already installed"
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
