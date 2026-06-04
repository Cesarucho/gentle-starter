#!/usr/bin/env bash
set -euo pipefail

DEVCONTAINER_PHASE="${DEVCONTAINER_PHASE:-build}"
ENGRAM_VERSION="${ENGRAM_VERSION:-1.16.1}"
TARGET_OS="linux"

setup_user_integrations() {
	local engram_data_dir="${ENGRAM_DATA_DIR:-${HOME}/.engram}"

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

if command -v engram >/dev/null 2>&1; then
	CURRENT_VERSION="$(engram version | awk '{print $NF}' | sed 's/^v//')"
	if [ "${CURRENT_VERSION}" = "${ENGRAM_VERSION}" ]; then
		echo "Engram ${ENGRAM_VERSION} already installed globally"
		exit 0
	fi
fi

ENGRAM_FILE="engram_${ENGRAM_VERSION}_${TARGET_OS}_${TARGET_ARCH}.tar.gz"
ENGRAM_URL="https://github.com/Gentleman-Programming/engram/releases/download/v${ENGRAM_VERSION}/${ENGRAM_FILE}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Installing Engram ${ENGRAM_VERSION}"
echo "Detected architecture: $(uname -m) -> ${TARGET_ARCH}"
echo "Downloading: ${ENGRAM_URL}"

curl -fsSL -o "${TMP_DIR}/${ENGRAM_FILE}" "${ENGRAM_URL}"
tar -xzf "${TMP_DIR}/${ENGRAM_FILE}" -C "${TMP_DIR}"

ENGRAM_BIN="$(find "${TMP_DIR}" -type f -name engram | head -n 1)"

if [ -z "${ENGRAM_BIN}" ]; then
	echo "engram binary not found inside archive" >&2
	find "${TMP_DIR}" -maxdepth 3 -type f -print >&2
	exit 1
fi

install -m 0755 "${ENGRAM_BIN}" /usr/bin/engram

echo "Engram installed at: $(command -v engram)"
engram version
