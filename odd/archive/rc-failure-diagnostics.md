# Full RC identities on blocked commands

## Objective and scope

Show full RC SHA and available source/tree/pinned-base/current-base identities when
candidate or status refuses a stale/inconsistent RC, without needing a separate Git
command. Diagnostics are not approval or permission to discard the candidate.

## Constraints and route

Preserve existing fail-closed behavior, exit codes, provenance checks, and refs.
Never print actionable promotion/rejection commands for an inconsistent state.
Read metadata only for diagnostics; no filtered-tree recomputation or object writes
in status. Missing/malformed fields must be labeled unavailable rather than invented.
No actual candidate/release/ref deletion, installs, builds, remote work, or commits.
One delegated-direct work unit; multi-file behavior/test/docs change triggers.
Forecast 100–200 authored changed lines; delivery strategy ask-on-risk.

## Acceptance

- [x] T1: Add deterministic RED/GREEN coverage and complete diagnostic output for
  blocked candidate/status, preserving successful output and read-only status.
- [x] T2: Document output, run fixture/quality checks, verify independently as
  applicable, then parent reconciles and archives the record.

## Verification and recovery

Run focused then full `.maintainer/test/unit/starter-distribution.bats` using
disposable Git fixtures, PYTHONDONTWRITEBYTECODE=1, and 600000ms timeout.
Run Python AST and Markdown checks, git diff checks, primary ref preservation.
No Docker or network proof. Default deterministic test-first policy applies.
Initial clean dev HEAD e529a6f; starter and starter-rc are existing inconsistent refs.
Locator `odd/archive/rc-failure-diagnostics.md`; mirror `odd/rc-failure-diagnostics/tasks`.

## Observed implementation evidence

- RED: focused diagnostics initially failed on missing failure identities (2/3);
  the added base-presence mismatch case also failed before its implementation.
- GREEN: `PYTHONDONTWRITEBYTECODE=1 bats --filter diagnostics .maintainer/test/unit/starter-distribution.bats`
  passed 3/3; the same runner without the filter passed 50/50, including the
  existing 47 tests for successful/no-op output, guards and source normalization.
- Shared best-effort diagnostics preserve original errors and omit action commands.
  Fixture snapshots prove inconsistent status leaves files/objects/index/refs intact;
  malformed metadata remains unavailable and absent RC output remains unchanged.
- Read-only primary status returned the expected exit 1 and full RC/source/tree,
  pinned-absent/current-base identities. All primary refs, index bytes, object
  inventory and bytecode inventory remained unchanged. No primary mutation ran.
- Python AST parsing passed without bytecode writes. An initial absolute absence
  assertion found pre-existing October 7 bytecode; it was preserved, and the
  corrected before/after inventory assertion passed.
- Markdown lint with explicit repository config and README/ODD paths passed;
  `git diff --check` passed. Tracked diff: 156 insertions, 14 deletions; the
  pre-existing untracked ODD record is also updated, without staging.
- T2 remains pending parent review, final reconciliation and archival. The worker
  updates/readbacks the full mirror; no approval, commit or closure is claimed.

## Parent closure

Parent reconciled authorized diagnostics, documentation and proof. Independent
verification passed all 50 fixture tests and preserved primary refs/status.
Parent AST and diff checks passed. Writer RED and primary byte-preservation
evidence remain reported observations; no native approval or live release proof
is claimed. RDD is clone-local off; unassessable assessment was treated as high
for independent verification. The actual inconsistent RC remains blocked.
Parent archived the completed record. Changes remain unstaged/uncommitted.
Next action: owner reviews the output and diff before authorizing delivery.

## Accepted output simplification

Reopened after the owner requested less diagnostic noise and approved a compact
default: show only the full blocked RC identity and a concise reason. `--verbose`
retains the detailed metadata report. Failure guards and exit codes remain intact;
successful identity/action reports remain unchanged. No discard or commit authorized.

- [x] T3: Observe RED/GREEN for compact default and verbose details, update docs,
  preserve read-only status and original failures, then parent verifies and rearchives.

### T3 implementation evidence

- Fresh RED: new compact/default cases failed on missing `Blocked RC:` output;
  existing detailed tests failed because `--verbose` was not recognized (5/6 failed).
- GREEN: focused diagnostics passed 7/7 and the full fixture suite passed 54/54
  using the documented PYTHONDONTWRITEBYTECODE runner and 600000ms timeout.
- Default prints one full blocked RC and a concise reason. Valid metadata can
  explain initial-base presence or a missing pinned base, without implying approval;
  malformed metadata uses a generic explanation. `--verbose` retains detailed labels
  and the claims warning. Original errors/exit codes and successful reports remain.
- Custom branch, malformed provenance, missing-base and verbose flag-guard tests
  passed; fixture byte snapshots remained unchanged for read-only status.
- Primary status default and verbose each returned expected exit 1. All primary
  refs, index bytes, object inventory and bytecode inventory remained unchanged.
  No primary candidate, promotion, rejection or ref mutation ran.
- Python AST/no-new-bytecode, configured README/ODD Markdown lint and
  `git diff --check` passed. Tracked accumulated diff is +282/-15
  (297 changed lines, 97 above the original 200-line advisory); no artificial split.
- T3 implementation is observed; parent verification, reconciliation and rearchival
  remain pending. Historical T1/T2 evidence and parent closure are preserved above.

### T3 parent closure

Independent verification observed 54/54 fixture tests passing, accurate compact
reasons, verbose detail retention, and unchanged primary refs/status. Parent AST
and diff checks passed. No correctness blocker remains; earlier proof limitations
and the intentionally blocked actual RC still apply. RDD remains clone-local off,
with unassessable risk treated as high for independent verification. Parent
rearchived this complete record. Changes remain unstaged/uncommitted.
