# Existing-project starter integration

## Objective

Provide a host-runnable, read-only compatibility preflight exported from `dev` to
`starter`, and document a reviewed two-parent merge for existing unrelated Git
projects without overwriting project-owned files or skills.

## Problem and scope

An unrelated project cannot use the starter Taskfile before import. Copying
files does not establish ancestry for later `upstream/starter` merges. The
initial merge must preserve the project's README, LICENSE, AGENTS.md,
skills-lock.json, own skills, and .env.example; .gitignore requires manual
combination. Existing paths in .agents/skills/add-tool/, .devcontainer/,
.taskfiles/, .markdownlint-cli2.yaml, or Taskfile.yml disallow the direct route.
Keep existing README edits and any user-owned skills untouched.

## Authorized scope and decisions

- Implement the checker in the distributed Taskfile/.taskfiles tree, callable
  from a separate starter checkout on the host with an absolute target path.
- Preflight is read-only, uses host Git/Python/Task, never fetches or merges,
  reports manual integration for reserved-path collisions (tracked, untracked,
  symlinks, unusual types), and fails closed on uncertain repository state.
- Initial unrelated-history integration uses a reviewed, real two-parent merge
  on `integrate-starter`, never squash; no automatic merge or commit by checker.
- No remote execution, Docker, credential use, push, or publication is in scope.
- TDD mode: unknown (no explicit project/session setting established); runner:
  `bats` for maintainer fixtures. Run ordinary focused and full applicable checks.
- Delivery strategy: ask-on-risk; the user chose feature-branch-chain for any
  later PR delivery, without authorizing a PR or push. Forecast exceeded the
  advisory ~400 authored lines across work units; this does not cap correctness.

## Tasks

- [x] EPI-1 — Add host-only read-only checker, exported Task entry, and Bats
  fixtures for clean/unrelated paths, reserved collisions, symlinks, dirty
  worktree, and unchanged Git state. Route: delegated writer (multiple
  nontrivial files, preparation read). Checks: focused Bats, maintainer unit,
  `git diff --check`; prove no repository mutations in fixtures.
- [x] EPI-2 — Verify release export in a disposable distribution fixture and
  document host invocation, direct and manual paths in README and
  `.devcontainer/docs/`, with index link. Route: delegated writer (multiple
  nontrivial files and documentation preparation). Checks: distribution Bats,
  markdownlint, links, `git diff --check`; preserve user's existing README edits.
- [x] EPI-3 — Address the two informational review edge cases: reserved paths
  tracked outside a sparse checkout must not return COMPATIBLE, and an active
  Git bisect must be rejected. Keep the checker read-only, add disposable Bats
  fixtures, and preserve all user-owned README/skills edits. Route: delegated
  writer (checker plus nontrivial fixtures). Checks: focused Bats, maintainer
  unit suite, `git diff --check`; runtime container boundary N/A (host Git).

## Acceptance and progress

- Task and script resolve from the published `starter` tree, not `.maintainer/`.
- A target with reserved paths never receives a direct-merge recommendation.
- Compatible state never implies a conflict-free merge; user reviews the
  two-parent merge and owns every commit and future update.
- EPI-1: `f757409` (`feat(starter): check existing projects before integration`)
  on `feat/existing-project-integration`; focused Bats 12/12, maintainer unit
  465/465, `task --list`, and `git diff --check` passed. The checker leaves
  repository state unchanged; untracked reserved paths take precedence over
  unrelated dirty changes. Runtime container boundary: N/A (host-only Git
  inspection). Rollback: revert the Task entry, checker, and focused fixture.
- EPI-2: `5877a07` (`docs(starter): guide existing-project integration`);
  release fixture passed 10/10, full unit 467/467,
  markdownlint 20 files with 0 issues, and `git diff --check` passed. Keep
  pre-existing user-owned README edits outside this work unit's staged patch.
  Runtime container boundary: N/A (host docs and Git fixtures). Rollback:
  revert the guide, README integration subsection, index link, and release
  fixtures; EPI-1 can then remain independently usable.
- EPI-3 was accepted by the user after native review approval and
  acknowledgement of the previous committed candidate. It is a new work unit,
  not a reopening or correction of that consumed review.
- EPI-3: `9c8bce8` (`fix(starter): detect sparse paths and active bisect`);
  RED for both new fixtures before the fix, GREEN 14/14 focused, maintainer
  unit 469/469, and `git diff --check` passed. Sparse tracked paths return
  MANUAL even when omitted from disk; active bisect returns ERROR. Runtime
  container boundary: N/A (host-only Git inspection). Rollback: revert this
  checker and fixture commit without touching the earlier work units.
- Mirror the full document to Engram after each update; commit work units on
  the feature branch with verification and commit identity.

## Next step

All three tasks are implemented. Assess the new committed work unit separately;
leave the user's uncommitted README edits untouched. No push or PR is authorized.
