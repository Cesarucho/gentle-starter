# Container lifecycle semantics

T1 aligns lifecycle behavior, isolated regressions, and current guidance as one
coherent work unit. Source outcomes are observed and recorded; implementation is
complete with strict validation open as an environmental follow-up. The user
authorized committing despite that failure; real Docker lifecycle/build was not run.

## Tracking and authority

- Project: `gentle-starter`; mirror: `odd/container-lifecycle-semantics/tasks`.
- T1: **Align container lifecycle behavior, tests, and guidance** — implemented.
- Baseline: clean `dev`, HEAD `7b7cddd1fd89948de14b8b39ee3d14cc377818b4`,
  apart from this untracked plan. Branch created before source writes:
  `feat/container-lifecycle-semantics`; this identifies the pre-commit baseline.
- The user explicitly authorized implementation, the feature branch, and directly
  coupled tests/docs/help/messages. This replaces the earlier tracking-only scope.
- Commit authorization explicitly includes the user's README sentence deletion;
  preserve its current content. No environment repair or `.env` validation change.
- Delivery: `ask-on-risk`; RDD remains `on (global)`. Candidate-specific review
  decline is recorded below; no native review receipt is claimed.
- No `strict_tdd` policy was supplied/found; voluntary tests-first evidence follows.
- Execution boundary: local mocks/temp fixtures only; no real Docker lifecycle,
  builds, installations, network operations, or restart of the working environment.

## Implemented contract

| Command | Behavior |
| --- | --- |
| `container:restart` | Resolve the existing service container, query all states, restart its ID. Running/stopped preserve identity; missing fails with `container:up` guidance. |
| `container:recreate` | Remove then up; stop if removal fails. Startup may build under existing up semantics. |
| `container:rebuild` | Remove then build only; no up or image deletion. Stop if removal fails. |
| `container:build` / `container:up` | Existing implementation unchanged, including automatic create/start behavior of up. |

The existing guarded identity setup and name resolver are reused. Restart does not
prepare mounts or call auto-start helpers. `rm` now distinguishes absence from
Docker lookup errors and propagates real removal failures: the former unconditional
`|| true` otherwise allowed recreate/rebuild to continue after a failed removal.

## Implementation and acceptance

- [x] Task behavior, descriptions, help, missing-container guidance, host guards,
  and explicit failure propagation implemented in `.taskfiles/devcontainer.yml`.
- [x] Isolated shell-body tests in `devcontainer-tasks.bats` cover running/stopped
  identity, missing/lookup/resolution/restart failures, removal errors, exact
  recreate/rebuild ordering, forbidden extra operations, and host guards. These
  tests replace Docker/nested Task commands with doubles; they are not daemon proof.
- [x] Lifecycle harness uses `recreate` for replacement and persistence evidence;
  recovery accepts both new `recreate` and legacy `restart` inventory stages.
- [x] Compose recovery assertion, updater message assertion, README, extension and
  optional-integration guides, volume guide, ADR workflow, root help, SSH/install
  messages, AGENTS guidance, and one add-tool reference agree. Historical changelog
  prose remains, with the new behavior recorded under Changed.
- [ ] Strict validation passes in a valid environment; do not repair runtime state
  under this authorization.
- [x] Candidate-specific native review decline; independent fallback verification.
- [x] User accepts the recorded validation failure and explicitly authorizes commit.

## Verification evidence

Tests-first RED before corresponding implementation:

- `bats --filter 'container:|host UID' .devcontainer/test/unit/devcontainer-tasks.bats`:
  11 tests, 6 failed on the old lifecycle behavior/missing recreate task.
- `PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/starter-lifecycle.bats`:
  both wrappers failed: old restart invocation and rejected recreate inventory stage.
- `bats --filter 'container:rm permits' .devcontainer/test/unit/devcontainer-tasks.bats`:
  1 failed before the removal failure-propagation fix.

Post-implementation foreground checks (no source normalization was needed):

| Command | Result |
| --- | --- |
| `git diff --check` | PASS; independently rerun by parent |
| `bats --filter 'container:|host UID' .devcontainer/test/unit/devcontainer-tasks.bats` | PASS, 12 tests; independently rerun by parent |
| `PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/starter-lifecycle.bats` | PASS, 2 wrappers covering 15 + 37 Python tests; fresh independent verifier rerun PASS |
| `task quality:full` | PASS: ShellCheck, shfmt check, Markdown lint |
| `task validate:full` | FAIL, including fresh independent rerun: doctor `Stale volume manifest repository inputs`; 1 error, 0 warnings; quality phase not reached |
| `PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/compose-manifest-test.py ManifestTests.test_unapplied_existing_container_fails_before_preparation` | PASS, 1 mock-only test |
| `bats --filter 'tools:update atomically updates' .devcontainer/test/unit/tools-update.bats` | PASS, 1 mocked updater fixture |

Parent findings isolate the ignored root `.env` hash mismatch with the active
manifest. Manifest identity, service, and ordered inputs are valid; all tracked
input hashes match HEAD. The HEAD validator evaluated in memory also rejects the
current local pair: changed source did not cause manifest input invalidation.
Historical pre-implementation staleness remains unproved without old `.env` bytes.
Quality/validation effects were inspected first; no manifest rewrite or environment
repair occurred. Full `test:starter` and real Docker lifecycle/build were not run.

## Review boundary and next step

Proposed boundary: keep T1 task behavior, directly coupled tests/harness, guidance,
and this tracking document together. Revert that unit together if needed; do not
revert unrelated work. There are no generated artifacts in this unit.

Before this tracking-only update, native assessment was **high**, covering 24 files
and **377 authored lines** (317 additions + 60 deletions). The user chose to skip
this candidate via the native question. Returned: `action: declined`,
`consent: declined_this_candidate`, matching target
`sha256:cbc6f360e4b6131e4ae2da180748ea1cfb93059b0e99dab8d82127675ff17970`.
No native review launched; no lineage or review receipt exists. Independent
functional verification satisfies the fallback high tier; global RDD stays enabled.

Next: commit this source unit, including the user's README edit. Strict validation
remains open: obtain separate authorization for `.env`/manifest follow-up, then
rerun `task validate:full`. No environment repair or validation redesign is permitted
here; commit identity is recorded separately after creation.
