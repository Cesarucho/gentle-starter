#!/usr/bin/env bash
#
# 30-ai-pi-gentle.sh — install the user-scoped Pi packages listed in
# PACKAGES. Each entry is "npm:<name>@<version>". Already-installed
# packages (matching version) are skipped.
#
# Mirrors .devcontainer/scripts/09-install-ai-pi-gentle.sh with the
# common.sh helpers. Skips during image build; intended to run during
# container start (called from setup.sh or hooks/) as the final
# non-root user.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${GENTLE_PI_VERSION:=${TOOL_GENTLE_PI_VERSION:-2.2.0}}"
: "${PI_SUBAGENTS_VERSION:=${TOOL_PI_SUBAGENTS_VERSION:-0.54.0}}"
: "${PI_INTERCOM_VERSION:=${TOOL_PI_INTERCOM_VERSION:-0.11.0}}"
: "${PI_WEB_ACCESS_VERSION:=${TOOL_PI_WEB_ACCESS_VERSION:-0.24.1}}"
: "${PI_LENS_VERSION:=${TOOL_PI_LENS_VERSION:-4.1.1}}"
: "${RPIV_TODO_VERSION:=${TOOL_RPIV_TODO_VERSION:-1.20.0}}"
: "${RPIV_ASK_USER_QUESTION_VERSION:=${TOOL_RPIV_ASK_USER_QUESTION_VERSION:-1.20.0}}"
: "${RPIV_BTW_VERSION:=${TOOL_RPIV_BTW_VERSION:-1.20.0}}"
: "${GENTLE_ENGRAM_VERSION:=${TOOL_GENTLE_ENGRAM_VERSION:-0.1.10}}"
: "${PI_MCP_ADAPTER_VERSION:=${TOOL_PI_MCP_ADAPTER_VERSION:-2.27.0}}"
: "${PI_POWERLINE_VERSION:=${TOOL_PI_POWERLINE_VERSION:-0.9.1}}"
: "${PI_TERMINAL_THEME_VERSION:=${TOOL_PI_TERMINAL_THEME_VERSION:-0.2.0}}"

: "${PI_AUTO_UPDATE:=0}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf '%s\n' \
		"GENTLE_PI_VERSION=${GENTLE_PI_VERSION}" \
		"PI_SUBAGENTS_VERSION=${PI_SUBAGENTS_VERSION}" \
		"PI_INTERCOM_VERSION=${PI_INTERCOM_VERSION}" \
		"PI_WEB_ACCESS_VERSION=${PI_WEB_ACCESS_VERSION}" \
		"PI_LENS_VERSION=${PI_LENS_VERSION}" \
		"RPIV_TODO_VERSION=${RPIV_TODO_VERSION}" \
		"RPIV_ASK_USER_QUESTION_VERSION=${RPIV_ASK_USER_QUESTION_VERSION}" \
		"RPIV_BTW_VERSION=${RPIV_BTW_VERSION}" \
		"GENTLE_ENGRAM_VERSION=${GENTLE_ENGRAM_VERSION}" \
		"PI_MCP_ADAPTER_VERSION=${PI_MCP_ADAPTER_VERSION}" \
		"PI_POWERLINE_VERSION=${PI_POWERLINE_VERSION}" \
		"PI_TERMINAL_THEME_VERSION=${PI_TERMINAL_THEME_VERSION}"
	exit 0
fi

PACKAGES=(
	"npm:gentle-pi@${GENTLE_PI_VERSION}"                                       # gentle-core
	"npm:pi-subagents@${PI_SUBAGENTS_VERSION}"                                 # gentle-recommendation
	"npm:pi-intercom@${PI_INTERCOM_VERSION}"                                   # gentle-recommendation
	"npm:pi-web-access@${PI_WEB_ACCESS_VERSION}"                               # gentle-recommendation
	"npm:pi-lens@${PI_LENS_VERSION}"                                           # gentle-recommendation
	"npm:@juicesharp/rpiv-todo@${RPIV_TODO_VERSION}"                           # gentle-recommendation
	"npm:@juicesharp/rpiv-ask-user-question@${RPIV_ASK_USER_QUESTION_VERSION}" # gentle-recommendation
	"npm:@juicesharp/rpiv-btw@${RPIV_BTW_VERSION}"                             # extra
	"npm:gentle-engram@${GENTLE_ENGRAM_VERSION}"                               # engram-dependency
	"npm:pi-mcp-adapter@${PI_MCP_ADAPTER_VERSION}"                             # engram-dependency
	"npm:pi-powerline@${PI_POWERLINE_VERSION}"                                 # extra
	"npm:pi-terminal-theme@${PI_TERMINAL_THEME_VERSION}"                       # extra
)

package_name() {
	local source="$1"
	local name_with_version

	name_with_version="${source#npm:}"
	printf '%s' "${name_with_version%@*}"
}

package_version() {
	local source="$1"
	printf '%s' "${source}" | sed -nE 's/^.*@([0-9][^@]*)$/\1/p'
}

installed_version() {
	local source="$1"
	local name
	local package_json

	name="$(package_name "${source}")"

	for package_json in \
		"${PWD}/.pi/npm/node_modules/${name}/package.json" \
		"${HOME}/.pi/agent/npm/node_modules/${name}/package.json"; do
		if [ -f "${package_json}" ]; then
			node -e "console.log(require(process.argv[1]).version)" "${package_json}"
			return 0
		fi
	done

	return 1
}

is_installed() {
	local source="$1"
	local expected_version
	local actual_version

	expected_version="$(package_version "${source}")"
	actual_version="$(installed_version "${source}" 2>/dev/null || true)"

	[ -n "${actual_version}" ] && [ "${actual_version}" = "${expected_version}" ]
}

print_package_metadata() {
	local source="$1"
	local actual_version

	actual_version="$(installed_version "${source}" 2>/dev/null || true)"
	printf '%s\n' \
		"PACKAGE_NAME=$(package_name "${source}")" \
		"PACKAGE_VERSION=$(package_version "${source}")" \
		"INSTALLED_VERSION=${actual_version}"
}

if [ "${1:-}" = "--print-package-metadata" ]; then
	print_package_metadata "${2:?package source is required}"
	exit 0
fi

# Build phase: skip. The Pi packages are user-scoped and are best
# installed at runtime when the user's home directory is in scope.
if devcontainer_is_build; then
	devcontainer_log_info "Skipping user-scoped Pi package install during image build"
	exit 0
fi

# Runtime phase: must run as the final non-root user.
if [ "$(id -u)" -eq 0 ]; then
	devcontainer_log_error "This script must run as the final non-root user during runtime"
	exit 1
fi

for source in "${PACKAGES[@]}"; do
	if is_installed "${source}"; then
		devcontainer_log_info "Pi package already installed: ${source}"
		continue
	fi

	devcontainer_log_info "Installing Pi package: ${source}"
	pi install "${source}"
done

case "${PI_AUTO_UPDATE}" in
1 | true | TRUE | yes | YES)
	devcontainer_log_info "Updating Pi packages to pick up newer available versions"
	pi update
	;;
*)
	devcontainer_log_info "Skipping automatic Pi updates (set PI_AUTO_UPDATE=1 to enable upgrades)"
	;;
esac
