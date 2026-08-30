#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	ROLLBACK="${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/rollback.sh"
	PROJECT="${BATS_TEST_TMPDIR}/project"
	TRANSACTION="${PROJECT}/.starter/journals/transaction.fixture"
	mkdir -p "${TRANSACTION}/prestate" "${TRANSACTION}/staged"
	printf 'before\n' >"${TRANSACTION}/prestate/0"
	printf 'after\n' >"${TRANSACTION}/staged/0"
	BEFORE_SHA="$(sha256sum "${TRANSACTION}/prestate/0" | cut -d' ' -f1)"
	AFTER_SHA="$(sha256sum "${TRANSACTION}/staged/0" | cut -d' ' -f1)"
}

write_journal() {
	local target="${1:-managed.txt}" journal="${TRANSACTION}/journal.json" sha
	jq -n --arg root "${PROJECT}" --arg target "${target}" --arg before "${BEFORE_SHA}" --arg after "${AFTER_SHA}" '{
		schema:"gentle-starter.journal/v2",project_root:$root,state_before_sha256:null,source_result:{},
		plan:{schema:"gentle-starter.plan/v2"},fusion:{contract:"F-manual/v1",status:"applying",pending:[]},progress:{applied:1},
		operations:[{index:0,type:"copy",ownership:"managed",target:$target,
			before:{sha256:$before,backup:"prestate/0"},after:{sha256:$after,staged:"staged/0"}}]
	}' >"${journal}"
	sha="$(jq -cS . "${journal}" | sha256sum | cut -d' ' -f1)"
	jq --arg sha "${sha}" '.integrity={canonicalization:"jq-sorted-utf8-v1",journal_sha256:$sha}' \
		"${journal}" >"${journal}.sealed"
	mv "${journal}.sealed" "${journal}"
}

recover() {
	run bash -c 'source "$1"; starter_rollback_recover "$2" "$3"' _ \
		"${ROLLBACK}" "${PROJECT}" "${TRANSACTION}/journal.json"
}

@test "v2 durable journal restores a CAS-provable mutation and removes only its transaction" {
	printf 'after\n' >"${PROJECT}/managed.txt"
	printf 'human\n' >"${PROJECT}/unrelated.txt"
	write_journal
	recover
	[ "${status}" -eq 0 ]
	[ "$(cat "${PROJECT}/managed.txt")" = before ]
	[ "$(cat "${PROJECT}/unrelated.txt")" = human ]
	[ ! -e "${TRANSACTION}" ]
}

@test "v2 recovery retains journal and concurrent human content on CAS mismatch" {
	printf 'human concurrent edit\n' >"${PROJECT}/managed.txt"
	write_journal
	recover
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"ambiguous concurrent change retained"* ]]
	[ "$(cat "${PROJECT}/managed.txt")" = "human concurrent edit" ]
	[ -f "${TRANSACTION}/journal.json" ]
}

@test "v2 recovery rejects a tampered journal before touching project content" {
	printf 'after\n' >"${PROJECT}/managed.txt"
	write_journal
	jq '.operations[0].target="unrelated.txt"' "${TRANSACTION}/journal.json" >"${TRANSACTION}/journal.tmp"
	mv "${TRANSACTION}/journal.tmp" "${TRANSACTION}/journal.json"
	recover
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"journal integrity mismatch"* ]]
	[ "$(cat "${PROJECT}/managed.txt")" = after ]
	[ -f "${TRANSACTION}/journal.json" ]
}

@test "v2 recovery rejects tampered backup bytes and preserves the applied value" {
	printf 'after\n' >"${PROJECT}/managed.txt"
	write_journal
	printf 'tampered\n' >"${TRANSACTION}/prestate/0"
	recover
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"ambiguous recovery failure retained"* ]]
	[ "$(cat "${PROJECT}/managed.txt")" = after ]
	[ -f "${TRANSACTION}/journal.json" ]
}

@test "v2 recovery refuses symlink targets without modifying the referent" {
	printf 'human referent\n' >"${PROJECT}/human.txt"
	ln -s human.txt "${PROJECT}/managed.txt"
	write_journal
	recover
	[ "${status}" -ne 0 ]
	[ "$(cat "${PROJECT}/human.txt")" = "human referent" ]
	[ -L "${PROJECT}/managed.txt" ]
}
