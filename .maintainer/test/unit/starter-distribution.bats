#!/usr/bin/env bats

setup() {
  ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  SCRIPT="${ROOT}/.maintainer/scripts/starter-distribution.py"
  TEMP="$(mktemp -d)"
  REPO="${TEMP}/repo"
  git init -q -b dev "${REPO}"
  git -C "${REPO}" config user.name "Distribution Test"
  git -C "${REPO}" config user.email "distribution@example.test"
  mkdir -p "${REPO}/.devcontainer/docs" "${REPO}/.devcontainer/test/unit" \
    "${REPO}/.github" "${REPO}/odd" "${REPO}/openspec" "${REPO}/docs" "${REPO}/.maintainer"
  printf 'license\n' > "${REPO}/LICENSE"
  printf 'template\n' > "${REPO}/AGENTS.md.TEMPLATE"
  chmod 640 "${REPO}/LICENSE" "${REPO}/AGENTS.md.TEMPLATE"
  printf 'v1\n' > "${REPO}/.devcontainer/docs/guide.md"
  printf 'shared\n' > "${REPO}/.devcontainer/test/unit/shared.bats"
  for path in README.md AGENTS.md AGENTS.md.TEMPLATE.EXAMPLE CHANGELOG.md \
    .github/workflow odd/task openspec/spec docs/guide .maintainer/tool; do
    printf 'maintainer\n' > "${REPO}/${path}"
  done
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm initial
}

teardown() { rm -rf "${TEMP}"; }

prepare() { (cd "${REPO}" && python3 "${SCRIPT}" --source dev --target starter); }

@test "first release has source ancestry and excludes only maintainer paths" {
  run prepare
  [ "$status" -eq 0 ]
  git -C "${REPO}" merge-base --is-ancestor dev starter
  [ "$(git -C "${REPO}" branch --show-current)" = dev ]
  [ "$(git -C "${REPO}" show starter:LICENSE)" = license ]
  [ "$(git -C "${REPO}" ls-tree starter LICENSE | cut -f1 | cut -d' ' -f1)" = 100644 ]
  [ "$(git -C "${REPO}" show starter:AGENTS.md.TEMPLATE)" = template ]
  [ "$(git -C "${REPO}" show starter:.devcontainer/test/unit/shared.bats)" = shared ]
  [ "$(git -C "${REPO}" show starter:.devcontainer/docs/guide.md)" = v1 ]
  for path in README.md AGENTS.md AGENTS.md.TEMPLATE.EXAMPLE CHANGELOG.md \
    .github odd openspec docs .maintainer; do
    ! git -C "${REPO}" cat-file -e "starter:${path}"
  done
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
  printf 'new maintainer\n' > "${REPO}/README.md"
  printf 'new maintainer\n' > "${REPO}/.github/workflow"
  git -C "${REPO}" add -A
  git -C "${REPO}" commit -qm update
  git -C "${REPO}" switch -q starter
  run prepare
  [ "$status" -eq 0 ]
  [ "$(git -C "${REPO}" show HEAD:.devcontainer/docs/guide.md)" = v2 ]
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
