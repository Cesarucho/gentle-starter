#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Volume-aware install repair lives in its own file. Sourced (not
# executed) so the three functions below are in scope and can call
# each other. The file's header documents the three-piece contract
# (docker-compose.yml volume + setup-volumes.sh mapping + install/
# script) that a contributor must keep in sync when adding a new
# stateful volume.
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/setup-volumes.sh"

repair_exact_directory() {
	local path="$1"
	local owner_uid="$2"
	local owner_gid="$3"
	local mode="$4"

	if [ -L "${path}" ]; then
		printf '[setup:error] Refusing to repair symlink: %s\n' "${path}" >&2
		return 1
	fi

	if [ -e "${path}" ]; then
		if [ ! -d "${path}" ]; then
			printf '[setup:error] Refusing to repair non-directory: %s\n' "${path}" >&2
			return 1
		fi
	elif ! mkdir -- "${path}"; then
		printf '[setup:error] Could not create directory without privileges: %s\n' "${path}" >&2
		return 1
	fi

	if [ -L "${path}" ] || [ ! -d "${path}" ]; then
		printf '[setup:error] Directory changed type before repair: %s\n' "${path}" >&2
		return 1
	fi

	if ! sudo python3 - "${path}" "${owner_uid}" "${owner_gid}" "${mode}" <<'PY'; then
import os
import stat
import sys

path = sys.argv[1]
owner_uid = int(sys.argv[2])
owner_gid = int(sys.argv[3])
mode = int(sys.argv[4], 8)
fd = None

try:
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    before = os.fstat(fd)
    if not stat.S_ISDIR(before.st_mode):
        raise RuntimeError("opened object is not a directory")

    os.fchown(fd, owner_uid, owner_gid)
    os.fchmod(fd, mode)

    after = os.fstat(fd)
    if (before.st_dev, before.st_ino) != (after.st_dev, after.st_ino):
        raise RuntimeError("opened directory identity changed during repair")
    if not stat.S_ISDIR(after.st_mode):
        raise RuntimeError("opened object changed type during repair")
    if (after.st_uid, after.st_gid) != (owner_uid, owner_gid):
        raise RuntimeError("directory ownership verification failed")
    if stat.S_IMODE(after.st_mode) != mode:
        raise RuntimeError("directory mode verification failed")
except (OSError, RuntimeError, ValueError) as error:
    print(f"[setup:error] Could not safely repair directory {path}: {error}", file=sys.stderr)
    sys.exit(1)
finally:
    if fd is not None:
        os.close(fd)
PY
		return 1
	fi
}

prepare_user_owned_mount_roots() {
	local runtime_uid
	local runtime_gid

	runtime_uid="$(id -u)"
	runtime_gid="$(id -g)"

	# Repair only the exact bind-mount roots. Parent directories precede
	# their mounted descendants so each path can be opened safely.
	repair_exact_directory "${HOME}/.pi" "${runtime_uid}" "${runtime_gid}" 0755
	repair_exact_directory "${HOME}/.engram" "${runtime_uid}" "${runtime_gid}" 0755
	repair_exact_directory "${HOME}/.gitconfig-volume" "${runtime_uid}" "${runtime_gid}" 0755
	repair_exact_directory "${HOME}/.local" "${runtime_uid}" "${runtime_gid}" 0755
	repair_exact_directory "${HOME}/.local/share" "${runtime_uid}" "${runtime_gid}" 0755
	repair_exact_directory "${HOME}/.local/share/opencode" "${runtime_uid}" "${runtime_gid}" 0755
}

prepare_user_owned_mount_roots

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

# Seed the base config files for every tool the project cares about.
# Each line is a (source_root, target_root) pair that gets handed to
# seed_config_tree. To add a new tool's baseline config:
#   1. Create .devcontainer/<name>-config/ with the file tree that
#      mirrors the tool's runtime config location.
#   2. Add a seed_config_tree call below with the absolute target.
# See .devcontainer/README.md for the full convention.
setup_versioned_configs() {
	# Pi and Gentle-AI configs land in the user's home (~/.pi/).
	seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config" "${HOME}/.pi"
	seed_config_tree "${WORKSPACE_DIR}/.devcontainer/opencode-config" "${HOME}/.config/opencode"

	# Add additional tool configs here, one line per source root:
	#   seed_config_tree "${WORKSPACE_DIR}/.devcontainer/postgres-config" "/etc/postgresql/16/main"
	#   seed_config_tree "${WORKSPACE_DIR}/.devcontainer/redis-config" "/etc/redis"
	#   seed_config_tree "${WORKSPACE_DIR}/.devcontainer/vscode-config" "${HOME}/.config/Code"
	#   seed_config_tree "${WORKSPACE_DIR}/.devcontainer/<name>-config.local" "${HOME}/.<name>" || true
}

run_enabled_opencode_installer() {
	local enabled_dir="${SCRIPT_DIR}/install/02-enabled"
	local installer="${SCRIPT_DIR}/install/available/30-ai-opencode.sh"
	local canonical_installer
	local enabled_script
	local resolved_script

	[ -f "${installer}" ] || return 0
	canonical_installer="$(readlink -f -- "${installer}")"

	for enabled_script in "${enabled_dir}"/*.sh; do
		[ -L "${enabled_script}" ] || continue
		resolved_script="$(readlink -f -- "${enabled_script}" 2>/dev/null)" || continue

		if [ "${resolved_script}" = "${canonical_installer}" ]; then
			DEVCONTAINER_PHASE=runtime bash "${canonical_installer}"
			return
		fi
	done
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
# Volume-aware install repair is sourced above from setup-volumes.sh.
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
setup_versioned_configs
setup_pi_workspace_trust
# export PATH="${HOME}/.local/bin:${PATH}"
repair_installed_volumes
run_enabled_opencode_installer

# ---------------------------------------------------------------------------
# SSH server: start if the install script is enabled.
# Detection: check for the symlink in 02-enabled/ (created by
# task install:enable -- ssh, or manually). The script is NOT started
# by default — this is an intentional security gate: SSH on a LAN port
# should not spin up silently for every rebuild.
# ---------------------------------------------------------------------------
_ssh_enabled_file="${SCRIPT_DIR}/install/02-enabled/20-ssh.sh"
if [ -L "${_ssh_enabled_file}" ]; then
	if command -v start-sshd >/dev/null 2>&1; then
		start-sshd
	else
		echo "[setup:warn] start-sshd not on PATH; rebuild the container to complete SSH install" >&2
	fi
fi
