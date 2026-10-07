#!/usr/bin/env bats
# Git revision braces are literal; Bats isolates tests and dispatches helpers
# through run, whose optional arguments are not visible to ShellCheck.
# shellcheck disable=SC1083,SC2030,SC2031,SC2119,SC2120

setup() {
  ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  TEMP="$(mktemp -d)"
  REPO="${TEMP}/repo"
  git init -q -b dev "${REPO}"
  git -C "${REPO}" config user.name "Distribution Test"
  git -C "${REPO}" config user.email "distribution@example.test"
  mkdir -p "${REPO}/.agents/skills/add-tool" "${REPO}/.agents/skills/external" \
    "${REPO}/.devcontainer/docs" "${REPO}/.devcontainer/test/unit" \
    "${REPO}/.github" "${REPO}/odd" "${REPO}/openspec" "${REPO}/docs" "${REPO}/.maintainer"
  printf 'license\n' > "${REPO}/LICENSE"
  printf 'template\n' > "${REPO}/AGENTS.md.TEMPLATE"
  chmod 640 "${REPO}/LICENSE" "${REPO}/AGENTS.md.TEMPLATE"
  printf 'v1\n' > "${REPO}/.devcontainer/docs/guide.md"
  printf 'shared\n' > "${REPO}/.devcontainer/test/unit/shared.bats"
  printf 'authored\n' > "${REPO}/.agents/skills/add-tool/SKILL.md"
  printf 'external\n' > "${REPO}/.agents/skills/external/SKILL.md"
  printf '%s\n' '{' '  "dockerComposeFile": [' \
    '    "./docker-compose.yml"' \
    '    , "./config/compose/docker-compose-core-tools.yml"' \
    '    , "./config/compose/docker-compose.pi.yml"' \
    '    , "./config/compose/docker-compose.gentle-shell.yml"' \
    '  ],' '  "service": "container-svc"' '}' > "${REPO}/.devcontainer/devcontainer.json"
  printf '{"version":1,"skills":{"external":{"source":"example/repo","skillPath":"skills/external/SKILL.md","computedHash":"dev-only"}}}\n' > "${REPO}/skills-lock.json"
  for path in README.md AGENTS.md AGENTS.md.TEMPLATE.EXAMPLE CHANGELOG.md \
    .github/workflow odd/task openspec/spec docs/guide .maintainer/tool; do
    printf 'maintainer\n' > "${REPO}/${path}"
  done
  mkdir -p "${REPO}/.devcontainer/install/available" "${REPO}/.devcontainer/install/03-enabled" \
    "${REPO}/.devcontainer/install/01-foundation"
  cp -a "${ROOT}/.devcontainer/install/02-core-tools" "${REPO}/.devcontainer/install/"
  cp -a "${ROOT}/.devcontainer/install/03-enabled/." "${REPO}/.devcontainer/install/03-enabled/"
  cp "${ROOT}/.devcontainer/install/dependencies.conf" "${REPO}/.devcontainer/install/dependencies.conf"
  cp "${ROOT}/.devcontainer/Dockerfile" "${REPO}/.devcontainer/Dockerfile"
  local installer
  for installer in "${ROOT}"/.devcontainer/install/available/*.sh; do
    printf '#!/bin/sh\nexit 99\n' > "${REPO}/.devcontainer/install/available/${installer##*/}"
    chmod 755 "${REPO}/.devcontainer/install/available/${installer##*/}"
  done
  printf '#!/bin/sh\nexit 99\n' > "${REPO}/.devcontainer/install/01-foundation/10-system.sh"
  printf '%s\n' '["2080-browser-playwright.sh", "3030-ai-pi-coding.sh", "3040-ai-gentle-shell.sh", "3070-ai-gga.sh", "4000-tool-ssh-client.sh"]' \
    > "${REPO}/.maintainer/starter-tools.json"
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm initial
}

teardown() { rm -rf "${TEMP}"; }

prepare() {
  local current base source tree approved
  current="$(git -C "${REPO}" branch --show-current)"
  if [ "$current" = starter ]; then git -C "${REPO}" switch -q dev; fi
  if git -C "${REPO}" show-ref --verify --quiet refs/heads/starter; then
    base="$(git -C "${REPO}" rev-parse starter)"
    candidate
  else
    base=absent
    candidate --base-absent
  fi
  approved="$(git -C "${REPO}" rev-parse starter-rc)"
  tree="$(git -C "${REPO}" rev-parse starter-rc^{tree})"
  source="$(git -C "${REPO}" rev-parse dev)"
  promote
  candidate --cancel
  if [ "$current" = starter ]; then git -C "${REPO}" switch -q starter; fi
}

candidate() { (cd "${REPO}" && python3 "${ROOT}/.maintainer/scripts/starter-candidate.py" "$@"); }

promote() {
  (cd "${REPO}" && python3 "${ROOT}/.maintainer/scripts/starter-promote.py" \
    --approved-rc "${approved}" --expected-tree "${tree}" \
    --expected-base "${base}" --expected-source "${source}" "$@")
}

approval() {
  approved="$(git -C "${REPO}" rev-parse starter-rc)"
  tree="$(git -C "${REPO}" rev-parse starter-rc^{tree})"
  source="$(git -C "${REPO}" rev-parse dev)"
}

set_tools() {
  printf '%s\n' "$1" > "${REPO}/.maintainer/starter-tools.json"
  git -C "${REPO}" commit -qam 'Edit starter tool suggestions'
}

absent() {
  run "$@"
  [ "$status" -ne 0 ]
}

@test "tool catalog generates exactly five canonical symlinks without changing producer extras" {
  before="$(git -C "${REPO}" rev-parse dev:.devcontainer/install)"
  index="$(git -C "${REPO}" hash-object .git/index)"
  candidate --base-absent
  [ "$(git -C "${REPO}" ls-tree starter-rc:.devcontainer/install/03-enabled | wc -l)" -eq 5 ]
  for name in 2080-browser-playwright.sh 3030-ai-pi-coding.sh 3040-ai-gentle-shell.sh \
    3070-ai-gga.sh 4000-tool-ssh-client.sh; do
    [ "$(git -C "${REPO}" ls-tree starter-rc:.devcontainer/install/03-enabled "$name" | cut -d' ' -f1)" = 120000 ]
    [ "$(git -C "${REPO}" cat-file -s "starter-rc:.devcontainer/install/03-enabled/${name}")" -eq "$((${#name} + 13))" ]
    [ "$(git -C "${REPO}" show "starter-rc:.devcontainer/install/03-enabled/${name}")" = "../available/${name}" ]
  done
  [ "$(git -C "${REPO}" rev-parse dev:.devcontainer/install)" = "$before" ]
  [ "$(git -C "${REPO}" hash-object .git/index)" = "$index" ]
  [ -z "$(git -C "${REPO}" status --porcelain)" ]
  [ "$(git -C "${REPO}" rev-parse starter-rc:.devcontainer/install/02-core-tools)" = \
    "$(git -C "${REPO}" rev-parse dev:.devcontainer/install/02-core-tools)" ]
  [[ "$(git -C "${REPO}" show -s --format=%B starter-rc)" == *"Starter-Tools-Normalization: 1"* ]]
}

@test "tool catalog allows addition removal replacement and empty selection" {
  for list in '["5000-cli-glow.sh"]' '["5000-cli-glow.sh","4000-tool-ssh-client.sh"]' \
    '["2080-browser-playwright.sh","3030-ai-pi-coding.sh","3040-ai-gentle-shell.sh","3070-ai-gga.sh"]' \
    '["4100-tool-pulseaudio-utils.sh"]' '[]'; do
    set_tools "$list"
    candidate --base-absent
    run python3 - "${REPO}" "$list" << 'PY'
import json
import subprocess
import sys
paths = subprocess.check_output(['git', '-C', sys.argv[1], 'ls-tree', '-r', '--name-only',
                                 'starter-rc', '--', '.devcontainer/install/03-enabled']).decode().splitlines()
assert paths == ['.devcontainer/install/03-enabled/' + name for name in sorted(json.loads(sys.argv[2]))]
PY
    [ "$status" -eq 0 ]
  done
}

@test "tool catalog rejects schema unsafe names missing nonexecutable symlink and core targets atomically" {
  candidate --base-absent
  prior="$(git -C "${REPO}" rev-parse starter-rc)"
  for list in '{}' '[1]' '["4000-tool-ssh-client.sh","4000-tool-ssh-client.sh"]' \
    '["../4000-tool-ssh-client.sh"]' '["9999-tool-missing.sh"]' '["2000-runtime-node.sh"]'; do
    set_tools "$list"
    run candidate --base-absent
    [ "$status" -ne 0 ]
    [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$prior" ]
    [ -z "$(git -C "${REPO}" status --porcelain)" ]
  done
  set_tools '["5000-cli-glow.sh"]'
  chmod 644 "${REPO}/.devcontainer/install/available/5000-cli-glow.sh"
  git -C "${REPO}" commit -qam 'Make selected target nonexecutable'
  run candidate --base-absent
  [ "$status" -ne 0 ]
  ln -s ../available/5000-cli-glow.sh "${REPO}/.devcontainer/install/available/9999-tool-link.sh"
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm 'Add symlink installer'
  set_tools '["9999-tool-link.sh"]'
  run candidate --base-absent
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$prior" ]
  chmod 755 "${REPO}/.maintainer/starter-tools.json"
  git -C "${REPO}" commit -qam 'Make tool list executable'
  run candidate --base-absent
  [ "$status" -ne 0 ]
  [[ "$output" == *"committed regular 100644"* ]]
  mv "${REPO}/.maintainer/starter-tools.json" "${TEMP}/executable-list"
  ln -s ../skills-lock.json "${REPO}/.maintainer/starter-tools.json"
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm 'Replace tool list with symlink'
  run candidate --base-absent
  [ "$status" -ne 0 ]
  [[ "$output" == *"committed regular 100644"* ]]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$prior" ]
}

@test "tool catalog validates dependencies cycle order and core authority without completing selection" {
  set_tools '["3040-ai-gentle-shell.sh"]'
  run candidate --base-absent
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires enabled installer"* ]]
  set_tools '["3030-ai-pi-coding.sh","3040-ai-gentle-shell.sh"]'
  candidate --base-absent
  prior="$(git -C "${REPO}" rev-parse starter-rc)"
  printf '3030-ai-pi-coding.sh|enabled|3040-ai-gentle-shell.sh|shell\n' >> "${REPO}/.devcontainer/install/dependencies.conf"
  git -C "${REPO}" commit -qam 'Introduce dependency cycle'
  run candidate --base-absent
  [ "$status" -ne 0 ]
  [[ "$output" == *"dependency cycle"* ]]
  printf '3030-ai-pi-coding.sh|enabled|4000-tool-ssh-client.sh|ssh\n' > "${REPO}/.devcontainer/install/dependencies.conf"
  set_tools '["3030-ai-pi-coding.sh","4000-tool-ssh-client.sh"]'
  run candidate --base-absent
  [ "$status" -ne 0 ]
  [[ "$output" == *"must run before"* ]]
  printf 'FROM base AS core-tools\n' > "${REPO}/.devcontainer/Dockerfile"
  git -C "${REPO}" commit -qam 'Break core COPY authority'
  run candidate --base-absent
  [ "$status" -ne 0 ]
  [[ "$output" == *"core aliases"* ]]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$prior" ]
}

@test "tool catalog source pinning preserves approved selection after current list replacement" {
  candidate --base-absent
  approval
  base=absent
  set_tools '[]'
  mv "${REPO}/.devcontainer/install/available/4000-tool-ssh-client.sh" "${TEMP}/removed-installer"
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm 'Remove now unselected installer'
  promote
  [ "$(git -C "${REPO}" rev-parse starter^{tree})" = "$tree" ]
  candidate --cancel
  candidate
  approval
  base="$(git -C "${REPO}" rev-parse starter)"
  promote
  [ -z "$(git -C "${REPO}" ls-tree -r --name-only starter -- .devcontainer/install/03-enabled)" ]
  candidate --cancel
}

@test "tool catalog dirty list is ignored by source transform and rejected by clean CLI guard" {
  candidate --base-absent
  prior="$(git -C "${REPO}" rev-parse starter-rc)"
  tree="$(git -C "${REPO}" rev-parse starter-rc^{tree})"
  printf '{}\n' > "${REPO}/.maintainer/starter-tools.json"
  run candidate --base-absent
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be clean"* ]]
  run python3 - "${ROOT}" "${REPO}" "$tree" << 'PY'
import importlib.util
import os
import sys
spec = importlib.util.spec_from_file_location('source', sys.argv[1] + '/.maintainer/scripts/starter-source.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
os.chdir(sys.argv[2])
assert module.filtered_tree(module.git('rev-parse', 'dev')) == sys.argv[3]
PY
  [ "$status" -eq 0 ]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$prior" ]
}

# Independent oracle for the actual pre-normalization producer filter. It does
# not call the implementation's filtered_tree or consult any tool list.
historical_tree() {
  (
    cd "${REPO}" && python3 - "$1" "${TEMP}/historical-index" << 'PY'
import json
import os
import subprocess
import sys
env = dict(os.environ, GIT_INDEX_FILE=sys.argv[2])
def git(*args, data=None):
    return subprocess.check_output(['git', *args], input=data, env=env)
git('read-tree', 'dev')
excluded = ['README.md', 'AGENTS.md', 'AGENTS.md.TEMPLATE', 'AGENTS.md.TEMPLATE.EXAMPLE',
            'CHANGELOG.md', 'docs', '.github', 'odd', 'openspec', '.maintainer',
            'skills-lock.json', '.agents/skills/external']
paths = git('ls-files', '-z', '--', *excluded)
git('update-index', '--force-remove', '-z', '--stdin', data=paths)
skills = {'version': 1, 'skills': {'external': {'source': 'example/repo', 'skillPath': 'skills/external/SKILL.md'}}}
blob = git('hash-object', '-w', '--stdin', data=(json.dumps(skills, indent=2) + '\n').encode()).decode().strip()
git('update-index', '--add', '--cacheinfo', '100644', blob, '.devcontainer/skills/recommended.json')
if sys.argv[1] == 'legacy':
    compose = git('show', 'dev:.devcontainer/devcontainer.json').decode()
    compose = compose.replace('    , "./config/compose/docker-compose.pi.yml"',
                              '    // , "./config/compose/docker-compose.pi.yml"')
    compose = compose.replace('    , "./config/compose/docker-compose.gentle-shell.yml"',
                              '    // , "./config/compose/docker-compose.gentle-shell.yml"')
    blob = git('hash-object', '-w', '--stdin', data=compose.encode()).decode().strip()
    git('update-index', '--add', '--cacheinfo', '100644', blob, '.devcontainer/devcontainer.json')
print(git('write-tree').decode().strip())
PY
  )
}

@test "tool catalog preserves real historical unmarked and Compose2 trees without a list" {
  mv "${REPO}/.maintainer/starter-tools.json" "${TEMP}/removed-list"
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm 'Historical source without starter list'
  source="$(git -C "${REPO}" rev-parse dev)"
  for policy in legacy current; do
    tree="$(historical_tree "$policy")"
    marker=''
    if [ "$policy" = current ]; then marker=$'\nStarter-Compose-Policy: 2'; fi
    old="$(git -C "${REPO}" commit-tree "$tree" -m 'Prepare starter release candidate' \
      -m "Starter-Candidate-Source: ${source}
Starter-Candidate-Base: 0000000000000000000000000000000000000000${marker}")"
    git -C "${REPO}" update-ref refs/heads/starter-rc "$old"
    approval
    base=absent
    run promote
    [ "$status" -ne 0 ]
    run candidate --base-absent
    [ "$status" -ne 0 ]
    [[ "$output" == *"committed regular 100644"* ]]
    [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$old" ]
    candidate --base-absent --cancel
    absent git -C "${REPO}" show-ref --verify -q refs/heads/starter-rc
  done
  run candidate --base-absent
  [ "$status" -ne 0 ]
}

@test "tool catalog upgrades same-source historical identity and validates historical release ancestry" {
  source="$(git -C "${REPO}" rev-parse dev)"
  old_tree="$(historical_tree current)"
  old="$(git -C "${REPO}" commit-tree "$old_tree" -m 'Prepare starter release candidate' \
    -m "Starter-Candidate-Source: ${source}
Starter-Candidate-Base: 0000000000000000000000000000000000000000
Starter-Compose-Policy: 2")"
  git -C "${REPO}" update-ref refs/heads/starter-rc "$old"
  candidate --base-absent
  [ "$(git -C "${REPO}" show -s --format=%P starter-rc)" = "$old" ]
  approval
  base=absent
  promote
  candidate --cancel
  historical_release="$(git -C "${REPO}" commit-tree "$old_tree" -m 'Publish consumer starter' \
    -m "Starter-Release-Source: ${source}
Starter-Compose-Policy: 2")"
  git -C "${REPO}" update-ref refs/heads/starter "$historical_release"
  candidate
  approval
  base="$historical_release"
  promote
  [ "$(git -C "${REPO}" show -s --format=%P starter)" = "$base" ]
  candidate --cancel
}

@test "tool catalog rejects unknown duplicate malformed and reordered normalization markers" {
  candidate --base-absent
  approval
  base=absent
  for markers in 'Starter-Tools-Normalization: 2' 'Starter-Tools-Normalization: 01' \
    'Starter-Tools-Normalization: ' $'Starter-Tools-Normalization: 1\nStarter-Tools-Normalization: 1' \
    $'Starter-Tools-Normalization: 1\nStarter-Compose-Policy: 2'; do
    forged="$(git -C "${REPO}" commit-tree "$tree" -m 'Prepare starter release candidate' \
      -m "Starter-Candidate-Source: ${source}
Starter-Candidate-Base: 0000000000000000000000000000000000000000
Starter-Compose-Policy: 2
${markers}")"
    git -C "${REPO}" update-ref refs/heads/starter-rc "$forged"
    run promote --approved-rc "$forged"
    [ "$status" -ne 0 ]
    run candidate --base-absent --cancel
    [ "$status" -ne 0 ]
    [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$forged" ]
    absent git -C "${REPO}" show-ref --verify -q refs/heads/starter
  done
}

@test "tool catalog validates actual historical release trees without consulting their invalid lists" {
  for policy in legacy current; do
    set_tools '{}'
    old_source="$(git -C "${REPO}" rev-parse dev)"
    old_tree="$(historical_tree "$policy")"
    marker=''
    if [ "$policy" = current ]; then marker=$'\nStarter-Compose-Policy: 2'; fi
    old_release="$(git -C "${REPO}" commit-tree "$old_tree" -m 'Publish consumer starter' \
      -m "Starter-Release-Source: ${old_source}${marker}")"
    git -C "${REPO}" update-ref refs/heads/starter "$old_release"
    set_tools '[]'
    candidate
    approval
    base="$old_release"
    promote
    [ "$(git -C "${REPO}" show -s --format=%P starter)" = "$old_release" ]
    candidate --cancel
  done
}

@test "tool catalog ref transaction failures leave index worktree and approved refs unchanged" {
  candidate --base-absent
  approval
  prior="$approved"
  base=absent
  set_tools '[]'
  index="$(git -C "${REPO}" hash-object .git/index)"
  touch "${REPO}/.git/refs/heads/starter-rc.lock"
  run candidate --base-absent
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$prior" ]
  touch "${REPO}/.git/refs/heads/starter.lock"
  run promote
  [ "$status" -ne 0 ]
  absent git -C "${REPO}" show-ref --verify -q refs/heads/starter
  [ "$(git -C "${REPO}" hash-object .git/index)" = "$index" ]
  [ -z "$(git -C "${REPO}" status --porcelain)" ]
}

@test "candidate comments active optional and future paths without changing committed or dirty producer bytes" {
  printf '%s\n' '{' '  "dockerComposeFile": [' \
    '    "./docker-compose.yml"' \
    '    , "./config/compose/docker-compose-core-tools.yml"' \
    '    , "./config/compose/docker-compose.pi.yml"' \
    '    , "./config/compose/docker-compose.gentle-shell.yml"' \
    '    , "./config/compose/docker-compose.audio.yml"' \
    '    , "./future/extra.yml"' \
    '  ],' '  // unrelated comment' '  "service": "container-svc"' '}' \
    > "${REPO}/.devcontainer/devcontainer.json"
  git -C "${REPO}" add .devcontainer/devcontainer.json
  git -C "${REPO}" commit -qm 'Add producer compose selections'
  original="$(git -C "${REPO}" hash-object .devcontainer/devcontainer.json)"
  candidate --base-absent
  approval
  base=absent
  [ "$(git -C "${REPO}" hash-object .devcontainer/devcontainer.json)" = "$original" ]
  [ "$(git -C "${REPO}" rev-parse dev:.devcontainer/devcontainer.json)" = "$original" ]
  git -C "${REPO}" show starter-rc:.devcontainer/devcontainer.json > "${TEMP}/published"
  [ "$(grep -c '^    // , ' "${TEMP}/published")" -eq 2 ]
  grep -q '"./future/extra.yml"' "${TEMP}/published"
  grep -q '^    , "./config/compose/docker-compose.pi.yml"$' "${TEMP}/published"
  grep -q '// unrelated comment' "${TEMP}/published"
  python3 - "${TEMP}/published" << 'PY'
import json
import pathlib
import sys
lines = pathlib.Path(sys.argv[1]).read_text().splitlines()
data = json.loads('\n'.join(line for line in lines if not line.lstrip().startswith('//')))
assert data['dockerComposeFile'] == ['./docker-compose.yml', './config/compose/docker-compose-core-tools.yml', './config/compose/docker-compose.pi.yml', './config/compose/docker-compose.gentle-shell.yml']
assert data['service'] == 'container-svc'
PY
  repeated="$(git -C "${REPO}" rev-parse starter-rc)"
  candidate --base-absent
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$repeated" ]
  promote
  [ "$(git -C "${REPO}" rev-parse starter:.devcontainer/devcontainer.json)" = \
    "$(git -C "${REPO}" rev-parse starter-rc:.devcontainer/devcontainer.json)" ]
  printf 'user edit\n' >> "${REPO}/.devcontainer/devcontainer.json"
  dirty="$(git -C "${REPO}" hash-object .devcontainer/devcontainer.json)"
  run candidate --base-absent
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" hash-object .devcontainer/devcontainer.json)" = "$dirty" ]
}

@test "candidate rejects malformed or ambiguous source compose JSONC before creating refs" {
  local input
  for input in \
    $'{\n  "dockerComposeFile": [\n    "./docker-compose.yml"\n    , "./future.yml"\n  ]\n}' \
    $'{\n  "dockerComposeFile": [\n    "./docker-compose.yml"\n    , "./docker-compose.yml"\n    , "./config/compose/docker-compose-core-tools.yml"\n    , "./config/compose/docker-compose.pi.yml"\n    , "./config/compose/docker-compose.gentle-shell.yml"\n  ]\n}' \
    $'{\n  "dockerComposeFile": [\n    "./docker-compose.yml"\n    , "./config/compose/docker-compose-core-tools.yml"\n    // , "./config/compose/docker-compose.pi.yml"\n    , "./config/compose/docker-compose.gentle-shell.yml"\n  ]\n}' \
    $'{\n  "dockerComposeFile": [\n    "./docker-compose.yml"\n    , "./config/compose/docker-compose-core-tools.yml"\n    , "./config/compose/docker-compose.pi.yml"\n    , "./config/compose/docker-compose.gentle-shell.yml"\n  ],\n  "dockerComposeFile": []\n}' \
    $'{\n  "dockerComposeFile": [\n    "./docker-compose.yml"\n    , "./config/compose/docker-compose-core-tools.yml"\n    , "./config/compose/docker-compose.pi.yml"\n    , "./config/compose/docker-compose.gentle-shell.yml"\n  ]\n} garbage'; do
    printf '%s\n' "$input" > "${REPO}/.devcontainer/devcontainer.json"
    git -C "${REPO}" commit -qam 'Set invalid source JSONC'
    run candidate --base-absent
    [ "$status" -ne 0 ]
    absent git -C "${REPO}" show-ref --verify -q refs/heads/starter-rc
    absent git -C "${REPO}" show-ref --verify -q refs/heads/starter
  done
}

@test "initial promotion publishes a root and later release has only the previous release as parent" {
  candidate --base-absent
  approval
  base=absent
  git -C "${REPO}" commit --allow-empty -qm 'Advance dev after approval'
  promote
  first="$(git -C "${REPO}" rev-parse starter)"
  [ -z "$(git -C "${REPO}" show -s --format=%P starter)" ]
  [ "$(git -C "${REPO}" rev-parse starter^{tree})" = "$tree" ]
  absent git -C "${REPO}" merge-base --is-ancestor dev starter
  absent git -C "${REPO}" merge-base --is-ancestor starter-rc starter
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$approved" ]
  run candidate
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$approved" ]
  candidate --cancel
  printf 'v2\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" commit -qam update
  candidate
  approval
  base="$first"
  promote
  second="$(git -C "${REPO}" rev-parse starter)"
  [ "$(git -C "${REPO}" show -s --format=%P starter)" = "$first" ]
  [ "$(git -C "${REPO}" show starter:.devcontainer/docs/guide.md)" = v2 ]
  [ "$(git -C "${REPO}" rev-parse starter^{tree})" = "$tree" ]
  git -C "${REPO}" clone -q --no-local --branch starter "${REPO}" "${TEMP}/consumer"
  [ "$(git -C "${TEMP}/consumer" rev-parse HEAD)" = "$second" ]
  [ "$(git -C "${TEMP}/consumer" rev-list --count HEAD)" -eq 2 ]
  candidate --cancel
  printf 'v3\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" commit -qam update-again
  candidate
  approval
  base="$second"
  promote
  candidate --cancel
  git -C "${TEMP}/consumer" fetch -q "${REPO}" refs/heads/starter:refs/remotes/upstream/starter
  git -C "${TEMP}/consumer" merge -q --ff-only upstream/starter
  [ "$(git -C "${TEMP}/consumer" show HEAD:.devcontainer/docs/guide.md)" = v3 ]
}

@test "promotion rejects stale identity, canceled candidates and dirty checkout" {
  candidate --base-absent
  approval
  base=absent
  run promote --expected-tree "$source"
  [ "$status" -ne 0 ]
  run promote --expected-source "$tree"
  [ "$status" -ne 0 ]
  run promote --expected-base "$source"
  [ "$status" -ne 0 ]
  run promote --approved-rc "$source"
  [ "$status" -ne 0 ]
  printf 'v2\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" commit -qam update
  candidate --base-absent
  run promote
  [ "$status" -ne 0 ]
  candidate --base-absent --cancel
  run promote
  [ "$status" -ne 0 ]
  candidate --base-absent
  approval
  printf 'dirty\n' > "${REPO}/README.md"
  run promote
  [ "$status" -ne 0 ]
  absent git -C "${REPO}" show-ref --verify -q refs/heads/starter
}

@test "promotion refuses symbolic and legacy release targets and checked-out worktrees" {
  candidate --base-absent
  approval
  base=absent
  git -C "${REPO}" symbolic-ref refs/heads/starter refs/heads/dev
  run promote
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse dev)" = "$source" ]
  git -C "${REPO}" symbolic-ref --delete refs/heads/starter
  git -C "${REPO}" branch starter dev
  base="$source"
  run promote
  [ "$status" -ne 0 ]
  git -C "${REPO}" branch -D starter
  base=absent
  promote
  base="$(git -C "${REPO}" rev-parse starter)"
  git -C "${REPO}" worktree add -q "${TEMP}/target" starter
  run promote
  [ "$status" -ne 0 ]
  git -C "${REPO}" worktree remove "${TEMP}/target"
  git -C "${REPO}" symbolic-ref refs/heads/starter-rc refs/heads/dev
  run promote
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter)" = "$base" ]
}

@test "candidate refuses checked-out secondary worktree and cancel accepts missing source branch" {
  candidate --base-absent
  approval
  git -C "${REPO}" worktree add -q "${TEMP}/candidate" starter-rc
  run candidate --base-absent --cancel
  [ "$status" -ne 0 ]
  run candidate --base-absent
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$approved" ]
  git -C "${REPO}" worktree remove "${TEMP}/candidate"
  git -C "${REPO}" switch -q -c retained
  git -C "${REPO}" branch -D dev
  run candidate --base-absent --cancel
  [ "$status" -eq 0 ]
  absent git -C "${REPO}" show-ref --verify -q refs/heads/starter-rc
}

@test "promotion checks every candidate ancestor and previous release source ancestry" {
  candidate --base-absent
  approval
  base=absent
  promote
  base="$(git -C "${REPO}" rev-parse starter)"
  candidate --cancel
  printf 'v2\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" commit -qam update
  candidate
  first="$(git -C "${REPO}" rev-parse starter-rc)"
  printf 'v3\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" commit -qam update-again
  candidate
  approval
  git -C "${REPO}" update-ref refs/heads/starter-rc "$(git -C "${REPO}" commit-tree "$tree" -p "$first" -m 'unrecognized candidate')"
  run promote --approved-rc "$(git -C "${REPO}" rev-parse starter-rc)"
  [ "$status" -ne 0 ]
  git -C "${REPO}" update-ref refs/heads/starter-rc "$approved"
  bad="$(git -C "${REPO}" commit-tree "$tree" -p "$base" -m "Prepare starter release candidate" -m "Starter-Candidate-Source: ${source}
Starter-Candidate-Base: ${base}")"
  child="$(git -C "${REPO}" commit-tree "$tree" -p "$bad" -m "Prepare starter release candidate" -m "Starter-Candidate-Source: ${source}
Starter-Candidate-Base: ${base}")"
  git -C "${REPO}" update-ref refs/heads/starter-rc "$child"
  run promote --approved-rc "$child"
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter)" = "$base" ]
}

@test "promotion rejects a forged prior release tree before changing refs" {
  candidate --base-absent
  approval
  prior_source="$source"
  base=absent
  promote
  legitimate="$(git -C "${REPO}" rev-parse starter)"
  candidate --cancel
  printf 'v2\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" commit -qam update
  wrong_tree="$(git -C "${REPO}" rev-parse dev^{tree})"
  forged="$(git -C "${REPO}" commit-tree "$wrong_tree" -m 'Publish consumer starter' -m "Starter-Release-Source: ${prior_source}
Starter-Compose-Policy: 2")"
  git -C "${REPO}" update-ref refs/heads/starter "$forged" "$legitimate"
  candidate
  approval
  base="$forged"
  run promote
  [ "$status" -ne 0 ]
  [[ "$output" == *"release tree does not match committed source"* ]]
  [ "$(git -C "${REPO}" rev-parse starter)" = "$forged" ]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$approved" ]
}

@test "clone keeps consumer commits through two linear merges and a source-only release" {
  candidate --base-absent
  approval
  base=absent
  promote
  first="$(git -C "${REPO}" rev-parse starter)"
  git clone -q --no-local --branch starter "${REPO}" "${TEMP}/consumer"
  consumer="${TEMP}/consumer"
  git -C "$consumer" config user.name 'Consumer Fixture'
  git -C "$consumer" config user.email 'consumer@example.test'
  mkdir -p "$consumer/.agents/skills/custom"
  printf 'consumer readme\n' > "$consumer/README.md"
  printf 'consumer skill\n' > "$consumer/.agents/skills/custom/SKILL.md"
  git -C "$consumer" add -A
  git -C "$consumer" commit -qm 'Customize consumer'
  consumer_head="$(git -C "$consumer" rev-parse HEAD)"
  absent git -C "$consumer" merge-base --is-ancestor "$(git -C "${REPO}" rev-parse dev)" HEAD

  for version in v2 v3; do
    candidate --cancel
    printf '%s\n' "$version" > "${REPO}/.devcontainer/docs/guide.md"
    git -C "${REPO}" commit -qam "Update guide to ${version}"
    candidate
    approval
    base="$(git -C "${REPO}" rev-parse starter)"
    promote
    release="$(git -C "${REPO}" rev-parse starter)"
    git -C "$consumer" fetch -q "${REPO}" refs/heads/starter:refs/remotes/upstream/starter
    git -C "$consumer" merge -q --no-ff -m "Merge ${version} starter" upstream/starter
    [ "$(git -C "$consumer" show -s --format=%P HEAD)" = "${consumer_head} ${release}" ]
    [ "$(git -C "$consumer" show HEAD:.devcontainer/docs/guide.md)" = "$version" ]
    [ "$(git -C "$consumer" show HEAD:README.md)" = 'consumer readme' ]
    [ "$(git -C "$consumer" show HEAD:.agents/skills/custom/SKILL.md)" = 'consumer skill' ]
    consumer_head="$(git -C "$consumer" rev-parse HEAD)"
  done
  [ "$(git -C "${REPO}" rev-list --count starter)" -eq 3 ]
  git -C "$consumer" merge-base --is-ancestor "$first" HEAD

  candidate --cancel
  printf 'producer readme only\n' > "${REPO}/README.md"
  git -C "${REPO}" commit -qam 'Update producer README only'
  candidate
  approval
  [ "$tree" = "$(git -C "${REPO}" rev-parse starter^{tree})" ]
  base="$release"
  promote
  source_only="$(git -C "${REPO}" rev-parse starter)"
  [ "$source_only" != "$release" ]
  [ "$(git -C "${REPO}" show -s --format=%P starter)" = "$release" ]
  git -C "$consumer" fetch -q "${REPO}" refs/heads/starter:refs/remotes/upstream/starter
  git -C "$consumer" merge -q --no-ff -m 'Merge source-only starter' upstream/starter
  [ "$(git -C "$consumer" show -s --format=%P HEAD)" = "${consumer_head} ${source_only}" ]
  [ "$(git -C "$consumer" show HEAD:README.md)" = 'consumer readme' ]
  [ "$(git -C "$consumer" show HEAD:.agents/skills/custom/SKILL.md)" = 'consumer skill' ]
  [ "$(git -C "$consumer" show HEAD:.devcontainer/docs/guide.md)" = v3 ]
  [ -z "$(git -C "$consumer" status --porcelain)" ]
}

@test "cancel refuses changed release without legitimate publication or with tampered candidate" {
  candidate --base-absent
  approval
  base=absent
  git -C "${REPO}" branch starter dev
  changed="$(git -C "${REPO}" rev-parse starter)"
  run candidate --cancel
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$approved" ]
  [ "$(git -C "${REPO}" rev-parse starter)" = "$changed" ]
  git -C "${REPO}" branch -D starter
  promote
  published="$(git -C "${REPO}" rev-parse starter)"
  wrong_tree="$(git -C "${REPO}" rev-parse dev^{tree})"
  impostor="$(git -C "${REPO}" commit-tree "$wrong_tree" -m 'Publish consumer starter' -m "Starter-Release-Source: ${source}")"
  git -C "${REPO}" update-ref refs/heads/starter "$impostor" "$published"
  run candidate --cancel
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$approved" ]
  git -C "${REPO}" update-ref refs/heads/starter "$published" "$impostor"
  forged="$(git -C "${REPO}" commit-tree "$tree" -p "$approved" -m 'unrecognized candidate')"
  git -C "${REPO}" update-ref refs/heads/starter-rc "$forged" "$approved"
  run candidate --cancel
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$forged" ]
  [ "$(git -C "${REPO}" rev-parse starter)" = "$published" ]
}

@test "candidate starts at a root, advances without source ancestry, and pins its base" {
  prepare
  base="$(git -C "${REPO}" rev-parse starter)"
  source="$(git -C "${REPO}" rev-parse dev)"
  run candidate
  [ "$status" -eq 0 ]
  first="$(git -C "${REPO}" rev-parse starter-rc)"
  [ -z "$(git -C "${REPO}" show -s --format=%P starter-rc)" ]
  absent git -C "${REPO}" merge-base --is-ancestor dev starter-rc
  [ "$(git -C "${REPO}" rev-parse starter-rc^{tree})" = "$(git -C "${REPO}" rev-parse starter^{tree})" ]
  [[ "$(git -C "${REPO}" show -s --format=%B starter-rc)" == *"Starter-Candidate-Source: ${source}"* ]]
  [[ "$(git -C "${REPO}" show -s --format=%B starter-rc)" == *"Starter-Candidate-Base: ${base}"* ]]
  run candidate
  [ "$status" -eq 0 ]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$first" ]
  printf 'maintainer-only\n' > "${REPO}/README.md"
  git -C "${REPO}" commit -qam 'Source-only change'
  run candidate
  [ "$status" -eq 0 ]
  [ "$(git -C "${REPO}" show -s --format=%P starter-rc)" = "$first" ]
  [ "$(git -C "${REPO}" rev-parse starter-rc^{tree})" = "$(git -C "${REPO}" rev-parse "${first}^{tree}")" ]
  [ "$(git -C "${REPO}" rev-parse starter)" = "$base" ]
  [ "$(git -C "${REPO}" branch --show-current)" = dev ]
}

@test "candidate keeps filtered skills and refuses stale or unexpected refs" {
  prepare
  candidate
  [ "$(git -C "${REPO}" show starter-rc:LICENSE)" = license ]
  [ "$(git -C "${REPO}" ls-tree starter-rc LICENSE | cut -f1 | cut -d' ' -f1)" = 100644 ]
  [ "$(git -C "${REPO}" show starter-rc:.devcontainer/test/unit/shared.bats)" = shared ]
  [ "$(git -C "${REPO}" show starter-rc:.devcontainer/docs/guide.md)" = v1 ]
  absent git -C "${REPO}" cat-file -e starter-rc:README.md
  absent git -C "${REPO}" cat-file -e starter-rc:skills-lock.json
  absent git -C "${REPO}" cat-file -e starter-rc:.agents/skills/external/SKILL.md
  [ "$(git -C "${REPO}" show starter-rc:.agents/skills/add-tool/SKILL.md)" = authored ]
  for path in AGENTS.md AGENTS.md.TEMPLATE AGENTS.md.TEMPLATE.EXAMPLE CHANGELOG.md \
    .github odd openspec docs .maintainer; do
    absent git -C "${REPO}" cat-file -e "starter-rc:${path}"
  done
  run python3 - "${REPO}" << 'PY'
import json
import subprocess
import sys
catalog = json.loads(subprocess.check_output(
    ['git', '-C', sys.argv[1], 'show', 'starter-rc:.devcontainer/skills/recommended.json']))
assert catalog == {'version': 1, 'skills': {
    'external': {'source': 'example/repo', 'skillPath': 'skills/external/SKILL.md'}}}
PY
  [ "$status" -eq 0 ]
  old="$(git -C "${REPO}" rev-parse starter-rc)"
  base="$(git -C "${REPO}" rev-parse starter)"
  git -C "${REPO}" branch -f starter dev
  run candidate
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$old" ]
  git -C "${REPO}" branch -f starter "$base"
  git -C "${REPO}" update-ref refs/heads/starter-rc "$(git -C "${REPO}" rev-parse dev)"
  run candidate
  [ "$status" -ne 0 ]
  run candidate --cancel
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$(git -C "${REPO}" rev-parse dev)" ]
}

@test "cancel removes only a verified candidate and allows a fresh root" {
  prepare
  candidate
  first="$(git -C "${REPO}" rev-parse starter-rc)"
  run candidate --cancel
  [ "$status" -eq 0 ]
  absent git -C "${REPO}" show-ref --verify --quiet refs/heads/starter-rc
  printf 'v2\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" commit -qam update
  run candidate
  [ "$status" -eq 0 ]
  [ -z "$(git -C "${REPO}" show -s --format=%P starter-rc)" ]
  [ "$(git -C "${REPO}" show starter-rc:.devcontainer/docs/guide.md)" = v2 ]
  absent git -C "${REPO}" merge-base --is-ancestor "$first" starter-rc
}

@test "candidate rejects a symbolic target without updating or deleting its aliased branch" {
  prepare
  candidate --target retained-rc
  before="$(git -C "${REPO}" rev-parse retained-rc)"
  git -C "${REPO}" symbolic-ref refs/heads/starter-rc refs/heads/retained-rc
  printf 'v2\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" commit -qam update

  run candidate
  [ "$status" -ne 0 ]
  [[ "$output" == *"candidate target must not be a symbolic ref"* ]]
  [ "$(git -C "${REPO}" rev-parse retained-rc)" = "$before" ]
  [ "$(git -C "${REPO}" symbolic-ref refs/heads/starter-rc)" = refs/heads/retained-rc ]

  run candidate --cancel
  [ "$status" -ne 0 ]
  [[ "$output" == *"candidate target must not be a symbolic ref"* ]]
  [ "$(git -C "${REPO}" rev-parse retained-rc)" = "$before" ]
  [ "$(git -C "${REPO}" symbolic-ref refs/heads/starter-rc)" = refs/heads/retained-rc ]
}

@test "candidate refuses divergent source and dirty checkout without changing refs" {
  prepare
  candidate
  first="$(git -C "${REPO}" rev-parse starter-rc)"
  base="$(git -C "${REPO}" rev-parse starter)"
  git -C "${REPO}" switch -q -c divergent "$base"
  git -C "${REPO}" commit --allow-empty -qm divergent
  git -C "${REPO}" switch -q dev
  run candidate --source divergent
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$first" ]
  printf 'dirty\n' > "${REPO}/README.md"
  run candidate --cancel
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$first" ]
  [ "$(git -C "${REPO}" rev-parse starter)" = "$base" ]
}

@test "published release preserves the filtered whitelist and external skill catalog" {
  candidate --base-absent
  approval
  base=absent
  promote

  [ "$(git -C "${REPO}" rev-parse starter^{tree})" = "$tree" ]
  [ "$(git -C "${REPO}" show starter:LICENSE)" = license ]
  [ "$(git -C "${REPO}" ls-tree starter LICENSE | cut -f1 | cut -d' ' -f1)" = 100644 ]
  [ "$(git -C "${REPO}" show starter:.devcontainer/test/unit/shared.bats)" = shared ]
  [ "$(git -C "${REPO}" show starter:.agents/skills/add-tool/SKILL.md)" = authored ]
  for path in README.md AGENTS.md AGENTS.md.TEMPLATE AGENTS.md.TEMPLATE.EXAMPLE \
    CHANGELOG.md .github odd openspec docs .maintainer skills-lock.json \
    .agents/skills/external/SKILL.md; do
    absent git -C "${REPO}" cat-file -e "starter:${path}"
  done
  run python3 - "${REPO}" << 'PY'
import json
import subprocess
import sys

catalog = json.loads(subprocess.check_output(
    ['git', '-C', sys.argv[1], 'show', 'starter:.devcontainer/skills/recommended.json']))
assert catalog == {'version': 1, 'skills': {
    'external': {'source': 'example/repo', 'skillPath': 'skills/external/SKILL.md'}}}
PY
  [ "$status" -eq 0 ]
}

@test "new release refreshes recommendations without publishing consumer-owned files" {
  prepare
  first="$(git -C "${REPO}" rev-parse starter)"
  printf '{"version":1,"skills":{"new":{"source":"other/repo","skillPath":"new/SKILL.md"}}}\n' > "${REPO}/skills-lock.json"
  printf 'maintainer update\n' > "${REPO}/README.md"
  git -C "${REPO}" commit -qam 'Update source catalog and README'
  candidate
  approval
  base="$first"
  promote

  [ "$(git -C "${REPO}" show -s --format=%P starter)" = "$first" ]
  absent git -C "${REPO}" cat-file -e starter:README.md
  absent git -C "${REPO}" cat-file -e starter:skills-lock.json
  run python3 - "${REPO}" << 'PY'
import json
import subprocess
import sys

catalog = json.loads(subprocess.check_output(
    ['git', '-C', sys.argv[1], 'show', 'starter:.devcontainer/skills/recommended.json']))
assert catalog['skills'] == {
    'new': {'source': 'other/repo', 'skillPath': 'new/SKILL.md'}}
PY
  [ "$status" -eq 0 ]
}

@test "published starter preserves skills selector and guide bytes" {
  mkdir -p "${REPO}/.taskfiles/scripts"
  for name in skills-suggest.sh skills-catalog.py; do
    cp "${ROOT}/.taskfiles/scripts/${name}" "${REPO}/.taskfiles/scripts/${name}"
  done
  cp "${ROOT}/.devcontainer/docs/optional-skills.md" "${REPO}/.devcontainer/docs/optional-skills.md"
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm 'Include skills selector and guidance'
  candidate --base-absent
  approval
  base=absent
  promote

  for path in .taskfiles/scripts/skills-suggest.sh .taskfiles/scripts/skills-catalog.py \
    .devcontainer/docs/optional-skills.md; do
    [ "$(git -C "${REPO}" rev-parse "starter:${path}")" = "$(git -C "${ROOT}" hash-object "${path}")" ]
  done
  absent git -C "${REPO}" cat-file -e starter:odd
}

@test "candidate rejects malformed skill lock and leaves release and candidate unchanged" {
  prepare
  candidate
  prior="$(git -C "${REPO}" rev-parse starter-rc)"
  release="$(git -C "${REPO}" rev-parse starter)"
  printf '{"version":2,"skills":{}}\n' > "${REPO}/skills-lock.json"
  git -C "${REPO}" commit -qam 'Unsupported skill lock'

  run candidate
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsupported source skills lock"* ]]
  [ "$(git -C "${REPO}" rev-parse starter-rc)" = "$prior" ]
  [ "$(git -C "${REPO}" rev-parse starter)" = "$release" ]
}

@test "dirty candidate checkout rejects creation without changing refs" {
  printf 'dirty\n' > "${REPO}/README.md"
  run candidate --base-absent
  [ "$status" -ne 0 ]
  absent git -C "${REPO}" show-ref --verify --quiet refs/heads/starter
  absent git -C "${REPO}" show-ref --verify --quiet refs/heads/starter-rc
}

@test "conflicting consumer merge retains the merge state for explicit resolution" {
  prepare
  consumer="${TEMP}/consumer"
  git clone -q --no-local --branch starter "${REPO}" "$consumer"
  git -C "$consumer" config user.name 'Consumer Fixture'
  git -C "$consumer" config user.email 'consumer@example.test'
  printf 'consumer edit\n' > "$consumer/.devcontainer/docs/guide.md"
  git -C "$consumer" commit -qam 'Customize guide'
  consumer_head="$(git -C "$consumer" rev-parse HEAD)"

  printf 'upstream edit\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" commit -qam 'Update guide'
  prepare
  release="$(git -C "${REPO}" rev-parse starter)"
  git -C "$consumer" fetch -q "${REPO}" refs/heads/starter:refs/remotes/upstream/starter
  run git -C "$consumer" merge --no-ff upstream/starter
  [ "$status" -ne 0 ]
  [ "$(git -C "$consumer" rev-parse HEAD)" = "$consumer_head" ]
  [ "$(git -C "$consumer" rev-parse MERGE_HEAD)" = "$release" ]
  [ "$(git -C "$consumer" show HEAD:.devcontainer/docs/guide.md)" = 'consumer edit' ]
  [ -n "$(git -C "$consumer" ls-files -u -- .devcontainer/docs/guide.md)" ]
}

@test "distributed guides do not instruct consumers to run maintainer tasks" {
  run python3 - "${ROOT}" << 'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
guides = [root / '.devcontainer/README.md', *sorted((root / '.devcontainer/docs').rglob('*.md'))]
for guide in guides:
    text = guide.read_text()
    assert not re.search(r'\.maintainer(?:/|\b)|project:init|upstream/main|test:starter', text), guide
    assert 'task test' in text if guide.name == 'extending.md' else True
assert 'git clone --branch starter --origin upstream' in (root / 'README.md').read_text()
assert 'git merge upstream/starter' in (root / 'README.md').read_text()
PY
  [ "$status" -eq 0 ]
}

@test "published starter exports host preflight and guide for an unrelated project" {
  cp "${ROOT}/Taskfile.yml" "${REPO}/Taskfile.yml"
  mkdir -p "${REPO}/.taskfiles"
  cp -a "${ROOT}/.taskfiles/." "${REPO}/.taskfiles/"
  cp "${ROOT}/.devcontainer/docs/existing-project.md" \
    "${REPO}/.devcontainer/docs/existing-project.md"
  cp "${ROOT}/.devcontainer/docs/README.md" "${REPO}/.devcontainer/docs/README.md"
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm 'Include host integration entry'
  run prepare
  [ "$status" -eq 0 ]
  for path in Taskfile.yml .taskfiles/scripts/check-existing-project.py \
    .devcontainer/docs/existing-project.md .devcontainer/docs/README.md; do
    git -C "${REPO}" cat-file -e "starter:${path}"
  done
  [[ "$(git -C "${REPO}" show starter:.devcontainer/docs/README.md)" == *"(existing-project.md)"* ]]

  git -C "${REPO}" switch -q starter
  local consumer="${TEMP}/unrelated consumer"
  mkdir -p "${consumer}"
  git init -q "${consumer}"
  git -C "${consumer}" -c user.name=Fixture -c user.email=fixture@example.test \
    commit -q --allow-empty -m initial
  local before
  before="$(git -C "${consumer}" rev-parse HEAD)"
  run env PROJECT="${consumer}" task --dir "${REPO}" project:check-existing
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMPATIBLE"* ]]
  [ "$(git -C "${consumer}" rev-parse HEAD)" = "$before" ]
  [ -z "$(git -C "${consumer}" status --porcelain)" ]

  touch "${consumer}/Taskfile.yml"
  run env PROJECT="${consumer}" task --dir "${REPO}" project:check-existing
  [ "$status" -ne 0 ]
  [[ "$output" == *"MANUAL INTEGRATION"* ]]
}

@test "filtered starter clone shows help without a missing maintainer command" {
  cp "${ROOT}/Taskfile.yml" "${REPO}/Taskfile.yml"
  mkdir -p "${REPO}/.taskfiles"
  cp -a "${ROOT}/.taskfiles/." "${REPO}/.taskfiles/"
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm 'Include task help entry'
  candidate --base-absent
  absent git -C "${REPO}" cat-file -e starter-rc:.maintainer/Taskfile.yml
  git clone -q --no-local --branch starter-rc "${REPO}" "${TEMP}/consumer"

  run task --dir "${TEMP}/consumer" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tasks help"* ]]
  [[ "$output" == *"task test"* ]]
  [[ "$output" != *".maintainer/Taskfile.yml"* ]]
}

@test "unrelated consumer reviews two-parent import and later merges starter by ancestry" {
  printf 'starter env defaults\n' > "${REPO}/.env.example"
  printf 'starter-state/\n' > "${REPO}/.gitignore"
  git -C "${REPO}" add .env.example .gitignore
  git -C "${REPO}" commit -qm 'Add starter defaults'
  prepare
  local first_release consumer project_head first_merge second_release
  first_release="$(git -C "${REPO}" rev-parse starter)"

  consumer="${TEMP}/unrelated consumer"
  git init -q -b main "${consumer}"
  git -C "${consumer}" config user.name 'Consumer Fixture'
  git -C "${consumer}" config user.email 'consumer@example.test'
  mkdir -p "${consumer}/.agents/skills/project-tool"
  printf 'project readme\n' > "${consumer}/README.md"
  printf 'project license\n' > "${consumer}/LICENSE"
  printf 'project env defaults\n' > "${consumer}/.env.example"
  printf 'project-state/\n' > "${consumer}/.gitignore"
  printf 'project agents\n' > "${consumer}/AGENTS.md"
  printf 'project skill lock\n' > "${consumer}/skills-lock.json"
  printf 'project skill\n' > "${consumer}/.agents/skills/project-tool/SKILL.md"
  git -C "${consumer}" add -A
  git -C "${consumer}" commit -qm 'Existing project'
  project_head="$(git -C "${consumer}" rev-parse HEAD)"
  git -C "${consumer}" switch -q -c integrate-starter

  # A local path fetch imports only disposable fixture objects, never a network remote.
  git -C "${consumer}" fetch -q "${REPO}" \
    refs/heads/starter:refs/remotes/upstream/starter
  [ "$(git -C "${consumer}" rev-parse refs/remotes/upstream/starter)" = "$first_release" ]
  run git -C "${consumer}" merge --allow-unrelated-histories --no-commit --no-ff upstream/starter
  [ "$status" -ne 0 ]
  [ "$(git -C "${consumer}" rev-parse HEAD)" = "$project_head" ]
  [ "$(git -C "${consumer}" rev-parse MERGE_HEAD)" = "$first_release" ]
  for path in LICENSE .env.example .gitignore; do
    git -C "${consumer}" ls-files -u -- "$path" | grep -q .
  done
  [ -z "$(git -C "${consumer}" ls-files -u -- README.md)" ]

  # Resolve only the overlapping files; keep both sets of independent surfaces.
  for path in LICENSE .env.example; do
    git -C "${consumer}" show "${project_head}:${path}" > "${consumer}/${path}"
  done
  printf 'project-state/\nstarter-state/\n' > "${consumer}/.gitignore"
  git -C "${consumer}" add README.md LICENSE .env.example .gitignore
  [ -z "$(git -C "${consumer}" ls-files -u)" ]
  [ "$(git -C "${consumer}" show :README.md)" = 'project readme' ]
  [ "$(git -C "${consumer}" show :.gitignore)" = "$(printf 'project-state/\nstarter-state/')" ]
  [ "$(git -C "${consumer}" show :.devcontainer/docs/guide.md)" = v1 ]
  [ "$(git -C "${consumer}" show :.agents/skills/add-tool/SKILL.md)" = authored ]
  [ "$(git -C "${consumer}" show :.agents/skills/project-tool/SKILL.md)" = 'project skill' ]
  git -C "${consumer}" diff --cached --check
  git -C "${consumer}" commit -qm 'Review initial starter integration'
  first_merge="$(git -C "${consumer}" rev-parse HEAD)"
  [ "$(git -C "${consumer}" show -s --format=%P HEAD)" = "${project_head} ${first_release}" ]
  for path in README.md LICENSE .env.example AGENTS.md skills-lock.json; do
    [ "$(git -C "${consumer}" show "HEAD:${path}")" = "$(git -C "${consumer}" show "${project_head}:${path}")" ]
  done
  [ "$(git -C "${consumer}" show HEAD:.gitignore)" = "$(printf 'project-state/\nstarter-state/')" ]

  printf 'v2\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" add .devcontainer/docs/guide.md
  git -C "${REPO}" commit -qm 'Update starter guide'
  prepare
  second_release="$(git -C "${REPO}" rev-parse starter)"
  git -C "${consumer}" fetch -q "${REPO}" \
    refs/heads/starter:refs/remotes/upstream/starter
  git -C "${consumer}" merge-base --is-ancestor "$first_release" "$second_release"
  run git -C "${consumer}" merge --no-commit --no-ff upstream/starter
  [ "$status" -eq 0 ]
  [ "$(git -C "${consumer}" rev-parse HEAD)" = "$first_merge" ]
  [ "$(git -C "${consumer}" rev-parse MERGE_HEAD)" = "$second_release" ]
  [ "$(git -C "${consumer}" show :.devcontainer/docs/guide.md)" = v2 ]
  git -C "${consumer}" diff --cached --check
  git -C "${consumer}" commit -qm 'Review starter update'
  [ "$(git -C "${consumer}" show -s --format=%P HEAD)" = "${first_merge} ${second_release}" ]
  for path in README.md LICENSE .env.example AGENTS.md skills-lock.json \
    .agents/skills/project-tool/SKILL.md; do
    [ "$(git -C "${consumer}" show "HEAD:${path}")" = "$(git -C "${consumer}" show "${project_head}:${path}")" ]
  done
  [ "$(git -C "${consumer}" show HEAD:.gitignore)" = "$(printf 'project-state/\nstarter-state/')" ]
  [ "$(git -C "${consumer}" show HEAD:.agents/skills/add-tool/SKILL.md)" = authored ]
  [ "$(git -C "${consumer}" show HEAD:.devcontainer/docs/guide.md)" = v2 ]
  [ -z "$(git -C "${consumer}" status --porcelain)" ]
}
