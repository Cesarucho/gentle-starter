#!/usr/bin/env bash
set -euo pipefail

PI_CODING_AGENT_VERSION="${PI_CODING_AGENT_VERSION:-0.79.0}"

npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@${PI_CODING_AGENT_VERSION}"
