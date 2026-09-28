# Starter producer release workflow

## Objective

Provide a producer-only local preparation and verification command for updating
`starter`, and a concise, accurate happy-path command sequence. Keep publication
as a separate human-controlled push.

## Problem and scope

The existing `distribution` task lives under `.maintainer/` on `dev`, but the
published `starter` tree intentionally excludes `.maintainer/`. The documented
update sequence switches to `starter` before invoking that missing Taskfile.
The producer workflow must use committed `dev` source and an existing clean
`starter` branch without automatically contacting or modifying a remote.

## Authorized scope and checks

- Source branch: `feat/starter-producer-release-workflow` from `dev`; publish
  nothing in this work unit. Preserve the current `starter` branch and user data.
- TDD: unknown (no explicit mode established); run ordinary focused Bats and
  applicable maintainer checks. Runner: `bats`.
- Route: delegated direct writer for multi-file implementation and preparation.
- Estimated authored change: approximately 150-300 lines; 400 lines is advisory.
- Delivery strategy: ask-on-risk; no PR or push authorized.

## Tasks

- [x] SPR-1 — Add producer-only preparation/check entry with safe branch and
  worktree behavior, focused regression fixtures, and no implicit push. Verify
  focused Bats, full maintainer suite, and `git diff --check`; record rollback.
- [x] SPR-2 — Replace the broken guide with a concise happy path and short
  explanations for review and explicit push. Check markdownlint and command
  consistency; record rollback.
- [x] SPR-3 — Correct cleanup after a partially successful `git worktree add`.
  Preserve the target and report cleanup uncertainty separately from the original
  failure; never delete an unknown checkout or claim an unchanged target without
  evidence. Delegated direct writer; TDD mode unknown, runner `bats`. Acceptance:
  failure injection covers partial registration and dirty failed cleanup, cleanup
  is limited to the producer-owned temporary checkout, and the original failure
  remains visible. Check focused Bats, markdownlint on both changed guides and
  task document, and `git diff --check`; record rollback and any limits.

## Progress and evidence

- SPR-1: producer task uses a temporary target worktree, rejects a dirty source,
  and aborts conflicting merges before removing the worktree. Focused Bats:
  13/13 pass; maintainer suite: 472 unit and 34 integration pass (first attempt
  timed out at 120 seconds, second completed); `git diff --check`: pass.
  Disposable Git fixture invoked the new Task entry from `dev`, confirmed
  unchanged source branch and updated target without remotes. Rollback: revert
  producer helper, Task entry and focused producer fixtures; direct task remains.
- SPR-1 commit: `010c663` (`feat(starter): prepare local producer release in
  isolated worktree`).
- SPR-2: guide now starts with the producer command, local review and optional
  separately authorized human push; explains conflict rollback and direct-task
  limitations. `markdownlint-cli2 .maintainer/README-distribution.md`: pass
  (0 issues); focused Bats: 13/13 pass; `git diff --check`: pass. Command
  consistency checked against Task entry and disposable Task fixture. Rollback:
  revert guide and this SPR-2 progress entry without removing producer code.
- SPR-3: RED focused Bats 0/2 (original add error hidden; cleanup skipped).
  GREEN focused Bats 3/3 and full file 16/16; markdownlint on guide and task
  document: 0 issues; `git diff --check`: pass. Injected registered partial
  add, dirty removal refusal, and unregistered path plus target-ref mutation.
  On cleanup uncertainty the private temporary path is retained for inspection;
  no unknown checkout is deleted. Runtime harness: N/A beyond disposable Git
  fixtures; no Docker or remote execution. Full maintainer suite not run (outside
  bounded checks). Rollback: revert only SPR-3 changes to producer helper,
  focused fixtures, guide and this progress entry; preserve SPR-1/2.
- SPR-3 commit: `c856509` (`fix(starter): preserve producer worktree on cleanup failure`).

## Next step

Review locally; publication remains a separate human decision.
