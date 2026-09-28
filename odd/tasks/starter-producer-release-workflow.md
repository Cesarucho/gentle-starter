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
- [ ] SPR-2 — Replace the broken guide with a concise happy path and short
  explanations for review and explicit push. Check markdownlint and command
  consistency; record rollback.

## Progress and evidence

- SPR-1: producer task uses a temporary target worktree, rejects a dirty source,
  and aborts conflicting merges before removing the worktree. Focused Bats:
  13/13 pass; maintainer suite: 472 unit and 34 integration pass (first attempt
  timed out at 120 seconds, second completed); `git diff --check`: pass.
  Disposable Git fixture invoked the new Task entry from `dev`, confirmed
  unchanged source branch and updated target without remotes. Rollback: revert
  producer helper, Task entry and focused producer fixtures; direct task remains.

## Next step

Commit SPR-1; implement SPR-2 and verify the guide.
