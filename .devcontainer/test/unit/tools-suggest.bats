#!/usr/bin/env bats

load install-fixture

tools() { (cd "${FIXTURE}" && bash "${REPO_ROOT}/.taskfiles/scripts/suggest.sh" tools); }

tool_catalog() {
	printf '{"version":1,"tools":["1020-tool-leaf.sh","1030-tool-companion.sh"]}\n' >"${INSTALL}/recommended-tools.json"
}

@test "tools catalog rejects nonexecutable recommended roots and their dependency closure before menu" {
	tool_catalog
	for name in 1020-tool-leaf 1010-tool-middle 1000-runtime-base; do
		chmod 0644 "${INSTALL}/available/${name}.sh"
		run tools <<<$'all\ny'
		[ "$status" -ne 0 ]
		[[ "$output" == *"nonexecutable installer: ${name}.sh"* ]]
		[[ "$output" != *"Suggested tools:"* ]]
		[ -z "$(ls -A "${INSTALL}/03-enabled")" ]
		chmod 0755 "${INSTALL}/available/${name}.sh"
	done
}

@test "tool selection deduplicates numbers and enables dependencies without installers" {
	tool_catalog
	run tools <<<$'1,1\ny'
	[ "$status" -eq 0 ]
	for name in 1000-runtime-base 1010-tool-middle 1020-tool-leaf; do
		[ -L "${INSTALL}/03-enabled/${name}.sh" ]
	done
	[ ! -L "${INSTALL}/03-enabled/1030-tool-companion.sh" ]
	[[ "$output" == *"future builds"* ]]
}

@test "invalid entire tool selections none cancellation and EOF never change links" {
	tool_catalog
	for answer in '' '0' '3' '1,x' '1,99999999' 'none' $'all\nn' '1'; do
		run tools <<<"$answer"
		[ -z "$(ls -A "${INSTALL}/03-enabled")" ]
	done
	run tools </dev/null
	[ "$status" -ne 0 ]
	[ -z "$(ls -A "${INSTALL}/03-enabled")" ]
}

@test "invalid tools catalog is rejected before selection" {
	for catalog in '{"version":2,"tools":[]}' '{"version":true,"tools":[]}' \
		'{"version":1,"tools":["missing-tool.sh"]}' \
		'{"version":1,"tools":["1020-tool-leaf.sh","1020-tool-leaf.sh"]}' \
		'{"version":1,"tools":["../1020-tool-leaf.sh"]}' \
		'{"version":1,"tools":[],"extra":1}'; do
		printf '%s\n' "$catalog" >"${INSTALL}/recommended-tools.json"
		run tools <<<$'all\ny'
		[ "$status" -ne 0 ]
		[ -z "$(ls -A "${INSTALL}/03-enabled")" ]
	done
}

@test "tools catalog refuses mandatory targets and unsafe aliases" {
	core_base
	printf '{"version":1,"tools":["1000-runtime-base.sh"]}\n' >"${INSTALL}/recommended-tools.json"
	run tools <<<$'all\ny'
	[ "$status" -ne 0 ]
	[[ "$output" == *mandatory* ]]
	tool_catalog
	ln -s /missing "${INSTALL}/03-enabled/99-unsafe.sh"
	run tools <<<$'all\ny'
	[ "$status" -ne 0 ]
	[ ! -L "${INSTALL}/03-enabled/1020-tool-leaf.sh" ]
}

@test "all tools retain custom aliases and repeat idempotently" {
	tool_catalog
	ln -s ../available/1020-tool-leaf.sh "${INSTALL}/03-enabled/99-custom.sh"
	for _ in 1 2; do
		run tools <<<$'all\ny'
		[ "$status" -eq 0 ]
		[ -L "${INSTALL}/03-enabled/99-custom.sh" ]
		[ ! -L "${INSTALL}/03-enabled/1020-tool-leaf.sh" ]
		[ -L "${INSTALL}/03-enabled/1030-tool-companion.sh" ]
	done
}

@test "empty recommendation catalog is a successful no-op" {
	printf '{"version":1,"tools":[]}\n' >"${INSTALL}/recommended-tools.json"
	run tools </dev/null
	[ "$status" -eq 0 ]
	[[ "$output" == *"No suggested tools available"* ]]
	[ -z "$(ls -A "${INSTALL}/03-enabled")" ]
}

@test "recommendation file symlinks fail closed" {
	tool_catalog
	mv "${INSTALL}/recommended-tools.json" "${FIXTURE}/catalog.json"
	ln -s "${FIXTURE}/catalog.json" "${INSTALL}/recommended-tools.json"
	run tools <<<$'all\ny'
	[ "$status" -ne 0 ]
	[[ "$output" == *unsafe* ]]
	[ -z "$(ls -A "${INSTALL}/03-enabled")" ]
}

@test "missing mandatory core fails before optional activation" {
	tool_catalog
	printf 'FROM foundation AS core-tools\nCOPY install/available/1000-runtime-base.sh /install/available/\nFROM core-tools AS devcontainer\n' >"${FIXTURE}/.devcontainer/Dockerfile"
	run tools <<<$'all\ny'
	[ "$status" -ne 0 ]
	[[ "$output" == *core* ]]
	[ -z "$(ls -A "${INSTALL}/03-enabled")" ]
}

@test "recommendations retain the exact owner order independently of publication defaults" {
	run python3 - "${REPO_ROOT}" <<'PY'
import json
from pathlib import Path
import sys
root = Path(sys.argv[1])
document = json.loads((root / '.devcontainer/install/recommended-tools.json').read_text())
assert document == {'version': 1, 'tools': [
    '2060-node-test.sh', '2050-node-mermaid.sh', '2040-node-contracts.sh',
    '2110-go-debug.sh', '2210-cli-plantuml.sh', '2220-cli-c4-plantuml.sh',
    '6020-cli-opentofu.sh', '5020-cli-graphviz.sh', '5010-cli-gitleaks.sh',
    '2100-runtime-go.sh', '2400-python-graphify.sh', '2200-runtime-java.sh',
    '4100-tool-pulseaudio-utils.sh', '4000-tool-ssh-client.sh', '5000-cli-glow.sh']}
PY
	[ "$status" -eq 0 ]
}

@test "new tool Task rejects shell payloads without execution" {
	local payload
	printf -v payload '%s(touch %s)' '$' "${FIXTURE}/injected"
	run task --taskfile "${REPO_ROOT}/Taskfile.yml" suggest:tools -- "$payload"
	[ "$status" -ne 0 ]
	[[ "$output" == *"Task arguments are not accepted"* ]]
	[ ! -e "${FIXTURE}/injected" ]
}
