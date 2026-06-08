#!/usr/bin/env bash
set -euo pipefail

DEVCONTAINER_PHASE="${DEVCONTAINER_PHASE:-runtime}"
PI_AUTO_UPDATE="${PI_AUTO_UPDATE:-0}"

PACKAGES=(
	# "npm:@vigolium/piolium"
	"npm:pi-powerline"
	"npm:gentle-pi"
	"npm:pi-subagents"
	"npm:pi-intercom"
	"npm:gentle-engram"
	"npm:pi-web-access"
	"npm:pi-lens"
	"npm:@juicesharp/rpiv-todo"
	"npm:@juicesharp/rpiv-ask-user-question"
	"npm:@juicesharp/rpiv-btw"
	"npm:pi-terminal-theme"
	"npm:pi-hud"
)

is_installed() {
	local source="$1"
	pi list 2>/dev/null | awk -v source="${source}" '
        $1 == source { found = 1 }
        index($1, source "@") == 1 { found = 1 }
        END { exit found ? 0 : 1 }
    '
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
