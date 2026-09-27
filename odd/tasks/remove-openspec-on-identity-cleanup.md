# Remove OpenSpec on identity cleanup

## Objective and authorization

Delete all root `openspec/` content after the existing explicit confirmation in
`task project:init`, `task clean:identity`, and its `task clean` alias. This includes
user-authored committed and ignored content. Preserve initialization's existing
dirty-worktree guard; authorization does not bypass it.

Independent verification and parent spot checks are complete. The user authorizes
the local six-file work-unit commit after final check-only commands and diff inspection.
This file is the pre-commit snapshot; completion and commit hash will be Engram-only.

## Scope

- `.taskfiles/scripts/clean-lib.sh`: removal list, truthful plan, root-type validation.
- `.taskfiles/scripts/project-init.sh`: include OpenSpec in transaction backup/restore.
- `.taskfiles/scripts/clean.sh`: correct deleted/kept help and explain complete deletion.
- `.devcontainer/test/unit/project-init.bats`: behavioral fixtures and real Task wrappers.
- `README.md`: tree-only removal of the OpenSpec row and final-connector correction.
- `odd/tasks/remove-openspec-on-identity-cleanup.md`: this feature's task and evidence.

Reuse existing `odd/` cleanup safety and tar rollback patterns; no unrelated refactor,
registry, provider-repair architecture, historical ADR rewrite, or Task wiring change.
Preserve `.env.d`, its README assertion, and the separate CFG migration tracker.
Preserve the user's exact current README; do not restore the explanatory paragraph.

## Delivery and baseline

- Route: delegated implementation; five nontrivial source/test/docs files form one unit.
- Strategy: `ask-on-risk`; forecast **250–380 authored additions plus deletions**, tracker
  included. Do not inherit CFG's size exception, compress code, or drop coverage to fit.
  If the forecast exceeds 400, report the risk before continuing without a decision.
- Testing: ordinary tests-first, matching this session's ordinary-verification preference;
  no enabled strict project mode is established. Do not initialize SDD or change TDD config.
- Baseline: `c385d8b6c8dace17398af5da4ab24a8b6aaab66e`, `feat/devcontainer-config-layout`.
- Preserve user `.env.example` bytes/mode exactly and its unstaged `+4/-1`; never stage it.
- Existing 22-case initialization suite is the baseline to recheck, not a new passing claim.
  New deletion/plan/unsafe-type tests should fail before implementation; preservation
  tests may already pass. Record actual results rather than fabricated RED evidence.
- Known baseline README failure: `readme-contract.bats:17` rejected `openspec/`; after its
  removal, line 18 still rejects documented `.env.d/`. That independent failure is out
  of scope: preserve the assertion and documentation, and never report aggregate PASS.

## Stable task

- [ ] **OSCL-01 — Remove root OpenSpec through shared identity cleanup safely.**
  - [x] Tests: add focused cases first; record baseline and expected behavioral failures.
  - [x] Runtime: update shared cleanup, validation, and initialization rollback inventory.
  - [x] Docs: explicit deletion in plan/help; preserve the user's tree-only README edit.
  - [x] Checks: independently verify the current snapshot; refresh documentation proof.
  - [ ] Commit: authorized; execution and proof remain pending in this pre-commit snapshot.
    Include only scoped behavior, tests, docs, and tracker; record the identity in Engram.

## Acceptance criteria

1. All three real Task entry points delete committed and ignored root OpenSpec content
   after confirmation in separate disposable repositories using production Taskfiles.
2. Preserve unrelated top-level content, including another directory's `openspec/`,
   LICENSE/template bytes and modes, normal parent commit, refs/config invariants, and
   initialization's tracked-change/ordinary-untracked guard and second-run refusal.
3. Dry-run names OpenSpec under deletion, never preservation; dry-run and cancellation
   preserve files, ignored content, modes, index, refs, and config for applicable commands.
4. Inject commit failure after proving deletion occurred; rollback restores committed
   and ignored nested bytes, directory/file modes, and symbolic-link targets exactly.
5. Reject root OpenSpec symlinks (including dangling links) and non-directory files before
   mutation for init/clean; preserve external targets and unrelated sentinel content.
6. Nested symlinks are not followed on deletion; missing OpenSpec is a successful no-op.
   Repeated standalone cleanup remains safe without relaxing initialization's guard.
7. Plan/help disclose all-content deletion before confirmation; README changes only its
   tree, without restoring the user-removed paragraph. Scoped proof includes wrapper
   delegation and cleanup evidence, not merely static list or README assertions.

## Verification and risks

Run `bats .devcontainer/test/unit/project-init.bats` before and after implementation and
`bats .devcontainer/test/unit/readme-contract.bats` separately in a disposable candidate.
Use isolated HOME/Git configuration, disable system/global Git config and prompting,
and neutralize inherited Git overrides. Fixture-local Git writes, archives, and scoped
deletion are expected; never initialize or clean the primary or candidate suite root.
No network, installs, sudo, Docker, builds, broad starter suite, or remote Git operations.

Also run `git diff --check` and `task quality:check` in the candidate. Inspected
`.taskfiles/quality.yml:56-61` calls optional ShellCheck, `shfmt -d`, and local
markdownlint-cli2 without installs/network; missing tools warn/skip. Its Markdown globs
exclude this tracker, so disclose that gap or separately lint this file with the installed
binary. Allow 300 seconds per command; forecast 1–3 minutes per Bats pass, under 10 minutes
total and under 100 MiB scratch. Inspect owned leftovers after interruption; no blind retry.

Risks: destructive-scope misunderstanding, ignored-data rollback loss, and symlink
collateral deletion. These are covered above; concurrent filesystem replacement is not
claimed safe. Rollback boundary is this feature's six-file diff, not prior CFG work.
Keep CFG-01's pending review untouched; any new review is parent-owned. No push, PR, merge,
native review/status/capture, or additional planning artifact is authorized here.

## Implementation evidence (before the user's README edit)

- Shared deletion, disclosure, root validation, and rollback inventory are implemented.
  The new validation explicitly returns failure because initialization invokes its
  enclosing function conditionally, which disables implicit Bash errexit handling.
- Isolated baseline: initialization **22/22 passed** (6.956s); README **5 passed, 1 failed**
  at the existing OpenSpec assertion (0.215s).
- Tests-first: initial **19 passed, 8 failed** included a new fixture-path collision.
  Corrected that fixture before runtime edits; corrected RED **20 passed, 7 failed**
  (8.640s), covering deletion, disclosure, and root-type rejection.
- First GREEN **27/27 passed** (9.953s). Added explicit early-rejection assertions;
  final initialization **27/27 passed** (10.241s), including real Task-wrapper scenarios.
- Final README **5 passed, 1 failed** (0.230s), now at unchanged `.env.d` assertion 18.
  This remains an overall check failure, not a feature regression or aggregate PASS.
- Final `task quality:check` passed (2.259s), no missing-tool warnings; primary scoped
  and candidate `git diff --check` passed. Tracker-specific Markdown check passed.
- All commands used 300-second external timeouts, synthetic HOME/Git configuration,
  and independent local clones; candidate `.env.example` matched committed HEAD.
- Evidence retained at `/tmp/opencode/oscl-verify.1e6W1VYd` (99 MiB rounded): snapshot
  repositories, harness, logs, and exit/time receipts. All five fixture TMPDIRs are empty.
- Primary `.env.example` SHA256 remains `ba23fc0374392475234f9dbb18aa96b9425922814af9bb1306167b6db56324d8`,
  mode `0644`, unstaged `+4/-1`. HEAD, branch, index/config hashes remain unchanged.
- Earlier snapshot count: **312 lines (+304/-8)** across six files, excluding user `.env.example`.
- No staging, commit, branch change, native review, or forbidden execution occurred
  during implementation. The independent verification below supersedes its next-step plan.

## Independent verification and commit handoff

- Evidence: `/tmp/opencode/oscl-independent.lj6k3h4v/results.json`.
- Current-snapshot initialization: **27/27 passed** (9.735s); README: **5/6 passed**
  (0.265s), with only the known `.env.d` assertion 18 failure, not an aggregate PASS.
- Quality passed (2.219s), no dropped tools; whitespace (0.032s) and tracker lint
  (0.164s) passed. Parent spot checks also passed whitespace and quality checks.
- All three wrappers, committed/ignored deletion, cancellation/dry-run, unsafe roots,
  external symlink targets, absence/repeated clean, dirty guard, and post-deletion
  rollback of bytes/modes/symlinks were exercised. Initialization mode assertions and
  rollback config snapshots passed; standalone wrapper mode preservation and arbitrary
  unrelated Git configuration on success were not individually asserted.
- Preserve the user's exact tree-only README; its removed paragraph stays removed.
- Implementation and independent checks are complete. Commit is authorized but not yet
  claimed here; rerun check-only commands after this edit, inspect/stage only the six
  scoped files, and record the resulting commit identity in Engram without a file rewrite.
