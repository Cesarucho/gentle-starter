#!/usr/bin/env bats

load install-fixture

prepare_all() {
	mkdir -p "${FIXTURE}/.devcontainer/skills" "${FIXTURE}/bin"
	printf '{"version":1,"tools":["1020-tool-leaf.sh"]}\n' >"${INSTALL}/recommended-tools.json"
	printf '{"version":1,"skills":{"alpha":{"source":"example/one","skillPath":"alpha/SKILL.md"},"beta":{"source":"example/two","skillPath":"beta/SKILL.md"}}}\n' >"${FIXTURE}/.devcontainer/skills/recommended.json"
	export CALLS="${FIXTURE}/calls" FAIL_NAME=''
	cat >"${FIXTURE}/bin/skills" <<'EOF'
#!/usr/bin/env bash
[[ -L .devcontainer/install/03-enabled/1020-tool-leaf.sh ]] || exit 90
printf '%s\n' "$*" >>"$CALLS"
[[ "$*" != *"--skill ${FAIL_NAME} --agent"* || -z "$FAIL_NAME" ]]
EOF
	chmod +x "${FIXTURE}/bin/skills"
	export PATH="${FIXTURE}/bin:${PATH}"
}

combined() { (cd "${FIXTURE}" && bash "${REPO_ROOT}/.taskfiles/scripts/suggest.sh" all); }

@test "combined nonexecutable root or dependency prevents menus and Skills calls" {
	prepare_all
	for name in 1020-tool-leaf 1010-tool-middle; do
		chmod 0644 "${INSTALL}/available/${name}.sh"
		run combined <<<$'all\nall\ny'
		[ "$status" -eq 1 ]
		[[ "$output" == *"nonexecutable installer: ${name}.sh"* ]]
		[[ "$output" != *"Suggested skills:"* ]]
		[ ! -e "$CALLS" ]
		[ -z "$(ls -A "${INSTALL}/03-enabled")" ]
		chmod 0755 "${INSTALL}/available/${name}.sh"
	done
}

@test "combined rechecks executable modes after confirmation before first link or Skills call" {
	prepare_all
	run python3 - "${FIXTURE}" "${REPO_ROOT}/.taskfiles/scripts/suggest.sh" <<'PY'
from pathlib import Path
import subprocess
import sys
fixture, script = Path(sys.argv[1]), sys.argv[2]
for name in ('1020-tool-leaf.sh', '1010-tool-middle.sh'):
    process = subprocess.Popen(['bash', script, 'all'], cwd=fixture, stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    target = fixture / '.devcontainer/install/available' / name
    try:
        process.stdin.write('all\nall\n')
        process.stdin.flush()
        while True:
            line = process.stdout.readline()
            assert line, 'selector exited before confirmation'
            if line.startswith('Selected tools:'):
                break
        target.chmod(0o644)
        out, err = process.communicate('y\n', timeout=5)
        assert process.returncode == 1, (out, err)
        assert f'nonexecutable installer: {name}' in err
        assert 'Tool stage failed; Skills stage not started' in err
        assert not (fixture / 'calls').exists()
        assert not list((fixture / '.devcontainer/install/03-enabled').iterdir())
    finally:
        target.chmod(0o755)
        if process.poll() is None:
            process.kill()
            process.wait()
PY
	[ "$status" -eq 0 ]
}

@test "combined uses one confirmation and tools precede skills" {
	prepare_all
	run combined <<<$'all\nall\ny'
	[ "$status" -eq 0 ]
	[ "$(wc -l <"$CALLS")" -eq 2 ]
	[[ "$output" == *"Tool stage complete"* ]]
	[[ "$output" == *"Installed: alpha beta"* ]]
}

@test "combined validates both catalogs and selections before side effects" {
	prepare_all
	for answer in $'all\ninvalid\ny' $'invalid\nall\ny' $'all\nall\nn' $'none\nnone' $'all\nall'; do
		run combined <<<"$answer"
		[ ! -e "$CALLS" ]
		[ -z "$(ls -A "${INSTALL}/03-enabled")" ]
	done
	printf '{"version":2,"tools":[]}\n' >"${INSTALL}/recommended-tools.json"
	run combined <<<$'all\nall\ny'
	[ "$status" -ne 0 ]
	[ ! -e "$CALLS" ]
	[[ "$output" != *"1. alpha"* ]]
}

@test "combined skills failure retains activated tools and continues installs" {
	prepare_all
	export FAIL_NAME=alpha
	run combined <<<$'all\nall\ny'
	[ "$status" -eq 1 ]
	[ "$(wc -l <"$CALLS")" -eq 2 ]
	[ -L "${INSTALL}/03-enabled/1020-tool-leaf.sh" ]
	[[ "$output" == *"install failed for: alpha"* ]]
	[[ "$output" == *"Tool stage remains applied"* ]]
}

@test "combined validates unavailable skills before displaying the tools menu" {
	prepare_all
	mv "${FIXTURE}/.devcontainer/skills/recommended.json" "${FIXTURE}/unavailable.json"
	run combined <<<$'all\nall\ny'
	[ "$status" -ne 0 ]
	[[ "$output" == *"published catalog unavailable"* ]]
	[[ "$output" != *"Suggested tools"* ]]
	[ ! -e "$CALLS" ]
	[ -z "$(ls -A "${INSTALL}/03-enabled")" ]
}

@test "combined apply revalidates roots and does not start skills after tool failure" {
	prepare_all
	run python3 - "${FIXTURE}" "${REPO_ROOT}/.taskfiles/scripts/suggest.sh" <<'PY'
import os
from pathlib import Path
import subprocess
import sys
fixture, script = Path(sys.argv[1]), sys.argv[2]
process = subprocess.Popen(['bash', script, 'all'], cwd=fixture, stdin=subprocess.PIPE,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
try:
    process.stdin.write('all\nall\n')
    process.stdin.flush()
    while True:
        line = process.stdout.readline()
        assert line, 'selector exited before confirmation'
        if line.startswith('Selected tools:'):
            break
    target = fixture / '.devcontainer/install/available/1020-tool-leaf.sh'
    target.rename(fixture / 'moved-installer.sh')
    target.symlink_to(fixture / 'moved-installer.sh')
    out, err = process.communicate('y\n', timeout=5)
    assert process.returncode == 1, (out, err)
    assert 'Tool stage failed; Skills stage not started' in err
    assert not (fixture / 'calls').exists()
    assert not list((fixture / '.devcontainer/install/03-enabled').iterdir())
finally:
    if process.poll() is None:
        process.kill()
        process.wait()
PY
	[ "$status" -eq 0 ]
}

@test "combined confirmation snapshot ignores changed skill sources and recommendation indices" {
	prepare_all
	run python3 - "${FIXTURE}" "${REPO_ROOT}/.taskfiles/scripts/suggest.sh" <<'PY'
import json
from pathlib import Path
import subprocess
import sys
fixture, script = Path(sys.argv[1]), sys.argv[2]
process = subprocess.Popen(['bash', script, 'all'], cwd=fixture, stdin=subprocess.PIPE,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
try:
    process.stdin.write('1\n1\n')
    process.stdin.flush()
    while True:
        line = process.stdout.readline()
        assert line, 'selector exited before confirmation'
        if line.startswith('Selected tools:'):
            break
    (fixture / '.devcontainer/skills/recommended.json').write_text(json.dumps({
        'version': 1, 'skills': {'alpha': {'source': 'changed/repo', 'skillPath': 'other'}}}))
    (fixture / '.devcontainer/install/recommended-tools.json').write_text(json.dumps({
        'version': 1, 'tools': ['1030-tool-companion.sh']}))
    out, err = process.communicate('y\n', timeout=5)
    assert process.returncode == 0, (out, err)
    assert (fixture / 'calls').read_text() == 'add example/one --skill alpha --agent universal --copy -y\n'
    assert (fixture / '.devcontainer/install/03-enabled/1020-tool-leaf.sh').is_symlink()
    assert not (fixture / '.devcontainer/install/03-enabled/1030-tool-companion.sh').is_symlink()
finally:
    if process.poll() is None:
        process.kill()
        process.wait()
PY
	[ "$status" -eq 0 ]
}

@test "combined Task rejects shell payloads without execution" {
	local payload
	printf -v payload '%s(touch %s)' '$' "${FIXTURE}/injected"
	run task --taskfile "${REPO_ROOT}/Taskfile.yml" suggest:all -- "$payload"
	[ "$status" -ne 0 ]
	[[ "$output" == *"Task arguments are not accepted"* ]]
	[ ! -e "${FIXTURE}/injected" ]
}
