#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	POLICY="${REPO_ROOT}/.devcontainer/tool-versions.conf"
	UPDATER="${REPO_ROOT}/.taskfiles/scripts/deps-update.sh"
	INSTALLER="${REPO_ROOT}/.devcontainer/install/01-foundation/15-task.sh"
	ADR="${REPO_ROOT}/docs/en/adr/0003-unified-tool-policy-ownership.md"
}

@test "Task remains outside TOOL and LOCK policy and deps:update inventory" {
	run grep -Eq '^(TOOL_TASK_VERSION|LOCK_TASK_[A-Z0-9_]*)=' "${POLICY}"
	[ "${status}" -eq 1 ]
	run grep -Eq 'TOOL_TASK_VERSION|LOCK_TASK_' "${UPDATER}"
	[ "${status}" -eq 1 ]
}

@test "Task remains a core Cloudsmith APT bootstrap" {
	[ -f "${INSTALLER}" ]
	grep -Fq 'https://dl.cloudsmith.io/public/task/task/setup.deb.sh' "${INSTALLER}"
	grep -Fq 'apt-get install -y --no-install-recommends task' "${INSTALLER}"
	run grep -Eq 'github\.com/.*/task|TOOL_TASK_VERSION|LOCK_TASK_|sha256' "${INSTALLER}"
	[ "${status}" -eq 1 ]
}

@test "Task bootstrap has no tool-specific retry behavior" {
	run grep -Eq -- '--retry|retry[_ -]|for .*retry|while .*retry' "${INSTALLER}"
	[ "${status}" -eq 1 ]
}

@test "documentation separates signed APT package integrity from HTTPS bootstrap trust" {
	local documentation
	documentation="$(tr '\n' ' ' <"${ADR}")"
	[[ "${documentation}" == *'external APT-managed core bootstrap'* ]]
	[[ "${documentation}" == *'signed Cloudsmith APT repository selects the Task package version and authenticates package metadata and integrity'* ]]
	[[ "${documentation}" == *'setup.deb.sh'* ]]
	[[ "${documentation}" == *'APT signatures do not authenticate that bootstrap script itself'* ]]
	[[ "${documentation}" == *'transient Cloudsmith or network failures require a manual build retry'* ]]
	[[ "${documentation}" == *'no shared retry policy'* ]]
	[[ "${documentation}" == *'does not authorize new unmanaged tools'* ]]
}
