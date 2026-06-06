#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-auto}"
ERRORS=0
WARNINGS=0

usage() {
	cat <<'EOF'
Usage:
  .taskfiles/scripts/doctor.sh [auto|host|container]

Modes:
  auto        Detect the current context and run the matching checks.
  host        Check host requirements for building/opening the devcontainer.
  container   Check tools and mounts inside the devcontainer.
EOF
}

info() { printf '[info] %s\n' "$*"; }
ok() { printf '[ok] %s\n' "$*"; }
warn() {
	printf '[warn] %s\n' "$*"
	WARNINGS=$((WARNINGS + 1))
}
fail() {
	printf '[fail] %s\n' "$*"
	ERRORS=$((ERRORS + 1))
}

has_command() {
	command -v "$1" >/dev/null 2>&1
}

check_command() {
	local command_name="$1"
	local required="${2:-required}"

	if has_command "${command_name}"; then
		ok "${command_name} available: $(${command_name} --version 2>/dev/null | head -n 1 || printf 'installed')"
		return 0
	fi

	if [ "${required}" = "optional" ]; then
		warn "${command_name} not found"
	else
		fail "${command_name} not found"
	fi
}

check_file() {
	local path="$1"
	if [ -f "${path}" ]; then
		ok "file exists: ${path}"
	else
		fail "missing file: ${path}"
	fi
}

check_dir() {
	local path="$1"
	local required="${2:-required}"

	if [ -d "${path}" ]; then
		ok "directory exists: ${path}"
		return 0
	fi

	if [ "${required}" = "optional" ]; then
		warn "directory missing: ${path}"
	else
		fail "missing directory: ${path}"
	fi
}

repo_root() {
	git rev-parse --show-toplevel 2>/dev/null || pwd
}

is_devcontainer() {
	if [ "${DEVCONTAINER:-}" = "true" ] || [ "${REMOTE_CONTAINERS:-}" = "true" ]; then
		return 0
	fi

	[ -f /.dockerenv ] && [ -f /home/ubuntu/code/.devcontainer/devcontainer.json ]
}

extract_devcontainer_service() {
	sed -n 's/^[[:space:]]*"service"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
		.devcontainer/devcontainer.json | head -n 1
}

check_devcontainer_service() {
	local service
	service="$(extract_devcontainer_service)"

	if [ -z "${service}" ]; then
		fail "could not read service from .devcontainer/devcontainer.json"
		return
	fi

	ok "devcontainer service configured: ${service}"

	if grep -Eq "^[[:space:]]{2}${service}:" .devcontainer/docker-compose.yml; then
		ok "docker-compose service exists: ${service}"
	else
		fail "docker-compose service not found: ${service}"
	fi
}

check_skills() {
	check_file skills-lock.json

	if [ ! -f skills-lock.json ]; then
		return
	fi

	if ! has_command jq; then
		warn "jq not found; skipping detailed skills-lock validation"
		return
	fi

	local missing=0
	while IFS= read -r skill; do
		if [ -f ".agents/skills/${skill}/SKILL.md" ]; then
			ok "skill present: ${skill}"
		else
			fail "missing skill: .agents/skills/${skill}/SKILL.md"
			missing=1
		fi
	done < <(jq -r '.skills | keys[]' skills-lock.json)

	[ "${missing}" -eq 0 ] || return 1
}

run_host() {
	info "Gentleman Starter doctor: host checks"

	if is_devcontainer; then
		warn "host checks are running from inside a container; results may not represent the real host"
	fi

	check_command docker
	check_command git
	check_command task
	check_command devcontainer optional
	check_command jq optional

	check_file .devcontainer/devcontainer.json
	check_file .devcontainer/docker-compose.yml
	check_file .devcontainer/Dockerfile
	check_file .devcontainer/setup.sh
	check_file Taskfile.yml
	check_file .env.example

	if [ -f .env ]; then
		ok "local .env exists"
	else
		warn "local .env missing; create it with: cp .env.example .env"
	fi

	check_dir env optional
	check_devcontainer_service
	check_skills || true
}

run_container() {
	info "Gentleman Starter doctor: devcontainer checks"

	check_command git
	check_command task
	check_command node
	check_command npm
	check_command pi
	check_command engram
	check_command gh optional
	check_command playwright optional

	check_dir /home/ubuntu/.pi
	check_dir /home/ubuntu/.engram
	check_dir /home/ubuntu/.gitconfig-volume

	if [ "$(id -un 2>/dev/null || true)" = "ubuntu" ]; then
		ok "running as expected user: ubuntu"
	else
		warn "unexpected user: $(id -un 2>/dev/null || printf unknown); expected ubuntu"
	fi

	check_file .devcontainer/devcontainer.json
	check_file .devcontainer/docker-compose.yml
	check_devcontainer_service
	check_skills || true
}

case "${MODE}" in
auto)
	cd "$(repo_root)"
	if is_devcontainer; then
		run_container
	else
		run_host
	fi
	;;
host)
	cd "$(repo_root)"
	run_host
	;;
container)
	cd "$(repo_root)"
	run_container
	;;
-h | --help | help)
	usage
	exit 0
	;;
*)
	usage >&2
	exit 2
	;;
esac

printf '\nSummary: %s error(s), %s warning(s)\n' "${ERRORS}" "${WARNINGS}"

if [ "${ERRORS}" -gt 0 ]; then
	exit 1
fi
