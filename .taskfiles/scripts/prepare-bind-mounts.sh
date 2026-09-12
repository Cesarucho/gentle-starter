#!/usr/bin/env bash
set -euo pipefail

workspace="${1:-.}"
workspace="$(cd "${workspace}" && pwd -P)"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec python3 "${script_dir}/compose-manifest.py" prepare "${workspace}"
