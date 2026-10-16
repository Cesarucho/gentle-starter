#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	FIXTURE="$(mktemp -d)"
	export DEPS_UPDATE_POLICY_FILE="${FIXTURE}/policy"
	cp "${REPO_ROOT}/.devcontainer/tool-versions.conf" "${DEPS_UPDATE_POLICY_FILE}"
	export DEPS_UPDATE_PNPM=/forbidden DEPS_UPDATE_CURL=/forbidden DEPS_UPDATE_GH=/forbidden
	export TOOLS_UPDATE_USE_GH_AUTH=1
	export DEPS_UPDATE_COMMON_SH="${REPO_ROOT}/.devcontainer/install/lib/common.sh"
}

teardown() {
	rm -rf "${FIXTURE}"
}

@test "retirement deletes only explicit absent-intent locks offline and repeats as a no-op" {
	cp "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/expected"
	printf 'LOCK_RETIRED_VERSION="1.2.3"\n' >>"${DEPS_UPDATE_POLICY_FILE}"
	chmod 640 "${DEPS_UPDATE_POLICY_FILE}"
	run bash "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --retire-locks LOCK_RETIRED_VERSION
	[ "$status" -eq 0 ]
	cmp "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/expected"
	[ "$(stat -c %a "${DEPS_UPDATE_POLICY_FILE}")" = 640 ]
	run bash "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --retire-locks LOCK_RETIRED_VERSION
	[ "$status" -eq 0 ]
	cmp "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/expected"
}

@test "retirement rejects malformed duplicate managed and active-intent requests unchanged" {
	printf 'TOOL_RETIRED_VERSION="latest"\n' >>"${DEPS_UPDATE_POLICY_FILE}"
	cp -p "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/before"
	for key in TOOL_RETIRED_VERSION LOCK_PI_CODING_AGENT_VERSION 'LOCK_BAD;VERSION' LOCK_RETIRED_VERSION; do
		run bash "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --retire-locks "$key"
		[ "$status" -ne 0 ]
		cmp "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/before"
	done
	run bash "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --retire-locks LOCK_UNUSED_VERSION LOCK_UNUSED_VERSION
	[ "$status" -ne 0 ]
	run bash "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --retire-locks
	[ "$status" -ne 0 ]
}

@test "retirement refuses unrelated unknown locks and noncanonical generated layout" {
	for corruption in unknown layout; do
		cp "${REPO_ROOT}/.devcontainer/tool-versions.conf" "${DEPS_UPDATE_POLICY_FILE}"
		printf 'LOCK_RETIRED_VERSION="1.2.3"\n' >>"${DEPS_UPDATE_POLICY_FILE}"
		case "$corruption" in
		unknown) printf 'LOCK_OTHER_VERSION="1.0.0"\n' >>"${DEPS_UPDATE_POLICY_FILE}" ;;
		layout) printf 'TOOL_RETIRED_VERSION="latest"\n' >>"${DEPS_UPDATE_POLICY_FILE}" ;;
		esac
		cp -p "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/before"
		run bash "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --retire-locks LOCK_RETIRED_VERSION
		[ "$status" -ne 0 ]
		cmp "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/before"
	done
}

@test "failed retirement publication preserves original bytes and cleans candidate" {
	printf 'LOCK_RETIRED_VERSION="1.2.3"\n' >>"${DEPS_UPDATE_POLICY_FILE}"
	cp -p "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/before"
	mkdir "${FIXTURE}/bin"
	printf '#!/bin/sh\nexit 1\n' >"${FIXTURE}/bin/mv"
	chmod +x "${FIXTURE}/bin/mv"
	run env PATH="${FIXTURE}/bin:${PATH}" bash "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --retire-locks LOCK_RETIRED_VERSION
	[ "$status" -ne 0 ]
	cmp "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/before"
	[ "$(stat -c %a "${DEPS_UPDATE_POLICY_FILE}")" = "$(stat -c %a "${FIXTURE}/before")" ]
	run bash -c 'compgen -G "$1/.tool-versions.conf.*"' _ "${FIXTURE}"
	[ "$status" -ne 0 ]
}

@test "Task forwards explicit retirement keys to the offline authority" {
	printf 'LOCK_RETIRED_VERSION="1.2.3"\n' >>"${DEPS_UPDATE_POLICY_FILE}"
	run task --dir "${REPO_ROOT}" tools:update -- --retire-locks LOCK_RETIRED_VERSION
	[ "$status" -eq 0 ]
	[[ "$output" == *"Retired explicit locks: LOCK_RETIRED_VERSION"* ]]
}

@test "retirement preserves survivor bytes including a missing final newline" {
	printf 'LOCK_RETIRED_VERSION="1.2.3"\n' >>"${DEPS_UPDATE_POLICY_FILE}"
	printf '# survivor without newline' >>"${DEPS_UPDATE_POLICY_FILE}"
	cp "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/before"
	run bash "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --retire-locks LOCK_RETIRED_VERSION
	[ "$status" -eq 0 ]
	run python3 - "${FIXTURE}/before" "${DEPS_UPDATE_POLICY_FILE}" <<'PY'
import sys
from pathlib import Path
before, after = (Path(path).read_bytes() for path in sys.argv[1:])
assert after == before.replace(b'LOCK_RETIRED_VERSION="1.2.3"\n', b'')
PY
	[ "$status" -eq 0 ]
}

@test "retirement rejects duplicate assignments and active intent before generated section" {
	for corruption in duplicate intent; do
		cp "${REPO_ROOT}/.devcontainer/tool-versions.conf" "${DEPS_UPDATE_POLICY_FILE}"
		printf 'LOCK_RETIRED_VERSION="1.2.3"\n' >>"${DEPS_UPDATE_POLICY_FILE}"
		case "$corruption" in
		duplicate) printf 'LOCK_RETIRED_VERSION="1.2.3"\n' >>"${DEPS_UPDATE_POLICY_FILE}" ;;
		intent) sed -i '/^# GENERATED LOCK/i TOOL_RETIRED_VERSION="latest"' "${DEPS_UPDATE_POLICY_FILE}" ;;
		esac
		cp -p "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/before"
		run bash "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --retire-locks LOCK_RETIRED_VERSION
		[ "$status" -ne 0 ]
		cmp "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/before"
	done
}

@test "retirement refuses surviving package and strategy registrations even without inventory or intent" {
	for key in LOCK_PNPM_VERSION LOCK_GRAPHIFY_VERSION; do
		cp "${REPO_ROOT}/.devcontainer/tool-versions.conf" "${DEPS_UPDATE_POLICY_FILE}"
		local intent="TOOL_${key#LOCK_}"
		sed -i "/^${intent}=/d" "${DEPS_UPDATE_POLICY_FILE}"
		python3 - "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" "${FIXTURE}/updater.sh" "$key" <<'PY'
import sys
from pathlib import Path
original, candidate, key = sys.argv[1:]
source = Path(original).read_text()
Path(candidate).write_text(source.replace(key + " ", "", 1))
PY
		cp -p "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/before"
		run bash "${FIXTURE}/updater.sh" --retire-locks "$key"
		[ "$status" -ne 0 ]
		[[ "$output" == *"registered "* ]]
		cmp "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/before"
	done
}

@test "retirement scope validation rejects candidate tampering without publishing" {
	printf 'LOCK_RETIRED_VERSION="1.2.3"\n' >>"${DEPS_UPDATE_POLICY_FILE}"
	cp -p "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/before"
	cat >"${FIXTURE}/common.sh" <<'SH'
devcontainer_load_tool_versions() {
	if [ "$1" != "${DEPS_UPDATE_POLICY_FILE}" ]; then
		printf '# unexpected survivor mutation\n' >>"$1"
	fi
}
SH
	run env DEPS_UPDATE_COMMON_SH="${FIXTURE}/common.sh" bash "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --retire-locks LOCK_RETIRED_VERSION
	[ "$status" -ne 0 ]
	cmp "${DEPS_UPDATE_POLICY_FILE}" "${FIXTURE}/before"
}
