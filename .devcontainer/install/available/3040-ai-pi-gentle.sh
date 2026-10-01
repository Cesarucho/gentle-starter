#!/usr/bin/env bash
#
# 3040-ai-pi-gentle.sh — install the user-scoped Pi packages listed in
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

: "${GENTLE_PI_VERSION:=${LOCK_GENTLE_PI_VERSION:?missing LOCK_GENTLE_PI_VERSION}}"
: "${PI_SUBAGENTS_VERSION:=${LOCK_PI_SUBAGENTS_VERSION:?missing LOCK_PI_SUBAGENTS_VERSION}}"
: "${PI_INTERCOM_VERSION:=${LOCK_PI_INTERCOM_VERSION:?missing LOCK_PI_INTERCOM_VERSION}}"
: "${PI_WEB_ACCESS_VERSION:=${LOCK_PI_WEB_ACCESS_VERSION:?missing LOCK_PI_WEB_ACCESS_VERSION}}"
: "${PI_LENS_VERSION:=${LOCK_PI_LENS_VERSION:?missing LOCK_PI_LENS_VERSION}}"
: "${RPIV_TODO_VERSION:=${LOCK_RPIV_TODO_VERSION:?missing LOCK_RPIV_TODO_VERSION}}"
: "${RPIV_ASK_USER_QUESTION_VERSION:=${LOCK_RPIV_ASK_USER_QUESTION_VERSION:?missing LOCK_RPIV_ASK_USER_QUESTION_VERSION}}"
: "${RPIV_BTW_VERSION:=${LOCK_RPIV_BTW_VERSION:?missing LOCK_RPIV_BTW_VERSION}}"
: "${GENTLE_ENGRAM_VERSION:=${LOCK_GENTLE_ENGRAM_VERSION:?missing LOCK_GENTLE_ENGRAM_VERSION}}"
: "${PI_MCP_ADAPTER_VERSION:=${LOCK_PI_MCP_ADAPTER_VERSION:?missing LOCK_PI_MCP_ADAPTER_VERSION}}"
: "${PI_TERMINAL_THEME_VERSION:=${LOCK_PI_TERMINAL_THEME_VERSION:?missing LOCK_PI_TERMINAL_THEME_VERSION}}"

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

configured_source() {
	local source="$1"
	local name

	name="$(package_name "${source}")"
	pi list | sed -nE "s/^[[:space:]]+(npm:${name//\//\\/}(@[^[:space:]]+)?)$/\\1/p"
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

legacy_powerline_is_configured() {
	local settings_file="${HOME}/.pi/agent/settings.json"

	[ -f "${settings_file}" ] || return 1
	node - "${settings_file}" <<'NODE'
const fs = require("fs");
const settings = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const packages = Array.isArray(settings.packages) ? settings.packages : [];
const configured = packages.some((entry) => {
	const source = typeof entry === "string" ? entry : entry?.source;
	return typeof source === "string" && /^npm:pi-powerline(?:@|$)/.test(source);
});
process.exit(configured ? 0 : 1);
NODE
}

remove_legacy_powerline() {
	if ! legacy_powerline_is_configured; then
		return
	fi

	devcontainer_log_info "Removing incompatible legacy Pi package: npm:pi-powerline"
	pi remove "npm:pi-powerline"
}

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

devcontainer_require_cmd pi "Enable 3030-ai-pi-coding.sh before Pi Gentle." || exit 1

remove_legacy_powerline

for source in "${PACKAGES[@]}"; do
	if is_installed "${source}"; then
		devcontainer_log_info "Pi package already installed: ${source}"
		continue
	fi
	actual_version="$(installed_version "${source}" 2>/dev/null || true)"
	if [ -n "${actual_version}" ]; then
		installed_source="$(configured_source "${source}")"
		: "${installed_source:=npm:$(package_name "${source}")}"
		devcontainer_log_info "Replacing Pi package ${installed_source} ${actual_version} with $(package_version "${source}")"
		pi remove "${installed_source}"
	fi

	devcontainer_log_info "Installing Pi package: ${source}"
	pi install "${source}"
done

devcontainer_log_info "Pi packages remain pinned to the generated policy resolutions"
