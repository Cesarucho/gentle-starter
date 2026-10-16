#!/usr/bin/env bash
# OpenSSH client only; server activation is independent and opt-in.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"
if devcontainer_is_build; then
	devcontainer_run_as_root apt-get update -qq
	devcontainer_run_as_root apt-get install -y -qq openssh-client >/dev/null
fi
