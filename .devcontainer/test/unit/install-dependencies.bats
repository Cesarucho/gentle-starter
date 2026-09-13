#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	mkdir -p "${TEST_ROOT}/.taskfiles/scripts" "${TEST_ROOT}/.devcontainer/install/available" \
		"${TEST_ROOT}/.devcontainer/install/03-enabled" "${TEST_ROOT}/.devcontainer/install/01-foundation" \
		"${TEST_ROOT}/.devcontainer/install/02-core-tools" \
		"${TEST_ROOT}/.devcontainer/install/04-hooks" "${TEST_ROOT}/.devcontainer/install/lib" \
		"${TEST_ROOT}/.devcontainer/install/templates"
	cp "${REPO_ROOT}/.taskfiles/scripts/install.sh" "${TEST_ROOT}/.taskfiles/scripts/"
	cp "${REPO_ROOT}/.taskfiles/install.yml" "${TEST_ROOT}/.taskfiles/"
	printf 'version: "3"\nincludes:\n  install: ./.taskfiles/install.yml\n' >"${TEST_ROOT}/Taskfile.yml"
	cp "${REPO_ROOT}/.devcontainer/install/dependencies.conf" "${TEST_ROOT}/.devcontainer/install/"
	cp "${REPO_ROOT}/.devcontainer/install/lib/activation.sh" "${TEST_ROOT}/.devcontainer/install/lib/"
	touch "${TEST_ROOT}/.devcontainer/install/lib/common.sh" "${TEST_ROOT}/.devcontainer/install/templates/install-script.sh"
	for name in 20-runtime-node 30-ai-pi-coding 30-ai-pi-gentle 30-ai-engram 30-ai-skills; do
		printf '#!/usr/bin/env bash\n' >"${TEST_ROOT}/.devcontainer/install/available/${name}.sh"
	done
}

teardown() { rm -rf "${TEST_ROOT}"; }

@test "doctor rejects Pi Gentle without Pi Coding" {
	ln -s ../available/30-ai-pi-gentle.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/80-pi-gentle.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" doctor
	[ "$status" -eq 1 ]
	[[ "$output" == *"requires enabled installer 30-ai-pi-coding.sh"* ]]
}

@test "enable rolls back when a required installer is disabled" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/30-node.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" enable 30-ai-pi-gentle
	[ "$status" -eq 1 ]
	[ ! -L "${TEST_ROOT}/.devcontainer/install/03-enabled/80-pi-gentle.sh" ]
}

@test "disable refuses to strand an enabled dependent but ignores companions" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/30-node.sh"
	ln -s ../available/30-ai-engram.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/60-engram.sh"
	ln -s ../available/30-ai-pi-coding.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/70-pi-coding.sh"
	ln -s ../available/30-ai-pi-gentle.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/80-pi-gentle.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" disable 30-ai-pi-coding
	[ "$status" -eq 1 ]
	[ -L "${TEST_ROOT}/.devcontainer/install/03-enabled/70-pi-coding.sh" ]

	rm "${TEST_ROOT}/.devcontainer/install/03-enabled/80-pi-gentle.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" disable 30-ai-pi-coding
	[ "$status" -eq 0 ]
	[ -L "${TEST_ROOT}/.devcontainer/install/03-enabled/60-engram.sh" ]
}

@test "disable resolves an ordering alias before protecting dependents" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/30-node.sh"
	ln -s ../available/30-ai-pi-coding.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/70-pi-coding.sh"
	ln -s ../available/30-ai-pi-gentle.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/80-pi-gentle.sh"

	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" disable 70-pi-coding
	[ "$status" -eq 1 ]
	[[ "$output" == *"required by enabled installer(s): 30-ai-pi-gentle.sh"* ]]
	[ -L "${TEST_ROOT}/.devcontainer/install/03-enabled/70-pi-coding.sh" ]
	[ -L "${TEST_ROOT}/.devcontainer/install/03-enabled/80-pi-gentle.sh" ]
}

@test "ordered alias disable succeeds after disabling its dependent" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/30-node.sh"
	ln -s ../available/30-ai-pi-coding.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/70-pi-coding.sh"
	ln -s ../available/30-ai-pi-gentle.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/80-pi-gentle.sh"

	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" disable 80-pi-gentle
	[ "$status" -eq 0 ]
	[ ! -L "${TEST_ROOT}/.devcontainer/install/03-enabled/80-pi-gentle.sh" ]
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" disable 70-pi-coding
	[ "$status" -eq 0 ]
	[ ! -L "${TEST_ROOT}/.devcontainer/install/03-enabled/70-pi-coding.sh" ]
}

@test "disable still removes broken and out-of-catalog aliases" {
	printf '#!/usr/bin/env bash\n' >"${TEST_ROOT}/outside.sh"
	ln -s ../available/missing.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/40-broken.sh"
	ln -s "${TEST_ROOT}/outside.sh" "${TEST_ROOT}/.devcontainer/install/03-enabled/50-outside.sh"

	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" disable 40-broken
	[ "$status" -eq 0 ]
	[ ! -L "${TEST_ROOT}/.devcontainer/install/03-enabled/40-broken.sh" ]
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" disable 50-outside
	[ "$status" -eq 0 ]
	[ ! -L "${TEST_ROOT}/.devcontainer/install/03-enabled/50-outside.sh" ]
	[ -f "${TEST_ROOT}/outside.sh" ]
}

@test "doctor accepts ordered Pi and npm dependencies and list reports no remaining tools" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/30-node.sh"
	ln -s ../available/30-ai-engram.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/60-engram.sh"
	ln -s ../available/30-ai-pi-coding.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/70-pi-coding.sh"
	ln -s ../available/30-ai-pi-gentle.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/80-pi-gentle.sh"
	ln -s ../available/30-ai-skills.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/90-skills.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" doctor
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok: enabled installer dependencies"* ]]
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list
	[ "$status" -eq 0 ]
	[[ "$output" == *"  (no tools available to enable)"* ]]
}

@test "list excludes canonical targets enabled through custom aliases and keeps other sections" {
	touch "${TEST_ROOT}/.devcontainer/install/01-foundation/core.sh" "${TEST_ROOT}/.devcontainer/install/04-hooks/hook.sh"
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/25-custom-node.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list
	[ "$status" -eq 0 ]
	[[ "$output" == *"  core.sh"* ]]
	[[ "$output" == *"  hook.sh"* ]]
	[[ "$output" == *"25-custom-node.sh -> ../available/20-runtime-node.sh"* ]]
	local available_section="${output#*available (}"
	[[ "$available_section" != *$'\n  20-runtime-node.sh'* ]]
	[[ "$available_section" == *"30-ai-engram.sh — optional companion: 30-ai-pi-coding.sh"* ]]
}

@test "list keeps broken and out-of-catalog aliases visible without hiding available tools" {
	touch "${TEST_ROOT}/20-runtime-node.sh"
	ln -s ../available/missing.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/40-broken.sh"
	ln -s "${TEST_ROOT}/20-runtime-node.sh" "${TEST_ROOT}/.devcontainer/install/03-enabled/50-outside.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list
	[ "$status" -eq 0 ]
	[[ "$output" == *"40-broken.sh -> ../available/missing.sh"* ]]
	[[ "$output" == *"50-outside.sh -> ${TEST_ROOT}/20-runtime-node.sh"* ]]
	[[ "$output" == *$'\n  20-runtime-node.sh\n'* ]]
}

@test "list shows plain disabled names and prerequisites without duplicate status" {
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list
	[ "$status" -eq 0 ]
	[[ "$output" == *$'available (not enabled):\n  20-runtime-node.sh\n'* ]]
	[[ "$output" == *$'\n  30-ai-pi-coding.sh — requires: 20-runtime-node.sh\n'* ]]
	[[ "$output" != *".sh (not enabled)"* ]]
	[[ "$output" != *"[enabled:"* ]]
}

@test "list distinguishes image requirements without checking their availability" {
	touch "${TEST_ROOT}/.devcontainer/install/available/40-python-graphify.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list
	[ "$status" -eq 0 ]
	[[ "$output" == *$'\n  40-python-graphify.sh — requires image: 01-foundation/10-system.sh\n'* ]]
}

@test "list separates multiple declared dependencies readably" {
	printf '%s\n' \
		'30-ai-pi-gentle.sh|enabled|20-runtime-node.sh|npm' \
		'30-ai-pi-gentle.sh|image|01-foundation/10-system.sh|python3' \
		>>"${TEST_ROOT}/.devcontainer/install/dependencies.conf"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list
	[ "$status" -eq 0 ]
	[[ "$output" == *$'\n  30-ai-pi-gentle.sh — requires: 30-ai-pi-coding.sh; requires: 20-runtime-node.sh; requires image: 01-foundation/10-system.sh\n'* ]]
}

@test "list keeps plain names when dependency metadata is missing" {
	rm "${TEST_ROOT}/.devcontainer/install/dependencies.conf"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list
	[ "$status" -eq 0 ]
	[[ "$output" == *$'\n  30-ai-pi-coding.sh\n'* ]]
	[[ "$output" != *" — "* ]]
}

@test "list rejects arguments including the removed presets flag" {
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list
	[ "$status" -eq 0 ]
	local option
	for option in --presets --json; do
		run task --exit-code --dir "${TEST_ROOT}" install:list -- "${option}"
		[ "$status" -eq 2 ]
		[[ "$output" == *"ERROR: list accepts no arguments"* ]]
	done
}

@test "core dependencies precede optional tools regardless of alias numbers" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/02-core-tools/99-node.sh"
	ln -s ../available/30-ai-skills.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/01-skills.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" doctor
	[ "$status" -eq 0 ]
}

@test "core consumer cannot depend on a later optional group" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/01-node.sh"
	ln -s ../available/30-ai-skills.sh "${TEST_ROOT}/.devcontainer/install/02-core-tools/99-skills.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" doctor
	[ "$status" -eq 1 ]
	[[ "$output" == *"must run before"* ]]
}

@test "core installers reject optional enable and disable by source or alias" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/02-core-tools/99-node.sh"
	for operation in 'enable 20-runtime-node' 'disable 20-runtime-node' 'disable 99-node'; do
		# Intentional argument splitting of fixed test cases.
		# shellcheck disable=SC2086
		run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" ${operation}
		[ "$status" -eq 1 ]
		[[ "$output" == *"mandatory 02-core-tools"* ]]
	done
	[ -L "${TEST_ROOT}/.devcontainer/install/02-core-tools/99-node.sh" ]
	[ ! -e "${TEST_ROOT}/.devcontainer/install/03-enabled/30-node.sh" ]
}

@test "doctor rejects duplicate canonical installers across groups" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/02-core-tools/99-node.sh"
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/01-node.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" doctor
	[ "$status" -eq 1 ]
	[[ "$output" == *"duplicate installer"* ]]
}

@test "list does not repeat core targets among tools available to enable" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/02-core-tools/99-node.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list
	[ "$status" -eq 0 ]
	[[ "$output" == *"02-core-tools (mandatory tools)"* ]]
	local available_section="${output#*available (}"
	[[ "$available_section" != *$'\n  20-runtime-node.sh'* ]]
}

@test "Task enable and disable reject path traversal without touching aliases" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/02-core-tools/99-node.sh"
	ln -s available/30-ai-engram.sh "${TEST_ROOT}/.devcontainer/install/outside.sh"
	for operation in enable disable; do
		for name in ../outside ../02-core-tools/99-node /tmp/unknown; do
			run task --dir "${TEST_ROOT}" "install:${operation}" -- "${name}"
			[ "$status" -ne 0 ]
			[[ "$output" == *"NAME must be a filename, not a path"* ]]
			[ -L "${TEST_ROOT}/.devcontainer/install/outside.sh" ]
			[ -L "${TEST_ROOT}/.devcontainer/install/02-core-tools/99-node.sh" ]
			[ ! -L "${TEST_ROOT}/.devcontainer/install/03-enabled/outside.sh" ]
		done
	done
}

@test "Task optional activation is idempotent and uses core dependencies" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/02-core-tools/99-node.sh"
	for _ in 1 2; do
		run task --dir "${TEST_ROOT}" install:enable -- 30-ai-pi-coding
		[ "$status" -eq 0 ]
		[ "$(readlink "${TEST_ROOT}/.devcontainer/install/03-enabled/70-pi-coding.sh")" = ../available/30-ai-pi-coding.sh ]
	done
	run task --dir "${TEST_ROOT}" install:disable -- 70-pi-coding
	[ "$status" -eq 0 ]
	[ ! -L "${TEST_ROOT}/.devcontainer/install/03-enabled/70-pi-coding.sh" ]
	[ -f "${TEST_ROOT}/.devcontainer/install/available/30-ai-pi-coding.sh" ]
	run task --dir "${TEST_ROOT}" install:doctor
	[ "$status" -eq 0 ]
}

@test "Task PHP activation orders canonical installers and remains idempotent" {
	local install_dir="${TEST_ROOT}/.devcontainer/install" name
	for name in lang debug test; do
		cp "${REPO_ROOT}/.devcontainer/install/available/40-php-${name}.sh" "${install_dir}/available/"
	done

	for _ in 1 2; do
		for name in lang debug test; do
			run task --dir "${TEST_ROOT}" install:enable -- "40-php-${name}"
			[ "$status" -eq 0 ]
		done
		local aliases=("${install_dir}/03-enabled/"*.sh)
		[ "${#aliases[@]}" -eq 3 ]
		[ "${aliases[0]##*/}" = 40-php-lang.sh ]
		[ "${aliases[1]##*/}" = 41-php-debug.sh ]
		[ "${aliases[2]##*/}" = 42-php-test.sh ]
		for name in "${aliases[@]}"; do
			[ -L "${name}" ]
		done
		[ "$(readlink -f "${aliases[0]}")" = "${install_dir}/available/40-php-lang.sh" ]
		[ "$(readlink -f "${aliases[1]}")" = "${install_dir}/available/40-php-debug.sh" ]
		[ "$(readlink -f "${aliases[2]}")" = "${install_dir}/available/40-php-test.sh" ]
		run task --dir "${TEST_ROOT}" install:doctor
		[ "$status" -eq 0 ]
		[[ "$output" == *"ok: enabled installer dependencies"* ]]
	done
}

@test "Task core guards and unknown enable fail without optional activation" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/02-core-tools/99-node.sh"
	for operation in enable disable; do
		run task --dir "${TEST_ROOT}" "install:${operation}" -- 20-runtime-node
		[ "$status" -ne 0 ]
		[[ "$output" == *"mandatory 02-core-tools"* ]]
	done
	run task --dir "${TEST_ROOT}" install:enable -- unknown
	[ "$status" -ne 0 ]
	[ -L "${TEST_ROOT}/.devcontainer/install/02-core-tools/99-node.sh" ]
	[ ! -L "${TEST_ROOT}/.devcontainer/install/03-enabled/30-node.sh" ]
}

@test "Task help and list expose all groups and selected manifest semantics" {
	run task --dir "${TEST_ROOT}" install:help
	[ "$status" -eq 0 ]
	[[ "$output" == *"validated selected Compose manifest, not applied mounts"* ]]
	run task --dir "${TEST_ROOT}" install:list
	[ "$status" -eq 0 ]
	for group in 01-foundation 02-core-tools 03-enabled 04-hooks; do
		[[ "$output" == *"${group}"* ]]
	done
}

@test "Task versions validation reads the public policy without changing it" {
	cp "${REPO_ROOT}/.devcontainer/tool-versions.conf" "${TEST_ROOT}/.devcontainer/"
	cp "${REPO_ROOT}/.devcontainer/install/lib/common.sh" "${REPO_ROOT}/.devcontainer/install/lib/archify-archive.sh" "${TEST_ROOT}/.devcontainer/install/lib/"
	cp "${REPO_ROOT}/.taskfiles/scripts/deps-update.sh" "${TEST_ROOT}/.taskfiles/scripts/"
	local before
	before="$(sha256sum "${TEST_ROOT}/.devcontainer/tool-versions.conf")"
	run env DEPS_UPDATE_CURL=false DEPS_UPDATE_PNPM=false DEPS_UPDATE_JQ=false task --dir "${TEST_ROOT}" install:versions:validate
	[ "$status" -eq 0 ]
	[ "$(sha256sum "${TEST_ROOT}/.devcontainer/tool-versions.conf")" = "$before" ]
	[[ "$output" == *"ok:"* ]]
}

@test "Task doctor rejects broken and escaping core aliases" {
	ln -s ../available/missing.sh "${TEST_ROOT}/.devcontainer/install/02-core-tools/10-broken.sh"
	ln -s ../templates/install-script.sh "${TEST_ROOT}/.devcontainer/install/02-core-tools/20-outside.sh"
	run task --dir "${TEST_ROOT}" install:doctor
	[ "$status" -ne 0 ]
	[[ "$output" == *"invalid or broken symlink 02-core-tools/10-broken.sh"* ]]
	[[ "$output" == *"must target an available shell installer"* ]]
}

@test "Task doctor checks optional dependency ordering and disable protects core consumers" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/99-node.sh"
	ln -s ../available/30-ai-skills.sh "${TEST_ROOT}/.devcontainer/install/03-enabled/01-skills.sh"
	run task --dir "${TEST_ROOT}" install:doctor
	[ "$status" -ne 0 ]
	[[ "$output" == *"must run before"* ]]
	mv "${TEST_ROOT}/.devcontainer/install/03-enabled/01-skills.sh" "${TEST_ROOT}/.devcontainer/install/02-core-tools/01-skills.sh"
	run task --dir "${TEST_ROOT}" install:disable -- 99-node
	[ "$status" -ne 0 ]
	[[ "$output" == *"required by enabled installer(s): 30-ai-skills.sh"* ]]
	[ -L "${TEST_ROOT}/.devcontainer/install/03-enabled/99-node.sh" ]
}
