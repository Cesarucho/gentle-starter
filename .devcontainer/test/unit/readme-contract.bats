#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"

@test "README documents the safe IDE startup and current product link" {
	run grep -F 'https://github.com/Gentleman-Programming/gentle-ai' "${REPO_ROOT}/README.md"
	[ "${status}" -eq 0 ]
	run grep -F 'an IDE may only attach after `task container:up`' "${REPO_ROOT}/README.md"
	[ "${status}" -eq 0 ]
}

@test "README repository tree lists current lifecycle surfaces without runtime state" {
	tree="$(awk '/^## 🗂️ Repository structure/{capture=1} capture && /^## 💾/{exit} capture' "${REPO_ROOT}/README.md")"
	[[ "${tree}" == *"AGENTS.md.TEMPLATE"* ]]
	[[ "${tree}" == *"lifecycle/"* ]]
	[[ "${tree}" == *"tool-versions.conf"* ]]
	[[ "${tree}" != *"openspec/"* ]]
	[[ "${tree}" != *".env.d/"* ]]
}

section_count() {
	grep -cF "$1" "${REPO_ROOT}/README.md"
}

section_between() {
	local start="$1"
	local end="$2"
	awk -v start="${start}" -v end="${end}" '
		$0 == start { capture=1; next }
		capture && $0 == end { exit }
		capture { print }
	' "${REPO_ROOT}/README.md"
}

blockquote_line_count() {
	awk '/^[[:space:]]*>[[:space:]]/ { count++ } END { print count + 0 }'
}

first_prose_after_blockquote_line_count() {
	awk '
		/^[[:space:]]*>[[:space:]]/ { quote=1; next }
		quote && /^[[:space:]]*$/ { after_quote=1; quote=0; next }
		after_quote && !/^[[:space:]]*$/ { started=1; count++ }
		started && /^[[:space:]]*$/ { print count; emitted=1; exit }
		END { if (started && !emitted) print count }
	'
}

first_prose_after_fence_line_count() {
	awk '
		/^[[:space:]]*```/ { fences++; next }
		fences >= 2 && !/^[[:space:]]*$/ { started=1; count++ }
		started && /^[[:space:]]*$/ { print count; emitted=1; exit }
		END { if (started && !emitted) print count }
	'
}

@test "README What's included has one collapsible additional-tool catalog" {
	local included
	included="$(section_between "## 📦 What's included?" '## ✅ Requirements')"
	[ "$(printf '%s\n' "${included}" | grep -c '^<details>$')" -eq 1 ]
	[ "$(printf '%s\n' "${included}" | grep -c '^</details>$')" -eq 1 ]
	[ "$(printf '%s\n' "${included}" | grep -c '^<summary>.*</summary>$')" -eq 1 ]
	[[ "${included}" != *'Separate scripts to install and configure Ubuntu dependencies.'* ]]
	[[ "${included}" == *'Run `task install:list` for the current catalog and activation state.'* ]]
}

@test "README activation examples reference current catalog installers" {
	run python3 - "${REPO_ROOT}" <<'PY'
import re
import sys
from pathlib import Path
root = Path(sys.argv[1])
names = re.findall(r"task install:(?:enable|disable) -- ([a-z0-9-]+)", (root / "README.md").read_text())
assert names
for name in names:
    assert (root / ".devcontainer/install/available" / (name + ".sh")).is_file(), name
PY
	[ "${status}" -eq 0 ]
}

@test "README keeps maintenance commands in one section without legacy presets" {
	[ "$(section_count '### Diagnostics and validation')" -eq 1 ]
	[ "$(section_count '### ✅ Validate after maintenance')" -eq 0 ]
	[ "$(section_count '### Dependency policy')" -eq 0 ]
	[ "$(grep -c '^task deps:update' "${REPO_ROOT}/README.md")" -eq 1 ]
	[ "$(grep -c '^task install:list$' "${REPO_ROOT}/README.md")" -eq 1 ]
	run grep -F 'task install:list -- --presets' "${REPO_ROOT}/README.md"
	[ "${status}" -eq 1 ]
}

@test "README concise startup callouts stay within source-line budgets" {
	local fast_path build_path deps_update
	local project_lines container_lines ide_lines deps_lines
	fast_path="$(section_between '### Fast path: start a new project from this base' '### Build and enter the environment')"
	build_path="$(section_between '### Build and enter the environment' '## 🔄 Maintain your project')"
	deps_update="$(section_between '### 📦 Update development tools' '## 🛠️ Useful commands')"
	project_lines="$(printf '%s\n' "${fast_path}" | blockquote_line_count)"
	container_lines="$(printf '%s\n' "${build_path}" | blockquote_line_count)"
	ide_lines="$(printf '%s\n' "${build_path}" | first_prose_after_blockquote_line_count)"
	deps_lines="$(printf '%s\n' "${deps_update}" | first_prose_after_fence_line_count)"
	[ "${project_lines}" -gt 0 ] && [ "${project_lines}" -le 3 ]
	[ "${container_lines}" -gt 0 ] && [ "${container_lines}" -le 3 ]
	[[ "${build_path}" == *'Do not use the IDE'* ]]
	[ "${deps_lines}" -gt 0 ] && [ "${deps_lines}" -le 3 ]
}
