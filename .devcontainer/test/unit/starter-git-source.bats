#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	CONTRACT="${REPO_ROOT}/.taskfiles/scripts/starter-lib/contracts/source-port.sh"
	ADAPTER="${REPO_ROOT}/.taskfiles/scripts/starter-lib/adapters/git-tag-source.sh"
	PLANNER="${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/planner.sh"
	FIXTURES="${BATS_TEST_DIRNAME}/../fixtures/starter-trust"
	TEST_ROOT="$(mktemp -d)"
	SIGN_HOME="${TEST_ROOT}/sign-home"
	mkdir -m 700 "${SIGN_HOME}"
	GNUPGHOME="${SIGN_HOME}" gpg --batch --quiet --import "${FIXTURES}/test-private-key.asc"
	SIGNER="06069EE0F0389C909090BF9D045AEADB4E22686A"
	SIGN_PROGRAM="${TEST_ROOT}/fixed-gpg"
	printf '%s\n' '#!/bin/sh' 'exec gpg --faked-system-time 1704153600 "$@"' >"${SIGN_PROGRAM}"
	chmod 0700 "${SIGN_PROGRAM}"
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

write_policy() {
	local revoked_at="${1:-}"
	local max_objects="${2:-100000}" max_object_bytes="${3:-67108864}"
	local max_pack_bytes="${4:-268435456}" max_retained_bytes="${5:-536870912}"
	local revocations='[]'
	[ -z "${revoked_at}" ] || revocations="[{\"subject_id\":\"openpgp:${SIGNER}\",\"effective_version\":\"${revoked_at}\",\"reason\":\"fixture revocation\"}]"
	jq -n --arg signer "openpgp:${SIGNER}" --argjson revocations "${revocations}" \
		--argjson max_objects "${max_objects}" --argjson max_object_bytes "${max_object_bytes}" \
		--argjson max_pack_bytes "${max_pack_bytes}" --argjson max_retained_bytes "${max_retained_bytes}" '{
		schema:"gentle-starter.signer-policy/v1", policy_id:"git-source-fixture/v1",
		signers:[{subject_id:$signer,key_file:"test-public-key.asc",valid_from:"1.0.0",valid_until:null}],
		revocations:$revocations, rotations:[], evidence_limits:{
			max_reachable_objects:$max_objects,max_object_bytes:$max_object_bytes,
			max_pack_bytes:$max_pack_bytes,max_retained_bytes:$max_retained_bytes
		}
	}' >"${TEST_ROOT}/policy.json"
}

create_remote() {
	local version="$1" mode="${2:-valid}" signed="${3:-signed}" layout="${4:-payload-only}"
	local work="${TEST_ROOT}/work-${version}" remote="${TEST_ROOT}/remote-${version}.git"
	local payload_sha payload_bytes migration_sha commit_oid tree_oid manifest_blob manifest_sha message
	mkdir -p "${work}/payloads/bin"
	git init -q "${work}"
	git -C "${work}" config user.name "Starter Test"
	git -C "${work}" config user.email "starter-test@example.invalid"
	git -C "${work}" config user.signingkey "${SIGNER}"
	git -C "${work}" config gpg.program "${SIGN_PROGRAM}"
	printf '%s\n' '#!/bin/sh' 'touch "${STARTER_EXECUTION_SENTINEL:?}"' >"${work}/payloads/bin/README.sh"
	chmod 0755 "${work}/payloads/bin/README.sh"
	payload_sha="$(sha256sum "${work}/payloads/bin/README.sh" | cut -d' ' -f1)"
	payload_bytes="$(wc -c <"${work}/payloads/bin/README.sh")"
	jq -n --arg version "${version}" --arg sha "${payload_sha}" --argjson bytes "${payload_bytes}" '{
		schema:"starter-manifest/v1", source:{id:"gentle-starter",release:("starter/v"+$version)},
		release:{version:$version,predecessor_id:null}, payload:{root:"payloads",entries:[{path:"bin/README.sh",sha256:$sha,bytes:$bytes}]}
	}' >"${work}/manifest.json"
	if [ "${layout}" = lifecycle ]; then
		mkdir -p "${work}/migrations"
		jq -n --arg from "${version%.*}.$((${version##*.} - 1))" --arg to "${version}" '{
			schema:"starter-migration/v1",id:"lifecycle",from_version:$from,to_version:$to,operations:[
				{type:"copy",ownership:"managed",source:"bin/README.sh",target:"bin/README.sh",expected_before_sha256:null}
			]
		}' >"${work}/migrations/010-lifecycle.json"
		migration_sha="$(sha256sum "${work}/migrations/010-lifecycle.json" | cut -d' ' -f1)"
		jq --arg sha "${migration_sha}" '.migrations={root:"migrations",entries:[{id:"lifecycle",path:"010-lifecycle.json",sha256:$sha}]}' \
			"${work}/manifest.json" >"${work}/manifest.tmp"
		mv "${work}/manifest.tmp" "${work}/manifest.json"
	fi
	git -C "${work}" add manifest.json payloads migrations 2>/dev/null || git -C "${work}" add manifest.json payloads
	GIT_AUTHOR_DATE=1704067200 GIT_COMMITTER_DATE=1704067200 git -C "${work}" commit -q -m "fixture ${version}"
	commit_oid="$(git -C "${work}" rev-parse HEAD)"
	tree_oid="$(git -C "${work}" rev-parse 'HEAD^{tree}')"
	manifest_blob="$(git -C "${work}" rev-parse 'HEAD:manifest.json')"
	manifest_sha="$(sha256sum "${work}/manifest.json" | cut -d' ' -f1)"
	case "${mode}" in
		release) version="9.9.9" ;;
		commit) commit_oid="$(printf '0%.0s' {1..40})" ;;
		tree) tree_oid="$(printf '1%.0s' {1..40})" ;;
		manifest) manifest_sha="$(printf '2%.0s' {1..64})" ;;
	esac
	message="$(jq -cn --arg version "${version}" --arg commit "${commit_oid}" --arg tree "${tree_oid}" --arg blob "${manifest_blob}" --arg sha "${manifest_sha}" '{schema:"gentle-starter.git-tag/v1",source_id:"gentle-starter",version:$version,commit_oid:$commit,tree_oid:$tree,manifest:{path:"manifest.json",blob_oid:$blob,sha256:$sha}}')"
	if [ "${signed}" = signed ]; then
		GNUPGHOME="${SIGN_HOME}" GIT_COMMITTER_DATE=1704153600 git -C "${work}" tag -s -m "${message}" "starter/v$1"
	else
		GIT_COMMITTER_DATE=1704153600 git -C "${work}" tag -a -m "${message}" "starter/v$1"
	fi
	git init -q --bare "${remote}"
	git -C "${work}" remote add fixture "${remote}"
	git -C "${work}" push -q fixture HEAD:refs/heads/main "refs/tags/starter/v$1"
	REMOTE="${remote}"
}

write_request() {
	local selector="$1" output="$2" remote="${3:-file://${REMOTE}}" governance_file="${4:-}"
	jq -n --arg remote "${remote}" --arg selector "${selector}" --arg output "${output}" \
		--arg policy "${TEST_ROOT}/policy.json" --arg key "${FIXTURES}/test-public-key.asc" \
		--arg governance_file "${governance_file}" '{
		schema:"gentle-starter.git-tag-source-request/v1",source_id:"gentle-starter",remote:$remote,
		selector:$selector,output_dir:$output,policy_file:$policy,key_file:$key
	} | if $governance_file == "" then . else .publisher_governance_file=$governance_file end' >"${TEST_ROOT}/request.json"
}

acquire() {
	bash -c "source '${CONTRACT}'; source '${ADAPTER}'; STARTER_SOURCE_ACQUIRE_IMPL=git_tag_source_acquire source_acquire '${TEST_ROOT}/request.json'"
}

acquire_from() {
	local working_directory="$1"
	bash -c "cd '\$1'; source '${CONTRACT}'; source '${ADAPTER}'; STARTER_SOURCE_ACQUIRE_IMPL=git_tag_source_acquire source_acquire '${TEST_ROOT}/request.json'" _ "${working_directory}"
}

@test "GitTagSource admits an exact signed semantic tag into a neutral envelope" {
	local candidate="${TEST_ROOT}/candidate" before_head before_status before_remotes
	write_policy
	create_remote 1.2.3
	write_request starter/v1.2.3 "${candidate}"
	before_head="$(git -C "${REPO_ROOT}" rev-parse HEAD)"
	before_status="$(git -C "${REPO_ROOT}" status --porcelain=v1)"
	before_remotes="$(git -C "${REPO_ROOT}" remote -v)"

	export STARTER_EXECUTION_SENTINEL="${TEST_ROOT}/executed"
	run acquire

	[ "$status" -eq 0 ]
	[ "$(jq -r '.schema' "${candidate}/envelope.json")" = "gentle-starter.verified-payload/v1" ]
	[ "$(jq -r '.release.version' "${candidate}/envelope.json")" = "1.2.3" ]
	[ "$(jq -r '.source.adapter_id' "${candidate}/envelope.json")" = "GitTagSource/v1" ]
	[ "$(jq 'has("git") or ([paths(scalars) as $p | $p[-1] | strings | test("tag_oid|commit_oid|tree_oid|blob_oid")] | any)' "${candidate}/envelope.json")" = false ]
	[ "$(jq '([paths(scalars) as $p | $p[-1] | strings | test("max_reachable_objects|max_object_bytes|max_pack_bytes|max_retained_bytes")] | any)' "${candidate}/envelope.json")" = false ]
	[ "$(jq '.closure | length' "${candidate}/evidence/index.json")" -ge 4 ]
	[ ! -e "${TEST_ROOT}/executed" ]
	[ "$(git -C "${REPO_ROOT}" rev-parse HEAD)" = "${before_head}" ]
	[ "$(git -C "${REPO_ROOT}" status --porcelain=v1)" = "${before_status}" ]
	[ "$(git -C "${REPO_ROOT}" remote -v)" = "${before_remotes}" ]
}

@test "GitTagSource rejects branch selectors before creating output" {
	write_policy
	create_remote 1.2.3
	write_request main "${TEST_ROOT}/candidate"
	run acquire
	[ "$status" -ne 0 ]
	[[ "$output" == *"selector must be an exact starter semantic tag"* ]]
	[ ! -e "${TEST_ROOT}/candidate" ]
}

@test "GitTagSource rejects relative absolute and nested-cwd repository selectors without output" {
	local relative nested_relative nested="${TEST_ROOT}/nested/work"
	write_policy
	create_remote 1.2.3
	relative="$(realpath --relative-to="${REPO_ROOT}" "${REMOTE}")"
	write_request starter/v1.2.3 "${TEST_ROOT}/relative-candidate" "${relative}"
	run acquire
	[ "$status" -ne 0 ]
	[[ "$output" == *"remote must be an explicit URL"* ]]
	[ ! -e "${TEST_ROOT}/relative-candidate" ]

	write_request starter/v1.2.3 "${TEST_ROOT}/absolute-candidate" "${REMOTE}"
	run acquire
	[ "$status" -ne 0 ]
	[[ "$output" == *"remote must be an explicit URL"* ]]
	[ ! -e "${TEST_ROOT}/absolute-candidate" ]

	mkdir -p "${nested}"
	nested_relative="$(realpath --relative-to="${nested}" "${REMOTE}")"
	write_request starter/v1.2.3 "${TEST_ROOT}/nested-candidate" "${nested_relative}"
	run acquire_from "${nested}"
	[ "$status" -ne 0 ]
	[[ "$output" == *"remote must be an explicit URL"* ]]
	[ ! -e "${TEST_ROOT}/nested-candidate" ]
}

@test "GitTagSource rejects unsigned and policy-revoked tags" {
	write_policy
	create_remote 1.2.4 valid unsigned
	write_request starter/v1.2.4 "${TEST_ROOT}/unsigned"
	run acquire
	[ "$status" -ne 0 ]
	[[ "$output" == *"annotated tag signature is invalid"* ]]
	write_policy 1.0.0
	create_remote 1.2.5
	write_request starter/v1.2.5 "${TEST_ROOT}/revoked"
	run acquire
	[ "$status" -ne 0 ]
	[[ "$output" == *"signer is revoked"* ]]
}

@test "publisher governance context never admits or claims verification for an unsigned tag" {
	local governance="${TEST_ROOT}/publisher-governance.json"
	write_policy
	create_remote 1.2.6 valid unsigned
	printf '%s\n' '{"protected_release_tags_documented":true,"publication_audit":"publisher-controlled"}' >"${governance}"
	write_request starter/v1.2.6 "${TEST_ROOT}/governance-rejected" "file://${REMOTE}" "${governance}"

	run acquire

	[ "$status" -ne 0 ]
	[[ "$output" == *"annotated tag signature is invalid"* ]]
	[[ ! "$output" =~ ([Hh]osting|[Pp]rotection|[Gg]overnance).*[Vv]erified ]]
	[ ! -e "${TEST_ROOT}/governance-rejected" ]
}

@test "GitTagSource rejects every exceeded retained evidence limit before admission" {
	local metric output expected
	write_policy
	create_remote 6.0.0
	for metric in objects object-bytes pack-bytes retained-bytes; do
		case "${metric}" in
		objects)
			write_policy "" 1 67108864 268435456 536870912
			expected="reachable object count exceeds policy limit"
			;;
		object-bytes)
			write_policy "" 100000 1 268435456 536870912
			expected="per-object size exceeds policy limit"
			;;
		pack-bytes)
			write_policy "" 100000 67108864 1 536870912
			expected="pack size exceeds policy limit"
			;;
		retained-bytes)
			write_policy "" 100000 67108864 268435456 1
			expected="aggregate retained bytes exceed policy limit"
			;;
		esac
		output="${TEST_ROOT}/limit-${metric}"
		write_request starter/v6.0.0 "${output}"
		run acquire
		[ "$status" -ne 0 ]
		[[ "$output" == *"${expected}"* ]]
		[ ! -e "${TEST_ROOT}/limit-${metric}" ]
	done
}

@test "GitTagSource accepts retained evidence exactly at every configured boundary" {
	local baseline="${TEST_ROOT}/boundary-a" boundary="${TEST_ROOT}/boundary-b"
	local object_count max_object_bytes pack_bytes=0 retained_bytes pack
	write_policy
	create_remote 6.0.1
	write_request starter/v6.0.1 "${baseline}"
	run acquire
	[ "$status" -eq 0 ]
	object_count="$(jq '.closure | length' "${baseline}/evidence/index.json")"
	max_object_bytes="$(jq '[.closure[].bytes] | max' "${baseline}/evidence/index.json")"
	retained_bytes="$(jq '[.closure[].bytes] | add' "${baseline}/evidence/index.json")"
	for pack in "${baseline}"/evidence/repository.git/objects/pack/*.pack; do
		[ -f "${pack}" ] || continue
		pack_bytes=$((pack_bytes + $(wc -c <"${pack}")))
	done
	[ "${pack_bytes}" -gt 0 ]

	write_policy "" "${object_count}" "${max_object_bytes}" "${pack_bytes}" "${retained_bytes}"
	write_request starter/v6.0.1 "${boundary}"
	run acquire

	[ "$status" -eq 0 ]
	[ -f "${boundary}/evidence/index.json" ]
	[ "$(jq '.closure | length' "${boundary}/evidence/index.json")" -eq "${object_count}" ]
}

@test "GitTagSource rejects signed release commit tree and manifest binding mismatches" {
	local mode version index=0
	write_policy
	for mode in release commit tree manifest; do
		index=$((index + 1))
		version="2.0.${index}"
		create_remote "${version}" "${mode}"
		write_request "starter/v${version}" "${TEST_ROOT}/${mode}"
		run acquire
		[ "$status" -ne 0 ]
		[[ "$output" == *"${mode} binding mismatch"* ]]
	done
}

@test "GitTagSource rejects corrupt retained evidence" {
	local candidate="${TEST_ROOT}/candidate" evidence
	write_policy
	create_remote 3.0.0
	write_request starter/v3.0.0 "${candidate}"
	run acquire
	[ "$status" -eq 0 ]
	evidence="$(jq -r '.evidence.ref' "${candidate}/envelope.json")"
	jq '.tree_oid = ("f" * 40)' "${evidence}/index.json" >"${evidence}/index.tmp"
	mv "${evidence}/index.tmp" "${evidence}/index.json"
	run bash -c "source '${CONTRACT}'; source '${ADAPTER}'; STARTER_EVIDENCE_REVALIDATE_IMPL=git_tag_evidence_revalidate evidence_revalidate '${evidence}'"
	[ "$status" -ne 0 ]
	[[ "$output" == *"evidence digest mismatch"* ]]
}

@test "retained closure revalidates after remote deletion while new acquisition fails closed" {
	local candidate="${TEST_ROOT}/candidate" evidence
	write_policy
	create_remote 4.0.0
	write_request starter/v4.0.0 "${candidate}"
	run acquire
	[ "$status" -eq 0 ]
	evidence="$(jq -r '.evidence.ref' "${candidate}/envelope.json")"
	rm -rf "${REMOTE}"
	run bash -c "source '${CONTRACT}'; source '${ADAPTER}'; STARTER_EVIDENCE_REVALIDATE_IMPL=git_tag_evidence_revalidate evidence_revalidate '${evidence}'"
	[ "$status" -eq 0 ]
	write_request starter/v4.0.0 "${TEST_ROOT}/unavailable"
	run acquire
	[ "$status" -ne 0 ]
	[[ "$output" == *"exact tag is unavailable"* ]]
	[ ! -e "${TEST_ROOT}/unavailable" ]
}

@test "GitTagSource materializes lifecycle descriptors for neutral opaque planning" {
	local candidate="${TEST_ROOT}/candidate"
	write_policy
	create_remote 5.0.1 valid signed lifecycle
	write_request starter/v5.0.1 "${candidate}"
	export STARTER_EXECUTION_SENTINEL="${TEST_ROOT}/executed"

	run acquire

	[ "$status" -eq 0 ]
	[ -f "${candidate}/materialized/migrations/010-lifecycle.json" ]
	run /usr/bin/bash -c "source '${PLANNER}'; starter_plan_build \"\$1\" 5.0.0" _ "${output}"
	[ "$status" -eq 0 ]
	[ "$(jq -r '.operations[0].source' <<<"${output}")" = "bin/README.sh" ]
	[ ! -e "${STARTER_EXECUTION_SENTINEL}" ]
}
