#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	[ -d /home/ubuntu/tmp ]
	TEST_ROOT="$(mktemp -d /home/ubuntu/tmp/starter-derived-test.XXXXXX)"
}

teardown() { rm -rf "${TEST_ROOT}"; }

@test "official tree transforms deterministically into a consumer-only tree" {
	local first="${TEST_ROOT}/first" second="${TEST_ROOT}/second" first_id second_id
	run bash -c 'source "$1"; starter_derived_transform "$2" "$3"; starter_derived_identity "$3"' _ \
		"${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/derived-tree.sh" "${REPO_ROOT}" "${first}"
	[ "$status" -eq 0 ]
	first_id="${output##*$'\n'}"
	run bash -c 'source "$1"; starter_derived_transform "$2" "$3"; starter_derived_identity "$3"' _ \
		"${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/derived-tree.sh" "${REPO_ROOT}" "${second}"
	[ "$status" -eq 0 ]
	second_id="${output##*$'\n'}"
	[ "${first_id}" = "${second_id}" ]
	[ ! -e "${first}/.taskfiles/project.yml" ]
	[ ! -e "${first}/.taskfiles/scripts/starter-release.sh" ]
	[ ! -e "${first}/.taskfiles/scripts/starter-prepare-release.sh" ]
	[ ! -e "${first}/.starter/distribution/manifest.json" ]
	[ ! -e "${first}/.starter/state.json" ]
	[ -f "${first}/.devcontainer/docs/starter-updates.md" ]
	run yq -e '.tasks.release or .tasks.prepare-release' "${first}/.taskfiles/starter.yml"
	[ "$status" -ne 0 ]
}
