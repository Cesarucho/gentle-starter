# Starter compose defaults

## Goal

Future candidate trees activate only the base and core-tools Compose paths in `dockerComposeFile`, retaining every other committed entry as a JSONC comment. Producer selections and working-tree bytes remain unchanged.

## Scope and guardrails

- Branch: `feat/starter-compose-defaults`, starting at `7c0d820`.
- Do not edit, stage, or commit `.devcontainer/devcontainer.json` (user-owned SSH-agent/audio edits).
- Transform only the committed source blob in the private candidate index; do not create a candidate or touch remote refs in this worktree.
- Fail closed on ambiguous or malformed JSONC, missing/duplicate required entries, or unsupported entry layouts. Keep unrelated configuration and comments intact.
- Leave all task/code/test changes unstaged and uncommitted until VS Code review and explicit approval.

## Work unit

- [x] Implement deterministic candidate-only JSONC compose filtering with strict validation.
- [x] Add scratch-repository tests for active/commented/unknown optional entries, rejected input before refs, repeated candidate and promotion, and producer-byte preservation.
- [x] Run focused and safe full suite, syntax/lint, and `git diff --check`; record exact results and caveats.
- [x] Repair pre-existing isolated Compose-manifest fixtures without changing producer selection or relaxing the two-core-only assertion.

## Verification evidence

- `bats .maintainer/test/unit/starter-distribution.bats`: 24/24 pass (scratch repositories only).
- `task --taskfile .maintainer/Taskfile.yml test:starter`: unit 488/489 pass; `isolated Compose manifest contracts` fails because the pre-existing user edits activate SSH-agent and audio while its default-selection assertion expects only base/core; its `test_task_up_prepares_after_env_and_passes_creation_identity` also fails because the fixture lacks `.taskfiles/scripts/locale-env.py`. Task stops before integration.
- `bats .devcontainer/test/integration/tools.bats`: 34/34 reported OK (disabled tools and unset runtime phase intentionally skipped).
- `python3 -m py_compile` for source, candidate, and promote scripts; `git diff --check`; `markdownlint-cli2 odd/tasks/starter-compose-defaults.md`: pass. Plain `bash -n` cannot parse Bats `@test` syntax; Bats executed successfully.
- Fixture correction: the default-selection test now supplies a deterministic base/core JSONC selection with optional entries commented, rather than copying the user-edited producer file; the task-up fixture now includes `locale-env.py`, which `ensure-identity-env` invokes. `python3 .devcontainer/test/unit/compose-manifest-test.py ManifestTests.test_default_selection_keeps_core_active_and_optional_overrides_disabled ManifestTests.test_task_up_prepares_after_env_and_passes_creation_identity`: 2/2 pass. `task --taskfile .maintainer/Taskfile.yml test:starter:unit`: 489/489 pass; fixture-only unit suite, no Docker build or lifecycle proof.
- Primary worktree refs remain at `7c0d820`; only the pre-existing SSH-agent/audio diff remains in the user-owned devcontainer file. No primary candidate, release, remote action, Docker build, staging, or commit.

## Caveats

- Unsupported JSONC entry layouts intentionally fail closed rather than risking lost overrides. Consumer-customized compose files may still require manual conflict resolution during future merges.
- The earlier general-unit failures were pre-existing fixture issues, not publication-rule failures; both are now resolved in the isolated tests. The prior `test:starter` run stopped before integration; this correction verifies its unit portion only.

## Rollback boundary

Remove the private-index transformation and its fixture tests; the producer file is not part of the work unit. No commit is authorized yet.
