#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	INSTALLER="${REPO_ROOT}/.devcontainer/install/available/30-ai-pi-gentle.sh"
	POLICY="${REPO_ROOT}/.devcontainer/tool-versions.conf"
	TEST_ROOT="$(mktemp -d)"
	HOME_DIR="${TEST_ROOT}/home"
	BIN_DIR="${TEST_ROOT}/bin"
	PI_LOG="${TEST_ROOT}/pi.log"
	PI_SETTINGS="${HOME_DIR}/.pi/agent/settings.json"
	mkdir -p "${HOME_DIR}/.pi/agent/npm/node_modules" "${BIN_DIR}"
	: >"${PI_LOG}"
	seed_declared_packages
	seed_declared_settings
	write_pi_stub
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

policy_value() {
	sed -nE "s/^$1=\"([^\"]+)\"$/\1/p" "${POLICY}"
}

seed_package() {
	local name="$1" version="$2" directory
	directory="${HOME_DIR}/.pi/agent/npm/node_modules/${name}"
	mkdir -p "${directory}"
	printf '{"name":"%s","version":"%s"}\n' "${name}" "${version}" >"${directory}/package.json"
}

seed_declared_packages() {
	seed_package gentle-pi "$(policy_value LOCK_GENTLE_PI_VERSION)"
	seed_package pi-subagents "$(policy_value LOCK_PI_SUBAGENTS_VERSION)"
	seed_package pi-intercom "$(policy_value LOCK_PI_INTERCOM_VERSION)"
	seed_package pi-web-access "$(policy_value LOCK_PI_WEB_ACCESS_VERSION)"
	seed_package pi-lens "$(policy_value LOCK_PI_LENS_VERSION)"
	seed_package @juicesharp/rpiv-todo "$(policy_value LOCK_RPIV_TODO_VERSION)"
	seed_package @juicesharp/rpiv-ask-user-question "$(policy_value LOCK_RPIV_ASK_USER_QUESTION_VERSION)"
	seed_package @juicesharp/rpiv-btw "$(policy_value LOCK_RPIV_BTW_VERSION)"
	seed_package gentle-engram "$(policy_value LOCK_GENTLE_ENGRAM_VERSION)"
	seed_package pi-mcp-adapter "$(policy_value LOCK_PI_MCP_ADAPTER_VERSION)"
	seed_package pi-terminal-theme "$(policy_value LOCK_PI_TERMINAL_THEME_VERSION)"
}

seed_declared_settings() {
	printf '%s\n' '{"packages":["npm:gentle-engram@0.1.12"]}' >"${PI_SETTINGS}"
}

write_pi_stub() {
	cat >"${BIN_DIR}/pi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${PI_LOG}"
source_value="${2:-}"
name_with_version="${source_value#npm:}"
name="${name_with_version%@*}"
directory="${HOME}/.pi/agent/npm/node_modules/${name}"
case "${1:-}" in
list)
  node - "${HOME}/.pi/agent/settings.json" <<'NODE'
const settings = require(process.argv[2]);
console.log("User packages:");
for (const source of settings.packages ?? []) console.log(`  ${source}`);
NODE
  ;;
remove)
  node - "${HOME}/.pi/agent/settings.json" "${source_value}" <<'NODE'
const fs = require("fs");
const path = process.argv[2];
const source = process.argv[3];
const settings = require(path);
settings.packages = (settings.packages ?? []).filter((entry) => entry !== source);
fs.writeFileSync(path, `${JSON.stringify(settings, null, 2)}\n`);
NODE
  rm -rf "${directory}"
  ;;
install)
  if node -e 'const s=require(process.argv[1]); process.exit((s.packages ?? []).some((entry) => entry.startsWith(`npm:${process.argv[2]}@`)) ? 0 : 1)' "${HOME}/.pi/agent/settings.json" "${name}"; then
    exit 0
  fi
  version="${source_value##*@}"
  mkdir -p "${directory}"
  printf '{"name":"%s","version":"%s"}\n' "${name}" "${version}" >"${directory}/package.json"
  node - "${HOME}/.pi/agent/settings.json" "${source_value}" <<'NODE'
const fs = require("fs");
const path = process.argv[2];
const settings = require(path);
settings.packages = [...(settings.packages ?? []), process.argv[3]];
fs.writeFileSync(path, `${JSON.stringify(settings, null, 2)}\n`);
NODE
  ;;
esac
EOF
	chmod +x "${BIN_DIR}/pi"
}

run_installer_twice() {
	run env HOME="${HOME_DIR}" PATH="${BIN_DIR}:${PATH}" PI_LOG="${PI_LOG}" \
		DEVCONTAINER_PHASE=runtime DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY}" \
		bash -c 'bash "$1" && bash "$1"' _ "${INSTALLER}"
}

@test "exact Pi package resolutions perform no install or update on repeated runtime setup" {
	run_installer_twice

	[ "${status}" -eq 0 ]
	[ ! -s "${PI_LOG}" ]
}

@test "wrong Pi package version is replaced once and then becomes idempotent" {
	seed_package gentle-engram 0.1.8
	printf '%s\n' '{"packages":["npm:gentle-engram@0.1.8"]}' >"${PI_SETTINGS}"
	expected="$(policy_value LOCK_GENTLE_ENGRAM_VERSION)"

	run_installer_twice

	[ "${status}" -eq 0 ]
	[ "$(grep -c '^list$' "${PI_LOG}")" -eq 1 ]
	[ "$(grep -c '^remove npm:gentle-engram@0.1.8$' "${PI_LOG}")" -eq 1 ]
	[ "$(grep -c "^install npm:gentle-engram@${expected}$" "${PI_LOG}")" -eq 1 ]
	[ "$(node -p "require('${HOME_DIR}/.pi/agent/npm/node_modules/gentle-engram/package.json').version")" = "${expected}" ]
	[ "$(node -p "require('${PI_SETTINGS}').packages.join(',')")" = "npm:gentle-engram@${expected}" ]
}
