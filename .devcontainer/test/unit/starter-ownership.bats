#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	CONTRACT="${REPO_ROOT}/.taskfiles/scripts/starter-lib/contracts/ownership.sh"
	CANONICAL="${REPO_ROOT}/.starter/distribution/ownership.json"
	TEST_ROOT="$(mktemp -d)"
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

validate() {
	run bash -c 'source "$1"; starter_ownership_validate_file "$2"' _ "${CONTRACT}" "$1"
}

@test "canonical v2 ownership inventory is valid and classifies exact paths" {
	validate "${CANONICAL}"
	[ "$status" -eq 0 ]
	run bash -c 'source "$1"; starter_ownership_classify "$2" "$3"' _ \
		"${CONTRACT}" "${CANONICAL}" ".taskfiles/scripts/starter-lib/core/planner-v2.sh"
	[ "$status" -eq 0 ]
	[ "$output" = managed ]
	run bash -c 'source "$1"; starter_ownership_classify "$2" "$3"' _ \
		"${CONTRACT}" "${CANONICAL}" ".taskfiles/scripts/starter-library/not-owned"
	[ "$output" = project-owned ]
}

@test "ownership inventory rejects unknown fields and unsafe paths" {
	local mutation
	for mutation in '.unknown=true' '.managed += [{match:"exact",path:"/absolute"}]' '.managed += [{match:"exact",path:"a/../b"}]'; do
		jq "${mutation}" "${CANONICAL}" >"${TEST_ROOT}/inventory.json"
		validate "${TEST_ROOT}/inventory.json"
		[ "$status" -ne 0 ]
	done
}

@test "ownership inventory rejects duplicates overlaps and ancestor ambiguity" {
	local entries
	for entries in \
		'[{"match":"exact","path":"a"},{"match":"exact","path":"a"}]' \
		'[{"match":"exact","path":"a/b"},{"match":"exact","path":"a"}]' \
		'[{"match":"exact","path":"a"},{"match":"exact","path":"a/b"}]'; do
		jq --argjson entries "${entries}" '.managed=$entries' "${CANONICAL}" >"${TEST_ROOT}/inventory.json"
		validate "${TEST_ROOT}/inventory.json"
		[ "$status" -ne 0 ]
	done
}

@test "ownership inventory rejects fusion declarations without a composition contract" {
	jq '.fusion=[{match:"exact",path:"Taskfile.yml"}]' "${CANONICAL}" >"${TEST_ROOT}/inventory.json"
	validate "${TEST_ROOT}/inventory.json"
	[ "$status" -ne 0 ]
	[[ "$output" == *"do not match supported F-manual/v1 paths"* ]]
}
