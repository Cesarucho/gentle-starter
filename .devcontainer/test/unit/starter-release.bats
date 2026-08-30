#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	RELEASE="${REPO_ROOT}/.taskfiles/scripts/starter-release.sh"
	TEST_ROOT="$(mktemp -d)"
	PROJECT="${TEST_ROOT}/project"
	REMOTE="${TEST_ROOT}/remote.git"
	DIST="${PROJECT}/.starter/distribution/prepared/0.1.0"
	create_project 0.1.0
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

create_project() {
	local version="$1" payload_sha payload_bytes migration_sha ownership_sha derived_sha manifest_sha
	local distribution="${PROJECT}/.starter/distribution/prepared/${version}"
	mkdir -p "${distribution}/payloads" "${distribution}/migrations" "${distribution}/tree"
	printf '%s\n' '# Gentle Starter fixture' >"${PROJECT}/AGENTS.md"
	printf '%s\n' 'inert payload' >"${distribution}/payloads/baseline.txt"
	printf '%s\n' 'derived tree' >"${distribution}/tree/README.md"
	payload_sha="$(sha256sum "${distribution}/payloads/baseline.txt" | cut -d' ' -f1)"
	payload_bytes="$(wc -c <"${distribution}/payloads/baseline.txt")"
	jq -n --arg version "${version}" '{schema:"starter-migration/v2",id:("release-"+$version),from_version:"0.0.0",to_version:$version,operations:[]}' \
		>"${distribution}/migrations/release.json"
	migration_sha="$(sha256sum "${distribution}/migrations/release.json" | cut -d' ' -f1)"
	jq -n '{schema:"gentle-starter.ownership-inventory/v2",default_ownership:"project-owned",managed:[],fusion:[
		{match:"exact",path:".devcontainer/devcontainer.json",contract:"F-manual/v1"},
		{match:"exact",path:".devcontainer/docker-compose.yml",contract:"F-manual/v1"}]}' >"${distribution}/ownership.json"
	ownership_sha="$(sha256sum "${distribution}/ownership.json" | cut -d' ' -f1)"
	jq -n --arg version "${version}" --arg payload_sha "${payload_sha}" --argjson bytes "${payload_bytes}" \
		--arg migration_sha "${migration_sha}" --arg ownership_sha "${ownership_sha}" '{
		schema:"starter-manifest/v2",source:{id:"gentle-starter",release:("starter/v"+$version)},release:{version:$version,predecessor_version:"0.0.0",predecessor_id:null},
		identities:{official_tree:("sha256:"+("a"*64)),derived_tree:("sha256:"+("b"*64))},
		transformation:{schema:"gentle-starter.derived-tree-transformation/v1"},
		ownership:{schema:"gentle-starter.ownership-inventory/v2",path:"ownership.json",sha256:$ownership_sha},
		payload:{root:"payloads",closure:"exact",entries:[{path:"baseline.txt",sha256:$payload_sha,bytes:$bytes,mode:"644",presence:"present"}]},
		migrations:{root:"migrations",entries:[{id:("release-"+$version),path:"release.json",sha256:$migration_sha}]}
	}' >"${distribution}/manifest.json"
	derived_sha="$(bash -c 'source "$1"; starter_derived_identity "$2"' _ "${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/derived-tree.sh" "${distribution}/tree")"
	jq --arg derived "sha256:${derived_sha}" '.identities.derived_tree=$derived' "${distribution}/manifest.json" >"${distribution}/manifest.tmp"
	mv "${distribution}/manifest.tmp" "${distribution}/manifest.json"
	jq -n --arg version "${version}" --arg derived "${derived_sha}" '{
		schema:"gentle-starter.prepared-release/v2",version:$version,predecessor_version:"0.0.0",
		official_tree_sha256:("a"*64),transformation:{schema:"gentle-starter.derived-tree-transformation/v1",derived_tree_sha256:$derived},
		artifacts:{manifest:"manifest.json",ownership:"ownership.json",migration_root:"migrations",payload_root:"payloads"}
	}' >"${distribution}/index.json"
	manifest_sha="$(sha256sum "${distribution}/manifest.json" | cut -d' ' -f1)"
	jq -n --arg version "${version}" --arg sha "${manifest_sha}" \
		'{schema:"gentle-starter.publication/v2",selector:("starter/v"+$version),manifest_sha256:$sha,publish:false}' \
		>"${distribution}/publication.json"
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
	[ "$status" -eq 0 ] || {
		printf '%s\n' "${output}" >&3
		false
	}
	[[ "$output" == *"selector/tag: starter/v0.1.0"* ]]
	[[ "$output" == *"structural/integrity status: validated"* ]]
	[[ "$output" == *"remote publication: pending"* ]]
	[ "$(git -C "${PROJECT}" cat-file -t starter/v0.1.0)" = tag ]
	[ "$(git -C "${PROJECT}" for-each-ref --format='%(contents:subject)' refs/tags/starter/v0.1.0 | jq -r '.manifest.path')" = .starter/distribution/prepared/0.1.0/manifest.json ]
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
	local before manifest="${DIST}/manifest.json"
	mv "${manifest}" "${manifest}.missing"
	run_release 0.1.0
	[ "$status" -ne 0 ]
	git -C "${PROJECT}" restore .
	printf '%s\n' '{}' >"${manifest}"
	git -C "${PROJECT}" add "${manifest}" && git -C "${PROJECT}" commit -qm malformed
	run_release 0.1.0
	[ "$status" -ne 0 ]
	git -C "${PROJECT}" show HEAD^:".starter/distribution/prepared/0.1.0/manifest.json" >"${manifest}"
	jq '.payload.entries[0].sha256 = ("f" * 64)' "${manifest}" >"${manifest}.tmp" && mv "${manifest}.tmp" "${manifest}"
	git -C "${PROJECT}" add "${manifest}" && git -C "${PROJECT}" commit -qm mismatch
	before="$(ref_snapshot)"
	run_release 0.1.0
	[ "$status" -ne 0 ]
	[ "$(ref_snapshot)" = "${before}" ]
}

@test "starter release rejects missing invalid mismatched and uncommitted ownership before tag mutation" {
	local inventory="${DIST}/ownership.json" manifest="${DIST}/manifest.json"
	rm "${inventory}"
	run_release 0.1.0
	[ "$status" -ne 0 ]
	! git -C "${PROJECT}" show-ref --verify --quiet refs/tags/starter/v0.1.0
	git -C "${PROJECT}" restore "${inventory}"
	jq '.unknown=true' "${inventory}" >"${inventory}.tmp" && mv "${inventory}.tmp" "${inventory}"
	git -C "${PROJECT}" add "${inventory}" && git -C "${PROJECT}" commit -qm "invalid ownership"
	jq --arg sha "$(sha256sum "${inventory}" | cut -d' ' -f1)" '.ownership.sha256=$sha' "${manifest}" >"${manifest}.tmp" && mv "${manifest}.tmp" "${manifest}"
	git -C "${PROJECT}" add "${manifest}" && git -C "${PROJECT}" commit -qm "bind invalid ownership"
	run_release 0.1.0
	[ "$status" -ne 0 ]
	! git -C "${PROJECT}" show-ref --verify --quiet refs/tags/starter/v0.1.0
	git -C "${PROJECT}" show HEAD~2:.starter/distribution/prepared/0.1.0/ownership.json >"${inventory}"
	run_release 0.1.0
	[ "$status" -ne 0 ]
	[[ "$output" == *"worktree and index must be clean"* ]]
	! git -C "${PROJECT}" show-ref --verify --quiet refs/tags/starter/v0.1.0
}

@test "starter release rejects hash-consistent malformed migration semantics and topology before tagging" {
	local migration="${DIST}/migrations/release.json" manifest="${DIST}/manifest.json" publication="${DIST}/publication.json"
	local tamper pristine="${TEST_ROOT}/pristine-release"
	cp -a "${DIST}" "${pristine}"
	for tamper in absolute project-owned duplicate-edge descending malformed-operation; do
		rm -rf "${DIST}"
		cp -a "${pristine}" "${DIST}"
		case "${tamper}" in
		absolute)
			jq '.operations=[{type:"copy",ownership:"managed",source:"baseline.txt",target:"/escape",expected_before:{presence:"any",sha256:null,mode:null},after:{presence:"present",sha256:("a"*64),mode:"644"}}]' "${migration}" >"${migration}.tmp"
			;;
		project-owned)
			jq '.operations=[{type:"copy",ownership:"managed",source:"baseline.txt",target:"project.txt",expected_before:{presence:"any",sha256:null,mode:null},after:{presence:"present",sha256:("a"*64),mode:"644"}}]' "${migration}" >"${migration}.tmp"
			;;
		duplicate-edge)
			cp "${migration}" "${DIST}/migrations/duplicate.json"
			jq '.id="duplicate"' "${DIST}/migrations/duplicate.json" >"${DIST}/migrations/duplicate.tmp" && mv "${DIST}/migrations/duplicate.tmp" "${DIST}/migrations/duplicate.json"
			jq --arg sha "$(sha256sum "${DIST}/migrations/duplicate.json" | cut -d' ' -f1)" '.migrations.entries += [{id:"duplicate",path:"duplicate.json",sha256:$sha}]' "${manifest}" >"${manifest}.tmp"
			mv "${manifest}.tmp" "${manifest}"
			;;
		descending) jq '.from_version="9.0.0"' "${migration}" >"${migration}.tmp" ;;
		malformed-operation) jq '.operations=[{type:"copy"}]' "${migration}" >"${migration}.tmp" ;;
		esac
		if [ -f "${migration}.tmp" ]; then
			mv "${migration}.tmp" "${migration}"
			jq --arg sha "$(sha256sum "${migration}" | cut -d' ' -f1)" '(.migrations.entries[]|select(.path=="release.json")|.sha256)=$sha' "${manifest}" >"${manifest}.tmp"
			mv "${manifest}.tmp" "${manifest}"
		fi
		jq --arg sha "$(sha256sum "${manifest}" | cut -d' ' -f1)" '.manifest_sha256=$sha' "${publication}" >"${publication}.tmp"
		mv "${publication}.tmp" "${publication}"
		git -C "${PROJECT}" add .starter && git -C "${PROJECT}" commit -qm "tamper ${tamper}"
		run_release 0.1.0
		[ "${status}" -ne 0 ]
		! git -C "${PROJECT}" show-ref --verify --quiet refs/tags/starter/v0.1.0
	done
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
