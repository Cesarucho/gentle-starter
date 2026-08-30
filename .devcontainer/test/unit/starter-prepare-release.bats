#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	PREPARE="${REPO_ROOT}/.taskfiles/scripts/starter-prepare-release.sh"
	[ -d /home/ubuntu/tmp ]
	TEST_ROOT="$(mktemp -d /home/ubuntu/tmp/starter-prepare.XXXXXX)"
	PROJECT="${TEST_ROOT}/publisher"
	mkdir -p "${PROJECT}/.starter/distribution" "${PROJECT}/.taskfiles" "${PROJECT}/.devcontainer"
	cp -p "${REPO_ROOT}/.starter/distribution/ownership.json" "${PROJECT}/.starter/distribution/ownership.json"
	printf 'version: "3"\ntasks: {}\n' >"${PROJECT}/.taskfiles/starter.yml"
	printf '# Fixture\n' >"${PROJECT}/.devcontainer/README.md"
	printf '{"name":"fixture"}\n' >"${PROJECT}/.devcontainer/devcontainer.json"
	printf 'services: {}\n' >"${PROJECT}/.devcontainer/docker-compose.yml"
	git init -q "${PROJECT}"
}

teardown() { rm -rf "${TEST_ROOT}"; }

run_prepare() {
	local version="${1:-2.0.0}" predecessor="${2:-0.0.0}"
	run env STARTER_PREPARE_FAILPOINT="${STARTER_PREPARE_FAILPOINT:-}" \
		bash -c 'cd "$1" && exec "$2" "$3" --predecessor "$4"' _ "${PROJECT}" "${PREPARE}" "${version}" "${predecessor}"
}

run_prepare_inferred() {
	local version="$1"
	run env STARTER_PREPARE_FAILPOINT="${STARTER_PREPARE_FAILPOINT:-}" \
		bash -c 'cd "$1" && exec "$2" "$3"' _ "${PROJECT}" "${PREPARE}" "${version}"
}

bind_predecessor_manifest() {
	local predecessor="$1" root
	root="${PROJECT}/.starter/distribution/prepared/${predecessor}"
	jq --arg sha "$(sha256sum "${root}/manifest.json" | cut -d' ' -f1)" '.manifest_sha256=$sha' \
		"${root}/publication.json" >"${root}/publication.next"
	mv "${root}/publication.next" "${root}/publication.json"
}

bind_predecessor_migration() {
	local predecessor="$1" path="$2" root
	root="${PROJECT}/.starter/distribution/prepared/${predecessor}"
	jq --arg path "${path}" --arg sha "$(sha256sum "${root}/migrations/${path}" | cut -d' ' -f1)" \
		'(.migrations.entries[]|select(.path == $path)|.sha256)=$sha' "${root}/manifest.json" >"${root}/manifest.next"
	mv "${root}/manifest.next" "${root}/manifest.json"
	bind_predecessor_manifest "${predecessor}"
}

prepare_predecessor_fixture() {
	run_prepare 2.0.0 0.0.0
	[ "${status}" -eq 0 ]
	cp -a "${PROJECT}/.starter/distribution/prepared/2.0.0" "${TEST_ROOT}/valid-predecessor"
}

restore_predecessor_fixture() {
	rm -rf "${PROJECT}/.starter/distribution/prepared/2.0.0" "${PROJECT}/.starter/distribution/prepared/2.1.0"
	cp -a "${TEST_ROOT}/valid-predecessor" "${PROJECT}/.starter/distribution/prepared/2.0.0"
}

@test "prepare-release removes only failed staging and permits a clean retry" {
	STARTER_PREPARE_FAILPOINT=after-build run_prepare
	[ "${status}" -eq 97 ]
	[ ! -e "${PROJECT}/.starter/distribution/prepared/2.0.0" ]
	[ -z "$(find "${PROJECT}/.starter/distribution/prepared" -maxdepth 1 -name '.2.0.0.prepare.*' -print -quit)" ]

	STARTER_PREPARE_FAILPOINT= run_prepare
	[ "${status}" -eq 0 ] || {
		printf '%s\n' "${output}" >&3
		false
	}
	[ -f "${PROJECT}/.starter/distribution/prepared/2.0.0/manifest.json" ]
	[ -z "$(find "${PROJECT}/.starter/distribution/prepared" -maxdepth 1 -name '.2.0.0.prepare.*' -print -quit)" ]
	run_prepare 2.1.0 2.0.0
	[ "${status}" -eq 0 ]
	[ -f "${PROJECT}/.starter/distribution/prepared/2.1.0/manifest.json" ]
}

@test "prepare-release preserves a pre-existing final output on collision" {
	mkdir -p "${PROJECT}/.starter/distribution/prepared/2.0.0"
	printf 'operator-owned\n' >"${PROJECT}/.starter/distribution/prepared/2.0.0/sentinel"

	run_prepare

	[ "${status}" -ne 0 ]
	[ "$(cat "${PROJECT}/.starter/distribution/prepared/2.0.0/sentinel")" = operator-owned ]
	[ -z "$(find "${PROJECT}/.starter/distribution/prepared" -maxdepth 1 -name '.2.0.0.prepare.*' -print -quit)" ]
}

@test "prepare-release infers bootstrap and the highest valid local predecessor without network" {
	run_prepare_inferred 2.0.0
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"selected predecessor 0.0.0"* ]]
	run_prepare_inferred 2.1.0
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"selected predecessor 2.0.0"* ]]
	run_prepare_inferred 3.0.0
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"selected predecessor 2.1.0"* ]]
	[ "$(jq -r '.release.predecessor_version' "${PROJECT}/.starter/distribution/prepared/3.0.0/manifest.json")" = 2.1.0 ]
	! grep -Eq 'ls-remote|fetch|curl|wget' "${PREPARE}"
}

@test "prepare-release inference fails closed on malformed candidates and descending targets" {
	mkdir -p "${PROJECT}/.starter/distribution/prepared/not-semver"
	run_prepare_inferred 2.0.0
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"malformed prepared release candidate"* ]]
	rm -rf "${PROJECT}/.starter/distribution/prepared/not-semver"
	run_prepare_inferred 2.0.0
	[ "${status}" -eq 0 ]
	run_prepare_inferred 1.9.0
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"does not form a lower predecessor chain"* ]]
}

@test "prepare-release rejects predecessor migration content hash ID and topology tampering" {
	prepare_predecessor_fixture
	local root path tamper
	root="${PROJECT}/.starter/distribution/prepared/2.0.0"
	path=from-0.0.0-to-2.0.0.json
	for tamper in content hash id from to operation-hash operation-mode operation-presence absolute traversal project-owned generated duplicate-target ambiguous; do
		restore_predecessor_fixture
		case "${tamper}" in
		content) printf '\n' >>"${root}/migrations/${path}" ;;
		hash) jq --arg path "${path}" '(.migrations.entries[]|select(.path == $path)|.sha256)=("f"*64)' \
			"${root}/manifest.json" >"${root}/manifest.next" && mv "${root}/manifest.next" "${root}/manifest.json" && bind_predecessor_manifest 2.0.0 ;;
		id) jq '.id="tampered-id"' "${root}/migrations/${path}" >"${root}/migration.next" && mv "${root}/migration.next" "${root}/migrations/${path}" && bind_predecessor_migration 2.0.0 "${path}" ;;
		from) jq '.from_version="9.9.9"' "${root}/migrations/${path}" >"${root}/migration.next" && mv "${root}/migration.next" "${root}/migrations/${path}" && bind_predecessor_migration 2.0.0 "${path}" ;;
		to) jq '.to_version="3.0.0"' "${root}/migrations/${path}" >"${root}/migration.next" && mv "${root}/migration.next" "${root}/migrations/${path}" && bind_predecessor_migration 2.0.0 "${path}" ;;
		operation-hash) jq '(.operations[0].after.sha256)=("f"*64)' "${root}/migrations/${path}" >"${root}/migration.next" && mv "${root}/migration.next" "${root}/migrations/${path}" && bind_predecessor_migration 2.0.0 "${path}" ;;
		operation-mode) jq '(.operations[0].after.mode)=(if .operations[0].after.mode == "644" then "755" else "644" end)' "${root}/migrations/${path}" >"${root}/migration.next" && mv "${root}/migration.next" "${root}/migrations/${path}" && bind_predecessor_migration 2.0.0 "${path}" ;;
		operation-presence) jq '.operations[0].after.presence="absent"' "${root}/migrations/${path}" >"${root}/migration.next" && mv "${root}/migration.next" "${root}/migrations/${path}" && bind_predecessor_migration 2.0.0 "${path}" ;;
		absolute) jq '.operations[0].target="/escape"' "${root}/migrations/${path}" >"${root}/migration.next" && mv "${root}/migration.next" "${root}/migrations/${path}" && bind_predecessor_migration 2.0.0 "${path}" ;;
		traversal) jq '.operations[0].source="../escape"' "${root}/migrations/${path}" >"${root}/migration.next" && mv "${root}/migration.next" "${root}/migrations/${path}" && bind_predecessor_migration 2.0.0 "${path}" ;;
		project-owned) jq '.operations[0].target="project-owned.txt"' "${root}/migrations/${path}" >"${root}/migration.next" && mv "${root}/migration.next" "${root}/migrations/${path}" && bind_predecessor_migration 2.0.0 "${path}" ;;
		generated) jq '.operations[0].target=".starter/state.json"' "${root}/migrations/${path}" >"${root}/migration.next" && mv "${root}/migration.next" "${root}/migrations/${path}" && bind_predecessor_migration 2.0.0 "${path}" ;;
		duplicate-target) jq '.operations += [.operations[0]]' "${root}/migrations/${path}" >"${root}/migration.next" && mv "${root}/migration.next" "${root}/migrations/${path}" && bind_predecessor_migration 2.0.0 "${path}" ;;
		ambiguous)
			jq -n '{schema:"starter-migration/v2",id:"ambiguous",from_version:"0.0.0",to_version:"1.5.0",operations:[]}' >"${root}/migrations/ambiguous.json"
			jq --arg sha "$(sha256sum "${root}/migrations/ambiguous.json" | cut -d' ' -f1)" \
				'.migrations.entries += [{id:"ambiguous",path:"ambiguous.json",sha256:$sha}]' "${root}/manifest.json" >"${root}/manifest.next"
			mv "${root}/manifest.next" "${root}/manifest.json"
			bind_predecessor_manifest 2.0.0
			;;
		esac
		run_prepare 2.1.0 2.0.0
		[ "${status}" -ne 0 ]
		[ ! -e "${PROJECT}/.starter/distribution/prepared/2.1.0" ]
	done
}

@test "prepare-release rejects predecessor closure ownership mode presence and identity tampering" {
	prepare_predecessor_fixture
	local root payload tamper
	root="${PROJECT}/.starter/distribution/prepared/2.0.0"
	payload="$(jq -r '.payload.entries[0].path' "${root}/manifest.json")"
	for tamper in missing symlink missing-migration extra extra-top ownership mode presence official-identity derived-identity; do
		restore_predecessor_fixture
		case "${tamper}" in
		missing) rm "${root}/payloads/${payload}" ;;
		symlink) rm "${root}/payloads/${payload}" && ln -s /etc/hosts "${root}/payloads/${payload}" ;;
		missing-migration) rm "${root}/migrations/from-0.0.0-to-2.0.0.json" ;;
		extra) printf 'extra\n' >"${root}/payloads/unlisted-extra" ;;
		extra-top) printf 'extra\n' >"${root}/unlisted-extra" ;;
		ownership) printf '\n' >>"${root}/ownership.json" ;;
		mode) jq '.payload.entries[0].mode=(if .payload.entries[0].mode == "644" then "755" else "644" end)' \
			"${root}/manifest.json" >"${root}/manifest.next" && mv "${root}/manifest.next" "${root}/manifest.json" && bind_predecessor_manifest 2.0.0 ;;
		presence) jq '.payload.entries[0].presence="absent"' "${root}/manifest.json" >"${root}/manifest.next" && mv "${root}/manifest.next" "${root}/manifest.json" && bind_predecessor_manifest 2.0.0 ;;
		official-identity) jq '.official_tree_sha256=("f"*64)' "${root}/index.json" >"${root}/index.next" && mv "${root}/index.next" "${root}/index.json" ;;
		derived-identity) jq '.transformation.derived_tree_sha256=("f"*64)' "${root}/index.json" >"${root}/index.next" && mv "${root}/index.next" "${root}/index.json" ;;
		esac
		run_prepare 2.1.0 2.0.0
		[ "${status}" -ne 0 ]
		[ ! -e "${PROJECT}/.starter/distribution/prepared/2.1.0" ]
	done
}
