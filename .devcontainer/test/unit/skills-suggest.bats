#!/usr/bin/env bats

setup() {
	ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEMP="$(mktemp -d)"
	export ROOT TEMP
	mkdir -p "${TEMP}/repo/.devcontainer/skills" "${TEMP}/bin"
	export CALLS="${TEMP}/calls" FAIL_NAME=''
	printf '{"version":1,"skills":{"alpha":{"source":"example/one","skillPath":"alpha/SKILL.md"},"beta":{"source":"example/two","skillPath":"beta/SKILL.md"}}}\n' >"${TEMP}/repo/.devcontainer/skills/recommended.json"
	cat >"${TEMP}/bin/skills" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALLS"
printf 'Attempted: %s\n' "$*"
[[ "$*" != *"--skill ${FAIL_NAME} --agent"* || -z "$FAIL_NAME" ]]
EOF
	chmod +x "${TEMP}/bin/skills"
	export PATH="${TEMP}/bin:${PATH}"
}

teardown() { rm -rf "${TEMP}"; }

suggest() { (cd "${TEMP}/repo" && bash "${ROOT}/.taskfiles/scripts/skills-suggest.sh" "$@"); }
export -f suggest

assert_manual_workaround() {
	local commands
	commands=$'skills add wondelai/skills/clean-code -a opencode -y\nskills add wondelai/skills/domain-driven-design -a opencode -y\nskills add https://github.com/upstash/context7/tree/master/plugins/agent-plugins/context7/skills/context7-mcp -a opencode -y'
	[[ "$output" == *"$commands"* ]]
	[[ "$output" == *"shown only, NOT executed"* ]]
	[[ "$output" == *"Temporary user-requested workaround (manual; the user monitors the patch)."* ]]
}

@test "missing published catalog reports unavailable, not dev lock suggestions" {
	rm "${TEMP}/repo/.devcontainer/skills/recommended.json"
	printf '{"version":1,"skills":{}}\n' >"${TEMP}/repo/skills-lock.json"
	run suggest alpha
	[ "$status" -ne 0 ]
	[[ "$output" == *"published catalog unavailable"* ]]
	[[ "$output" != *"skills add "* ]]
	[ ! -e "$CALLS" ]
}

@test "invalid catalog and unknown or duplicate names never install" {
	run suggest alpha missing
	[ "$status" -ne 0 ]
	[[ "$output" != *"skills add "* ]]
	run suggest alpha alpha
	[ "$status" -ne 0 ]
	[[ "$output" != *"skills add "* ]]
	printf '{"version":2,"skills":{}}\n' >"${TEMP}/repo/.devcontainer/skills/recommended.json"
	run suggest alpha
	[ "$status" -ne 0 ]
	[[ "$output" != *"skills add "* ]]
	[ ! -e "$CALLS" ]
}

@test "empty, invalid, none and cancelled choices do not install" {
	for answer in '' '0' '3' '1,broken' 'none' $'1\nn'; do
		run bash -c 'printf "%s\n" "$1" | suggest' -- "$answer"
		[ ! -e "$CALLS" ]
		[[ "$output" != *"skills add "* ]]
	done
}

@test "number selection installs only chosen entries after one confirmation" {
	run bash -c 'printf "2,2\ny\n" | suggest'
	[ "$status" -eq 0 ]
	[ "$(wc -l <"$CALLS")" -eq 1 ]
	[ "$(<"$CALLS")" = 'add example/two --skill beta --agent universal --copy -y' ]
	assert_manual_workaround
	[[ "$output" == *$'Installed: beta\n\nTemporary user-requested workaround'* ]]
}

@test "all selection and explicit batch names install selected entries" {
	run bash -c 'printf "all\ny\n" | suggest'
	[ "$status" -eq 0 ]
	[ "$(wc -l <"$CALLS")" -eq 2 ]
	assert_manual_workaround
	: >"$CALLS"
	run bash -c 'printf "y\n" | suggest beta alpha'
	[ "$status" -eq 0 ]
	[ "$(wc -l <"$CALLS")" -eq 2 ]
	[ "$(
		read -r first <"$CALLS"
		printf '%s' "$first"
	)" = 'add example/two --skill beta --agent universal --copy -y' ]
	[ "$(<"$CALLS")" = $'add example/two --skill beta --agent universal --copy -y\nadd example/one --skill alpha --agent universal --copy -y' ]
	assert_manual_workaround
}

@test "partial failure reports failed names and continues selected installs" {
	export FAIL_NAME=alpha
	run bash -c 'printf "y\n" | suggest alpha beta'
	[ "$status" -eq 1 ]
	[[ "$output" == *"install failed for: alpha"* ]]
	[ "$(wc -l <"$CALLS")" -eq 2 ]
	[ "$(<"$CALLS")" = $'add example/one --skill alpha --agent universal --copy -y\nadd example/two --skill beta --agent universal --copy -y' ]
	assert_manual_workaround
	[[ "$output" == *$'Attempted: add example/two --skill beta --agent universal --copy -y\n'*'install failed for: alpha'*$'\n\nTemporary user-requested workaround'* ]]
}

@test "failed sole install still displays manual commands without masking failure" {
	export FAIL_NAME=beta
	run bash -c 'printf "y\n" | suggest beta'
	[ "$status" -eq 1 ]
	[ "$(<"$CALLS")" = 'add example/two --skill beta --agent universal --copy -y' ]
	[[ "$output" != *"Installed:"* ]]
	assert_manual_workaround
}

@test "empty catalog and selection or confirmation EOF show no workaround" {
	run bash -c 'suggest </dev/null'
	[ "$status" -eq 1 ]
	[[ "$output" != *"skills add "* ]]
	run bash -c 'suggest alpha </dev/null'
	[ "$status" -eq 0 ]
	[[ "$output" != *"skills add "* ]]
	printf '{"version":1,"skills":{}}\n' >"${TEMP}/repo/.devcontainer/skills/recommended.json"
	run suggest
	[ "$status" -eq 0 ]
	[[ "$output" == *"No suggested skills available."* ]]
	[[ "$output" != *"skills add "* ]]
	[ ! -e "$CALLS" ]
}

@test "Task rejects metacharacter arguments without executing them" {
	local payload
	printf -v payload '%s(touch %s)' '$' "${TEMP}/injected"
	run task --taskfile "${ROOT}/Taskfile.yml" skills:suggest -- "$payload"
	[ "$status" -ne 0 ]
	[[ "$output" == *"Task arguments are not accepted"* ]]
	[ ! -e "${TEMP}/injected" ]
	[ ! -e "$CALLS" ]
}

@test "direct batch metacharacter name is rejected without execution" {
	local payload
	printf -v payload '%s(touch %s)' '$' "${TEMP}/injected"
	run suggest "$payload"
	[ "$status" -ne 0 ]
	[ ! -e "${TEMP}/injected" ]
	[ ! -e "$CALLS" ]
}
