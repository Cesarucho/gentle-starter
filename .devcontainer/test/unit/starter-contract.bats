#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	CONTRACT="${REPO_ROOT}/.taskfiles/scripts/starter-lib/contracts/source-port.sh"
	REPOSITORY_STATUS_ADAPTER="${REPO_ROOT}/.taskfiles/scripts/starter-lib/adapters/git-repository-status.sh"
	STATE_CORE="${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/state.sh"
	QUALITY_CONFIG="${REPO_ROOT}/.taskfiles/quality.yml"
	TEST_ROOT="$(mktemp -d)"
	PAYLOAD_ROOT="${TEST_ROOT}/candidate"
	mkdir -p "${PAYLOAD_ROOT}"
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

snapshot_tree() {
	find "$1" -mindepth 1 -printf '%P %y %s\n' | sort
}

seal_envelope() {
	local envelope="$1"
	local canonical digest
	canonical="$(jq -cS 'del(.integrity)' "${envelope}")"
	digest="$(printf '%s\n' "${canonical}" | sha256sum | cut -d' ' -f1)"
	jq --arg digest "${digest}" \
		'.integrity = {canonicalization: "jq-sorted-utf8-v1", envelope_sha256: $digest}' \
		"${envelope}" >"${envelope}.sealed"
	mv "${envelope}.sealed" "${envelope}"
}

write_valid_payload() {
	local envelope="$1"
	local manifest_sha payload_sha payload_bytes
	mkdir -p "${PAYLOAD_ROOT}/payloads/config"
	printf '%s\n' '{"schema":"starter-manifest/v1","operations":[]}' >"${PAYLOAD_ROOT}/manifest.json"
	printf '%s\n' 'managed=true' >"${PAYLOAD_ROOT}/payloads/config/starter.conf"
	manifest_sha="$(sha256sum "${PAYLOAD_ROOT}/manifest.json" | cut -d' ' -f1)"
	payload_sha="$(sha256sum "${PAYLOAD_ROOT}/payloads/config/starter.conf" | cut -d' ' -f1)"
	payload_bytes="$(wc -c <"${PAYLOAD_ROOT}/payloads/config/starter.conf")"

	jq -n \
		--arg manifest_sha "${manifest_sha}" \
		--arg payload_sha "${payload_sha}" \
		--argjson payload_bytes "${payload_bytes}" \
		'{
			schema: "gentle-starter.release-payload/v1",
			source: {adapter_id: "FixtureSource/v1", source_id: ("sha256:" + ("1" * 64))},
			release: {id: ("sha256:" + ("2" * 64)), version: "1.2.3", predecessor_id: null},
			immutable_identities: [
				{role: "release", id: ("sha256:" + ("2" * 64))},
				{role: "content", id: ("sha256:" + ("3" * 64))}
			],
			manifest: {schema: "starter-manifest/v1", path: "manifest.json", sha256: $manifest_sha},
			payload: {
				root: "payloads",
				entries: [{path: "config/starter.conf", sha256: $payload_sha, bytes: $payload_bytes}]
			},
			evidence: {
				adapter_id: "FixtureSource/v1",
				ref: "fixture-evidence:release-1.2.3",
				sha256: ("5" * 64)
			}
		}' >"${envelope}"
	seal_envelope "${envelope}"
}

@test "release payload rejects an unknown schema without writes" {
	local envelope="${TEST_ROOT}/unknown-schema.json"
	local before after
	printf '%s\n' '{"schema":"gentle-starter.release-payload/v2"}' >"${envelope}"
	before="$(snapshot_tree "${PAYLOAD_ROOT}")"

	run bash -c "source '${CONTRACT}'; release_payload_validate '${envelope}' '${PAYLOAD_ROOT}'"

	[ "$status" -ne 0 ]
	[[ "$output" == *"unsupported release payload schema"* ]]
	after="$(snapshot_tree "${PAYLOAD_ROOT}")"
	[ "${after}" = "${before}" ]
}

@test "release payload rejects Git-shaped core fields without writes" {
	local envelope="${TEST_ROOT}/git-shaped.json"
	local before after
	write_valid_payload "${envelope}"
	jq '.git = {tag_oid: "0123456789abcdef"}' "${envelope}" >"${envelope}.tmp"
	mv "${envelope}.tmp" "${envelope}"
	seal_envelope "${envelope}"
	before="$(snapshot_tree "${PAYLOAD_ROOT}")"

	run bash -c "source '${CONTRACT}'; release_payload_validate '${envelope}' '${PAYLOAD_ROOT}'"

	[ "$status" -ne 0 ]
	[[ "$output" == *"invalid release payload envelope"* ]]
	after="$(snapshot_tree "${PAYLOAD_ROOT}")"
	[ "${after}" = "${before}" ]
}

@test "release payload accepts neutral identities and validates materialized bytes" {
	local envelope="${TEST_ROOT}/valid.json"
	write_valid_payload "${envelope}"

	run bash -c "source '${CONTRACT}'; release_payload_validate '${envelope}' '${PAYLOAD_ROOT}'"
	[ "$status" -eq 0 ]

	printf '%s\n' 'tampered=true' >"${PAYLOAD_ROOT}/payloads/config/starter.conf"
	run bash -c "source '${CONTRACT}'; release_payload_validate '${envelope}' '${PAYLOAD_ROOT}'"
	[ "$status" -ne 0 ]
	[[ "$output" == *"release payload entry digest mismatch"* ]]
}

@test "source acquisition port returns only a validated neutral result" {
	local envelope="${TEST_ROOT}/source-result.json"
	local request="${TEST_ROOT}/request.json"
	write_valid_payload "${envelope}"
	printf '%s\n' '{"release_version":"1.2.3"}' >"${request}"

	run bash -c "
		source '${CONTRACT}'
		fixture_source_acquire() {
			jq -n --arg envelope_file '${envelope}' --arg payload_root '${PAYLOAD_ROOT}' \
				'{envelope_file: \$envelope_file, payload_root: \$payload_root}'
		}
		STARTER_SOURCE_ACQUIRE_IMPL=fixture_source_acquire source_acquire '${request}'
	"

	[ "$status" -eq 0 ]
	[ "$(jq -r '.envelope_file' <<<"${output}")" = "${envelope}" ]
	[ "$(jq -r '.payload_root' <<<"${output}")" = "${PAYLOAD_ROOT}" ]
	[ "$(jq 'keys | length' <<<"${output}")" -eq 2 ]
}

@test "repository status adapter emits only neutral cleanliness data" {
	local repository="${TEST_ROOT}/repository"
	mkdir -p "${repository}"
	git init -q "${repository}"
	git -C "${repository}" config user.name "Repository Status Test"
	git -C "${repository}" config user.email "repository-status@example.invalid"
	printf '%s\n' clean >"${repository}/tracked.txt"
	git -C "${repository}" add tracked.txt
	git -C "${repository}" commit -q -m fixture

	run bash -c "source '${REPOSITORY_STATUS_ADAPTER}'; STARTER_REPOSITORY_STATUS_IMPL=git_repository_status_inspect repository_status_inspect '${repository}'"
	[ "$status" -eq 0 ]
	jq -e '. == {schema:"gentle-starter.repository-status/v1",is_repository:true,root_matches:true,clean:true}' <<<"${output}" >/dev/null

	printf '%s\n' dirty >"${repository}/untracked.txt"
	run bash -c "source '${REPOSITORY_STATUS_ADAPTER}'; STARTER_REPOSITORY_STATUS_IMPL=git_repository_status_inspect repository_status_inspect '${repository}'"
	[ "$status" -eq 0 ]
	[ "$(jq -r '.clean' <<<"${output}")" = false ]
	[ "$(jq 'has("git") or has("index") or has("worktree")' <<<"${output}")" = false ]
}

@test "state core consumes repository status through the port without invoking Git" {
	local stubs="${TEST_ROOT}/stubs" sentinel="${TEST_ROOT}/git-invoked" project="${TEST_ROOT}/project"
	mkdir -p "${stubs}" "${project}"
	printf '%s\n' '#!/bin/sh' 'touch "${GIT_INVOCATION_SENTINEL:?}"' 'exit 91' >"${stubs}/git"
	chmod 0700 "${stubs}/git"

	run env PATH="${stubs}:${PATH}" GIT_INVOCATION_SENTINEL="${sentinel}" bash -c '
		source "$1"
		fixture_repository_status() {
			jq -cn '\''{schema:"gentle-starter.repository-status/v1",is_repository:true,root_matches:true,clean:true}'\''
		}
		STARTER_REPOSITORY_STATUS_IMPL=fixture_repository_status starter_state_require_clean_workspace "$2"
	' _ "${STATE_CORE}" "${project}"

	[ "$status" -eq 0 ]
	[ ! -e "${sentinel}" ]
}

@test "strict quality configuration covers nested starter production scripts" {
	run bash -c 'case "$(cat "$1")" in *".taskfiles/scripts/starter-lib/*/*.sh"*) exit 0 ;; *) exit 1 ;; esac' _ "${QUALITY_CONFIG}"
	[ "$status" -eq 0 ]
}
