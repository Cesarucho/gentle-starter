#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	FACADE="${REPO_ROOT}/.taskfiles/scripts/starter.sh"
	TEST_ROOT="$(mktemp -d)"
	PROJECT="${TEST_ROOT}/project"
	REMOTE="${TEST_ROOT}/starter.git"
	CACHE="${TEST_ROOT}/cache"
	SENTINEL="${TEST_ROOT}/payload-executed"
	OFFICIAL_SOURCE="https://github.com/Cesarucho/gentle-starter.git"
	git init -q --bare "${REMOTE}"
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

publish_release() {
	local version="$1" from_version="$2" content="$3" expected_before="$4"
	local work="${TEST_ROOT}/release-${version}" distribution payload_sha payload_bytes migration_sha
	local commit_oid tree_oid manifest_blob manifest_sha message
	distribution="${work}/.starter/distribution"
	mkdir -p "${distribution}/payloads" "${distribution}/migrations"
	git init -q "${work}"
	git -C "${work}" config user.name "Starter Facade Test"
	git -C "${work}" config user.email "starter-facade@example.invalid"
	printf '%s\n' "${content}" >"${distribution}/payloads/managed.txt"
	chmod 0755 "${distribution}/payloads/managed.txt"
	payload_sha="$(sha256sum "${distribution}/payloads/managed.txt" | cut -d' ' -f1)"
	payload_bytes="$(wc -c <"${distribution}/payloads/managed.txt")"
	jq -n --arg from "${from_version}" --arg to "${version}" --arg expected "${expected_before}" '{
		schema:"starter-migration/v1",id:("release-"+$to),from_version:$from,to_version:$to,
		operations:[{type:"copy",ownership:"managed",source:"managed.txt",target:"managed.txt",
			expected_before_sha256:(if $expected == "null" then null else $expected end)}]
	}' >"${distribution}/migrations/release.json"
	migration_sha="$(sha256sum "${distribution}/migrations/release.json" | cut -d' ' -f1)"
	jq -n --arg version "${version}" --arg payload_sha "${payload_sha}" --argjson bytes "${payload_bytes}" \
		--arg migration_sha "${migration_sha}" '{
		schema:"starter-manifest/v1",source:{id:"gentle-starter",release:("starter/v"+$version)},
		release:{version:$version,predecessor_id:null},
		payload:{root:"payloads",entries:[{path:"managed.txt",sha256:$payload_sha,bytes:$bytes}]},
		migrations:{root:"migrations",entries:[{id:("release-"+$version),path:"release.json",sha256:$migration_sha}]}
	}' >"${distribution}/manifest.json"
	git -C "${work}" add .starter
	GIT_AUTHOR_DATE=1704067200 GIT_COMMITTER_DATE=1704067200 git -C "${work}" commit -q -m "release ${version}"
	commit_oid="$(git -C "${work}" rev-parse HEAD)"
	tree_oid="$(git -C "${work}" rev-parse 'HEAD^{tree}')"
	manifest_blob="$(git -C "${work}" rev-parse 'HEAD:.starter/distribution/manifest.json')"
	manifest_sha="$(sha256sum "${distribution}/manifest.json" | cut -d' ' -f1)"
	message="$(jq -cn --arg version "${version}" --arg commit "${commit_oid}" --arg tree "${tree_oid}" \
		--arg blob "${manifest_blob}" --arg sha "${manifest_sha}" '{
		schema:"gentle-starter.git-tag/v1",source_id:"gentle-starter",version:$version,
		commit_oid:$commit,tree_oid:$tree,manifest:{path:".starter/distribution/manifest.json",blob_oid:$blob,sha256:$sha}}')"
	GIT_COMMITTER_DATE=1704153600 git -C "${work}" tag -a -m "${message}" "starter/v${version}"
	git -C "${work}" remote add fixture "${REMOTE}"
	git -C "${work}" push -q fixture "HEAD:refs/heads/release-${version}" "refs/tags/starter/v${version}"
	PUBLISHED_SHA="${payload_sha}"
}

initialize_project() {
	local managed_content="$1"
	mkdir -p "${PROJECT}/.starter"
	printf '%s\n' "${managed_content}" >"${PROJECT}/managed.txt"
	printf '%s\n' 'project-owned content' >"${PROJECT}/owned.txt"
	printf '%s\n' '{"anchor":"retained"}' >"${PROJECT}/.starter/anchor.json"
	git init -q "${PROJECT}"
	git -C "${PROJECT}" config user.name "Derived Project"
	git -C "${PROJECT}" config user.email "derived@example.invalid"
	git -C "${PROJECT}" remote add origin https://example.invalid/derived.git
	git -C "${PROJECT}" add managed.txt owned.txt .starter/anchor.json
	git -C "${PROJECT}" commit -q -m "derived project"
}

run_facade() {
	local command="$1"
	shift
	run env STARTER_CACHE_DIR="${CACHE}" STARTER_EXECUTION_SENTINEL="${SENTINEL}" \
		STARTER_TRANSACTION_FAILPOINT="${STARTER_TRANSACTION_FAILPOINT:-}" \
		"${FACADE}" "${command}" --project-root "${PROJECT}" --source "file://${REMOTE}" \
		"$@"
}

parse_source_url() {
	mkdir -p "${PROJECT}"
	run bash -c '
		source "$1"
		starter_parse_args check "${@:2}" || exit $?
		printf "%s\n" "${STARTER_SOURCE_URL}"
	' _ "${FACADE}" "$@"
}

source_cache_candidate() {
	mkdir -p "${PROJECT}"
	run bash -c '
		source "$1"
		starter_parse_args check "${@:2}" || exit $?
		starter_cache_candidate
	' _ "${FACADE}" "$@"
}

snapshot_git_boundaries() {
	SNAPSHOT_HEAD="$(git -C "${PROJECT}" rev-parse HEAD)"
	SNAPSHOT_HISTORY="$(git -C "${PROJECT}" rev-list --all --objects)"
	SNAPSHOT_REFS="$(git -C "${PROJECT}" for-each-ref --format='%(refname) %(objectname)')"
	SNAPSHOT_REMOTES="$(git -C "${PROJECT}" remote -v)"
	SNAPSHOT_INDEX="$(sha256sum "${PROJECT}/.git/index" | cut -d' ' -f1)"
	SNAPSHOT_OWNED="$(sha256sum "${PROJECT}/owned.txt" | cut -d' ' -f1)"
}

assert_git_boundaries_preserved() {
	[ "$(git -C "${PROJECT}" rev-parse HEAD)" = "${SNAPSHOT_HEAD}" ]
	[ "$(git -C "${PROJECT}" rev-list --all --objects)" = "${SNAPSHOT_HISTORY}" ]
	[ "$(git -C "${PROJECT}" for-each-ref --format='%(refname) %(objectname)')" = "${SNAPSHOT_REFS}" ]
	[ "$(git -C "${PROJECT}" remote -v)" = "${SNAPSHOT_REMOTES}" ]
	[ "$(sha256sum "${PROJECT}/.git/index" | cut -d' ' -f1)" = "${SNAPSHOT_INDEX}" ]
	[ "$(sha256sum "${PROJECT}/owned.txt" | cut -d' ' -f1)" = "${SNAPSHOT_OWNED}" ]
	[ ! -e "${SENTINEL}" ]
}

@test "starter commands use the official source when --source is omitted" {
	parse_source_url --release starter/v1.0.0 --project-root "${PROJECT}"

	[ "$status" -eq 0 ]
	[ "$output" = "${OFFICIAL_SOURCE}" ]
}

@test "starter commands prefer explicit --source over the official default" {
	local override="file://${REMOTE}"

	parse_source_url --release starter/v1.0.0 --project-root "${PROJECT}" --source "${override}"

	[ "$status" -eq 0 ]
	[ "$output" = "${override}" ]
}

@test "explicit --source cannot reuse a candidate cached from the default source" {
	source_cache_candidate --release starter/v1.0.0 --project-root "${PROJECT}"
	[ "$status" -eq 0 ]
	local default_candidate="${output}"

	source_cache_candidate --release starter/v1.0.0 --project-root "${PROJECT}" --source "file://${REMOTE}"

	[ "$status" -eq 0 ]
	[ "$output" != "${default_candidate}" ]
}

@test "starter:adopt rejects managed drift without creating a marker or mutating Git" {
	publish_release 1.0.0 0.0.0 '#!/bin/sh; touch "${STARTER_EXECUTION_SENTINEL:?}"; baseline' null
	initialize_project 'locally drifted managed content'
	snapshot_git_boundaries
	local before_status before_managed
	before_status="$(git -C "${PROJECT}" status --porcelain=v1 --untracked-files=all)"
	before_managed="$(sha256sum "${PROJECT}/managed.txt" | cut -d' ' -f1)"

	run_facade adopt --release starter/v1.0.0

	[ "$status" -eq 1 ]
	[[ "$output" == *'BLOCKER state.fingerprint:'* ]]
	[ ! -e "${PROJECT}/.starter/state.json" ]
	[ "$(git -C "${PROJECT}" status --porcelain=v1 --untracked-files=all)" = "${before_status}" ]
	[ "$(sha256sum "${PROJECT}/managed.txt" | cut -d' ' -f1)" = "${before_managed}" ]
	assert_git_boundaries_preserved
}

@test "starter:check reports every blocker and remains fully read-only" {
	local baseline='#!/bin/sh; touch "${STARTER_EXECUTION_SENTINEL:?}"; baseline'
	publish_release 1.0.0 0.0.0 "${baseline}" null
	local baseline_sha="${PUBLISHED_SHA}"
	initialize_project "${baseline}"
	snapshot_git_boundaries
	run_facade adopt --release starter/v1.0.0
	[ "$status" -eq 0 ]
	assert_git_boundaries_preserved
	git -C "${PROJECT}" add .starter/state.json .starter/evidence
	git -C "${PROJECT}" commit -q -m "adopt starter baseline"
	publish_release 3.0.0 9.0.0 'unreachable candidate content' "${baseline_sha}"
	printf '%s\n' 'drifted managed content' >"${PROJECT}/managed.txt"
	printf '%s\n' 'untracked owner note' >"${PROJECT}/notes.txt"
	snapshot_git_boundaries
	local before_status before_managed before_note
	before_status="$(git -C "${PROJECT}" status --porcelain=v1 --untracked-files=all)"
	before_managed="$(sha256sum "${PROJECT}/managed.txt" | cut -d' ' -f1)"
	before_note="$(sha256sum "${PROJECT}/notes.txt" | cut -d' ' -f1)"

	run_facade check --release starter/v3.0.0

	[ "$status" -eq 1 ]
	[[ "$output" == *'BLOCKER state.drift:'* ]]
	[[ "$output" == *'BLOCKER repository.dirty:'* ]]
	[[ "$output" == *'BLOCKER plan.invalid:'* ]]
	[[ "$output" == *'starter: check blocked (3 blockers)'* ]]
	[ "$(git -C "${PROJECT}" status --porcelain=v1 --untracked-files=all)" = "${before_status}" ]
	[ "$(sha256sum "${PROJECT}/managed.txt" | cut -d' ' -f1)" = "${before_managed}" ]
	[ "$(sha256sum "${PROJECT}/notes.txt" | cut -d' ' -f1)" = "${before_note}" ]
	assert_git_boundaries_preserved
}

@test "starter:update uses validated planning rollback and state-last semantics without executing payloads" {
	local baseline='#!/bin/sh; touch "${STARTER_EXECUTION_SENTINEL:?}"; baseline'
	local update='#!/bin/sh; touch "${STARTER_EXECUTION_SENTINEL:?}"; update'
	publish_release 1.0.0 0.0.0 "${baseline}" null
	local baseline_sha="${PUBLISHED_SHA}"
	initialize_project "${baseline}"
	run_facade adopt --release starter/v1.0.0
	[ "$status" -eq 0 ]
	git -C "${PROJECT}" add .starter/state.json .starter/evidence
	git -C "${PROJECT}" commit -q -m "adopt starter baseline"
	publish_release 2.0.0 1.0.0 "${update}" "${baseline_sha}"
	snapshot_git_boundaries

	STARTER_TRANSACTION_FAILPOINT=before-state run_facade update --release starter/v2.0.0 --yes
	[ "$status" -eq 1 ]
	[[ "$output" == *'BLOCKER update.failed:'* ]]
	[ "$(cat "${PROJECT}/managed.txt")" = "${baseline}" ]
	[ "$(jq -r '.release.version' "${PROJECT}/.starter/state.json")" = 1.0.0 ]
	[ -z "$(find "${PROJECT}/.starter" -path '*/journals/*/journal.json' -print -quit)" ]
	assert_git_boundaries_preserved

	STARTER_TRANSACTION_FAILPOINT= run_facade update --release starter/v2.0.0 --yes
	[ "$status" -eq 0 ]
	[[ "$output" == *'starter: updated 1.0.0 -> 2.0.0; review and commit the changes'* ]]
	[ "$(cat "${PROJECT}/managed.txt")" = "${update}" ]
	[ "$(jq -r '.release.version' "${PROJECT}/.starter/state.json")" = 2.0.0 ]
	[ -z "$(find "${PROJECT}/.starter" -path '*/journals/*/journal.json' -print -quit)" ]
	assert_git_boundaries_preserved
}

@test "starter:update requires explicit confirmation before acquisition or writes" {
	publish_release 1.0.0 0.0.0 baseline null
	initialize_project baseline
	local before_status
	before_status="$(git -C "${PROJECT}" status --porcelain=v1 --untracked-files=all)"

	run_facade update --release starter/v1.0.0

	[ "$status" -eq 64 ]
	[[ "$output" == *'starter: update requires --yes'* ]]
	[ "$(git -C "${PROJECT}" status --porcelain=v1 --untracked-files=all)" = "${before_status}" ]
	[ ! -e "${PROJECT}/.starter/state.json" ]
}
