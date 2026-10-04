#!/usr/bin/env bats

load ../helpers/npm-fixture.bash

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="${BATS_TEST_TMPDIR}/shell"
	setup_npm_fixture "${TEST_ROOT}"
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
    npm "$@"
}
npm_fixture_dispatch() {
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

run_shell_fixture() {
	run_npm_fixture "${INSTALLER}" "${NPM_FIXTURE_RUNTIME}" \
		TEST_ROOT="${TEST_ROOT}" POLICY="${POLICY}" SHELL_PACKAGE="${SHELL_PACKAGE}" "$@"
}

@test "Shell verifies local SRI and uses native global npm scripts and bin" {
	run_shell_fixture
	[ "$status" -eq 0 ]
	grep -q 'root npm install --global --ignore-scripts=false --no-audit --no-fund .*package.tgz' "${TEST_ROOT}/calls"
	local argv
	mapfile -d '' -t argv <"${NPM_FIXTURE_CALLS}/1"
	[ "${#argv[@]}" -eq 6 ]
	[ "${argv[*]:0:5}" = 'install --global --ignore-scripts=false --no-audit --no-fund' ]
	[[ "${argv[5]}" == "${TEST_ROOT}"/*/package.tgz ]]
	[ "$(readlink "${TEST_ROOT}/npm/bin/gentle-shell")" = ../lib/node_modules/gentle-pi/bin/gentle-shell.mjs ]
	[ ! -e "${HOME}/.gentle-shell" ]
	! grep -Eq 'pnpm|ignore-scripts( |$)|legacy-peer-deps|/opt/|launcher|provision' "${TEST_ROOT}/calls"
}

@test "Shell bad SRI fails before npm or native script execution" {
	printf 'tampered' >>"${SHELL_PACKAGE}"
	run_shell_fixture
	[ "$status" -ne 0 ]
	[[ "$output" == *'SRI mismatch'* ]]
	! grep -q 'root npm' "${TEST_ROOT}/calls"
}

@test "Shell missing or malformed SRI fails before download and npm" {
	for value in '' sha512-invalid; do
		printf 'LOCK_GENTLE_SHELL_VERSION="4.0.0"\nLOCK_GENTLE_SHELL_INTEGRITY="%s"\n' "${value}" >"${POLICY}"
		run_shell_fixture
		[ "$status" -ne 0 ]
		[ ! -e "${TEST_ROOT}/calls" ]
	done
}

@test "Shell root-created private bundle becomes ubuntu-readable without changing npm parents" {
	chmod 755 "${TEST_ROOT}/npm/lib/node_modules"
	run_shell_fixture
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
	run_shell_fixture RUNTIME=1
	[ "$status" -eq 0 ]
	[ ! -e "${TEST_ROOT}/calls" ]
	[ "$(<"${HOME}/.gentle-shell/preferences")" = preserved ]
}

@test "Shell failed npm and wrong installed version fail without CLI probing" {
	run_shell_fixture FAIL_NPM=1
	[ "$status" -ne 0 ]
	[ ! -e "${TEST_ROOT}/npm/bin/gentle-shell" ]
	run_shell_fixture WRONG_VERSION=9.0.0
	[ "$status" -ne 0 ]
	[[ "$output" == *'Unexpected native Shell package'* ]]
	! grep -q -- '--version' "${TEST_ROOT}/calls"
}

@test "Shell unsupported architecture fails before download" {
	run_shell_fixture BAD_ARCH=1
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
	export WORKSPACE_DIR="${REPO_ROOT}" SCRIPT_DIR="${REPO_ROOT}/.devcontainer"
	run bash -c 'source "$1"; install_script_is_enabled() { return 1; }; setup_versioned_configs' _ "${TEST_ROOT}/seed.sh"
	[ "$status" -eq 0 ]
	[ ! -e "${HOME}/.gentle-shell" ]
	run bash -c 'source "$1"; install_script_is_enabled() { [[ "$1" == */3040-ai-gentle-shell.sh ]]; }; setup_versioned_configs' _ "${TEST_ROOT}/seed.sh"
	[ "$status" -eq 0 ]
	[ ! -e "${HOME}/.gentle-shell" ]
	mkdir -p "${HOME}/.gentle-shell/agent" "${TEST_ROOT}/future-seed/agent"
	printf 'custom preferences\n' >"${HOME}/.gentle-shell/agent/settings.json"
	run bash -c 'source "$1"; install_script_is_enabled() { [[ "$1" == */3040-ai-gentle-shell.sh ]]; }; setup_versioned_configs' _ "${TEST_ROOT}/seed.sh"
	[ "$status" -eq 0 ]
	[ "$(<"${HOME}/.gentle-shell/agent/settings.json")" = 'custom preferences' ]
	printf 'synthetic replacement\n' >"${TEST_ROOT}/future-seed/agent/settings.json"
	printf 'synthetic future file\n' >"${TEST_ROOT}/future-seed/other"
	run bash -c 'source "$1"; seed_config_tree "$2" "$HOME/.gentle-shell"' _ "${TEST_ROOT}/seed.sh" "${TEST_ROOT}/future-seed"
	[ "$status" -eq 0 ]
	[ "$(<"${HOME}/.gentle-shell/agent/settings.json")" = 'custom preferences' ]
	cmp "${TEST_ROOT}/future-seed/other" "${HOME}/.gentle-shell/other"
	[ ! -e "${HOME}/.gentle-shell/agent/extensions" ]
}

@test "Shell passive bind is exact independently selected and has no runtime owner" {
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
assert "docker-compose.gentle-shell.yml" not in [path.name for path in manifest.selection(root)[1]]
assert '// , "./config/compose/docker-compose.gentle-shell.yml"' in (root / ".devcontainer/devcontainer.json").read_text()
assert '.gentle-shell' not in (root / ".devcontainer/lifecycle/setup-volumes.sh").read_text()
PY
}
