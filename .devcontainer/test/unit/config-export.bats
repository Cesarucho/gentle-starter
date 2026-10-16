#!/usr/bin/env bats

setup() {
  REPOSITORY_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  HELPER="${REPOSITORY_ROOT}/.taskfiles/scripts/config-export.py"
  FIXTURE="$(mktemp -d)"
  HOME_FIXTURE="${FIXTURE}/home"
  REPO_FIXTURE="${FIXTURE}/repo"
  mkdir -p "${HOME_FIXTURE}/.config/opencode" "${HOME_FIXTURE}/.pi" \
    "${REPO_FIXTURE}/.devcontainer/config/opencode" "${REPO_FIXTURE}/.devcontainer/config/pi"
  cp "${BATS_TEST_DIRNAME}/../fixtures/config-export.json" \
    "${REPO_FIXTURE}/.devcontainer/config-export.json"
  INSTALL_FIXTURE="${REPO_FIXTURE}/.devcontainer/install"
  mkdir -p "${INSTALL_FIXTURE}/available" "${INSTALL_FIXTURE}/02-core-tools" \
    "${INSTALL_FIXTURE}/03-enabled" "${HOME_FIXTURE}/.pi/agent"
  local name
  for name in 3020-ai-gentle-ai.sh 3030-ai-pi-coding.sh 3040-ai-gentle-shell.sh; do
    printf '#!/bin/sh\nexit 99\n' >"${INSTALL_FIXTURE}/available/${name}"
  done
  ln -s ../available/3020-ai-gentle-ai.sh "${INSTALL_FIXTURE}/02-core-tools/3020-ai-gentle-ai.sh"
  ln -s ../available/3030-ai-pi-coding.sh "${INSTALL_FIXTURE}/03-enabled/7100-custom-coding.sh"
  : >"${INSTALL_FIXTURE}/dependencies.conf"
  printf 'FROM fixture AS core-tools\nCOPY install/available/3020-ai-gentle-ai.sh /tmp/\n' \
    >"${REPO_FIXTURE}/.devcontainer/Dockerfile"
}

# Read-only loader/filter tests do not need Git history. Export guards do.
initialize_git_fixture() {
  [ ! -d "${REPO_FIXTURE}/.git" ] || return 0
  git -C "${REPO_FIXTURE}" init -q
  git -C "${REPO_FIXTURE}" config user.name "Fixture"
  git -C "${REPO_FIXTURE}" config user.email "fixture@example.invalid"
}

teardown() {
  rm -rf "${FIXTURE}"
}

run_helper() {
  if [ "$1" = export ]; then
    initialize_git_fixture
  fi
  run env HOME="${FIXTURE}/forbidden-home" python3 "${HELPER}" "$1" \
    --repo "${REPO_FIXTURE}" --home "${HOME_FIXTURE}"
}

commit_fixture() {
  initialize_git_fixture
  git -C "${REPO_FIXTURE}" add .
  git -C "${REPO_FIXTURE}" commit -qm "$1"
}

@test "diff classifies equal modified new missing and candidate files" {
  mkdir -p "${HOME_FIXTURE}/.config/opencode/commands" \
    "${REPO_FIXTURE}/.devcontainer/config/opencode/commands"
  printf 'equal' >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  printf 'equal' >"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json"
  printf 'runtime' >"${HOME_FIXTURE}/.config/opencode/tui.json"
  printf 'seed' >"${REPO_FIXTURE}/.devcontainer/config/opencode/tui.json"
  printf 'new' >"${HOME_FIXTURE}/.config/opencode/commands/new.md"
  printf 'missing' >"${REPO_FIXTURE}/.devcontainer/config/opencode/AGENTS.md"
  printf 'candidate' >"${HOME_FIXTURE}/.config/opencode/unknown.txt"

  run_helper diff

  [ "$status" -eq 1 ]
  [[ "$output" == *"modified: OpenCode: tui.json"* ]]
  [[ "$output" == *"new: OpenCode: commands/new.md"* ]]
  [[ "$output" == *"missing-runtime: OpenCode: AGENTS.md"* ]]
  [[ "$output" == *"candidate: OpenCode: unknown.txt (file; runtime)"* ]]
  [[ "$output" == *"unchanged=1"* ]]
}

@test "diff exits zero when managed trees agree" {
  printf 'same' >"${HOME_FIXTURE}/.pi/agent-settings-placeholder"
  rm "${HOME_FIXTURE}/.pi/agent-settings-placeholder"

  run_helper diff

  [ "$status" -eq 0 ]
}

@test "export replaces settings byte for byte and never deletes missing runtime files" {
  mkdir -p "${HOME_FIXTURE}/.pi/agent" "${REPO_FIXTURE}/.devcontainer/config/pi/agent"
  printf '\x00runtime\r\nbytes' >"${HOME_FIXTURE}/.pi/agent/settings.json"
  printf 'old' >"${REPO_FIXTURE}/.devcontainer/config/pi/agent/settings.json"
  printf 'keep' >"${REPO_FIXTURE}/.devcontainer/config/pi/agent/mcp.json"
  commit_fixture "seed files"

  run_helper export

  [ "$status" -eq 0 ]
  cmp "${HOME_FIXTURE}/.pi/agent/settings.json" \
    "${REPO_FIXTURE}/.devcontainer/config/pi/agent/settings.json"
  [ "$(<"${REPO_FIXTURE}/.devcontainer/config/pi/agent/mcp.json")" = "keep" ]
  [[ "$output" == *"Review: git diff -- .devcontainer/config/opencode .devcontainer/config/pi"* ]]
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
  mkdir -p "${HOME_FIXTURE}/.pi/agent/generated/packages/deep"
  for index in $(seq 1 200); do
    printf 'generated' >"${HOME_FIXTURE}/.pi/agent/generated/packages/deep/${index}.json"
  done

  run_helper diff

  [ "$status" -eq 1 ]
  [[ "$output" == *"candidate: Pi Coding: generated (directory; runtime)"* ]]
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
  printf 'managed' >"${HOME_FIXTURE}/.pi/agent/settings.json"
  printf 'excluded' >"${HOME_FIXTURE}/.pi/agent/APPEND_SYSTEM.md"
  printf 'metadata' >"${HOME_FIXTURE}/.config/opencode/.gitignore"

  run_helper diff

  [ "$status" -eq 1 ]
  [[ "$output" == *"new: Pi Coding: settings.json"* ]]
  [[ "$output" == *"candidates=0"* ]]
  [[ "$output" != *"APPEND_SYSTEM.md"* ]]
  [[ "$output" != *"models-store"* ]]
  [[ "$output" != *"devcontainer-backup"* ]]
  [[ "$output" != *".gitignore"* ]]
}

@test "fixture secrets are excluded even when also managed" {
  mkdir -p "${HOME_FIXTURE}/.pi/agent"
  printf 'fixture-secret' >"${HOME_FIXTURE}/.config/opencode/auth.json"
  printf 'fixture-secret' >"${HOME_FIXTURE}/.pi/agent/auth.json"
  run_helper diff
  [ "$status" -eq 0 ]
  [[ "$output" == *"excluded-files=2"* ]]
  [[ "$output" != *"fixture-secret"* ]]
}

@test "consumer manifest cannot override mandatory JSONC exclusion" {
  python3 - "${REPO_FIXTURE}/.devcontainer/config-export.json" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text())
data["trees"][0]["excluded"].remove("opencode.jsonc")
data["trees"][0]["managed"].append("opencode.jsonc")
path.write_text(json.dumps(data))
PY
  printf '// consumer configuration\n{}' >"${HOME_FIXTURE}/.config/opencode/opencode.jsonc"
  run_helper diff
  [ "$status" -eq 0 ]
  [[ "$output" != *"new: OpenCode: opencode.jsonc"* ]]
  [[ "$output" == *"candidates=0"* ]]
}

@test "export refuses tracked staged and untracked seed changes" {
  printf 'base' >"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json"
  commit_fixture "tracked seed"
  printf 'tracked dirty' >"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json"
  run_helper export
  [ "$status" -eq 2 ]

  git -C "${REPO_FIXTURE}" checkout -q -- .devcontainer/config/opencode/opencode.json
  printf 'staged dirty' >"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json"
  git -C "${REPO_FIXTURE}" add .devcontainer/config/opencode/opencode.json
  run_helper export
  [ "$status" -eq 2 ]

  git -C "${REPO_FIXTURE}" reset -q --hard HEAD
  mkdir -p "${REPO_FIXTURE}/.devcontainer/config/pi/agent"
  printf 'untracked' >"${REPO_FIXTURE}/.devcontainer/config/pi/agent/agent-new.txt"
  run_helper export
  [ "$status" -eq 2 ]
}

@test "unrelated repository changes do not block export" {
  printf 'unrelated' >"${REPO_FIXTURE}/notes.txt"
  mkdir -p "${HOME_FIXTURE}/.pi/agent"
  printf 'new' >"${HOME_FIXTURE}/.pi/agent/settings.json"

  run_helper export

  [ "$status" -eq 0 ]
  [ "$(<"${REPO_FIXTURE}/.devcontainer/config/pi/agent/settings.json")" = "new" ]
}

@test "preflight rejects symlinks without partial writes" {
  mkdir -p "${HOME_FIXTURE}/.config/opencode" "${HOME_FIXTURE}/.pi/agent"
  printf 'new value' >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  printf 'old value' >"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json"
  ln -s /tmp "${HOME_FIXTURE}/.pi/agent/linked"
  commit_fixture "destination"

  run_helper export

  [ "$status" -eq 2 ]
  [ "$(<"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json")" = "old value" ]
}

@test "invalid later destination leaves all planned destinations unchanged" {
  mkdir -p "${HOME_FIXTURE}/.config/opencode/commands"
  printf 'runtime first' >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  printf 'runtime second' >"${HOME_FIXTURE}/.config/opencode/commands/new.md"
  printf 'seed first' >"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json"
  printf 'blocking file' >"${REPO_FIXTURE}/.devcontainer/config/opencode/commands"
  commit_fixture "two destination plan"

  run_helper export

  [ "$status" -eq 2 ]
  [ "$(<"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json")" = "seed first" ]
  [ "$(<"${REPO_FIXTURE}/.devcontainer/config/opencode/commands")" = "blocking file" ]
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
  printf 'new' >"${HOME_FIXTURE}/.config/opencode/tui.json"
  printf 'old' >"${REPO_FIXTURE}/.devcontainer/config/pi/agent-settings-placeholder"
  mkdir -p "${REPO_FIXTURE}/.devcontainer/config/pi/agent"
  mv "${REPO_FIXTURE}/.devcontainer/config/pi/agent-settings-placeholder" \
    "${REPO_FIXTURE}/.devcontainer/config/pi/agent/settings.json"
  chmod 0600 "${REPO_FIXTURE}/.devcontainer/config/pi/agent/settings.json"
  commit_fixture "mode seed"

  run_helper export

  [ "$status" -eq 0 ]
  [ "$(stat -c %a "${REPO_FIXTURE}/.devcontainer/config/pi/agent/settings.json")" = "600" ]
  [ "$(stat -c %a "${REPO_FIXTURE}/.devcontainer/config/opencode/tui.json")" = "644" ]
}

@test "task propagates the intentional diff exit code" {
  mkdir -p "${HOME_FIXTURE}/.pi/agent"
  printf 'candidate' >"${HOME_FIXTURE}/.pi/agent/other.json"

  run task --exit-code --dir "${REPOSITORY_ROOT}" config:diff -- \
    --repo "${REPO_FIXTURE}" --home "${HOME_FIXTURE}"

  [ "$status" -eq 1 ]
}

@test "both tasks use the shared manifest for new and modified notifier exports" {
  initialize_git_fixture
  local runtime="${HOME_FIXTURE}/.config/opencode"
  local seed="${REPO_FIXTURE}/.devcontainer/config/opencode"
  local state
  printf '{"legacy":true}\r\n' >"${runtime}/opencode.jsonc"
  cp "${runtime}/opencode.jsonc" "${FIXTURE}/legacy-before"

  for state in new modified; do
    printf '{"terminal":"ghostty","state":"%s"}\r\n' "$state" >"${runtime}/opencode-notifier.json"
    cp "${runtime}/opencode-notifier.json" "${FIXTURE}/notifier-before"

    run task --exit-code --dir "${REPOSITORY_ROOT}" config:diff -- \
      --repo "${REPO_FIXTURE}" --home "${HOME_FIXTURE}"
    [ "$status" -eq 1 ]
    [[ "$output" == *"${state}: OpenCode: opencode-notifier.json"* ]]
    [[ "$output" == *"candidates=0"* ]]
    [[ "$output" != *"OpenCode: opencode.jsonc"* ]]
    cmp "${FIXTURE}/notifier-before" "${runtime}/opencode-notifier.json"
    cmp "${FIXTURE}/legacy-before" "${runtime}/opencode.jsonc"

    run task --exit-code --dir "${REPOSITORY_ROOT}" config:export -- \
      --repo "${REPO_FIXTURE}" --home "${HOME_FIXTURE}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Exported: files=1"* ]]
    cmp "${FIXTURE}/notifier-before" "${seed}/opencode-notifier.json"
    cmp "${FIXTURE}/notifier-before" "${runtime}/opencode-notifier.json"
    cmp "${FIXTURE}/legacy-before" "${runtime}/opencode.jsonc"
    [ ! -e "${seed}/opencode.jsonc" ]
    commit_fixture "export ${state} notifier"

    run_helper diff
    [ "$status" -eq 0 ]
  done
}

@test "fixture JSONC exclusion prevents export without changing runtime bytes" {
  printf '{"legacy":true}\r\n' >"${HOME_FIXTURE}/.config/opencode/opencode.jsonc"
  cp "${HOME_FIXTURE}/.config/opencode/opencode.jsonc" "${FIXTURE}/legacy-before"

  run_helper diff
  [ "$status" -eq 0 ]
  [[ "$output" == *"excluded-files=1"* ]]
  [[ "$output" == *"candidates=0"* ]]

  run_helper export
  [ "$status" -eq 0 ]
  [[ "$output" == *"Exported: files=0"* ]]
  [ ! -e "${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.jsonc" ]
  cmp "${FIXTURE}/legacy-before" "${HOME_FIXTURE}/.config/opencode/opencode.jsonc"
}

@test "both tasks exclude telemetry while exporting another plugin" {
  local runtime="${HOME_FIXTURE}/.config/opencode" seed="${REPO_FIXTURE}/.devcontainer/config/opencode"
  mkdir -p "${runtime}/plugins" "${seed}/plugins"
  printf 'runtime telemetry' >"${runtime}/.gentle-ai-telemetry-runtime.json"
  printf 'runtime plugin' >"${runtime}/plugins/telemetry-runtime.ts"
  printf 'seed telemetry' >"${seed}/.gentle-ai-telemetry-runtime.json"
  printf 'seed plugin' >"${seed}/plugins/telemetry-runtime.ts"
  printf 'portable plugin' >"${runtime}/plugins/portable.ts"
  commit_fixture "seed telemetry"

  run_helper diff
  [ "$status" -eq 1 ]
  [[ "$output" == *"new: OpenCode: plugins/portable.ts"* ]]
  [[ "$output" == *"candidates=0"* ]]
  [[ "$output" != *"OpenCode: .gentle-ai-telemetry-runtime.json"* ]]
  [[ "$output" != *"OpenCode: plugins/telemetry-runtime.ts"* ]]
  run_helper export
  [ "$status" -eq 0 ]
  [[ "$output" == *"Exported: files=1"* ]]
  [ "$(<"${seed}/.gentle-ai-telemetry-runtime.json")" = "seed telemetry" ]
  [ "$(<"${seed}/plugins/telemetry-runtime.ts")" = "seed plugin" ]
  [ "$(<"${seed}/plugins/portable.ts")" = "portable plugin" ]
  [ "$(<"${runtime}/.gentle-ai-telemetry-runtime.json")" = "runtime telemetry" ]
  [ "$(<"${runtime}/plugins/telemetry-runtime.ts")" = "runtime plugin" ]
}

@test "missing telemetry runtime is not reported or deleted by either task" {
  local seed="${REPO_FIXTURE}/.devcontainer/config/opencode"
  mkdir -p "${seed}/plugins"
  printf 'seed telemetry' >"${seed}/.gentle-ai-telemetry-runtime.json"
  printf 'seed plugin' >"${seed}/plugins/telemetry-runtime.ts"
  commit_fixture "seed telemetry"

  run_helper diff
  [ "$status" -eq 0 ]
  [[ "$output" == *"candidates=0"* ]]
  [[ "$output" != *"missing-runtime: OpenCode"* ]]
  run_helper export
  [ "$status" -eq 0 ]
  [[ "$output" == *"Exported: files=0"* ]]
  [ "$(<"${seed}/.gentle-ai-telemetry-runtime.json")" = "seed telemetry" ]
  [ "$(<"${seed}/plugins/telemetry-runtime.ts")" = "seed plugin" ]
}

@test "excluded telemetry symlinks are skipped before inspection" {
  cp "${REPOSITORY_ROOT}/.devcontainer/config-export.json" "${REPO_FIXTURE}/.devcontainer/config-export.json"
  local runtime="${HOME_FIXTURE}/.config/opencode" seed="${REPO_FIXTURE}/.devcontainer/config/opencode"
  mkdir -p "${runtime}/plugins" "${seed}/plugins"
  local name
  for name in .gentle-ai-telemetry-runtime.json plugins/telemetry-runtime.ts; do
    ln -s "${FIXTURE}/must-not-read" "${runtime}/${name}"
    ln -s "${FIXTURE}/must-not-read" "${seed}/${name}"
  done
  commit_fixture "seed telemetry links"

  run_helper diff
  [ "$status" -eq 0 ]
  [[ "$output" == *"excluded-files=4"* ]]
  [[ "$output" != *"symlink is not allowed"* ]]
  run_helper export
  [ "$status" -eq 0 ]
  [[ "$output" == *"Exported: files=0"* ]]
  [ -L "${seed}/.gentle-ai-telemetry-runtime.json" ]
  [ -L "${seed}/plugins/telemetry-runtime.ts" ]
}

@test "production manifest rejects a missing Shell owner before runtime reads or export" {
  cp "${REPOSITORY_ROOT}/.devcontainer/config-export.json" "${REPO_FIXTURE}/.devcontainer/config-export.json"
  rm "${INSTALL_FIXTURE}/available/3040-ai-gentle-shell.sh"
  printf old >"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json"
  printf new >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  ln -s "${FIXTURE}/must-not-read" "${HOME_FIXTURE}/.config/opencode/unsafe"
  commit_fixture "missing owner"
  local action
  for action in diff export; do
    run_helper "${action}"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Gentle Shell owner is not in the installer catalog: 3040-ai-gentle-shell.sh"* ]]
    [[ "$output" != *"symlink is not allowed"* ]]
    [ "$(<"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json")" = old ]
  done
}

@test "production manifest exports recursive portable config and excludes nested state before reads" {
  cp "${REPOSITORY_ROOT}/.devcontainer/config-export.json" "${REPO_FIXTURE}/.devcontainer/config-export.json"
  local runtime="${HOME_FIXTURE}/.config/opencode" seed="${REPO_FIXTURE}/.devcontainer/config/opencode"
  local tree boundary
  printf 'portable\r\n' >"${runtime}/opencode-example.json"
  printf 'keep seed only' >"${seed}/opencode-example.json"
  for tree in commands plugins profiles prompts skills; do
    mkdir -p "${runtime}/${tree}/new/deep"
    printf 'portable' >"${runtime}/${tree}/new/deep/future.any"
  done
  printf 'runtime telemetry plugin' >"${runtime}/plugins/telemetry-runtime.ts"
  for boundary in .git node_modules state sessions logs cache caches profile-versions; do
    mkdir -p "${runtime}/skills/new/${boundary}"
    ln -s "${FIXTURE}/must-not-read" "${runtime}/skills/new/${boundary}/secret"
  done
  for boundary in .git auth.json credentials.json opencode.jsonc .gentle-ai-telemetry-runtime.json; do
    ln -s "${FIXTURE}/must-not-read" "${runtime}/plugins/${boundary}"
    mkdir -p "${seed}/plugins"
    ln -s "${FIXTURE}/must-not-read" "${seed}/plugins/${boundary}"
  done
  ln -s "${FIXTURE}/must-not-read" "${runtime}/opencode.jsonc"
  ln -s "${FIXTURE}/must-not-read" "${HOME_FIXTURE}/.pi/agent/.gentle-ai-telemetry-runtime.json"
  printf 'gitdir: private metadata' >"${runtime}/profiles/new/deep/.git"
  ln -s "${FIXTURE}/must-not-read" "${runtime}/prompts/new/node_modules"
  commit_fixture "excluded boundaries"

  run_helper diff
  [ "$status" -eq 1 ]
  [[ "$output" == *"modified: OpenCode: opencode-example.json"* ]]
  [[ "$output" != *"new: OpenCode: plugins/telemetry-runtime.ts"* ]]
  [[ "$output" == *"candidates=0"* ]]
  run_helper export
  [ "$status" -eq 0 ]
  [[ "$output" == *"Exported: files=6"* ]]
  [ ! -e "${seed}/plugins/telemetry-runtime.ts" ]
  cmp "${runtime}/opencode-example.json" "${seed}/opencode-example.json"
  for tree in commands plugins profiles prompts skills; do
    cmp "${runtime}/${tree}/new/deep/future.any" "${seed}/${tree}/new/deep/future.any"
  done
  [ ! -e "${seed}/skills/new/.git" ]
  [ -L "${seed}/plugins/.git" ]
  [ -L "${seed}/plugins/.gentle-ai-telemetry-runtime.json" ]
}

@test "candidate union includes seed files and deduplicates bounded paths on both sides" {
  local runtime="${HOME_FIXTURE}/.config/opencode" seed="${REPO_FIXTURE}/.devcontainer/config/opencode"
  local index
  for index in $(seq -w 1 60); do
    printf 'not inspected' >"${runtime}/unknown-${index}.json"
    printf 'not inspected' >"${seed}/unknown-${index}.json"
  done
  mkdir -p "${runtime}/unknown-dir" "${seed}/unknown-dir"
  ln -s "${FIXTURE}/missing" "${runtime}/unknown-dir/ignored-link"
  printf 'seed candidate' >"${seed}/seed-only.txt"
  commit_fixture "candidates"

  run_helper diff
  [ "$status" -eq 1 ]
  [[ "$output" == *"candidates=62"* ]]
  [[ "$output" == *"(file; runtime, seed)"* ]]
  [[ "$output" == *"Candidate output limited to 50 paths per tree"* ]]
  [ "$(printf '%s\n' "$output" | grep -c '^candidate:')" -eq 50 ]
  [[ "$output" != *"not inspected"* ]]
  run_helper export
  [ "$status" -eq 0 ]
  [[ "$output" == *"candidates=62"* ]]
  [[ "$output" == *"Exported: files=0"* ]]
  [ -f "${seed}/seed-only.txt" ]
}

@test "seed-only candidates are reported with their side and managed files are never deleted" {
  printf 'candidate' >"${REPO_FIXTURE}/.devcontainer/config/opencode/seed-only.json"
  printf 'portable' >"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode-non-sdd.json"
  commit_fixture "seed only"
  run_helper diff
  [ "$status" -eq 1 ]
  [[ "$output" == *"candidate: OpenCode: seed-only.json (file; seed)"* ]]
  [[ "$output" == *"missing-runtime: OpenCode: opencode-non-sdd.json"* ]]
  run_helper export
  [ "$status" -eq 0 ]
  [ "$(<"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode-non-sdd.json")" = portable ]
}

@test "disabled Pi skips unsafe runtime and dirty seed without blocking OpenCode" {
  rm "${INSTALL_FIXTURE}/03-enabled/7100-custom-coding.sh"
  rm -r "${HOME_FIXTURE}/.pi"
  ln -s "${FIXTURE}/missing" "${HOME_FIXTURE}/.pi"
  ln -s "${FIXTURE}/missing" "${REPO_FIXTURE}/.devcontainer/config/pi/agent"
  printf portable >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  run_helper diff
  [ "$status" -eq 1 ]
  [[ "$output" == *"skipped: Pi Coding: owner 3030-ai-pi-coding.sh is disabled"* ]]
  [[ "$output" == *"candidates=0"* ]]
  run_helper export
  [ "$status" -eq 0 ]
  [ "$(<"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json")" = portable ]
  [ -L "${REPO_FIXTURE}/.devcontainer/config/pi/agent" ]
  run_helper diff
  [ "$status" -eq 0 ]
}

@test "valid custom Pi alias participates without executing installers or binaries" {
  printf agent >"${HOME_FIXTURE}/.pi/agent/settings.json"
  run_helper diff
  [ "$status" -eq 1 ]
  [[ "$output" == *"new: Pi Coding: settings.json"* ]]
  run_helper export
  [ "$status" -eq 0 ]
  [[ "$output" == *"Exported: files=1"* ]]
  [ "$(<"${REPO_FIXTURE}/.devcontainer/config/pi/agent/settings.json")" = agent ]
}

@test "base Pi export never provisions legacy extension config or scans retired runtime tree" {
  mkdir -p "${HOME_FIXTURE}/.pi/gentle-ai"
  ln -s "${FIXTURE}/must-not-read" "${HOME_FIXTURE}/.pi/gentle-ai/unsafe"
  printf legacy >"${HOME_FIXTURE}/.pi/agent/mcp.json"
  printf legacy >"${HOME_FIXTURE}/.pi/agent/subagents.json"
  printf agent >"${HOME_FIXTURE}/.pi/agent/settings.json"
  run_helper export
  [ "$status" -eq 0 ]
  [ -e "${REPO_FIXTURE}/.devcontainer/config/pi/agent/settings.json" ]
  [ ! -e "${REPO_FIXTURE}/.devcontainer/config/pi/agent/mcp.json" ]
  [ ! -e "${REPO_FIXTURE}/.devcontainer/config/pi/agent/subagents.json" ]
  [ ! -e "${REPO_FIXTURE}/.devcontainer/config/pi/gentle-ai" ]
  [ -L "${HOME_FIXTURE}/.pi/gentle-ai/unsafe" ]
  [ "$(<"${HOME_FIXTURE}/.pi/agent/mcp.json")" = legacy ]
}

@test "invalid Pi selection errors before runtime inspection or writes" {
  printf old >"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json"
  commit_fixture "old config"
  printf new >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  rm "${INSTALL_FIXTURE}/03-enabled/7100-custom-coding.sh"
  ln -s ../available/missing.sh "${INSTALL_FIXTURE}/03-enabled/7100-custom-coding.sh"
  run_helper diff
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid or broken symlink"* ]]
  rm "${INSTALL_FIXTURE}/03-enabled/7100-custom-coding.sh"
  printf unsafe >"${FIXTURE}/outside.sh"
  ln -s "${FIXTURE}/outside.sh" "${INSTALL_FIXTURE}/03-enabled/7100-custom-coding.sh"
  run_helper export
  [ "$status" -eq 2 ]
  [[ "$output" == *"must target an available shell installer"* ]]
  [ "$(<"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json")" = old ]
}

@test "enabled missing runtime differs from disabled and never deletes the seed" {
  rm -r "${HOME_FIXTURE}/.pi/agent"
  mkdir -p "${REPO_FIXTURE}/.devcontainer/config/pi/agent"
  printf keep >"${REPO_FIXTURE}/.devcontainer/config/pi/agent/settings.json"
  commit_fixture "missing runtime"
  run_helper diff
  [ "$status" -eq 1 ]
  [[ "$output" == *"enabled-runtime-missing: Pi Coding"* ]]
  [[ "$output" == *"missing-runtime: Pi Coding: settings.json"* ]]
  run_helper export
  [ "$status" -eq 0 ]
  [ "$(<"${REPO_FIXTURE}/.devcontainer/config/pi/agent/settings.json")" = keep ]
  rm "${REPO_FIXTURE}/.devcontainer/config/pi/agent/settings.json"
  run_helper diff
  [ "$status" -eq 1 ]
  [[ "$output" == *"enabled-runtime-missing: Pi Coding"* ]]
}

@test "dirty participating Pi seed blocks export before unsafe runtime inspection" {
  mkdir -p "${REPO_FIXTURE}/.devcontainer/config/pi/agent"
  printf dirty >"${REPO_FIXTURE}/.devcontainer/config/pi/agent/settings.json"
  ln -s "${FIXTURE}/missing" "${HOME_FIXTURE}/.config/opencode/unsafe"
  printf new >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  run_helper export
  [ "$status" -eq 2 ]
  [[ "$output" == *"pending Git worktree or index changes"* ]]
  [[ "$output" != *"symlink is not allowed"* ]]
  [ ! -e "${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json" ]
}

@test "diff does not probe binaries and propagates permission and traversal failures" {
  run env PYTHONDONTWRITEBYTECODE=1 python3 - "${HELPER}" "${REPO_FIXTURE}" "${HOME_FIXTURE}" <<'PY'
import os
import runpy
import sys
from pathlib import Path
from unittest.mock import patch

helper, repo, home = sys.argv[1:]
main = runpy.run_path(helper)["main"]
sys.argv = [helper, "diff", "--repo", repo, "--home", home]
with patch("subprocess.run", side_effect=AssertionError("unexpected binary probe")):
    assert main() == 0
    original_stat = Path.lstat
    blocked = Path(home) / ".pi/agent"
    def deny_root(path, *args, **kwargs):
        if path == blocked:
            raise PermissionError("fixture root permission denied")
        return original_stat(path, *args, **kwargs)
    with patch.object(Path, "lstat", deny_root):
        assert main() == 2
    original_scan = os.scandir
    def deny_scan(path):
        if Path(path) == blocked:
            raise PermissionError("fixture traversal permission denied")
        return original_scan(path)
    with patch("os.scandir", deny_scan):
        assert main() == 2
PY
  [ "$status" -eq 0 ]
  [[ "$output" == *"fixture root permission denied"* ]]
  [[ "$output" == *"fixture traversal permission denied"* ]]
  [[ "$output" != *"enabled-runtime-missing"* ]]
}

@test "enabled seed ancestor symlink cannot redirect planned copies outside the seed" {
  printf old >"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json"
  printf new >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  printf agent >"${HOME_FIXTURE}/.pi/agent/settings.json"
  rmdir "${REPO_FIXTURE}/.devcontainer/config/pi"
  mkdir -p "${FIXTURE}/outside/agent"
  ln -s "${FIXTURE}/outside" "${REPO_FIXTURE}/.devcontainer/config/pi"
  commit_fixture "redirected seed ancestor"
  run_helper export
  [ "$status" -eq 2 ]
  [[ "$output" == *"seed selector escapes .devcontainer/config"* ]]
  [ "$(<"${REPO_FIXTURE}/.devcontainer/config/opencode/opencode.json")" = old ]
  [ ! -e "${FIXTURE}/outside/agent/settings.json" ]
}

select_profile_fixture() {
  local config="${REPO_FIXTURE}/.devcontainer/config"
  mv "${config}/opencode" "${config}/selected profile"
  ln -s "selected profile" "${config}/opencode"
  mkdir -p "${config}/inactive-profile"
  printf inactive >"${config}/inactive-profile/opencode.json"
}

@test "both tasks use the selected profile and preserve selectors runtime and inactive profiles" {
  local config="${REPO_FIXTURE}/.devcontainer/config"
  select_profile_fixture
  printf old >"${config}/selected profile/opencode.json"
  chmod 0600 "${config}/selected profile/opencode.json"
  printf 'runtime\r\n' >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  commit_fixture "profile selector"
  local before action
  before="$(sha256sum "${HOME_FIXTURE}/.config/opencode/opencode.json" "${config}/inactive-profile/opencode.json")"
  for action in diff export; do
    run task --exit-code --dir "${REPOSITORY_ROOT}" "config:${action}" -- \
      --repo "${REPO_FIXTURE}" --home "${HOME_FIXTURE}"
    if [ "${action}" = diff ]; then
      [ "$status" -eq 1 ]
      [[ "$output" == *"modified: OpenCode: opencode.json"* ]]
      [ "$(cat "${config}/selected profile/opencode.json")" = old ]
    else
      [ "$status" -eq 0 ]
      [[ "$output" == *"Exported: files=1"* ]]
      [[ "$output" == *"Review: git diff -- '.devcontainer/config/selected profile'"* ]]
      cmp "${HOME_FIXTURE}/.config/opencode/opencode.json" "${config}/selected profile/opencode.json"
      [ "$(stat -c %a "${config}/selected profile/opencode.json")" = 600 ]
    fi
    [ -L "${config}/opencode" ]
    [ "$(readlink "${config}/opencode")" = 'selected profile' ]
    [ "$(sha256sum "${HOME_FIXTURE}/.config/opencode/opencode.json" "${config}/inactive-profile/opencode.json")" = "${before}" ]
  done
}

@test "selected profile tracked staged and untracked changes block export before runtime inspection" {
  local config="${REPO_FIXTURE}/.devcontainer/config" state
  select_profile_fixture
  printf old >"${config}/selected profile/opencode.json"
  commit_fixture "selected profile baseline"
  ln -s "${FIXTURE}/must-not-read" "${HOME_FIXTURE}/.config/opencode/unsafe"
  for state in tracked staged untracked; do
    printf dirty >"${config}/selected profile/opencode.json"
    if [ "${state}" = staged ]; then
      git -C "${REPO_FIXTURE}" add '.devcontainer/config/selected profile/opencode.json'
    elif [ "${state}" = untracked ]; then
      git -C "${REPO_FIXTURE}" checkout -q -- '.devcontainer/config/selected profile/opencode.json'
      printf new >"${config}/selected profile/new.txt"
    fi
    run_helper export
    [ "$status" -eq 2 ]
    [[ "$output" == *"pending Git worktree or index changes"* ]]
    [[ "$output" != *"symlink is not allowed"* ]]
    git -C "${REPO_FIXTURE}" reset -q --hard HEAD
  done
}

@test "changed root and intermediate selectors block export but inactive profile edits do not" {
  local config="${REPO_FIXTURE}/.devcontainer/config" selector
  select_profile_fixture
  rm "${config}/opencode"
  ln -s 'selected profile' "${config}/intermediate"
  ln -s intermediate "${config}/opencode"
  commit_fixture "selector chain"
  printf new >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  for selector in opencode intermediate; do
    rm "${config}/${selector}"
    ln -s inactive-profile "${config}/${selector}"
    run_helper export
    [ "$status" -eq 2 ]
    [[ "$output" == *"pending Git worktree or index changes"* ]]
    [ ! -e "${config}/selected profile/opencode.json" ]
    git -C "${REPO_FIXTURE}" checkout -q -- ".devcontainer/config/${selector}"
  done
  printf unrelated >"${config}/inactive-profile/opencode.json"
  run_helper export
  [ "$status" -eq 0 ]
  [ "$(cat "${config}/selected profile/opencode.json")" = new ]
  [ "$(cat "${config}/inactive-profile/opencode.json")" = unrelated ]
}

@test "ancestor selectors resolve active subtrees and protect ancestor selection changes" {
  local config="${REPO_FIXTURE}/.devcontainer/config"
  mv "${config}/pi" "${config}/pi-profile"
  ln -s pi-profile "${config}/pi"
  mkdir -p "${config}/pi-profile/agent"
  printf old >"${config}/pi-profile/agent/settings.json"
  printf new >"${HOME_FIXTURE}/.pi/agent/settings.json"
  commit_fixture "ancestor selector"
  run_helper diff
  [ "$status" -eq 1 ]
  [[ "$output" == *"modified: Pi Coding: settings.json"* ]]
  run_helper export
  [ "$status" -eq 0 ]
  [ "$(cat "${config}/pi-profile/agent/settings.json")" = new ]
  commit_fixture "export active subtree"
  mkdir -p "${config}/other-pi/agent"
  rm "${config}/pi"
  ln -s other-pi "${config}/pi"
  run_helper export
  [ "$status" -eq 2 ]
  [[ "$output" == *"pending Git worktree or index changes"* ]]
  [ ! -e "${config}/other-pi/agent/settings.json" ]
}

@test "invalid root selectors refuse both tasks without changing any destinations" {
  local config="${REPO_FIXTURE}/.devcontainer/config" target action
  printf old >"${config}/pi/keep"
  printf new >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  printf file >"${config}/plain-file"
  mkdir -p "${FIXTURE}/outside" "${REPO_FIXTURE}/outside-config"
  printf external >"${FIXTURE}/outside/opencode.json"
  rmdir "${config}/opencode"
  for target in missing plain-file "${FIXTURE}/outside" ../../outside-config opencode; do
    ln -s "${target}" "${config}/opencode"
    commit_fixture "invalid selector ${target}"
    local before
    before="$(sha256sum "${config}/pi/keep" "${FIXTURE}/outside/opencode.json" "${HOME_FIXTURE}/.config/opencode/opencode.json")"
    for action in diff export; do
      run_helper "${action}"
      [ "$status" -eq 2 ]
      [[ "$output" == *"seed selector"* ]]
      [ "$(sha256sum "${config}/pi/keep" "${FIXTURE}/outside/opencode.json" "${HOME_FIXTURE}/.config/opencode/opencode.json")" = "${before}" ]
      [ -L "${config}/opencode" ]
    done
    rm "${config}/opencode"
  done
}

@test "selected profiles still reject internal and runtime links before any export" {
  local config="${REPO_FIXTURE}/.devcontainer/config" side action root
  select_profile_fixture
  printf old >"${config}/selected profile/opencode.json"
  printf new >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  for side in seed runtime; do
    root="${config}/selected profile"
    [ "${side}" = seed ] || root="${HOME_FIXTURE}/.config/opencode"
    ln -s "${FIXTURE}/must-not-read" "${root}/linked"
    commit_fixture "internal link ${side}"
    for action in diff export; do
      run_helper "${action}"
      [ "$status" -eq 2 ]
      [[ "$output" == *"symlink is not allowed"* ]]
      [ "$(cat "${config}/selected profile/opencode.json")" = old ]
    done
    rm "${root}/linked"
  done
}

@test "generic selector destinations collide before export creates files" {
  local config="${REPO_FIXTURE}/.devcontainer/config"
  mkdir -p "${config}/shared-profile"
  ln -s shared-profile "${config}/example-tool"
  ln -s "${config}/shared-profile" "${config}/future-tool"
  python3 - "${REPO_FIXTURE}/.devcontainer/config-export.json" <<'PY'
import json
import sys
from pathlib import Path

trees = [
    {"name": name, "seed": f".devcontainer/config/{name}", "runtime": runtime,
     "managed": ["settings.json"], "excluded": []}
    for name, runtime in (("example-tool", ".config/opencode"), ("future-tool", ".pi/agent"))
]
Path(sys.argv[1]).write_text(json.dumps({"version": 1, "trees": trees}))
PY
  printf first >"${HOME_FIXTURE}/.config/opencode/settings.json"
  printf second >"${HOME_FIXTURE}/.pi/agent/settings.json"
  commit_fixture "generic profile aliases"
  run_helper diff
  [ "$status" -eq 1 ]
  [[ "$output" == *"new: example-tool: settings.json"* ]]
  [[ "$output" == *"new: future-tool: settings.json"* ]]
  run_helper export
  [ "$status" -eq 2 ]
  [[ "$output" == *"destination collision"* ]]
  [ ! -e "${config}/shared-profile/settings.json" ]
  [ "$(cat "${HOME_FIXTURE}/.config/opencode/settings.json")" = first ]
  [ "$(cat "${HOME_FIXTURE}/.pi/agent/settings.json")" = second ]
}

@test "disabled ancestor selectors are skipped and active profile subtrees can be created" {
  local config="${REPO_FIXTURE}/.devcontainer/config"
  rm "${INSTALL_FIXTURE}/03-enabled/7100-custom-coding.sh"
  rmdir "${config}/pi"
  ln -s "${FIXTURE}/must-not-read" "${config}/pi"
  select_profile_fixture
  printf new >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  commit_fixture "disabled selector"
  run_helper export
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped: Pi Coding"* ]]
  [ "$(cat "${config}/selected profile/opencode.json")" = new ]
  [ -L "${config}/pi" ]
  commit_fixture "export selected profile"
  rm "${config}/pi"
  mkdir -p "${config}/pi-profile"
  ln -s pi-profile "${config}/pi"
  ln -s ../available/3030-ai-pi-coding.sh "${INSTALL_FIXTURE}/03-enabled/7100-custom-coding.sh"
  printf agent >"${HOME_FIXTURE}/.pi/agent/settings.json"
  commit_fixture "enabled selector with missing subtree"
  run_helper export
  [ "$status" -eq 0 ]
  [ "$(cat "${config}/pi-profile/agent/settings.json")" = agent ]
  [ "$(stat -c %a "${config}/pi-profile/agent/settings.json")" = 644 ]
  [ -L "${config}/pi" ]
}

@test "finite ancestor selector chain may revisit a selector without looping" {
  local config="${REPO_FIXTURE}/.devcontainer/config"
  rmdir "${config}/opencode"
  mkdir -p "${config}/active/subdir"
  ln -s active "${config}/opencode"
  ln -s ../opencode/subdir "${config}/active/agent"
  printf old >"${config}/active/subdir/opencode.json"
  printf new >"${HOME_FIXTURE}/.config/opencode/opencode.json"
  python3 - "${REPO_FIXTURE}/.devcontainer/config-export.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
data["trees"][0]["seed"] = ".devcontainer/config/opencode/agent"
path.write_text(json.dumps(data))
PY
  commit_fixture "finite selector chain"
  run_helper diff
  [ "$status" -eq 1 ]
  [[ "$output" == *"modified: OpenCode: opencode.json"* ]]
  [ "$(cat "${config}/active/subdir/opencode.json")" = old ]
  run_helper export
  [ "$status" -eq 0 ]
  [ "$(cat "${config}/active/subdir/opencode.json")" = new ]
  [ "$(readlink "${config}/opencode")" = active ]
  [ "$(readlink "${config}/active/agent")" = ../opencode/subdir ]
  [[ "$output" == *"Review: git diff -- .devcontainer/config/active/subdir "* ]]
}
