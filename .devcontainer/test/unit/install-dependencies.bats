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

@test "doctor accepts ordered Pi and npm dependencies and list describes companions" {
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
	[[ "$output" == *"30-ai-engram.sh (enabled) [companion:30-ai-pi-coding.sh]"* ]]
}
