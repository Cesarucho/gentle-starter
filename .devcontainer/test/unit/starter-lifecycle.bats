#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	CONTRACT="${REPO_ROOT}/.taskfiles/scripts/starter-lib/contracts/source-port.sh"
	MANIFEST_CORE="${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/manifest.sh"
	MIGRATION_CORE="${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/migration.sh"
	PLANNER_CORE="${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/planner.sh"
	STATE_CORE="${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/state.sh"
	JOURNAL_CORE="${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/journal.sh"
	ROLLBACK_CORE="${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/rollback.sh"
	TEST_ROOT="$(mktemp -d)"
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

write_envelope() {
	local root="$1"
	local manifest_sha envelope_sha
	manifest_sha="$(sha256sum "${root}/manifest.json" | cut -d' ' -f1)"
	jq -n \
		--arg version "$(jq -r '.release.version' "${root}/manifest.json")" \
		--argjson predecessor "$(jq '.release.predecessor_id' "${root}/manifest.json")" \
		--arg manifest_sha "${manifest_sha}" \
		--argjson entries "$(jq '.payload.entries' "${root}/manifest.json")" \
		'{
			schema:"gentle-starter.verified-payload/v1",
			source:{adapter_id:"FixtureSource/v1",source_id:("sha256:"+("1"*64))},
			release:{id:("sha256:"+("2"*64)),version:$version,predecessor_id:$predecessor},
			immutable_identities:[
				{role:"release",id:("sha256:"+("2"*64))},
				{role:"content",id:("sha256:"+("3"*64))}
			],
			manifest:{schema:"starter-manifest/v1",path:"manifest.json",sha256:$manifest_sha},
			payload:{root:"payloads",entries:$entries},
			verification:{result:"accepted",policy_id:"fixture/v1",policy_sha256:("4"*64),signer_subject_id:"fixture:signer"},
			evidence:{adapter_id:"FixtureSource/v1",ref:"fixture:evidence",sha256:("5"*64)}
		}' >"${root}/envelope.json"
	envelope_sha="$(jq -cS 'del(.integrity)' "${root}/envelope.json" | sha256sum | cut -d' ' -f1)"
	jq --arg sha "${envelope_sha}" \
		'.integrity={canonicalization:"jq-sorted-utf8-v1",envelope_sha256:$sha}' \
		"${root}/envelope.json" >"${root}/envelope.tmp"
	mv "${root}/envelope.tmp" "${root}/envelope.json"
}

write_manifest() {
	local root="$1" version="$2" predecessor="$3"
	local payload_entries migration_entries
	payload_entries="$(
		find "${root}/payloads" -type f -printf '%P\n' | sort | while IFS= read -r path; do
			jq -cn --arg path "${path}" \
				--arg sha "$(sha256sum "${root}/payloads/${path}" | cut -d' ' -f1)" \
				--argjson bytes "$(wc -c <"${root}/payloads/${path}")" \
				'{path:$path,sha256:$sha,bytes:$bytes}'
		done | jq -s .
	)"
	migration_entries="$(
		find "${root}/migrations" -type f -name '*.json' -printf '%P\n' | sort | while IFS= read -r path; do
			jq -cn --arg id "$(jq -r '.id' "${root}/migrations/${path}")" --arg path "${path}" \
				--arg sha "$(sha256sum "${root}/migrations/${path}" | cut -d' ' -f1)" \
				'{id:$id,path:$path,sha256:$sha}'
		done | jq -s .
	)"
	jq -n --arg version "${version}" --argjson predecessor "${predecessor}" \
		--argjson payload_entries "${payload_entries}" --argjson migration_entries "${migration_entries}" '{
		schema:"starter-manifest/v1",source:{id:"gentle-starter",release:("starter/v"+$version)},
		release:{version:$version,predecessor_id:$predecessor},
		payload:{root:"payloads",entries:$payload_entries},
		migrations:{root:"migrations",entries:$migration_entries}
	}' >"${root}/manifest.json"
	write_envelope "${root}"
}

source_result() {
	jq -cn --arg envelope_file "$1/envelope.json" --arg payload_root "$1" \
		'{envelope_file:$envelope_file,payload_root:$payload_root}'
}

run_plan() {
	local root="$1" current_version="$2" project_root="${3:-${TEST_ROOT}/project}"
	mkdir -p "${project_root}"
	/usr/bin/bash -c "
		cd \"\$3\"
		source '${CONTRACT}'
		source '${MANIFEST_CORE}'
		source '${MIGRATION_CORE}'
		source '${PLANNER_CORE}'
		starter_plan_build \"\$1\" \"\$2\"
	" _ "$(source_result "${root}")" "${current_version}" "${project_root}"
}

project_digest() {
	local project_root="$1"
	tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner -cf - -C "${project_root}" . | sha256sum | cut -d' ' -f1
}

write_single_migration() {
	local root="$1" id="$2" from="$3" to="$4" operations="$5"
	jq -n --arg id "${id}" --arg from "${from}" --arg to "${to}" --argjson operations "${operations}" '{
		schema:"starter-migration/v1",id:$id,from_version:$from,to_version:$to,operations:$operations
	}' >"${root}/migrations/${id}.json"
}

initialize_state_fixture() {
	local root="${TEST_ROOT}/state-release" project="${TEST_ROOT}/state-project"
	local operations plan
	mkdir -p "${root}/payloads" "${root}/migrations" "${project}/.starter"
	printf '%s\n' 'managed release content' >"${root}/payloads/managed.txt"
	operations='[
		{"type":"copy","ownership":"managed","source":"managed.txt","target":"managed.txt","expected_before_sha256":null},
		{"type":"delete","ownership":"managed","source":null,"target":"obsolete.txt","expected_before_sha256":null}
	]'
	write_single_migration "${root}" state-baseline 1.0.0 2.0.0 "${operations}"
	write_manifest "${root}" 2.0.0 '"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
	printf '%s\n' 'managed release content' >"${project}/managed.txt"
	printf '%s\n' '{"purpose":"state-directory-anchor"}' >"${project}/.starter/anchor.json"
	git init -q "${project}"
	git -C "${project}" config user.name "Starter State Test"
	git -C "${project}" config user.email "starter-state@example.invalid"
	git -C "${project}" add managed.txt .starter/anchor.json
	git -C "${project}" commit -q -m "state fixture"
	plan="$(run_plan "${root}" 1.0.0 "${project}")"
	printf '%s\n' "$(source_result "${root}")" >"${TEST_ROOT}/state-source-result.json"
	printf '%s\n' "${plan}" >"${TEST_ROOT}/state-plan.json"
	STATE_RELEASE_ROOT="${root}"
	STATE_PROJECT_ROOT="${project}"
}

run_state_write() {
	run /usr/bin/bash -c '
		source "$1"
		starter_state_write_last "$2" "$(cat "$3")" "$(cat "$4")"
	' _ "${STATE_CORE}" "${STATE_PROJECT_ROOT}" \
		"${TEST_ROOT}/state-source-result.json" "${TEST_ROOT}/state-plan.json"
}

initialize_transaction_fixture() {
	local root="${TEST_ROOT}/transaction-release" project="${TEST_ROOT}/transaction-project"
	local old_managed_sha old_obsolete_sha operations plan
	mkdir -p "${root}/payloads" "${root}/migrations" "${project}/.starter" "${TEST_ROOT}/command-stubs"
	printf '%s\n' 'managed release content' >"${root}/payloads/managed.txt"
	printf '%s\n' 'managed project content' >"${project}/managed.txt"
	printf '%s\n' 'obsolete managed content' >"${project}/obsolete.txt"
	printf '%s\n' 'project-owned content' >"${project}/owned.txt"
	printf '%s\n' '{"purpose":"transaction-directory-anchor"}' >"${project}/.starter/anchor.json"
	old_managed_sha="$(sha256sum "${project}/managed.txt" | cut -d' ' -f1)"
	old_obsolete_sha="$(sha256sum "${project}/obsolete.txt" | cut -d' ' -f1)"
	operations="$(jq -cn --arg managed "${old_managed_sha}" --arg obsolete "${old_obsolete_sha}" '[
		{type:"copy",ownership:"managed",source:"managed.txt",target:"managed.txt",expected_before_sha256:$managed},
		{type:"delete",ownership:"managed",source:null,target:"obsolete.txt",expected_before_sha256:$obsolete}
	]')"
	write_single_migration "${root}" transaction-update 1.0.0 2.0.0 "${operations}"
	write_manifest "${root}" 2.0.0 '"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
	git init -q "${project}"
	git -C "${project}" config user.name "Starter Transaction Test"
	git -C "${project}" config user.email "starter-transaction@example.invalid"
	git -C "${project}" remote add origin https://example.invalid/project.git
	git -C "${project}" add managed.txt obsolete.txt owned.txt .starter/anchor.json
	git -C "${project}" commit -q -m "transaction fixture"
	plan="$(run_plan "${root}" 1.0.0 "${project}")"
	printf '%s\n' "$(source_result "${root}")" >"${TEST_ROOT}/transaction-source-result.json"
	printf '%s\n' "${plan}" >"${TEST_ROOT}/transaction-plan.json"
	printf '%s\n' 'external resource' >"${TEST_ROOT}/external-resource.txt"
	for command_name in docker podman; do
		printf '%s\n' '#!/usr/bin/env bash' 'touch "${STARTER_EXTERNAL_INVOCATION:?}"' 'exit 91' >"${TEST_ROOT}/command-stubs/${command_name}"
		chmod 0755 "${TEST_ROOT}/command-stubs/${command_name}"
	done
	TRANSACTION_RELEASE_ROOT="${root}"
	TRANSACTION_PROJECT_ROOT="${project}"
	export STARTER_EXTERNAL_INVOCATION="${TEST_ROOT}/external-invocation"
}

transaction_journal_file() {
	find "${TRANSACTION_PROJECT_ROOT}/.starter/journals" -name journal.json -type f -print -quit
}

run_transaction() {
	local failpoint="${1:-}"
	run env PATH="${TEST_ROOT}/command-stubs:${PATH}" STARTER_TRANSACTION_FAILPOINT="${failpoint}" \
		/usr/bin/bash -c '
			source "$1"
			starter_transaction_run "$2" "$(cat "$3")" "$(cat "$4")"
		' _ "${JOURNAL_CORE}" "${TRANSACTION_PROJECT_ROOT}" \
		"${TEST_ROOT}/transaction-source-result.json" "${TEST_ROOT}/transaction-plan.json"
}

run_transaction_recovery() {
	local journal_file="$1"
	run env PATH="${TEST_ROOT}/command-stubs:${PATH}" /usr/bin/bash -c '
		source "$1"
		starter_rollback_recover "$2" "$3"
	' _ "${ROLLBACK_CORE}" "${TRANSACTION_PROJECT_ROOT}" "${journal_file}"
}

snapshot_transaction_boundaries() {
	TRANSACTION_HEAD="$(git -C "${TRANSACTION_PROJECT_ROOT}" rev-parse HEAD)"
	TRANSACTION_HISTORY="$(git -C "${TRANSACTION_PROJECT_ROOT}" rev-list --all --objects)"
	TRANSACTION_REMOTES="$(git -C "${TRANSACTION_PROJECT_ROOT}" remote -v)"
	TRANSACTION_INDEX_SHA="$(sha256sum "${TRANSACTION_PROJECT_ROOT}/.git/index" | cut -d' ' -f1)"
	TRANSACTION_OWNED_SHA="$(sha256sum "${TRANSACTION_PROJECT_ROOT}/owned.txt" | cut -d' ' -f1)"
}

assert_transaction_boundaries_preserved() {
	[ "$(git -C "${TRANSACTION_PROJECT_ROOT}" rev-parse HEAD)" = "${TRANSACTION_HEAD}" ]
	[ "$(git -C "${TRANSACTION_PROJECT_ROOT}" rev-list --all --objects)" = "${TRANSACTION_HISTORY}" ]
	[ "$(git -C "${TRANSACTION_PROJECT_ROOT}" remote -v)" = "${TRANSACTION_REMOTES}" ]
	[ "$(sha256sum "${TRANSACTION_PROJECT_ROOT}/.git/index" | cut -d' ' -f1)" = "${TRANSACTION_INDEX_SHA}" ]
	[ "$(sha256sum "${TRANSACTION_PROJECT_ROOT}/owned.txt" | cut -d' ' -f1)" = "${TRANSACTION_OWNED_SHA}" ]
	[ "$(cat "${TEST_ROOT}/external-resource.txt")" = 'external resource' ]
	[ ! -e "${STARTER_EXTERNAL_INVOCATION}" ]
}

assert_state_rejection_preserves_git() {
	local expected_status="$1" before_head="$2" before_remotes="$3" before_index="$4" before_managed="$5"
	[ "$status" -ne 0 ]
	[[ "$output" == *"workspace or index is not clean"* ]]
	[ ! -e "${STATE_PROJECT_ROOT}/.starter/state.json" ]
	[ "$(git -C "${STATE_PROJECT_ROOT}" rev-parse HEAD)" = "${before_head}" ]
	[ "$(git -C "${STATE_PROJECT_ROOT}" remote -v)" = "${before_remotes}" ]
	[ "$(sha256sum "${STATE_PROJECT_ROOT}/.git/index" | cut -d' ' -f1)" = "${before_index}" ]
	[ "$(sha256sum "${STATE_PROJECT_ROOT}/managed.txt" | cut -d' ' -f1)" = "${before_managed}" ]
	[ "$(GIT_OPTIONAL_LOCKS=0 git -C "${STATE_PROJECT_ROOT}" status --porcelain=v1 --untracked-files=all)" = "${expected_status}" ]
}

@test "planner keeps interpreter-looking payloads opaque" {
	local root="${TEST_ROOT}/opaque" operations expected_sources command_name
	mkdir -p "${root}/payloads/docs" "${root}/migrations"
	printf '%s\n' '--global-option=touch-${STARTER_EXECUTION_SENTINEL}' >"${root}/payloads/requirements.txt"
	printf '%s\n' 'file(WRITE "$ENV{STARTER_EXECUTION_SENTINEL}" "cmake")' >"${root}/payloads/CMakeLists.txt"
	printf '%s\n' '#!/bin/sh' 'touch "${STARTER_EXECUTION_SENTINEL:?}"' >"${root}/payloads/docs/guide.md"
	printf '%s\n' '#!/bin/sh' 'touch "${STARTER_EXECUTION_SENTINEL:?}"' >"${root}/payloads/docs/guide.mdx"
	printf '%s\n' '#!/bin/sh' 'touch "${STARTER_EXECUTION_SENTINEL:?}"' >"${root}/payloads/README.sh"
	chmod 0755 "${root}/payloads/docs/guide.md" "${root}/payloads/docs/guide.mdx" "${root}/payloads/README.sh"
	operations="$(jq -cn '[
		"requirements.txt","CMakeLists.txt","docs/guide.md","docs/guide.mdx","README.sh"
	] | map({type:"copy",ownership:"managed",source:.,target:("managed/"+.),expected_before_sha256:null})')"
	jq -n --argjson operations "${operations}" '{
		schema:"starter-migration/v1",id:"opaque-data",from_version:"1.0.0",to_version:"1.1.0",operations:$operations
	}' >"${root}/migrations/010-opaque-data.json"
	write_manifest "${root}" 1.1.0 '"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
	export STARTER_EXECUTION_SENTINEL="${TEST_ROOT}/executed"
	mkdir -p "${TEST_ROOT}/tool-stubs"
	for command_name in pip pip3 python python3 cmake glow markdown node npx; do
		printf '%s\n' '#!/bin/sh' 'touch "${STARTER_EXECUTION_SENTINEL:?}"' 'exit 99' >"${TEST_ROOT}/tool-stubs/${command_name}"
		chmod 0755 "${TEST_ROOT}/tool-stubs/${command_name}"
	done
	export PATH="${TEST_ROOT}/tool-stubs:${PATH}"

	run run_plan "${root}" 1.0.0

	[ "$status" -eq 0 ]
	[ ! -e "${STARTER_EXECUTION_SENTINEL}" ]
	[ "$(jq '.operations | length' <<<"${output}")" -eq 5 ]
	expected_sources='["CMakeLists.txt","README.sh","docs/guide.md","docs/guide.mdx","requirements.txt"]'
	[ "$(jq -c '[.operations[].source] | sort' <<<"${output}")" = "${expected_sources}" ]
	[ "$(jq -r '.ownership_summary.managed' <<<"${output}")" -eq 5 ]
	[ "$(jq -r '.operations[] | select(.source=="README.sh") | .content_sha256' <<<"${output}")" = \
		"$(sha256sum "${root}/payloads/README.sh" | cut -d' ' -f1)" ]
}

@test "migration selection is deterministic and ownership classes remain explicit" {
	local root="${TEST_ROOT}/chain" result
	mkdir -p "${root}/payloads" "${root}/migrations"
	printf '%s\n' 'starter=true' >"${root}/payloads/starter.conf"
	jq -n '{schema:"starter-migration/v1",id:"first",from_version:"1.0.0",to_version:"1.1.0",operations:[
		{type:"fusion",ownership:"fusion",source:"starter.conf",target:"Taskfile.yml",expected_before_sha256:null}
	]}' >"${root}/migrations/010-first.json"
	jq -n '{schema:"starter-migration/v1",id:"second",from_version:"1.1.0",to_version:"2.0.0",operations:[
		{type:"delete",ownership:"managed",source:null,target:"legacy.conf",expected_before_sha256:null}
	]}' >"${root}/migrations/020-second.json"
	write_manifest "${root}" 2.0.0 '"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"'

	run run_plan "${root}" 1.0.0

	[ "$status" -eq 0 ]
	[ "$(jq -c '.migration_ids' <<<"${output}")" = '["first","second"]' ]
	[ "$(jq -c '.ownership_summary' <<<"${output}")" = '{"managed":1,"fusion":1,"project_owned":0}' ]
	result="$(/usr/bin/bash -c "source '${PLANNER_CORE}'; starter_planner_classify_ownership '{\"ownership\":\"project-owned\"}'")"
	[ "${result}" = "project-owned" ]
}

@test "checked-in distribution baseline produces a real neutral planning result" {
	local root="${TEST_ROOT}/baseline"
	cp -R "${REPO_ROOT}/.starter/distribution" "${root}"
	write_envelope "${root}"

	run run_plan "${root}" 0.0.0

	[ "$status" -eq 0 ]
	[ "$(jq -r '.schema' <<<"${output}")" = "gentle-starter.plan/v1" ]
	[ "$(jq -r '.target_release.version' <<<"${output}")" = "1.0.0" ]
	[ "$(jq -c '.migration_ids' <<<"${output}")" = '["baseline-1.0.0"]' ]
	[ "$(jq -r '.operations[0].target' <<<"${output}")" = ".starter/baseline.json" ]
}

@test "planner rejects descriptor traversal and unsafe operation targets without writes" {
	local root project before operations outside_descriptor
	project="${TEST_ROOT}/unsafe-project"
	mkdir -p "${project}"
	printf '%s\n' 'project-owned' >"${project}/sentinel.txt"
	before="$(project_digest "${project}")"

	root="${TEST_ROOT}/descriptor-traversal"
	mkdir -p "${root}/payloads" "${root}/migrations"
	printf '%s\n' 'safe' >"${root}/payloads/source.txt"
	operations='[{"type":"copy","ownership":"managed","source":"source.txt","target":"managed/safe.txt","expected_before_sha256":null}]'
	write_single_migration "${root}" descriptor 1.0.0 2.0.0 "${operations}"
	write_manifest "${root}" 2.0.0 '"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
	outside_descriptor="${TEST_ROOT}/outside-migration.json"
	cp "${root}/migrations/descriptor.json" "${outside_descriptor}"
	jq --arg sha "$(sha256sum "${outside_descriptor}" | cut -d' ' -f1)" \
		'.migrations={root:"..",entries:[{id:"descriptor",path:"outside-migration.json",sha256:$sha}]}' \
		"${root}/manifest.json" >"${root}/manifest.tmp"
	mv "${root}/manifest.tmp" "${root}/manifest.json"
	write_envelope "${root}"
	run run_plan "${root}" 1.0.0 "${project}"
	[ "$status" -ne 0 ]
	[[ "$output" == *"unsafe migration path"* ]]
	[ "$(project_digest "${project}")" = "${before}" ]

	root="${TEST_ROOT}/target-traversal"
	mkdir -p "${root}/payloads" "${root}/migrations"
	printf '%s\n' 'safe' >"${root}/payloads/source.txt"
	operations='[{"type":"copy","ownership":"managed","source":"source.txt","target":"../escaped.txt","expected_before_sha256":null}]'
	write_single_migration "${root}" traversal 1.0.0 2.0.0 "${operations}"
	write_manifest "${root}" 2.0.0 '"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
	run run_plan "${root}" 1.0.0 "${project}"
	[ "$status" -ne 0 ]
	[[ "$output" == *"invalid migration descriptor"* ]]
	[ "$(project_digest "${project}")" = "${before}" ]
	[ ! -e "${TEST_ROOT}/escaped.txt" ]

	root="${TEST_ROOT}/absolute-target"
	mkdir -p "${root}/payloads" "${root}/migrations"
	printf '%s\n' 'safe' >"${root}/payloads/source.txt"
	operations="$(jq -cn --arg target "${TEST_ROOT}/absolute-write.txt" '[{type:"copy",ownership:"managed",source:"source.txt",target:$target,expected_before_sha256:null}]')"
	write_single_migration "${root}" absolute 1.0.0 2.0.0 "${operations}"
	write_manifest "${root}" 2.0.0 '"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
	run run_plan "${root}" 1.0.0 "${project}"
	[ "$status" -ne 0 ]
	[[ "$output" == *"invalid migration descriptor"* ]]
	[ "$(project_digest "${project}")" = "${before}" ]
	[ ! -e "${TEST_ROOT}/absolute-write.txt" ]
}

@test "planner rejects direct and nested symlink escapes without writes" {
	local root project outside before operations target
	root="${TEST_ROOT}/symlink-release"
	project="${TEST_ROOT}/symlink-project"
	outside="${TEST_ROOT}/outside"
	mkdir -p "${root}/payloads" "${root}/migrations" "${project}/nested" "${outside}"
	printf '%s\n' 'safe' >"${root}/payloads/source.txt"
	printf '%s\n' 'project-owned' >"${project}/sentinel.txt"
	ln -s "${outside}" "${project}/direct"
	ln -s "${outside}" "${project}/nested/link"
	before="$(project_digest "${project}")"
	for target in direct/escaped.txt nested/link/escaped.txt; do
		rm -f "${root}/migrations/symlink.json"
		operations="$(jq -cn --arg target "${target}" '[{type:"copy",ownership:"managed",source:"source.txt",target:$target,expected_before_sha256:null}]')"
		write_single_migration "${root}" symlink 1.0.0 2.0.0 "${operations}"
		write_manifest "${root}" 2.0.0 '"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
		run run_plan "${root}" 1.0.0 "${project}"
		[ "$status" -ne 0 ]
		[[ "$output" == *"target escapes project root"* ]]
		[ "$(project_digest "${project}")" = "${before}" ]
		[ ! -e "${outside}/escaped.txt" ]
	done
}

@test "planner rejects duplicate and ancestor target collisions without writes" {
	local root project before operations collision
	project="${TEST_ROOT}/collision-project"
	mkdir -p "${project}"
	printf '%s\n' 'project-owned' >"${project}/sentinel.txt"
	before="$(project_digest "${project}")"
	for collision in duplicate ancestor; do
		root="${TEST_ROOT}/collision-${collision}"
		mkdir -p "${root}/payloads" "${root}/migrations"
		printf '%s\n' 'one' >"${root}/payloads/one.txt"
		printf '%s\n' 'two' >"${root}/payloads/two.txt"
		if [ "${collision}" = duplicate ]; then
			operations='[
				{"type":"copy","ownership":"managed","source":"one.txt","target":"same.txt","expected_before_sha256":null},
				{"type":"copy","ownership":"managed","source":"two.txt","target":"same.txt","expected_before_sha256":null}
			]'
		else
			operations='[
				{"type":"copy","ownership":"managed","source":"one.txt","target":"tree","expected_before_sha256":null},
				{"type":"copy","ownership":"managed","source":"two.txt","target":"tree/child.txt","expected_before_sha256":null}
			]'
		fi
		write_single_migration "${root}" collision 1.0.0 2.0.0 "${operations}"
		write_manifest "${root}" 2.0.0 '"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
		run run_plan "${root}" 1.0.0 "${project}"
		[ "$status" -ne 0 ]
		[[ "$output" == *"target path collision"* ]]
		[ "$(project_digest "${project}")" = "${before}" ]
	done
}

@test "planner rejects copy and delete operations on project-owned paths without writes" {
	local root project before operations operation_type
	project="${TEST_ROOT}/ownership-project"
	mkdir -p "${project}"
	printf '%s\n' 'keep' >"${project}/owned.txt"
	before="$(project_digest "${project}")"
	for operation_type in copy delete; do
		root="${TEST_ROOT}/ownership-${operation_type}"
		mkdir -p "${root}/payloads" "${root}/migrations"
		printf '%s\n' 'replacement' >"${root}/payloads/source.txt"
		if [ "${operation_type}" = copy ]; then
			operations='[{"type":"copy","ownership":"project-owned","source":"source.txt","target":"owned.txt","expected_before_sha256":null}]'
		else
			operations='[{"type":"delete","ownership":"project-owned","source":null,"target":"owned.txt","expected_before_sha256":null}]'
		fi
		write_single_migration "${root}" ownership 1.0.0 2.0.0 "${operations}"
		write_manifest "${root}" 2.0.0 '"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
		run run_plan "${root}" 1.0.0 "${project}"
		[ "$status" -ne 0 ]
		[[ "$output" == *"project-owned target is immutable"* ]]
		[ "$(project_digest "${project}")" = "${before}" ]
		[ "$(cat "${project}/owned.txt")" = keep ]
	done
}

@test "planner rejects migration-chain gaps before and after progress without writes" {
	local root project before operations gap
	project="${TEST_ROOT}/chain-project"
	mkdir -p "${project}"
	printf '%s\n' 'keep' >"${project}/sentinel.txt"
	before="$(project_digest "${project}")"
	operations='[{"type":"delete","ownership":"managed","source":null,"target":"obsolete.txt","expected_before_sha256":null}]'
	for gap in initial later; do
		root="${TEST_ROOT}/chain-${gap}"
		mkdir -p "${root}/payloads" "${root}/migrations"
		printf '%s\n' 'payload' >"${root}/payloads/source.txt"
		if [ "${gap}" = initial ]; then
			write_single_migration "${root}" only 2.0.0 3.0.0 "${operations}"
		else
			write_single_migration "${root}" first 1.0.0 2.0.0 "${operations}"
		fi
		write_manifest "${root}" 3.0.0 '"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
		run run_plan "${root}" 1.0.0 "${project}"
		[ "$status" -ne 0 ]
		[[ "$output" == *"incomplete migration chain"* ]]
		[ "$(project_digest "${project}")" = "${before}" ]
	done
}

@test "state admission blocks staged-only dirt without Git or project mutation" {
	local before_head before_remotes before_index before_managed expected_status
	initialize_state_fixture
	printf '%s\n' 'staged replacement' >"${STATE_PROJECT_ROOT}/managed.txt"
	git -C "${STATE_PROJECT_ROOT}" add managed.txt
	expected_status="$(GIT_OPTIONAL_LOCKS=0 git -C "${STATE_PROJECT_ROOT}" status --porcelain=v1 --untracked-files=all)"
	before_head="$(git -C "${STATE_PROJECT_ROOT}" rev-parse HEAD)"
	before_remotes="$(git -C "${STATE_PROJECT_ROOT}" remote -v)"
	before_index="$(sha256sum "${STATE_PROJECT_ROOT}/.git/index" | cut -d' ' -f1)"
	before_managed="$(sha256sum "${STATE_PROJECT_ROOT}/managed.txt" | cut -d' ' -f1)"

	run_state_write

	assert_state_rejection_preserves_git "${expected_status}" "${before_head}" "${before_remotes}" "${before_index}" "${before_managed}"
}

@test "state admission blocks tracked modifications visible to git commit -a" {
	local before_head before_remotes before_index before_managed expected_status
	initialize_state_fixture
	printf '%s\n' 'unstaged tracked replacement' >"${STATE_PROJECT_ROOT}/managed.txt"
	expected_status="$(GIT_OPTIONAL_LOCKS=0 git -C "${STATE_PROJECT_ROOT}" status --porcelain=v1 --untracked-files=all)"
	before_head="$(git -C "${STATE_PROJECT_ROOT}" rev-parse HEAD)"
	before_remotes="$(git -C "${STATE_PROJECT_ROOT}" remote -v)"
	before_index="$(sha256sum "${STATE_PROJECT_ROOT}/.git/index" | cut -d' ' -f1)"
	before_managed="$(sha256sum "${STATE_PROJECT_ROOT}/managed.txt" | cut -d' ' -f1)"

	run_state_write

	assert_state_rejection_preserves_git "${expected_status}" "${before_head}" "${before_remotes}" "${before_index}" "${before_managed}"
}

@test "state admission blocks untracked dirt with an otherwise empty index diff" {
	local before_head before_remotes before_index before_managed expected_status
	initialize_state_fixture
	GIT_OPTIONAL_LOCKS=0 git -C "${STATE_PROJECT_ROOT}" diff --cached --quiet
	printf '%s\n' 'untracked project content' >"${STATE_PROJECT_ROOT}/notes.txt"
	expected_status="$(GIT_OPTIONAL_LOCKS=0 git -C "${STATE_PROJECT_ROOT}" status --porcelain=v1 --untracked-files=all)"
	before_head="$(git -C "${STATE_PROJECT_ROOT}" rev-parse HEAD)"
	before_remotes="$(git -C "${STATE_PROJECT_ROOT}" remote -v)"
	before_index="$(sha256sum "${STATE_PROJECT_ROOT}/.git/index" | cut -d' ' -f1)"
	before_managed="$(sha256sum "${STATE_PROJECT_ROOT}/managed.txt" | cut -d' ' -f1)"

	run_state_write

	assert_state_rejection_preserves_git "${expected_status}" "${before_head}" "${before_remotes}" "${before_index}" "${before_managed}"
	[ "$(cat "${STATE_PROJECT_ROOT}/notes.txt")" = "untracked project content" ]
}

@test "state marker validates fingerprints before atomic write and retains opaque evidence" {
	local marker migration_sha expected_state_sha actual_state_sha
	initialize_state_fixture
	jq '.evidence.ref="urn:opaque:retained-evidence?adapter-data=%2Fnot-a-core-path"' \
		"${STATE_RELEASE_ROOT}/envelope.json" >"${STATE_RELEASE_ROOT}/envelope.tmp"
	mv "${STATE_RELEASE_ROOT}/envelope.tmp" "${STATE_RELEASE_ROOT}/envelope.json"
	expected_state_sha="$(jq -cS 'del(.integrity)' "${STATE_RELEASE_ROOT}/envelope.json" | sha256sum | cut -d' ' -f1)"
	jq --arg sha "${expected_state_sha}" '.integrity.envelope_sha256=$sha' \
		"${STATE_RELEASE_ROOT}/envelope.json" >"${STATE_RELEASE_ROOT}/envelope.tmp"
	mv "${STATE_RELEASE_ROOT}/envelope.tmp" "${STATE_RELEASE_ROOT}/envelope.json"
	printf '%s\n' 'wrong but clean managed content' >"${STATE_PROJECT_ROOT}/managed.txt"
	git -C "${STATE_PROJECT_ROOT}" add managed.txt
	git -C "${STATE_PROJECT_ROOT}" commit -q -m "clean fingerprint mismatch"

	run_state_write

	[ "$status" -ne 0 ]
	[[ "$output" == *"managed fingerprint mismatch"* ]]
	[ ! -e "${STATE_PROJECT_ROOT}/.starter/state.json" ]
	[ -z "$(find "${STATE_PROJECT_ROOT}/.starter" -maxdepth 1 -name '.state.json.*' -print)" ]

	printf '%s\n' 'managed release content' >"${STATE_PROJECT_ROOT}/managed.txt"
	git -C "${STATE_PROJECT_ROOT}" add managed.txt
	git -C "${STATE_PROJECT_ROOT}" commit -q -m "matching managed fingerprint"
	run_state_write

	[ "$status" -eq 0 ]
	marker="${STATE_PROJECT_ROOT}/.starter/state.json"
	[ -f "${marker}" ]
	[ "$(jq -r '.schema' "${marker}")" = "gentle-starter.state/v1" ]
	[ "$(jq -c '.source' "${marker}")" = "$(jq -c '.source' "${STATE_RELEASE_ROOT}/envelope.json")" ]
	[ "$(jq -c '.release' "${marker}")" = "$(jq -c '.release' "${STATE_RELEASE_ROOT}/envelope.json")" ]
	[ "$(jq -c '.immutable_identities' "${marker}")" = "$(jq -c '.immutable_identities' "${STATE_RELEASE_ROOT}/envelope.json")" ]
	[ "$(jq -c '.evidence' "${marker}")" = "$(jq -c '.evidence' "${STATE_RELEASE_ROOT}/envelope.json")" ]
	[ "$(jq -r '.evidence.ref' "${marker}")" = "urn:opaque:retained-evidence?adapter-data=%2Fnot-a-core-path" ]
	[ "$(jq -r '.envelope.sha256' "${marker}")" = "$(jq -r '.integrity.envelope_sha256' "${STATE_RELEASE_ROOT}/envelope.json")" ]
	[ "$(jq -r '.manifest.sha256' "${marker}")" = "$(jq -r '.manifest.sha256' "${STATE_RELEASE_ROOT}/envelope.json")" ]
	migration_sha="$(sha256sum "${STATE_RELEASE_ROOT}/migrations/state-baseline.json" | cut -d' ' -f1)"
	[ "$(jq -r '.migrations[0].sha256' "${marker}")" = "${migration_sha}" ]
	[ "$(jq -r '.managed_fingerprints[0].path' "${marker}")" = managed.txt ]
	[ "$(jq -r '.managed_fingerprints[0].sha256' "${marker}")" = "$(sha256sum "${STATE_PROJECT_ROOT}/managed.txt" | cut -d' ' -f1)" ]
	[ "$(jq -r '.managed_fingerprints[1].path' "${marker}")" = obsolete.txt ]
	[ "$(jq -c '.managed_fingerprints[1].sha256' "${marker}")" = null ]
	actual_state_sha="$(jq -cS 'del(.integrity)' "${marker}" | sha256sum | cut -d' ' -f1)"
	[ "$(jq -r '.integrity.state_sha256' "${marker}")" = "${actual_state_sha}" ]
	[ -z "$(find "${STATE_PROJECT_ROOT}/.starter" -maxdepth 1 -name '.state.json.*' -print)" ]
	[ "$(GIT_OPTIONAL_LOCKS=0 git -C "${STATE_PROJECT_ROOT}" status --porcelain=v1 --untracked-files=all)" = "?? .starter/state.json" ]
}

@test "transaction failpoint leaves a durable complete journal before mutation" {
	local journal_file before_managed before_obsolete
	initialize_transaction_fixture
	before_managed="$(sha256sum "${TRANSACTION_PROJECT_ROOT}/managed.txt" | cut -d' ' -f1)"
	before_obsolete="$(sha256sum "${TRANSACTION_PROJECT_ROOT}/obsolete.txt" | cut -d' ' -f1)"

	run_transaction after-journal

	[ "$status" -eq 97 ]
	journal_file="$(transaction_journal_file)"
	[ -f "${journal_file}" ]
	[ "$(jq -r '.schema' "${journal_file}")" = 'gentle-starter.journal/v1' ]
	[ "$(jq '.operations | length' "${journal_file}")" -eq 2 ]
	[ "$(jq -r '.operations[0].before.sha256' "${journal_file}")" = "${before_managed}" ]
	[ "$(jq -r '.operations[1].before.sha256' "${journal_file}")" = "${before_obsolete}" ]
	[ "$(sha256sum "$(dirname "${journal_file}")/prestate/0" | cut -d' ' -f1)" = "${before_managed}" ]
	[ "$(sha256sum "$(dirname "${journal_file}")/prestate/1" | cut -d' ' -f1)" = "${before_obsolete}" ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/managed.txt")" = 'managed project content' ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/obsolete.txt")" = 'obsolete managed content' ]
	[ ! -e "${TRANSACTION_PROJECT_ROOT}/.starter/state.json" ]
}

@test "transaction drift validation fails before creating journal artifacts" {
	initialize_transaction_fixture
	printf '%s\n' 'drift before transaction admission' >"${TRANSACTION_PROJECT_ROOT}/managed.txt"
	git -C "${TRANSACTION_PROJECT_ROOT}" add managed.txt
	git -C "${TRANSACTION_PROJECT_ROOT}" commit -q -m "clean drift fixture"

	run_transaction

	[ "$status" -ne 0 ]
	[[ "$output" == *'pre-mutation CAS mismatch'* ]]
	[ ! -e "${TRANSACTION_PROJECT_ROOT}/.starter/journals" ]
	[ ! -e "${TRANSACTION_PROJECT_ROOT}/.starter/state.json" ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/managed.txt")" = 'drift before transaction admission' ]
}

@test "transaction mutation rejects a post-journal concurrent change and recovery retains ambiguity" {
	local journal_file
	initialize_transaction_fixture
	journal_file="$(/usr/bin/bash -c '
		source "$1"
		starter_journal_prepare "$2" "$(cat "$3")" "$(cat "$4")"
	' _ "${JOURNAL_CORE}" "${TRANSACTION_PROJECT_ROOT}" \
		"${TEST_ROOT}/transaction-source-result.json" "${TEST_ROOT}/transaction-plan.json")"
	printf '%s\n' 'concurrent project change' >"${TRANSACTION_PROJECT_ROOT}/managed.txt"

	run /usr/bin/bash -c 'source "$1"; starter_transaction_apply "$2" "$3"' \
		_ "${JOURNAL_CORE}" "${TRANSACTION_PROJECT_ROOT}" "${journal_file}"

	[ "$status" -ne 0 ]
	[[ "$output" == *'CAS mismatch'* ]]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/managed.txt")" = 'concurrent project change' ]
	run_transaction_recovery "${journal_file}"
	[ "$status" -ne 0 ]
	[[ "$output" == *'ambiguous'* ]]
	[ -f "${journal_file}" ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/managed.txt")" = 'concurrent project change' ]
	[ ! -e "${TRANSACTION_PROJECT_ROOT}/.starter/state.json" ]
}

@test "recovery rejects a tampered journal before touching project-owned content" {
	local journal_file owned_sha
	initialize_transaction_fixture
	run_transaction after-journal
	[ "$status" -eq 97 ]
	journal_file="$(transaction_journal_file)"
	owned_sha="$(sha256sum "${TRANSACTION_PROJECT_ROOT}/owned.txt" | cut -d' ' -f1)"
	jq --arg owned_sha "${owned_sha}" \
		'.operations[0].target="owned.txt" | .operations[0].after.sha256=$owned_sha' \
		"${journal_file}" >"${journal_file}.tampered"
	mv "${journal_file}.tampered" "${journal_file}"

	run_transaction_recovery "${journal_file}"

	[ "$status" -ne 0 ]
	[[ "$output" == *'journal integrity mismatch'* ]]
	[ -f "${journal_file}" ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/owned.txt")" = 'project-owned content' ]
	[ ! -e "${TRANSACTION_PROJECT_ROOT}/.starter/state.json" ]
}

@test "rollback restores only CAS-provable mutations and preserves repository and external boundaries" {
	local journal_file before_status
	initialize_transaction_fixture
	printf '%s\n' '{"schema":"existing-adopted-state/test-fixture"}' >"${TRANSACTION_PROJECT_ROOT}/.starter/state.json"
	git -C "${TRANSACTION_PROJECT_ROOT}" add .starter/state.json
	git -C "${TRANSACTION_PROJECT_ROOT}" commit -q -m "existing adopted marker"
	snapshot_transaction_boundaries
	before_status="$(GIT_OPTIONAL_LOCKS=0 git -C "${TRANSACTION_PROJECT_ROOT}" status --porcelain=v1 --untracked-files=all)"

	run_transaction after-operation-1

	[ "$status" -eq 97 ]
	journal_file="$(transaction_journal_file)"
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/managed.txt")" = 'managed release content' ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/obsolete.txt")" = 'obsolete managed content' ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/.starter/state.json")" = '{"schema":"existing-adopted-state/test-fixture"}' ]
	run_transaction_recovery "${journal_file}"
	[ "$status" -eq 0 ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/managed.txt")" = 'managed project content' ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/obsolete.txt")" = 'obsolete managed content' ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/.starter/state.json")" = '{"schema":"existing-adopted-state/test-fixture"}' ]
	[ ! -e "${journal_file}" ]
	[ "$(GIT_OPTIONAL_LOCKS=0 git -C "${TRANSACTION_PROJECT_ROOT}" status --porcelain=v1 --untracked-files=all)" = "${before_status}" ]
	assert_transaction_boundaries_preserved
}

@test "rollback never overwrites a concurrent post-mutation change and retains its journal" {
	local journal_file
	initialize_transaction_fixture
	snapshot_transaction_boundaries
	run_transaction after-operation-1
	[ "$status" -eq 97 ]
	journal_file="$(transaction_journal_file)"
	printf '%s\n' 'concurrent owner replacement' >"${TRANSACTION_PROJECT_ROOT}/managed.txt"

	run_transaction_recovery "${journal_file}"

	[ "$status" -ne 0 ]
	[[ "$output" == *'ambiguous'* ]]
	[ -f "${journal_file}" ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/managed.txt")" = 'concurrent owner replacement' ]
	[ ! -e "${TRANSACTION_PROJECT_ROOT}/.starter/state.json" ]
	assert_transaction_boundaries_preserved
}

@test "transaction writes state last and never commits or touches external resources" {
	local journal_file
	initialize_transaction_fixture
	snapshot_transaction_boundaries

	run_transaction before-state

	[ "$status" -eq 97 ]
	journal_file="$(transaction_journal_file)"
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/managed.txt")" = 'managed release content' ]
	[ ! -e "${TRANSACTION_PROJECT_ROOT}/obsolete.txt" ]
	[ ! -e "${TRANSACTION_PROJECT_ROOT}/.starter/state.json" ]
	run_transaction_recovery "${journal_file}"
	[ "$status" -eq 0 ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/managed.txt")" = 'managed project content' ]
	[ -f "${TRANSACTION_PROJECT_ROOT}/obsolete.txt" ]

	run_transaction

	[ "$status" -eq 0 ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/managed.txt")" = 'managed release content' ]
	[ ! -e "${TRANSACTION_PROJECT_ROOT}/obsolete.txt" ]
	[ -f "${TRANSACTION_PROJECT_ROOT}/.starter/state.json" ]
	[ "$(jq -r '.release.version' "${TRANSACTION_PROJECT_ROOT}/.starter/state.json")" = '2.0.0' ]
	[ -z "$(transaction_journal_file)" ]
	assert_transaction_boundaries_preserved
}

@test "recovery treats a matching state marker as committed and only removes the journal" {
	local journal_file
	initialize_transaction_fixture
	snapshot_transaction_boundaries

	run_transaction after-state

	[ "$status" -eq 97 ]
	journal_file="$(transaction_journal_file)"
	[ -f "${journal_file}" ]
	[ -f "${TRANSACTION_PROJECT_ROOT}/.starter/state.json" ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/managed.txt")" = 'managed release content' ]
	[ ! -e "${TRANSACTION_PROJECT_ROOT}/obsolete.txt" ]
	run_transaction_recovery "${journal_file}"
	[ "$status" -eq 0 ]
	[ ! -e "${journal_file}" ]
	[ -f "${TRANSACTION_PROJECT_ROOT}/.starter/state.json" ]
	[ "$(cat "${TRANSACTION_PROJECT_ROOT}/managed.txt")" = 'managed release content' ]
	[ ! -e "${TRANSACTION_PROJECT_ROOT}/obsolete.txt" ]
	assert_transaction_boundaries_preserved
}
