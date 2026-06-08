#!/usr/bin/env bash
set -euo pipefail

DEVCONTAINER_PHASE="${DEVCONTAINER_PHASE:-build}"
ENGRAM_VERSION="${ENGRAM_VERSION:-1.16.1}"
TARGET_OS="linux"

resolve_target_arch() {
	case "$(uname -m)" in
	x86_64)
		TARGET_ARCH="amd64"
		;;
	aarch64 | arm64)
		TARGET_ARCH="arm64"
		;;
	*)
		echo "Unsupported architecture: $(uname -m)" >&2
		exit 1
		;;
	esac
}

ensure_user_path() {
	local path_line='export PATH="$HOME/.local/bin:$PATH"'

	mkdir -p "${HOME}/.local/bin"

	if [ -f "${HOME}/.bashrc" ]; then
		if ! grep -Fq '.local/bin' "${HOME}/.bashrc"; then
			{
				echo ""
				echo "# User-local CLI tools"
				echo "${path_line}"
			} >>"${HOME}/.bashrc"
		fi
	else
		echo "${path_line}" >"${HOME}/.bashrc"
	fi

	export PATH="${HOME}/.local/bin:${PATH}"
}

install_engram() {
	local install_dir="${ENGRAM_INSTALL_DIR:-}"
	local engram_cmd=""
	local current_version=""
	local engram_file=""
	local engram_url=""
	local tmp_dir=""
	local engram_bin=""

	resolve_target_arch

	if [ -z "${install_dir}" ]; then
		if [ "$(id -u)" -eq 0 ]; then
			install_dir="/usr/bin"
		else
			install_dir="${HOME}/.local/bin"
		fi
	fi

	mkdir -p "${install_dir}"

	if [ -x "${install_dir}/engram" ]; then
		engram_cmd="${install_dir}/engram"
	elif command -v engram >/dev/null 2>&1; then
		engram_cmd="$(command -v engram)"
	fi

	if [ -n "${engram_cmd}" ]; then
		current_version="$(${engram_cmd} version | awk '{print $NF}' | sed 's/^v//')"
		if [ "${current_version}" = "${ENGRAM_VERSION}" ]; then
			echo "Engram ${ENGRAM_VERSION} already installed at ${engram_cmd}"
			return 0
		fi
	fi

	engram_file="engram_${ENGRAM_VERSION}_${TARGET_OS}_${TARGET_ARCH}.tar.gz"
	engram_url="https://github.com/Gentleman-Programming/engram/releases/download/v${ENGRAM_VERSION}/${engram_file}"
	tmp_dir="$(mktemp -d)"
	trap 'rm -rf "${tmp_dir}"' RETURN

	echo "Installing Engram ${ENGRAM_VERSION} into ${install_dir}"
	echo "Detected architecture: $(uname -m) -> ${TARGET_ARCH}"
	echo "Downloading: ${engram_url}"

	curl -fsSL -o "${tmp_dir}/${engram_file}" "${engram_url}"
	tar -xzf "${tmp_dir}/${engram_file}" -C "${tmp_dir}"

	engram_bin="$(find "${tmp_dir}" -type f -name engram | head -n 1)"

	if [ -z "${engram_bin}" ]; then
		echo "engram binary not found inside archive" >&2
		find "${tmp_dir}" -maxdepth 3 -type f -print >&2
		exit 1
	fi

	install -m 0755 "${engram_bin}" "${install_dir}/engram"

	export PATH="${install_dir}:${PATH}"
	echo "Engram installed at: ${install_dir}/engram"
	"${install_dir}/engram" version
}

setup_user_integrations() {
	local engram_data_dir="${ENGRAM_DATA_DIR:-${HOME}/.engram}"

	ensure_user_path
	install_engram
	mkdir -p "${engram_data_dir}"

	if [ -f "${engram_data_dir}/engram.db" ]; then
		echo "Preserving existing Engram database at ${engram_data_dir}/engram.db"
	fi

	engram setup pi
	engram setup opencode || true
}

if [ "${DEVCONTAINER_PHASE}" = "runtime" ]; then
	if [ "$(id -u)" -eq 0 ]; then
		echo "Engram user setup must run as the final non-root user" >&2
		exit 1
	fi

	setup_user_integrations
	exit 0
fi

install_engram
