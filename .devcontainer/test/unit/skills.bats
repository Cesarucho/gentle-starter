#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	mkdir -p "${TEST_ROOT}/.taskfiles/scripts" "${TEST_ROOT}/.agents/skills/locked" "${TEST_ROOT}/.agents/skills/local"
	cp "${REPO_ROOT}/.taskfiles/scripts/skills.sh" "${TEST_ROOT}/.taskfiles/scripts/skills.sh"
	cat >"${TEST_ROOT}/skills-lock.json" <<'EOF'
{"version":1,"skills":{"locked":{}}}
EOF
	printf '%s\n' '# Project-authored skills' 'local' >"${TEST_ROOT}/.agents/local-skills.txt"
	touch "${TEST_ROOT}/.agents/skills/locked/SKILL.md" "${TEST_ROOT}/.agents/skills/local/SKILL.md"
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

@test "skills validate accepts locked and project-local skills" {
	run bash "${TEST_ROOT}/.taskfiles/scripts/skills.sh" validate

	[ "$status" -eq 0 ]
	[[ "$output" == *"ok: locked (locked)"* ]]
	[[ "$output" == *"ok: local (project-local)"* ]]
}

@test "skills prune preserves managed entries and removes unmanaged directories and symlinks" {
	mkdir -p "${TEST_ROOT}/.agents/skills/unmanaged" "${TEST_ROOT}/external-skill"
	touch "${TEST_ROOT}/.agents/skills/unmanaged/SKILL.md" "${TEST_ROOT}/external-skill/SKILL.md"
	ln -s "${TEST_ROOT}/external-skill" "${TEST_ROOT}/.agents/skills/unmanaged-link"

	run bash "${TEST_ROOT}/.taskfiles/scripts/skills.sh" prune

	[ "$status" -eq 0 ]
	[ -d "${TEST_ROOT}/.agents/skills/locked" ]
	[ -d "${TEST_ROOT}/.agents/skills/local" ]
	[ ! -e "${TEST_ROOT}/.agents/skills/unmanaged" ]
	[ ! -L "${TEST_ROOT}/.agents/skills/unmanaged-link" ]
	[ -f "${TEST_ROOT}/external-skill/SKILL.md" ]
}

@test "skills prune cannot escape through newline-containing names" {
	local hostile_name=$'junk\noutside'
	mkdir -p "${TEST_ROOT}/.agents/skills/${hostile_name}" "${TEST_ROOT}/outside"
	touch "${TEST_ROOT}/.agents/skills/${hostile_name}/SKILL.md" "${TEST_ROOT}/outside/SENTINEL"

	run bash -c "cd '${TEST_ROOT}' && bash .taskfiles/scripts/skills.sh prune"

	[ "$status" -eq 0 ]
	[ ! -e "${TEST_ROOT}/.agents/skills/${hostile_name}" ]
	[ -f "${TEST_ROOT}/outside/SENTINEL" ]
}

@test "skills commands reject managed skill symlinks" {
	rm -rf "${TEST_ROOT}/.agents/skills/local"
	mkdir -p "${TEST_ROOT}/external-managed"
	touch "${TEST_ROOT}/external-managed/SKILL.md"
	ln -s "${TEST_ROOT}/external-managed" "${TEST_ROOT}/.agents/skills/local"

	run bash "${TEST_ROOT}/.taskfiles/scripts/skills.sh" validate
	[ "$status" -ne 0 ]
	[[ "$output" == *"invalid managed skill symlink"* ]]

	run bash "${TEST_ROOT}/.taskfiles/scripts/skills.sh" prune
	[ "$status" -ne 0 ]
	[ -L "${TEST_ROOT}/.agents/skills/local" ]
}

@test "skills validate rejects unsafe or duplicate local names" {
	printf '%s\n' '../escape' >"${TEST_ROOT}/.agents/local-skills.txt"
	run bash "${TEST_ROOT}/.taskfiles/scripts/skills.sh" validate
	[ "$status" -ne 0 ]
	[[ "$output" == *"invalid project-local skill name"* ]]

	printf '%s\n' 'locked' >"${TEST_ROOT}/.agents/local-skills.txt"
	run bash "${TEST_ROOT}/.taskfiles/scripts/skills.sh" validate
	[ "$status" -ne 0 ]
	[[ "$output" == *"also exists in skills-lock.json"* ]]
}

@test "skills commands fail closed on malformed lock data" {
	printf '%s\n' '{invalid' >"${TEST_ROOT}/skills-lock.json"

	run bash "${TEST_ROOT}/.taskfiles/scripts/skills.sh" validate
	[ "$status" -ne 0 ]
	[[ "$output" == *"invalid skills-lock.json"* ]]

	run bash "${TEST_ROOT}/.taskfiles/scripts/skills.sh" prune
	[ "$status" -ne 0 ]
	[ -d "${TEST_ROOT}/.agents/skills/locked" ]

	printf '%s\n' '{"version":1,"skills":null}' >"${TEST_ROOT}/skills-lock.json"
	run bash "${TEST_ROOT}/.taskfiles/scripts/skills.sh" prune
	[ "$status" -ne 0 ]
	[ -d "${TEST_ROOT}/.agents/skills/locked" ]
}

@test "skills validate rejects unsafe locked names" {
	mkdir -p "${TEST_ROOT}/.agents/outside"
	touch "${TEST_ROOT}/.agents/outside/SKILL.md"
	printf '%s\n' '{"version":1,"skills":{"../outside":{}}}' >"${TEST_ROOT}/skills-lock.json"

	run bash "${TEST_ROOT}/.taskfiles/scripts/skills.sh" validate

	[ "$status" -ne 0 ]
	[[ "$output" == *"invalid locked skill name"* ]]
}

@test "add-tool installer template preserves backup when rollback fails" {
	local template="${REPO_ROOT}/.agents/skills/add-tool/templates/install-script.sh"
	local replacement_line verification_line

	grep -q 'trap cleanup EXIT' "${template}"
	# Assert literal template variables and recovery contract.
	# shellcheck disable=SC2016
	grep -q 'if devcontainer_run_as_root mv -f "${backup}" "${target}"' "${template}"
	grep -q 'preserve_backup=1' "${template}"
	grep -q 'status=1' "${template}"
	grep -q 'Rollback failed; previous binary preserved at' "${template}"
	# shellcheck disable=SC2016
	grep -q 'if \[ "${preserve_backup}" -eq 0 \]' "${template}"
	replacement_line="$(grep -n '^target_replaced=1$' "${template}" | cut -d: -f1)"
	verification_line="$(grep -n '^install_verified=1$' "${template}" | cut -d: -f1)"
	[ "${replacement_line}" -lt "${verification_line}" ]
}

@test "root test task executes the complete included aggregate" {
	run bash -c "cd '${REPO_ROOT}' && task --dry test"

	[ "$status" -eq 0 ]
	[[ "$output" == *'skills.bats'* ]]
	[[ "$output" == *'integration/tools.bats'* ]]
}
