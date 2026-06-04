#!/usr/bin/env bash
set -euo pipefail

ENGRAM_VERSION="${ENGRAM_VERSION:-1.16.1}"
TARGET_OS="linux"

case "$(uname -m)" in
    x86_64)
        TARGET_ARCH="amd64"
        ;;
    aarch64|arm64)
        TARGET_ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

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
engram --version || true

engram setup pi || true
engram setup opencode || true