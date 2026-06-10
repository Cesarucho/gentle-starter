#!/usr/bin/env bash
set -euo pipefail

: "${PNPM_VERSION:=latest}"

npm install --global "pnpm@${PNPM_VERSION}"

pnpm --version
