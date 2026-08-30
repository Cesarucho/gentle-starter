#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	PLANNER_V2="${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/planner-v2.sh"
	TEST_ROOT="$(mktemp -d)"
	mkdir -p "${TEST_ROOT}/migrations"
}

teardown() { rm -rf "${TEST_ROOT}"; }

write_edge() {
	local id="$1" from="$2" to="$3"
	jq -n --arg id "${id}" --arg from "${from}" --arg to "${to}" \
		'{schema:"starter-migration/v2",id:$id,from_version:$from,to_version:$to,operations:[]}' \
		>"${TEST_ROOT}/migrations/${id}.json"
}

context() {
	local target="$1" entries
	entries="$(for path in "${TEST_ROOT}"/migrations/*.json; do
		jq -cn --arg id "$(jq -r '.id' "${path}")" --arg path "$(basename "${path}")" '{id:$id,path:$path}'
	done | jq -s .)"
	jq -cn --arg target "${target}" --arg root "${TEST_ROOT}/migrations" --argjson entries "${entries}" \
		'{target_release:{version:$target},migration_root:$root,manifest:{migrations:{entries:$entries}}}'
}

select_chain() {
	local current="$1" target="$2"
	bash -c 'source "$1"; starter_plan_v2_chain "$2" "$3"' _ "${PLANNER_V2}" "$(context "${target}")" "${current}"
}

@test "v2 planner selects one ordered multi-release chain" {
	write_edge bootstrap 0.0.0 2.0.0
	write_edge minor 2.0.0 2.1.0
	run select_chain 0.0.0 2.1.0
	[ "${status}" -eq 0 ]
	[ "$(jq -r '[.[].id] | join(",")' <<<"${output}")" = bootstrap,minor ]
}

@test "v2 planner rejects gaps, ambiguity, and duplicate edges" {
	write_edge gap 2.0.0 2.1.0
	run select_chain 1.0.0 2.1.0
	[ "${status}" -ne 0 ]
	write_edge alternate 2.0.0 2.2.0
	run select_chain 2.0.0 2.2.0
	[ "${status}" -ne 0 ]
	rm "${TEST_ROOT}/migrations/alternate.json"
	write_edge duplicate 2.0.0 2.1.0
	run select_chain 2.0.0 2.1.0
	[ "${status}" -ne 0 ]
}

@test "v2 planner rejects cycles, downgrades, and target mismatches" {
	write_edge forward 2.0.0 2.1.0
	write_edge cycle 2.1.0 2.0.0
	run select_chain 2.0.0 2.2.0
	[ "${status}" -ne 0 ]
	run select_chain 2.1.0 2.0.0
	[ "${status}" -ne 0 ]
	rm "${TEST_ROOT}/migrations/cycle.json"
	write_edge overshoot 2.1.0 3.0.0
	run select_chain 2.0.0 2.2.0
	[ "${status}" -ne 0 ]
}
