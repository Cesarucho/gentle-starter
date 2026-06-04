#!/usr/bin/env bash
set -euo pipefail

NODE_MAJOR="${NODE_MAJOR:-26}"

curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -

apt-get install -y --no-install-recommends nodejs

node --version
npm --version