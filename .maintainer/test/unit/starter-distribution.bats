#!/usr/bin/env bats

setup() {
  ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  SCRIPT="${ROOT}/.maintainer/scripts/starter-distribution.py"
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
  printf '{"version":1,"skills":{"external":{"source":"example/repo","skillPath":"skills/external/SKILL.md","computedHash":"dev-only"}}}\n' > "${REPO}/skills-lock.json"
  for path in README.md AGENTS.md AGENTS.md.TEMPLATE.EXAMPLE CHANGELOG.md \
    .github/workflow odd/task openspec/spec docs/guide .maintainer/tool; do
    printf 'maintainer\n' > "${REPO}/${path}"
  done
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm initial
}

teardown() { rm -rf "${TEMP}"; }

prepare() { (cd "${REPO}" && python3 "${SCRIPT}" --source dev --target starter); }

producer() {
  (cd "${REPO}" && task --taskfile .maintainer/Taskfile.yml distribution:producer -- --source dev --target starter)
}

producer_fixture() {
  mkdir -p "${REPO}/.maintainer/scripts"
  cp "${ROOT}/.maintainer/Taskfile.yml" "${REPO}/.maintainer/Taskfile.yml"
  cp -a "${ROOT}/.maintainer/tasks" "${REPO}/.maintainer/"
  cp "${ROOT}/.maintainer/scripts/starter-distribution.py" "${REPO}/.maintainer/scripts/"
  cp "${ROOT}/.maintainer/scripts/starter-producer.py" "${REPO}/.maintainer/scripts/"
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm 'Add producer fixture'
  prepare
}

@test "producer task updates target from source while retaining current branch" {
  producer_fixture
  printf 'v2\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" commit -qam update
  before="$(git -C "${REPO}" rev-parse HEAD)"
  run producer
  [ "$status" -eq 0 ]
  [ "$(git -C "${REPO}" branch --show-current)" = dev ]
  [ "$(git -C "${REPO}" rev-parse HEAD)" = "$before" ]
  [ "$(git -C "${REPO}" show starter:.devcontainer/docs/guide.md)" = v2 ]
  [ -z "$(git -C "${REPO}" worktree list --porcelain | grep '^worktree ' | grep -v "${REPO}$")" ]
  [ -z "$(git -C "${REPO}" status --porcelain)" ]
}

@test "producer conflict leaves target intact and removes temporary worktree" {
  producer_fixture
  git -C "${REPO}" switch -q starter
  printf 'consumer\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" commit -qam consumer
  target_before="$(git -C "${REPO}" rev-parse HEAD)"
  git -C "${REPO}" switch -q dev
  printf 'producer\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" commit -qam producer
  run producer
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter)" = "$target_before" ]
  [ "$(git -C "${REPO}" branch --show-current)" = dev ]
  [ "$(git -C "${REPO}" worktree list --porcelain | grep -c '^worktree ')" -eq 1 ]
  [ -z "$(git -C "${REPO}" status --porcelain)" ]
}

@test "producer refuses dirty checkout before touching target" {
  producer_fixture
  before="$(git -C "${REPO}" rev-parse starter)"
  printf 'dirty\n' > "${REPO}/README.md"
  run producer
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter)" = "$before" ]
  [ "$(git -C "${REPO}" worktree list --porcelain | grep -c '^worktree ')" -eq 1 ]
}

@test "first release has source ancestry and excludes only maintainer paths" {
  run prepare
  [ "$status" -eq 0 ]
  git -C "${REPO}" merge-base --is-ancestor dev starter
  [ "$(git -C "${REPO}" branch --show-current)" = dev ]
  [ "$(git -C "${REPO}" show starter:LICENSE)" = license ]
  [ "$(git -C "${REPO}" show dev:AGENTS.md.TEMPLATE)" = template ]
  [ "$(git -C "${REPO}" ls-tree starter LICENSE | cut -f1 | cut -d' ' -f1)" = 100644 ]
  [ "$(git -C "${REPO}" show starter:.devcontainer/test/unit/shared.bats)" = shared ]
  [ "$(git -C "${REPO}" show starter:.devcontainer/docs/guide.md)" = v1 ]
  [ "$(git -C "${REPO}" show starter:.agents/skills/add-tool/SKILL.md)" = authored ]
  ! git -C "${REPO}" cat-file -e starter:.agents/skills/external/SKILL.md
  ! git -C "${REPO}" cat-file -e starter:skills-lock.json
  [ "$(git -C "${REPO}" show dev:.agents/skills/external/SKILL.md)" = external ]
  [ "$(git -C "${REPO}" show dev:skills-lock.json)" = '{"version":1,"skills":{"external":{"source":"example/repo","skillPath":"skills/external/SKILL.md","computedHash":"dev-only"}}}' ]
  run python3 - "${REPO}" <<'PY'
import json
import subprocess
import sys
repo = sys.argv[1]
catalog = json.loads(subprocess.check_output(['git', '-C', repo, 'show', 'starter:.devcontainer/skills/recommended.json']))
assert catalog == {'version': 1, 'skills': {'external': {'source': 'example/repo', 'skillPath': 'skills/external/SKILL.md'}}}
PY
  [ "$status" -eq 0 ]
  for path in README.md AGENTS.md AGENTS.md.TEMPLATE AGENTS.md.TEMPLATE.EXAMPLE CHANGELOG.md \
    .github odd openspec docs .maintainer; do
    ! git -C "${REPO}" cat-file -e "starter:${path}"
  done
}

@test "later releases retain consumer lock and custom skill while refreshing recommendations" {
  prepare
  git -C "${REPO}" switch -q starter
  mkdir -p "${REPO}/.agents/skills/custom"
  printf 'custom\n' > "${REPO}/.agents/skills/custom/SKILL.md"
  printf 'consumer lock\n' > "${REPO}/skills-lock.json"
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm consumer
  git -C "${REPO}" switch -q dev
  printf '{"version":1,"skills":{"new":{"source":"other/repo","skillPath":"new/SKILL.md"}}}\n' > "${REPO}/skills-lock.json"
  git -C "${REPO}" commit -qam update
  git -C "${REPO}" switch -q starter
  run prepare
  [ "$status" -eq 0 ]
  [ "$(git -C "${REPO}" show HEAD:skills-lock.json)" = 'consumer lock' ]
  [ "$(git -C "${REPO}" show HEAD:.agents/skills/custom/SKILL.md)" = custom ]
  ! git -C "${REPO}" cat-file -e HEAD:.agents/skills/external/SKILL.md
  run python3 - "${REPO}" <<'PY'
import json
import subprocess
import sys
catalog = json.loads(subprocess.check_output(['git', '-C', sys.argv[1], 'show', 'HEAD:.devcontainer/skills/recommended.json']))
assert catalog['skills'] == {'new': {'source': 'other/repo', 'skillPath': 'new/SKILL.md'}}
PY
  [ "$status" -eq 0 ]
}

@test "legacy release conflicts instead of deleting consumer edits to distributed skills and lock" {
  # Model a previously published release with the old unfiltered skill tree.
  python3 - "${REPO}" <<'PY'
import subprocess
import sys
repo = sys.argv[1]
source = subprocess.check_output(['git', '-C', repo, 'rev-parse', 'dev']).decode().strip()
tree = subprocess.check_output(['git', '-C', repo, 'rev-parse', 'dev^{tree}']).decode().strip()
commit = subprocess.check_output(['git', '-C', repo, 'commit-tree', tree, '-p', source],
    input=f'Prepare consumer starter\n\nStarter-Distribution-Source: {source}\n'.encode()).decode().strip()
subprocess.check_call(['git', '-C', repo, 'branch', 'starter', commit])
PY
  git -C "${REPO}" switch -q starter
  printf 'consumer skill\n' > "${REPO}/.agents/skills/external/SKILL.md"
  printf 'consumer lock\n' > "${REPO}/skills-lock.json"
  git -C "${REPO}" commit -qam consumer
  git -C "${REPO}" switch -q dev
  git -C "${REPO}" commit --allow-empty -qm update
  git -C "${REPO}" switch -q starter
  run prepare
  [ "$status" -ne 0 ]
  [ -f "${REPO}/.git/MERGE_HEAD" ]
  [ "$(git -C "${REPO}" show HEAD:skills-lock.json)" = 'consumer lock' ]
  [ "$(git -C "${REPO}" show HEAD:.agents/skills/external/SKILL.md)" = 'consumer skill' ]
  git -C "${REPO}" merge --abort
  [ "$(git -C "${REPO}" show HEAD:skills-lock.json)" = 'consumer lock' ]
}

@test "second release merges without touching consumer-owned paths" {
  prepare
  git -C "${REPO}" switch -q starter
  mkdir -p "${REPO}/.github" "${REPO}/odd" "${REPO}/openspec"
  for path in README.md .github/workflow odd/task openspec/spec; do
    printf 'consumer\n' > "${REPO}/${path}"
  done
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm consumer
  git -C "${REPO}" switch -q dev
  printf 'v2\n' > "${REPO}/.devcontainer/docs/guide.md"
  printf 'legacy template update\n' > "${REPO}/AGENTS.md.TEMPLATE"
  printf 'new maintainer\n' > "${REPO}/README.md"
  printf 'new maintainer\n' > "${REPO}/.github/workflow"
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm update
  git -C "${REPO}" switch -q starter
  run prepare
  [ "$status" -eq 0 ]
  [ "$(git -C "${REPO}" show HEAD:.devcontainer/docs/guide.md)" = v2 ]
  ! git -C "${REPO}" cat-file -e HEAD:AGENTS.md.TEMPLATE
  [ "$(git -C "${REPO}" show dev:AGENTS.md.TEMPLATE)" = 'legacy template update' ]
  for path in README.md .github/workflow odd/task openspec/spec; do
    [ "$(git -C "${REPO}" show "HEAD:${path}")" = consumer ]
  done
  git -C "${REPO}" merge-base --is-ancestor dev starter
  run prepare
  [ "$status" -eq 0 ]
}

@test "source-only release advances ancestry and marker without changing the target tree" {
  prepare
  git -C "${REPO}" switch -q starter
  printf 'consumer\n' > "${REPO}/README.md"
  git -C "${REPO}" add README.md
  git -C "${REPO}" commit -qm consumer
  before_tree="$(git -C "${REPO}" rev-parse HEAD^{tree})"
  git -C "${REPO}" switch -q dev
  printf 'maintainer update\n' > "${REPO}/README.md"
  git -C "${REPO}" commit -qam source-only
  source_commit="$(git -C "${REPO}" rev-parse dev)"
  git -C "${REPO}" switch -q starter

  run prepare
  [ "$status" -eq 0 ]
  [ "$(git -C "${REPO}" rev-parse HEAD^{tree})" = "$before_tree" ]
  [ "$(git -C "${REPO}" show HEAD:README.md)" = consumer ]
  git -C "${REPO}" merge-base --is-ancestor "$source_commit" HEAD
  marker="$(git -C "${REPO}" log -1 --format=%B --grep='^Prepare consumer starter$' HEAD)"
  [[ "$marker" == *"Starter-Distribution-Source: ${source_commit}"* ]]
  first_head="$(git -C "${REPO}" rev-parse HEAD)"

  run prepare
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to update"* ]]
  [ "$(git -C "${REPO}" rev-parse HEAD)" = "$first_head" ]
  [ -z "$(git -C "${REPO}" status --porcelain)" ]
}

@test "unrelated target and dirty worktree fail without mutations" {
  git -C "${REPO}" branch starter dev
  run prepare
  [ "$status" -ne 0 ]
  [ "$(git -C "${REPO}" rev-parse starter)" = "$(git -C "${REPO}" rev-parse dev)" ]
  git -C "${REPO}" branch -D starter
  printf 'dirty\n' > "${REPO}/README.md"
  run prepare
  [ "$status" -ne 0 ]
  ! git -C "${REPO}" show-ref --verify --quiet refs/heads/starter
}

@test "conflict leaves consumer merge state for explicit resolution" {
  prepare
  git -C "${REPO}" switch -q starter
  printf 'consumer edit\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" commit -qam consumer
  git -C "${REPO}" switch -q dev
  printf 'upstream edit\n' > "${REPO}/.devcontainer/docs/guide.md"
  git -C "${REPO}" commit -qam upstream
  git -C "${REPO}" switch -q starter
  run prepare
  [ "$status" -ne 0 ]
  [ -f "${REPO}/.git/MERGE_HEAD" ]
  [ "$(git -C "${REPO}" show HEAD:.devcontainer/docs/guide.md)" = 'consumer edit' ]
}

@test "distributed guides do not instruct consumers to run maintainer tasks" {
  run python3 - "${ROOT}" <<'PY'
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
  git -C "${REPO}" switch -q starter
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
