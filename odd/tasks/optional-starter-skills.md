# Optional starter skills

## Objective and authority

Publish `starter` with only the project-authored `add-tool` skill installed.
Derive optional recommendations from `dev`'s external skills lock at release
time. Let consumers select several suggestions in one explicit Task command,
or install their own with Skills CLI. Do not publish, push, or touch the pending
`.env.example` change. Branch: `feat/optional-starter-skills`; mirror:
`odd/optional-starter-skills/tasks`.

- Scope: distribution generator, recommendation catalog, optional Task selector,
  documentation and regression tests. Keep the full dev skill tree and lock.
- TDD: no configured strict mode in project ODD history; focused Bats runner.
- Delivery strategy: `ask-on-risk`; forecast above ~400 authored lines across
  units; ~400 lines per unit is advisory, not a hard cap. User selected
  `feature-branch-chain` for any later PR slicing; no PR authorized.

## Tasks

- [x] T1 — Publish only `add-tool` plus a generated recommendations catalog,
  without dev external skill folders or dev lock. Preserve consumer-owned skills
  and lock across subsequent updates. Route: delegated direct writer (multi-file
  architecture and tests). Acceptance: fixture tests prove dev is unchanged,
  initial starter is lean, and later merges retain consumer-owned paths. Checks:
  distribution Bats, maintainer quality checks, diff check.
- [x] T2 — Offer `task skills:suggest` inside the container: one multiple-choice
  input supporting numbers, all, none; one confirmation; explicit batch names
  as noninteractive alternative. Validate names against the local catalog;
  invoke native Skills CLI for selected skills, report partial failures, never
  run on startup. Route: delegated direct writer (multi-file, tests/docs).
  Acceptance: invalid/empty/cancelled choices make no changes; only selected
  entries install; user-owned lock and custom skills remain theirs. Checks:
  focused fixture Bats, markdown lint, Task listing, diff check.

## Progress and verification

- T1 implemented locally without publication or network installs. Disposable
  Bats fixtures verify the first release, consumer-owned lock and skill retention,
  catalog refresh, and migration conflicts for edited legacy paths. Source checkout
  has a pre-existing local `.env.example` edit; leave it untouched. Work-unit
  commit: `0791142`; native review approved and acknowledged under
  `review-e1f209a6155de781`. Non-blocking warning: add a successful legacy
  upgrade fixture later; the edited legacy conflict path is already covered.
- T2 uses the published catalog only; dev reports its absence rather than
  duplicating recommendations from the dev lock. Selection and confirmation are
  separate; explicit batch names through the Bash script skip only the selection
  menu. Task CLI arguments are rejected to avoid shell interpolation. No startup
  hook or real Skills CLI installation was run. Bash UI correction verified:
  focused Bats 16/16, `task --list` lists `skills:suggest`, markdownlint reports
  zero issues, shellcheck, `shfmt -d`, and `git diff --check` pass. The fake
  Skills CLI fixture is the runtime harness. Only the new Bash script and Bats
  test were formatted; review found no semantic change. Rollback boundary:
  remove the selector Task include/script, shared selector tests and optional
  skills guide/link without reverting the reviewed T1 distribution changes.
