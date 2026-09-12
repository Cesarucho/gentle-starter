#!/usr/bin/env bats

setup() {
	ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	FIXTURE="${BATS_TEST_TMPDIR}/consumer"
	mkdir -p "${FIXTURE}/.taskfiles"
	cp "${ROOT}/Taskfile.yml" "${FIXTURE}/Taskfile.yml"
	cp "${ROOT}/.taskfiles/"*.yml "${FIXTURE}/.taskfiles/"
}

@test "post-init layout keeps application routing separate from explicit maintainer aliases" {
	[ ! -e "${FIXTURE}/README.md" ]
	[ ! -e "${FIXTURE}/docs" ]
	run task --exit-code --dir "${FIXTURE}" test
	[ "${status}" -eq 2 ]
	[[ "${output}" == *"Application tests are not configured"* ]]
	[[ "${output}" == *"tasks.test.cmds"* ]]

	local route
	for route in test:starter test:test test:all; do
		run task --dry --dir "${FIXTURE}" "${route}"
		[ "${status}" -eq 0 ]
		[[ "${output}" == *'bats .devcontainer/test/unit/*.bats'* ]]
		[[ "${output}" == *'bats .devcontainer/test/integration/tools.bats'* ]]
		[[ "${output}" != *'starter-lifecycle.py'* ]]
		[[ "${output}" != *'starter-test-clean.py'* ]]
	done
	for route in test:starter:unit test:unit; do
		run task --dry --dir "${FIXTURE}" "${route}"
		[ "${status}" -eq 0 ]
		[[ "${output}" == *'bats .devcontainer/test/unit/*.bats'* ]]
		[[ "${output}" != *'integration/tools.bats'* ]]
	done
	for route in test:starter:integration test:integration; do
		run task --dry --dir "${FIXTURE}" "${route}"
		[ "${status}" -eq 0 ]
		[[ "${output}" == *'bats .devcontainer/test/integration/tools.bats'* ]]
		[[ "${output}" != *'test/unit/'* ]]
	done
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

@test "expensive lifecycle route is explicit and forwards only explicit arguments" {
	run task --dry --dir "${FIXTURE}" test:starter:lifecycle -- --daemon-visible-scratch /workspace
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'starter-lifecycle.py --daemon-visible-scratch /workspace'* ]]
	[[ "${output}" != *'bats '* ]]
}

@test "recovery routing defaults to preview and is separate from operational lifecycle" {
	run task --dry --dir "${FIXTURE}" test:starter:clean
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'starter-test-clean.py'* ]]
	[[ "${output}" != *'--apply'* ]]
	[[ "${output}" != *'starter-lifecycle.py'* ]]
	run task --dry --dir "${FIXTURE}" test:starter:clean -- --apply --run 00000000-0000-4000-8000-000000000001
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'starter-test-clean.py --apply --run 00000000-0000-4000-8000-000000000001'* ]]
	run task --dry --dir "${FIXTURE}" validate:full
	[ "${status}" -eq 0 ]
	[[ "${output}" != *'starter-test-clean.py'* ]]
	[[ "${output}" != *'starter-lifecycle.py'* ]]
}

@test "selected reusable tests run without deleted starter root docs" {
	mkdir -p "${FIXTURE}/.taskfiles/scripts" "${FIXTURE}/.devcontainer/test/unit" \
		"${FIXTURE}/.devcontainer/test/fixtures"
	local file
	for file in compose-manifest.py prepare-bind-mounts.py clean-lib.sh config-export.py; do
		cp "${ROOT}/.taskfiles/scripts/${file}" "${FIXTURE}/.taskfiles/scripts/"
	done
	for file in compose-manifest-test.py config-export.bats; do
		cp "${BATS_TEST_DIRNAME}/${file}" "${FIXTURE}/.devcontainer/test/unit/"
	done
	cp "${BATS_TEST_DIRNAME}/../fixtures/config-export.json" "${FIXTURE}/.devcontainer/test/fixtures/"
	run env PYTHONDONTWRITEBYTECODE=1 python3 "${FIXTURE}/.devcontainer/test/unit/compose-manifest-test.py" -v \
		ManifestTests.test_optional_guide_migration_without_identity_removal \
		ManifestTests.test_external_sources_are_never_prepared
	printf '%s\n' "${output}"
	[ "${status}" -eq 0 ]
	run bats --filter '^(diff classifies|consumer manifest can manage JSONC)' \
		"${FIXTURE}/.devcontainer/test/unit/config-export.bats"
	printf '%s\n' "${output}"
	[ "${status}" -eq 0 ]
	[ ! -e "${FIXTURE}/docs" ]
	[ ! -e "${FIXTURE}/README.md" ]
	[ ! -e "${FIXTURE}/.git" ]
}
