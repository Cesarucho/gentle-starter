#!/usr/bin/env bash
set -euo pipefail

PI_CODING_AGENT_VERSION="${PI_CODING_AGENT_VERSION:-0.78.1}"

npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@${PI_CODING_AGENT_VERSION}"
