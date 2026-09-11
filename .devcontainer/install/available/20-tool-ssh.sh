#!/usr/bin/env bash
#
# 20-tool-ssh.sh — OpenSSH server for remote VSCode access.
#
# Lifecycle:
#   * DEVCONTAINER_PHASE=build  — install OpenSSH packages
#   * DEVCONTAINER_PHASE=runtime — prepare persistent keys and seed configuration
#
# Security defaults:
#   * Pubkey authentication only (no password auth)
#   * Root login disabled
#   * PermitRootLogin no
#   * Port forced to 22 inside container (published on generated SSH_PORT at host loopback)
#
# Usage:
#   # Inside the container:
#   start-sshd              # start sshd (idempotent: no-op if already running)
#   start-sshd --regenerate # regenerate host keys first, then start
#
#   # From the host:
#   ssh -p <SSH_PORT from .env> ubuntu@127.0.0.1
#
# To enable: create symlink in 02-enabled/ (opt-in; not enabled by default)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${SSH_PORT:=22}"
: "${SSH_CONFIG_DIR:=${HOME}/.ssh-server}"
: "${SSH_START_WRAPPER_TARGET:=/usr/local/bin/start-sshd}"
: "${SSHD_CONFIG_TARGET:=/etc/ssh/sshd_config.gentle-starter}"

# ---------------------------------------------------------------------------
# Phase: build
# ---------------------------------------------------------------------------
_devcontainer_ssh_install() {
	devcontainer_log_info "Installing openssh-server"

	# Install openssh-server (sshd for remote container access)
	# Install openssh-client (ssh, ssh-add, scp for debugging agent forwarding)
	devcontainer_run_as_root apt-get update -qq
	devcontainer_run_as_root apt-get install -y -qq openssh-server openssh-client >/dev/null

	devcontainer_log_info "openssh-server installed"
}

# ---------------------------------------------------------------------------
# Phase: runtime — seed configs (idempotent: skip if already seeded)
# ---------------------------------------------------------------------------
_devcontainer_ssh_install_start_wrapper() {
	# The repository source is content (tracked as 0644); installation owns the
	# executable mode at the privileged destination.
	local source="${WORKSPACE_DIR}/.devcontainer/ssh-config/usr/local/bin/start-sshd"
	local target_dir
	target_dir="$(dirname "${SSH_START_WRAPPER_TARGET}")"

	if [ -e "${SSH_START_WRAPPER_TARGET}" ]; then
		if [ ! -f "${SSH_START_WRAPPER_TARGET}" ] || [ -L "${SSH_START_WRAPPER_TARGET}" ]; then
			devcontainer_log_error "Refusing to replace non-regular SSH startup wrapper: ${SSH_START_WRAPPER_TARGET}"
			return 1
		fi
		devcontainer_run_as_root chmod 0755 "${SSH_START_WRAPPER_TARGET}"
		return 0
	fi

	devcontainer_run_as_root install -d -m 0755 "${target_dir}"
	devcontainer_run_as_root install -m 0755 "${source}" "${SSH_START_WRAPPER_TARGET}"
}

_devcontainer_ssh_install_config() {
	local source="${WORKSPACE_DIR}/.devcontainer/ssh-config/etc/ssh/sshd_config"
	local target_dir
	target_dir="$(dirname "${SSHD_CONFIG_TARGET}")"

	if [ -e "${SSHD_CONFIG_TARGET}" ] && { [ ! -f "${SSHD_CONFIG_TARGET}" ] || [ -L "${SSHD_CONFIG_TARGET}" ]; }; then
		devcontainer_log_error "Refusing to replace non-regular managed SSH configuration: ${SSHD_CONFIG_TARGET}"
		return 1
	fi

	devcontainer_run_as_root install -d -m 0755 "${target_dir}"
	devcontainer_run_as_root install -m 0644 "${source}" "${SSHD_CONFIG_TARGET}"
}

_devcontainer_ssh_seed_config() {
	local home_owner key_type key_file
	mkdir -p "${SSH_CONFIG_DIR}/ssh"
	chmod 0700 "${SSH_CONFIG_DIR}" "${SSH_CONFIG_DIR}/ssh"
	for key_type in rsa ed25519; do
		key_file="${SSH_CONFIG_DIR}/ssh/ssh_host_${key_type}_key"
		if [ ! -f "${key_file}" ]; then
			ssh-keygen -t "${key_type}" -f "${key_file}" -N "" -C ""
		fi
	done

	# OpenSSH owns /etc/ssh/sshd_config. Install our managed configuration at a
	# distinct path so package defaults can never silently select image keys.
	_devcontainer_ssh_install_config

	# Preserve existing wrapper content while enforcing its executable contract.
	_devcontainer_ssh_install_start_wrapper

	home_owner="$(id -u):$(id -g)"
	if [ "$(stat -c '%u:%g' "${HOME}")" != "${home_owner}" ] || [ "$((8#$(stat -c '%a' "${HOME}") & 8#022))" -ne 0 ]; then
		devcontainer_log_error "StrictModes requires ${HOME} to be owned by $(id -un) and not writable by group or others"
		return 1
	fi
	if [ -e "${HOME}/.ssh" ] && { [ ! -d "${HOME}/.ssh" ] || [ -L "${HOME}/.ssh" ]; }; then
		devcontainer_log_error "Refusing unsafe SSH authorization directory: ${HOME}/.ssh"
		return 1
	fi
	mkdir -p "${HOME}/.ssh"
	chmod 0700 "${HOME}/.ssh"

	# Inject authorized_keys from the SSH_AUTHORIZED_KEYS env var.
	# Set this in .env (or in the shell before container start):
	#   SSH_AUTHORIZED_KEYS="ssh-ed25519 AAAA... tu-comentario\nssh-ed25519 BBBB... otra-clave"
	# The environment is authoritative: never retain keys from an earlier run.
	if [ -n "${SSH_AUTHORIZED_KEYS:-}" ]; then
		local authorized_keys_tmp key
		authorized_keys_tmp="$(mktemp "${HOME}/.ssh/.authorized_keys.XXXXXX")"
		chmod 0600 "${authorized_keys_tmp}"
		while IFS= read -r key; do
			key="${key%$'\r'}"
			[ -z "${key}" ] && continue
			[[ "${key}" =~ ^# ]] && continue
			if [[ ! "${key}" =~ ^(ssh-(ed25519|rsa)|ecdsa-sha2-nistp(256|384|521)|sk-(ssh-ed25519|ecdsa-sha2-nistp256)@openssh\.com)[[:space:]]+[A-Za-z0-9+/]+={0,3}([[:space:]].*)?$ ]]; then
				rm -f "${authorized_keys_tmp}"
				devcontainer_log_error "SSH_AUTHORIZED_KEYS contains an unsupported or malformed public key"
				return 1
			fi
			printf '%s\n' "${key}" >>"${authorized_keys_tmp}"
		done <<<"${SSH_AUTHORIZED_KEYS}"
		if [ ! -s "${authorized_keys_tmp}" ] || ! ssh-keygen -l -f "${authorized_keys_tmp}" >/dev/null 2>&1; then
			rm -f "${authorized_keys_tmp}"
			devcontainer_log_error "SSH_AUTHORIZED_KEYS did not contain a valid public key"
			return 1
		fi
		mv -f "${authorized_keys_tmp}" "${HOME}/.ssh/authorized_keys"
		chmod 0600 "${HOME}/.ssh/authorized_keys"
		devcontainer_log_info "authorized_keys: installed explicit validated keys"
	else
		rm -f "${HOME}/.ssh/authorized_keys"
		devcontainer_log_warn "SSH_AUTHORIZED_KEYS is not set; no pubkey registered."
		devcontainer_log_warn "Add to .env: SSH_AUTHORIZED_KEYS=\"ssh-ed25519 ...\""
	fi
	if [ "$(stat -c '%u:%g:%a' "${HOME}/.ssh")" != "${home_owner}:700" ] ||
		{ [ -e "${HOME}/.ssh/authorized_keys" ] && [ "$(stat -c '%u:%g:%a' "${HOME}/.ssh/authorized_keys")" != "${home_owner}:600" ]; }; then
		devcontainer_log_error "SSH authorization paths do not satisfy StrictModes ownership and permissions"
		return 1
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
