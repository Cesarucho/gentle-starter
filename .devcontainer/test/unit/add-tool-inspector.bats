#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
}

@test "add-tool inspector reports concise normalized architecture facts" {
	local inspector="${REPO_ROOT}/.agents/skills/add-tool/scripts/inspect-install-tree.sh"

	run bash "${inspector}" "${REPO_ROOT}"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"prepare-bind-mounts.sh"* ]]
	[[ "${output}" == *"prepare-bind-mounts.py"* ]]
	[[ "${output}" == *"bind_records: .devcontainer/lifecycle/compose-volume-records.py"* ]]
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
		"${fixture_root}/.devcontainer/install/02-core-tools" \
		"${fixture_root}/.devcontainer/install/03-enabled" \
		"${fixture_root}/outside"
	touch "${fixture_root}/.devcontainer/install/available/40-valid.sh" \
		"${fixture_root}/outside/escape.sh"
	ln -s "${fixture_root}/.devcontainer/install/available/40-valid.sh" \
		"${fixture_root}/.devcontainer/install/02-core-tools/40-valid.sh"
	ln -s "${fixture_root}/outside/escape.sh" \
		"${fixture_root}/.devcontainer/install/03-enabled/50-escape.sh"
	ln -s "../available/not-an-installer" \
		"${fixture_root}/.devcontainer/install/03-enabled/60-directory.sh"

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
		"${fixture_root}/.devcontainer/install/03-enabled"
	touch "${fixture_root}/.devcontainer/install/available/40-one.sh" \
		"${fixture_root}/.devcontainer/install/available/40-two.sh"
	ln -s "../available/40-one.sh" "${fixture_root}/.devcontainer/install/03-enabled/50-one.sh"
	ln -s "../available/40-two.sh" "${fixture_root}/.devcontainer/install/03-enabled/50-two.sh"
	ln -s "../available/missing.sh" "${fixture_root}/.devcontainer/install/03-enabled/60-missing.sh"

	run bash "${inspector}" --format=json "${fixture_root}"
	rm -rf "${fixture_root}"

	[ "${status}" -eq 0 ]
	printf '%s' "${output}" | jq -e '
		(.broken_aliases == ["60-missing.sh"]) and
		(.duplicate_slots["03-enabled/50"] == ["50-one.sh", "50-two.sh"]) and
		(.available[0].enabled_aliases == ["50-one.sh"])
	' >/dev/null
}
