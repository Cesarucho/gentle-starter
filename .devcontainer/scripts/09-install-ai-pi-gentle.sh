#!/usr/bin/env bash
set -euo pipefail

DEVCONTAINER_PHASE="${DEVCONTAINER_PHASE:-runtime}"
PI_AUTO_UPDATE="${PI_AUTO_UPDATE:-0}"

PACKAGES=(
	# "npm:@vigolium/piolium@<version>"
	"npm:pi-powerline@0.7.1"
	"npm:gentle-pi@0.4.5"
	"npm:pi-subagents@0.28.0"
	"npm:pi-intercom@0.6.0"
	"npm:gentle-engram@0.1.7"
	"npm:pi-web-access@0.10.7"
	"npm:pi-lens@3.8.50"
	"npm:pi-mcp-adapter@2.9.0"
	"npm:@juicesharp/rpiv-todo@1.18.2"
	"npm:@juicesharp/rpiv-ask-user-question@1.18.2"
	"npm:@juicesharp/rpiv-btw@1.18.2"
	"npm:pi-terminal-theme@0.2.0"
	"npm:pi-hud@0.8.0"
)

package_key() {
	local source="$1"

	printf '%s' "${source}" | sed -E 's/@[0-9][^@]*$//'
}

package_name() {
	local source="$1"

	package_key "${source}" | sed 's/^npm://'
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

if [ "${DEVCONTAINER_PHASE}" = "build" ]; then
	echo "Skipping user-scoped Pi package install during image build"
	exit 0
fi

if [ "$(id -u)" -eq 0 ]; then
	echo "This script must run as the final non-root user during runtime" >&2
	exit 1
fi

for source in "${PACKAGES[@]}"; do
	if is_installed "${source}"; then
		echo "Pi package already installed: ${source}"
		continue
	fi

	echo "Installing Pi package: ${source}"
	pi install "${source}"
done

case "${PI_AUTO_UPDATE}" in
1 | true | TRUE | yes | YES)
	echo "Updating Pi packages to pick up newer available versions"
	pi update
	;;
*)
	echo "Skipping automatic Pi updates (set PI_AUTO_UPDATE=1 to enable upgrades)"
	;;
esac
