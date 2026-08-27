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
