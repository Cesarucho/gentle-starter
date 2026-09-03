#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"

@test "README documents the safe IDE startup and current product link" {
	run grep -F 'https://github.com/Gentleman-Programming/gentle-ai' "${REPO_ROOT}/README.md"
	[ "${status}" -eq 0 ]
	run grep -F 'first run `task container:up`' "${REPO_ROOT}/README.md"
	[ "${status}" -eq 0 ]
}

@test "README repository tree lists current lifecycle surfaces without runtime state" {
	tree="$(awk '/^## 🗂️ Repository structure/{capture=1} capture && /^## 💾/{exit} capture' "${REPO_ROOT}/README.md")"
	[[ "${tree}" == *"AGENTS.md.TEMPLATE"* ]]
	[[ "${tree}" == *"setup-volumes.sh"* ]]
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

readme_install_placement_inventory() {
	cat <<'EOF'
10-bats.sh|details
20-runtime-go.sh|primary
20-runtime-java.sh|primary
20-runtime-node.sh|details
20-runtime-pnpm.sh|primary
20-tool-devcontainer-cli.sh|primary
20-tool-ssh.sh|details
30-ai-engram.sh|primary
30-ai-gentle-ai.sh|primary
30-ai-opencode.sh|primary
30-ai-pi-coding.sh|primary
30-ai-pi-gentle.sh|details
30-ai-skills.sh|primary
40-cli-ansible.sh|details
40-cli-c4-plantuml.sh|details
40-cli-gitleaks.sh|details
40-cli-glow.sh|details
40-cli-graphviz.sh|details
40-cli-kubectl.sh|details
40-cli-opentofu.sh|details
40-cli-plantuml.sh|details
40-cli-pulumi.sh|details
40-cli-terraform.sh|details
40-cli-terragrunt.sh|details
40-go-debug.sh|details
40-node-contracts.sh|details
40-node-markdownlint.sh|details
40-node-mermaid.sh|details
40-node-test.sh|details
40-php-debug.sh|details
40-php-lang.sh|details
40-php-test.sh|details
40-python-graphify.sh|details
50-browser-playwright.sh|details
EOF
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

@test "README install placement inventory uniquely covers every available installer" {
	local inventory inventory_names available_names
	inventory="$(readme_install_placement_inventory)"

	[ "$(printf '%s\n' "${inventory}" | cut -d '|' -f 1 | sort | uniq -d | wc -l)" -eq 0 ]
	[ "$(printf '%s\n' "${inventory}" | awk -F '|' 'NF != 2 || ($2 != "primary" && $2 != "details") { count++ } END { print count + 0 }')" -eq 0 ]

	inventory_names="$(printf '%s\n' "${inventory}" | cut -d '|' -f 1 | sort)"
	available_names="$(printf '%s\n' "${REPO_ROOT}"/.devcontainer/install/available/*.sh | xargs -n 1 basename | sort)"
	[ "${inventory_names}" = "${available_names}" ]
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
	[ "${ide_lines}" -gt 0 ] && [ "${ide_lines}" -le 2 ]
	[ "${deps_lines}" -gt 0 ] && [ "${deps_lines}" -le 3 ]
}
