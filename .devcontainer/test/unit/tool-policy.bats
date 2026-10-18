#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	POLICY="${REPO_ROOT}/.devcontainer/tool-versions.conf"
	UPDATER="${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	TEST_ROOT="$(mktemp -d)"
}

teardown() { rm -rf "${TEST_ROOT}"; }

@test "every editable intent has one known strategy and generated lock output" {
	run "${UPDATER}" --validate
	[ "${status}" -eq 0 ]
	[ -z "$(sed -nE 's/^((TOOL|LOCK)_[A-Z0-9_]+)=.*/\1/p' "${POLICY}" | sort | uniq -d)" ]
}

@test "offline validation does not require provider commands authentication or Archify helpers" {
	run env DEPS_UPDATE_PNPM=/absent DEPS_UPDATE_CURL=/absent DEPS_UPDATE_JQ=/absent \
		DEPS_UPDATE_GH=/absent DEPS_UPDATE_SLEEP=/absent TOOLS_UPDATE_USE_GH_AUTH=1 \
		DEPS_UPDATE_ARCHIFY_ARCHIVE_SH=/absent "${UPDATER}" --validate
	[ "$status" -eq 0 ]
}

@test "unknown tool intent fails closed" {
	cp "${POLICY}" "${TEST_ROOT}/policy"
	sed -i '/^# GENERATED LOCK/i TOOL_UNKNOWN_VERSION="latest"' "${TEST_ROOT}/policy"
	run env DEPS_UPDATE_POLICY_FILE="${TEST_ROOT}/policy" "${UPDATER}" --validate
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"unknown tool strategy"* ]]
}

@test "unsafe intent fails without changing bytes or mode" {
	cp -p "${POLICY}" "${TEST_ROOT}/policy"
	sed -i 's/^TOOL_PLANTUML_VERSION=.*/TOOL_PLANTUML_VERSION="1.2026.x"/' "${TEST_ROOT}/policy"
	cp -p "${TEST_ROOT}/policy" "${TEST_ROOT}/before"
	before_mode="$(stat -c %a "${TEST_ROOT}/policy")"
	run env DEPS_UPDATE_POLICY_FILE="${TEST_ROOT}/policy" "${UPDATER}" --validate
	[ "${status}" -ne 0 ]
	cmp -s "${TEST_ROOT}/before" "${TEST_ROOT}/policy"
	[ "$(stat -c %a "${TEST_ROOT}/policy")" = "${before_mode}" ]
}

@test "all user intent precedes one final generated lock section" {
	marker="$(grep -n '^# GENERATED LOCK' "${POLICY}" | cut -d: -f1)"
	[ "$(grep -c '^# GENERATED LOCK' "${POLICY}")" -eq 1 ]
	[ -z "$(awk -v marker="${marker}" 'NR > marker && /^TOOL_/ { print } NR < marker && /^LOCK_/ { print }' "${POLICY}")" ]
	legacy_term="SELECT"'OR'
	[ -z "$(grep -E "${legacy_term}|INSTALL_${legacy_term}" "${POLICY}")" ]
}

@test "installers consume locks rather than editable intent" {
	run grep -R -nE '\$\{TOOL_[A-Z0-9_]+_VERSION' "${REPO_ROOT}/.devcontainer/install/available"
	[ "${status}" -eq 1 ]
	[ -z "${output}" ]
	grep -q 'LOCK_EXAMPLE_VERSION' "${REPO_ROOT}/.devcontainer/install/templates/install-script.sh"
}

@test "policy-only installers ignore external version overrides" {
	printf '%s\n' 'LOCK_ENGRAM_VERSION="1.17.0"' 'LOCK_NODE_MAJOR="26"' \
		'LOCK_PLAYWRIGHT_VERSION="1.64.1"' 'LOCK_PLAYWRIGHT_CLI_VERSION="0.1.22"' >"${TEST_ROOT}/policy"
	local entry script variable expected
	for entry in '3010-ai-engram.sh|ENGRAM_VERSION|1.17.0' \
		'2000-runtime-node.sh|NODE_MAJOR|26' '2080-browser-playwright.sh|PLAYWRIGHT_VERSION|1.64.1'; do
		IFS='|' read -r script variable expected <<<"${entry}"
		run env -u PLAYWRIGHT_CLI_VERSION DEVCONTAINER_TOOL_VERSIONS_FILE="${TEST_ROOT}/policy" \
			"${variable}=9.9.9" bash "${REPO_ROOT}/.devcontainer/install/available/${script}" --print-version-policy
		[ "$status" -eq 0 ]
		if [ "${variable}" = PLAYWRIGHT_VERSION ]; then
			[ "$output" = "${variable}=${expected}"$'\n''PLAYWRIGHT_CLI_VERSION=0.1.22' ]
		else
			[ "$output" = "${variable}=${expected}" ]
		fi
	done
}

@test "policy-only installers reject missing locks despite external overrides" {
	printf '%s\n' 'LOCK_PLAYWRIGHT_CLI_VERSION="0.1.19"' >"${TEST_ROOT}/policy"
	local entry script variable lock
	for entry in '3010-ai-engram.sh|ENGRAM_VERSION|LOCK_ENGRAM_VERSION' \
		'2000-runtime-node.sh|NODE_MAJOR|LOCK_NODE_MAJOR' \
		'2080-browser-playwright.sh|PLAYWRIGHT_VERSION|LOCK_PLAYWRIGHT_VERSION'; do
		IFS='|' read -r script variable lock <<<"${entry}"
		run env DEVCONTAINER_TOOL_VERSIONS_FILE="${TEST_ROOT}/policy" \
			"${variable}=9.9.9" bash "${REPO_ROOT}/.devcontainer/install/available/${script}" --print-version-policy
		[ "$status" -ne 0 ]
		[[ "$output" == *"missing ${lock}"* ]]
	done
}

@test "only tools-update owns policy replacement" {
	run grep -R -l -E '(^|[;&|])[[:space:]]*(mv|cp|install)[[:space:]].*tool-versions\.conf' \
		"${REPO_ROOT}/.devcontainer/install" "${REPO_ROOT}/.devcontainer/setup.sh" "${REPO_ROOT}/.devcontainer/lifecycle/setup-volumes.sh"
	[ "${status}" -eq 1 ]
	grep -q 'mv "${CANDIDATE_FILE}" "${POLICY_FILE}"' "${UPDATER}"
}

@test "current tool documentation enforces updater ownership and fail-closed consumers" {
	run grep -R -nE 'Tool selectors|transitional local fallback|leaves? the tool manual|deliberately excluded policy' \
		"${REPO_ROOT}/.agents/skills/add-tool" \
		"${REPO_ROOT}/.devcontainer/docs/extending.md" \
		"${REPO_ROOT}/.devcontainer/docs/install-tree.md" \
		"${REPO_ROOT}/.devcontainer/Dockerfile"
	[ "${status}" -eq 1 ]
	[ -z "${output}" ]

	grep -q 'one safe, explicit strategy registered in' \
		"${REPO_ROOT}/.agents/skills/add-tool/references/decision-matrix.md"
	grep -q 'Unsupported providers fail until that strategy is safely' \
		"${REPO_ROOT}/.agents/skills/add-tool/references/verification.md"
	grep -q 'ADR 0003 is normative' \
		"${REPO_ROOT}/docs/en/adr/0002-centralized-tool-version-policy.md"
}
