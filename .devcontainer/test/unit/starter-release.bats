#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	RELEASE="${REPO_ROOT}/.taskfiles/scripts/starter-release.sh"
	TEST_ROOT="$(mktemp -d)"
	PROJECT="${TEST_ROOT}/project"
	REMOTE="${TEST_ROOT}/remote.git"
	create_project 0.1.0
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

create_project() {
	local version="$1" payload_sha payload_bytes migration_sha
	mkdir -p "${PROJECT}/.starter/distribution/payloads" "${PROJECT}/.starter/distribution/migrations"
	printf '%s\n' '# Gentle Starter fixture' >"${PROJECT}/AGENTS.md"
	printf '%s\n' 'inert payload' >"${PROJECT}/.starter/distribution/payloads/baseline.txt"
	payload_sha="$(sha256sum "${PROJECT}/.starter/distribution/payloads/baseline.txt" | cut -d' ' -f1)"
	payload_bytes="$(wc -c <"${PROJECT}/.starter/distribution/payloads/baseline.txt")"
	jq -n --arg version "${version}" '{schema:"starter-migration/v1",id:("release-"+$version),from_version:"0.0.0",to_version:$version,operations:[]}' \
		>"${PROJECT}/.starter/distribution/migrations/release.json"
	migration_sha="$(sha256sum "${PROJECT}/.starter/distribution/migrations/release.json" | cut -d' ' -f1)"
	jq -n --arg version "${version}" --arg payload_sha "${payload_sha}" --argjson bytes "${payload_bytes}" --arg migration_sha "${migration_sha}" '{
		schema:"starter-manifest/v1",source:{id:"gentle-starter",release:("starter/v"+$version)},release:{version:$version,predecessor_id:null},
		payload:{root:"payloads",entries:[{path:"baseline.txt",sha256:$payload_sha,bytes:$bytes}]},
		migrations:{root:"migrations",entries:[{id:("release-"+$version),path:"release.json",sha256:$migration_sha}]}
	}' >"${PROJECT}/.starter/distribution/manifest.json"
	git init -q "${PROJECT}"
	git -C "${PROJECT}" config user.name "Release Test"
	git -C "${PROJECT}" config user.email "release@example.invalid"
	git -C "${PROJECT}" add .
	git -C "${PROJECT}" commit -qm fixture
	git -C "${PROJECT}" commit --allow-empty -qm "ordinary clone history"
	git init -q --bare "${REMOTE}"
	git -C "${PROJECT}" remote add origin "${REMOTE}"
}

run_release() {
	run bash -c 'cd "$1" && exec "$2" "${@:3}"' _ "${PROJECT}" "${RELEASE}" "$@"
}

ref_snapshot() {
	git -C "${PROJECT}" for-each-ref --format='%(refname) %(objectname)'
}

@test "starter release creates an unsigned annotated tag and validates it through GitTagSource without pushing" {
	local remote_before
	remote_before="$(git --git-dir="${REMOTE}" for-each-ref --format='%(refname) %(objectname)')"
	run_release 0.1.0
	[ "$status" -eq 0 ]
	[[ "$output" == *"selector/tag: starter/v0.1.0"* ]]
	[[ "$output" == *"structural/integrity status: validated"* ]]
	[[ "$output" == *"remote publication: pending"* ]]
	[ "$(git -C "${PROJECT}" cat-file -t starter/v0.1.0)" = tag ]
	[ "$(git -C "${PROJECT}" for-each-ref --format='%(contents:subject)' refs/tags/starter/v0.1.0 | jq -r '.manifest.path')" = .starter/distribution/manifest.json ]
	[ "$(git --git-dir="${REMOTE}" for-each-ref --format='%(refname) %(objectname)')" = "${remote_before}" ]
}

@test "starter release rejects invalid SemVer and dirty or untracked repositories without ref mutation" {
	local before
	before="$(ref_snapshot)"
	run_release v0.1.0
	[ "$status" -ne 0 ]
	[ "$(ref_snapshot)" = "${before}" ]
	printf '%s\n' dirty >"${PROJECT}/untracked.txt"
	run_release 0.1.0
	[ "$status" -ne 0 ]
	[[ "$output" == *"worktree and index must be clean"* ]]
	[ "$(ref_snapshot)" = "${before}" ]
}

@test "starter release rejects missing malformed and mismatched distribution metadata before mutation" {
	local before manifest="${PROJECT}/.starter/distribution/manifest.json"
	mv "${manifest}" "${manifest}.missing"
	run_release 0.1.0
	[ "$status" -ne 0 ]
	git -C "${PROJECT}" restore .
	printf '%s\n' '{}' >"${manifest}"
	git -C "${PROJECT}" add "${manifest}" && git -C "${PROJECT}" commit -qm malformed
	run_release 0.1.0
	[ "$status" -ne 0 ]
	git -C "${PROJECT}" show HEAD^:".starter/distribution/manifest.json" >"${manifest}"
	jq '.payload.entries[0].sha256 = ("f" * 64)' "${manifest}" >"${manifest}.tmp" && mv "${manifest}.tmp" "${manifest}"
	git -C "${PROJECT}" add "${manifest}" && git -C "${PROJECT}" commit -qm mismatch
	before="$(ref_snapshot)"
	run_release 0.1.0
	[ "$status" -ne 0 ]
	[ "$(ref_snapshot)" = "${before}" ]
}

@test "starter release rejects duplicate local and publication-remote exact tags" {
	git -C "${PROJECT}" tag -a -m existing starter/v0.1.0
	run_release 0.1.0
	[ "$status" -ne 0 ]
	[[ "$output" == *"local tag already exists"* ]]
	git -C "${PROJECT}" tag -d starter/v0.1.0 >/dev/null
	git -C "${PROJECT}" tag -a -m remote starter/v0.1.0
	git -C "${PROJECT}" push -q origin refs/tags/starter/v0.1.0
	git -C "${PROJECT}" tag -d starter/v0.1.0 >/dev/null
	local before="$(ref_snapshot)"
	run_release 0.1.0
	[ "$status" -ne 0 ]
	[[ "$output" == *"publication remote already has exact tag"* ]]
	[ "$(ref_snapshot)" = "${before}" ]
}

@test "starter release rejects project-init history without ref mutation" {
	git -C "${PROJECT}" checkout -q --orphan derived-main
	git -C "${PROJECT}" add -A
	git -C "${PROJECT}" commit -qm "chore: initialize project"
	git -C "${PROJECT}" commit --allow-empty -qm "derived project work"
	local before="$(ref_snapshot)"
	run_release 0.1.0
	[ "$status" -ne 0 ]
	[[ "$output" == *"derived project roots cannot create releases"* ]]
	[ "$(ref_snapshot)" = "${before}" ]
}

@test "starter release rolls back only its unchanged tag after post-create validation failure" {
	git -C "${PROJECT}" branch collateral
	local before="$(ref_snapshot)"
	run env STARTER_RELEASE_FAILPOINT=after-tag bash -c 'cd "$1" && exec "$2" 0.1.0' _ "${PROJECT}" "${RELEASE}"
	[ "$status" -ne 0 ]
	[ "$(ref_snapshot)" = "${before}" ]
	! git -C "${PROJECT}" show-ref --verify --quiet refs/tags/starter/v0.1.0
}
