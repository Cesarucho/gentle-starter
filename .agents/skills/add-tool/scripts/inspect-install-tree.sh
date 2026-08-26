#!/usr/bin/env bash
# Read-only discovery for repositories with a catalog-driven devcontainer tool lifecycle.
set -euo pipefail

start="${1:-${PWD}}"
if root="$(git -C "${start}" rev-parse --show-toplevel 2>/dev/null)"; then :; else root="$(cd "${start}" && pwd)"; fi
install="${root}/.devcontainer/install"

section() { printf '\n== %s ==\n' "$1"; }
show_path() { if [ -e "$1" ]; then printf 'present  %s\n' "${1#"${root}"/}"; else printf 'missing  %s\n' "${1#"${root}"/}"; fi; }

printf 'Repository: %s\n' "${root}"
section "Extension surfaces"
for path in \
	"${install}/available" "${install}/02-enabled" "${install}/lib/common.sh" \
	"${install}/templates/install-script.sh" "${root}/.devcontainer/tool-versions.conf" \
	"${root}/.devcontainer/setup.sh" "${root}/.devcontainer/setup-volumes.sh" \
	"${root}/.devcontainer/docker-compose.yml"; do show_path "${path}"; done

section "Available installers"
if [ -d "${install}/available" ]; then find "${install}/available" -maxdepth 1 -type f -name '*.sh' -printf '%f\n' | sort; else printf '(none discovered)\n'; fi

section "Enabled execution order"
if [ -d "${install}/02-enabled" ]; then
	find "${install}/02-enabled" -maxdepth 1 -type l -print | sort | while IFS= read -r link; do
		printf '%s -> %s%s\n' "$(basename "${link}")" "$(readlink "${link}")" "$([ -e "${link}" ] || printf ' [BROKEN]')"
	done
else printf '(none discovered)\n'; fi

section "Preferred enabled-name policy"
helper="${root}/.taskfiles/scripts/install.sh"
if [ -f "${helper}" ]; then
	awk '/^preferred_enabled_name\(\)/,/^}/' "${helper}"
else printf '(helper not discovered; inspect task definitions)\n'; fi

section "Version policy keys"
policy="${root}/.devcontainer/tool-versions.conf"
if [ -f "${policy}" ]; then sed -nE 's/^(TOOL_[A-Z0-9_]+)=.*/\1/p' "${policy}" | sort; else printf '(policy not discovered)\n'; fi

section "Volume repair mappings"
volumes="${root}/.devcontainer/setup-volumes.sh"
if [ -f "${volumes}" ]; then
	awk '/^compose_target_to_install_scripts\(\)/,/^}/' "${volumes}"
else printf '(volume helper not discovered)\n'; fi

section "Relevant task names"
if command -v task >/dev/null 2>&1 && [ -f "${root}/Taskfile.yml" ]; then
	(
		cd "${root}"
		task --list-all 2>/dev/null | grep -E 'install:|deps:update|validate|quality|test|doctor|skill' || true
	)
else
	find "${root}" -maxdepth 3 \( -name 'Taskfile.yml' -o -name '*.yml' \) -path '*/.taskfiles/*' -print 2>/dev/null | sort
fi

section "Next inspection"
printf '%s\n' \
	'Read the Dockerfile build loop and postCreate command.' \
	'Read the closest installer and its focused tests.' \
	'Confirm supported architectures and upstream trust material.' \
	'Derive the next enabled slot from dependency order, not merely the first numeric gap.'
