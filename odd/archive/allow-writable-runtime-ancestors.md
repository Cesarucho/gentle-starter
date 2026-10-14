# Allow writable runtime ancestors

## Goal

Accept existing group/other-writable filesystem ancestors while preserving the
runtime directory policy's independent identity and boundary protections.

## Intent and authorization

The user explicitly requested removal of the existing `Plan.check` runtime
`st_mode & 0o022` rejection and accepts the broadened runtime trust boundary.
Existing `0775` and `0777` directories must be accepted subject to remaining
guards. Remove the now-dead sticky-system-directory exception narrowly.
Do not remove the schema rule rejecting a declared writable final-mode parent.

## Specifications

- Preserve owner/type validation, no-follow descriptors, inode binding, applied
  root/manifest validation, and full applicable preflight before mutation.
- Apply exact selected directory modes; leave unselected modes unchanged.
- Preserve independent owner, type, symlink, collision and replacement rejection.
- Do not change normalization, JSON modes, OpenCode files, live permissions,
  authority contents or historical archived documentation.
- Tests use isolated synthetic fixtures only; never read real authority payloads
  or real `.env` files.

## Tasks

- [x] T1: Prepare the seven affected tests first; parent observed RED before the
  narrow runtime guard removal. Retain schema and independent identity coverage.
- [x] T2: Align current install-volume, extension and runtime-directory guidance;
  parent verified full-suite GREEN including relevant alternate/negative cases.

## Execution strategy

- Delegation trigger: preparation and multi-file runtime-contract route.
- Strategy: ask-on-risk; findings do not expand allowed edit surfaces.
- Advisory forecast: at most 300 authored lines. Notify parent before additional
  writes if the change is forecast to exceed 400 lines.
- Current phase: functional tasks complete after parent-observed RED/GREEN and
  independent structural verification; owner acceptance and archival complete,
  parent-owned commit pending.
- Retain the `ancestor` parameter and traversal call arguments to avoid unrelated
  traversal/deferred-root refactoring; it no longer gates runtime mode validation.
- Parent exclusively executes tests and owns isolated fixture creation, chmod,
  cleanup and any separately authorized bounded local synthetic Git history.
- The owner subsequently authorized the parent to commit. This worker remains
  unauthorized to stage or commit; remote operations, daemon changes and
  installation remain unauthorized.

## Verification evidence

Default test-first sequence: tests were prepared before the runtime change;
the parent observed RED, then authorized implementation and observed GREEN.

Parent-observed RED command before helper changes:

```sh
TMPDIR=/tmp/opencode PYTHONDONTWRITEBYTECODE=1 python3 -B .devcontainer/test/unit/runtime-directory-permissions-test.py PolicyTests
```

Parent reported 55 tests, exit 1, six errors and two failures, all from the
existing `Insecure writable ancestor` guard for `0775`/`0777`; remaining tests
passed.

Parent-observed full-suite GREEN command after helper changes:

```sh
TMPDIR=/tmp/opencode PYTHONDONTWRITEBYTECODE=1 python3 -B .devcontainer/test/unit/runtime-directory-permissions-test.py
```

Parent reported 59 tests, exit 0, in 1.253 seconds, and diff check exit 0.
The independent read-only verifier reported structural pass with no blockers,
preserving remaining guards and the schema declared-parent restriction.

No test execution is authorized for this worker. Worker verification is limited
to diff checks and readback; do not infer runtime results.

## Review and lifecycle handoff

Parent-reported RDD status: `off` with `clone_local` scope; global status is `on`.
Assessment is `unassessable`/`high` due to the untracked task document; there is
no native approval. Record this evidence without repair or review disposition.
Owner acceptance is complete: the user explicitly authorized the commit with
“Adelante con el commit”. The record was archived after confirming the destination
was absent. Its current locator is
`odd/archive/allow-writable-runtime-ancestors.md`; the full mirror remains at
`odd/allow-writable-runtime-ancestors/tasks`, observation `3244`.
The authorized commit remains parent-owned and pending; no commit identity is
claimed. This bookkeeping does not constitute native approval or RDD repair.
