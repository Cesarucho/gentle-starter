# Simple local starter release workflow

## Objective and rationale

Make the starter-rc/starter lifecycle concrete and easy to follow: happy path,
RC rejection, and next release. Automate identity reporting and guarded rejection
using the existing release engine rather than adding another framework.

## Authorized scope

Extend candidate helper reporting, read-only status and expected-RC cancellation;
add thin maintainer Task entries, deterministic tests, and simplified producer docs.
Preserve existing candidate/promotion provenance, explicit absence, dirty-worktree,
checked-out-ref, and compare-and-swap protections. Promotion keeps explicit four
identity approvals; preparation prints a copyable command but grants no approval.
No real release refs, installs, builds, container lifecycle, remote operations,
commits, staging or push are authorized by this implementation request.

## Route and constraints

One coherent delegated-direct work unit; triggers: multi-file behavior change and
preparation for writing. Forecast: approximately 350–600 authored changed lines,
advisory only; tests and safety must not be omitted to meet a size target.
Delivery strategy: ask-on-risk; commits require separate owner approval. RDD status
must be read at verification; parent owns closure and archival. Status must not
recompute filtered trees, write Git objects, or imply full provenance validation.
Keep optional expensive proofs and remote publication separate from happy path.
Distinguish HOST/CONTAINER and never invent host paths or remote authorization.

## Acceptance and checklist

- [x] T1: Add complete preparation/no-op identity report, read-only status, and
  explicitly pinned rejection with observed deterministic RED then GREEN.
- [x] T2: Simplify producer guide into happy path, reject, and next cycle; remove
  historical state claims from instructions, retain deep-dive anchors/history.
- [x] T3: Verify disposable-repository behavior, Task wiring, docs quality,
  unchanged primary refs/worktree, and independent evidence before parent closure.

## Verification

Default test-first policy: add runnable Bats workflow tests before behavior changes.
Run focused workflow and full starter-distribution unit suite in disposable local
Git fixtures, with explicit 600000ms command timeout. No Docker/network intended.
Run check-only Python/syntax and Markdown validation and git diff checks.
Actual HOST runtime and remote publication proof are outside scope, not claimed.

## Recovery

Initial branch dev; HEAD 3e21ac5; worktree clean. Implementation pending.
Locator `odd/archive/starter-rc-workflow.md` (formerly `odd/tasks/starter-rc-workflow.md`).
Engram mirror topic `odd/starter-rc-workflow/tasks`.

## Implementation evidence (2026-10-10)

- RED: `PYTHONDONTWRITEBYTECODE=1 bats --filter workflow .maintainer/test/unit/starter-distribution.bats`
  initially failed 8/10 tests on missing reports, modes and Task wiring. Two
  generic negative tests already passed; their guard-specific diagnostics were
  strengthened before final verification.
- GREEN: the same focused command passed 11/11; full
  `PYTHONDONTWRITEBYTECODE=1 bats .maintainer/test/unit/starter-distribution.bats`
  passed 47/47 with 600000ms foreground timeouts. Fixtures use disposable local
  Git repositories, no network or Docker. Legacy cancel/promotion remained green.
- Status filesystem snapshots include objects, index, refs and worktree bytes;
  actual Task status also passes without an inherited Python bytecode setting.
  Instrumented status refuses any call to full identity/filtered-tree validation.
- Python AST parsing passed without bytecode output. Markdown validation passed
  after fixing a list prefix. Passive docs have no meaningful behavior-level RED.
- `task validate` intentionally not run: its runtime manifest path reads local
  environment inputs and invokes Docker, outside this delegation's safety scope.
- Before/after read-only inventory: branch `dev`, full HEAD
  `3e21ac55d04aaf2b0702d7dae4255d8585b81b32`, all refs and the clean index unchanged.
  Only the six allowed files are edited; all changes remain unstaged/uncommitted.
- T3 remains parent-owned: independent review/RDD disposition, final reconciliation
  and archival are pending. No live RC, host runtime or remote proof is claimed.
- Tracked diff: 533 insertions/60 deletions, plus this untracked task record.
  The 350–600-line advisory is exceeded once the record is included; safety tests
  and historical context were retained rather than compressed or split artificially.

## Parent closure

Parent reconciled the authorized implementation with writer evidence and independent
47/47 fixture tests and zero-issue Markdown verification. Primary refs, HEAD, and
status listing were unchanged by verification; fixture status tests additionally
prove byte-level filesystem/index preservation. Parent AST and diff checks passed.
No candidate-caused blocker remains. `task validate` was deliberately skipped
because its Docker access is outside scope; exact-primary-RC runtime and remote
publication proofs remain unauthorized and are not claimed.
RDD is clone-local off; native assessment was unassessable due to untracked files
and treated as high for independent verification, not as approval. Parent archived
this record with its historical evidence and synchronized the full recovery mirror.
Changes remain unstaged/uncommitted. Next action: owner reviews commands and docs.

## Owner-approved delivery

The owner subsequently requested a local commit and explicitly approved keeping
commands, tests, guide, and this record together despite the advisory size budget
(`exception-ok`). Prior uncommitted-state statements remain historical evidence.
No push, remote publication, or real release operation is authorized.
