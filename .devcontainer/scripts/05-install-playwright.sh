#!/usr/bin/env bash
set -euo pipefail

PLAYWRIGHT_VERSION="${PLAYWRIGHT_VERSION:-1.60.0}"
PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/ms-playwright}"

mkdir -p "${PLAYWRIGHT_BROWSERS_PATH}"
chmod 0755 "${PLAYWRIGHT_BROWSERS_PATH}"

npm install -g "playwright@${PLAYWRIGHT_VERSION}"

PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH}" \
	npx -y "playwright@${PLAYWRIGHT_VERSION}" install chromium --with-deps
