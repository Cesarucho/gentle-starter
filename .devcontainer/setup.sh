#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Volume-aware install repair lives in its own file. Sourced (not
# executed) so the three functions below are in scope and can call
# each other. The file's header documents the three-piece contract
# (docker-compose.yml volume + lifecycle/setup-volumes.sh mapping + install/
# script) that a contributor must keep in sync when adding a new
# stateful volume.
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lifecycle/setup-volumes.sh"

# Validate desired inputs AND the creation-time identity before any runtime mutation.
python3 "${WORKSPACE_DIR}/.taskfiles/scripts/compose-manifest.py" runtime "${WORKSPACE_DIR}" >/dev/null
if install_script_is_enabled "${SCRIPT_DIR}/install/available/4010-tool-ssh-server.sh"; then
	python3 "${WORKSPACE_DIR}/.taskfiles/scripts/compose-manifest.py" ssh-server "${WORKSPACE_DIR}" >/dev/null
fi

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
build_gitignore_prune_args gitignore_prune_args
sudo find -P "${WORKSPACE_DIR}" "${gitignore_prune_args[@]}" -exec chown --no-dereference "${UID}:${UID}" -- {} +
sudo find "${WORKSPACE_DIR}" "${gitignore_prune_args[@]}" -type d -exec chmod 755 {} +
sudo find "${WORKSPACE_DIR}" "${gitignore_prune_args[@]}" -type f ! -name "*.sh" -exec chmod 644 {} +
sudo find "${WORKSPACE_DIR}" "${gitignore_prune_args[@]}" -type f -name "*.sh" -exec chmod 755 {} +
bash "${SCRIPT_DIR}/lifecycle/restore-tracked-modes.sh" "${WORKSPACE_DIR}"

# Copy the file tree under source_root into target_root, but only
# for files that do NOT already exist at the target (so the user's
# customisations are preserved across rebuilds). The relative path
# under source_root is preserved under target_root: a file at
# source_root/foo/bar.json lands at target_root/foo/bar.json.
#
# If target_root is outside ${HOME} (e.g. /etc/postgresql/16/main,
# /etc/redis), the helper escalates to sudo because the running
# postCreate user (ubuntu) cannot write there. Inside ${HOME}
# (e.g. ~/.pi, ~/.config/Code) the helper runs as ubuntu and the
# files are owned by ubuntu.
#
# This is the building block for the versioned config contract:
#   .devcontainer/<name>-config/<ruta>/archivo  ->  <target>/<ruta>/archivo
# See .devcontainer/README.md for the convention.
seed_config_tree() {
	local source_root="$1"
	local target_root="$2"

	if [ ! -d "${source_root}" ]; then
		return 0
	fi

	local needs_sudo=false
	if [ "${target_root:0:1}" = "/" ] &&
		[ "${target_root}" != "${HOME}" ] &&
		[ "${target_root#"$HOME"/}" = "${target_root}" ]; then
		needs_sudo=true
	fi

	local mkdir_cmd="mkdir -p"
	local cp_cmd="cp"
	if [ "${needs_sudo}" = true ]; then
		mkdir_cmd="sudo mkdir -p"
		cp_cmd="sudo cp"
	fi

	local source
	local relative
	local target
	while IFS= read -r source; do
		relative="${source#"${source_root}/"}"
		target="${target_root}/${relative}"

		if [ -e "${target}" ]; then
			continue
		fi

		# shellcheck disable=SC2086
		${mkdir_cmd} "$(dirname "${target}")"
		# shellcheck disable=SC2086
		${cp_cmd} "${source}" "${target}"
	done < <(find "${source_root}" -type f)
}

repair_user_local_parents() {
	local runtime_uid runtime_gid path path_ownership path_uid
	local -a repairable_parents=(
		"${HOME}/.local"
		"${HOME}/.local/share"
	)
	runtime_uid="$(id -u)"
	runtime_gid="$(id -g)"

	for path in "${repairable_parents[@]}"; do
		if [ -L "${path}" ] || { [ -e "${path}" ] && [ ! -d "${path}" ]; }; then
			echo "[setup:error] Refusing unsafe user-local parent: ${path}" >&2
			return 1
		fi
		if [ ! -e "${path}" ]; then
			continue
		fi

		path_ownership="$(stat -c '%u:%g' -- "${path}")"
		path_uid="${path_ownership%%:*}"
		if [ "${path_uid}" != "${runtime_uid}" ] && [ "${path_uid}" != 0 ]; then
			echo "[setup:error] Refusing user-local parent with unexpected ownership: ${path} (owner ${path_ownership}, expected UID ${runtime_uid} or root)" >&2
			return 1
		fi
	done

	for path in "${repairable_parents[@]}"; do
		sudo install -d -m 0755 -o "${runtime_uid}" -g "${runtime_gid}" -- "${path}"
	done
}

# Seed base config only for the tools that own each runtime subtree.
# Each line is a (source_root, target_root) pair that gets handed to
# seed_config_tree. To add a new tool's baseline config:
#   1. Create .devcontainer/<name>-config/ with the file tree that
#      mirrors the tool's runtime config location.
#   2. Add a seed_config_tree call below with the absolute target.
# See .devcontainer/README.md for the full convention.
setup_versioned_configs() {
	if install_script_is_enabled "${SCRIPT_DIR}/install/available/3030-ai-pi-coding.sh"; then
		seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config/agent" "${HOME}/.pi/agent"
	fi
	if install_script_is_enabled "${SCRIPT_DIR}/install/available/3030-ai-pi-coding.sh" &&
		install_script_is_enabled "${SCRIPT_DIR}/install/available/3020-ai-gentle-ai.sh"; then
		seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config/gentle-ai" "${HOME}/.pi/gentle-ai"
	fi
	if install_script_is_enabled "${SCRIPT_DIR}/install/available/3000-ai-opencode.sh"; then
		seed_config_tree "${WORKSPACE_DIR}/.devcontainer/opencode-config" "${HOME}/.config/opencode"
	fi

	# Add additional tool configs here, one line per source root:
	#   seed_config_tree "${WORKSPACE_DIR}/.devcontainer/postgres-config" "/etc/postgresql/16/main"
	#   seed_config_tree "${WORKSPACE_DIR}/.devcontainer/redis-config" "/etc/redis"
	#   seed_config_tree "${WORKSPACE_DIR}/.devcontainer/vscode-config" "${HOME}/.config/Code"
	#   seed_config_tree "${WORKSPACE_DIR}/.devcontainer/<name>-config.local" "${HOME}/.<name>" || true
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
	local fixed_dir="/home/ubuntu/code"
	if [ -f "${trust_file}" ]; then
		jq --arg workspace "${WORKSPACE_DIR}" --arg fixed "${fixed_dir}" '. + {($workspace): true, ($fixed): true}' "${trust_file}" >"${tmp_file}"
	else
		jq -n --arg workspace "${WORKSPACE_DIR}" --arg fixed "${fixed_dir}" '{($workspace): true, ($fixed): true}' >"${tmp_file}"
	fi

	mv "${tmp_file}" "${trust_file}"
	chmod 0644 "${trust_file}"
}

# Setup git files configurations
touch "${HOME}/.gitconfig-volume/config"
ln -fs "${HOME}/.gitconfig-volume/config" "${HOME}/.gitconfig"
sudo chown -R "${UID}:${UID}" "${HOME}/.gitconfig"

touch "${HOME}/.gitconfig-volume/.git-credentials"
ln -fs "${HOME}/.gitconfig-volume/.git-credentials" "${HOME}/.git-credentials"
sudo chown -R "${UID}:${UID}" "${HOME}/.git-credentials"

if ! git config --global --get-all safe.directory | grep -Fxq "${WORKSPACE_DIR}"; then
	git config --global --add safe.directory "${WORKSPACE_DIR}"
fi

# Create /home/ubuntu/${APP_NAME} -> /home/ubuntu/code alias (symlink).
# APP_NAME comes from the .env generated by ensure-identity-env.
# The symlink is idempotent: re-creating it on every run is a no-op
# when it already points to the right target.
if [ -n "${APP_NAME:-}" ] && [ "${APP_NAME}" != "code" ]; then
	if [ -L "${HOME}/${APP_NAME}" ]; then
		if [ "$(readlink "${HOME}/${APP_NAME}")" != "code" ]; then
			ln -sfn code "${HOME}/${APP_NAME}"
		fi
	elif [ -d "${HOME}/${APP_NAME}" ] || [ -f "${HOME}/${APP_NAME}" ]; then
		# Path exists but is not the right symlink; skip to avoid clobbering.
		:
	else
		ln -s code "${HOME}/${APP_NAME}"
	fi
fi

git config --global alias.logline \
	"log --graph --decorate --abbrev-commit --date=short --pretty=format:'%C(yellow)%h%Creset %C(cyan)%ad%Creset %Cgreen%s%Creset %Cblue(%an)%Creset %C(red)%d%Creset'"

git config --global alias.config-list "config --list --show-origin --show-scope"

# ---------------------------------------------------------------------------
# Volume-aware install repair is sourced above from lifecycle/setup-volumes.sh.
# The functions (resolve_compose_volume_targets,
# compose_target_to_install_scripts, repair_installed_volumes) are
# in scope by the time the pipeline below runs.
# ---------------------------------------------------------------------------

# Install/update user-scoped AI tooling after volumes are mounted for ubuntu.
# setup_versioned_configs copies base configs (see above); it is
# idempotent and safe to call once. The legacy implementation used
# symlinks and had to be called twice (link, then re-link in case
# any tool broke the symlinks via atomic replace); with copy, there
# is nothing to re-link, so one call is enough.
repair_user_local_parents
setup_versioned_configs
if install_script_is_enabled "${SCRIPT_DIR}/install/available/3030-ai-pi-coding.sh"; then
	setup_pi_workspace_trust
fi
# export PATH="${HOME}/.local/bin:${PATH}"
repair_installed_volumes

# ---------------------------------------------------------------------------
# SSH server: start if the install script is enabled.
# Detection: check for the symlink in 03-enabled/ (created by
# task install:enable -- 4010-tool-ssh-server, or manually). The persisted-key
# Compose override is also required. Disabling that canonical installer
# prevents both runtime preparation and service startup.
# ---------------------------------------------------------------------------
_ssh_installer="${SCRIPT_DIR}/install/available/4010-tool-ssh-server.sh"
if install_script_is_enabled "${_ssh_installer}"; then
	export -f seed_config_tree
	WORKSPACE_DIR="${WORKSPACE_DIR}" DEVCONTAINER_PHASE=runtime bash "${_ssh_installer}"
	if command -v start-sshd >/dev/null 2>&1; then
		start-sshd
	else
		echo "[setup:warn] start-sshd not on PATH; rebuild the container to complete SSH install" >&2
	fi
fi
