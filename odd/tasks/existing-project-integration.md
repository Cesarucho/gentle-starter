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
- Delivery strategy: ask-on-risk. Forecast: approximately 250–400 authored
  changed lines, advisory only; no automatic size stop.

## Tasks

- [ ] EPI-1 — Add host-only read-only checker, exported Task entry, and Bats
  fixtures for clean/unrelated paths, reserved collisions, symlinks, dirty
  worktree, and unchanged Git state. Route: delegated writer (multiple
  nontrivial files, preparation read). Checks: focused Bats, maintainer unit,
  `git diff --check`; prove no repository mutations in fixtures.
- [ ] EPI-2 — Verify release export in a disposable distribution fixture and
  document host invocation, direct and manual paths in README and
  `.devcontainer/docs/`, with index link. Route: delegated writer (multiple
  nontrivial files and documentation preparation). Checks: distribution Bats,
  markdownlint, links, `git diff --check`; preserve user's existing README edits.

## Acceptance and progress

- Task and script resolve from the published `starter` tree, not `.maintainer/`.
- A target with reserved paths never receives a direct-merge recommendation.
- Compatible state never implies a conflict-free merge; user reviews the
  two-parent merge and owns every commit and future update.
- No work unit has started. Mirror the full document to Engram after each update;
  commit work units on a feature branch with verification and commit identity.

## Next step

Implement EPI-1 after readback of this document and its Engram mirror.
