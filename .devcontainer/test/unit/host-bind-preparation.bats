#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	WORKSPACE="${TEST_ROOT}/workspace"
	mkdir -p "${WORKSPACE}/.devcontainer" "${WORKSPACE}/.taskfiles/scripts"
	cp "${REPO_ROOT}/.taskfiles/scripts/prepare-bind-mounts.sh" "${WORKSPACE}/.taskfiles/scripts/prepare-bind-mounts.sh" 2>/dev/null || true
	cp "${REPO_ROOT}/.taskfiles/scripts/prepare-bind-mounts.py" "${WORKSPACE}/.taskfiles/scripts/prepare-bind-mounts.py"
	cp "${REPO_ROOT}/.taskfiles/scripts/yq-compatibility.sh" "${WORKSPACE}/.taskfiles/scripts/yq-compatibility.sh"
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

write_compose() {
	cat >"${WORKSPACE}/.devcontainer/docker-compose.yml"
}

run_preparation() {
	run bash "${WORKSPACE}/.taskfiles/scripts/prepare-bind-mounts.sh" "${WORKSPACE}"
}

metadata() {
	stat -c '%u:%g:%a:%Y' -- "$1"
}

write_expected_managed_directories() {
	local compose_file="$1"
	local output_file="$2"
	local source relative

	while IFS= read -r source; do
		relative="${source#../}"
		while [[ "${relative}" == .env.d/* ]]; do
			printf '%s\n' "${relative}"
			relative="${relative%/*}"
		done
		printf '%s\n' '.env.d'
	done < <(
		yq -r '.services."container-svc".volumes[] | select(.type == "bind" and (.source | startswith("../.env.d/")) and .bind.create_host_path == false) | .source' "${compose_file}"
	) | sort -u >"${output_file}"
}

@test "empty managed root is derived from long-syntax Compose binds and preparation is idempotent" {
	write_compose <<'YAML'
services:
  container-svc:
    volumes:
      - type: bind
        source: ../.env.d/.pi
        target: /home/ubuntu/.pi
        bind:
          create_host_path: false
      - type: bind
        source: ../.env.d/.opencode/share
        target: /home/ubuntu/.local/share/opencode
        bind:
          create_host_path: false
YAML

	run_preparation
	[ "${status}" -eq 0 ]
	for path in .env.d .env.d/.pi .env.d/.opencode .env.d/.opencode/share; do
		[ "$(stat -c '%u:%g:%a' -- "${WORKSPACE}/${path}")" = "$(id -u):$(id -g):755" ]
	done
	[ "$(find "${WORKSPACE}" -mindepth 1 -printf '%P\n' | sort)" = $'.devcontainer\n.devcontainer/docker-compose.yml\n.env.d\n.env.d/.opencode\n.env.d/.opencode/share\n.env.d/.pi\n.taskfiles\n.taskfiles/scripts\n.taskfiles/scripts/prepare-bind-mounts.py\n.taskfiles/scripts/prepare-bind-mounts.sh\n.taskfiles/scripts/yq-compatibility.sh' ]
	before="$(metadata "${WORKSPACE}/.env.d")|$(metadata "${WORKSPACE}/.env.d/.opencode/share")"
	sleep 1
	run_preparation
	[ "${status}" -eq 0 ]
	[ "$(metadata "${WORKSPACE}/.env.d")|$(metadata "${WORKSPACE}/.env.d/.opencode/share")" = "${before}" ]
}

@test "new managed directories are exactly 0755 under a restrictive umask" {
	write_compose <<'YAML'
services:
  container-svc:
    volumes:
      - {type: bind, source: ../.env.d/.opencode/share, target: /state, bind: {create_host_path: false}}
YAML
	mkdir -p "${WORKSPACE}/.env.d"
	chmod 0711 "${WORKSPACE}/.env.d"
	before="$(stat -c '%u:%g:%a' -- "${WORKSPACE}/.env.d")"

	run bash -c 'umask 077; exec bash "$1" "$2"' _ \
		"${WORKSPACE}/.taskfiles/scripts/prepare-bind-mounts.sh" "${WORKSPACE}"

	[ "${status}" -eq 0 ]
	[ "$(stat -c '%u:%g:%a' -- "${WORKSPACE}/.env.d")" = "${before}" ]
	for path in .env.d/.opencode .env.d/.opencode/share; do
		[ "$(stat -c '%u:%g:%a' -- "${WORKSPACE}/${path}")" = "$(id -u):$(id -g):755" ]
	done
}

@test "pre-populated managed state is not traversed or mutated" {
	write_compose <<'YAML'
services:
  container-svc:
    volumes:
      - {type: bind, source: ../.env.d/.pi, target: /home/ubuntu/.pi, bind: {create_host_path: false}}
      - {type: bind, source: ../.env.d/.engram, target: /home/ubuntu/.engram, bind: {create_host_path: false}}
      - {type: bind, source: ../.env.d/.gentle-ai, target: /home/ubuntu/.gentle-ai, bind: {create_host_path: false}}
      - {type: bind, source: ../.env.d/.opencode/share, target: /home/ubuntu/.local/share/opencode, bind: {create_host_path: false}}
      - {type: bind, source: ../.env.d/.gitconfig, target: /home/ubuntu/.gitconfig-volume, bind: {create_host_path: false}}
YAML
	mkdir -p "${WORKSPACE}/.env.d"/{.pi,.engram,.gentle-ai,.opencode/share,.gitconfig,unrelated}
	for path in .pi .engram .gentle-ai .opencode/share .gitconfig unrelated; do
		printf 'sentinel:%s\n' "${path}" >"${WORKSPACE}/.env.d/${path}/sentinel"
		chmod 0711 "${WORKSPACE}/.env.d/${path}"
		chmod 0600 "${WORKSPACE}/.env.d/${path}/sentinel"
	done
	before="$(find "${WORKSPACE}/.env.d" -printf '%P|%u|%g|%m|%T@\n' | sort)|$(sha256sum "${WORKSPACE}/.env.d"/*/sentinel "${WORKSPACE}/.env.d/.opencode/share/sentinel" | sort)"

	run_preparation
	[ "${status}" -eq 0 ]
	[ "$(find "${WORKSPACE}/.env.d" -printf '%P|%u|%g|%m|%T@\n' | sort)|$(sha256sum "${WORKSPACE}/.env.d"/*/sentinel "${WORKSPACE}/.env.d/.opencode/share/sentinel" | sort)" = "${before}" ]
}

@test "only contained normalized relative binds with fail-closed creation are managed" {
	write_compose <<'YAML'
services:
  container-svc:
    volumes:
      - {type: bind, source: ../nested/../.env.d/inside, target: /inside, bind: {create_host_path: false}}
      - {type: bind, source: ../../escape, target: /escape, bind: {create_host_path: false}}
      - {type: bind, source: /tmp/external, target: /absolute, bind: {create_host_path: false}}
      - {type: bind, source: "${STATE_PATH}", target: /variable, bind: {create_host_path: false}}
      - {type: bind, source: named-state, target: /named}
      - {type: bind, source: ../.env.d/docker-created, target: /unsafe, bind: {create_host_path: true}}
YAML

	run_preparation
	[ "${status}" -eq 0 ]
	[ -d "${WORKSPACE}/.env.d/inside" ]
	[ ! -e "${TEST_ROOT}/escape" ]
	[ ! -e "${WORKSPACE}/.env.d/docker-created" ]
	[[ "${output}" == *"externally managed"* ]]
}

@test "symlink and regular-file collisions fail without mutating either object" {
	write_compose <<'YAML'
services:
  container-svc:
    volumes:
      - {type: bind, source: ../.env.d/.opencode/share, target: /state, bind: {create_host_path: false}}
YAML
	mkdir -p "${WORKSPACE}/.env.d" "${TEST_ROOT}/target"
	printf 'protected\n' >"${TEST_ROOT}/target/sentinel"
	ln -s "${TEST_ROOT}/target" "${WORKSPACE}/.env.d/.opencode"
	run_preparation
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"${WORKSPACE}/.env.d/.opencode"* ]]
	[ "$(cat "${TEST_ROOT}/target/sentinel")" = protected ]

	rm "${WORKSPACE}/.env.d/.opencode"
	printf 'collision\n' >"${WORKSPACE}/.env.d/.opencode"
	run_preparation
	[ "${status}" -ne 0 ]
	[ "$(cat "${WORKSPACE}/.env.d/.opencode")" = collision ]
}

@test "wrong ownership fails with exact-path non-recursive remediation" {
	[ "$(id -u)" -ne 0 ] || skip "requires an unprivileged invoking user"
	write_compose <<'YAML'
services:
  container-svc:
    volumes:
      - {type: bind, source: ../.env.d/.pi, target: /state, bind: {create_host_path: false}}
YAML
	mkdir -p "${WORKSPACE}/.env.d/.pi"
	sudo chown 0:0 "${WORKSPACE}/.env.d/.pi"

	run_preparation
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"${WORKSPACE}/.env.d/.pi"* ]]
	[[ "${output}" == *"sudo chown $(id -u):$(id -g) '${WORKSPACE}/.env.d/.pi'"* ]]
	[[ "${output}" != *"chown -R"* ]]
}

@test "Compose managed binds fail closed and setup has no mount-root repair layer" {
	cp "${REPO_ROOT}/.devcontainer/docker-compose.yml" "${WORKSPACE}/.devcontainer/docker-compose.yml"
	write_expected_managed_directories \
		"${WORKSPACE}/.devcontainer/docker-compose.yml" \
		"${TEST_ROOT}/expected-managed-directories"

	run yq -e '[.services."container-svc".volumes[] | select(.type == "bind" and (.source | startswith("../.env.d/")) and .bind.create_host_path != false)] | length == 0' "${WORKSPACE}/.devcontainer/docker-compose.yml"
	[ "${status}" -eq 0 ]
	run_preparation
	[ "${status}" -eq 0 ]
	find "${WORKSPACE}/.env.d" -type d -printf '%P\n' |
		sed 's|^$|.env.d|; /^\.env\.d$/! s|^|.env.d/|' |
		sort >"${TEST_ROOT}/actual-managed-directories"
	cmp -s "${TEST_ROOT}/expected-managed-directories" "${TEST_ROOT}/actual-managed-directories"
	run grep -E 'prepare_user_owned_mount_roots|repair_exact_directory' "${REPO_ROOT}/.devcontainer/setup.sh"
	[ "${status}" -eq 1 ]
}

@test "preparation does not execute base64 or realpath from PATH" {
	write_compose <<'YAML'
services:
  container-svc:
    volumes:
      - {type: bind, source: ../.env.d/odd path, target: /state, bind: {create_host_path: false}}
YAML
	mkdir -p "${TEST_ROOT}/shims"
	for command in base64 realpath; do
		printf '#!/usr/bin/env bash\nexit 97\n' >"${TEST_ROOT}/shims/${command}"
		chmod +x "${TEST_ROOT}/shims/${command}"
	done

	run env PATH="${TEST_ROOT}/shims:${PATH}" bash \
		"${WORKSPACE}/.taskfiles/scripts/prepare-bind-mounts.sh" "${WORKSPACE}"

	[ "${status}" -eq 0 ]
	[ -d "${WORKSPACE}/.env.d/odd path" ]
}

@test "complete JSON parsing preserves safe whitespace and escaped path content" {
	write_compose <<'YAML'
services:
  container-svc:
    volumes:
      - type: bind
        source: "../.env.d/space and [brackets]"
        target: "/state with spaces"
        bind: {create_host_path: false}
      - type: bind
        source: "../.env.d/literal\\nsequence"
        target: /escaped
        bind: {create_host_path: false}
YAML

	run_preparation

	[ "${status}" -eq 0 ]
	[ -d "${WORKSPACE}/.env.d/space and [brackets]" ]
	[ -d "${WORKSPACE}/.env.d/literal\nsequence" ]
}

@test "relevant lifecycle has no executable base64 or realpath references" {
	run grep -E '(^|[[:space:]|;])(base64|realpath)([[:space:]]|$)' \
		"${REPO_ROOT}/.taskfiles/scripts/prepare-bind-mounts.sh" \
		"${REPO_ROOT}/.devcontainer/setup-volumes.sh"

	[ "${status}" -eq 1 ]
}
