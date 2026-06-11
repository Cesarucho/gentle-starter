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
		"${WORKSPACE_DIR}/.devcontainer/pi-config/agent/mcp.json" \
		"${HOME}/.pi/agent/mcp.json"

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

# ---------------------------------------------------------------------------
# Volume-aware install repair
# ---------------------------------------------------------------------------
#
# The install/ tree has a catalog of available/ scripts and a set of
# enabled/ symlinks that run during image build. A subset of those
# scripts owns a bind-mounted volume (declared in docker-compose.yml)
# and needs to run again at runtime when the host directory has just
# been created or repopulated. The three functions below implement
# that wiring without the legacy scripts/ hardcoded paths.

# Emit "source|target" pairs, one per line, for each bind mount in
# docker-compose.yml with both source and target defined.
resolve_compose_volume_targets() {
	local compose_file="${WORKSPACE_DIR}/.devcontainer/docker-compose.yml"
	local vol
	local src
	local tgt

	while IFS= read -r vol; do
		# Skip empty lines
		[ -z "${vol// /}" ] && continue

		# The short-form volume entry is a string like
		# "../env/.pi:/home/ubuntu/.pi[:ro|:rw]". Strip the YAML
		# list prefix and split on the first colon.
		vol="${vol#"${vol%%[![:space:]]*}"}" # leading whitespace
		vol="${vol#- }"                      # YAML list marker
		vol="${vol#-}"                       # YAML list marker (no space)

		if [[ "${vol}" == *:* ]]; then
			src="${vol%%:*}"
			tgt="${vol#*:}"
			tgt="${tgt%%:*}" # strip optional :ro/:rw mode

			# Bind mounts have a non-empty source.
			if [ -n "${src}" ] && [ -n "${tgt}" ]; then
				printf '%s|%s\n' "${src}" "${tgt}"
			fi
		fi
	done < <(yq -r '.services."container-svc".volumes[]' "${compose_file}" 2>/dev/null || true)
}

# Map a container-side target path to the install script base names
# (without the .sh extension) that own that volume.
compose_target_to_install_scripts() {
	local target="$1"
	local -n scripts_ref="$2"

	scripts_ref=()
	case "${target}" in
	"${HOME}/.pi" | "/home/${UID}/.pi")
		scripts_ref+=("30-ai-pi-coding" "30-ai-pi-gentle")
		;;
	"${HOME}/.engram" | "/home/${UID}/.engram")
		scripts_ref+=("30-ai-engram")
		;;
	"${HOME}/.local" | "/home/${UID}/.local")
		scripts_ref+=("30-ai-engram")
		;;
	esac
}

# Iterate over bind-mount volume targets from docker-compose.yml and
# run the install scripts that own each target, with
# DEVCONTAINER_PHASE=runtime. Each script is idempotent: it skips
# itself when the tool is already installed, so a re-run on a
# populated volume is a no-op.
repair_installed_volumes() {
	local install_root="${WORKSPACE_DIR}/.devcontainer/install/available"
	local source_path
	local target_path
	local scripts=()
	local script
	local script_path

	while IFS='|' read -r source_path target_path; do
		compose_target_to_install_scripts "${target_path}" scripts

		for script in "${scripts[@]}"; do
			script_path="${install_root}/${script}.sh"
			if [ ! -f "${script_path}" ]; then
				continue
			fi
			echo "Volume repair: ${target_path} -> ${script}.sh"
			DEVCONTAINER_PHASE=runtime bash "${script_path}"
		done
	done < <(resolve_compose_volume_targets)
}

# Install/update user-scoped AI tooling after volumes are mounted for ubuntu.
# Link before install so Pi reads the versioned settings, then link again in case
# any tool rewrites config files via atomic replace and breaks the symlink.
setup_versioned_pi_config
setup_pi_workspace_trust
# export PATH="${HOME}/.local/bin:${PATH}"
repair_installed_volumes
setup_versioned_pi_config
