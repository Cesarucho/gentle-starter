#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	CONTRACT="${REPO_ROOT}/.taskfiles/scripts/starter-lib/contracts/source-port.sh"
	ADAPTER="${REPO_ROOT}/.taskfiles/scripts/starter-lib/adapters/git-tag-source.sh"
	PLANNER="${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/planner-v2.sh"
	TEST_ROOT="$(mktemp -d)"
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

create_remote() {
	local version="$1" mode="${2:-valid}" tag_type="${3:-annotated}" layout="${4:-payload-only}"
	local work="${TEST_ROOT}/work-${version}" remote="${TEST_ROOT}/remote-${version}.git"
	local distribution="${work}/.starter/distribution" manifest_path=.starter/distribution/manifest.json
	local payload_sha payload_bytes migration_sha ownership_sha commit_oid tree_oid manifest_blob manifest_sha message
	mkdir -p "${distribution}/payloads/bin"
	git init -q "${work}"
	git -C "${work}" config user.name "Starter Test"
	git -C "${work}" config user.email "starter-test@example.invalid"
	printf '%s\n' '#!/bin/sh' 'touch "${STARTER_EXECUTION_SENTINEL:?}"' >"${distribution}/payloads/bin/README.sh"
	chmod 0755 "${distribution}/payloads/bin/README.sh"
	payload_sha="$(sha256sum "${distribution}/payloads/bin/README.sh" | cut -d' ' -f1)"
	payload_bytes="$(wc -c <"${distribution}/payloads/bin/README.sh")"
	jq -n '{schema:"gentle-starter.ownership-inventory/v2",default_ownership:"project-owned",
		managed:[{match:"exact",path:"bin/README.sh"}],fusion:[
		{match:"exact",path:".devcontainer/devcontainer.json",contract:"F-manual/v1"},
		{match:"exact",path:".devcontainer/docker-compose.yml",contract:"F-manual/v1"}]}' >"${distribution}/ownership.json"
	ownership_sha="$(sha256sum "${distribution}/ownership.json" | cut -d' ' -f1)"
	jq -n --arg version "${version}" --arg sha "${payload_sha}" --argjson bytes "${payload_bytes}" --arg ownership_sha "${ownership_sha}" '{
		schema:"starter-manifest/v2", source:{id:"gentle-starter",release:("starter/v"+$version)},
		release:{version:$version,predecessor_version:"0.0.0",predecessor_id:null},
		identities:{official_tree:("sha256:"+("a"*64)),derived_tree:("sha256:"+("b"*64))},
		transformation:{schema:"gentle-starter.derived-tree-transformation/v1"},
		ownership:{schema:"gentle-starter.ownership-inventory/v2",path:"ownership.json",sha256:$ownership_sha},
		payload:{root:"payloads",closure:"exact",entries:[{path:"bin/README.sh",sha256:$sha,bytes:$bytes,mode:"755",presence:"present"}]},
		migrations:{root:"migrations",entries:[]}
	}' >"${distribution}/manifest.json"
	if [ "${layout}" = lifecycle ]; then
		mkdir -p "${distribution}/migrations"
		jq -n --arg from "${version%.*}.$((${version##*.} - 1))" --arg to "${version}" --arg sha "${payload_sha}" '{
			schema:"starter-migration/v2",id:"lifecycle",from_version:$from,to_version:$to,operations:[
				{type:"copy",ownership:"managed",source:"bin/README.sh",target:"bin/README.sh",
				expected_before:{presence:"any",sha256:null,mode:null},after:{presence:"present",sha256:$sha,mode:"755"}}
			]
		}' >"${distribution}/migrations/010-lifecycle.json"
		migration_sha="$(sha256sum "${distribution}/migrations/010-lifecycle.json" | cut -d' ' -f1)"
		jq --arg sha "${migration_sha}" '.migrations={root:"migrations",entries:[{id:"lifecycle",path:"010-lifecycle.json",sha256:$sha}]}' \
			"${distribution}/manifest.json" >"${distribution}/manifest.tmp"
		mv "${distribution}/manifest.tmp" "${distribution}/manifest.json"
	fi
	if [ "${mode}" = path ]; then
		mkdir -p "${work}/another"
		cp "${distribution}/manifest.json" "${work}/another/manifest.json"
		manifest_path=another/manifest.json
	fi
	git -C "${work}" add .starter another 2>/dev/null || git -C "${work}" add .starter
	GIT_AUTHOR_DATE=1704067200 GIT_COMMITTER_DATE=1704067200 git -C "${work}" commit -q -m "fixture ${version}"
	commit_oid="$(git -C "${work}" rev-parse HEAD)"
	tree_oid="$(git -C "${work}" rev-parse 'HEAD^{tree}')"
	manifest_blob="$(git -C "${work}" rev-parse "HEAD:${manifest_path}")"
	manifest_sha="$(sha256sum "${work}/${manifest_path}" | cut -d' ' -f1)"
	case "${mode}" in
	release) version="9.9.9" ;;
	commit) commit_oid="$(printf '0%.0s' {1..40})" ;;
	tree) tree_oid="$(printf '1%.0s' {1..40})" ;;
	manifest) manifest_sha="$(printf '2%.0s' {1..64})" ;;
	esac
	message="$(jq -cn --arg version "${version}" --arg commit "${commit_oid}" --arg tree "${tree_oid}" --arg path "${manifest_path}" --arg blob "${manifest_blob}" --arg sha "${manifest_sha}" '{schema:"gentle-starter.git-tag/v1",source_id:"gentle-starter",version:$version,commit_oid:$commit,tree_oid:$tree,manifest:{path:$path,blob_oid:$blob,sha256:$sha}}')"
	if [ "${tag_type}" = annotated ]; then
		GIT_COMMITTER_DATE=1704153600 git -C "${work}" tag -a -m "${message}" "starter/v$1"
	else
		git -C "${work}" tag "starter/v$1"
	fi
	git init -q --bare "${remote}"
	git -C "${work}" remote add fixture "${remote}"
	git -C "${work}" push -q fixture HEAD:refs/heads/main "refs/tags/starter/v$1"
	REMOTE="${remote}"
}

write_request() {
	local selector="$1" output="$2" remote="${3:-file://${REMOTE}}"
	jq -n --arg remote "${remote}" --arg selector "${selector}" --arg output "${output}" \
		'{
		schema:"gentle-starter.git-tag-source-request/v1",source_id:"gentle-starter",remote:$remote,
		selector:$selector,output_dir:$output
	}' >"${TEST_ROOT}/request.json"
}

acquire() {
	bash -c "source '${CONTRACT}'; source '${ADAPTER}'; STARTER_SOURCE_ACQUIRE_IMPL=git_tag_source_acquire source_acquire '${TEST_ROOT}/request.json'"
}

acquire_from() {
	local working_directory="$1"
	bash -c "cd '\$1'; source '${CONTRACT}'; source '${ADAPTER}'; STARTER_SOURCE_ACQUIRE_IMPL=git_tag_source_acquire source_acquire '${TEST_ROOT}/request.json'" _ "${working_directory}"
}

discover_from_listing() {
	local listing="$1"
	bash -c '
		source "$1"
		source "$2"
		FIXTURE_REFS="$3"
		fixture_refs() { cat "${FIXTURE_REFS}"; }
		STARTER_DISCOVERY_LIST_REFS_IMPL=fixture_refs git_tag_discover_latest_release file:///fixture.git
	' _ "${CONTRACT}" "${ADAPTER}" "${listing}"
}

@test "GitTagSource discovery selects the highest stable annotated semantic release" {
	local listing="${TEST_ROOT}/refs"
	cat >"${listing}" <<EOF
1111111111111111111111111111111111111111	refs/heads/main
2222222222222222222222222222222222222222	refs/tags/starter/v1.9.0
3333333333333333333333333333333333333333	refs/tags/starter/v1.9.0^{}
4444444444444444444444444444444444444444	refs/tags/starter/v1.10.0
5555555555555555555555555555555555555555	refs/tags/starter/v1.10.0^{}
6666666666666666666666666666666666666666	refs/tags/starter/v2.0.0-rc.1
7777777777777777777777777777777777777777	refs/tags/starter/v9.0.0
EOF

	run discover_from_listing "${listing}"

	[ "$status" -eq 0 ]
	[ "$output" = starter/v1.10.0 ]
}

@test "GitTagSource discovery fails closed for missing malformed conflicting and bounded refs" {
	local listing="${TEST_ROOT}/refs"
	: >"${listing}"
	run discover_from_listing "${listing}"
	[ "$status" -ne 0 ]
	[[ "$output" == *"no valid exact annotated starter releases"* ]]

	printf 'not-a-ref-line\n' >"${listing}"
	run discover_from_listing "${listing}"
	[ "$status" -ne 0 ]
	[[ "$output" == *"listing is malformed"* ]]

	printf '1%.0s' {1..40} >"${listing}"
	printf '\trefs/tags/starter/v1.0.0\n' >>"${listing}"
	printf '2%.0s' {1..40} >>"${listing}"
	printf '\trefs/tags/starter/v1.0.0\n' >>"${listing}"
	run discover_from_listing "${listing}"
	[ "$status" -ne 0 ]
	[[ "$output" == *"duplicate or conflicting identities"* ]]

	run env STARTER_DISCOVERY_MAX_BYTES=1 bash -c '
		source "$1"; source "$2"
		fixture_refs() { printf "%040d\\trefs/tags/starter/v1.0.0\\n" 1; }
		STARTER_DISCOVERY_LIST_REFS_IMPL=fixture_refs git_tag_discover_latest_release file:///fixture.git
	' _ "${CONTRACT}" "${ADAPTER}"
	[ "$status" -ne 0 ]
	[[ "$output" == *"exceeds discovery limit"* ]]
}

@test "GitTagSource admits an exact annotated semantic tag into a neutral envelope" {
	local candidate="${TEST_ROOT}/candidate" before_head before_status before_remotes
	create_remote 1.2.3
	write_request starter/v1.2.3 "${candidate}"
	before_head="$(git -C "${REPO_ROOT}" rev-parse HEAD)"
	before_status="$(git -C "${REPO_ROOT}" status --porcelain=v1)"
	before_remotes="$(git -C "${REPO_ROOT}" remote -v)"

	export STARTER_EXECUTION_SENTINEL="${TEST_ROOT}/executed"
	run acquire

	[ "$status" -eq 0 ]
	[ "$(jq -r '.schema' "${candidate}/envelope.json")" = "gentle-starter.release-payload/v2" ]
	[ "$(jq 'has("verification")' "${candidate}/envelope.json")" = false ]
	[ "$(jq -r '.release.version' "${candidate}/envelope.json")" = "1.2.3" ]
	[ "$(jq -r '.source.adapter_id' "${candidate}/envelope.json")" = "GitTagSource/v1" ]
	[ "$(jq 'has("git") or ([paths(scalars) as $p | $p[-1] | strings | test("tag_oid|commit_oid|tree_oid|blob_oid")] | any)' "${candidate}/envelope.json")" = false ]
	[ "$(jq '([paths(scalars) as $p | $p[-1] | strings | test("max_reachable_objects|max_object_bytes|max_pack_bytes|max_retained_bytes")] | any)' "${candidate}/envelope.json")" = false ]
	[ "$(jq '.closure | length' "${candidate}/evidence/index.json")" -ge 4 ]
	git --git-dir="${candidate}/evidence/repository.git" show-ref --verify --quiet refs/gentle-starter/releases/1.2.3
	! git --git-dir="${candidate}/evidence/repository.git" show-ref --verify --quiet refs/tags/starter/v1.2.3
	[ ! -e "${TEST_ROOT}/executed" ]
	[ "$(git -C "${REPO_ROOT}" rev-parse HEAD)" = "${before_head}" ]
	[ "$(git -C "${REPO_ROOT}" status --porcelain=v1)" = "${before_status}" ]
	[ "$(git -C "${REPO_ROOT}" remote -v)" = "${before_remotes}" ]
}

@test "GitTagSource rejects branch selectors before creating output" {
	create_remote 1.2.3
	write_request main "${TEST_ROOT}/candidate"
	run acquire
	[ "$status" -ne 0 ]
	[[ "$output" == *"selector must be an exact starter semantic tag"* ]]
	[ ! -e "${TEST_ROOT}/candidate" ]
}

@test "GitTagSource rejects relative absolute and nested-cwd repository selectors without output" {
	local relative nested_relative nested="${TEST_ROOT}/nested/work"
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

@test "GitTagSource rejects lightweight tags" {
	create_remote 1.2.4 valid lightweight
	write_request starter/v1.2.4 "${TEST_ROOT}/lightweight"
	run acquire
	[ "$status" -ne 0 ]
	[[ "$output" == *"selected ref is not an annotated tag"* ]]
	[ ! -e "${TEST_ROOT}/lightweight" ]
}

@test "GitTagSource rejects metadata that binds a noncanonical relative manifest path" {
	create_remote 1.2.5 path
	write_request starter/v1.2.5 "${TEST_ROOT}/noncanonical"
	run acquire
	[ "$status" -ne 0 ]
	[[ "$output" == *"annotated tag metadata is invalid"* ]]
	[ ! -e "${TEST_ROOT}/noncanonical" ]
}

@test "GitTagSource rejects every exceeded retained evidence limit before admission" {
	local metric output expected
	create_remote 6.0.0
	for metric in objects object-bytes pack-bytes retained-bytes; do
		case "${metric}" in
		objects)
			export STARTER_EVIDENCE_MAX_REACHABLE_OBJECTS=1 STARTER_EVIDENCE_MAX_OBJECT_BYTES=67108864 STARTER_EVIDENCE_MAX_PACK_BYTES=268435456 STARTER_EVIDENCE_MAX_RETAINED_BYTES=536870912
			expected="reachable object count exceeds evidence limit"
			;;
		object-bytes)
			export STARTER_EVIDENCE_MAX_REACHABLE_OBJECTS=100000 STARTER_EVIDENCE_MAX_OBJECT_BYTES=1 STARTER_EVIDENCE_MAX_PACK_BYTES=268435456 STARTER_EVIDENCE_MAX_RETAINED_BYTES=536870912
			expected="per-object size exceeds evidence limit"
			;;
		pack-bytes)
			export STARTER_EVIDENCE_MAX_REACHABLE_OBJECTS=100000 STARTER_EVIDENCE_MAX_OBJECT_BYTES=67108864 STARTER_EVIDENCE_MAX_PACK_BYTES=1 STARTER_EVIDENCE_MAX_RETAINED_BYTES=536870912
			expected="pack size exceeds evidence limit"
			;;
		retained-bytes)
			export STARTER_EVIDENCE_MAX_REACHABLE_OBJECTS=100000 STARTER_EVIDENCE_MAX_OBJECT_BYTES=67108864 STARTER_EVIDENCE_MAX_PACK_BYTES=268435456 STARTER_EVIDENCE_MAX_RETAINED_BYTES=1
			expected="aggregate retained bytes exceed evidence limit"
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

	export STARTER_EVIDENCE_MAX_REACHABLE_OBJECTS="${object_count}" STARTER_EVIDENCE_MAX_OBJECT_BYTES="${max_object_bytes}"
	export STARTER_EVIDENCE_MAX_PACK_BYTES="${pack_bytes}" STARTER_EVIDENCE_MAX_RETAINED_BYTES="${retained_bytes}"
	write_request starter/v6.0.1 "${boundary}"
	run acquire

	[ "$status" -eq 0 ]
	[ -f "${boundary}/evidence/index.json" ]
	[ "$(jq '.closure | length' "${boundary}/evidence/index.json")" -eq "${object_count}" ]
}

@test "GitTagSource rejects release commit tree and manifest binding mismatches" {
	local mode version index=0
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
	create_remote 5.0.1 valid annotated lifecycle
	write_request starter/v5.0.1 "${candidate}"
	export STARTER_EXECUTION_SENTINEL="${TEST_ROOT}/executed"

	run acquire

	[ "$status" -eq 0 ]
	[ -f "${candidate}/materialized/migrations/010-lifecycle.json" ]
	run /usr/bin/bash -c "source '${PLANNER}'; starter_plan_v2_build \"\$1\" 5.0.0" _ "${output}"
	[ "$status" -eq 0 ] || {
		printf '%s\n' "${output}" >&3
		false
	}
	[ "$(jq -r '.operations[0].source' <<<"${output}")" = "bin/README.sh" ]
	[ ! -e "${STARTER_EXECUTION_SENTINEL}" ]
}
