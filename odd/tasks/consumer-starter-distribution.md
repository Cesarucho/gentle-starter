# Consumer starter distribution

## Objective and authority

Provide a maintained `starter` branch for downstream projects without a root
README, project:init, maintainer-only tasks, tests, identity, or planning state.
Preserve a shared Git history so consumers can merge `upstream/starter` while
owning their own `main`, README, workflows, and planning files. The user
authorized local implementation on a new branch derived from `dev`, not remote
publication or a real Docker lifecycle/build.

- Source branch: `dev` at `f745ab1`; implementation branch:
  `refactor/consumer-starter-distribution`.
- Mirror: `odd/consumer-starter-distribution/tasks`.
- Delivery strategy: `ask-on-risk`; user chose `feature-branch-chain` for
  any later PR slicing. No push or PR authorized.
- TDD: not configured (source: existing ODD project record reports no strict
  policy); ordinary focused and applicable full tests are required. Runner:
  `bats` via starter test tasks. `task test` intentionally fails until an
  application supplies its own command.
- Scope: documentation, Taskfile and test ownership, local publication
  mechanism, local consumer-branch proof and accompanying tests/docs.
- Work-unit advisory: roughly 400 authored changed lines, not a hard cap;
  keep coherent tests and docs with each behavior even if larger.
- Forecast: likely exceeds 400 authored lines in total; assess running commits
  and decide PR slicing before crossing the delivery budget. No PR or push now.

## Tasks

- [x] T1 — Move reusable environment guides to `.devcontainer/docs/` as the
  single source in `dev`; keep maintainer-only docs under `docs/en/`. Repair
  relative links and tests. Acceptance: no project-init-time documentation
  copy is needed for the future consumer branch; both developer and consumer
  entry guides resolve their local links. Route: delegated writer (4+ files,
  preparation and non-trivial multi-file changes). Checks: focused doc/link
  tests and markdown validation.
- [x] T2 — Isolate maintainer-only Task commands, tests, scripts, and fixtures
  in `.maintainer/` while keeping shared environment tests and application
  `task test` available. Acceptance: root Taskfile has no maintainer include,
  maintainer suites run separately, shared tests run without deleted helpers.
  Route: delegated writer (multi-file, test and Taskfile mapping). Checks:
  targeted Bats, `task --list`, `task validate`, `task validate:full`,
  applicable `task test:starter` equivalent. Verify the complete refactored
  `dev` baseline before starting T3; skip expensive lifecycle unless separately
  authorized.
- [x] T3 — Prepare a local `starter` branch from the verified refactor with a
  repeatable, fail-closed content contract; remove maintainer identity and
  tooling, preserve useful environment docs/tests, and do not publish remotely.
  Acceptance: no root README, AGENTS.md, CHANGELOG.md, `.maintainer/`,
  maintainer `docs/en/`, `.github/`, `odd/`, or `openspec/` from upstream;
  LICENSE and AGENTS.md.TEMPLATE preserved; consumer-owned files survive later
  merges. Route: delegated writer (non-trivial scripts and tests). Checks:
  temporary-clone generation and second-update tests, merge ancestry, links,
  Task list, preservation of user-created paths; local branch inspection.

## Progress and verification

- T1 complete: `300c463` moved five guides to `.devcontainer/docs/` and
  eliminated documentation copying at initialization. Focused Bats:
  `project-init.bats` 27/27 and `tool-policy.bats` 8/8; markdown lint 18 files;
  focused link check 14 files; `git diff --check` clean. Parent independently
  reran `project-init.bats` (27/27). Native assessed high risk due to shell
  source, reviewed four lenses and acknowledged approved authority for this
  exact commit (lineage `review-3d7520b2f182e3f3`). Follow-up warning:
  add automated coverage for relocated guide links (T2 or T3); suggestion:
  preserve the policy ADR context in the maintainer docs.
- T2 complete: `123e278` isolates maintainer commands and tests in
  `.maintainer/`. Parent reran `task test:starter` through the alternate
  Taskfile (439 unit passes and 34 integration cases, 11 expected skips),
  `task validate`, `task validate:full`, `task install:list`,
  `task install:doctor`, and `task install:volumes`: all passed.
  `task test` intentionally fails until application tests are configured.
  Real Docker image-contract and lifecycle builds were not authorized or run.
  Follow-up commit `27fec1b` restores original executable modes on moved
  test files. Native review approved and acknowledged T2 range under lineage
  `review-0d0cb1f408104a1e`. This gate verifies refactored `dev`
  behavior before T3, not real Docker lifecycle operation.
- T3 complete locally: `1e8d0f9` implements distribution, and `570d7b3`
  fixes source-only ancestry advancement (reviewed and acknowledged under
  `review-a36b31eeec41d8dd` and `review-6905ad099593239f`). Bats distribution
  6/6, maintainer unit 445/445, strict repository validation passed on the
  feature checkout. Local `starter` initially created at `0b638b9`; an
  independent disposable clone proved branch rename, upstream removal,
  consumer-owned README/.github/odd/openspec preservation, shared doc update,
  modes, symlink and Git ancestry through a later release merge. All six
  distributed Markdown guides resolved local links; `task --list` passed.
  `task validate` and `task validate:full` in that independent clone were
  blocked by the absent active volume snapshot, not run to quality completion;
  full shared Bats suite there was skipped because ownership fixtures use
  `sudo`. No real Docker build/lifecycle or remote publication was run.
- Local `starter` was advanced through the task-document source commit using
  a temporary linked worktree; its tree stayed identical and its source parent
  advanced. The temporary worktree was removed cleanly. Next: review the two
  local branches and decide separately on merge into `dev` and remote branch
  publication. No push, PR or merge to `dev` has occurred.
