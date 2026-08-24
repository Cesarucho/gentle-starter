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

: "${PI_AUTO_UPDATE:=0}"

PACKAGES=(
	"npm:gentle-pi@2.2.0"                           # gentle-core
	"npm:pi-subagents@0.54.0"                       # gentle-recommendation
	"npm:pi-intercom@0.11.0"                        # gentle-recommendation
	"npm:pi-web-access@0.24.1"                      # gentle-recommendation
	"npm:pi-lens@4.1.1"                             # gentle-recommendation
	"npm:@juicesharp/rpiv-todo@1.20.0"              # gentle-recommendation
	"npm:@juicesharp/rpiv-ask-user-question@1.20.0" # gentle-recommendation
	"npm:@juicesharp/rpiv-btw@1.20.0"               # extra
	"npm:gentle-engram@0.1.10"                      # engram-dependency
	"npm:pi-mcp-adapter@2.27.0"                     # engram-dependency
	"npm:pi-powerline@0.9.1"                        # extra
	"npm:pi-terminal-theme@0.2.0"                   # extra
)

package_name() {
	local source="$1"
	printf '%s' "${source}" | sed -E 's/^npm:([^@]+)@.*$/\1/'
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
