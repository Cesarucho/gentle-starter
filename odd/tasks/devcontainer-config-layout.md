# Devcontainer configuration layout

## Objective

Relocate versioned devcontainer configuration trees beneath
`.devcontainer/config/` while preserving their runtime behavior.

## Problem and why

The current flat `<tool>-config` directories make configuration ownership harder
to scan as more managed tools are added. A single configuration root makes the
repository layout explicit without changing configuration content or lifecycle
semantics.

## Authorized scope

CFG-01 moved `.devcontainer/{compose-config,opencode-config,pi-config,ssh-config}`
to `.devcontainer/config/{compose,opencode,pi,ssh}`. The user now authorizes only
CFG-02: migrate the eleven test/fixture paths listed below and update this tracker.
Runtime source/configuration and CFG-03 documentation/skills are out of scope.

## Constraints

- This is a path-only migration.
- Preserve Compose ordering and file content except for required path literals.
- Do not change mount targets, `.env.d` locations, lifecycle semantics, runtime
  source/configuration, user documentation, or skills.
- Preserve unrelated working-tree changes if present.
- Technical artifacts are English.
- Verification: ordinary before/after functional checks; strict TDD is off for
  CFG-02 by explicit current user choice. Runner: Bats/Python unittest. No
  repository/global TDD configuration changes or strict RED/GREEN claims.
- Delivery strategy: `exception-ok`; the user approved `size:exception` for one
  feature delivery with separate work-unit commits and no chain strategy.

## Delivery strategy and route

Selected route: delegated CFG-02 implementation and bounded local verification;
eleven nontrivial test/fixture files justify the delegated work unit. The user
authorized the CFG-02 local commit under `exception-ok`. Initial forecast was
245–265 authored CFG-02 lines, or 432–452 combined with CFG-01's +163/-24.
The approximately 400-line budget is advisory, not a reason to omit evidence.
No push, PR, merge, native review command, or pending-lineage mutation.
The user explicitly authorized branch-first creation of
`feat/devcontainer-config-layout` from the current CFG-01 HEAD because local
`origin/HEAD` points to `dev`. The absent branch was created with `git switch -c`;
HEAD, worktree diff, and index diff were verified unchanged by the switch.
Review `review-49d9ff8415aad1c5` remains pending; no approval is claimed.
No installs, network, real sudo, Docker, build, or container lifecycle operations.
Temporary fixture Git repositories/commits/config/reset and fixture exports are
authorized test effects; primary-repository destructive commands are not.

## Stable checklist

### CFG-01 — Runtime and path migration

- [x] Move the four configuration trees with Git-aware moves.
- [x] Update only declared runtime/config path literals.
- [x] Preserve Compose order, file content, mount targets, `.env.d`, and lifecycle
  behavior.
- [x] Run focused safe checks and record observed outcomes.
- [x] Commit this work unit: `264f6e274345a1b80aca84919f41a827c4582182`
  (`refactor(devcontainer): relocate configuration trees`).

### CFG-02 — Tests

- [ ] Update and run affected fixtures/tests for the new configuration layout.
- [x] Implement the eleven mapped fixture/test path migrations.
- [x] Record ordinary before/after authorized checks and remaining proof gaps.
- [x] Resolve delivery scope: user-approved `size:exception`, `exception-ok`,
  single feature delivery, separate work-unit commits, no chain strategy.
- [ ] Commit authorized CFG-02; exact hash and completion are recorded in the
  post-commit Engram mirror. Reconcile this checkbox during the next task.

### CFG-03 — Documentation and skill

- [ ] Update user-facing documentation and the relevant skill for the new layout.

## Acceptance criteria

- The canonical trees are `.devcontainer/config/{compose,opencode,pi,ssh}`.
- All CFG-01 runtime/config references resolve to those trees.
- `dockerComposeFile` selection preserves its original order.
- Compose fragment content is unchanged except where a path literal requires it.
- No mount target, `.env.d` path, or lifecycle behavior changes.
- The scoped stale-name search has no remaining old configuration-directory names
  in changed CFG-01 runtime/config files.
- Applicable focused checks pass, or unavailable checks are reported accurately.

## Applicable checks

Before execution, inspect repository task definitions. Expected narrow checks are
the scoped stale-name search, the focused configuration/manifest test selected
from `.taskfiles/test.yml`, `task --exit-code config:diff` when safe, and
`git diff --check`. Run a source-mutating normalization first only if an
applicable repository task defines one.

## Initial progress

- [x] Tracker created before changing existing source or configuration.
- [x] Full tracker mirrored to Engram and read back.
- [x] CFG-01 implementation and verification.
- [x] CFG-01 Conventional Commit: `264f6e274345a1b80aca84919f41a827c4582182`.

Initial baseline: branch `dev`, HEAD
`4f92a56a05c3850523a5ce16b3cb752e5554f255`, and a clean worktree were observed.
No unrelated modifications were present.

## Closure record

Final CFG-01 scope is limited to the four Git-aware directory moves and these
runtime/config files:

- `.devcontainer/devcontainer.json`
- `.devcontainer/setup.sh`
- `.devcontainer/config-export.json`
- `.devcontainer/install/available/4010-tool-ssh-server.sh`
- `.taskfiles/scripts/config-export.py`
- `.taskfiles/scripts/compose-manifest.py`
- `.taskfiles/ssh.yml`

`git diff --find-renames --name-status` reports the moved trees as renames with
no content edits; only the seven declared runtime/config files have path-literal
edits. The compose selection assertion passed with the original active order:
base, core tools, SSH agent, SSH server, audio. The selected files all exist.

No applicable source-mutating normalization task is defined: `.taskfiles/quality.yml`
defines check-only `shfmt -d`, not a write task. Observed verification:

| Command | Result |
| --- | --- |
| `rg 'compose-config|opencode-config|pi-config|ssh-config' -- .devcontainer/devcontainer.json .devcontainer/setup.sh .devcontainer/config-export.json .devcontainer/install/available/4010-tool-ssh-server.sh .taskfiles/scripts/config-export.py .taskfiles/scripts/compose-manifest.py .taskfiles/ssh.yml` | PASS: no matches |
| `python3 -c "…compose-manifest.py selection…"` | PASS: `container-svc`, original active order, all selected files exist |
| `task --exit-code config:diff` | Exit 1: one existing OpenCode candidate, `opencode-notifier-state.json`; Pi trees were skipped because their owners are disabled |
| `bats .devcontainer/test/unit/compose-manifest.bats` | Exit 1: 33 of 39 Python tests passed; six errors remain in CFG-02 fixtures/assertions that reference the old paths, plus three `yq`-dependent fragment reads failed in this environment |
| `bats .devcontainer/test/unit/config-export.bats` | Exit 1: 28 of 32 passed; four assertions expect old seed paths/output and belong to CFG-02 |
| `task quality:check` | PASS: exit 0; ShellCheck and shfmt checks were silent-success, Markdown lint reported 17 files and 0 issues |
| `git diff --check` | PASS: no output, exit 0 |

The failing focused tests are intentionally not changed in CFG-01 because the
authorized checklist reserves fixture/test updates for CFG-02. They are recorded
as blockers to a full green suite, not as runtime migration failures.

The exact pre-commit identity is
`4f92a56a05c3850523a5ce16b3cb752e5554f255`. The exact CFG-01 commit hash cannot
be self-referentially embedded in this file; it is recorded in the complete
post-commit Engram mirror. There are no unrelated working-tree modifications.

## CFG-02 scope and verification

All paths below are relative to `.devcontainer/test/`:

- `fixtures/config-export.json`
- `lifecycle/starter-lifecycle.py`
- `unit/codegraph-test.py`
- `unit/compose-manifest-test.py`
- `unit/config-export.bats`
- `unit/host-bind-preparation.bats`
- `unit/opencode.bats`
- `unit/project-identity.bats`
- `unit/ssh-startup.bats`
- `unit/starter-lifecycle-test.py`
- `unit/tool-ownership.bats`

Replace only the four old configuration path names. Required layout adjustments:
create nested Compose parents recursively and create/copy SSH under `config/`.
Rollback boundary: these eleven files and this tracker, independently of CFG-01.

Run the following before and after fixture edits, with an explicit 180-second
outer command timeout. Effects are temporary fixture writes and local reads;
Git mutations/exports stay in fixture repositories and SSH/sudo are stubbed.

```bash
PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/compose-manifest-test.py -v \
  ManifestTests.test_core_config_seeding_copies_missing_files_without_pi_or_user_overwrite \
  ManifestTests.test_server_requires_both_enabled_installer_and_persisted_override \
  ManifestTests.test_core_extraction_preserves_original_mounts_and_port \
  ManifestTests.test_default_selection_keeps_core_active_and_codegraph_disabled \
  ManifestTests.test_audio_stays_outside_dind_tmp_and_is_never_managed
PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/starter-lifecycle-test.py -v
PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/codegraph-test.py -v \
  CodeGraphTests.test_mcp_seeds_are_disabled_and_consistent
PYTHONDONTWRITEBYTECODE=1 bats --filter '^compose publishes generated host ports on all host interfaces$' .devcontainer/test/unit/project-identity.bats
PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/config-export.bats
PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/tool-ownership.bats
PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/ssh-startup.bats
```

After edits, run `git diff --check`, `task quality:check`, and
`rg --hidden -n 'compose-config|opencode-config|pi-config|ssh-config' .devcontainer/test`
(expected search exit 1/no matches), each with a 120-second outer timeout.
Quality tasks are check-only; no source-mutating normalizer applies. Their shell
globs exclude Bats and Markdown globs exclude this tracker.

Do not run `opencode.bats` (real sudo), full `compose-manifest.bats` or
`host-bind-preparation.bats` (real Docker), `task test:starter`, or the operational
lifecycle harness. Unit lifecycle mocks do not prove operational lifecycle.
Current Kislyuk `yq` is detected and parses the migrated audio fragment; historical
fragment-read failures remain historical evidence, not an authorized config fix.
CFG-02 implementation, incomplete verification, and commit status must remain
distinct. CFG-03 remains pending.

### CFG-02 observed results

Before fixture edits, `dev` was clean at
`264f6e274345a1b80aca84919f41a827c4582182`; the tracker was updated and fully
mirrored/read back first. The seven exact commands above produced these results:

| Check | Before fixture edits | After fixture edits |
| --- | --- | --- |
| Selected Compose methods | Exit 1: 0/5 passed, 5 errors | Exit 0: 5/5 passed |
| Lifecycle unit mocks | Exit 1: 13/16 passed, 3 errors | Exit 0: 16/16 passed |
| Selected CodeGraph method | Exit 1: 0/1 passed, 1 error | Exit 0: 1/1 passed |
| Selected project identity test | Exit 1: 0/1 passed | Exit 0: 1/1 passed |
| Config export suite | Exit 1: 28/32 passed | Exit 0: 32/32 passed |
| Tool ownership suite | Exit 1: 4/10 passed | Exit 0: 10/10 passed |
| SSH startup suite | 1/12 reported passing; outer timeout at 180 seconds | Exit 0: 12/12 passed |

SSH baseline output reported missing-wrapper exit 127; failed assertions can
bypass inline cleanup of fixture sleep processes. The baseline timeout is
incomplete proof, not a normal exit or PASS. Process inspection afterward found
no remaining test processes; no manual cleanup escalation or baseline retry.
Post-edit process inspection likewise found no remaining test processes.

All 77 authorized post-edit tests passed. The two selected fragment-read errors
disappeared with path-only updates and unchanged `yq`; stale fragment paths had
been masked by the generic parser diagnostic. No environment fix was made.
`git diff --check` passed; `task quality:check` exited 0 (17 Markdown files,
zero issues); the full test-tree stale-name search returned no matches (exit 1).
No source normalization was needed. The excluded suites above remain unrun;
there is no complete affected-suite or operational lifecycle proof.

Implementation is complete within the eleven-file scope; broader proof remains
incomplete. No runtime/configuration, CFG-03, or review-lineage changes were made.
The tracker records evidence, not review approval. The authorized local commit
will contain only the eleven fixture/test files and this tracker.

Before closure reconciliation, CFG-02 was +229/-134 = 363 authored lines;
cumulative CFG-01/02 was 550. The forecast underestimated tracker scope/evidence.
The user accepted the size exception; no evidence was removed to reduce size.

### CFG-02 local commit authorization

Parent-supplied evidence records a config-export spot-check at 32/32 and a fresh
independent verifier run of all seven authorized commands at 77/77, with no
weakened assertions. These are parent-reported results, additional to the direct
before/after observations above. The parent also reports read-only native assess
classification `high` / `process_boundary` for
`.devcontainer/test/lifecycle/starter-lifecycle.py`; this is not approval.
Review `review-49d9ff8415aad1c5` remains pending and untouched.

Pre-commit checks are `git diff --check` and check-only `task quality:check`;
inspect status, complete diff, and recent commits before staging only this scope.
Do not skip hooks or amend; verify any hook mutation before final proof.
The commit message is `test(devcontainer): align fixtures with centralized config layout`.
The exact hash cannot be embedded in its own commit: the complete Engram mirror
will append explicitly post-commit metadata after success, leaving file
reconciliation to the next task rather than creating another tracker commit.
No broader sudo/Docker/runtime checks are claimed; CFG-03 remains pending.
