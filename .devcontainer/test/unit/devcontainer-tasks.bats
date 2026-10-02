#!/usr/bin/env bats
#
# devcontainer-tasks.bats — unit tests for public devcontainer task entrypoints
#
# Run from the repo root:
#   bats .devcontainer/test/unit/devcontainer-tasks.bats

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"

@test "container:opencode continues the direct TUI in the default devcontainer workspace" {
	cd "${REPO_ROOT}"

	run task --dry container:opencode

	[ "${status}" -eq 0 ]

	task_definition="$(awk '/^  opencode:$/{capture=1} capture && /^  [[:alnum:]:-]+:/ && !/^  opencode:$/{exit} capture' .taskfiles/devcontainer.yml)"
	[[ "${task_definition}" == *"interactive: true"* ]]
	[[ "${task_definition}" == *'    cmds:
      - task: ensure-running
      - task: run-devcontainer
        vars:
          ARGS: exec --workspace-folder {{.WORKSPACE}} opencode --continue' ]]
}

@test "container:opencode:server supervises OpenCode in the default devcontainer workspace" {
	cd "${REPO_ROOT}"

	run task --dry container:opencode:server

	[ "${status}" -eq 0 ]

	task_definition="$(awk '/^  opencode:server:$/{capture=1} capture && /^  [[:alnum:]:-]+:/ && !/^  opencode:server:$/{exit} capture' .taskfiles/devcontainer.yml)"
	[[ "${task_definition}" == *"interactive: true"* ]]
	[[ "${task_definition}" == *'    cmds:
      - task: ensure-running
      - task: run-devcontainer
        vars:
          ARGS: exec --workspace-folder {{.WORKSPACE}} bash .taskfiles/scripts/opencode-server.sh' ]]
}

@test "OpenCode supervisor passes isolated mocked lifecycle contracts" {
	run python3 "${REPO_ROOT}/.devcontainer/test/unit/opencode-server-test.py"
	printf '%s\n' "${output}"
	[ "${status}" -eq 0 ]
}

@test "container:up prepares managed bind sources after the host guard and before startup" {
	cd "${REPO_ROOT}"
	task_definition="$(awk '/^  up:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  up:/{exit} capture' .taskfiles/devcontainer.yml)"
	guard_line="$(grep -nF 'if [ -f /.dockerenv ]' <<<"${task_definition}" | cut -d: -f1)"
	prepare_line="$(grep -nF 'bash .taskfiles/scripts/prepare-bind-mounts.sh' <<<"${task_definition}" | cut -d: -f1)"
	up_line="$(grep -nF 'devcontainer up --workspace-folder' <<<"${task_definition}" | cut -d: -f1)"

	[ -n "${guard_line}" ]
	[ "${guard_line}" -lt "${prepare_line}" ]
	[ "${prepare_line}" -lt "${up_line}" ]
	env_line="$(grep -nF '. .devcontainer/.env' <<<"${task_definition}" | cut -d: -f1)"
	[ "${env_line}" -lt "${prepare_line}" ]
	[[ "${task_definition}" == *'export GENTLE_VOLUME_MANIFEST_ID'* ]]
}

@test "host UID generation is guarded and running containers do not bypass preparation" {
	definition="$(awk '/^  ensure-identity-env:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  ensure-identity-env:/{exit} capture' "${REPO_ROOT}/.taskfiles/devcontainer.yml")"
	guard="$(grep -nF 'if [ -f /.dockerenv ]' <<<"${definition}" | cut -d: -f1)"
	uid="$(grep -nF 'host_uid="$(id -u)"' <<<"${definition}" | cut -d: -f1)"
	[ "${guard}" -lt "${uid}" ]
	[[ "${definition}" != *'HOST_GID'* ]]
	definition="$(awk '/^  ensure-running:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  ensure-running:/{exit} capture' "${REPO_ROOT}/.taskfiles/devcontainer.yml")"
	prepare="$(grep -nF 'prepare-bind-mounts.sh' <<<"${definition}" | cut -d: -f1)"
	running="$(grep -nF 'if docker ps' <<<"${definition}" | cut -d: -f1)"
	[ "${prepare}" -lt "${running}" ]
}

@test "build and up regenerate locale settings before sourcing generated env" {
	for operation in build up; do
		definition="$(awk -v task="${operation}:" '$0 == "  " task {capture=1} capture && /^  [[:alnum:]-]+:/ && $0 != "  " task {exit} capture' "${REPO_ROOT}/.taskfiles/devcontainer.yml")"
		[[ "${definition}" == *'- task: ensure-identity-env'* ]]
		[[ "${definition}" == *'. .devcontainer/.env'* ]]
	done
	definition="$(awk '/^  ensure-identity-env:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  ensure-identity-env:/{exit} capture' "${REPO_ROOT}/.taskfiles/devcontainer.yml")"
	[[ "${definition}" == *'locale-env.py .env LOCALE'* ]]
	[[ "${definition}" == *'locale-env.py .env TZ'* ]]
}

@test "container:rebuild runs remove and build without startup" {
	cd "${REPO_ROOT}"
	task_definition="$(awk '/^  rebuild:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  rebuild:/{exit} capture' .taskfiles/devcontainer.yml)"
	rm_line="$(grep -nF 'task container:rm' <<<"${task_definition}" | cut -d: -f1)"
	build_line="$(grep -nF 'task container:build' <<<"${task_definition}" | cut -d: -f1)"
	up_line="$(grep -nF 'task container:up' <<<"${task_definition}" | cut -d: -f1)"

	[ -n "${rm_line}" ]
	[ "${rm_line}" -lt "${build_line}" ]
	[ -z "${up_line}" ]
}

# Execute the actual task shell body with fail-closed command doubles. No daemon
# or nested Task invocation is reachable, including on a regression to old code.
run_lifecycle() {
	local operation="$1"
	local body
	body="$(awk -v task="${operation}:" '$0 == "  " task {capture=1; next} capture && /^  [[:alnum:]-]+:/ {exit} capture && /^      - \|/ {body=1; next} body {sub(/^        /, ""); print}' "${REPO_ROOT}/.taskfiles/devcontainer.yml")"
	run env FORCE_HOST_CONTEXT="${HOST_CONTEXT:-1}" bash -c '
task() {
  printf "task %s\n" "$*" >> "$BATS_TEST_TMPDIR/calls"
  if [[ "$*" == *resolve-container-name ]]; then
    [[ "${FAIL_STEP:-}" != resolve ]] || return 17
    printf "fixture-container\n"
  else
    [[ "$*" != "${FAIL_STEP:-}" ]] || return 18
  fi
}
docker() {
  printf "docker %s\n" "$*" >> "$BATS_TEST_TMPDIR/calls"
  case "$1" in
    ps)
      [[ "${FAIL_STEP:-}" != lookup ]] || return 19
      [[ "$*" == *--all* && "$*" == *"name=^/fixture-container$"* ]] || return 20
      [[ "${CONTAINER_STATE:-running}" == missing ]] || printf "same-container-id\n"
      ;;
    restart|rm)
      [[ "${*: -1}" == same-container-id ]] || return 21
      [[ "${FAIL_STEP:-}" != "$1" ]] || return 22
      ;;
    *) return 23 ;;
  esac
}
devcontainer() { return 24; }
eval "$1"
' _ "${body}"
}

@test "container:restart preserves running and stopped container identity" {
	for state in running stopped; do
		export CONTAINER_STATE="${state}"
		run_lifecycle restart
		[ "${status}" -eq 0 ]
		[ "$(<"${BATS_TEST_TMPDIR}/calls")" = 'task --silent container:resolve-container-name
docker ps --all --filter name=^/fixture-container$ --quiet
docker restart same-container-id' ]
		rm "${BATS_TEST_TMPDIR}/calls"
	done
}

@test "container:restart missing container fails with up guidance" {
	export CONTAINER_STATE=missing
	run_lifecycle restart
	[ "${status}" -ne 0 ]
	[[ "${output}" == *'container:up'* ]]
	[[ "$(<"${BATS_TEST_TMPDIR}/calls")" != *'docker restart'* ]]
}

@test "container:rm permits absence but propagates lookup and removal errors" {
	for step in none lookup rm; do
		export FAIL_STEP="${step}"
		run_lifecycle rm
		if [ "${step}" = none ]; then
			[ "${status}" -eq 0 ]
			[[ "$(<"${BATS_TEST_TMPDIR}/calls")" == *'docker rm -f same-container-id' ]]
		else
			[ "${status}" -ne 0 ]
		fi
		rm "${BATS_TEST_TMPDIR}/calls"
	done
	export FAIL_STEP=none CONTAINER_STATE=missing
	run_lifecycle rm
	[ "${status}" -eq 0 ]
	[[ "$(<"${BATS_TEST_TMPDIR}/calls")" != *'docker rm'* ]]
}

@test "container:restart propagates resolution lookup and restart failures" {
	for step in resolve lookup restart; do
		export FAIL_STEP="${step}"
		run_lifecycle restart
		[ "${status}" -ne 0 ]
		[[ "${output}" != *'container:up'* ]]
		if [ "${step}" != restart ]; then
			[[ "$(<"${BATS_TEST_TMPDIR}/calls")" != *'docker restart'* ]]
		fi
		rm "${BATS_TEST_TMPDIR}/calls"
	done
}

@test "container:recreate and container:rebuild sequence and stop on failure" {
	for operation in recreate rebuild; do
		next=up
		[ "${operation}" != rebuild ] || next=build
		for failure in none container:rm "container:${next}"; do
			export FAIL_STEP="${failure}"
			run_lifecycle "${operation}"
			expected='task container:rm'
			[ "${failure}" = container:rm ] || expected+=$'\n'"task container:${next}"
			[ "$(<"${BATS_TEST_TMPDIR}/calls")" = "${expected}" ]
			if [ "${failure}" = none ]; then
				[ "${status}" -eq 0 ]
			else
				[ "${status}" -ne 0 ]
			fi
			rm "${BATS_TEST_TMPDIR}/calls"
		done
	done
}

@test "container:restart recreate rebuild host guards prevent all effects" {
	[ -f /.dockerenv ] || skip "requires container host marker"
	export HOST_CONTEXT=0
	for operation in restart recreate rebuild; do
		run_lifecycle "${operation}"
		[ "${status}" -eq 0 ]
		[[ "${output}" == *'[skip]'* ]]
		[ ! -e "${BATS_TEST_TMPDIR}/calls" ]
	done
}

@test "container:rebuild host guard precedes all lifecycle calls" {
	cd "${REPO_ROOT}"
	task_definition="$(awk '/^  rebuild:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  rebuild:/{exit} capture' .taskfiles/devcontainer.yml)"
	guard_line="$(grep -nF 'if [ -f /.dockerenv ]' <<<"${task_definition}" | cut -d: -f1)"
	rm_line="$(grep -nF 'task container:rm' <<<"${task_definition}" | cut -d: -f1)"

	[ -n "${guard_line}" ]
	[ "${guard_line}" -lt "${rm_line}" ]
}

@test "Dockerfile isolates core inputs in the foundation cache boundary" {
	cd "${REPO_ROOT}"
	foundation="$(awk '/^FROM \$\{IMAGE\} AS foundation$/{capture=1; next} capture && /^FROM /{exit} capture' .devcontainer/Dockerfile)"
	mapfile -t copy_directives < <(awk '$1 == "COPY" || $1 == "ADD" {$1=$1; print}' <<<"${foundation}")

	[ "${#copy_directives[@]}" -eq 2 ]
	[ "${copy_directives[0]}" = "COPY install/01-foundation/ ./.devcontainer-install/01-foundation/" ]
	[ "${copy_directives[1]}" = "COPY install/lib/common.sh install/lib/run-installers.sh ./.devcontainer-install/lib/" ]
}

@test "Dockerfile routes every installer group through the fail-fast runner" {
	cd "${REPO_ROOT}"
	dockerfile="$(<.devcontainer/Dockerfile)"

	[ "$(grep -c '&& ./.devcontainer-install/lib/run-installers.sh' <<<"${dockerfile}")" -eq 4 ]
	[[ "${dockerfile}" != *'| sort | while'* ]]
}

@test "Dockerfile installs tool-specific inputs only downstream of foundation" {
	cd "${REPO_ROOT}"
	downstream="$(awk '/^FROM foundation AS core-tools$/{capture=1} capture' .devcontainer/Dockerfile)"

	[[ "${downstream}" == *"ARG ENGRAM_VERSION="* ]]
	[[ "${downstream}" == *"COPY tool-versions.conf"* ]]
	[[ "${downstream}" == *"COPY install/available/"* ]]
	[[ "${downstream}" == *"COPY install/02-core-tools/"* ]]
	[[ "${downstream}" == *"COPY install/03-enabled/"* ]]
	[[ "${downstream}" == *"COPY install/04-hooks/"* ]]
}

@test "Dockerfile keeps the cheap version contract independent and synchronized" {
	cd "${REPO_ROOT}"
	contract="$(awk '/^FROM \$\{IMAGE\} AS devcontainer-version-contract$/{capture=1; next} capture && /^FROM /{exit} capture' .devcontainer/Dockerfile)"
	devcontainer="$(awk '/^FROM foundation AS core-tools$/{capture=1; next} capture' .devcontainer/Dockerfile)"
	contract_variables="$(awk '$1 == "ARG" || ($1 == "ENV" && $2 ~ /^(ENGRAM_VERSION|NODE_MAJOR|PLAYWRIGHT_VERSION)=/) {print}' <<<"${contract}")"
	devcontainer_variables="$(awk '$1 == "ARG" && $2 ~ /^(ENGRAM_VERSION|NODE_MAJOR|PLAYWRIGHT_VERSION)=/ || ($1 == "ENV" && $2 ~ /^(ENGRAM_VERSION|NODE_MAJOR|PLAYWRIGHT_VERSION)=/) {print}' <<<"${devcontainer}")"

	[ "$(sort <<<"${contract_variables}")" = "$(sort <<<"${devcontainer_variables}")" ]
	[[ "${contract}" != *"COPY "* ]]
	[[ "${contract}" != *"RUN "* ]]
}

@test "core cache inputs match canonical aliases and exclude project and optional inputs" {
	run python3 - "${REPO_ROOT}" <<'PY'
import re
import shlex
import sys
from pathlib import Path

root = Path(sys.argv[1])
context = root / ".devcontainer"
dockerfile = (context / "Dockerfile").read_text()
core = dockerfile.split("FROM foundation AS core-tools\n", 1)[1].split("\nFROM ", 1)[0]
final = dockerfile.split("FROM core-tools AS devcontainer\n", 1)[1]
foundation = dockerfile.split("AS foundation\n", 1)[1].split("\nFROM ", 1)[0]
assert "APP_NAME" not in foundation + core
assert "PLAYWRIGHT_VERSION" not in foundation + core
assert "ARG APP_NAME=" in final and "ARG PLAYWRIGHT_VERSION=" in final
assert "install/03-enabled" not in core and "install/04-hooks" not in core
copies = [shlex.split(line)[1:-1] for line in core.splitlines() if line.startswith("COPY ")]
sources = {source for instruction in copies for source in instruction}
assert "install/available/" not in sources
aliases = list((context / "install/02-core-tools").glob("*.sh"))
assert all(alias.is_symlink() and alias.is_file() for alias in aliases)
targets = {str(alias.resolve().relative_to(context)) for alias in aliases}
assert len(targets) == len(aliases), "duplicate canonical core installer"
assert targets == {source for source in sources if source.startswith("install/available/")}
assert "tool-versions.conf" in sources and "install/02-core-tools/" in sources
helpers = {"install/lib/common.sh", "install/lib/run-installers.sh"}
helpers |= {source for source in sources if source.startswith("install/lib/")}
for source in targets | helpers:
    assert (context / source).is_file(), source
    for helper in re.findall(r'\$\{SCRIPT_DIR\}/\.\./lib/([^"\s]+)', (context / source).read_text()):
        assert "install/lib/" + helper in helpers, helper
assert core.index("COPY install/02-core-tools/") < core.index("RUN ")
assert final.index("COPY install/03-enabled/") < final.index("run-installers.sh ./.devcontainer-install/03-enabled")
PY
	[ "${status}" -eq 0 ]
}
