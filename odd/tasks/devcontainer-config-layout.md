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

The user explicitly authorized the migration. This work item implements only
CFG-01: move `.devcontainer/{compose-config,opencode-config,pi-config,ssh-config}`
to `.devcontainer/config/{compose,opencode,pi,ssh}` and update only their
runtime/config references in the declared CFG-01 paths.

## Constraints

- This is a path-only migration.
- Preserve Compose ordering and file content except for required path literals.
- Do not change mount targets, `.env.d` locations, lifecycle semantics, fixtures,
  tests, user documentation, or skills.
- Preserve unrelated working-tree changes if present.
- Technical artifacts are English.
- TDD mode: `unknown`; do not invent a test runner or claim a RED/GREEN cycle.
- Delivery strategy: `ask-on-risk`; the advisory review budget is about 400
  authored changed lines.

## Delivery strategy and route

Selected route: one isolated CFG-01 path migration, followed by focused
repository checks and one Conventional Commit. No remote operation, PR, push,
RDD review command, container lifecycle operation, or source-mutating export is
authorized.

Delegation trigger evidence: CFG-01 is a cohesive path-only work unit with a
small, explicitly enumerated runtime/config reference set. CFG-02 owns tests and
CFG-03 owns documentation and skill updates, so neither may be delegated or
absorbed into this commit. Escalate under `ask-on-risk` if the migration exposes
a semantic change, an undeclared reference outside CFG-01, or a review-size risk.

## Stable checklist

### CFG-01 — Runtime and path migration

- [x] Move the four configuration trees with Git-aware moves.
- [x] Update only declared runtime/config path literals.
- [x] Preserve Compose order, file content, mount targets, `.env.d`, and lifecycle
  behavior.
- [x] Run focused safe checks and record observed outcomes.
- [ ] Commit this work unit with a Conventional Commit. Its exact hash is recorded
  in the post-commit Engram mirror because a commit cannot contain its own hash.

### CFG-02 — Tests

- [ ] Update and run affected fixtures/tests for the new configuration layout.

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
- [ ] CFG-01 Conventional Commit.

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

Remaining next task: **CFG-02 — Tests**, to migrate fixtures and assertions,
resolve the environment's `yq` prerequisite where applicable, and rerun the
focused suites. CFG-03 remains pending after CFG-02.
