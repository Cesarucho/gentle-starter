#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	mkdir -p "${TEST_ROOT}/.taskfiles/scripts" "${TEST_ROOT}/.devcontainer/install/available" \
		"${TEST_ROOT}/.devcontainer/install/02-enabled" "${TEST_ROOT}/.devcontainer/install/01-core" \
		"${TEST_ROOT}/.devcontainer/install/03-hooks" "${TEST_ROOT}/.devcontainer/install/lib" \
		"${TEST_ROOT}/.devcontainer/install/templates"
	cp "${REPO_ROOT}/.taskfiles/scripts/install.sh" "${TEST_ROOT}/.taskfiles/scripts/"
	cp "${REPO_ROOT}/.devcontainer/install/dependencies.conf" "${TEST_ROOT}/.devcontainer/install/"
	touch "${TEST_ROOT}/.devcontainer/install/lib/common.sh" "${TEST_ROOT}/.devcontainer/install/templates/install-script.sh"
	for name in 20-runtime-node 30-ai-pi-coding 30-ai-pi-gentle 30-ai-engram 30-ai-skills; do
		printf '#!/usr/bin/env bash\n' >"${TEST_ROOT}/.devcontainer/install/available/${name}.sh"
	done
}

teardown() { rm -rf "${TEST_ROOT}"; }

@test "doctor rejects Pi Gentle without Pi Coding" {
	ln -s ../available/30-ai-pi-gentle.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/80-pi-gentle.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" doctor
	[ "$status" -eq 1 ]
	[[ "$output" == *"requires enabled installer 30-ai-pi-coding.sh"* ]]
}

@test "enable rolls back when a required installer is disabled" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/30-node.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" enable 30-ai-pi-gentle
	[ "$status" -eq 1 ]
	[ ! -L "${TEST_ROOT}/.devcontainer/install/02-enabled/80-pi-gentle.sh" ]
}

@test "disable refuses to strand an enabled dependent but ignores companions" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/30-node.sh"
	ln -s ../available/30-ai-engram.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/60-engram.sh"
	ln -s ../available/30-ai-pi-coding.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/70-pi-coding.sh"
	ln -s ../available/30-ai-pi-gentle.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/80-pi-gentle.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" disable 30-ai-pi-coding
	[ "$status" -eq 1 ]
	[ -L "${TEST_ROOT}/.devcontainer/install/02-enabled/70-pi-coding.sh" ]

	rm "${TEST_ROOT}/.devcontainer/install/02-enabled/80-pi-gentle.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" disable 30-ai-pi-coding
	[ "$status" -eq 0 ]
	[ -L "${TEST_ROOT}/.devcontainer/install/02-enabled/60-engram.sh" ]
}

@test "disable resolves an ordering alias before protecting dependents" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/30-node.sh"
	ln -s ../available/30-ai-pi-coding.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/70-pi-coding.sh"
	ln -s ../available/30-ai-pi-gentle.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/80-pi-gentle.sh"

	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" disable 70-pi-coding
	[ "$status" -eq 1 ]
	[[ "$output" == *"required by enabled installer(s): 30-ai-pi-gentle.sh"* ]]
	[ -L "${TEST_ROOT}/.devcontainer/install/02-enabled/70-pi-coding.sh" ]
	[ -L "${TEST_ROOT}/.devcontainer/install/02-enabled/80-pi-gentle.sh" ]
}

@test "ordered alias disable succeeds after disabling its dependent" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/30-node.sh"
	ln -s ../available/30-ai-pi-coding.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/70-pi-coding.sh"
	ln -s ../available/30-ai-pi-gentle.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/80-pi-gentle.sh"

	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" disable 80-pi-gentle
	[ "$status" -eq 0 ]
	[ ! -L "${TEST_ROOT}/.devcontainer/install/02-enabled/80-pi-gentle.sh" ]
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" disable 70-pi-coding
	[ "$status" -eq 0 ]
	[ ! -L "${TEST_ROOT}/.devcontainer/install/02-enabled/70-pi-coding.sh" ]
}

@test "disable still removes broken and out-of-catalog aliases" {
	printf '#!/usr/bin/env bash\n' >"${TEST_ROOT}/outside.sh"
	ln -s ../available/missing.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/40-broken.sh"
	ln -s "${TEST_ROOT}/outside.sh" "${TEST_ROOT}/.devcontainer/install/02-enabled/50-outside.sh"

	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" disable 40-broken
	[ "$status" -eq 0 ]
	[ ! -L "${TEST_ROOT}/.devcontainer/install/02-enabled/40-broken.sh" ]
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" disable 50-outside
	[ "$status" -eq 0 ]
	[ ! -L "${TEST_ROOT}/.devcontainer/install/02-enabled/50-outside.sh" ]
	[ -f "${TEST_ROOT}/outside.sh" ]
}

@test "doctor accepts ordered Pi and npm dependencies and list reports no remaining tools" {
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/30-node.sh"
	ln -s ../available/30-ai-engram.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/60-engram.sh"
	ln -s ../available/30-ai-pi-coding.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/70-pi-coding.sh"
	ln -s ../available/30-ai-pi-gentle.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/80-pi-gentle.sh"
	ln -s ../available/30-ai-skills.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/90-skills.sh"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" doctor
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok: enabled installer dependencies"* ]]
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list
	[ "$status" -eq 0 ]
	[[ "$output" == *"  (no tools available to enable)"* ]]
}

@test "list excludes canonical targets enabled through custom aliases and keeps other sections" {
	touch "${TEST_ROOT}/.devcontainer/install/01-core/core.sh" "${TEST_ROOT}/.devcontainer/install/03-hooks/hook.sh"
	ln -s ../available/20-runtime-node.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/25-custom-node.sh"
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
	ln -s ../available/missing.sh "${TEST_ROOT}/.devcontainer/install/02-enabled/40-broken.sh"
	ln -s "${TEST_ROOT}/20-runtime-node.sh" "${TEST_ROOT}/.devcontainer/install/02-enabled/50-outside.sh"
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
	[[ "$output" == *$'\n  40-python-graphify.sh — requires image: 01-core/10-system.sh\n'* ]]
}

@test "list separates multiple declared dependencies readably" {
	printf '%s\n' \
		'30-ai-pi-gentle.sh|enabled|20-runtime-node.sh|npm' \
		'30-ai-pi-gentle.sh|image|01-core/10-system.sh|python3' \
		>>"${TEST_ROOT}/.devcontainer/install/dependencies.conf"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list
	[ "$status" -eq 0 ]
	[[ "$output" == *$'\n  30-ai-pi-gentle.sh — requires: 30-ai-pi-coding.sh; requires: 20-runtime-node.sh; requires image: 01-core/10-system.sh\n'* ]]
}

@test "list keeps plain names when dependency metadata is missing" {
	rm "${TEST_ROOT}/.devcontainer/install/dependencies.conf"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list
	[ "$status" -eq 0 ]
	[[ "$output" == *$'\n  30-ai-pi-coding.sh\n'* ]]
	[[ "$output" != *" — "* ]]
}

@test "list preserves the presets alias and rejects unknown options" {
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list
	[ "$status" -eq 0 ]
	local plain_output="$output"
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list --presets
	[ "$status" -eq 0 ]
	[ "$output" = "$plain_output" ]
	run bash "${TEST_ROOT}/.taskfiles/scripts/install.sh" list --json
	[ "$status" -eq 2 ]
	[[ "$output" == *"ERROR: list accepts no arguments or the legacy --presets alias"* ]]
}
