#!/usr/bin/env bats
#
# devcontainer-tasks.bats — unit tests for public devcontainer task entrypoints
#
# Run from the repo root:
#   bats .devcontainer/test/unit/devcontainer-tasks.bats

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"

@test "container:opencode continues OpenCode in the default devcontainer workspace" {
	cd "${REPO_ROOT}"

	run task --dry container:opencode

	[ "${status}" -eq 0 ]

	task_definition="$(awk '/^  opencode:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  opencode:/{exit} capture' .taskfiles/devcontainer.yml)"
	[[ "${task_definition}" == *"interactive: true"* ]]
	[[ "${task_definition}" == *"- task: ensure-running"* ]]
	[[ "${task_definition}" == *"- task: run-devcontainer"* ]]
	[[ "${task_definition}" == *"ARGS: exec --workspace-folder {{.WORKSPACE}} opencode -c"* ]]
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
}

@test "container:rebuild runs remove build and up in exact order" {
	cd "${REPO_ROOT}"
	task_definition="$(awk '/^  rebuild:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  rebuild:/{exit} capture' .taskfiles/devcontainer.yml)"
	rm_line="$(grep -nF 'task container:rm' <<<"${task_definition}" | cut -d: -f1)"
	build_line="$(grep -nF 'task container:build' <<<"${task_definition}" | cut -d: -f1)"
	up_line="$(grep -nF 'task container:up' <<<"${task_definition}" | cut -d: -f1)"

	[ -n "${rm_line}" ]
	[ "${rm_line}" -lt "${build_line}" ]
	[ "${build_line}" -lt "${up_line}" ]
}

@test "container:rebuild host guard precedes all lifecycle calls" {
	cd "${REPO_ROOT}"
	task_definition="$(awk '/^  rebuild:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  rebuild:/{exit} capture' .taskfiles/devcontainer.yml)"
	guard_line="$(grep -nF 'if [ -f /.dockerenv ]' <<<"${task_definition}" | cut -d: -f1)"
	rm_line="$(grep -nF 'task container:rm' <<<"${task_definition}" | cut -d: -f1)"

	[ -n "${guard_line}" ]
	[ "${guard_line}" -lt "${rm_line}" ]
}
