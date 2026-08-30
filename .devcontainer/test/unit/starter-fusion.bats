#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	F_MANUAL="${REPO_ROOT}/.taskfiles/scripts/starter-lib/contracts/f-manual.sh"
	COMPATIBILITY="${REPO_ROOT}/.taskfiles/scripts/starter-lib/contracts/devcontainer-compatibility.sh"
	TEST_ROOT="$(mktemp -d)"
}

teardown() { rm -rf "${TEST_ROOT}"; }

@test "F-manual equality shortcuts and conflicts are deterministic" {
	run bash -c 'source "$1"; starter_f_manual_decision a a b' _ "${F_MANUAL}"
	[ "$output" = take-starter ]
	run bash -c 'source "$1"; starter_f_manual_decision a b a' _ "${F_MANUAL}"
	[ "$output" = keep-project ]
	run bash -c 'source "$1"; starter_f_manual_decision a b c' _ "${F_MANUAL}"
	[ "$output" = manual ]
}

@test "F-manual accepts only the two approved paths" {
	run bash -c 'source "$1"; starter_f_manual_validate_paths "$2" "$3"' _ "${F_MANUAL}" \
		.devcontainer/devcontainer.json .devcontainer/docker-compose.yml
	[ "$status" -eq 0 ]
	run bash -c 'source "$1"; starter_f_manual_validate_paths "$2"' _ "${F_MANUAL}" Taskfile.yml
	[ "$status" -ne 0 ]
}

@test "F-manual choices resolve every pending conflict without path arguments" {
	cat >"${TEST_ROOT}/journal.json" <<'JSON'
{"schema":"gentle-starter.journal/v2","fusion":{"contract":"F-manual/v1","pending":[{"path":".devcontainer/devcontainer.json"},{"path":".devcontainer/docker-compose.yml"}]}}
JSON
	run bash -c 'source "$1"; starter_f_manual_resolve_all "$2" take-starter' _ "${F_MANUAL}" "${TEST_ROOT}/journal.json"
	[ "$status" -eq 0 ]
	[ "$(jq -r '.fusion.decision.scope' <<<"${output}")" = all ]
	[ "$(jq -r '.fusion.decision.count' <<<"${output}")" -eq 2 ]
}

@test "managed devcontainer lock is compatible with project-owned configuration" {
	run bash -c 'source "$1"; starter_devcontainer_compatibility_validate "$2"' _ "${COMPATIBILITY}" "${REPO_ROOT}"
	[ "$status" -eq 0 ]
	cp -a "${REPO_ROOT}/.devcontainer" "${TEST_ROOT}/.devcontainer"
	jq 'del(.features["ghcr.io/devcontainers/features/github-cli:1"])' \
		"${TEST_ROOT}/.devcontainer/devcontainer-lock.json" >"${TEST_ROOT}/lock" &&
		mv "${TEST_ROOT}/lock" "${TEST_ROOT}/.devcontainer/devcontainer-lock.json"
	run bash -c 'source "$1"; starter_devcontainer_compatibility_validate "$2"' _ "${COMPATIBILITY}" "${TEST_ROOT}"
	[ "$status" -ne 0 ]
}

@test "F-manual proposals support take keep manual continue and abort without touching unrelated files" {
	local engine="${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/fusion-transaction.sh"
	local project="${TEST_ROOT}/project" base="${TEST_ROOT}/base" theirs="${TEST_ROOT}/theirs" journal
	for root in "${project}" "${base}" "${theirs}"; do
		mkdir -p "${root}/.devcontainer" "${root}/.starter/journals"
		printf 'base-json\n' >"${root}/.devcontainer/devcontainer.json"
		printf 'base-compose\n' >"${root}/.devcontainer/docker-compose.yml"
	done
	printf 'ours-json\n' >"${project}/.devcontainer/devcontainer.json"
	printf 'ours-compose\n' >"${project}/.devcontainer/docker-compose.yml"
	printf 'theirs-json\n' >"${theirs}/.devcontainer/devcontainer.json"
	printf 'theirs-compose\n' >"${theirs}/.devcontainer/docker-compose.yml"
	git -C "${project}" init -q && git -C "${project}" config user.name Test && git -C "${project}" config user.email test@example.test
	git -C "${project}" add -A && git -C "${project}" commit -qm baseline
	run bash -c 'source "$1"; starter_f_prepare_conflicts "$2" 2.0.0 "$3" "$4"' _ \
		"${engine}" "${project}" "${base}" "${theirs}"
	[ "$status" -eq 0 ]
	journal="${output##*$'\n'}"
	[ -f "$(dirname "${journal}")/proposed/.devcontainer/devcontainer.json" ]
	run bash -c 'source "$1"; starter_f_transaction_resume "$2" take-starter' _ "${engine}" "${project}"
	[ "$status" -eq 0 ]
	[ "$(cat "${project}/.devcontainer/devcontainer.json")" = theirs-json ]
	[ "$(cat "${project}/.devcontainer/docker-compose.yml")" = theirs-compose ]
	[ "$(jq -r '.schema' "${project}/.starter/state.json")" = gentle-starter.state/v2 ]

	git -C "${project}" add -A && git -C "${project}" commit -qm resolved
	printf 'ours-again\n' >"${project}/.devcontainer/devcontainer.json"
	printf 'ours-compose-again\n' >"${project}/.devcontainer/docker-compose.yml"
	printf 'theirs-again\n' >"${theirs}/.devcontainer/devcontainer.json"
	printf 'theirs-compose-again\n' >"${theirs}/.devcontainer/docker-compose.yml"
	rm -rf "${project}/.starter/journals"
	mkdir -p "${project}/.starter/journals"
	run bash -c 'source "$1"; starter_f_prepare_conflicts "$2" 2.1.0 "$3" "$4"' _ \
		"${engine}" "${project}" "${base}" "${theirs}"
	[ "$status" -eq 0 ]
	run bash -c 'source "$1"; starter_f_transaction_resume "$2" abort' _ "${engine}" "${project}"
	[ "$status" -eq 0 ]
	[ "$(cat "${project}/.devcontainer/devcontainer.json")" = ours-again ]
}

@test "F-manual rolls back an injected second-write failure and preserves concurrent edits" {
	local engine="${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/fusion-transaction.sh"
	local project="${TEST_ROOT}/project" base="${TEST_ROOT}/base" theirs="${TEST_ROOT}/theirs"
	for root in "${project}" "${base}" "${theirs}"; do
		mkdir -p "${root}/.devcontainer" "${root}/.starter/journals"
		printf 'base-json\n' >"${root}/.devcontainer/devcontainer.json"
		printf 'base-compose\n' >"${root}/.devcontainer/docker-compose.yml"
	done
	printf 'ours-json\n' >"${project}/.devcontainer/devcontainer.json"
	printf 'ours-compose\n' >"${project}/.devcontainer/docker-compose.yml"
	printf 'theirs-json\n' >"${theirs}/.devcontainer/devcontainer.json"
	printf 'theirs-compose\n' >"${theirs}/.devcontainer/docker-compose.yml"
	git -C "${project}" init -q && git -C "${project}" config user.name Test && git -C "${project}" config user.email test@example.test
	git -C "${project}" add -A && git -C "${project}" commit -qm baseline
	bash -c 'source "$1"; starter_f_prepare_conflicts "$2" 2.0.0 "$3" "$4"' _ "${engine}" "${project}" "${base}" "${theirs}" >/dev/null
	run env STARTER_F_FAILPOINT=after-write-2 bash -c 'source "$1"; starter_f_transaction_resume "$2" take-starter' _ "${engine}" "${project}"
	[ "${status}" -ne 0 ]
	[ "$(cat "${project}/.devcontainer/devcontainer.json")" = ours-json ]
	[ "$(cat "${project}/.devcontainer/docker-compose.yml")" = ours-compose ]
	printf 'human-edit\n' >"${project}/.devcontainer/devcontainer.json"
	run bash -c 'source "$1"; starter_f_transaction_resume "$2" abort' _ "${engine}" "${project}"
	[ "${status}" -ne 0 ]
	[ "$(cat "${project}/.devcontainer/devcontainer.json")" = human-edit ]
}
