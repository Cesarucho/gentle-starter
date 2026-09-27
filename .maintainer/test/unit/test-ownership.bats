#!/usr/bin/env bats

setup() {
	ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	FIXTURE="${BATS_TEST_TMPDIR}/consumer"
	mkdir -p "${FIXTURE}/.taskfiles"
	cp "${ROOT}/Taskfile.yml" "${FIXTURE}/Taskfile.yml"
	cp "${ROOT}/.taskfiles/"*.yml "${FIXTURE}/.taskfiles/"
}

@test "consumer taskfile has no maintainer dependencies or routes" {
	[ ! -e "${FIXTURE}/README.md" ]
	[ ! -e "${FIXTURE}/docs" ]
	[ ! -e "${FIXTURE}/.maintainer" ]
	run task --dir "${FIXTURE}" --list
	[ "${status}" -eq 0 ]
	[[ "${output}" != *'test:starter:'* ]]
	run task --exit-code --dir "${FIXTURE}" test
	[ "${status}" -eq 2 ]
	[[ "${output}" == *"Application tests are not configured"* ]]
	[[ "${output}" == *"tasks.test.cmds"* ]]
	[[ "$(<"${FIXTURE}/Taskfile.yml")" != *'taskfile: ./.maintainer/'* ]]
}

@test "maintainer routes are absent from consumer root" {
	local route
	for route in clean clean:identity project:init test:starter test:starter:unit test:starter:integration test:starter:lifecycle test:starter:clean; do
		run task --dry --dir "${FIXTURE}" "${route}"
		[ "${status}" -ne 0 ]
		[[ "${output}" == *"does not exist"* ]]
	done
}

@test "maintainer taskfile routes unit integration and lifecycle separately" {
	run task --taskfile "${ROOT}/.maintainer/Taskfile.yml" --dry test:starter
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'bats .devcontainer/test/unit/*.bats .maintainer/test/unit/*.bats'* ]]
	[[ "${output}" == *'bats .devcontainer/test/integration/tools.bats'* ]]
	[[ "${output}" != *'starter-lifecycle.py'* ]]
	[[ "${output}" != *'image-contract.bats'* ]]
	run task --taskfile "${ROOT}/.maintainer/Taskfile.yml" --dry test:starter:lifecycle -- --daemon-visible-scratch /workspace
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'.maintainer/test/lifecycle/starter-lifecycle.py --daemon-visible-scratch /workspace'* ]]
	run task --taskfile "${ROOT}/.maintainer/Taskfile.yml" --dry test:starter:clean
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'.maintainer/test/lifecycle/starter-test-clean.py'* ]]
	[[ "${output}" != *'--apply'* ]]
}

@test "application owner can replace only the root test command" {
	python3 - "${FIXTURE}/Taskfile.yml" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
start = source.index("  test:\n", source.index("\ntasks:\n"))
end = source.index("\n  help:\n", start)
path.write_text(source[:start] + '  test:\n    cmds:\n      - exit 17\n' + source[end:])
PY
	run task --exit-code --dir "${FIXTURE}" test
	[ "${status}" -eq 17 ]
	[[ "${output}" != *'bats'* ]]
}

@test "root validation does not invoke lifecycle or recovery" {
	cp -R "${ROOT}/.taskfiles/scripts" "${FIXTURE}/.taskfiles/"
	mkdir -p "${FIXTURE}/.devcontainer"
	run env DEVCONTAINER=true FORCE_HOST_CONTEXT=1 task --dry --dir "${FIXTURE}" validate
	[ "${status}" -eq 0 ]
	[[ "${output}" != *'shfmt'* ]]
	[[ "${output}" != *'starter-test-clean.py'* ]]
	[[ "${output}" != *'starter-lifecycle.py'* ]]
	run env DEVCONTAINER=true task --dry --dir "${FIXTURE}" validate
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'shfmt'* ]]
	[[ "${output}" == *'markdownlint-cli2'* ]]
}

@test "validation is the only public doctor and quality route" {
	run task --dir "${FIXTURE}" --list
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'validate'* ]]
	[[ "${output}" != *'* doctor:'* ]]
	[[ "${output}" != *'* quality:'* ]]
	[[ "${output}" != *'validate:full'* ]]
	local route
	for route in doctor doctor:auto doctor:host doctor:container quality:check quality:full quality:shellcheck validate:full; do
		run task --dry --dir "${FIXTURE}" "${route}"
		[ "${status}" -ne 0 ]
	done
}

@test "selected reusable tests run without deleted starter root docs" {
	mkdir -p "${FIXTURE}/.taskfiles/scripts" "${FIXTURE}/.devcontainer/test/unit" \
		"${FIXTURE}/.devcontainer/test/fixtures"
	mkdir -p "${FIXTURE}/.devcontainer/install/lib"
	cp "${ROOT}/.devcontainer/install/lib/selection.py" "${FIXTURE}/.devcontainer/install/lib/"
	local file
	for file in compose-manifest.py prepare-bind-mounts.py config-export.py; do
		cp "${ROOT}/.taskfiles/scripts/${file}" "${FIXTURE}/.taskfiles/scripts/"
	done
	[ ! -e "${FIXTURE}/.taskfiles/scripts/clean-lib.sh" ]
	for file in compose-manifest-test.py config-export.bats; do
		cp "${ROOT}/.devcontainer/test/unit/${file}" "${FIXTURE}/.devcontainer/test/unit/"
	done
	cp "${ROOT}/.devcontainer/test/fixtures/config-export.json" "${FIXTURE}/.devcontainer/test/fixtures/"
	run env PYTHONDONTWRITEBYTECODE=1 python3 "${FIXTURE}/.devcontainer/test/unit/compose-manifest-test.py" -v \
		ManifestTests.test_external_sources_are_never_prepared
	printf '%s\n' "${output}"
	[ "${status}" -eq 0 ]
	run bats --filter '^(diff classifies|consumer manifest cannot override mandatory JSONC)' \
		"${FIXTURE}/.devcontainer/test/unit/config-export.bats"
	printf '%s\n' "${output}"
	[ "${status}" -eq 0 ]
	[ ! -e "${FIXTURE}/docs" ]
	[ ! -e "${FIXTURE}/README.md" ]
	[ ! -e "${FIXTURE}/.git" ]
}
