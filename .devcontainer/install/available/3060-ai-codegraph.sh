#!/usr/bin/env bash
# Image-owned CLI; project indexing and MCP activation are explicit user actions.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"
devcontainer_load_tool_versions
: "${CODEGRAPH_VERSION:=${LOCK_CODEGRAPH_VERSION:?missing LOCK_CODEGRAPH_VERSION}}"
[[ "${CODEGRAPH_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
	devcontainer_log_error "CodeGraph requires an exact stable SemVer"
	exit 1
}
if [ "${1:-}" = --print-version-policy ]; then
	printf 'CODEGRAPH_VERSION=%s\n' "${CODEGRAPH_VERSION}"
	exit 0
fi
if devcontainer_is_runtime; then
	devcontainer_log_info "CodeGraph is image-owned; rebuild to install or update it."
	exit 0
fi
[ "$(uname -s)" = Linux ] || {
	devcontainer_log_error "CodeGraph requires Linux"
	exit 1
}
architecture="$(devcontainer_arch)"
[ "${architecture}" != amd64 ] || architecture=x64
devcontainer_require_cmd npm "Enable core Node before CodeGraph."
devcontainer_require_cmd node "Enable core Node before CodeGraph."
: "${CODEGRAPH_INSTALL_ROOT:=/opt/codegraph}"
: "${CODEGRAPH_BIN:=/usr/local/bin/codegraph}"
if [ -d "${CODEGRAPH_BIN}" ]; then
	devcontainer_log_error "CodeGraph launcher destination is a directory: ${CODEGRAPH_BIN}"
	exit 1
fi
destination="${CODEGRAPH_INSTALL_ROOT}/${CODEGRAPH_VERSION}"
stage=""
probe_home="$(mktemp -d)"
cleanup() {
	[ -z "${stage}" ] || devcontainer_run_as_root rm -rf -- "${stage}"
	rm -rf -- "${probe_home}"
}
trap cleanup EXIT

verify_bundle() {
	local root="$1" bundle version relative
	relative="$(node "${SCRIPT_DIR}/../lib/codegraph-bundle.cjs" "${root}" "${CODEGRAPH_VERSION}" "${architecture}")" || return 1
	bundle="${root}/${relative}"
	HOME="${probe_home}" "${bundle}/node" --disable-warning=ExperimentalWarning -e \
		'const {DatabaseSync}=require("node:sqlite"); const db=new DatabaseSync(":memory:"); db.close();' || return 1
	version="$(HOME="${probe_home}" CODEGRAPH_TELEMETRY=0 CODEGRAPH_NO_UPDATE_CHECK=1 CODEGRAPH_NO_DOWNLOAD=1 \
		"${bundle}/bin/codegraph" --version)" || return 1
	[ "${version}" = "${CODEGRAPH_VERSION}" ] || {
		devcontainer_log_error "CodeGraph executable version mismatch: ${version}"
		return 1
	}
}

if ! verify_bundle "${destination}" 2>/dev/null; then
	devcontainer_run_as_root mkdir -p -- "${CODEGRAPH_INSTALL_ROOT}"
	stage="$(devcontainer_run_as_root mktemp -d "${CODEGRAPH_INSTALL_ROOT}/.stage.XXXXXX")"
	devcontainer_run_as_root chmod 0755 "${stage}"
	devcontainer_run_as_root npm install --global --prefix "${stage}" --include=optional --ignore-scripts \
		"@colbymchenry/codegraph@${CODEGRAPH_VERSION}"
	verify_bundle "${stage}"
	# Do not destroy a damaged or unexpected installation; require explicit recovery.
	if [ -e "${destination}" ] || [ -L "${destination}" ]; then
		devcontainer_log_error "Invalid existing ${destination}; remove that image-owned version and rebuild."
		exit 1
	fi
	devcontainer_run_as_root mv -- "${stage}" "${destination}"
	stage=""
fi
bundle_relative="$(node "${SCRIPT_DIR}/../lib/codegraph-bundle.cjs" "${destination}" "${CODEGRAPH_VERSION}" "${architecture}")"
devcontainer_run_as_root ln -sfn -- "${bundle_relative}" "${destination}/bundle"
devcontainer_run_as_root install -m 0755 "${SCRIPT_DIR}/../lib/codegraph-launcher.sh" "${destination}/codegraph"
devcontainer_run_as_root ln -sfn -- "${destination}/codegraph" "${CODEGRAPH_BIN}"
devcontainer_log_info "CodeGraph ${CODEGRAPH_VERSION} installed; run codegraph init manually in a project."
