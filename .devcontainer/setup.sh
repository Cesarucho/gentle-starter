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
sudo chown -R ${UID}:${UID} "${WORKSPACE_DIR}"
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
}

# Setup git files configurations
sudo chown -R ${UID}:${UID} ${HOME}/.gitconfig-volume

touch ${HOME}/.gitconfig-volume/config
ln -fs ${HOME}/.gitconfig-volume/config ${HOME}/.gitconfig
sudo chown -R ${UID}:${UID} ${HOME}/.gitconfig

touch ${HOME}/.gitconfig-volume/.git-credentials
ln -fs ${HOME}/.gitconfig-volume/.git-credentials ${HOME}/.git-credentials
sudo chown -R ${UID}:${UID} ${HOME}/.git-credentials

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
export PATH="${HOME}/.local/bin:${PATH}"
DEVCONTAINER_PHASE=runtime "${WORKSPACE_DIR}/.devcontainer/scripts/09-install-ai-pi-gentle.sh"
DEVCONTAINER_PHASE=runtime "${WORKSPACE_DIR}/.devcontainer/scripts/10-install-ai-engram.sh"
# Make user-local tools available to the remaining setup commands without
# requiring a new terminal. Future shells pick this up from ~/.bashrc.
# shellcheck disable=SC1091
source "${HOME}/.bashrc"
setup_versioned_pi_config
pi update
