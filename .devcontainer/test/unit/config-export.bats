#!/usr/bin/env bats

setup() {
  REPOSITORY_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  HELPER="${REPOSITORY_ROOT}/.taskfiles/scripts/config-export.py"
  FIXTURE="$(mktemp -d)"
  HOME_FIXTURE="${FIXTURE}/home"
  REPO_FIXTURE="${FIXTURE}/repo"
  mkdir -p "${HOME_FIXTURE}/.config/opencode" "${HOME_FIXTURE}/.pi" \
    "${REPO_FIXTURE}/.devcontainer/opencode-config" "${REPO_FIXTURE}/.devcontainer/pi-config"
  cp "${REPOSITORY_ROOT}/.devcontainer/config-export.json" \
    "${REPO_FIXTURE}/.devcontainer/config-export.json"
  git -C "${REPO_FIXTURE}" init -q
  git -C "${REPO_FIXTURE}" config user.name "Fixture"
  git -C "${REPO_FIXTURE}" config user.email "fixture@example.invalid"
  git -C "${REPO_FIXTURE}" add .
  git -C "${REPO_FIXTURE}" commit -qm "fixture"
}

teardown() {
  rm -rf "${FIXTURE}"
}

run_helper() {
  run env HOME="${FIXTURE}/forbidden-home" python3 "${HELPER}" "$1" \
    --repo "${REPO_FIXTURE}" --home "${HOME_FIXTURE}"
}

commit_fixture() {
  git -C "${REPO_FIXTURE}" add .
  git -C "${REPO_FIXTURE}" commit -qm "$1"
}

@test "diff classifies equal modified new missing and candidate files" {
  mkdir -p "${HOME_FIXTURE}/.config/opencode/commands" \
    "${REPO_FIXTURE}/.devcontainer/opencode-config/commands"
  printf 'equal' >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  printf 'equal' >"${REPO_FIXTURE}/.devcontainer/opencode-config/opencode.json"
  printf 'runtime' >"${HOME_FIXTURE}/.config/opencode/tui.json"
  printf 'seed' >"${REPO_FIXTURE}/.devcontainer/opencode-config/tui.json"
  printf 'new' >"${HOME_FIXTURE}/.config/opencode/commands/new.md"
  printf 'missing' >"${REPO_FIXTURE}/.devcontainer/opencode-config/AGENTS.md"
  printf 'candidate' >"${HOME_FIXTURE}/.config/opencode/unknown.txt"

  run_helper diff

  [ "$status" -eq 1 ]
  [[ "$output" == *"modified: OpenCode: tui.json"* ]]
  [[ "$output" == *"new: OpenCode: commands/new.md"* ]]
  [[ "$output" == *"missing-runtime: OpenCode: AGENTS.md"* ]]
  [[ "$output" == *"candidate: OpenCode: unknown.txt (file)"* ]]
  [[ "$output" == *"unchanged=1"* ]]
}

@test "diff exits zero when managed trees agree" {
  printf 'same' >"${HOME_FIXTURE}/.pi/agent-settings-placeholder"
  rm "${HOME_FIXTURE}/.pi/agent-settings-placeholder"

  run_helper diff

  [ "$status" -eq 0 ]
}

@test "export replaces settings byte for byte and never deletes missing runtime files" {
  mkdir -p "${HOME_FIXTURE}/.pi/agent" "${REPO_FIXTURE}/.devcontainer/pi-config/agent"
  printf '\x00runtime\r\nbytes' >"${HOME_FIXTURE}/.pi/agent/settings.json"
  printf 'old' >"${REPO_FIXTURE}/.devcontainer/pi-config/agent/settings.json"
  printf 'keep' >"${REPO_FIXTURE}/.devcontainer/pi-config/agent/mcp.json"
  commit_fixture "seed files"

  run_helper export

  [ "$status" -eq 0 ]
  cmp "${HOME_FIXTURE}/.pi/agent/settings.json" \
    "${REPO_FIXTURE}/.devcontainer/pi-config/agent/settings.json"
  [ "$(<"${REPO_FIXTURE}/.devcontainer/pi-config/agent/mcp.json")" = "keep" ]
  [[ "$output" == *"Review: git diff -- .devcontainer/opencode-config .devcontainer/pi-config"* ]]
}

@test "exclusions override managed paths and summarize a large tree" {
  mkdir -p "${HOME_FIXTURE}/.config/opencode/profile-versions/generated"
  for index in $(seq 1 200); do
    printf 'secret' >"${HOME_FIXTURE}/.config/opencode/profile-versions/generated/${index}.json"
  done

  run_helper diff

  [ "$status" -eq 0 ]
  [[ "$output" == *"excluded-directories=1"* ]]
  [[ "$output" != *"1.json"* ]]
}

@test "unknown candidate directories are reported once without traversal" {
  mkdir -p "${HOME_FIXTURE}/.pi/generated/packages/deep"
  for index in $(seq 1 200); do
    printf 'generated' >"${HOME_FIXTURE}/.pi/generated/packages/deep/${index}.json"
  done

  run_helper diff

  [ "$status" -eq 1 ]
  [[ "$output" == *"candidate: Pi: generated (directory)"* ]]
  [[ "$output" == *"candidates=1"* ]]
  [[ "$output" != *"packages"* ]]
  [[ "$output" != *"1.json"* ]]
}

@test "generated Pi state and OpenCode Git metadata are excluded" {
  mkdir -p "${HOME_FIXTURE}/.pi/agent/state" \
    "${HOME_FIXTURE}/.pi/agent/sessions" \
    "${HOME_FIXTURE}/.pi/agent/intercom" \
    "${HOME_FIXTURE}/.pi/agent/bin" \
    "${HOME_FIXTURE}/.pi/agent/chains" \
    "${HOME_FIXTURE}/.pi/agent/agents" \
    "${HOME_FIXTURE}/.pi/agent/gentle-ai" \
    "${HOME_FIXTURE}/.pi/agent/pi-pretty"
  printf 'state' >"${HOME_FIXTURE}/.pi/agent/state/data.json"
  printf 'state' >"${HOME_FIXTURE}/.pi/agent/sessions/data.json"
  printf 'state' >"${HOME_FIXTURE}/.pi/agent/intercom/data.json"
  printf 'state' >"${HOME_FIXTURE}/.pi/agent/bin/tool"
  printf 'state' >"${HOME_FIXTURE}/.pi/agent/chains/data.json"
  printf 'state' >"${HOME_FIXTURE}/.pi/agent/agents/data.json"
  printf 'state' >"${HOME_FIXTURE}/.pi/agent/gentle-ai/data.json"
  printf 'state' >"${HOME_FIXTURE}/.pi/agent/pi-pretty/data.json"
  printf 'state' >"${HOME_FIXTURE}/.pi/agent/models-store.json"
  printf 'state' >"${HOME_FIXTURE}/.pi/agent/mcp-cache.json"
  printf 'state' >"${HOME_FIXTURE}/.pi/agent/mcp-npx-cache.json"
  printf 'state' >"${HOME_FIXTURE}/.pi/agent/mcp.json.devcontainer-backup.20260902"
  printf 'managed' >"${HOME_FIXTURE}/.pi/agent/subagents.json"
  printf 'excluded' >"${HOME_FIXTURE}/.pi/agent/APPEND_SYSTEM.md"
  printf 'metadata' >"${HOME_FIXTURE}/.config/opencode/.gitignore"

  run_helper diff

  [ "$status" -eq 1 ]
  [[ "$output" == *"new: Pi: agent/subagents.json"* ]]
  [[ "$output" == *"candidates=0"* ]]
  [[ "$output" != *"APPEND_SYSTEM.md"* ]]
  [[ "$output" != *"models-store"* ]]
  [[ "$output" != *"devcontainer-backup"* ]]
  [[ "$output" != *".gitignore"* ]]
}

@test "export refuses tracked staged and untracked seed changes" {
  printf 'base' >"${REPO_FIXTURE}/.devcontainer/opencode-config/opencode.json"
  commit_fixture "tracked seed"
  printf 'tracked dirty' >"${REPO_FIXTURE}/.devcontainer/opencode-config/opencode.json"
  run_helper export
  [ "$status" -eq 2 ]

  git -C "${REPO_FIXTURE}" checkout -q -- .devcontainer/opencode-config/opencode.json
  printf 'staged dirty' >"${REPO_FIXTURE}/.devcontainer/opencode-config/opencode.json"
  git -C "${REPO_FIXTURE}" add .devcontainer/opencode-config/opencode.json
  run_helper export
  [ "$status" -eq 2 ]

  git -C "${REPO_FIXTURE}" reset -q --hard HEAD
  printf 'untracked' >"${REPO_FIXTURE}/.devcontainer/pi-config/agent-new.txt"
  run_helper export
  [ "$status" -eq 2 ]
}

@test "unrelated repository changes do not block export" {
  printf 'unrelated' >"${REPO_FIXTURE}/notes.txt"
  mkdir -p "${HOME_FIXTURE}/.pi/agent"
  printf 'new' >"${HOME_FIXTURE}/.pi/agent/mcp.json"

  run_helper export

  [ "$status" -eq 0 ]
  [ "$(<"${REPO_FIXTURE}/.devcontainer/pi-config/agent/mcp.json")" = "new" ]
}

@test "preflight rejects symlinks without partial writes" {
  mkdir -p "${HOME_FIXTURE}/.config/opencode" "${HOME_FIXTURE}/.pi/agent"
  printf 'new value' >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  printf 'old value' >"${REPO_FIXTURE}/.devcontainer/opencode-config/opencode.json"
  ln -s /tmp "${HOME_FIXTURE}/.pi/agent/linked"
  commit_fixture "destination"

  run_helper export

  [ "$status" -eq 2 ]
  [ "$(<"${REPO_FIXTURE}/.devcontainer/opencode-config/opencode.json")" = "old value" ]
}

@test "invalid later destination leaves all planned destinations unchanged" {
  mkdir -p "${HOME_FIXTURE}/.config/opencode/commands"
  printf 'runtime first' >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  printf 'runtime second' >"${HOME_FIXTURE}/.config/opencode/commands/new.md"
  printf 'seed first' >"${REPO_FIXTURE}/.devcontainer/opencode-config/opencode.json"
  printf 'blocking file' >"${REPO_FIXTURE}/.devcontainer/opencode-config/commands"
  commit_fixture "two destination plan"

  run_helper export

  [ "$status" -eq 2 ]
  [ "$(<"${REPO_FIXTURE}/.devcontainer/opencode-config/opencode.json")" = "seed first" ]
  [ "$(<"${REPO_FIXTURE}/.devcontainer/opencode-config/commands")" = "blocking file" ]
  [[ "$output" == *"destination ancestor is not a real directory"* ]]
}

@test "preflight rejects special managed files" {
  mkdir -p "${HOME_FIXTURE}/.pi/agent"
  mkfifo "${HOME_FIXTURE}/.pi/agent/settings.json"

  run_helper diff

  [ "$status" -eq 2 ]
  [[ "$output" == *"non-regular file"* ]]
}

@test "manifest rejects traversal and absolute paths" {
  python3 - "${REPO_FIXTURE}/.devcontainer/config-export.json" <<'PY'
import json
import sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["trees"][0]["managed"].append("../secret")
json.dump(data, open(path, "w", encoding="utf-8"))
PY
  run_helper diff
  [ "$status" -eq 2 ]

  python3 - "${REPO_FIXTURE}/.devcontainer/config-export.json" <<'PY'
import json
import sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["trees"][0]["managed"][-1] = "/etc/passwd"
json.dump(data, open(path, "w", encoding="utf-8"))
PY
  run_helper diff
  [ "$status" -eq 2 ]
}

@test "export preserves existing mode and gives new files mode 0644" {
  mkdir -p "${HOME_FIXTURE}/.pi/agent"
  printf 'replacement' >"${HOME_FIXTURE}/.pi/agent/settings.json"
  printf 'new' >"${HOME_FIXTURE}/.pi/agent/mcp.json"
  printf 'old' >"${REPO_FIXTURE}/.devcontainer/pi-config/agent-settings-placeholder"
  mkdir -p "${REPO_FIXTURE}/.devcontainer/pi-config/agent"
  mv "${REPO_FIXTURE}/.devcontainer/pi-config/agent-settings-placeholder" \
    "${REPO_FIXTURE}/.devcontainer/pi-config/agent/settings.json"
  chmod 0600 "${REPO_FIXTURE}/.devcontainer/pi-config/agent/settings.json"
  commit_fixture "mode seed"

  run_helper export

  [ "$status" -eq 0 ]
  [ "$(stat -c %a "${REPO_FIXTURE}/.devcontainer/pi-config/agent/settings.json")" = "600" ]
  [ "$(stat -c %a "${REPO_FIXTURE}/.devcontainer/pi-config/agent/mcp.json")" = "644" ]
}

@test "task propagates the intentional diff exit code" {
  mkdir -p "${HOME_FIXTURE}/.pi/agent"
  printf 'candidate' >"${HOME_FIXTURE}/.pi/agent/other.json"

  run task --exit-code --dir "${REPOSITORY_ROOT}" config:diff -- \
    --repo "${REPO_FIXTURE}" --home "${HOME_FIXTURE}"

  [ "$status" -eq 1 ]
}
