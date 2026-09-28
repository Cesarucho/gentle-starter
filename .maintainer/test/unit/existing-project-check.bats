#!/usr/bin/env bats

setup() {
  STARTER="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  SANDBOX="$(mktemp -d)"
  PROJECT="${SANDBOX}/existing project"
  mkdir -p "${PROJECT}"
  git -C "${PROJECT}" init -q
  git -C "${PROJECT}" -c user.name=Fixture -c user.email=fixture@example.test commit -q --allow-empty -m initial
}

teardown() { rm -rf "${SANDBOX}"; }

check() { run python3 "${STARTER}/.taskfiles/scripts/check-existing-project.py" "$1"; }

@test "clean unrelated project is compatible without requiring upstream" {
  check "${PROJECT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"does not guarantee a conflict-free merge"* ]]
  [[ "$output" == *"No ancestry, remote, or merge result was verified"* ]]
}

@test "Task invocation from separate starter checkout accepts spaces in absolute PROJECT" {
  run env PROJECT="${PROJECT}" task --dir "${STARTER}" project:check-existing
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMPATIBLE"* ]]
}

@test "existing reserved tracked and untracked directories require manual integration" {
  mkdir -p "${PROJECT}/.devcontainer" "${PROJECT}/.agents/skills/add-tool" "${PROJECT}/.taskfiles"
  touch "${PROJECT}/.devcontainer/owned"
  git -C "${PROJECT}" add .devcontainer
  git -C "${PROJECT}" -c user.name=Fixture -c user.email=fixture@example.test commit -qm owned
  touch "${PROJECT}/.agents/skills/add-tool/owned" "${PROJECT}/.taskfiles/owned"
  check "${PROJECT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *".devcontainer"* && "$output" == *".taskfiles"* && "$output" == *".agents/skills/add-tool"* ]]
  git -C "${PROJECT}" add .agents .taskfiles
  git -C "${PROJECT}" -c user.name=Fixture -c user.email=fixture@example.test commit -qm reserved
  check "${PROJECT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *".devcontainer"* && "$output" == *".taskfiles"* && "$output" == *".agents/skills/add-tool"* ]]
}

@test "untracked reserved path takes precedence over unrelated dirty changes" {
  touch "${PROJECT}/Taskfile.yml" "${PROJECT}/unrelated"
  before="$(git -C "${PROJECT}" status --porcelain=v1 --untracked-files=all; git -C "${PROJECT}" for-each-ref; sha256sum "${PROJECT}/.git/index" "${PROJECT}/.git/config" "${PROJECT}/Taskfile.yml" "${PROJECT}/unrelated")"
  check "${PROJECT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Taskfile.yml (file)"* ]]
  after="$(git -C "${PROJECT}" status --porcelain=v1 --untracked-files=all; git -C "${PROJECT}" for-each-ref; sha256sum "${PROJECT}/.git/index" "${PROJECT}/.git/config" "${PROJECT}/Taskfile.yml" "${PROJECT}/unrelated")"
  [ "$before" = "$after" ]
}

@test "ignored untracked reserved path still requires manual integration" {
  printf '.devcontainer/\n' > "${PROJECT}/.gitignore"
  git -C "${PROJECT}" add .gitignore
  git -C "${PROJECT}" -c user.name=Fixture -c user.email=fixture@example.test commit -qm ignore
  mkdir "${PROJECT}/.devcontainer"
  touch "${PROJECT}/.devcontainer/ignored"
  check "${PROJECT}"
  [ "$status" -eq 1 ]
}

@test "ignored unusual reserved path requires manual integration" {
  printf '.taskfiles\n' > "${PROJECT}/.gitignore"
  git -C "${PROJECT}" add .gitignore
  git -C "${PROJECT}" -c user.name=Fixture -c user.email=fixture@example.test commit -qm ignore
  mkfifo "${PROJECT}/.taskfiles"
  check "${PROJECT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *".taskfiles (unusual path type)"* ]]
}

@test "exact reserved files require manual integration" {
  touch "${PROJECT}/Taskfile.yml" "${PROJECT}/.markdownlint-cli2.yaml"
  git -C "${PROJECT}" add -A
  git -C "${PROJECT}" -c user.name=Fixture -c user.email=fixture@example.test commit -qm reserved
  check "${PROJECT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Taskfile.yml"* && "$output" == *".markdownlint-cli2.yaml"* ]]
}

@test "symlink and ancestor file blocker require manual integration" {
  ln -s nowhere "${PROJECT}/.devcontainer"
  touch "${PROJECT}/.agents"
  git -C "${PROJECT}" add -A
  git -C "${PROJECT}" -c user.name=Fixture -c user.email=fixture@example.test commit -qm reserved
  check "${PROJECT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *".devcontainer (symlink)"* && "$output" == *".agents (file)"* ]]
}

@test "dirty tracked and untracked projects fail closed" {
  touch "${PROJECT}/owned"
  check "${PROJECT}"
  [ "$status" -eq 2 ]
  git -C "${PROJECT}" add owned
  git -C "${PROJECT}" -c user.name=Fixture -c user.email=fixture@example.test commit -qm owned
  printf changed > "${PROJECT}/owned"
  check "${PROJECT}"
  [ "$status" -eq 2 ]
}

@test "non-root and merge in progress fail closed" {
  mkdir "${PROJECT}/child"
  check "${PROJECT}/child"
  [ "$status" -eq 2 ]
  git -C "${PROJECT}" rev-parse --git-path MERGE_HEAD > /dev/null
  git -C "${PROJECT}" rev-parse HEAD > "${PROJECT}/.git/MERGE_HEAD"
  check "${PROJECT}"
  [ "$status" -eq 2 ]
}

@test "relative path and non-repository fail closed" {
  check "relative/project"
  [ "$status" -eq 2 ]
  check "${SANDBOX}"
  [ "$status" -eq 2 ]
}

@test "checker does not mutate repository files refs or Git metadata" {
  touch "${PROJECT}/README.md" "${PROJECT}/LICENSE" "${PROJECT}/AGENTS.md" "${PROJECT}/skills-lock.json" "${PROJECT}/.env.example" "${PROJECT}/.gitignore"
  git -C "${PROJECT}" add -A
  git -C "${PROJECT}" -c user.name=Fixture -c user.email=fixture@example.test commit -qm owned
  before="$(git -C "${PROJECT}" status --porcelain=v1; git -C "${PROJECT}" for-each-ref; sha256sum "${PROJECT}/.git/index" "${PROJECT}/.git/config" "${PROJECT}/README.md" "${PROJECT}/.gitignore")"
  check "${PROJECT}"
  [ "$status" -eq 0 ]
  after="$(git -C "${PROJECT}" status --porcelain=v1; git -C "${PROJECT}" for-each-ref; sha256sum "${PROJECT}/.git/index" "${PROJECT}/.git/config" "${PROJECT}/README.md" "${PROJECT}/.gitignore")"
  [ "$before" = "$after" ]
}
