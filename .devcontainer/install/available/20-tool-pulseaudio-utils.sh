#!/usr/bin/env bash
# Optional PulseAudio clients (paplay); does not configure or start a sound server.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"
if devcontainer_is_build; then
	devcontainer_run_as_root apt-get update -qq
	devcontainer_run_as_root apt-get install -y -qq pulseaudio-utils >/dev/null
fi
