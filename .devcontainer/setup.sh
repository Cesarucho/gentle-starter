#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# sudo chown -R ${UID}:${UID} ${HOME}/.codex

build_gitignore_prune_args() {
	local -n prune_args_ref="$1"
	local ignored_path

	prune_args_ref=()

	while IFS= read -r -d '' ignored_path; do
		ignored_path="${ignored_path%/}"
		[ -n "${ignored_path}" ] || continue
		[ -d "${WORKSPACE_DIR}/${ignored_path}" ] || continue

		prune_args_ref+=(-path "${WORKSPACE_DIR}/${ignored_path}" -prune -o)
	done < <(git -C "${WORKSPACE_DIR}" ls-files --others --ignored --exclude-standard --directory -z)
}

# Fix project file permissions to standard privileges, excluding ignored directories.
gitignore_prune_args=()
sudo chown -R "${UID}:${UID}" "${WORKSPACE_DIR}"
build_gitignore_prune_args gitignore_prune_args
sudo find "${WORKSPACE_DIR}" "${gitignore_prune_args[@]}" -type d -exec chmod 755 {} +
sudo find "${WORKSPACE_DIR}" "${gitignore_prune_args[@]}" -type f ! -name "*.sh" -exec chmod 644 {} +
sudo find "${WORKSPACE_DIR}" "${gitignore_prune_args[@]}" -type f -name "*.sh" -exec chmod 755 {} +

link_versioned_pi_config() {
	local source_path="$1"
	local target_path="$2"
	local backup_path

	mkdir -p "$(dirname "${target_path}")"

	if [ -e "${target_path}" ] && [ ! -L "${target_path}" ]; then
		backup_path="${target_path}.devcontainer-backup.$(date +%Y%m%d%H%M%S)"
		echo "Backing up existing Pi config: ${target_path} -> ${backup_path}"
		mv "${target_path}" "${backup_path}"
	fi

	ln -sfn "${source_path}" "${target_path}"
}

setup_versioned_pi_config() {
	# Keep runtime state in ~/.pi, but source selected stable config files from Git.
	link_versioned_pi_config \
		"${WORKSPACE_DIR}/.devcontainer/pi-config/agent/settings.json" \
		"${HOME}/.pi/agent/settings.json"

	link_versioned_pi_config \
		"${WORKSPACE_DIR}/.devcontainer/pi-config/gentle-ai/banner.json" \
		"${HOME}/.pi/gentle-ai/banner.json"

	link_versioned_pi_config \
		"${WORKSPACE_DIR}/.devcontainer/pi-config/gentle-ai/models.json" \
		"${HOME}/.pi/gentle-ai/models.json"

	link_versioned_pi_config \
		"${WORKSPACE_DIR}/.devcontainer/pi-config/gentle-ai/persona.json" \
		"${HOME}/.pi/gentle-ai/persona.json"
}

setup_pi_workspace_trust() {
	local trust_file="${HOME}/.pi/agent/trust.json"
	local backup_path
	local tmp_file

	mkdir -p "$(dirname "${trust_file}")"

	if [ -f "${trust_file}" ] && ! jq -e 'type == "object"' "${trust_file}" >/dev/null; then
		backup_path="${trust_file}.devcontainer-backup.$(date +%Y%m%d%H%M%S)"
		echo "Backing up invalid Pi trust config: ${trust_file} -> ${backup_path}"
		mv "${trust_file}" "${backup_path}"
	fi

	tmp_file="$(mktemp)"
	if [ -f "${trust_file}" ]; then
		jq --arg workspace "${WORKSPACE_DIR}" '. + {($workspace): true}' "${trust_file}" >"${tmp_file}"
	else
		jq -n --arg workspace "${WORKSPACE_DIR}" '{($workspace): true}' >"${tmp_file}"
	fi

	mv "${tmp_file}" "${trust_file}"
	chmod 0644 "${trust_file}"
}

# Setup git files configurations
sudo chown -R "${UID}:${UID}" "${HOME}/.gitconfig-volume"

touch "${HOME}/.gitconfig-volume/config"
ln -fs "${HOME}/.gitconfig-volume/config" "${HOME}/.gitconfig"
sudo chown -R "${UID}:${UID}" "${HOME}/.gitconfig"

touch "${HOME}/.gitconfig-volume/.git-credentials"
ln -fs "${HOME}/.gitconfig-volume/.git-credentials" "${HOME}/.git-credentials"
sudo chown -R "${UID}:${UID}" "${HOME}/.git-credentials"

if ! git config --global --get-all safe.directory | grep -Fxq "${WORKSPACE_DIR}"; then
	git config --global --add safe.directory "${WORKSPACE_DIR}"
fi

git config --global alias.logline \
	"log --graph --decorate --abbrev-commit --date=short --pretty=format:'%C(yellow)%h%Creset %C(cyan)%ad%Creset %Cgreen%s%Creset %Cblue(%an)%Creset %C(red)%d%Creset'"

git config --global alias.config-list "config --list --show-origin --show-scope"

# Install/update user-scoped AI tooling after volumes are mounted for ubuntu.
# Link before install so Pi reads the versioned settings, then link again in case
# any tool rewrites config files via atomic replace and breaks the symlink.
setup_versioned_pi_config
setup_pi_workspace_trust
# export PATH="${HOME}/.local/bin:${PATH}"
# DEVCONTAINER_PHASE=runtime "${WORKSPACE_DIR}/.devcontainer/scripts/08-install-ai-opencode.sh"
DEVCONTAINER_PHASE=runtime "${WORKSPACE_DIR}/.devcontainer/scripts/09-install-ai-pi-gentle.sh"
DEVCONTAINER_PHASE=runtime "${WORKSPACE_DIR}/.devcontainer/scripts/10-install-ai-engram.sh"
setup_versioned_pi_config
