# Managed OpenCode PATH

## Objective

Give managed OpenCode runtime priority without inheriting the host PATH.

## Scope

Only `.env.example`, `.agents/skills/add-tool/SKILL.md`,
`.devcontainer/test/unit/runtime-path-test.py`, and this record may change.
No Dockerfile, real `.env`, container recreation, remote actions, staging, or commits.
Preserve skill metadata; no registry refresh is required.

## Specs

- S1: Enable `CONTAINER_BASE_PATH=/home/ubuntu/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/ubuntu/.local/share/pnpm/bin:/home/ubuntu/.local/share/pnpm`, followed by `PATH="/home/ubuntu/.gentle-ai/bin:${CONTAINER_BASE_PATH}"` in `.env.example`. Add concise English comments explaining base maintenance and managed OpenCode priority.
- S2: For every added or changed tool, check its executable directory against `CONTAINER_BASE_PATH`; update only when necessary, preserving order without duplicates. Keep skill metadata unchanged.
- S3: Prove exact enabled entries and resolved container PATH through an isolated Compose configuration with hostile host PATH, no unresolved tokens, and no duplicate directories.

## Tasks

- [x] Template and fixture test: parent-observed RED before template edit, then GREEN for S1/S3 (2 tests, exit 0).
- [x] Skill maintenance rule: implemented S2, preserved metadata; parent-run inspector 5 tests, exit 0.
- [x] Closure: owner authorized commit after disclosure of unavailable native review; no permission repair or review approval claimed.

## Route and preparation

Bounded implementation worker; managed-tool PATH maintenance triggers `add-tool`.
Loaded add-tool, skill-improver, operational-verification, and Starter harness.
Forecast: fewer than 100 implementation lines; no commits authorized.
Parent owns synthetic fixture execution/cleanup, independent verification, review,
and record closure. Worker prepares tests only until parent supplies observed RED.
RDD authority failed its permissions guard; mode unknown, no repair authorized.

## Verification

Parent runs `python3 -B .devcontainer/test/unit/runtime-path-test.py` at RED/GREEN,
then `bats .devcontainer/test/unit/add-tool-inspector.bats`.
Run `git diff --check`; configuration proof excludes real `.env` and daemon calls.

## Log

- Prepared active record before source changes. Worktree initially clean at a63d1af.
- User selected parent-owned verification/temporary fixture creation and cleanup.
- Parent observed RED: `python3 -B .devcontainer/test/unit/runtime-path-test.py`
  exited 1 with two tests: enabled entries were `[]` instead of the approved pair;
  missing Compose service environment raised `KeyError`. Compose config itself exited 0.
- Implemented S1 template entries/comments and S2 skill maintenance instruction;
  skill metadata preserved. Changed the S3 missing-environment lookup to report
   an assertion failure instead of `KeyError`. Parent GREEN and inspector proof pending.
- Parent GREEN: Python runner passed 2 tests (exit 0); inspector Bats passed 5 tests
  (exit 0); git diff --check passed. Full public template is now used in the fixture.
- A host CONTAINER_BASE_PATH override affects interpolation, as disclosed in the
  accepted proposal; host PATH alone does not leak into the resolved container PATH.
- Independent read-only verification found S1/S2 met and no reproduced defects;
  requested full-template proof was executed by the parent and passed.
- No image builds, daemon calls, real .env modifications, staging or commits.
- Review assessment returned unassessable/high for undeclared untracked files.
  Mode status failed on unsafe authority permissions; review and archive remain pending.
- User continuation: "Adelante con el commit". Owner authorized the reviewed
  changes after the unavailable-review disclosure; no push authorized.
- Parent reconciled functional proof and archived this record without changing
  historical evidence. Native review remains unavailable, not approved.
