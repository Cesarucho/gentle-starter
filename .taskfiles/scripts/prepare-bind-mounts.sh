#!/usr/bin/env bash
set -euo pipefail

workspace="${1:-.}"
workspace="$(cd "${workspace}" && pwd -P)"
compose_file="${workspace}/.devcontainer/docker-compose.yml"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${script_dir}/yq-compatibility.sh"

yq_compatibility_json '.services."container-svc".volumes // []' "${compose_file}" |
	python3 "${script_dir}/prepare-bind-mounts.py" "${workspace}" "$(id -u)" "$(id -g)"
