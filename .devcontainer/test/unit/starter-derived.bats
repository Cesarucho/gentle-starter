#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/starter-derived-test.XXXXXX")"
}

teardown() { rm -rf "${TEST_ROOT}"; }

copy_official_fixture() {
	local destination="$1"
	mkdir -p "${destination}"
	rsync -a --exclude=.git --exclude=.env.d --exclude=.starter/distribution/prepared \
		"${REPO_ROOT}/" "${destination}/"
}

@test "official tree transforms deterministically into a consumer-only tree" {
	local first="${TEST_ROOT}/first" second="${TEST_ROOT}/second" modes="${TEST_ROOT}/tracked-modes" first_id second_id template_sha template_mode
	template_sha="$(sha256sum "${REPO_ROOT}/AGENTS.md.TEMPLATE" | cut -d' ' -f1)"
	template_mode="$(stat -c '%a' "${REPO_ROOT}/AGENTS.md.TEMPLATE")"
	git -C "${REPO_ROOT}" ls-files --stage -z >"${modes}"
	run bash -c 'source "$1"; starter_derived_transform "$2" "$3" "$4"; starter_derived_identity "$3"' _ \
		"${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/derived-tree.sh" "${REPO_ROOT}" "${first}" "${modes}"
	[ "$status" -eq 0 ]
	first_id="${output##*$'\n'}"
	run bash -c 'source "$1"; starter_derived_transform "$2" "$3" "$4"; starter_derived_identity "$3"' _ \
		"${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/derived-tree.sh" "${REPO_ROOT}" "${second}" "${modes}"
	[ "$status" -eq 0 ]
	second_id="${output##*$'\n'}"
	[ "${first_id}" = "${second_id}" ]
	[ ! -e "${first}/.taskfiles/project.yml" ]
	[ ! -e "${first}/.taskfiles/scripts/starter-release.sh" ]
	[ ! -e "${first}/.taskfiles/scripts/starter-prepare-release.sh" ]
	[ ! -e "${first}/.starter/distribution/manifest.json" ]
	[ ! -e "${first}/.starter/state.json" ]
	[ ! -e "${first}/AGENTS.md" ]
	[ ! -e "${first}/AGENTS.md.TEMPLATE.EXAMPLE" ]
	[ "$(sha256sum "${first}/AGENTS.md.TEMPLATE" | cut -d' ' -f1)" = "${template_sha}" ]
	[ "$(stat -c '%a' "${first}/AGENTS.md.TEMPLATE")" = "${template_mode}" ]
	[ -f "${first}/.devcontainer/docs/starter-updates.md" ]
	! grep -Fq 'project-init.bats' "${first}/.taskfiles/test.yml"
	! grep -Fq 'starter-release.bats' "${first}/.taskfiles/test.yml"
	grep -Fq 'starter-derived.bats' "${first}/.taskfiles/test.yml"
	run yq -e '.tasks.release or .tasks.prepare-release' "${first}/.taskfiles/starter.yml"
	[ "$status" -ne 0 ]
}

@test "official tree excludes every runtime-generated starter path" {
	local source="${TEST_ROOT}/source" destination="${TEST_ROOT}/derived" modes="${TEST_ROOT}/tracked-modes" path
	copy_official_fixture "${source}"
	git -C "${REPO_ROOT}" ls-files --stage -z >"${modes}"
	mkdir -p "${source}/.starter/evidence" "${source}/.starter/journals" "${source}/.starter/caches" \
		"${source}/.starter/proposals" "${source}/.starter/pending"
	printf '{}\n' >"${source}/.starter/state.json"
	for path in evidence journals caches proposals pending; do
		printf 'runtime marker\n' >"${source}/.starter/${path}/marker"
	done

	run bash -c 'source "$1"; starter_derived_transform "$2" "$3" "$4"' _ \
		"${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/derived-tree.sh" "${source}" "${destination}" "${modes}"
	[ "$status" -eq 0 ]
	for path in state.json evidence journals caches proposals pending; do
		[ ! -e "${destination}/.starter/${path}" ]
	done
}

@test "unexpected generated path makes transformation fail closed" {
	local source="${TEST_ROOT}/source" destination="${TEST_ROOT}/derived" modes="${TEST_ROOT}/tracked-modes"
	copy_official_fixture "${source}"
	git -C "${REPO_ROOT}" ls-files --stage -z >"${modes}"

	run bash -c '
		source "$1"
		starter_derived_transform_taskfile() { mkdir -p "$1/.starter/pending"; }
		starter_derived_transform "$2" "$3" "$4"
	' _ "${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/derived-tree.sh" "${source}" "${destination}" "${modes}"
	[ "$status" -ne 0 ]
	[[ "$output" == *"generated path is forbidden: .starter/pending"* ]]
}
