#!/usr/bin/env bash
# Safely prove the Pi Gentle lifecycle across two real devcontainer rebuilds.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE="container-svc"
RUN_ROOT=""
CANDIDATE=""
PROJECT=""
SSH_PORT=""
PRIVATE_DIR=""
CLEANUP_FAILED=0

fail() {
	printf '[pi-lifecycle:error] %s\n' "$*" >&2
	exit 1
}

note() {
	printf '[pi-lifecycle] %s\n' "$*"
}

require_safe_context() {
	[ -n "${ROOT}" ] || fail "run from a Git worktree"
	[ "$(pwd -P)" = "${ROOT}" ] || fail "run from the repository root: ${ROOT}"
	case "${ROOT}" in
	/ | /tmp | /tmp/opencode) fail "unsafe repository root: ${ROOT}" ;;
	esac
	for command in docker devcontainer git rsync ssh ssh-keygen sha256sum python3 task; do
		command -v "${command}" >/dev/null 2>&1 || fail "required command is unavailable: ${command}"
	done
	docker info >/dev/null 2>&1 || fail "Docker daemon is unavailable"
	mkdir -p /tmp/opencode
	if [ ! -d /tmp/opencode ] || [ -L /tmp/opencode ]; then
		fail "/tmp/opencode must be a real directory"
	fi
}

primary_snapshot() {
	local output="$1"
	{
		printf 'branch=%s\n' "$(git symbolic-ref --quiet --short HEAD || printf DETACHED)"
		printf 'head=%s\n' "$(git rev-parse HEAD)"
		printf '%s\n' 'status<<EOF'
		git status --porcelain=v1 --untracked-files=all
		printf '%s\n' 'EOF'
		git ls-files -s
		git ls-files -co --exclude-standard -z |
			while IFS= read -r -d '' path; do
				case "${path}" in .env | .devcontainer/.env | .env.d/*) continue ;; esac
				[ -f "${path}" ] && printf '%s  %s\n' "$(sha256sum "${path}" | cut -d' ' -f1)" "${path}"
			done
	} >"${output}"
}

cleanup() {
	local status=$?
	local -a owned_volumes=()
	trap - EXIT INT TERM
	if [ -n "${CANDIDATE}" ] && [ -d "${CANDIDATE}" ] && [ -n "${PROJECT}" ]; then
		mapfile -t owned_volumes < <(docker volume ls -q --filter "label=com.docker.compose.project=${PROJECT}")
		(
			cd "${CANDIDATE}"
			docker compose --project-name "${PROJECT}" --project-directory "$PWD" \
				-f .devcontainer/docker-compose.yml down --volumes --remove-orphans --rmi local >/dev/null 2>&1 || true
		)
		if [ "${#owned_volumes[@]}" -gt 0 ]; then
			docker volume rm "${owned_volumes[@]}" >/dev/null 2>&1 || true
		fi
		if docker ps -aq --filter "label=com.docker.compose.project=${PROJECT}" | grep -q . ||
			docker network ls -q --filter "label=com.docker.compose.project=${PROJECT}" | grep -q . ||
			docker volume ls -q --filter "label=com.docker.compose.project=${PROJECT}" | grep -q .; then
			printf '[pi-lifecycle:error] run-owned Docker resources remain for project %s\n' "${PROJECT}" >&2
			CLEANUP_FAILED=1
		else
			printf '[pi-lifecycle] cleanup verified: no run-owned Compose resources remain\n'
		fi
		rm -rf "${RUN_ROOT}"
	fi
	[ "${CLEANUP_FAILED}" -eq 0 ] || status=1
	exit "${status}"
}

candidate_snapshot() {
	local output="$1"
	python3 "${HARNESS_DIR}/tracked-path-snapshot.py" capture \
		"${PRIVATE_DIR}/candidate.manifest" "${CANDIDATE}" "${output}"
}

allocate_port() {
	python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
}

configure_candidate() {
	local compose="${CANDIDATE}/.devcontainer/docker-compose.yml"
	local devcontainer="${CANDIDATE}/.devcontainer/devcontainer.json"
	python3 - "${compose}" "${PROJECT}" "${SSH_PORT}" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
if not text.startswith("services:\n"):
    raise SystemExit("unexpected Compose structure")
needle = '      # - "2222:22" # SSH (open to LAN at your own risk)'
if needle not in text:
    raise SystemExit("SSH port marker not found")
text = f'name: "{sys.argv[2]}"\n' + text
text = text.replace(needle, f'      - "127.0.0.1:{sys.argv[3]}:22" # harness-only SSH')
path.write_text(text)
PY
	# Agent forwarding is unrelated to this proof and may refer to an unavailable host socket.
	python3 - "${devcontainer}" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
needle = '        "source=${localEnv:SSH_AUTH_SOCK},target=/ssh-agent,type=bind"'
text = text.replace(',\n' + needle, '')
path.write_text(text)
PY
	printf 'APP_NAME=%s\nAPP_PORT=%s\n' "${PROJECT}" "$(allocate_port)" >"${CANDIDATE}/.devcontainer/.env"
	printf 'APP_NAME=%s\nAPP_PORT=%s\nSSH_AUTHORIZED_KEYS="%s"\n' \
		"${PROJECT}" "$(allocate_port)" "$(<"${PRIVATE_DIR}/client_key.pub")" >"${CANDIDATE}/.env"
	chmod 0600 "${CANDIDATE}/.env" "${PRIVATE_DIR}"/*
}

compose() {
	(
		cd "${CANDIDATE}"
		docker compose --project-name "${PROJECT}" --project-directory "$PWD" -f .devcontainer/docker-compose.yml "$@"
	)
}

service_container() {
	local id
	id="$(compose ps -q "${SERVICE}")"
	[ -n "${id}" ] || fail "Compose did not resolve a container for service ${SERVICE} in project ${PROJECT}"
	[ "$(printf '%s\n' "${id}" | wc -l)" -eq 1 ] || fail "Compose resolved multiple service containers"
	printf '%s\n' "${id}"
}

container_exec() {
	docker exec "$(service_container)" bash -lc "$1"
}

capture_versions() {
	local output="$1"
	# shellcheck disable=SC2016 # Container-side HOME and variables must expand remotely.
	if ! container_exec 'installer="$HOME/'"${PROJECT}"'/.devcontainer/install/available/30-ai-pi-gentle.sh"; policy="$($installer --print-version-policy)"; while IFS="=" read -r key version; do case "$key" in GENTLE_PI_VERSION) package=gentle-pi;; PI_SUBAGENTS_VERSION) package=pi-subagents;; PI_INTERCOM_VERSION) package=pi-intercom;; PI_WEB_ACCESS_VERSION) package=pi-web-access;; PI_LENS_VERSION) package=pi-lens;; RPIV_TODO_VERSION) package=@juicesharp/rpiv-todo;; RPIV_ASK_USER_QUESTION_VERSION) package=@juicesharp/rpiv-ask-user-question;; RPIV_BTW_VERSION) package=@juicesharp/rpiv-btw;; GENTLE_ENGRAM_VERSION) package=gentle-engram;; PI_MCP_ADAPTER_VERSION) package=pi-mcp-adapter;; PI_TERMINAL_THEME_VERSION) package=pi-terminal-theme;; *) exit 91;; esac; actual="$($installer --print-package-metadata "npm:${package}@${version}" | sed -n "s/^INSTALLED_VERSION=//p")"; printf "%s=%s observed=%s\n" "$package" "$version" "$actual"; [ "$version" = "$actual" ] || exit 92; done <<<"$policy"' >"${output}"; then
		tail -n 12 "${output}" >&2 || true
		fail "declared/observed Pi version verification failed"
	fi
}

capture_persisted_ssh_identity() {
	local fingerprints="$1"
	local hashes="$2"
	container_exec 'for algorithm in rsa ed25519; do key="$HOME/.ssh-server/ssh/ssh_host_${algorithm}_key"; [ -f "$key" ] && [ ! -L "$key" ] && [ -r "$key" ] || exit 93; fingerprint="$(ssh-keygen -yf "$key" | ssh-keygen -E sha256 -lf - | cut -d" " -f2)"; printf "ssh-%s %s\n" "$algorithm" "$fingerprint"; done' |
		sort >"${fingerprints}"
	container_exec 'sha256sum "$HOME/.ssh-server/ssh/ssh_host_rsa_key" "$HOME/.ssh-server/ssh/ssh_host_ed25519_key"' |
		awk '{ print $1, $2 }' >"${hashes}"
	chmod 0600 "${fingerprints}" "${hashes}"
}

rebuild() {
	local log="$1"
	(
		cd "${CANDIDATE}"
		FORCE_HOST_CONTEXT=1 task container:rebuild
	) >"${log}" 2>&1 || {
		grep -E '^([[:space:]]*×|\[.*(error|ERROR)|Error:|error:)' "${log}" | tail -n 20 >&2 || true
		fail "rebuild failed; private log: ${log} (removed during cleanup)"
	}
}

require_safe_context
RUN_ROOT="$(mktemp -d /tmp/opencode/pi-gentle-lifecycle.XXXXXXXX)"
case "${RUN_ROOT}" in /tmp/opencode/pi-gentle-lifecycle.*) ;; *) fail "unsafe temporary path" ;; esac
PRIVATE_DIR="${RUN_ROOT}/private"
mkdir -m 0700 "${PRIVATE_DIR}"
trap cleanup EXIT INT TERM

primary_snapshot "${PRIVATE_DIR}/primary.before"
git ls-files --stage -z >"${PRIVATE_DIR}/candidate.manifest"
PROJECT="pi-gentle-$(date +%s)-$$"
PROJECT="$(printf '%s' "${PROJECT}" | tr '[:upper:]_' '[:lower:]-' | tr -cd 'a-z0-9-')"
CANDIDATE="${RUN_ROOT}/${PROJECT}"
SSH_PORT="$(allocate_port)"

note "creating Git-backed candidate in isolated run ${RUN_ROOT##*/}"
bash "${HARNESS_DIR}/create-candidate.sh" "${ROOT}" "${CANDIDATE}"
ssh-keygen -q -t ed25519 -N '' -f "${PRIVATE_DIR}/client_key"
configure_candidate
candidate_snapshot "${PRIVATE_DIR}/candidate.configured"

note "running first rebuild"
rebuild "${PRIVATE_DIR}/rebuild-1.log"
capture_versions "${PRIVATE_DIR}/versions-1"
# shellcheck disable=SC2016 # Container-side HOME must expand remotely.
container_exec 'mkdir -p "$HOME/.pi" "$HOME/.gentle-ai"; printf pi-state >"$HOME/.pi/idempotency-marker"; printf gentle-state >"$HOME/.gentle-ai/idempotency-marker"; start-sshd >/dev/null'
compose port "${SERVICE}" 22 | grep -Fxq "127.0.0.1:${SSH_PORT}" || fail "SSH is not published strictly on the selected loopback port"
if ! bash "${HARNESS_DIR}/capture-ssh-hostkey-fingerprints.sh" \
	127.0.0.1 "${SSH_PORT}" "${PRIVATE_DIR}/hostkey-fingerprints-1"; then
	fail "could not capture exactly one RSA and ED25519 SSH host-key fingerprint"
fi
capture_persisted_ssh_identity "${PRIVATE_DIR}/persisted-hostkey-fingerprints-1" "${PRIVATE_DIR}/persisted-hostkey-hashes-1"
cmp -s "${PRIVATE_DIR}/persisted-hostkey-fingerprints-1" "${PRIVATE_DIR}/hostkey-fingerprints-1" || fail "served SSH identity does not match persistent host-key files after first rebuild"
ssh -i "${PRIVATE_DIR}/client_key" -p "${SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=no \
	-o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 ubuntu@127.0.0.1 'printf ssh-ok' 2>/dev/null |
	grep -Fxq ssh-ok || fail "loopback public-key SSH access failed"

note "running second rebuild"
rebuild "${PRIVATE_DIR}/rebuild-2.log"
capture_versions "${PRIVATE_DIR}/versions-2"
mutation_count="$(grep -Ec 'Installing Pi package:|Replacing Pi package |Removing incompatible legacy Pi package:|(^|[[:space:]])pi (install|remove|update)([[:space:]]|$)' "${PRIVATE_DIR}/rebuild-2.log" || true)"
[ "${mutation_count}" -eq 0 ] || fail "second rebuild performed ${mutation_count} Pi package mutation action(s)"
# shellcheck disable=SC2016 # Container-side HOME must expand remotely.
container_exec '[ "$(cat "$HOME/.pi/idempotency-marker")" = pi-state ] && [ "$(cat "$HOME/.gentle-ai/idempotency-marker")" = gentle-state ] && start-sshd >/dev/null'
if ! bash "${HARNESS_DIR}/capture-ssh-hostkey-fingerprints.sh" \
	127.0.0.1 "${SSH_PORT}" "${PRIVATE_DIR}/hostkey-fingerprints-2"; then
	fail "could not capture exactly one RSA and ED25519 SSH host-key fingerprint"
fi
capture_persisted_ssh_identity "${PRIVATE_DIR}/persisted-hostkey-fingerprints-2" "${PRIVATE_DIR}/persisted-hostkey-hashes-2"
cmp -s "${PRIVATE_DIR}/persisted-hostkey-fingerprints-2" "${PRIVATE_DIR}/hostkey-fingerprints-2" || fail "served SSH identity does not match persistent host-key files after second rebuild"
cmp -s "${PRIVATE_DIR}/hostkey-fingerprints-1" "${PRIVATE_DIR}/hostkey-fingerprints-2" || fail "SSH host-key fingerprints changed across rebuilds"
cmp -s "${PRIVATE_DIR}/persisted-hostkey-hashes-1" "${PRIVATE_DIR}/persisted-hostkey-hashes-2" || fail "persistent SSH private host-key files changed across rebuilds"
cmp -s "${PRIVATE_DIR}/versions-1" "${PRIVATE_DIR}/versions-2" || fail "declared or observed Pi versions changed across rebuilds"
candidate_snapshot "${PRIVATE_DIR}/candidate.after"
python3 "${HARNESS_DIR}/tracked-path-snapshot.py" compare \
	"${PRIVATE_DIR}/candidate.configured" "${PRIVATE_DIR}/candidate.after" ||
	fail "candidate tracked source changed beyond harness configuration"

primary_snapshot "${PRIVATE_DIR}/primary.after"
cmp -s "${PRIVATE_DIR}/primary.before" "${PRIVATE_DIR}/primary.after" || fail "primary branch, HEAD, status, hashes, or modes changed"

note "declared and observed Pi package versions"
cat "${PRIVATE_DIR}/versions-2"
note "second rebuild Pi mutation actions: ${mutation_count}"
note "state markers persisted: .pi and .gentle-ai"
note "SSH host fingerprints persisted: $(sha256sum "${PRIVATE_DIR}/hostkey-fingerprints-2" | cut -c1-16)"
note "SSH exposure verified: 127.0.0.1:${SSH_PORT} only"
note "primary branch, HEAD, status, hashes, and modes preserved"
note "candidate policy and source files remained unchanged"
