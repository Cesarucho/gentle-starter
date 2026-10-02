#!/usr/bin/env bats
load gentle-shell-fixture.bash

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	write_shell_fixture
	mkdir -p "${TEST_ROOT}/install/available" "${TEST_ROOT}/install/lib" "${TEST_ROOT}/bin" "${TEST_ROOT}/home"
	cp "${REPO_ROOT}/.devcontainer/install/available/3040-ai-gentle-shell.sh" "${TEST_ROOT}/install/available/"
	cp "${REPO_ROOT}/.devcontainer/install/lib/"gentle-shell-* "${TEST_ROOT}/install/lib/"
	cp "${REPO_ROOT}/.devcontainer/install/lib/common.sh" "${TEST_ROOT}/install/lib/"
	mkdir -p "${TEST_ROOT}/workspace/.devcontainer/install/lib" "${TEST_ROOT}/workspace/.devcontainer/config"
	cp "${REPO_ROOT}/.devcontainer/install/lib/gentle-shell-provision.mjs" "${TEST_ROOT}/workspace/.devcontainer/install/lib/"
	cp -a "${REPO_ROOT}/.devcontainer/config/gentle-shell" "${TEST_ROOT}/workspace/.devcontainer/config/"
	SEED_SCRIPT="${TEST_ROOT}/seed-functions.sh"
	# Extract only the existing copying function and activation-gated config route.
	# Never source the complete postCreate script or its ownership/runtime actions.
	python3 - "${REPO_ROOT}/.devcontainer/setup.sh" "${SEED_SCRIPT}" <<'PY'
import pathlib,sys
source=pathlib.Path(sys.argv[1]).read_text()
seed='seed_config_tree() {'+source.split('seed_config_tree() {',1)[1].split('\nrepair_user_local_parents() {',1)[0]
configs='setup_versioned_configs() {'+source.split('setup_versioned_configs() {',1)[1].split('\nsetup_pi_workspace_trust() {',1)[0]
pathlib.Path(sys.argv[2]).write_text('#!/usr/bin/env bash\nset -euo pipefail\n'+seed+configs+'''
WORKSPACE_DIR="${TEST_ROOT}/workspace"; SCRIPT_DIR="$WORKSPACE_DIR/.devcontainer"
install_script_is_enabled() { [[ "${ENABLED:-1}" = 1 && "$1" == */3040-ai-gentle-shell.sh ]]; }
setup_versioned_configs
''')
PY
	# The only privileged operation is replaced, never allowed to reach sudo.
	printf '\ndevcontainer_run_as_root() { "$@"; }\n' >>"${TEST_ROOT}/install/lib/common.sh"
	POLICY="${TEST_ROOT}/policy"
	cp "${REPO_ROOT}/.devcontainer/tool-versions.conf" "${POLICY}"
	sed -i '/^LOCK_GENTLE_SHELL_/d' "${POLICY}"
	cat >>"${POLICY}" <<EOF
LOCK_GENTLE_SHELL_VERSION="4.0.0"
LOCK_GENTLE_SHELL_INTEGRITY="${SHELL_INTEGRITY}"
LOCK_GENTLE_SHELL_GENTLE_AI_VERSION="4.0.0"
LOCK_GENTLE_SHELL_SHA256_AMD64="${SHELL_ARCHIVE_SHA}"
LOCK_GENTLE_SHELL_SHA256_ARM64="${SHELL_ARCHIVE_SHA}"
LOCK_GENTLE_SHELL_BINARY_SHA256_AMD64="${SHELL_BINARY_SHA}"
LOCK_GENTLE_SHELL_BINARY_SHA256_ARM64="${SHELL_BINARY_SHA}"
EOF
	cat >"${TEST_ROOT}/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -eu
case "$4" in
https://registry.npmjs.org/*) cp "$SHELL_PACKAGE" "$3" ;;
https://github.com/*) cp "$SHELL_ARCHIVE" "$3" ;;
*) exit 99 ;;
esac
EOF
	cat >"${TEST_ROOT}/bin/npm" <<'EOF'
#!/usr/bin/env bash
set -eu
if [[ "$*" == 'root --global' ]]; then printf '%s\n' "$TEST_ROOT/global/node_modules"; exit; fi
printf '%s\n' "$*" >>"$TEST_ROOT/npm-calls"
[[ "$*" == *--ignore-scripts* ]] || exit 99
[[ "$1 $2 $3" == 'install --global --prefix' ]] || exit 99
mkdir -p "$4/lib/node_modules/gentle-pi"
cp -a "$SHELL_SOURCE/." "$4/lib/node_modules/gentle-pi/"
[[ "$*" == *--legacy-peer-deps* && "$*" != *"@earendil-works/"* ]] || exit 99
EOF
	PI_ROOT="${TEST_ROOT}/global/node_modules/@earendil-works/pi-coding-agent"
	mkdir -p "${PI_ROOT}/dist/bundle"
	printf '%s\n' '{"name":"@earendil-works/pi-coding-agent","version":"0.99.2","bin":{"pi":"dist/bundle/cli.js"}}' >"${PI_ROOT}/package.json"
	cat >"${PI_ROOT}/dist/bundle/cli.js" <<'JS'
#!/usr/bin/env node
if (process.argv[2]==='--version') console.log(require('../../package.json').version);
else console.log('managed Pi fixture',JSON.stringify(process.argv.slice(2)),JSON.stringify(process.env));
JS
	chmod +x "${PI_ROOT}/dist/bundle/cli.js"
	ln -s "${PI_ROOT}/dist/bundle/cli.js" "${TEST_ROOT}/bin/pi"
	chmod +x "${TEST_ROOT}/bin/"*
	export TEST_ROOT HOME="${TEST_ROOT}/home" PATH="${TEST_ROOT}/bin:${PATH}"
	export DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY}"
	export GENTLE_SHELL_INSTALL_ROOT="${TEST_ROOT}/image" GENTLE_SHELL_BIN="${TEST_ROOT}/bin/gentle-shell"
	INSTALLER="${TEST_ROOT}/install/available/3040-ai-gentle-shell.sh"
}
teardown() { rm -rf "${TEST_ROOT}"; }

@test "Shell stages verified package/private bytes with readable canonical manifest and no user setup" {
	run bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	[ "$(stat -c %a "${GENTLE_SHELL_INSTALL_ROOT}/4.0.0/lib/node_modules/gentle-pi/.gentle-ai/v4.0.0/integrity.json")" = 644 ]
	[ "$(stat -c %a "${GENTLE_SHELL_INSTALL_ROOT}/4.0.0/lib/node_modules/gentle-pi/.gentle-ai/v4.0.0/gentle-ai")" = 755 ]
	[ -z "$(ls -A "${HOME}")" ]
	[ "$(wc -l <"${TEST_ROOT}/npm-calls")" -eq 1 ]
	run bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	[ "$(wc -l <"${TEST_ROOT}/npm-calls")" -eq 1 ]
	[ ! -e "${GENTLE_SHELL_INSTALL_ROOT}/4.0.0/baseline" ]
	bash "${SEED_SCRIPT}"
	run "${GENTLE_SHELL_BIN}" -- --print "argument with spaces"
	[ "$status" -eq 0 ]
	[[ "$output" == *'managed Pi fixture'*'"argument with spaces"'* ]]
	run "${GENTLE_SHELL_BIN}" -- --package-root=literal-prompt
	[ "$status" -eq 0 ]
}

@test "Shell rejects damaged bundle, env and persistent dev overrides before native CLI" {
	bash "${INSTALLER}"
	for key in GENTLE_PI_GENTLE_AI_DEV_BINARY GENTLE_SHELL_GENTLE_AI_BIN GENTLE_SHELL_GENTLE_AI_PIN GENTLE_SHELL_GENTLE_AI_INSTALLER; do
		run env "${key}=/untrusted" "${GENTLE_SHELL_BIN}" --help
		[ "$status" -ne 0 ]
		[[ "$output" == *"rejects ${key}"* ]]
	done
	run "${GENTLE_SHELL_BIN}" --package-root=/untrusted
	[ "$status" -ne 0 ]
	mkdir -p "${HOME}/.pi/gentle-ai"
	printf '{}' >"${HOME}/.pi/gentle-ai/dev-binary.json"
	run "${GENTLE_SHELL_BIN}" --help
	[ "$status" -ne 0 ]
	[[ "$output" == *'development registration'* ]]
	rm "${HOME}/.pi/gentle-ai/dev-binary.json"
	printf 'tampered' >>"${GENTLE_SHELL_INSTALL_ROOT}/4.0.0/lib/node_modules/gentle-pi/.gentle-ai/v4.0.0/gentle-ai"
	run "${GENTLE_SHELL_BIN}" --help
	[ "$status" -ne 0 ]
	run bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	[[ "$output" == *'Invalid existing'* ]]
}

@test "Shell refuses missing policy and corrupted package before npm or activation" {
	sed -i '/^LOCK_GENTLE_SHELL_BINARY_SHA256_ARM64=/d' "${POLICY}"
	run bash "${INSTALLER}" --print-version-policy
	[ "$status" -ne 0 ]
	[ ! -e "${TEST_ROOT}/npm-calls" ]
}

@test "Shell package and direct archive integrity checks fail closed" {
	run python3 "${TEST_ROOT}/install/lib/gentle-shell-archive.py" package "${SHELL_PACKAGE}" sha512-invalid "${TEST_ROOT}/extract"
	[ "$status" -ne 0 ]
	run python3 "${TEST_ROOT}/install/lib/gentle-shell-archive.py" binary "${SHELL_ARCHIVE}" "$(printf '%064d' 0)" "${TEST_ROOT}/binary"
	[ "$status" -ne 0 ]
	[ ! -e "${TEST_ROOT}/binary" ]
}

@test "Shell rejects traversal symlink and duplicate archive entries even with matching digest" {
	for mode in traversal symlink duplicate; do
		python3 - "${TEST_ROOT}/unsafe.tar.gz" "${mode}" <<'PY'
import io, sys, tarfile
archive, mode = sys.argv[1:]
with tarfile.open(archive, "w:gz") as out:
    member = tarfile.TarInfo("../escape" if mode == "traversal" else "gentle-ai")
    if mode == "symlink":
        member.type, member.linkname = tarfile.SYMTYPE, "/untrusted"
        out.addfile(member)
    else:
        member.size = 1
        out.addfile(member, io.BytesIO(b"x"))
        if mode == "duplicate":
            out.addfile(member, io.BytesIO(b"x"))
PY
		sha="$(sha256sum "${TEST_ROOT}/unsafe.tar.gz" | cut -d' ' -f1)"
		run python3 "${TEST_ROOT}/install/lib/gentle-shell-archive.py" binary "${TEST_ROOT}/unsafe.tar.gz" "${sha}" "${TEST_ROOT}/binary"
		[ "$status" -ne 0 ]
		[[ "$output" == *'unsafe archive'* ]]
		[ ! -e "${TEST_ROOT}/binary" ]
	done
}

@test "Shell supports restrictive umask and rejects old Pi before network or npm" {
	run bash -c 'umask 077; bash "$1"' _ "${INSTALLER}"
	[ "$status" -eq 0 ]
	[ "$(stat -c %a "${GENTLE_SHELL_INSTALL_ROOT}")" = 755 ]
	[ "$(stat -c %a "${GENTLE_SHELL_INSTALL_ROOT}/4.0.0/lib/node_modules/gentle-pi")" = 755 ]
	sed -i 's/0.99.2/0.98.0/' "${PI_ROOT}/package.json"
	run bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	[ "$(wc -l <"${TEST_ROOT}/npm-calls")" -eq 1 ]
}

@test "Shell staging failure preserves the previous command and removes only its own stage" {
	printf 'previous command\n' >"${GENTLE_SHELL_BIN}"
	printf '#!/usr/bin/env bash\nexit 73\n' >"${TEST_ROOT}/bin/npm"
	run bash "${INSTALLER}"
	[ "$status" -eq 73 ]
	[ "$(<"${GENTLE_SHELL_BIN}")" = 'previous command' ]
	[ ! -e "${GENTLE_SHELL_INSTALL_ROOT}/4.0.0" ]
	[ -z "$(find "${GENTLE_SHELL_INSTALL_ROOT}" -name '.stage.*' -type d)" ]
}

@test "Shell fails on package SRI mismatch before npm and runtime mode never provisions" {
	sed -i 's|^LOCK_GENTLE_SHELL_INTEGRITY=.*|LOCK_GENTLE_SHELL_INTEGRITY="sha512-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=="|' "${POLICY}"
	run bash "${INSTALLER}"
	[ "$status" -ne 0 ]
	[[ "$output" == *'archive integrity mismatch'* ]]
	[ ! -e "${TEST_ROOT}/npm-calls" ]
	run env DEVCONTAINER_PHASE=runtime bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	[ ! -e "${TEST_ROOT}/npm-calls" ]
	[ -z "$(ls -A "${HOME}")" ]
}

@test "Shell policy-only Pi update reuses immutable Shell bytes and records exact new runtime" {
	bash "${INSTALLER}"
	before="$(sha256sum "${GENTLE_SHELL_INSTALL_ROOT}/4.0.0/lib/node_modules/gentle-pi/.gentle-ai/v4.0.0/gentle-ai")"
	sed -i 's/^LOCK_PI_CODING_AGENT_VERSION=.*/LOCK_PI_CODING_AGENT_VERSION="0.99.3"/' "${POLICY}"
	sed -i 's/0.99.2/0.99.3/' "${PI_ROOT}/package.json"
	run bash "${INSTALLER}"
	[ "$status" -eq 0 ]
	[ "$(wc -l <"${TEST_ROOT}/npm-calls")" -eq 1 ]
	[ "$(sha256sum "${GENTLE_SHELL_INSTALL_ROOT}/4.0.0/lib/node_modules/gentle-pi/.gentle-ai/v4.0.0/gentle-ai")" = "${before}" ]
	run node -e 'const p=require(process.argv[1]); if(p.piVersion!=="0.99.3" || !p.piRoot.endsWith("@earendil-works/pi-coding-agent"))process.exit(1)' "${GENTLE_SHELL_INSTALL_ROOT}/4.0.0/bundle.json"
	[ "$status" -eq 0 ]
	[ ! -e "${GENTLE_SHELL_INSTALL_ROOT}/4.0.0/lib/node_modules/@earendil-works" ]
}

@test "Shell runtime never trusts ambient Pi overrides or linked homes" {
	bash "${INSTALLER}"
	for key in GENTLE_SHELL_PI GENTLE_SHELL_HOME GENTLE_SHELL_CONFIG GENTLE_PI_CONFIG_HOME; do
		run env "${key}=/untrusted" "${GENTLE_SHELL_BIN}" --help
		[ "$status" -ne 0 ]
		[[ "$output" == *"rejects ${key}"* ]]
	done
	run "${GENTLE_SHELL_BIN}" --link
	[ "$status" -ne 0 ]
	[ ! -e "${HOME}/.gentle-shell" ]
	sed -i 's/0.99.2/0.99.3/' "${PI_ROOT}/package.json"
	run "${GENTLE_SHELL_BIN}" --help
	[ "$status" -ne 0 ]
	[[ "$output" == *'managed Pi differs from policy'* ]]
}

@test "Shell postCreate provisions reviewed isolated bytes and launch keeps process HOME for Engram" {
	bash "${INSTALLER}"
	run "${GENTLE_SHELL_BIN}" -- --print fixture
	[ "$status" -ne 0 ]
	[[ "$output" == *'automatic container postCreate setup must finish'* ]]
	[ ! -e "${HOME}/.gentle-shell" ]
	bash "${SEED_SCRIPT}"
	run "${GENTLE_SHELL_BIN}" -- --print fixture
	[ "$status" -eq 0 ]
	[[ "$output" == *"\"HOME\":\"${HOME}\""* ]]
	[[ "$output" == *"\"PI_CODING_AGENT_DIR\":\"${HOME}/.gentle-shell/agent\""* ]]
	[[ "$output" == *'"ENGRAM_BIN":"/usr/local/bin/engram"'* ]]
	[[ "$output" == *'"GENTLE_PI_HISTORY_CAPTURE":"0"'* ]]
	[ -s "${HOME}/.gentle-shell/agent/extensions/engram/index.ts" ]
	[ ! -e "${HOME}/.pi" ]
	[ ! -e "${HOME}/.engram" ]
	run node -e 'const s=require(process.argv[1]);if(s.theme!=="Gentleman-Cute"||s.tuiMode!=="fullscreen") process.exit(1)' "${HOME}/.gentle-shell/agent/settings.json"
	[ "$status" -eq 0 ]
}

@test "Shell preserves preferences byte-for-byte across repeated provisioning and launch" {
	bash "${INSTALLER}"
	mkdir -p "${HOME}/.gentle-shell/agent"
	printf '{ "home": "isolated", "custom": true }\n' >"${HOME}/.gentle-shell/config.json"
	printf '{ "theme": "mine", "tuiMode": "inline", "custom": 42 }\n' >"${HOME}/.gentle-shell/agent/settings.json"
	before="$(sha256sum "${HOME}/.gentle-shell/config.json" "${HOME}/.gentle-shell/agent/settings.json")"
	for attempt in 1 2; do
		bash "${SEED_SCRIPT}"
		run "${GENTLE_SHELL_BIN}" -- --print fixture
		[ "$status" -eq 0 ]
		[ "$(sha256sum "${HOME}/.gentle-shell/config.json" "${HOME}/.gentle-shell/agent/settings.json")" = "${before}" ]
	done
}

@test "Shell malformed settings and unsafe paths fail before provisioning unrelated bytes" {
	for content in 'not-json' '[]' '{"extensions":false}'; do
		mkdir -p "${HOME}/.gentle-shell/agent"
		printf '%s' "${content}" >"${HOME}/.gentle-shell/agent/settings.json"
		run bash "${SEED_SCRIPT}"
		[ "$status" -ne 0 ]
		[ ! -e "${HOME}/.gentle-shell/config.json" ]
		[ "$(<"${HOME}/.gentle-shell/agent/settings.json")" = "${content}" ]
	done
	rm -rf "${HOME}/.gentle-shell"
	mkdir -p "${TEST_ROOT}/protected"
	ln -s "${TEST_ROOT}/protected" "${HOME}/.gentle-shell"
	run bash "${SEED_SCRIPT}"
	[ "$status" -ne 0 ]
	[ -z "$(ls -A "${TEST_ROOT}/protected")" ]
}

@test "Shell refuses altered pinned adapter and leaves preferences unchanged" {
	helper="${REPO_ROOT}/.devcontainer/install/lib/gentle-shell-provision.mjs"
	bash "${SEED_SCRIPT}"
	printf '\nmodified\n' >>"${HOME}/.gentle-shell/agent/extensions/engram/index.ts"
	before="$(sha256sum "${HOME}/.gentle-shell/agent/settings.json")"
	run node "${helper}" check "${HOME}/.gentle-shell"
	[ "$status" -ne 0 ]
	[[ "$output" == *'existing adapter differs from pinned source'* ]]
	[ "$(sha256sum "${HOME}/.gentle-shell/agent/settings.json")" = "${before}" ]
}

@test "Shell explicit adapter-only recovery preserves custom bytes and preferences" {
	bash "${SEED_SCRIPT}"
	adapter="${HOME}/.gentle-shell/agent/extensions/engram"
	printf '\nold or custom adapter fixture\n' >>"${adapter}/index.ts"
	before="$(sha256sum "${HOME}/.gentle-shell/config.json" "${HOME}/.gentle-shell/agent/settings.json")"
	custom="$(sha256sum "${adapter}/index.ts" | cut -d' ' -f1)"
	run bash "${SEED_SCRIPT}"
	[ "$status" -ne 0 ]
	[[ "$output" == *'adapter-upgrade-recovery'* ]]
	[ "$(sha256sum "${HOME}/.gentle-shell/config.json" "${HOME}/.gentle-shell/agent/settings.json")" = "${before}" ]
	# Explicit operator move outside extension discovery, never automatic overwrite.
	mkdir "${HOME}/.gentle-shell/adapter-backups"
	backup="${HOME}/.gentle-shell/adapter-backups/engram-before-0.2.0"
	[ ! -e "${backup}" ]
	mv -T "${adapter}" "${backup}"
	bash "${SEED_SCRIPT}"
	run node "${REPO_ROOT}/.devcontainer/install/lib/gentle-shell-provision.mjs" check "${HOME}/.gentle-shell"
	[ "$status" -eq 0 ]
	[ "$(sha256sum "${backup}/index.ts" | cut -d' ' -f1)" = "${custom}" ]
	[ "$(sha256sum "${HOME}/.gentle-shell/config.json" "${HOME}/.gentle-shell/agent/settings.json")" = "${before}" ]
	[ ! -e "${HOME}/.engram" ]
}

@test "Shell 0.2.0 adapter dispatch and pin checks use no server or database" {
	run node --test "${REPO_ROOT}/.devcontainer/test/unit/gentle-shell-adapter-test.mjs"
	printf '%s\n' "${output}"
	[ "$status" -eq 0 ]
}

@test "Shell setup seeding is activation-gated and never calls unrelated setup lifecycle" {
	for enabled in 0 1; do
		run env ENABLED="${enabled}" bash "${SEED_SCRIPT}"
		[ "$status" -eq 0 ]
		if [ "${enabled}" = 0 ]; then
			[ ! -e "${HOME}/.gentle-shell" ]
		else
			[ -s "${HOME}/.gentle-shell/agent/extensions/engram/index.ts" ]
		fi
	done
}

@test "Shell never migrates credentials databases or shared configuration" {
	mkdir -p "${HOME}/.pi/agent" "${HOME}/.engram"
	printf 'private fixture credentials\n' >"${HOME}/.pi/agent/auth.json"
	printf 'private fixture database\n' >"${HOME}/.engram/engram.db"
	before="$(sha256sum "${HOME}/.pi/agent/auth.json" "${HOME}/.engram/engram.db")"
	printf 'unreviewed source fixture\n' >"${TEST_ROOT}/workspace/.devcontainer/config/gentle-shell/auth.json"
	run bash "${SEED_SCRIPT}"
	[ "$status" -ne 0 ]
	[[ "$output" == *'unreviewed Shell baseline path'* ]]
	[ ! -e "${HOME}/.gentle-shell" ]
	rm "${TEST_ROOT}/workspace/.devcontainer/config/gentle-shell/auth.json"
	bash "${SEED_SCRIPT}"
	[ "$(sha256sum "${HOME}/.pi/agent/auth.json" "${HOME}/.engram/engram.db")" = "${before}" ]
	[ ! -e "${HOME}/.gentle-shell/agent/auth.json" ]
	[ ! -e "${HOME}/.gentle-shell/engram.db" ]
}

@test "Shell rejects isolated dev registrations duplicate Pi peers and stale CLI bytes" {
	bash "${INSTALLER}"
	mkdir -p "${HOME}/.gentle-shell/gentle-ai"
	printf '{}' >"${HOME}/.gentle-shell/gentle-ai/dev-binary.json"
	run "${GENTLE_SHELL_BIN}" --help
	[ "$status" -ne 0 ]
	[[ "$output" == *'development registration'* ]]
	rm "${HOME}/.gentle-shell/gentle-ai/dev-binary.json"
	mkdir -p "${GENTLE_SHELL_INSTALL_ROOT}/4.0.0/lib/node_modules/gentle-pi/node_modules/typebox"
	run "${GENTLE_SHELL_BIN}" --help
	[ "$status" -ne 0 ]
	[[ "$output" == *'duplicate managed Pi dependency'* ]]
	rmdir "${GENTLE_SHELL_INSTALL_ROOT}/4.0.0/lib/node_modules/gentle-pi/node_modules/typebox"
	printf '#!/usr/bin/env node\nconsole.log("0.98.0");\n' >"${PI_ROOT}/dist/bundle/cli.js"
	run "${GENTLE_SHELL_BIN}" --help
	[ "$status" -ne 0 ]
	[[ "$output" == *'managed Pi CLI version differs from policy'* ]]
}

@test "Shell malformed or linked launcher config and busy provisioning lock fail without overwrites" {
	mkdir -p "${HOME}/.gentle-shell"
	for content in 'not-json' '[]' '{"home":"link"}' '{"home":"/foreign"}'; do
		printf '%s' "${content}" >"${HOME}/.gentle-shell/config.json"
		run bash "${SEED_SCRIPT}"
		[ "$status" -ne 0 ]
		[ "$(<"${HOME}/.gentle-shell/config.json")" = "${content}" ]
		[ ! -e "${HOME}/.gentle-shell/agent" ]
	done
	rm "${HOME}/.gentle-shell/config.json"
	mkdir "${HOME}/.gentle-shell/.provisioning.lock"
	run bash "${SEED_SCRIPT}"
	[ "$status" -ne 0 ]
	[ -d "${HOME}/.gentle-shell/.provisioning.lock" ]
	[ ! -e "${HOME}/.gentle-shell/config.json" ]
	[ ! -e "${HOME}/.gentle-shell/agent" ]
}

@test "Shell image installation has no config dependency and launcher never provisions a home" {
	rm -rf "${TEST_ROOT}/workspace/.devcontainer/config/gentle-shell"
	bash "${INSTALLER}"
	[ ! -e "${GENTLE_SHELL_INSTALL_ROOT}/4.0.0/baseline" ]
	for flag in --version --help; do
		run "${GENTLE_SHELL_BIN}" "${flag}"
		[ "$status" -eq 0 ]
		[ ! -e "${HOME}/.gentle-shell" ]
	done
	run "${GENTLE_SHELL_BIN}" setup --dry-run
	[ "$status" -ne 0 ]
	[ ! -e "${HOME}/.gentle-shell" ]
	run "${GENTLE_SHELL_BIN}" setup
	[ "$status" -ne 0 ]
	[[ "$output" == *'automatic container postCreate setup'* ]]
	[ ! -e "${HOME}/.gentle-shell" ]
	[ ! -e "${HOME}/.engram" ]
	[ ! -e "${HOME}/.pi" ]
}
