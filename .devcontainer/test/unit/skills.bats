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

prepare_skill_update_sandbox() {
	mkdir -p "${TEST_ROOT}/bin" "${TEST_ROOT}/.claude/skills"
	cp "${REPO_ROOT}/.taskfiles/skills.yml" "${TEST_ROOT}/skills.yml"
	cat >"${TEST_ROOT}/Taskfile.yml" <<'EOF'
version: "3"
includes:
  skill:
    taskfile: ./skills.yml
EOF
	cat >"${TEST_ROOT}/bin/skills" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${SKILLS_CALL_LOG}"
if [ "$1" = update ]; then
	[ "${SKILLS_UPDATE_FAIL:-0}" -eq 0 ] || exit 42
	ln -s ../../.agents/skills/locked .claude/skills/locked
	exit 0
fi
if [ "$*" = "remove --agent claude-code --skill * -y" ]; then
	rm -f .claude/skills/*
	exit 0
fi
exit 64
EOF
	chmod +x "${TEST_ROOT}/bin/skills"
}

@test "skills validate accepts locked and project-local skills" {
	run bash "${TEST_ROOT}/.taskfiles/scripts/skills.sh" validate

	[ "$status" -eq 0 ]
	[[ "$output" == *"ok: locked (locked)"* ]]
	[[ "$output" == *"ok: local (project-local)"* ]]
}

@test "skill update stops before compatibility cleanup when update fails" {
	prepare_skill_update_sandbox
	local call_log="${TEST_ROOT}/skills-calls.log"

	run env PATH="${TEST_ROOT}/bin:${PATH}" SKILLS_CALL_LOG="${call_log}" \
		SKILLS_UPDATE_FAIL=1 task --dir "${TEST_ROOT}" skill:update

	[ "$status" -ne 0 ]
	[ "$(cat "${call_log}")" = "update --project -y" ]
}

@test "skill update removes only generated Claude compatibility links" {
	prepare_skill_update_sandbox
	local call_log="${TEST_ROOT}/skills-calls.log"
	local lock_before canonical_before
	lock_before="$(sha256sum "${TEST_ROOT}/skills-lock.json")"
	canonical_before="$(sha256sum "${TEST_ROOT}/.agents/skills/locked/SKILL.md")"

	run env PATH="${TEST_ROOT}/bin:${PATH}" SKILLS_CALL_LOG="${call_log}" \
		task --dir "${TEST_ROOT}" skill:update

	[ "$status" -eq 0 ]
	[ "$(sed -n '1p' "${call_log}")" = "update --project -y" ]
	[ "$(sed -n '2p' "${call_log}")" = "remove --agent claude-code --skill * -y" ]
	[ "$(wc -l <"${call_log}")" -eq 2 ]
	[ -d "${TEST_ROOT}/.agents/skills/locked" ]
	[ "$(sha256sum "${TEST_ROOT}/skills-lock.json")" = "${lock_before}" ]
	[ "$(sha256sum "${TEST_ROOT}/.agents/skills/locked/SKILL.md")" = "${canonical_before}" ]
	[ -z "$(ls -A "${TEST_ROOT}/.claude/skills")" ]
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

@test "add-tool inspector reports concise normalized architecture facts" {
	local inspector="${REPO_ROOT}/.agents/skills/add-tool/scripts/inspect-install-tree.sh"

	run bash "${inspector}" "${REPO_ROOT}"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"prepare-bind-mounts.sh"* ]]
	[[ "${output}" == *"prepare-bind-mounts.py"* ]]
	[[ "${output}" == *"bind_records: .devcontainer/compose-volume-records.py"* ]]
	[[ "${output}" == *"canonical_template: .devcontainer/install/templates/install-script.sh"* ]]
	[[ "${output}" == *"Policy: .devcontainer/tool-versions.conf"* ]]
	[[ "${output}" != *"preferred_enabled_name()"* ]]
}

@test "add-tool inspector emits structured JSON" {
	local inspector="${REPO_ROOT}/.agents/skills/add-tool/scripts/inspect-install-tree.sh"

	run bash "${inspector}" --format=json "${REPO_ROOT}"

	[ "${status}" -eq 0 ]
	printf '%s' "${output}" | jq -e '
		.repository and
		(.available | type == "array") and
		(.enabled | type == "array") and
		(.broken_aliases | type == "array") and
		(.unsafe_aliases | type == "array") and
		(.duplicate_slots | type == "object") and
		(.policy.keys | index("TOOL_GENTLE_AI_VERSION")) and
		(.paths.host_prepare_python == ".taskfiles/scripts/prepare-bind-mounts.py")
	' >/dev/null
}

@test "add-tool inspector distinguishes escaping and non-file aliases" {
	local inspector="${REPO_ROOT}/.agents/skills/add-tool/scripts/inspect-install-tree.sh"
	local fixture_root
	fixture_root="$(mktemp -d)"
	mkdir -p "${fixture_root}/.devcontainer/install/available/not-an-installer" \
		"${fixture_root}/.devcontainer/install/02-enabled" \
		"${fixture_root}/outside"
	touch "${fixture_root}/.devcontainer/install/available/40-valid.sh" \
		"${fixture_root}/outside/escape.sh"
	ln -s "${fixture_root}/.devcontainer/install/available/40-valid.sh" \
		"${fixture_root}/.devcontainer/install/02-enabled/40-valid.sh"
	ln -s "${fixture_root}/outside/escape.sh" \
		"${fixture_root}/.devcontainer/install/02-enabled/50-escape.sh"
	ln -s "../available/not-an-installer" \
		"${fixture_root}/.devcontainer/install/02-enabled/60-directory.sh"

	run bash "${inspector}" --format=json "${fixture_root}"
	[ "${status}" -eq 0 ]
	printf '%s' "${output}" | jq -e '
		(.broken_aliases == []) and
		(.unsafe_aliases == [
			{"alias":"50-escape.sh","reason":"outside_available"},
			{"alias":"60-directory.sh","reason":"not_regular_shell_installer"}
		]) and
		(.available[0].enabled_aliases == ["40-valid.sh"]) and
		(.enabled | map(select(.alias == "50-escape.sh"))[0].broken == false) and
		(.enabled | map(select(.alias == "60-directory.sh"))[0].unsafe_reason == "not_regular_shell_installer")
	' >/dev/null

	run bash "${inspector}" "${fixture_root}"
	rm -rf "${fixture_root}"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"50-escape.sh -> ${fixture_root}/outside/escape.sh [UNSAFE: outside_available]"* ]]
	[[ "${output}" == *"60-directory.sh -> ../available/not-an-installer [UNSAFE: not_regular_shell_installer]"* ]]
	[[ "${output}" == *"Broken aliases: none"* ]]
	[[ "${output}" == *"Unsafe aliases: 50-escape.sh=outside_available, 60-directory.sh=not_regular_shell_installer"* ]]
}

@test "add-tool inspector rejects an invalid repository root clearly" {
	local inspector="${REPO_ROOT}/.agents/skills/add-tool/scripts/inspect-install-tree.sh"
	local invalid_root
	invalid_root="$(mktemp -d)"

	run bash "${inspector}" "${invalid_root}"
	rm -rf "${invalid_root}"

	[ "${status}" -eq 2 ]
	[[ "${output}" == *"invalid repository root; missing .devcontainer/install"* ]]
}

@test "add-tool inspector detects broken aliases and duplicate enabled slots" {
	local inspector="${REPO_ROOT}/.agents/skills/add-tool/scripts/inspect-install-tree.sh"
	local fixture_root
	fixture_root="$(mktemp -d)"
	mkdir -p "${fixture_root}/.devcontainer/install/available" \
		"${fixture_root}/.devcontainer/install/02-enabled"
	touch "${fixture_root}/.devcontainer/install/available/40-one.sh" \
		"${fixture_root}/.devcontainer/install/available/40-two.sh"
	ln -s "../available/40-one.sh" "${fixture_root}/.devcontainer/install/02-enabled/50-one.sh"
	ln -s "../available/40-two.sh" "${fixture_root}/.devcontainer/install/02-enabled/50-two.sh"
	ln -s "../available/missing.sh" "${fixture_root}/.devcontainer/install/02-enabled/60-missing.sh"

	run bash "${inspector}" --format=json "${fixture_root}"
	rm -rf "${fixture_root}"

	[ "${status}" -eq 0 ]
	printf '%s' "${output}" | jq -e '
		(.broken_aliases == ["60-missing.sh"]) and
		(.duplicate_slots["50"] == ["50-one.sh", "50-two.sh"]) and
		(.available[0].enabled_aliases == ["50-one.sh"])
	' >/dev/null
}

@test "root test task executes the complete included aggregate" {
	run bash -c "cd '${REPO_ROOT}' && task --dry test"

	[ "$status" -eq 0 ]
	[[ "$output" == *'skills.bats'* ]]
	[[ "$output" == *'integration/tools.bats'* ]]
}
