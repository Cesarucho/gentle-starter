#!/usr/bin/env bash
#
# 40-cli-c4-plantuml.sh — install the C4-PlantUML standard library.
#
# Installs pinned C4 macros under /usr/local/share/c4-plantuml for local
# `!include` directives. PlantUML itself is provided by 40-cli-plantuml.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${C4_PLANTUML_VERSION:=2.13.0}"
: "${C4_PLANTUML_SHA256:=1bf4e0061dafc7dea13923a0c5e0456a3702e99b73ef1c01e0871832e15a4e91}"
: "${C4_PLANTUML_INSTALL_DIR:=/usr/local/share/c4-plantuml}"

VERSION_FILE="${C4_PLANTUML_INSTALL_DIR}/.version"
if [ -f "${VERSION_FILE}" ] && [ "$(cat "${VERSION_FILE}")" = "${C4_PLANTUML_VERSION}" ]; then
	devcontainer_log_info "C4-PlantUML ${C4_PLANTUML_VERSION} already installed at ${C4_PLANTUML_INSTALL_DIR}"
	exit 0
fi

if [ "${C4_PLANTUML_VERSION#v}" != "${C4_PLANTUML_VERSION}" ]; then
	devcontainer_log_error "C4_PLANTUML_VERSION must not include the v prefix: ${C4_PLANTUML_VERSION}"
	exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
ARCHIVE_PATH="${TMP_DIR}/c4-plantuml.tar.gz"
UNPACK_DIR="${TMP_DIR}/unpack"
ARCHIVE_URL="https://codeload.github.com/plantuml-stdlib/C4-PlantUML/tar.gz/refs/tags/v${C4_PLANTUML_VERSION}"

devcontainer_log_info "Downloading C4-PlantUML ${C4_PLANTUML_VERSION}"
devcontainer_fetch "${ARCHIVE_URL}" "${ARCHIVE_PATH}"
devcontainer_verify_sha256 "${ARCHIVE_PATH}" "${C4_PLANTUML_SHA256}"

mkdir -p "${UNPACK_DIR}"
tar -xzf "${ARCHIVE_PATH}" --strip-components=1 -C "${UNPACK_DIR}"
if [ ! -f "${UNPACK_DIR}/C4.puml" ]; then
	devcontainer_log_error "C4-PlantUML archive layout changed: C4.puml missing"
	exit 1
fi

printf '%s\n' "${C4_PLANTUML_VERSION}" >"${UNPACK_DIR}/.version"
devcontainer_run_as_root rm -rf "${C4_PLANTUML_INSTALL_DIR}"
devcontainer_run_as_root mkdir -p "$(dirname "${C4_PLANTUML_INSTALL_DIR}")"
devcontainer_run_as_root mv "${UNPACK_DIR}" "${C4_PLANTUML_INSTALL_DIR}"

if [ ! -f "${C4_PLANTUML_INSTALL_DIR}/C4.puml" ]; then
	devcontainer_log_error "C4-PlantUML install failed: C4.puml missing"
	exit 1
fi

devcontainer_log_info "C4-PlantUML ${C4_PLANTUML_VERSION} installed at ${C4_PLANTUML_INSTALL_DIR}"
