#!/usr/bin/env bash
set -euo pipefail

npm install -g playwright@latest

npx -y playwright@latest install chromium --with-deps