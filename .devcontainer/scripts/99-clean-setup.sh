#!/usr/bin/env bash
set -euo pipefail

apt-get clean

if command -v npm >/dev/null 2>&1; then
    npm cache clean --force
fi

rm -rf /root/.npm
rm -rf /usr/local/lib/node_modules/.cache
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*