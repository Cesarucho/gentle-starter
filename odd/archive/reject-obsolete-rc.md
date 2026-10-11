# Reject explicitly pinned obsolete RCs

## Objective and authorized scope

Make `distribution:reject -- --expected-rc FULL_RC_SHA` discard that valid local
candidate even when its recorded release base is absent, missing, or obsolete.
Rejecting does not promote, recreate an RC, roll back starter, or mutate source.
Update candidate helper, fixture tests and producer guide together.

## Safety and route

Keep exact full expected-RC validation, clean worktree/index, nonsymbolic and
not-checked-out candidate, candidate provenance/chain validation and deletion CAS.
Preserve candidate preparation, promotion, status and legacy cancellation guards.
Reject must not require current base presence/publication relation. Retain legacy
`--base-absent` acceptance for reject callers, but it is no longer required for
rejection; document its continuing preparation/legacy-cancel meaning explicitly.
No real RC deletion, ref mutation, build, network, staging, commit or push.
Delegated-direct route: multi-file behavior/test/docs change. Forecast 150–300
authored changed lines, advisory only. Delivery strategy ask-on-risk.

## Checklist and acceptance

- [x] T1: Observe RED then GREEN for obsolete-base rejection with and without
  legacy absence flag, retain guard failures and complete legacy regression tests.
- [x] T2: Update copyable report commands and docs, independently verify local
  fixture behavior/ref preservation, then parent reconcile and archive.

## Verification and recovery

Default deterministic test-first policy. Focused and full distribution Bats suite
in disposable Git fixtures, PYTHONDONTWRITEBYTECODE=1, 600000ms timeout. Python
AST, configured Markdown and diff checks. No Docker/live release proof.
Initial clean dev HEAD 137ee75; existing starter/RC refs must remain unchanged.
Locator `odd/archive/reject-obsolete-rc.md`; mirror `odd/reject-obsolete-rc/tasks`.

## Implementation evidence

Explicit rejection skips current release presence/resolution/publication checks
only; historical candidate identity/tree/chain and pinned deletion CAS remain.
Legacy cancellation, preparation, promotion and inconsistent-status diagnostics
retain their guards. Successful reports omit the irrelevant absence flag.

- RED: focused `obsolete|reject` suite failed 10 of 21 tests before implementation,
  including initial absence, unrelated current release and obsolete later base.
- GREEN: `PYTHONDONTWRITEBYTECODE=1 bats --filter 'obsolete|reject'
  .maintainer/test/unit/starter-distribution.bats` passed 21/21.
- Regression: `PYTHONDONTWRITEBYTECODE=1 bats
  .maintainer/test/unit/starter-distribution.bats` passed 59/59 (600000ms timeout).
- Fixture checks cover historical source/base object and other-ref/index
  preservation, source movement/absence, no replacement RC, malformed source/tree/
  base/chain, stale or abbreviated pins, dirty/staged/checked-out/symbolic guards,
  root/custom-name constraints and failed deletion CAS.
- Changed old expectations narrowly: explicit rejection no longer requires the
  absence flag or a legitimate publication relationship; legacy cancel still does.
- No primary discard, preparation, promotion, build, Docker or network operation.
- Python AST passed with bytecode unchanged; configured Markdown passed (24 files,
  zero issues); `git diff --check` passed. Primary HEAD/all refs/index match the
  initial inspection, with index hash `915f82b0e62f66b9d8cd32165add78d525236bb0`.

T2 remains pending parent reconciliation, independent review and archival.

## Parent closure

Authorized rejection behavior and docs are complete. Independent verification
observed 59/59 fixture tests passing and identical primary refs/status/index.
Parent AST and diff checks passed; earlier RED and quality evidence remain
writer-reported. No blocker was found. RDD is clone-local off; unassessable native
risk was treated as high for independent verification, not native approval.
No real candidate was discarded. Actual rejection still requires a clean checkout;
these unstaged implementation edits must be reviewed and committed before use.
Parent archived the record and reconciled its full mirror. Next action: owner
reviews the diff; commits and real rejection require separate authorization.
