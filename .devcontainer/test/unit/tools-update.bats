#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	POLICY_FILE="${TEST_ROOT}/tool-versions.conf"
	BIN_DIR="${TEST_ROOT}/bin"
	CALLS_FILE="${TEST_ROOT}/calls"
	GITHUB_API_CACHE_DIR="${TEST_ROOT}/github-api-cache"
	mkdir -p "${BIN_DIR}"
	cp "${REPO_ROOT}/.devcontainer/tool-versions.conf" "${POLICY_FILE}"
	sed -i -E '/^TOOL_(JAVA|NODE|PHP|KUBECTL|PLANTUML)_VERSION=/! s/^(TOOL_[A-Z0-9_]+_VERSION)=.*/\1="latest"/' "${POLICY_FILE}"
	sed -i \
		-e 's/^TOOL_KUBECTL_VERSION=.*/TOOL_KUBECTL_VERSION="1.36.4"/' \
		-e 's/^TOOL_PLANTUML_VERSION=.*/TOOL_PLANTUML_VERSION="1.2026.8"/' \
		-e 's/^TOOL_GENTLE_SHELL_VERSION=.*/TOOL_GENTLE_SHELL_VERSION="=4.0.0"/' \
		"${POLICY_FILE}"
	: >"${CALLS_FILE}"
	export REPO_ROOT TEST_ROOT POLICY_FILE BIN_DIR CALLS_FILE GITHUB_API_CACHE_DIR
	export PATH="${BIN_DIR}:${PATH}"
	export DEPS_UPDATE_POLICY_FILE="${POLICY_FILE}"
	export DEPS_UPDATE_PNPM="${BIN_DIR}/pnpm"
	export DEPS_UPDATE_CURL="${BIN_DIR}/curl"
	export DEPS_UPDATE_SLEEP="${BIN_DIR}/sleep"
	export DEPS_UPDATE_GH="${BIN_DIR}/gh"
	export DEPS_UPDATE_GITHUB_API_CACHE_DIR="${GITHUB_API_CACHE_DIR}"
	export DEPS_UPDATE_COMMON_SH="${REPO_ROOT}/.devcontainer/install/lib/common.sh"
	unset GH_TOKEN
	unset TOOLS_UPDATE_USE_GH_AUTH
	unset TOOLS_UPDATE_SHOW_LOCKS
	GENTLE_FIXTURE_VERSION="1.2.3"
	GENTLE_FIXTURE_NEW_VERSION="1.2.4"
	GENTLE_FIXTURE_SHA256_AMD64="$(printf 'a%.0s' {1..64})"
	GENTLE_FIXTURE_SHA256_ARM64="$(printf 'b%.0s' {1..64})"
	GENTLE_FIXTURE_NEW_SHA256_AMD64="$(printf 'c%.0s' {1..64})"
	GENTLE_FIXTURE_NEW_SHA256_ARM64="$(printf 'd%.0s' {1..64})"
	GGA_FIXTURE_COMMIT="1124c3672f082c56b033c4e23a30e95d0e8cd593"
	GGA_FIXTURE_SHA256="$(printf 'gga archive bytes' | sha256sum | awk '{print $1}')"
	ARCHIFY_FIXTURE_VERSION="9.8.7"
	ARCHIFY_ARCHIVE_FILE="${TEST_ROOT}/archify.zip"
	write_archify_archive "${ARCHIFY_FIXTURE_VERSION}" normal
	SHELL_INTEGRITY="sha512-$(printf 'A%.0s' {1..86})=="
	ARCHIFY_FIXTURE_SHA256="$(sha256sum "${ARCHIFY_ARCHIVE_FILE}" | awk '{print $1}')"
	write_archify_archive 9.9.9 normal
	cp "${ARCHIFY_ARCHIVE_FILE}" "${ARCHIFY_ARCHIVE_FILE}.wrong-version"
	ARCHIFY_WRONG_VERSION_SHA256="$(sha256sum "${ARCHIFY_ARCHIVE_FILE}.wrong-version" | awk '{print $1}')"
	write_archify_archive "${ARCHIFY_FIXTURE_VERSION}" malformed
	cp "${ARCHIFY_ARCHIVE_FILE}" "${ARCHIFY_ARCHIVE_FILE}.bad-layout"
	ARCHIFY_BAD_LAYOUT_SHA256="$(sha256sum "${ARCHIFY_ARCHIVE_FILE}.bad-layout" | awk '{print $1}')"
	write_archify_archive "${ARCHIFY_FIXTURE_VERSION}" normal
	write_pnpm_stub stable
	write_curl_stub success
	write_sleep_stub
	write_forbidden_stub gh
	write_forbidden_stub npm
	write_forbidden_stub pi
}

write_openspec_metadata() {
	cat >"${BIN_DIR}/curl" <<EOF
#!/usr/bin/env bash
printf 'curl %s\n' "\$*" >>"${CALLS_FILE}"
printf '%s\n' '$1'
EOF
	chmod +x "${BIN_DIR}/curl"
}

@test "summary defaults to TOOL changes with hidden LOCK count and identical policy for all visibility modes" {
	sed -i -e 's/^TOOL_VITEST_VERSION=.*/TOOL_VITEST_VERSION="9.9.8"/' \
		-e 's/^LOCK_VITEST_VERSION=.*/LOCK_VITEST_VERSION="9.9.8"/' "${POLICY_FILE}"
	chmod 0640 "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/original"
	local visibility
	for visibility in unset '' 0 1; do
		cp -p "${TEST_ROOT}/original" "${POLICY_FILE}"
		if [ "${visibility}" = unset ]; then
			unset TOOLS_UPDATE_SHOW_LOCKS
		else
			export TOOLS_UPDATE_SHOW_LOCKS="${visibility}"
		fi
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only vitest
		[ "$status" -eq 0 ]
		[[ "$output" == *$'\nTOOL_*\n  TOOL_VITEST_VERSION: 9.9.8 -> 9.9.9'* ]]
		if [ "${visibility}" = 1 ]; then
			[[ "$output" == *$'\nLOCK_*\n  LOCK_VITEST_VERSION: 9.9.8 -> 9.9.9'* ]]
			[[ "$output" != *'changes hidden'* ]]
		else
			[[ "$output" != *'LOCK_VITEST_VERSION:'* ]]
			[[ "$output" != *$'\nLOCK_*\n'* ]]
			[[ "$output" == *'Generated lock changes hidden: 1. Set TOOLS_UPDATE_SHOW_LOCKS=1 to show.'* ]]
		fi
		[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
		if [ "${visibility}" = unset ]; then
			cp "${POLICY_FILE}" "${TEST_ROOT}/expected"
		else
			cmp "${TEST_ROOT}/expected" "${POLICY_FILE}"
		fi
	done
}

@test "summary displays TOOL before LOCK and preserves the existing order within each group" {
	sed -i -e 's/^TOOL_VITEST_VERSION=.*/TOOL_VITEST_VERSION="9.9.8"/' \
		-e 's/^LOCK_VITEST_VERSION=.*/LOCK_VITEST_VERSION="9.9.8"/' \
		-e 's/^TOOL_PLAYWRIGHT_VERSION=.*/TOOL_PLAYWRIGHT_VERSION="9.9.8"/' \
		-e 's/^LOCK_PLAYWRIGHT_VERSION=.*/LOCK_PLAYWRIGHT_VERSION="9.9.8"/' \
		-e 's/^TOOL_PLAYWRIGHT_CLI_VERSION=.*/TOOL_PLAYWRIGHT_CLI_VERSION="9.9.8"/' \
		-e 's/^LOCK_PLAYWRIGHT_CLI_VERSION=.*/LOCK_PLAYWRIGHT_CLI_VERSION="9.9.8"/' "${POLICY_FILE}"
	run env TOOLS_UPDATE_SHOW_LOCKS=1 "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only vitest,playwright
	[ "$status" -eq 0 ]
	local expected=$'\nTOOL_*\n  TOOL_PLAYWRIGHT_CLI_VERSION: 9.9.8 -> 9.9.9\n  TOOL_VITEST_VERSION: 9.9.8 -> 9.9.9\n  TOOL_PLAYWRIGHT_VERSION: 9.9.8 -> 9.9.9\n\nLOCK_*\n  LOCK_PLAYWRIGHT_CLI_VERSION: 9.9.8 -> 9.9.9\n  LOCK_VITEST_VERSION: 9.9.8 -> 9.9.9\n  LOCK_PLAYWRIGHT_VERSION: 9.9.8 -> 9.9.9'
	[[ "$output" == *"${expected}" ]]
}

@test "summary distinguishes lock-only updates from an unchanged policy" {
	sed -i -e 's/^TOOL_VITEST_VERSION=.*/TOOL_VITEST_VERSION="latest"/' \
		-e 's/^LOCK_VITEST_VERSION=.*/LOCK_VITEST_VERSION="9.9.8"/' "${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only vitest
	[ "$status" -eq 0 ]
	[[ "$output" == *$'\nTOOL_*\n  No TOOL_* changes.'* ]]
	[[ "$output" == *'Generated lock changes hidden: 1.'* ]]
	[[ "$output" != *$'\n  No changes.'* ]]
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/expected"
	run env TOOLS_UPDATE_SHOW_LOCKS=1 "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only vitest
	[ "$status" -eq 0 ]
	[[ "$output" == *$'\nVersion policy updates:\n  No changes.' ]]
	[[ "$output" != *$'\nTOOL_*\n'* ]]
	[[ "$output" != *$'\nLOCK_*\n'* ]]
	cmp "${TEST_ROOT}/expected" "${POLICY_FILE}"
}

@test "summary rejects invalid visibility before providers authentication or temporary files" {
	local visibility
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/expected"
	export TOOLS_UPDATE_USE_GH_AUTH=1
	write_forbidden_stub mktemp
	for visibility in true false 2 yes ' 1' '1 '; do
		run env TOOLS_UPDATE_SHOW_LOCKS="${visibility}" "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
		[ "$status" -eq 1 ]
		[ "$output" = 'tools:update: TOOLS_UPDATE_SHOW_LOCKS must be unset, empty, 0, or 1' ]
		[ ! -s "${CALLS_FILE}" ]
		cmp "${TEST_ROOT}/expected" "${POLICY_FILE}"
	done
}

@test "summary is not announced when atomic publication fails" {
	cat >"${BIN_DIR}/mv" <<'SH'
#!/usr/bin/env bash
[ "${2:-}" != "$DEPS_UPDATE_POLICY_FILE" ] || exit 71
exec /usr/bin/mv "$@"
SH
	chmod +x "${BIN_DIR}/mv"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/expected"
	run env TOOLS_UPDATE_SHOW_LOCKS=1 "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only vitest
	[ "$status" -ne 0 ]
	[[ "$output" != *'Version policy updates:'* ]]
	[[ "$output" != *'TOOL_VITEST_VERSION:'* ]]
	[[ "$output" != *'LOCK_VITEST_VERSION:'* ]]
	cmp "${TEST_ROOT}/expected" "${POLICY_FILE}"
}

@test "only mixed selection preserves unrelated bytes mode and provider order" {
	sed -i 's/^TOOL_VITEST_VERSION=.*/TOOL_VITEST_VERSION="9.9.8"/' "${POLICY_FILE}"
	chmod 0640 "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only engram,vitest
	[ "$status" -eq 0 ]
	grep -q '^TOOL_VITEST_VERSION="9.9.9"$' "${POLICY_FILE}"
	grep -q '^LOCK_ENGRAM_VERSION="1.99.0"$' "${POLICY_FILE}"
	grep -q '^LOCK_ENGRAM_SHA256_AMD64="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"$' "${POLICY_FILE}"
	grep -q '^LOCK_ENGRAM_SHA256_ARM64="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"$' "${POLICY_FILE}"
	local pattern='^(TOOL_VITEST_VERSION|LOCK_VITEST_VERSION|LOCK_ENGRAM_.*)='
	grep -Ev "${pattern}" "${TEST_ROOT}/before" >"${TEST_ROOT}/unrelated-before"
	grep -Ev "${pattern}" "${POLICY_FILE}" >"${TEST_ROOT}/unrelated-after"
	cmp "${TEST_ROOT}/unrelated-before" "${TEST_ROOT}/unrelated-after"
	[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
	[ "$(sed -n '1p' "${CALLS_FILE}")" = 'pnpm view vitest versions --json' ]
	[ "$(grep -c '^curl ' "${CALLS_FILE}")" -eq 2 ]
	! grep -Eq 'gh |archify|anomalyco|gentle-ai|go.dev|pypi|packagist' "${CALLS_FILE}"
}

@test "OpenCode standalone discovery couples both digests without GitHub or npm installation" {
	export TOOLS_UPDATE_USE_GH_AUTH=invalid DEPS_UPDATE_SLEEP=/absent DEPS_UPDATE_GH=/absent
	sed -i 's/^TOOL_OPENCODE_VERSION=.*/TOOL_OPENCODE_VERSION="2.0.0"/' "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only opencode
	[ "$status" -eq 0 ]
	grep -q '^TOOL_OPENCODE_VERSION="2.0.29"$' "${POLICY_FILE}"
	grep -q '^LOCK_OPENCODE_VERSION="2.0.29"$' "${POLICY_FILE}"
	grep -q '^LOCK_OPENCODE_SHA256_AMD64="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"$' "${POLICY_FILE}"
	grep -q '^LOCK_OPENCODE_SHA256_ARM64="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"$' "${POLICY_FILE}"
	diff <(grep -Ev '^(TOOL|LOCK)_OPENCODE_' "${TEST_ROOT}/before") <(grep -Ev '^(TOOL|LOCK)_OPENCODE_' "${POLICY_FILE}")
	[ "$(cat "${CALLS_FILE}")" = 'curl -fsSL https://opencode.ai/update/api/latest/cli/opencode' ]
}

@test "OpenCode standalone discovery honors matching intents and refuses unavailable historical pins atomically" {
	local intent
	for intent in latest 2 2.0 =2.0.29; do
		sed -i "s/^TOOL_OPENCODE_VERSION=.*/TOOL_OPENCODE_VERSION=\"${intent}\"/" "${POLICY_FILE}"
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only opencode
		[ "$status" -eq 0 ]
		grep -q "^TOOL_OPENCODE_VERSION=\"${intent}\"$" "${POLICY_FILE}"
	done
	for intent in =2.0.28 2.1 3; do
		sed -i "s/^TOOL_OPENCODE_VERSION=.*/TOOL_OPENCODE_VERSION=\"${intent}\"/" "${POLICY_FILE}"
		chmod 0640 "${POLICY_FILE}"
		cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only opencode
		[ "$status" -ne 0 ]
		[[ "$output" == *'OpenCode standalone latest does not match intent'* ]]
		cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
		[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
	done
}

@test "OpenCode standalone metadata failures preserve policy bytes and mode" {
	local mode
	chmod 0640 "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	for mode in opencode_inactive opencode_identity opencode_missing opencode_digest opencode_url opencode_prerelease; do
		write_curl_stub "${mode}"
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only opencode
		[ "$status" -ne 0 ]
		[[ "$output" == *'OpenCode'* ]]
		cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
		[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
	done
}

@test "only local selection needs no network authentication or unrelated prerequisites" {
	export DEPS_UPDATE_PNPM=/absent DEPS_UPDATE_CURL=/absent DEPS_UPDATE_JQ=/absent
	export DEPS_UPDATE_SLEEP=/absent DEPS_UPDATE_GH=/absent TOOLS_UPDATE_USE_GH_AUTH=1
	export DEPS_UPDATE_ARCHIFY_ARCHIVE_SH=/absent
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only php,node,java
	[ "$status" -eq 0 ]
	[ ! -s "${CALLS_FILE}" ]
}

@test "only npm selection skips GitHub auth Archify and unrelated calls" {
	export DEPS_UPDATE_ARCHIFY_ARCHIVE_SH=/absent DEPS_UPDATE_GH=/absent
	export TOOLS_UPDATE_USE_GH_AUTH=1 DEPS_UPDATE_SLEEP=/absent DEPS_UPDATE_CURL=/absent
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only openspec,skills
	[ "$status" -eq 0 ]
	[ "$(cat "${CALLS_FILE}")" = $'pnpm view skills versions --json\npnpm view @fission-ai/openspec versions --json' ]
}

@test "only strict parsing rejects malformed lists and mode combinations before side effects" {
	local list
	export TOOLS_UPDATE_USE_GH_AUTH=1
	write_forbidden_stub mktemp
	for list in '' ',node' 'node,' 'node,,go' 'Node' 'node, go' 'node,node' 'all' 'playwright-cli' 'gentle-pi' 'TOOL_NODE_VERSION' '2000-runtime-node' 'node;go' unknown; do
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only "${list}"
		[ "$status" -ne 0 ]
		[[ "$output" == *'--only'* ]]
		[ ! -s "${CALLS_FILE}" ]
	done
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only
	[ "$status" -ne 0 ]
	local mode
	for mode in --only --validate --retire-locks --update-engram --update-pi --update-openspec extra; do
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only node "${mode}"
		[ "$status" -ne 0 ]
		[ ! -s "${CALLS_FILE}" ]
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" "${mode}" --only node
		[ "$status" -ne 0 ]
		[ ! -s "${CALLS_FILE}" ]
	done
}

@test "only playwright resolves both independently constrained component locks" {
	sed -i -e 's/^TOOL_PLAYWRIGHT_VERSION=.*/TOOL_PLAYWRIGHT_VERSION="9.9.8"/' \
		-e 's/^TOOL_PLAYWRIGHT_CLI_VERSION=.*/TOOL_PLAYWRIGHT_CLI_VERSION="9"/' "${POLICY_FILE}"
	run task --dir "${REPO_ROOT}" tools:update -- --only playwright
	[ "$status" -eq 0 ]
	grep -q '^LOCK_PLAYWRIGHT_VERSION="9.9.9"$' "${POLICY_FILE}"
	grep -q '^LOCK_PLAYWRIGHT_CLI_VERSION="9.9.9"$' "${POLICY_FILE}"
	grep -q '^TOOL_PLAYWRIGHT_VERSION="9.9.9"$' "${POLICY_FILE}"
	grep -q '^TOOL_PLAYWRIGHT_CLI_VERSION="9"$' "${POLICY_FILE}"
	[ "$(cat "${CALLS_FILE}")" = $'pnpm view playwright versions --json\npnpm view @playwright/cli versions --json' ]
}

@test "only selected later-provider and publication failures remain atomic" {
	chmod 0640 "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	write_curl_stub engram_bad_digest
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only vitest,engram
	[ "$status" -ne 0 ]
	[[ "$output" == *'has no valid SHA-256'* ]]
	grep -q '^pnpm view vitest ' "${CALLS_FILE}"
	cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
	write_curl_stub success
	# Fail only the final atomic replacement, not the staging assignments.
	cat >"${BIN_DIR}/mv" <<'SH'
#!/usr/bin/env bash
[ "${2:-}" != "$DEPS_UPDATE_POLICY_FILE" ] || exit 71
exec /usr/bin/mv "$@"
SH
	chmod +x "${BIN_DIR}/mv"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only vitest
	[ "$status" -ne 0 ]
	cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
	[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
	[ -z "$(find "${TEST_ROOT}" -maxdepth 1 -name '.tool-versions.conf.*')" ]
}

@test "only refuses missing unselected initial locks before discovery" {
	sed -i '/^LOCK_OPENSPEC_VERSION=/d' "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only node
	[ "$status" -ne 0 ]
	[[ "$output" == *'LOCK_OPENSPEC_VERSION is absent'* ]]
	cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
	[ ! -s "${CALLS_FILE}" ]
}

@test "only bootstraps registered selected outputs without repairing unselected locks" {
	sed -i '/^LOCK_CODEGRAPH_VERSION=/d; /^LOCK_GENTLE_SHELL_/d' "${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only gentle-shell,codegraph
	[ "$status" -eq 0 ]
	[ "$(grep -c '^LOCK_CODEGRAPH_VERSION="10.0.0"$' "${POLICY_FILE}")" -eq 1 ]
	[ "$(grep -c '^LOCK_GENTLE_SHELL_' "${POLICY_FILE}")" -eq 2 ]
}

@test "only every canonical identity publishes the complete full-update output set independently" {
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/original"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "$status" -eq 0 ]
	cp "${POLICY_FILE}" "${TEST_ROOT}/full"
	local name
	for name in java node go pnpm bats engram opencode gentle-ai pi-coding-agent gentle-shell skills codegraph openspec gga c4-plantuml markdownlint-cli2 mermaid-cli archify graphify playwright devcontainer-cli vitest php phpunit terraform gitleaks pulumi opentofu terragrunt kubectl plantuml delve spectral redocly asyncapi; do
		cp -p "${TEST_ROOT}/original" "${POLICY_FILE}"
		: >"${CALLS_FILE}"
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only "${name}"
		[ "$status" -eq 0 ]
		run python3 - "${TEST_ROOT}/original" "${TEST_ROOT}/full" "${POLICY_FILE}" "${name}" "${CALLS_FILE}" <<'PY'
import re, sys
from pathlib import Path
before, full, after = (Path(p).read_bytes() for p in sys.argv[1:4])
identity = sys.argv[4].upper().replace('-', '_').encode()
prefixes = (b'TOOL_' + identity + b'_', b'LOCK_' + identity + b'_')
def owned(data):
    return b''.join(line for line in data.splitlines(keepends=True) if line.startswith(prefixes))
def unrelated(data):
    return b''.join(line for line in data.splitlines(keepends=True) if not line.startswith(prefixes))
assert owned(after) == owned(full), sys.argv[4] + ': incomplete coupled outputs'
assert unrelated(after) == unrelated(before), sys.argv[4] + ': unrelated mutation'
assert re.search(rb'^LOCK_' + identity + rb'_', after, re.M)
packages = {
    'pnpm': 'pnpm', 'pi-coding-agent': '@earendil-works/pi-coding-agent',
    'skills': 'skills', 'codegraph': '@colbymchenry/codegraph',
    'openspec': '@fission-ai/openspec', 'markdownlint-cli2': 'markdownlint-cli2',
    'mermaid-cli': '@mermaid-js/mermaid-cli', 'playwright': 'playwright',
    'devcontainer-cli': '@devcontainers/cli', 'vitest': 'vitest',
    'spectral': '@stoplight/spectral-cli', 'redocly': '@redocly/cli',
    'asyncapi': '@asyncapi/cli',
}
urls = {
    'java': (), 'node': (), 'php': (), 'go': ('https://go.dev/dl/',),
    'bats': ('/bats-core/bats-core/',), 'engram': ('/Gentleman-Programming/engram/',),
    'opencode': ('https://opencode.ai/update/api/latest/cli/opencode',), 'gentle-ai': ('/Gentleman-Programming/gentle-ai/',),
    'gentle-shell': ('https://registry.npmjs.org/gentle-pi/',),
    'gga': ('/Gentleman-Programming/gentleman-guardian-angel/',),
    'c4-plantuml': ('/plantuml-stdlib/C4-PlantUML/',), 'archify': ('/tt-a1i/archify/',),
    'graphify': ('https://pypi.org/pypi/graphifyy/json',),
    'phpunit': ('https://repo.packagist.org/p2/phpunit/phpunit.json',),
    'terraform': ('https://releases.hashicorp.com/terraform/index.json',),
    'gitleaks': ('/gitleaks/gitleaks/',), 'pulumi': ('/pulumi/pulumi/',),
    'opentofu': ('/opentofu/opentofu/',), 'terragrunt': ('/gruntwork-io/terragrunt/',),
    'kubectl': ('https://dl.k8s.io/release/stable-',),
    'plantuml': ('/plantuml/plantuml/', '/maven2/net/sourceforge/plantuml/plantuml/'),
    'delve': ('/go-delve/delve/',),
}
name = sys.argv[4]
expected_npm = [f'pnpm view {packages[name]} versions --json'] if name in packages else []
if name == 'playwright': expected_npm.append('pnpm view @playwright/cli versions --json')
calls = Path(sys.argv[5]).read_text().splitlines()
assert [c for c in calls if c.startswith('pnpm ')] == expected_npm
for call in calls:
    if call.startswith('curl '):
        assert any(part in call.split()[-1] for part in urls.get(name, ())), name + ': unrelated ' + call
    assert not call.startswith(('gh ', 'npm ', 'pi ', 'sleep ')), name + ': unrelated ' + call
PY
		[ "$status" -eq 0 ]
	done
}

@test "only GitHub selection authenticates but Go and Terraform do not" {
	export TOOLS_UPDATE_USE_GH_AUTH=invalid
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only terraform,go
	[ "$status" -eq 0 ]
	! grep -q '^gh ' "${CALLS_FILE}"
	: >"${CALLS_FILE}"
	export TOOLS_UPDATE_USE_GH_AUTH=1
	write_gh_stub token
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only gitleaks
	[ "$status" -eq 0 ]
	[ "$(grep -c '^gh auth token --hostname github.com$' "${CALLS_FILE}")" -eq 1 ]
	grep -Fq 'header Authorization: Bearer [redacted]' "${CALLS_FILE}"
}

@test "only advances selected bare baselines while preserving partial exact and provider intents" {
	sed -i -e 's/^TOOL_VITEST_VERSION=.*/TOOL_VITEST_VERSION="9.9.8"/' \
		-e 's/^TOOL_PNPM_VERSION=.*/TOOL_PNPM_VERSION="9.9"/' \
		-e 's/^TOOL_CODEGRAPH_VERSION=.*/TOOL_CODEGRAPH_VERSION="=1.6.0"/' \
		-e 's/^TOOL_GO_VERSION=.*/TOOL_GO_VERSION="9.0.0"/' \
		-e 's/^TOOL_DELVE_VERSION=.*/TOOL_DELVE_VERSION="1.0.0"/' "${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only vitest,pnpm,codegraph,go,delve,kubectl,plantuml
	[ "$status" -eq 0 ]
	grep -q '^TOOL_VITEST_VERSION="9.9.9"$' "${POLICY_FILE}"
	grep -q '^TOOL_GO_VERSION="9.9.9"$' "${POLICY_FILE}"
	grep -q '^LOCK_GO_VERSION="go9.9.9"$' "${POLICY_FILE}"
	grep -q '^TOOL_DELVE_VERSION="1.99.0"$' "${POLICY_FILE}"
	grep -q '^LOCK_DELVE_VERSION="v1.99.0"$' "${POLICY_FILE}"
	grep -q '^TOOL_PNPM_VERSION="9.9"$' "${POLICY_FILE}"
	grep -q '^TOOL_CODEGRAPH_VERSION="=1.6.0"$' "${POLICY_FILE}"
	grep -q '^TOOL_KUBECTL_VERSION="1.36.4"$' "${POLICY_FILE}"
	grep -q '^TOOL_PLANTUML_VERSION="1.2026.8"$' "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only vitest,pnpm,codegraph,go,delve,kubectl,plantuml
	[ "$status" -eq 0 ]
	cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
	sed -i 's/^TOOL_VITEST_VERSION=.*/TOOL_VITEST_VERSION="8.0.0"/' "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only vitest
	[ "$status" -ne 0 ]
	[[ "$output" == *'no stable candidate matching 8.0.0'* ]]
	cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
}

@test "only refuses symlink policy and validates unrelated inventory offline" {
	printf 'LOCK_UNKNOWN_VERSION="1.0.0"\n' >>"${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only vitest
	[ "$status" -ne 0 ]
	[ ! -s "${CALLS_FILE}" ]
	mv "${POLICY_FILE}" "${TEST_ROOT}/real-policy"
	ln -s "${TEST_ROOT}/real-policy" "${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --only vitest
	[ "$status" -ne 0 ]
	[[ "$output" == *'regular policy file'* ]]
	[ ! -s "${CALLS_FILE}" ]
}

@test "legacy update-pi exact version preserves unrelated bytes mode and provider isolation" {
	export TOOLS_UPDATE_USE_GH_AUTH=1
	chmod 0640 "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-pi 9.9.9
	[ "$status" -eq 0 ]
	grep -q '^TOOL_PI_CODING_AGENT_VERSION="9.9.9"$' "${POLICY_FILE}"
	grep -q '^LOCK_PI_CODING_AGENT_VERSION="9.9.9"$' "${POLICY_FILE}"
	local pattern='^(TOOL_PI_CODING_AGENT_VERSION|LOCK_PI_CODING_AGENT_VERSION)='
	grep -Ev "${pattern}" "${TEST_ROOT}/before" >"${TEST_ROOT}/unrelated-before"
	grep -Ev "${pattern}" "${POLICY_FILE}" >"${TEST_ROOT}/unrelated-after"
	cmp "${TEST_ROOT}/unrelated-before" "${TEST_ROOT}/unrelated-after"
	[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
	[ "$(cat "${CALLS_FILE}")" = 'curl -q -fsSL --max-time 15 --max-filesize 10000000 https://registry.npmjs.org/@earendil-works/pi-coding-agent/9.9.9' ]
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	: >"${CALLS_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-pi 9.9.9
	[ "$status" -eq 0 ]
	cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
	[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
	[ "$(cat "${CALLS_FILE}")" = 'curl -q -fsSL --max-time 15 --max-filesize 10000000 https://registry.npmjs.org/@earendil-works/pi-coding-agent/9.9.9' ]
}

@test "legacy update-pi exact argument parsing rejects missing extra and nonexact versions" {
	export TOOLS_UPDATE_USE_GH_AUTH=1
	chmod 0640 "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	write_forbidden_stub mktemp
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-pi
	[ "$status" -ne 0 ]
	[[ "$output" == *'expected --update-pi exact-version'* ]]
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-pi 9.9.9 extra
	[ "$status" -ne 0 ]
	[[ "$output" == *'expected --update-pi exact-version'* ]]
	local version
	for version in '' latest 9 9.9 '=9.9.9' '9.9.9-rc.1' ' 9.9.9' unsafe; do
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-pi "${version}"
		[ "$status" -ne 0 ]
		[[ "$output" == *'not a stable semantic version'* ]]
		cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
		[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
		[ ! -s "${CALLS_FILE}" ]
	done
}

@test "openspec scoped bootstrap selects stable 1.x and preserves unrelated bytes and mode" {
	sed -i '/^LOCK_OPENSPEC_VERSION=/d; s/^TOOL_OPENSPEC_VERSION=.*/TOOL_OPENSPEC_VERSION="1"/' "${POLICY_FILE}"
	write_openspec_metadata '{"name":"@fission-ai/openspec","versions":{"1.0.0":{},"1.9.0":{},"1.10.0":{},"1.11.0-beta.1":{},"2.0.0":{}}}'
	chmod 0640 "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-openspec
	[ "$status" -eq 0 ]
	[ "$(grep -c '^LOCK_OPENSPEC_VERSION="1.10.0"$' "${POLICY_FILE}")" -eq 1 ]
	grep -q '^TOOL_OPENSPEC_VERSION="1"$' "${POLICY_FILE}"
	grep -v '^LOCK_OPENSPEC_VERSION=' "${POLICY_FILE}" >"${TEST_ROOT}/unrelated"
	cmp "${TEST_ROOT}/before" "${TEST_ROOT}/unrelated"
	[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
	[ "$(wc -l <"${CALLS_FILE}")" -eq 1 ]
	grep -Fq 'https://registry.npmjs.org/@fission-ai/openspec' "${CALLS_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-openspec
	[ "$status" -eq 0 ]
	cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
}

@test "openspec scoped update rejects invalid or incompatible metadata atomically" {
	local metadata
	sed -i 's/^TOOL_OPENSPEC_VERSION=.*/TOOL_OPENSPEC_VERSION="1"/' "${POLICY_FILE}"
	chmod 0640 "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	for metadata in invalid '{"name":"wrong","versions":{"1.0.0":{}}}' '{"name":"@fission-ai/openspec","versions":[]}' '{"name":"@fission-ai/openspec","versions":{"2.0.0":{},"1.0.0-beta.1":{}}}'; do
		write_openspec_metadata "${metadata}"
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-openspec
		[ "$status" -ne 0 ]
		cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
		[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
	done
	write_forbidden_stub curl
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-openspec
	[ "$status" -ne 0 ]
	[[ "$output" == *'OpenSpec metadata request failed'* ]]
	cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
}

@test "openspec scoped update rejects extra arguments and symlink policy before network" {
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-openspec 1.0.0
	[ "$status" -ne 0 ]
	[ ! -s "${CALLS_FILE}" ]
	mv "${POLICY_FILE}" "${TEST_ROOT}/real-policy"
	ln -s "${TEST_ROOT}/real-policy" "${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-openspec
	[ "$status" -ne 0 ]
	[ ! -s "${CALLS_FILE}" ]
}

@test "new CodeGraph lock is bootstrapped by the updater with an exact pin" {
	sed -i '/^LOCK_CODEGRAPH_VERSION=/d; s/^TOOL_CODEGRAPH_VERSION=.*/TOOL_CODEGRAPH_VERSION="=1.6.0"/' "${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "$status" -eq 0 ]
	[ "$(grep -c '^LOCK_CODEGRAPH_VERSION="1.6.0"$' "${POLICY_FILE}")" -eq 1 ]
	grep -q '^TOOL_CODEGRAPH_VERSION="=1.6.0"$' "${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --validate
	[ "$status" -eq 0 ]
}

@test "ordinary updater bootstraps exactly two Shell locks and preserves policy mode" {
	sed -i '/^LOCK_GENTLE_SHELL_/d; s/^TOOL_GENTLE_SHELL_VERSION=.*/TOOL_GENTLE_SHELL_VERSION="=4.0.0"/' "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	chmod 640 "${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "$status" -eq 0 ]
	[ "$(grep -c '^LOCK_GENTLE_SHELL_' "${POLICY_FILE}")" -eq 2 ]
	grep -q '^LOCK_GENTLE_SHELL_VERSION="4.0.0"$' "${POLICY_FILE}"
	grep -q "^LOCK_GENTLE_SHELL_INTEGRITY=\"${SHELL_INTEGRITY}\"$" "${POLICY_FILE}"
	[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "$status" -eq 0 ]
	[[ "$output" == *'No changes'* ]]
	cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
}

@test "ordinary Shell bootstrap rolls back invalid registry metadata" {
	sed -i '/^LOCK_GENTLE_SHELL_/d' "${POLICY_FILE}"
	chmod 640 "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	write_curl_stub shell_bad_identity
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "$status" -ne 0 ]
	[[ "$output" == *'registry identity failed'* ]]
	cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
	[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
}

@test "ordinary Shell bootstrap rolls back invalid registry SRI" {
	sed -i '/^LOCK_GENTLE_SHELL_/d' "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	SHELL_INTEGRITY=sha512-invalid write_curl_stub success
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "$status" -ne 0 ]
	[[ "$output" == *'canonical SHA-512 SRI'* ]]
	cmp "${POLICY_FILE}" "${TEST_ROOT}/before"
	[ "$(stat -c %a "${POLICY_FILE}")" = "$(stat -c %a "${TEST_ROOT}/before")" ]
}

@test "failed bootstrap keeps policy bytes and mode without a partial lock" {
	sed -i '/^LOCK_CODEGRAPH_VERSION=/d' "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	write_pnpm_stub prerelease
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "$status" -ne 0 ]
	cmp "${POLICY_FILE}" "${TEST_ROOT}/before"
	[ "$(stat -c %a "${POLICY_FILE}")" = "$(stat -c %a "${TEST_ROOT}/before")" ]
}

@test "late provider failure does not publish a discovered initial lock" {
	sed -i '/^LOCK_CODEGRAPH_VERSION=/d' "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	write_curl_stub engram_bad_digest
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "$status" -ne 0 ]
	grep -q 'pnpm view @colbymchenry/codegraph versions --json' "${CALLS_FILE}"
	cmp "${POLICY_FILE}" "${TEST_ROOT}/before"
	[ "$(stat -c %a "${POLICY_FILE}")" = "$(stat -c %a "${TEST_ROOT}/before")" ]
}

@test "bootstrap keeps duplicate unknown and generated-section validation fail closed" {
	for corruption in duplicate unknown layout; do
		cp "${REPO_ROOT}/.devcontainer/tool-versions.conf" "${POLICY_FILE}"
		case "${corruption}" in
		duplicate) printf 'LOCK_CODEGRAPH_VERSION="1.6.0"\n' >>"${POLICY_FILE}" ;;
		unknown) printf 'LOCK_UNKNOWN_VERSION="1.0.0"\n' >>"${POLICY_FILE}" ;;
		layout) printf 'TOOL_UNKNOWN_VERSION="latest"\n' >>"${POLICY_FILE}" ;;
		esac
		cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
		[ "$status" -ne 0 ]
		cmp "${POLICY_FILE}" "${TEST_ROOT}/before"
		[ ! -s "${CALLS_FILE}" ]
	done
}

@test "bootstrap rejects missing intent and missing unregistered locks before discovery" {
	for key in TOOL_CODEGRAPH_VERSION LOCK_SKILLS_VERSION; do
		cp "${REPO_ROOT}/.devcontainer/tool-versions.conf" "${POLICY_FILE}"
		sed -i "/^${key}=/d" "${POLICY_FILE}"
		cp "${POLICY_FILE}" "${TEST_ROOT}/before"
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
		[ "$status" -ne 0 ]
		cmp "${POLICY_FILE}" "${TEST_ROOT}/before"
		[ ! -s "${CALLS_FILE}" ]
	done
}

write_archify_archive() {
	local version="$1"
	local mode="$2"
	python3 - "${ARCHIFY_ARCHIVE_FILE}" "${version}" "${mode}" <<'PY'
import json, stat, sys, zipfile
archive, version, mode = sys.argv[1:]
files = {
    "archify/SKILL.md": "---\nname: archify\ndescription: Fixture.\n---\n",
    "archify/package.json": json.dumps({"name": "archify", "version": version}),
    "archify/skill-release.json": json.dumps({"version": version}),
    "archify/bin/archify.mjs": "#!/usr/bin/env node\n",
}
if mode == "malformed": files = {"other/file": "bad"}
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
    for name, body in files.items():
        info = zipfile.ZipInfo(name)
        info.external_attr = (stat.S_IFREG | (0o755 if name.endswith(".mjs") else 0o644)) << 16
        z.writestr(info, body)
PY
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

write_pnpm_stub() {
	local mode="$1"
	cat >"${BIN_DIR}/pnpm" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'pnpm %s\n' "\$*" >>"${CALLS_FILE}"
if [ "${mode}" = prerelease ]; then
  printf '%s\n' '["9.9.9-beta.1"]'
else
  printf '%s\n' '["1.6.0","5.0.0","9.9.9","10.0.0"]'
fi
EOF
	chmod +x "${BIN_DIR}/pnpm"
}

write_sleep_stub() {
	cat >"${BIN_DIR}/sleep" <<'EOF'
#!/usr/bin/env bash
printf 'sleep %s\n' "$*" >>"${CALLS_FILE}"
EOF
	chmod +x "${BIN_DIR}/sleep"
}

write_forbidden_stub() {
	local command_name="$1"
	cat >"${BIN_DIR}/${command_name}" <<EOF
#!/usr/bin/env bash
printf '${command_name} %s\n' "\$*" >>"${CALLS_FILE}"
exit 99
EOF
	chmod +x "${BIN_DIR}/${command_name}"
}

write_gh_stub() {
	local mode="$1"
	cat >"${BIN_DIR}/gh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'gh %s\n' "\$*" >>"${CALLS_FILE}"
case "${mode}" in
token)
  [ "\$*" = 'auth token --hostname github.com' ] || exit 64
  printf '%s\n' 'gh-fixture-token' ;;
empty)
  [ "\$*" = 'auth token --hostname github.com' ] || exit 64 ;;
fail) exit 70 ;;
*) exit 64 ;;
esac
EOF
	chmod +x "${BIN_DIR}/gh"
}

write_expected_pnpm_calls() {
	python3 - "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" "$1" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
block = text.split("PACKAGE_SPECS=(", 1)[1].split("\n)", 1)[0]
packages = re.findall(r'"LOCK_[A-Z0-9_]+\|([^"|]+)"', block)
open(sys.argv[2], "w", encoding="utf-8").write("".join(f"pnpm view {p} versions --json\n" for p in packages))
PY
}

seed_gentle_fixture() {
	sed -i \
		-e 's/^TOOL_GENTLE_AI_VERSION=.*/TOOL_GENTLE_AI_VERSION="latest"/' \
		-e "s/^LOCK_GENTLE_AI_VERSION=.*/LOCK_GENTLE_AI_VERSION=\"${GENTLE_FIXTURE_VERSION}\"/" \
		-e "s/^LOCK_GENTLE_AI_SHA256_AMD64=.*/LOCK_GENTLE_AI_SHA256_AMD64=\"${GENTLE_FIXTURE_SHA256_AMD64}\"/" \
		-e "s/^LOCK_GENTLE_AI_SHA256_ARM64=.*/LOCK_GENTLE_AI_SHA256_ARM64=\"${GENTLE_FIXTURE_SHA256_ARM64}\"/" \
		"${POLICY_FILE}"
}

write_gentle_block() {
	grep '^LOCK_GENTLE_AI_' "${POLICY_FILE}" >"$1"
}

write_c4_archive_fixture() {
	local archive_root="${TEST_ROOT}/c4-archive"
	C4_ARCHIVE_FILE="${TEST_ROOT}/c4-plantuml.tar.gz"
	C4_ARCHIVE_VERSION="$(sed -n 's/^LOCK_C4_PLANTUML_VERSION="\([^"]*\)"$/\1/p' "${POLICY_FILE}")"
	mkdir -p "${archive_root}/C4-PlantUML-${C4_ARCHIVE_VERSION}"
	printf '%s\n' 'configured C4 content' >"${archive_root}/C4-PlantUML-${C4_ARCHIVE_VERSION}/C4.puml"
	tar -czf "${C4_ARCHIVE_FILE}" -C "${archive_root}" "C4-PlantUML-${C4_ARCHIVE_VERSION}"
	expected_checksum="$(sha256sum "${C4_ARCHIVE_FILE}" | awk '{print $1}')"
	sed -i "s/^LOCK_C4_PLANTUML_SHA256=.*/LOCK_C4_PLANTUML_SHA256=\"${expected_checksum}\"/" "${POLICY_FILE}"
}

write_curl_stub() {
	local mode="$1"
	local kubectl_response="${2:-v1.36.99}"
	local configured_gentle_version configured_gga_version
	local pagination_page
	configured_gentle_version="$(sed -n 's/^LOCK_GENTLE_AI_VERSION="\([^"]*\)"$/\1/p' "${POLICY_FILE}")"
	configured_gga_version="$(sed -n 's/^LOCK_GGA_VERSION="\([^"]*\)"$/\1/p' "${POLICY_FILE}")"
	pagination_page="$(
		python3 - <<'PY'
import json
print(json.dumps([{"tag_name": f"v9.0.{number}", "draft": False, "prerelease": False} for number in range(1, 101)]))
PY
	)"
	cat >"${BIN_DIR}/curl" <<EOF
#!/usr/bin/env bash
set -euo pipefail
	printf 'curl %s\n' "\$*" >>"${CALLS_FILE}"
	output=""
	headers=""
	writeout=""
	url=""
	conditional_etag=0
	while [ "\$#" -gt 0 ]; do
	  case "\$1" in
	    -o) output="\$2"; shift 2 ;;
	    -D) headers="\$2"; shift 2 ;;
	    -w) writeout="\$2"; shift 2 ;;
	    -H)
	      if [ "\$2" = @- ]; then
	        IFS= read -r authorization_header
	        case "\${authorization_header}" in
	          'Authorization: Bearer '*) printf '%s\n' 'header Authorization: Bearer [redacted]' >>"${CALLS_FILE}" ;;
	          *) printf '%s\n' 'invalid stdin authorization header' >&2; exit 64 ;;
	        esac
	      else
	        printf 'header %s\n' "\$2" >>"${CALLS_FILE}"
	        [ "\$2" != 'If-None-Match: "fixture-cache-etag"' ] || conditional_etag=1
	      fi
	      shift 2 ;;
	    -*) shift ;;
	    *) url="\$1"; shift ;;
	  esac
	done
	response_status=200
	response_headers=""
	body=""
if [ "${mode}" = github_etag_304 ] && [[ "\${url}" == *api.github.com* ]]; then
  if [ -f "${TEST_ROOT}/github-etag-phase" ] && [ "\${conditional_etag}" -eq 1 ]; then
    response_status=304
    response_headers='HTTP/2 304 Not Modified\r
X-GitHub-Request-Id: etag-fixture\r
'
  else
    response_headers='HTTP/2 200 OK\r
ETag: "fixture-cache-etag"\r
'
  fi
elif [ "${mode}" = github_403_retry ] && [[ "\${url}" == *api.github.com* ]]; then
  attempts_file="${TEST_ROOT}/github-api-attempts"
  attempts=0
  [ ! -f "\${attempts_file}" ] || attempts="\$(cat "\${attempts_file}")"
  attempts=\$((attempts + 1))
  printf '%s' "\${attempts}" >"\${attempts_file}"
  if [ "\${attempts}" -eq 1 ]; then
    body='{"message":"API rate limit exceeded"}'
    response_status=403
    response_headers='HTTP/2 403 Forbidden\r
Retry-After: 1\r
X-RateLimit-Remaining: 0\r
X-GitHub-Request-Id: retry-fixture\r
'
  fi
elif [ "${mode}" = github_403_unretryable ] && [[ "\${url}" == *api.github.com* ]]; then
  body='{"message":"Forbidden by fixture"}'
  response_status=403
  response_headers='HTTP/2 403 Forbidden\r
X-RateLimit-Remaining: 10\r
X-GitHub-Request-Id: denied-fixture\r
'
fi
if [ "${mode}" = fail ] && [[ "\${url}" == *releases.hashicorp.com* ]]; then
  exit 22
fi
if [ "${mode}" = gentle_fail ] && [[ "\${url}" == *Gentleman-Programming/gentle-ai* ]]; then
  exit 22
fi
if [ "\${response_status}" -eq 200 ]; then
case "\${url}" in
	https://registry.npmjs.org/@earendil-works/pi-coding-agent/9.9.9)
		body='{"name":"@earendil-works/pi-coding-agent","version":"9.9.9"}' ;;
	https://registry.npmjs.org/@colbymchenry/codegraph/1.6.0)
		body='{"name":"@colbymchenry/codegraph","version":"1.6.0"}'
		[ "${mode}" != npm_bad_name ] || body='{"name":"unexpected","version":"1.6.0"}'
		[ "${mode}" != npm_bad_version ] || body='{"name":"@colbymchenry/codegraph","version":"1.6.1"}' ;;
	https://registry.npmjs.org/vitest/9.9.9)
		body='{"name":"vitest","version":"9.9.9"}'
		[ "${mode}" != npm_bad_name ] || body='{"name":"unexpected","version":"9.9.9"}'
		[ "${mode}" != npm_bad_version ] || body='{"name":"vitest","version":"9.9.10"}' ;;
	*registry.npmjs.org/gentle-pi)
		body='{"versions":{"4.0.0":{},"4.1.0-beta.1":{}}}' ;;
	*registry.npmjs.org/gentle-pi/4.0.0)
		body='{"name":"gentle-pi","version":"4.0.0","bin":{"gentle-shell":"bin/gentle-shell.mjs"},"gitHead":"1f35ab1e4ff78f41ce6102cd961e7889a9f1cf69","dist":{"tarball":"https://registry.npmjs.org/gentle-pi/-/gentle-pi-4.0.0.tgz","integrity":"${SHELL_INTEGRITY}"}}'
		[ "${mode}" != shell_bad_identity ] || body='{"name":"unexpected"}' ;;
	*pypi.org/pypi/graphifyy/json) body='{"releases":{"9.9.9":{},"10.0.0":{}}}' ;;
	*repo.packagist.org/p2/phpunit/phpunit.json) body='{"packages":{"phpunit/phpunit":[{"version":"10.99.0","version_normalized":"10.99.0.0"}]}}' ;;

	*go.dev/dl*)
    body='[{"version":"go9.9.9","files":[{"version":"go9.9.9","os":"linux","arch":"amd64","kind":"archive","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},{"version":"go9.9.9","os":"linux","arch":"arm64","kind":"archive","sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]}]' ;;
  *bats-core/bats-core/archive/refs/tags/*)
    printf 'bats archive' >"\${output}"; exit 0 ;;
	*codeload.github.com/Gentleman-Programming/gentleman-guardian-angel/tar.gz/*)
    printf 'gga archive bytes' >"\${output}"; exit 0 ;;
  *go-delve/delve/releases/download/*/checksums.txt)
    body='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  dlv_1.99.0_linux_amd64.tar.gz
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb  dlv_1.99.0_linux_arm64.tar.gz' ;;
	*api.github.com/repos/bats-core/bats-core/releases/tags/v1.14.0)
		body='{"tag_name":"v1.14.0","draft":false,"prerelease":false}' ;;
  *api.github.com/repos/bats-core/bats-core/releases*)
		body='[{"tag_name":"v1.99.0","draft":false,"prerelease":false}]' ;;
	*repo.maven.apache.org/maven2/net/sourceforge/plantuml/plantuml/*/*.sha256)
		body='cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc' ;;
  *api.github.com/repos/Gentleman-Programming/engram/releases/tags/*)
    engram_prerelease=false
    engram_arm64_name=engram_1.99.0_linux_arm64.tar.gz
    engram_arm64_digest=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
    [ "${mode}" != engram_prerelease ] || engram_prerelease=true
    [ "${mode}" != engram_missing_asset ] || engram_arm64_name=unexpected.tar.gz
    [ "${mode}" != engram_bad_digest ] || engram_arm64_digest=sha256:invalid
    body="{\"tag_name\":\"v1.99.0\",\"draft\":false,\"prerelease\":\${engram_prerelease},\"assets\":[{\"name\":\"engram_1.99.0_linux_amd64.tar.gz\",\"digest\":\"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"},{\"name\":\"\${engram_arm64_name}\",\"digest\":\"\${engram_arm64_digest}\"}]}" ;;
  *api.github.com/repos/Gentleman-Programming/engram/releases*)
    body='[{"tag_name":"v1.99.0","draft":false,"prerelease":false}]' ;;
  https://opencode.ai/update/api/latest/cli/opencode)
    body='{"channel":"latest","name":"cli","distribution":"opencode","active":true,"version":"2.0.29","metadata":{"files":{"opencode-linux-x64.tar.gz":{"url":"https://opencode.ai/files/bin/2.0.29/opencode-linux-x64.tar.gz","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"opencode-linux-arm64.tar.gz":{"url":"https://opencode.ai/files/bin/2.0.29/opencode-linux-arm64.tar.gz","sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}}}'
    case "${mode}" in
      opencode_inactive) body="\$(printf '%s' "\${body}" | jq '.active = false')" ;;
      opencode_identity) body="\$(printf '%s' "\${body}" | jq '.distribution = "npm"')" ;;
      opencode_missing) body="\$(printf '%s' "\${body}" | jq 'del(.metadata.files["opencode-linux-arm64.tar.gz"])')" ;;
      opencode_digest) body="\$(printf '%s' "\${body}" | jq '.metadata.files["opencode-linux-arm64.tar.gz"].sha256 = "invalid"')" ;;
      opencode_url) body="\$(printf '%s' "\${body}" | jq '.metadata.files["opencode-linux-x64.tar.gz"].url = "https://example.com/binary"')" ;;
      opencode_prerelease) body="\$(printf '%s' "\${body}" | jq '.version = "2.0.30-beta.1"')" ;;
    esac ;;
  *api.github.com/repos/Gentleman-Programming/gentle-ai/releases\?*)
    body='[{"tag_name":"v${configured_gentle_version}","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/Gentleman-Programming/gentleman-guardian-angel/releases\?*)
    body='[{"tag_name":"v${configured_gga_version}","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/Gentleman-Programming/gentleman-guardian-angel/git/ref/tags/v*)
    gga_ref="refs/tags/v${configured_gga_version}"
    gga_type=commit
    gga_commit="${GGA_FIXTURE_COMMIT}"
    [ "${mode}" != gga_wrong_ref ] || gga_ref=refs/tags/v9.9.9
    [ "${mode}" != gga_tag_object ] || gga_type=tag
    [ "${mode}" != gga_bad_commit ] || gga_commit=invalid
    body="{\"ref\":\"\${gga_ref}\",\"object\":{\"type\":\"\${gga_type}\",\"sha\":\"\${gga_commit}\"}}" ;;

  *github.com/tt-a1i/archify/releases/download/*/archify.zip)
    case "${mode}" in
      archify_zip_layout) cp "${ARCHIFY_ARCHIVE_FILE}.bad-layout" "\${output}" ;;
      archify_zip_version) cp "${ARCHIFY_ARCHIVE_FILE}.wrong-version" "\${output}" ;;
      *) cp "${ARCHIFY_ARCHIVE_FILE}" "\${output}" ;;
    esac
    exit 0 ;;
  *releases.hashicorp.com/terraform/index.json)
    body='{"versions":{"1.98.0":{},"1.99.0":{},"2.0.0-beta.1":{}}}' ;;
  *dl.k8s.io/release/stable-1.36.txt)
    body='${kubectl_response}' ;;
  *dl.k8s.io/release/stable-1.37.txt)
    body='v1.37.99' ;;
  *codeload.github.com/plantuml-stdlib/C4-PlantUML*)
    if [ "${mode}" = c4_archive ]; then
      cp "${C4_ARCHIVE_FILE}" "\${output}"
      exit 0
    fi
    body='c4 archive bytes' ;;
  *api.github.com/repos/plantuml-stdlib/C4-PlantUML/releases*)
    body='[{"tag_name":"v3.0.0-beta.1","draft":false,"prerelease":true},{"tag_name":"v2.99.0","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/gitleaks/gitleaks/releases*)
		if [ "${mode}" = github_pagination ] && [[ "\${url}" == *'&page=1' ]]; then
			body='${pagination_page}'
		elif [ "${mode}" = github_pagination ]; then
			body='[{"tag_name":"v8.99.0","draft":false,"prerelease":false}]'
		else
			body='[{"tag_name":"v9.0.0-beta.1","draft":false,"prerelease":true},{"tag_name":"v8.99.0","draft":false,"prerelease":false}]'
		fi ;;
  *api.github.com/repos/pulumi/pulumi/releases*)
    body='[{"tag_name":"v3.999.0","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/opentofu/opentofu/releases*)
    body='[{"tag_name":"v1.99.0","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/gruntwork-io/terragrunt/releases*)
    body='[{"tag_name":"v1.99.0","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/plantuml/plantuml/releases*)
    body='[{"tag_name":"v1.2027.1","draft":false,"prerelease":false},{"tag_name":"v1.2026.99","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/go-delve/delve/releases*)
    body='[{"tag_name":"v2.0.0-rc.1","draft":false,"prerelease":true},{"tag_name":"v1.99.0","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/tt-a1i/archify/releases*)
    tag="v${ARCHIFY_FIXTURE_VERSION}"
    name=archify.zip
    asset_url="https://github.com/tt-a1i/archify/releases/download/\${tag}/archify.zip"
    digest="sha256:${ARCHIFY_FIXTURE_SHA256}"
    immutable=true; draft=false; prerelease=false
    case "${mode}" in
      archify_mutable) immutable=false ;;
      archify_bad_digest) digest=sha256:ABC ;;
      archify_download_digest) digest="sha256:$(printf '0%.0s' {1..64})" ;;
      archify_zip_layout) digest="sha256:${ARCHIFY_BAD_LAYOUT_SHA256}" ;;
      archify_zip_version) digest="sha256:${ARCHIFY_WRONG_VERSION_SHA256}" ;;
      archify_wrong_asset) name=other.zip ;;
      archify_wrong_url) asset_url="https://example.com/archify.zip" ;;
      archify_prerelease) prerelease=true ;;
    esac
    body="[{\"tag_name\":\"\${tag}\",\"draft\":\${draft},\"prerelease\":\${prerelease},\"immutable\":\${immutable},\"assets\":[{\"name\":\"\${name}\",\"browser_download_url\":\"\${asset_url}\",\"digest\":\"\${digest}\"}]}]"
    if [ "${mode}" = archify_duplicate ]; then
      body="\${body%]}]}, {\"name\":\"archify.zip\",\"browser_download_url\":\"\${asset_url}\",\"digest\":\"\${digest}\"}]}]"
    elif [ "${mode}" = archify_malformed ]; then
      body='not-json'
    fi ;;
  *api.github.com/repos/Gentleman-Programming/gentle-ai/releases/tags/v*)
    tag="v${configured_gentle_version}"
    api_url="https://api.github.com/repos/Gentleman-Programming/gentle-ai/releases/tags/\${tag}"
    html_url="https://github.com/Gentleman-Programming/gentle-ai/releases/tag/\${tag}"
    amd64_name="gentle-ai_${configured_gentle_version}_linux_amd64.tar.gz"
    arm64_name="gentle-ai_${configured_gentle_version}_linux_arm64.tar.gz"
    amd64_url="https://github.com/Gentleman-Programming/gentle-ai/releases/download/\${tag}/\${amd64_name}"
    arm64_url="https://github.com/Gentleman-Programming/gentle-ai/releases/download/\${tag}/\${arm64_name}"
    immutable=true; draft=false; prerelease=false
    amd64_digest="sha256:${GENTLE_FIXTURE_NEW_SHA256_AMD64}"
    arm64_digest="sha256:${GENTLE_FIXTURE_NEW_SHA256_ARM64}"
    case "${mode}" in
      gentle_wrong_tag) tag=v9.9.9 ;;
      gentle_wrong_repository) html_url="https://github.com/example/gentle-ai/releases/tag/\${tag}" ;;
      gentle_draft) draft=true ;;
      gentle_prerelease) prerelease=true ;;
      gentle_mutable) immutable=false ;;
      gentle_bad_digest) arm64_digest=sha256:ABC ;;
      gentle_missing_asset) arm64_name=not-the-selected-asset ;;
      gentle_wrong_asset_url) arm64_url="https://github.com/example/gentle-ai/releases/download/\${tag}/\${arm64_name}" ;;
    esac
    body="{\"url\":\"\${api_url}\",\"html_url\":\"\${html_url}\",\"tag_name\":\"\${tag}\",\"draft\":\${draft},\"prerelease\":\${prerelease},\"immutable\":\${immutable},\"assets\":[{\"name\":\"\${amd64_name}\",\"browser_download_url\":\"\${amd64_url}\",\"digest\":\"\${amd64_digest}\"},{\"name\":\"\${arm64_name}\",\"browser_download_url\":\"\${arm64_url}\",\"digest\":\"\${arm64_digest}\"}]}"
    if [ "${mode}" = gentle_duplicate ]; then
      body="\${body%]}}, {\"name\":\"\${amd64_name}\",\"browser_download_url\":\"\${amd64_url}\",\"digest\":\"\${amd64_digest}\"}]}"
    elif [ "${mode}" = gentle_no_immutable ]; then
      body="\${body/,\"immutable\":true/}"
    fi ;;
  *) echo "unexpected URL: \${url}" >&2; exit 64 ;;
esac
fi
if [ -n "\${output}" ]; then
  printf '%s' "\${body}" >"\${output}"
else
  printf '%s\n' "\${body}"
fi
if [ -n "\${headers}" ]; then
  printf '%b' "\${response_headers}" >"\${headers}"
fi
if [ -n "\${writeout}" ]; then
  printf '%s' "\${response_status}"
fi
EOF
	chmod +x "${BIN_DIR}/curl"
}

@test "tools:update atomically updates the approved stable pins with pnpm metadata" {
	write_gentle_block "${TEST_ROOT}/gentle-before"

	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"Run 'task container:rebuild && task container:up' to apply these versions."* ]]
	grep -q '^LOCK_PI_CODING_AGENT_VERSION="10.0.0"$' "${POLICY_FILE}"
	grep -q '^LOCK_ASYNCAPI_VERSION="10.0.0"$' "${POLICY_FILE}"
	grep -q '^LOCK_C4_PLANTUML_VERSION="2.99.0"$' "${POLICY_FILE}"
	expected_c4_sha="$(printf 'c4 archive bytes' | sha256sum | awk '{print $1}')"
	grep -q "^LOCK_C4_PLANTUML_SHA256=\"${expected_c4_sha}\"$" "${POLICY_FILE}"
	grep -q '^LOCK_TERRAFORM_VERSION="1.99.0"$' "${POLICY_FILE}"
	grep -q '^LOCK_GITLEAKS_VERSION="8.99.0"$' "${POLICY_FILE}"
	grep -q "^LOCK_GENTLE_AI_SHA256_AMD64=\"${GENTLE_FIXTURE_NEW_SHA256_AMD64}\"$" "${POLICY_FILE}"
	grep -q "^LOCK_GENTLE_AI_SHA256_ARM64=\"${GENTLE_FIXTURE_NEW_SHA256_ARM64}\"$" "${POLICY_FILE}"
	grep -q '^LOCK_PLANTUML_VERSION="1.2026.99"$' "${POLICY_FILE}"
	grep -q '^LOCK_KUBECTL_VERSION="1.36.99"$' "${POLICY_FILE}"
	grep -q '^LOCK_PLANTUML_SHA256="cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"$' "${POLICY_FILE}"
	grep -q '^LOCK_DELVE_VERSION="v1.99.0"$' "${POLICY_FILE}"
	grep -q "^LOCK_ARCHIFY_VERSION=\"${ARCHIFY_FIXTURE_VERSION}\"$" "${POLICY_FILE}"
	grep -q "^LOCK_ARCHIFY_SHA256=\"${ARCHIFY_FIXTURE_SHA256}\"$" "${POLICY_FILE}"
	grep -q '^LOCK_GGA_VERSION="2.10.1"$' "${POLICY_FILE}"
	grep -q "^LOCK_GGA_COMMIT=\"${GGA_FIXTURE_COMMIT}\"$" "${POLICY_FILE}"
	grep -q "^LOCK_GGA_SHA256=\"${GGA_FIXTURE_SHA256}\"$" "${POLICY_FILE}"
	! grep -Eq '(^| )(npm|pi)( |$)' "${CALLS_FILE}"
	write_expected_pnpm_calls "${TEST_ROOT}/expected-pnpm-calls"
	grep '^pnpm view ' "${CALLS_FILE}" >"${TEST_ROOT}/actual-pnpm-calls"
	cmp -s "${TEST_ROOT}/expected-pnpm-calls" "${TEST_ROOT}/actual-pnpm-calls"
}

@test "tools:update rejects invalid Archify metadata atomically" {
	local mode
	for mode in archify_mutable archify_bad_digest archify_wrong_asset archify_wrong_url archify_prerelease archify_duplicate archify_malformed; do
		write_curl_stub "${mode}"
		cp "${POLICY_FILE}" "${TEST_ROOT}/before"

		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"

		[ "${status}" -ne 0 ]
		cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
	done
}

@test "tools:update rejects invalid Archify candidate ZIPs at the intended validator" {
	local mode expected_error
	for mode in archify_download_digest archify_zip_layout archify_zip_version; do
		case "${mode}" in
		archify_download_digest) expected_error='SHA-256 mismatch' ;;
		archify_zip_layout) expected_error='unsafe path or multiple top-level trees' ;;
		archify_zip_version) expected_error='embedded version does not match' ;;
		esac
		write_curl_stub "${mode}"
		cp "${POLICY_FILE}" "${TEST_ROOT}/before"

		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"

		[ "${status}" -ne 0 ]
		[[ "${output}" == *"${expected_error}"* ]]
		cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
	done
}

@test "policy groups representative editable keys by owning installer" {
	awk '
		/^# Java — install\/available\/20-runtime-java\.sh$/ { group = "java"; next }
		/^# Node contracts — install\/available\/40-node-contracts\.sh$/ { group = "contracts"; next }
		/^# Playwright — install\/available\/50-browser-playwright\.sh$/ { group = "playwright"; next }
		/^# .* — install\/available\// { group = ""; next }
		/^#/ || /^$/ { next }
		group == "java" && /^TOOL_JAVA_/ { java++ }
		group == "contracts" && /^(TOOL_SPECTRAL_|TOOL_REDOCLY_|TOOL_ASYNCAPI_)/ { contracts++ }
		group == "playwright" && /^TOOL_PLAYWRIGHT_/ { playwright++ }
		END { exit !(java == 1 && contracts == 3 && playwright == 2) }
	' "${REPO_ROOT}/.devcontainer/tool-versions.conf"
}

@test "policy keys are valid and unique and digests stay in declared ownership sections" {
	policy="${REPO_ROOT}/.devcontainer/tool-versions.conf"
	run bash -c 'source "$1"; devcontainer_load_tool_versions "$2"' _ \
		"${REPO_ROOT}/.devcontainer/install/lib/common.sh" "${policy}"
	[ "${status}" -eq 0 ]

	keys="$(sed -nE 's/^(TOOL_[A-Z0-9_]+)=.*/\1/p' "${policy}")"
	[ -z "$(printf '%s\n' "${keys}" | sort | uniq -d)" ]
	grep -q '^# GENERATED LOCK' "${policy}"
	grep -q '^LOCK_OPENCODE_SHA256_AMD64=' "${policy}"
}

@test "tools:update keeps the selected Gentle AI version and atomically updates both digests" {
	seed_gentle_fixture
	write_curl_stub success

	run env TOOLS_UPDATE_SHOW_LOCKS=1 "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"

	[ "${status}" -eq 0 ]
	grep -q "^LOCK_GENTLE_AI_VERSION=\"${GENTLE_FIXTURE_VERSION}\"$" "${POLICY_FILE}"
	grep -q "^LOCK_GENTLE_AI_SHA256_AMD64=\"${GENTLE_FIXTURE_NEW_SHA256_AMD64}\"$" "${POLICY_FILE}"
	grep -q "^LOCK_GENTLE_AI_SHA256_ARM64=\"${GENTLE_FIXTURE_NEW_SHA256_ARM64}\"$" "${POLICY_FILE}"
	[[ "${output}" == *"LOCK_GENTLE_AI_SHA256_AMD64"* ]]
}

@test "tools:update accepts an exact stable release when immutable metadata is unavailable" {
	seed_gentle_fixture
	write_curl_stub gentle_no_immutable

	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"

	[ "${status}" -eq 0 ]
}

@test "tools:update rejects invalid Gentle AI release metadata and assets without writing" {
	local mode
	for mode in gentle_fail gentle_wrong_tag gentle_wrong_repository gentle_draft gentle_prerelease gentle_mutable gentle_bad_digest gentle_missing_asset gentle_wrong_asset_url gentle_duplicate; do
		seed_gentle_fixture
		write_curl_stub "${mode}"
		cp "${POLICY_FILE}" "${TEST_ROOT}/before"

		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"

		[ "${status}" -ne 0 ]
		cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
	done
}

@test "tools:update rejects invalid GGA tag resolution atomically" {
	local mode
	for mode in gga_wrong_ref gga_tag_object gga_bad_commit; do
		write_curl_stub "${mode}"
		cp "${POLICY_FILE}" "${TEST_ROOT}/before"

		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"

		[ "${status}" -ne 0 ]
		[[ "${output}" == *"GGA tag v2.10.1 must resolve directly to one immutable commit"* ]]
		cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
	done
}

@test "tools:update preserves channels pins provider strings and exception floors byte for byte" {
	sed -i \
		-e 's/^TOOL_VITEST_VERSION=.*/TOOL_VITEST_VERSION="9"/' \
		-e 's/^TOOL_PNPM_VERSION=.*/TOOL_PNPM_VERSION="9.9"/' \
		-e 's/^TOOL_GRAPHIFY_VERSION=.*/TOOL_GRAPHIFY_VERSION="=9.9.9"/' \
		"${POLICY_FILE}"
	grep '^TOOL_' "${POLICY_FILE}" >"${TEST_ROOT}/intent-before"

	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"

	[ "${status}" -eq 0 ]
	grep '^TOOL_' "${POLICY_FILE}" >"${TEST_ROOT}/intent-after"
	cmp -s "${TEST_ROOT}/intent-before" "${TEST_ROOT}/intent-after"
	grep -q '^LOCK_KUBECTL_VERSION="1.36.99"$' "${POLICY_FILE}"
	grep -q '^LOCK_PLANTUML_VERSION="1.2026.99"$' "${POLICY_FILE}"
}

@test "exact intents transition npm PyPI and GitHub asset locks to validated candidates" {
	sed -i \
		-e 's/^TOOL_VITEST_VERSION=.*/TOOL_VITEST_VERSION="=9.9.9"/' \
		-e 's/^LOCK_VITEST_VERSION=.*/LOCK_VITEST_VERSION="5.0.0"/' \
		-e 's/^TOOL_GRAPHIFY_VERSION=.*/TOOL_GRAPHIFY_VERSION="=9.9.9"/' \
		-e 's/^LOCK_GRAPHIFY_VERSION=.*/LOCK_GRAPHIFY_VERSION="1.0.0"/' \
		-e 's/^TOOL_ENGRAM_VERSION=.*/TOOL_ENGRAM_VERSION="=1.99.0"/' \
		-e 's/^LOCK_ENGRAM_VERSION=.*/LOCK_ENGRAM_VERSION="1.20.0"/' \
		-e 's/^LOCK_ENGRAM_SHA256_AMD64=.*/LOCK_ENGRAM_SHA256_AMD64="eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"/' \
		-e 's/^LOCK_ENGRAM_SHA256_ARM64=.*/LOCK_ENGRAM_SHA256_ARM64="ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"/' \
		"${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	grep -q '^TOOL_VITEST_VERSION="=9.9.9"$' "${POLICY_FILE}"
	grep -q '^LOCK_VITEST_VERSION="9.9.9"$' "${POLICY_FILE}"
	grep -q '^LOCK_GRAPHIFY_VERSION="9.9.9"$' "${POLICY_FILE}"
	grep -q '^LOCK_ENGRAM_VERSION="1.99.0"$' "${POLICY_FILE}"
	grep -q '^LOCK_ENGRAM_SHA256_AMD64="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"$' "${POLICY_FILE}"
	grep -q '^LOCK_ENGRAM_SHA256_ARM64="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"$' "${POLICY_FILE}"
	grep -Fq 'api.github.com/repos/Gentleman-Programming/engram/releases/tags/v1.99.0' "${CALLS_FILE}"
	! grep -Fq 'api.github.com/repos/Gentleman-Programming/engram/releases?per_page=' "${CALLS_FILE}"
}

@test "scoped Engram update preserves every unrelated byte and policy mode" {
	chmod 0640 "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-engram 1.99.0
	[ "$status" -eq 0 ]
	grep -q '^TOOL_ENGRAM_VERSION="1.99.0"$' "${POLICY_FILE}"
	grep -q '^LOCK_ENGRAM_VERSION="1.99.0"$' "${POLICY_FILE}"
	grep -q '^LOCK_ENGRAM_SHA256_AMD64="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"$' "${POLICY_FILE}"
	grep -q '^LOCK_ENGRAM_SHA256_ARM64="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"$' "${POLICY_FILE}"
	grep -Ev '^(TOOL_ENGRAM_VERSION|LOCK_ENGRAM_VERSION|LOCK_ENGRAM_SHA256_AMD64|LOCK_ENGRAM_SHA256_ARM64)=' "${TEST_ROOT}/before" >"${TEST_ROOT}/unrelated-before"
	grep -Ev '^(TOOL_ENGRAM_VERSION|LOCK_ENGRAM_VERSION|LOCK_ENGRAM_SHA256_AMD64|LOCK_ENGRAM_SHA256_ARM64)=' "${POLICY_FILE}" >"${TEST_ROOT}/unrelated-after"
	cmp "${TEST_ROOT}/unrelated-before" "${TEST_ROOT}/unrelated-after"
	[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
	! grep -Eq 'pnpm|registry.npmjs.org|anomalyco|releases\?per_page=' "${CALLS_FILE}"
}

@test "scoped Engram failures preserve original intent locks and mode" {
	local mode
	chmod 0640 "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	for mode in engram_prerelease engram_missing_asset engram_bad_digest; do
		write_curl_stub "${mode}"
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-engram 1.99.0
		[ "$status" -ne 0 ]
		cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
		[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
	done
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-engram 3.0.0 extra
	[ "$status" -ne 0 ]
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-engram unsafe
	[ "$status" -ne 0 ]
	cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
}

@test "scoped Engram uses the existing selector and refuses symlink policy" {
	sed -i 's/^TOOL_ENGRAM_VERSION=.*/TOOL_ENGRAM_VERSION="=1.99.0"/' "${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-engram
	[ "$status" -eq 0 ]
	grep -q '^TOOL_ENGRAM_VERSION="=1.99.0"$' "${POLICY_FILE}"
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-engram
	[ "$status" -eq 0 ]
	cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
	mv "${POLICY_FILE}" "${TEST_ROOT}/real-policy"
	ln -s "${TEST_ROOT}/real-policy" "${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" --update-engram 1.99.0
	[ "$status" -ne 0 ]
	[[ "$output" == *'regular policy file'* ]]
	cmp "${TEST_ROOT}/before" "${TEST_ROOT}/real-policy"
}

@test "exact npm metadata rejects wrong package names and versions without writing" {
	local key package version mode
	for key in CODEGRAPH VITEST; do
		case "${key}" in
		CODEGRAPH)
			package=@colbymchenry/codegraph
			version=1.6.0
			;;
		VITEST)
			package=vitest
			version=9.9.9
			;;
		esac
		for mode in npm_bad_name npm_bad_version; do
			sed -i "s/^TOOL_${key}_VERSION=.*/TOOL_${key}_VERSION=\"=${version}\"/" "${POLICY_FILE}"
			write_curl_stub "${mode}"
			chmod 0640 "${POLICY_FILE}"
			cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
			run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
			[ "$status" -ne 0 ]
			[[ "$output" == *"npm package ${package}@${version} identity validation failed"* ]]
			cmp "${TEST_ROOT}/before" "${POLICY_FILE}"
			[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
		done
		sed -i "s/^TOOL_${key}_VERSION=.*/TOOL_${key}_VERSION=\"latest\"/" "${POLICY_FILE}"
	done
}

@test "Engram byte scope rejects a publisher changing unrelated intent or comments" {
	# Load definitions only; do not run the updater main or its provider discovery.
	python3 - "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" "${TEST_ROOT}/scope.sh" <<'PY'
import pathlib,sys
source = pathlib.Path(sys.argv[1]).read_text()
assert source.endswith('main "$@"\n')
pathlib.Path(sys.argv[2]).write_text(source[:-len('main "$@"\n')])
PY
	local mutation
	for mutation in allowed unrelated comment; do
		cp -p "${POLICY_FILE}" "${TEST_ROOT}/candidate"
		# A permitted change proves this guard is not rejecting every candidate.
		sed -i 's/^TOOL_ENGRAM_VERSION=.*/TOOL_ENGRAM_VERSION="1.99.0"/' "${TEST_ROOT}/candidate"
		case "${mutation}" in
		unrelated) sed -i 's/^TOOL_PI_CODING_AGENT_VERSION=.*/TOOL_PI_CODING_AGENT_VERSION="9.0.0"/' "${TEST_ROOT}/candidate" ;;
		comment) printf '# unexpected publisher comment\n' >>"${TEST_ROOT}/candidate" ;;
		esac
		run bash -c '
			source "$1"
			UPDATE_KEYS=(TOOL_ENGRAM_VERSION LOCK_ENGRAM_VERSION LOCK_ENGRAM_SHA256_AMD64 LOCK_ENGRAM_SHA256_ARM64)
			validate_scope "$2" "$3" scoped-update
		' _ "${TEST_ROOT}/scope.sh" "${POLICY_FILE}" "${TEST_ROOT}/candidate"
		if [ "${mutation}" = allowed ]; then
			[ "$status" -eq 0 ]
		else
			[ "$status" -ne 0 ]
			[[ "$output" == *'unrelated policy bytes'* ]]
		fi
	done
}

@test "exact GitHub asset pins reject unstable or incomplete releases atomically" {
	local mode before_mode
	for mode in engram_prerelease engram_missing_asset engram_bad_digest; do
		sed -i 's/^TOOL_ENGRAM_VERSION=.*/TOOL_ENGRAM_VERSION="=1.99.0"/' "${POLICY_FILE}"
		chmod 0640 "${POLICY_FILE}"
		write_curl_stub "${mode}"
		cp "${POLICY_FILE}" "${TEST_ROOT}/before"
		before_mode="$(stat -c %a "${POLICY_FILE}")"

		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"

		[ "${status}" -ne 0 ]
		cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
		[ "$(stat -c %a "${POLICY_FILE}")" = "${before_mode}" ]
	done
}

@test "provider discovery selects the newest compatible major and PlantUML year lane" {
	sed -i \
		-e 's/^TOOL_VITEST_VERSION=.*/TOOL_VITEST_VERSION="9"/' \
		-e 's/^TOOL_PLANTUML_VERSION=.*/TOOL_PLANTUML_VERSION="1.2026"/' \
		"${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	grep -q '^LOCK_VITEST_VERSION="9.9.9"$' "${POLICY_FILE}"
	grep -q '^LOCK_PLANTUML_VERSION="1.2026.99"$' "${POLICY_FILE}"
}

@test "kubectl rejects provider responses outside the requested minor before continuing discovery" {
	local response
	cp "${POLICY_FILE}" "${TEST_ROOT}/before"
	for response in v1.37.99 v1.35.99 v2.36.99 v0.36.99; do
		write_curl_stub success "${response}"
		: >"${CALLS_FILE}"

		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"

		[ "${status}" -ne 0 ]
		[[ "${output}" == *"kubectl channel 1.36 returned out-of-lane version '${response}'"* ]]
		cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
		grep -Fq 'https://dl.k8s.io/release/stable-1.36.txt' "${CALLS_FILE}"
		run grep -Fq "https://dl.k8s.io/release/${response}/" "${CALLS_FILE}"
		[ "${status}" -eq 1 ]
		run grep -Fq 'api.github.com/repos/plantuml/plantuml/' "${CALLS_FILE}"
		[ "${status}" -eq 1 ]
	done
}

@test "kubectl rejects malformed and prerelease channel responses without writing" {
	local response
	cp "${POLICY_FILE}" "${TEST_ROOT}/before"
	for response in 1.36.99 v1.36 v1.36.99-rc.1 v1.36.99+build; do
		write_curl_stub success "${response}"
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
		[ "${status}" -ne 0 ]
		[[ "${output}" == *"kubectl channel returned invalid version '${response}'"* ]]
		cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
	done
}

@test "kubectl preserves minimum floors and exact pin semantics within the selected minor" {
	local intent
	for intent in 1.36.100 =1.36.4; do
		sed -i "s/^TOOL_KUBECTL_VERSION=.*/TOOL_KUBECTL_VERSION=\"${intent}\"/" "${POLICY_FILE}"
		cp "${POLICY_FILE}" "${TEST_ROOT}/before"
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
		[ "${status}" -ne 0 ]
		[[ "${output}" == *"LOCK_KUBECTL_VERSION candidate 1.36.99 escapes intent ${intent}"* ]]
		cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
	done
	sed -i 's/^TOOL_KUBECTL_VERSION=.*/TOOL_KUBECTL_VERSION="=1.36.99"/' "${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	grep -q '^LOCK_KUBECTL_VERSION="1.36.99"$' "${POLICY_FILE}"
}

@test "kubectl resolves a deliberately selected alternative minor independently of the live policy" {
	sed -i 's/^TOOL_KUBECTL_VERSION=.*/TOOL_KUBECTL_VERSION="1.37.4"/' "${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	grep -q '^LOCK_KUBECTL_VERSION="1.37.99"$' "${POLICY_FILE}"
	grep -Fq 'https://dl.k8s.io/release/stable-1.37.txt' "${CALLS_FILE}"
	run grep -Fq 'https://dl.k8s.io/release/stable-1.36.txt' "${CALLS_FILE}"
	[ "${status}" -eq 1 ]
}

@test "PlantUML permits a deliberately selected alternative year and the latest escape" {
	local intent
	for intent in 1.2027.1 latest; do
		sed -i "s/^TOOL_PLANTUML_VERSION=.*/TOOL_PLANTUML_VERSION=\"${intent}\"/" "${POLICY_FILE}"
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
		[ "${status}" -eq 0 ]
		grep -q '^LOCK_PLANTUML_VERSION="1.2027.1"$' "${POLICY_FILE}"
	done
}

@test "bare semantic baseline rejects older candidates and selects a newer compatible candidate" {
	sed -i 's/^TOOL_VITEST_VERSION=.*/TOOL_VITEST_VERSION="9.9.8"/' "${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	grep -q '^LOCK_VITEST_VERSION="9.9.9"$' "${POLICY_FILE}"
	grep -q '^TOOL_VITEST_VERSION="9.9.9"$' "${POLICY_FILE}"
	[[ "${output}" == *"TOOL_VITEST_VERSION: 9.9.8 -> 9.9.9"* ]]
}

@test "baseline advancement covers direct releases and normalizes provider lock prefixes" {
	sed -i \
		-e 's/^TOOL_ENGRAM_VERSION=.*/TOOL_ENGRAM_VERSION="1.20.0"/' \
		-e 's/^TOOL_TERRAFORM_VERSION=.*/TOOL_TERRAFORM_VERSION="1.16.1"/' \
		-e 's/^TOOL_DELVE_VERSION=.*/TOOL_DELVE_VERSION="1.0.0"/' \
		-e 's/^TOOL_GO_VERSION=.*/TOOL_GO_VERSION="9.0.0"/' \
		"${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	grep -q '^TOOL_ENGRAM_VERSION="1.99.0"$' "${POLICY_FILE}"
	grep -q '^TOOL_TERRAFORM_VERSION="1.99.0"$' "${POLICY_FILE}"
	grep -q '^TOOL_DELVE_VERSION="1.99.0"$' "${POLICY_FILE}"
	grep -q '^LOCK_DELVE_VERSION="v1.99.0"$' "${POLICY_FILE}"
	grep -q '^TOOL_GO_VERSION="9.9.9"$' "${POLICY_FILE}"
	grep -q '^LOCK_GO_VERSION="go9.9.9"$' "${POLICY_FILE}"
}

@test "baseline advancement catches up with an existing lock and is idempotent" {
	sed -i \
		-e 's/^TOOL_VITEST_VERSION=.*/TOOL_VITEST_VERSION="9.9.8"/' \
		-e 's/^LOCK_VITEST_VERSION=.*/LOCK_VITEST_VERSION="9.9.9"/' \
		"${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	grep -q '^TOOL_VITEST_VERSION="9.9.9"$' "${POLICY_FILE}"
	[[ "${output}" == *"TOOL_VITEST_VERSION: 9.9.8 -> 9.9.9"* ]]
	[[ "${output}" != *"LOCK_VITEST_VERSION:"* ]]
	cp "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"No changes."* ]]
	cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
}

@test "baseline advancement rejects another major using the original floor without writing" {
	sed -i 's/^TOOL_VITEST_VERSION=.*/TOOL_VITEST_VERSION="8.0.0"/' "${POLICY_FILE}"
	cp "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"no stable candidate matching 8.0.0"* ]]
	cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
}

@test "baseline advancement remains atomic when a later architecture checksum fails" {
	sed -i 's/^TOOL_VITEST_VERSION=.*/TOOL_VITEST_VERSION="9.9.8"/' "${POLICY_FILE}"
	write_curl_stub engram_bad_digest
	cp "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"has no valid SHA-256"* ]]
	cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
}

@test "baseline scope guard rejects tampering and rechecks the original compatibility floor" {
	local mutation
	for mutation in unrelated wrong-baseline wrong-lock other-major; do
		run bash -c '
			source <(sed '\''$d'\'' "$1")
			TEMP_DIR="$TEST_ROOT/scope"
			mkdir -p "$TEMP_DIR"
			MANAGED_KEYS=(LOCK_VITEST_VERSION)
			replace_assignment "$POLICY_FILE" TOOL_VITEST_VERSION 9.9.8
			CANDIDATES[LOCK_VITEST_VERSION]=9.9.9
			candidate="$TEMP_DIR/candidate"
			cp "$POLICY_FILE" "$candidate"
			replace_assignment "$candidate" TOOL_VITEST_VERSION 9.9.9
			replace_assignment "$candidate" LOCK_VITEST_VERSION 9.9.9
			validate_scope "$POLICY_FILE" "$candidate"
			case "$2" in
			unrelated) replace_assignment "$candidate" TOOL_KUBECTL_VERSION 1.36.99 ;;
			wrong-baseline) replace_assignment "$candidate" TOOL_VITEST_VERSION 9.9.10 ;;
			wrong-lock) replace_assignment "$candidate" LOCK_VITEST_VERSION 9.9.10 ;;
			other-major)
				CANDIDATES[LOCK_VITEST_VERSION]=10.0.0
				replace_assignment "$candidate" TOOL_VITEST_VERSION 10.0.0
				replace_assignment "$candidate" LOCK_VITEST_VERSION 10.0.0 ;;
			esac
			validate_scope "$POLICY_FILE" "$candidate"
		' _ "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh" "${mutation}"
		[ "${status}" -ne 0 ]
		[[ "${output}" == *"outside the approved key scope"* || "${output}" == *"changed resolved lock"* || "${output}" == *"escapes original intent"* ]]
	done
}

@test "GitHub compatibility discovery continues beyond the first 100 releases" {
	sed -i 's/^TOOL_GITLEAKS_VERSION=.*/TOOL_GITLEAKS_VERSION="8"/' "${POLICY_FILE}"
	write_curl_stub github_pagination
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	grep -q '^LOCK_GITLEAKS_VERSION="8.99.0"$' "${POLICY_FILE}"
	grep -Fq 'api.github.com/repos/gitleaks/gitleaks/releases?per_page=100&page=2' "${CALLS_FILE}"
}

@test "exact GitHub intent uses the exact release endpoint instead of a release listing" {
	sed -i 's/^TOOL_BATS_VERSION=.*/TOOL_BATS_VERSION="=1.14.0"/' "${POLICY_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	grep -Fq 'api.github.com/repos/bats-core/bats-core/releases/tags/v1.14.0' "${CALLS_FILE}"
	! grep -Fq 'api.github.com/repos/bats-core/bats-core/releases?per_page=' "${CALLS_FILE}"
	grep -q '^LOCK_BATS_VERSION="1.14.0"$' "${POLICY_FILE}"
}

@test "GitHub API requests identify the updater and retry a bounded rate limit response" {
	write_curl_stub github_403_retry
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	grep -Fq 'header Accept: application/vnd.github+json' "${CALLS_FILE}"
	grep -Fq 'header X-GitHub-Api-Version: 2026-03-10' "${CALLS_FILE}"
	grep -Fq 'header User-Agent: gentle-starter-tools-update' "${CALLS_FILE}"
	grep -Fq 'sleep 1' "${CALLS_FILE}"
	[ "$(grep -c 'Gentleman-Programming/gentle-ai/releases?per_page=100&page=1' "${CALLS_FILE}")" -eq 2 ]
	[[ "${output}" == *"GitHub API rate limit"* ]]
}

@test "GitHub API 200 responses create a private opaque ETag cache without temporary files" {
	write_curl_stub github_etag_304
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	[ "$(stat -c %a "${GITHUB_API_CACHE_DIR}")" = 700 ]
	[ "$(find "${GITHUB_API_CACHE_DIR}" -maxdepth 1 -name '*.body' -type f | wc -l)" -gt 0 ]
	[ "$(find "${GITHUB_API_CACHE_DIR}" -maxdepth 1 -name '*.etag' -type f | wc -l)" -gt 0 ]
	[ -z "$(find "${GITHUB_API_CACHE_DIR}" -maxdepth 1 -name '.github-api-*' -print)" ]
	while IFS= read -r cache_file; do
		[ "$(stat -c %a "${cache_file}")" = 600 ]
		[[ "$(basename "${cache_file}")" =~ ^[0-9a-f]{64}\.(body|etag)$ ]]
	done < <(find "${GITHUB_API_CACHE_DIR}" -maxdepth 1 -type f -print)
}

@test "GitHub API sends If-None-Match and validates cached bodies after a 304" {
	write_curl_stub github_etag_304
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	touch "${TEST_ROOT}/github-etag-phase"
	: >"${CALLS_FILE}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"No changes."* ]]
	grep -Fq 'header If-None-Match: "fixture-cache-etag"' "${CALLS_FILE}"
}

@test "GitHub API 304 fails closed for missing or corrupt cached response bodies" {
	local corruption
	for corruption in missing corrupt; do
		write_curl_stub github_etag_304
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
		[ "${status}" -eq 0 ]
		cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
		if [ "${corruption}" = missing ]; then
			find "${GITHUB_API_CACHE_DIR}" -name '*.body' -delete
		else
			find "${GITHUB_API_CACHE_DIR}" -name '*.body' -exec sh -c 'printf invalid >"$1"' _ {} \;
		fi
		touch "${TEST_ROOT}/github-etag-phase"
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
		[ "${status}" -ne 0 ]
		cmp -s "${POLICY_FILE}" "${TEST_ROOT}/before"
		if [ "${corruption}" = missing ]; then
			[[ "${output}" == *"cached response body is missing or malformed"* ]]
		fi
		rm -rf "${GITHUB_API_CACHE_DIR}" "${TEST_ROOT}/github-etag-phase"
	done
}

@test "GitHub API cache miss plus transport failure fails closed without publishing" {
	write_curl_stub gentle_fail
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"GitHub API request failed"* ]]
	cmp -s "${POLICY_FILE}" "${TEST_ROOT}/before"
	[ ! -d "${GITHUB_API_CACHE_DIR}" ]
}

@test "GitHub API sends a non-empty GH_TOKEN without exposing it" {
	secret_marker='fixture-secret-not-for-output'
	write_curl_stub github_etag_304
	export GH_TOKEN="${secret_marker}"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	unset GH_TOKEN
	[ "${status}" -eq 0 ]
	update_output="${output}"
	grep -Fq 'header Authorization: Bearer [redacted]' "${CALLS_FILE}"
	run grep -Fq "${secret_marker}" "${CALLS_FILE}"
	[ "${status}" -ne 0 ]
	run grep -R -F "${secret_marker}" "${GITHUB_API_CACHE_DIR}"
	[ "${status}" -ne 0 ]
	[[ "${update_output}" != *"${secret_marker}"* ]]
}

@test "GitHub API preserves GH_TOKEN precedence over opted-in gh authentication" {
	secret_marker='fixture-direct-token'
	export GH_TOKEN="${secret_marker}"
	export TOOLS_UPDATE_USE_GH_AUTH=1
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	unset GH_TOKEN TOOLS_UPDATE_USE_GH_AUTH
	[ "${status}" -eq 0 ]
	grep -Fq 'header Authorization: Bearer [redacted]' "${CALLS_FILE}"
	run grep -Fq 'gh auth token' "${CALLS_FILE}"
	[ "${status}" -ne 0 ]
	[[ "${output}" != *"${secret_marker}"* ]]
}

@test "GitHub API does not probe gh without explicit opt-in" {
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -eq 0 ]
	run grep -Fq 'gh auth token' "${CALLS_FILE}"
	[ "${status}" -ne 0 ]
}

@test "GitHub API uses an opted-in github.com gh token without disclosure" {
	write_gh_stub token
	export TOOLS_UPDATE_USE_GH_AUTH=1
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	unset TOOLS_UPDATE_USE_GH_AUTH
	[ "${status}" -eq 0 ]
	grep -Fq 'gh auth token --hostname github.com' "${CALLS_FILE}"
	grep -Fq 'header Authorization: Bearer [redacted]' "${CALLS_FILE}"
	run grep -Fq 'gh-fixture-token' "${CALLS_FILE}"
	[ "${status}" -ne 0 ]
	[[ "${output}" != *'gh-fixture-token'* ]]
}

@test "GitHub API rejects invalid gh authentication opt-in before discovery" {
	local direct_token
	for direct_token in unset present; do
		export TOOLS_UPDATE_USE_GH_AUTH=enabled
		if [ "${direct_token}" = present ]; then
			export GH_TOKEN='fixture-direct-token'
		fi
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
		unset GH_TOKEN TOOLS_UPDATE_USE_GH_AUTH
		[ "${status}" -ne 0 ]
		[[ "${output}" == *'TOOLS_UPDATE_USE_GH_AUTH must be unset or 1'* ]]
		[ ! -s "${CALLS_FILE}" ]
	done
}

@test "GitHub API fails closed when opted-in gh authentication is unavailable, fails, or is empty" {
	local mode expected_error
	for mode in unavailable fail empty; do
		case "${mode}" in
		unavailable)
			export DEPS_UPDATE_GH="${BIN_DIR}/missing-gh"
			expected_error='gh is unavailable'
			;;
		fail)
			write_gh_stub fail
			expected_error='gh auth token failed'
			;;
		empty)
			write_gh_stub empty
			expected_error='gh auth token returned no token'
			;;
		esac
		export TOOLS_UPDATE_USE_GH_AUTH=1
		run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
		unset TOOLS_UPDATE_USE_GH_AUTH
		[ "${status}" -ne 0 ]
		[[ "${output}" == *"${expected_error}"* ]]
		[ "$(grep -c '^curl ' "${CALLS_FILE}")" -eq 0 ]
		: >"${CALLS_FILE}"
		export DEPS_UPDATE_GH="${BIN_DIR}/gh"
	done
}

@test "GitHub API preserves anonymous requests for an empty GH_TOKEN" {
	export GH_TOKEN=''
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	unset GH_TOKEN
	[ "${status}" -eq 0 ]
	run grep -Fq 'Authorization: Bearer' "${CALLS_FILE}"
	[ "${status}" -ne 0 ]
}

@test "GitHub API 403 diagnostics fail closed without retry when no retry signal exists" {
	write_curl_stub github_403_unretryable
	cp -p "${POLICY_FILE}" "${TEST_ROOT}/before"
	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"HTTP 403"* ]]
	[[ "${output}" == *"request_id=denied-fixture"* ]]
	[[ "${output}" == *"rate_remaining=10"* ]]
	[[ "${output}" == *"message=Forbidden by fixture"* ]]
	! grep -Fq 'sleep ' "${CALLS_FILE}"
	cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
}

@test "tools:update rejects prerelease package metadata without writing" {
	write_pnpm_stub prerelease
	cp "${POLICY_FILE}" "${TEST_ROOT}/before"

	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"not a stable semantic version"* ]]
	cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
}

@test "tools:update leaves policy unchanged when direct release discovery fails" {
	write_curl_stub fail
	chmod 0640 "${POLICY_FILE}"
	cp "${POLICY_FILE}" "${TEST_ROOT}/before"
	before_mode="$(stat -c %a "${POLICY_FILE}")"

	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"

	[ "${status}" -ne 0 ]
	cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
	[ "$(stat -c %a "${POLICY_FILE}")" = "${before_mode}" ]
	[ -z "$(find "${TEST_ROOT}" -maxdepth 1 -name '.tool-versions.conf.*' -print)" ]
}

@test "tools:update preserves policy bytes and mode when atomic publication fails" {
	chmod 0640 "${POLICY_FILE}"
	cp "${POLICY_FILE}" "${TEST_ROOT}/before"
	cat >"${BIN_DIR}/mv" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == */.tool-versions.conf.* && "${2:-}" == "${DEPS_UPDATE_POLICY_FILE}" ]]; then
	exit 73
fi
exec /bin/mv "$@"
EOF
	chmod +x "${BIN_DIR}/mv"

	run "${REPO_ROOT}/.taskfiles/scripts/tools-update.sh"

	[ "${status}" -eq 73 ]
	cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
	[ "$(stat -c %a "${POLICY_FILE}")" = 640 ]
	[ -z "$(find "${TEST_ROOT}" -maxdepth 1 -name '.tool-versions.conf.*' -print)" ]
}

@test "C4 installer resolves the central version and checksum with environment precedence" {
	sed -i 's/^LOCK_C4_PLANTUML_SHA256=.*/LOCK_C4_PLANTUML_SHA256="0000000000000000000000000000000000000000000000000000000000000001"/' "${POLICY_FILE}"
	configured_version="$(sed -n 's/^LOCK_C4_PLANTUML_VERSION="\([^"]*\)"$/\1/p' "${POLICY_FILE}")"

	run env DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY_FILE}" \
		"${REPO_ROOT}/.devcontainer/install/available/2220-cli-c4-plantuml.sh" --print-version-policy
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"C4_PLANTUML_VERSION=${configured_version}"* ]]
	[[ "${output}" == *"C4_PLANTUML_SHA256=$(printf '%064d' 1)"* ]]

	run env DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY_FILE}" \
		C4_PLANTUML_VERSION="2.88.0" C4_PLANTUML_SHA256="$(printf '%064d' 2)" \
		"${REPO_ROOT}/.devcontainer/install/available/2220-cli-c4-plantuml.sh" --print-version-policy
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"C4_PLANTUML_VERSION=2.88.0"* ]]
	[[ "${output}" == *"C4_PLANTUML_SHA256=$(printf '%064d' 2)"* ]]
}

@test "C4 installer replaces a stale checksum installation with the configured archive" {
	install_dir="${TEST_ROOT}/c4-plantuml"
	write_c4_archive_fixture
	expected_version="${C4_ARCHIVE_VERSION}"
	expected_checksum="$(sed -n 's/^LOCK_C4_PLANTUML_SHA256="\([^"]*\)"$/\1/p' "${POLICY_FILE}")"
	write_curl_stub c4_archive
	mkdir -p "${install_dir}"
	printf '%s\n' 'stale C4 content' >"${install_dir}/C4.puml"
	printf '%s\n' "${expected_version}" >"${install_dir}/.version"
	printf '%064d\n' 9 >"${install_dir}/.sha256"

	run env DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY_FILE}" \
		C4_PLANTUML_INSTALL_DIR="${install_dir}" \
		"${REPO_ROOT}/.devcontainer/install/available/2220-cli-c4-plantuml.sh"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"Downloading C4-PlantUML ${expected_version}"* ]]
	[ "$(cat "${install_dir}/C4.puml")" = 'configured C4 content' ]
	[ "$(cat "${install_dir}/.version")" = "${expected_version}" ]
	[ "$(cat "${install_dir}/.sha256")" = "${expected_checksum}" ]
}

@test "C4 installer treats matching version and checksum as installed" {
	install_dir="${TEST_ROOT}/c4-plantuml"
	expected_version="$(sed -n 's/^LOCK_C4_PLANTUML_VERSION="\([^"]*\)"$/\1/p' "${POLICY_FILE}")"
	expected_checksum="$(sed -n 's/^LOCK_C4_PLANTUML_SHA256="\([^"]*\)"$/\1/p' "${POLICY_FILE}")"
	mkdir -p "${install_dir}"
	printf '%s\n' "${expected_version}" >"${install_dir}/.version"
	printf '%s\n' "${expected_checksum}" >"${install_dir}/.sha256"

	run env DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY_FILE}" \
		C4_PLANTUML_INSTALL_DIR="${install_dir}" \
		"${REPO_ROOT}/.devcontainer/install/available/2220-cli-c4-plantuml.sh"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"already installed at ${install_dir}"* ]]
}

@test "public task surface exposes tools:update and removes legacy update tasks" {
	run task --dir "${REPO_ROOT}" --list
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"tools:update"* ]]
	[[ "${output}" != *"deps:update"* ]]
	[[ "${output}" != *"ai:update"* ]]
	[[ "${output}" != *"ai:configure-models"* ]]

	run task --dir "${REPO_ROOT}" help
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"task tools:update"* ]]
	[[ "${output}" != *"task deps:update"* ]]
	[[ "${output}" != *"task ai:update"* ]]
	[[ "${output}" != *"task ai:configure-models"* ]]
}
