#!/usr/bin/env bash
#
# 20-tool-ssh.sh — OpenSSH server for remote VSCode access.
#
# Lifecycle:
#   * DEVCONTAINER_PHASE=build  — install openssh-server + generate host keys
#   * DEVCONTAINER_PHASE=runtime — seed sshd_config and startup wrapper (idempotent)
#
# Security defaults:
#   * Pubkey authentication only (no password auth)
#   * Root login disabled
#   * PermitRootLogin no
#   * Port forced to 22 inside container (exposed as 2222 in compose)
#
# Usage:
#   # Inside the container:
#   start-sshd              # start sshd (idempotent: no-op if already running)
#   start-sshd --regenerate # regenerate host keys first, then start
#
#   # From remote PC (same WiFi):
#   ssh -p 2222 ubuntu@<host-ip>
#
# To enable: create symlink in 02-enabled/ (opt-in; not enabled by default)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${SSH_PORT:=22}"
: "${SSH_CONFIG_DIR:=${HOME}/.ssh-server}"

# ---------------------------------------------------------------------------
# Phase: build
# ---------------------------------------------------------------------------
_devcontainer_ssh_install() {
	devcontainer_log_info "Installing openssh-server"

	# Create state dir for host keys (survives rebuild when volume-mounted)
	mkdir -p "${SSH_CONFIG_DIR}/ssh"
	chmod 0700 "${SSH_CONFIG_DIR}"
	chmod 0700 "${SSH_CONFIG_DIR}/ssh"

	# Generate host keys if missing (idempotent: skip if already exist)
	local key_type
	for key_type in rsa ed25519; do
		local key_file="${SSH_CONFIG_DIR}/ssh/ssh_host_${key_type}_key"
		if [ ! -f "${key_file}" ]; then
			devcontainer_log_info "Generating ssh_host_${key_type}_key"
			ssh-keygen -t "${key_type}" -f "${key_file}" -N "" -C "" 2>/dev/null || true
		else
			devcontainer_log_info "ssh_host_${key_type}_key already exists"
		fi
	done

	# Install openssh-server (sshd for remote container access)
	# Install openssh-client (ssh, ssh-add, scp for debugging agent forwarding)
	devcontainer_run_as_root apt-get update -qq
	devcontainer_run_as_root apt-get install -y -qq openssh-server openssh-client >/dev/null

	devcontainer_log_info "openssh-server installed"
}

# ---------------------------------------------------------------------------
# Phase: runtime — seed configs (idempotent: skip if already seeded)
# ---------------------------------------------------------------------------
_devcontainer_ssh_seed_config() {
	local config_source="${WORKSPACE_DIR}/.devcontainer/ssh-config"

	# Seed sshd_config (copy only if target does not exist)
	seed_config_tree "${config_source}/etc" "/etc"

	# Seed startup wrapper (copy only if target does not exist)
	seed_config_tree "${config_source}/usr" "/usr"

	# Ensure ~/.ssh directory exists with correct permissions (700).
	# This is the prerequisite for authorized_keys to work with PubkeyAuth.
	if [ ! -d "${HOME}/.ssh" ]; then
		mkdir -p "${HOME}/.ssh"
		chmod 0700 "${HOME}/.ssh"
		devcontainer_log_info "Created ${HOME}/.ssh with mode 0700"
	else
		# Fix permissions if something set them wrong (e.g. a bind mount with 755)
		chmod 0700 "${HOME}/.ssh"
	fi

	# Inject authorized_keys from the SSH_AUTHORIZED_KEYS env var.
	# Set this in .env (or in the shell before container start):
	#   SSH_AUTHORIZED_KEYS="ssh-ed25519 AAAA... tu-comentario\nssh-ed25519 BBBB... otra-clave"
	# Keys are appended (idempotent): existing keys are not removed.
	if [ -n "${SSH_AUTHORIZED_KEYS:-}" ]; then
		local key
		while IFS= read -r key; do
			# Skip empty lines and comment-only lines
			[ -z "${key}" ] && continue
			[[ "${key}" =~ ^# ]] && continue

			if grep -FqFx -- "${key}" "${HOME}/.ssh/authorized_keys" 2>/dev/null; then
				devcontainer_log_info "authorized_keys: key already present (skipped)"
			else
				printf '%s\n' "${key}" >>"${HOME}/.ssh/authorized_keys"
				devcontainer_log_info "authorized_keys: key added"
			fi
		done <<<"${SSH_AUTHORIZED_KEYS}"
		chmod 0600 "${HOME}/.ssh/authorized_keys"
	else
		devcontainer_log_warn "SSH_AUTHORIZED_KEYS is not set; no pubkey registered."
		devcontainer_log_warn "Add to .env: SSH_AUTHORIZED_KEYS=\"ssh-ed25519 ...\""
	fi

	devcontainer_log_info "sshd_config and start-sshd wrapper seeded"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
main() {
	if devcontainer_is_build; then
		_devcontainer_ssh_install
	elif devcontainer_is_runtime; then
		_devcontainer_ssh_seed_config
	fi
}

main
