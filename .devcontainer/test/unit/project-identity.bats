#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
IDENTITY="${REPO_ROOT}/.taskfiles/scripts/project-identity.sh"

@test "project identity maps normalized names to aligned three-port blocks" {
	run bash "${IDENTITY}" "César-Fernando" --output name
	[ "${status}" -eq 0 ]
	[ "${output}" = "cesar-fernando" ]

	port="$(bash "${IDENTITY}" "César-Fernando" --output code)"
	[ "${port}" -eq 43774 ]
	[ "${port}" -ge 10000 ]
	[ "$((port + 2))" -le 59999 ]
	[ "$(((port - 10000) % 3))" -eq 0 ]
	[ "${port}" = "$(bash "${IDENTITY}" "cesar-fernando" --output code)" ]
}

@test "generated blocks stay aligned and wholly inside the inclusive range" {
	for index in $(seq 1 100); do
		port="$(bash "${IDENTITY}" "project-${index}" --output code)"
		[ "${port}" -ge 10000 ]
		[ "$((port + 2))" -le 59999 ]
		[ "$(((port - 10000) % 3))" -eq 0 ]
	done
}

@test "project identity defaults to the current directory basename" {
	test_root="$(mktemp -d)"
	mkdir -p "${test_root}/My Project"

	cd "${test_root}/My Project"
	[ "$(bash "${IDENTITY}" --output code)" = "$(bash "${IDENTITY}" "My Project" --output code)" ]

	rm -rf "${test_root}"
}

@test "identity env regeneration replaces generated ports and preserves unrelated content" {
	test_root="$(mktemp -d)/Identity Fixture"
	mkdir -p "${test_root}/.taskfiles/scripts" "${test_root}/.devcontainer"
	cp "${REPO_ROOT}/.taskfiles/devcontainer.yml" "${test_root}/.taskfiles/devcontainer.yml"
	cp "${IDENTITY}" "${test_root}/.taskfiles/scripts/project-identity.sh"
	cat >"${test_root}/Taskfile.yml" <<'EOF'
version: "3"
includes:
  container:
    taskfile: ./.taskfiles/devcontainer.yml
tasks:
  regenerate:
    cmds:
      - task: container:ensure-identity-env
EOF
	printf 'KEEP_ME=yes\nAPP_PORT=1\nOPENCODE_PORT=2\nSSH_PORT=3\nAPP_PORT=4\n' >"${test_root}/.env"
	printf 'OTHER=value\nSSH_PORT=9\n' >"${test_root}/.devcontainer/.env"

	cd "${test_root}"
	run task regenerate
	[ "${status}" -eq 0 ]
	app_port="$(bash .taskfiles/scripts/project-identity.sh --output code)"
	expected="APP_NAME=identity-fixture
APP_PORT=${app_port}
OPENCODE_PORT=$((app_port + 1))
SSH_PORT=$((app_port + 2))"
	[ "$(grep -E '^(APP_NAME|APP_PORT|OPENCODE_PORT|SSH_PORT)=' .env)" = "${expected}" ]
	[ "$(grep -E '^(APP_NAME|APP_PORT|OPENCODE_PORT|SSH_PORT)=' .devcontainer/.env)" = "${expected}" ]
	grep -Fxq 'KEEP_ME=yes' .env
	grep -Fxq 'OTHER=value' .devcontainer/.env
	cp .env before
	task regenerate
	cmp -s before .env

	rm -rf "${test_root%/Identity Fixture}"
}

@test "compose publishes generated host ports to canonical container ports" {
	compose="$(<"${REPO_ROOT}/.devcontainer/docker-compose.yml")"

	[[ "${compose}" == *'"${APP_PORT}:${APP_PORT}"'* ]]
	[[ "${compose}" == *'"127.0.0.1:${OPENCODE_PORT}:4096"'* ]]
	[[ "${compose}" == *'"127.0.0.1:${SSH_PORT}:22"'* ]]
	[[ "${compose}" != *'OPENCODE_SERVER_PORT'* ]]
}

@test "SSH guidance uses the generated loopback host port without fixed legacy values" {
	installer="$(<"${REPO_ROOT}/.devcontainer/install/available/20-tool-ssh.sh")"
	help="$(<"${REPO_ROOT}/.taskfiles/ssh.yml")"

	[[ "${installer}" == *'ssh -p <SSH_PORT from .env> ubuntu@127.0.0.1'* ]]
	[[ "${help}" == *'ssh -p <SSH_PORT from .env> ubuntu@127.0.0.1'* ]]
	[[ "${installer}${help}" != *'2222'* ]]
	[[ "${installer}${help}" != *'<host-ip>'* ]]
}
