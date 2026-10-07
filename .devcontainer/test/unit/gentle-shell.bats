#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	mkdir -p "${TEST_ROOT}/tmp"
	export TMPDIR="${TEST_ROOT}/tmp"
	# Real synthetic bytes retain the installer's same-tarball and tampering checks.
	SHELL_PACKAGE="${TEST_ROOT}/shell.tgz"
	printf 'synthetic native npm package\n' >"${SHELL_PACKAGE}"
	SHELL_INTEGRITY="$(node -e 'const fs=require("node:fs"),crypto=require("node:crypto"); console.log("sha512-"+crypto.createHash("sha512").update(fs.readFileSync(process.argv[1])).digest("base64"))' "${SHELL_PACKAGE}")"
	mkdir -p "${TEST_ROOT}/install/available" "${TEST_ROOT}/install/lib" "${TEST_ROOT}/npm/lib/node_modules" "${TEST_ROOT}/home"
	cp "${REPO_ROOT}/.devcontainer/install/available/3040-ai-gentle-shell.sh" "${TEST_ROOT}/install/available/"
	INSTALLER="${TEST_ROOT}/install/available/3040-ai-gentle-shell.sh"
	POLICY="${TEST_ROOT}/policy"
	printf 'LOCK_GENTLE_SHELL_VERSION="4.0.0"\nLOCK_GENTLE_SHELL_INTEGRITY="%s"\n' "${SHELL_INTEGRITY}" >"${POLICY}"
	export TEST_ROOT POLICY SHELL_PACKAGE HOME="${TEST_ROOT}/home"
	cat >"${TEST_ROOT}/install/lib/common.sh" <<'SH'
devcontainer_load_tool_versions() { source "${POLICY}"; }
devcontainer_is_runtime() { [ "${RUNTIME:-0}" = 1 ]; }
devcontainer_arch() { [ "${BAD_ARCH:-0}" = 0 ]; }
devcontainer_require_cmd() { command -v "$1" >/dev/null; }
devcontainer_log_info() { printf '%s\n' "$*"; }
devcontainer_fetch() { printf 'fetch %s\n' "$1" >>"${TEST_ROOT}/calls"; cp "${SHELL_PACKAGE}" "$2"; }
devcontainer_run_as_root() {
    printf 'root %s\n' "$*" >>"${TEST_ROOT}/calls"
    if [ "$1" != npm ]; then "$@"; return; fi
    shift
    if [ "$1" = root ]; then printf '%s\n' "${TEST_ROOT}/npm/lib/node_modules"; return; fi
    [ "$1" = install ] || return 98
    [ "${FAIL_NPM:-0}" = 0 ] || return 97
    [[ "${*: -1}" = "${TEST_ROOT}"/*/package.tgz ]] || return 96
    cmp "${*: -1}" "${SHELL_PACKAGE}" || return 95
    local package="${TEST_ROOT}/npm/lib/node_modules/gentle-pi"
    mkdir -p "${package}/bin" "${package}/.gentle-ai/v4.0.0" "${TEST_ROOT}/npm/bin"
    printf '{"name":"gentle-pi","version":"%s","bin":{"gentle-shell":"bin/gentle-shell.mjs"}}\n' "${WRONG_VERSION:-4.0.0}" >"${package}/package.json"
    printf 'native bin fixture\n' >"${package}/bin/gentle-shell.mjs"
    printf 'synthetic executable\n' >"${package}/.gentle-ai/v4.0.0/gentle-ai"
    printf '{}\n' >"${package}/.gentle-ai/v4.0.0/integrity.json"
    chmod 700 "${package}/.gentle-ai" "${package}/.gentle-ai/v4.0.0" "${package}/.gentle-ai/v4.0.0/gentle-ai"
    chmod 600 "${package}/.gentle-ai/v4.0.0/integrity.json"
    ln -s ../lib/node_modules/gentle-pi/bin/gentle-shell.mjs "${TEST_ROOT}/npm/bin/gentle-shell"
}
SH
}

teardown() { rm -rf -- "${TEST_ROOT}"; }

@test "Shell verifies local SRI and uses native global npm scripts and bin" {
	run bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	grep -q 'root npm install --global --ignore-scripts=false --no-audit --no-fund .*package.tgz' "${TEST_ROOT}/calls"
	[ "$(readlink "${TEST_ROOT}/npm/bin/gentle-shell")" = ../lib/node_modules/gentle-pi/bin/gentle-shell.mjs ]
	[ ! -e "${HOME}/.gentle-shell" ]
	! grep -Eq 'pnpm|ignore-scripts( |$)|legacy-peer-deps|/opt/|launcher|provision' "${TEST_ROOT}/calls"
}

@test "Shell bad SRI fails before npm or native script execution" {
	printf 'tampered' >>"${SHELL_PACKAGE}"
	run bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	[[ "$output" == *'SRI mismatch'* ]]
	! grep -q 'root npm' "${TEST_ROOT}/calls"
}

@test "Shell missing or malformed SRI fails before download and npm" {
	for value in '' sha512-invalid; do
		printf 'LOCK_GENTLE_SHELL_VERSION="4.0.0"\nLOCK_GENTLE_SHELL_INTEGRITY="%s"\n' "${value}" >"${POLICY}"
		run bash "${INSTALLER}"
		[ "$status" -ne 0 ]
		[ ! -e "${TEST_ROOT}/calls" ]
	done
}

@test "Shell root-created private bundle becomes ubuntu-readable without changing npm parents" {
	chmod 755 "${TEST_ROOT}/npm/lib/node_modules"
	run bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	local bundle="${TEST_ROOT}/npm/lib/node_modules/gentle-pi/.gentle-ai/v4.0.0"
	[ "$(stat -c %a "${bundle}")" = 755 ]
	[ "$(stat -c %a "${bundle}/gentle-ai")" = 755 ]
	[ "$(stat -c %a "${bundle}/integrity.json")" = 644 ]
	[ "$(stat -c %a "${TEST_ROOT}/npm/lib/node_modules")" = 755 ]
	! grep -q chown "${TEST_ROOT}/calls"
}

@test "Shell runtime passive mount does not trigger npm or state mutation" {
	mkdir "${HOME}/.gentle-shell"
	printf 'preserved\n' >"${HOME}/.gentle-shell/preferences"
	run env RUNTIME=1 bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	[ ! -e "${TEST_ROOT}/calls" ]
	[ "$(<"${HOME}/.gentle-shell/preferences")" = preserved ]
}

@test "Shell failed npm and wrong installed version fail without CLI probing" {
	run env FAIL_NPM=1 bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	[ ! -e "${TEST_ROOT}/npm/bin/gentle-shell" ]
	run env WRONG_VERSION=9.0.0 bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	[[ "$output" == *'Unexpected native Shell package'* ]]
	! grep -q -- '--version' "${TEST_ROOT}/calls"
}

@test "Shell unsupported architecture fails before download" {
	run env BAD_ARCH=1 bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	[ ! -e "${TEST_ROOT}/calls" ]
}

@test "Shell absent baseline is a no-op and future seeding preserves preferences" {
	python3 - "${REPO_ROOT}/.devcontainer/setup.sh" "${TEST_ROOT}/seed.sh" <<'PY'
import re, sys
from pathlib import Path
source = Path(sys.argv[1]).read_text()
functions = [re.search(r'^' + name + r'\(\) \{.*?^\}', source, re.M | re.S).group()
             for name in ('seed_config_tree', 'setup_versioned_configs')]
Path(sys.argv[2]).write_text('\n'.join(functions))
PY
	# An absent baseline must be synthetic: the producer now ships Shell config.
	export WORKSPACE_DIR="${TEST_ROOT}/workspace" SCRIPT_DIR="${TEST_ROOT}/workspace/.devcontainer"
	mkdir -p "${SCRIPT_DIR}/config"
	run bash -c 'source "$1"; install_script_is_enabled() { return 1; }; setup_versioned_configs' _ "${TEST_ROOT}/seed.sh"
	[ "$status" -eq 0 ]
	[ ! -e "${HOME}/.gentle-shell" ]
	run bash -c 'source "$1"; install_script_is_enabled() { [[ "$1" == */3040-ai-gentle-shell.sh ]]; }; setup_versioned_configs' _ "${TEST_ROOT}/seed.sh"
	[ "$status" -eq 0 ]
	[ ! -e "${HOME}/.gentle-shell" ]
	mkdir -p "${HOME}/.gentle-shell/agent" "${SCRIPT_DIR}/config/gentle-shell/agent"
	printf 'custom preferences\n' >"${HOME}/.gentle-shell/agent/settings.json"
	run bash -c 'source "$1"; install_script_is_enabled() { [[ "$1" == */3040-ai-gentle-shell.sh ]]; }; setup_versioned_configs' _ "${TEST_ROOT}/seed.sh"
	[ "$status" -eq 0 ]
	[ "$(<"${HOME}/.gentle-shell/agent/settings.json")" = 'custom preferences' ]
	printf 'synthetic replacement\n' >"${SCRIPT_DIR}/config/gentle-shell/agent/settings.json"
	printf 'synthetic future file\n' >"${SCRIPT_DIR}/config/gentle-shell/other"
	run bash -c 'source "$1"; install_script_is_enabled() { return 1; }; setup_versioned_configs' _ "${TEST_ROOT}/seed.sh"
	[ "$status" -eq 0 ]
	[ ! -e "${HOME}/.gentle-shell/other" ]
	[ "$(<"${HOME}/.gentle-shell/agent/settings.json")" = 'custom preferences' ]
	run bash -c 'source "$1"; install_script_is_enabled() { [[ "$1" == */3040-ai-gentle-shell.sh ]]; }; setup_versioned_configs' _ "${TEST_ROOT}/seed.sh"
	[ "$status" -eq 0 ]
	[ "$(<"${HOME}/.gentle-shell/agent/settings.json")" = 'custom preferences' ]
	cmp "${SCRIPT_DIR}/config/gentle-shell/other" "${HOME}/.gentle-shell/other"
	[ ! -e "${HOME}/.gentle-shell/agent/extensions" ]
}

@test "Shell passive bind is exact selected by the producer and has no runtime owner" {
	python3 - "${REPO_ROOT}" <<'PY'
import importlib.util, sys
from pathlib import Path
root = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("manifest", root / ".taskfiles/scripts/compose-manifest.py")
manifest = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manifest)
fragment = manifest.read_compose_fragment(root / ".devcontainer/config/compose/docker-compose.gentle-shell.yml")
assert fragment == {"services": {"container-svc": {"volumes": [{"type": "bind",
    "source": "../.env.d/.gentle-shell", "target": "/home/ubuntu/.gentle-shell",
    "bind": {"create_host_path": False}}]}}}
assert "docker-compose.gentle-shell.yml" in [path.name for path in manifest.selection(root)[1]]
assert '.gentle-shell' not in (root / ".devcontainer/lifecycle/setup-volumes.sh").read_text()
PY
	run bash -c 'source "$1"; devcontainer_install_is_active "$2" "$2/available/3040-ai-gentle-shell.sh"' _ \
		"${REPO_ROOT}/.devcontainer/install/lib/activation.sh" "${REPO_ROOT}/.devcontainer/install"
	[ "$status" -eq 0 ]
}
