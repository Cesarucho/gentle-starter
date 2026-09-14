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
	if [ "${FORCE_HOST_CONTEXT:-}" = "1" ]; then
		return 1
	fi

	if [ "${DEVCONTAINER:-}" = "true" ] || [ "${REMOTE_CONTAINERS:-}" = "true" ]; then
		return 0
	fi

	[ -f /.dockerenv ] && [ -d .devcontainer ]
}

extract_devcontainer_service() {
	python3 .taskfiles/scripts/compose-manifest.py service .
}

check_devcontainer_service() {
	local service
	service="$(extract_devcontainer_service)" || {
		fail "selected Compose manifest unavailable; run task container:up on the host"
		return
	}

	if [ -z "${service}" ]; then
		fail "could not read service from .devcontainer/devcontainer.json"
		return
	fi

	ok "devcontainer service configured: ${service}"

	if python3 .taskfiles/scripts/compose-manifest.py check .; then
		ok "selected Compose volume manifest is current (desired, not applied)"
	else
		fail "selected Compose volume manifest missing or stale; run task container:up on the host"
	fi
}

check_skills() {
	if [ ! -f skills-lock.json ]; then
		warn "skills-lock.json not found; skipping optional project skill checks"
		return
	fi

	ok "file exists: skills-lock.json"

	if ! has_command jq; then
		warn "jq not found; skipping optional project skill checks"
		return
	fi

	while IFS= read -r skill; do
		if [ -f ".agents/skills/${skill}/SKILL.md" ]; then
			ok "skill present: ${skill}"
		else
			warn "optional project skill missing: .agents/skills/${skill}/SKILL.md"
		fi
	done < <(jq -r '.skills | keys[]' skills-lock.json)
}

is_install_enabled() {
	# shellcheck source=/dev/null
	source .devcontainer/install/lib/activation.sh
	devcontainer_install_is_active .devcontainer/install ".devcontainer/install/available/$1"
}

check_enabled_command() {
	local installer="$1" command_name="$2"
	if is_install_enabled "${installer}"; then
		check_command "${command_name}"
	else info "${command_name} check skipped: ${installer} is disabled"; fi
}

run_host() {
	info "Gentle Starter doctor: host checks"

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

	check_dir .env.d optional
	check_devcontainer_service
	check_skills || true
}

run_container() {
	info "Gentle Starter doctor: devcontainer checks"

	check_command git
	check_command task
	check_command node
	check_command npm
	check_enabled_command 3030-ai-pi-coding.sh pi
	check_enabled_command 3010-ai-engram.sh engram
	check_enabled_command 3020-ai-gentle-ai.sh gentle-ai
	check_command gh optional
	check_command playwright optional

	if is_install_enabled 3030-ai-pi-coding.sh || is_install_enabled 3040-ai-pi-gentle.sh; then check_dir /home/ubuntu/.pi; fi
	if is_install_enabled 3010-ai-engram.sh; then check_dir /home/ubuntu/.engram; fi
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
