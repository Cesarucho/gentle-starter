# Linear starter release candidates

## Objective and scope

Publish filtered consumer releases through a testable `starter-rc` branch without exposing producer history or candidate iteration commits in `starter`. Local implementation only: no fetch, push, remote branch deletion, or live container lifecycle. Existing unpublished `starter` may be replaced locally only after fixture proof; keep its ref until explicit cutover approval.

## Constraints

- Keep committed-source filtering and consumer-owned file protection.
- An approved candidate is identified by immutable commit/tree and previous `starter` tip; canceled candidates never publish.
- `starter` starts at a root commit and advances by one-parent release commits only. Consumers retain normal merge updates.
- TDD mode: unknown (no ODD setting established; SDD cache does not apply). Run ordinary focused Bats checks; runner `bats .maintainer/test/unit/starter-distribution.bats`.
- Route: delegated direct writer; source, tests, and docs are multiple nontrivial files; read preparation belongs to writer. Delivery strategy: ask-on-risk. Forecast ~450–800 authored lines; 400-line work-unit figure advisory, not a cap.

## Tasks

- [x] T1: Implement isolated linear candidate creation/update with provenance and canceled-candidate semantics. Acceptance: filtered tree, no source parent, repeat no-op, source-only advance, safe refusal on unexpected refs. Focused Bats 21/21, `git diff --check` passed; independent verification found a symbolic-ref mutation risk, fixed and regression-tested. Commit: `00b92df`. Native committed-only tier high, candidate review granted and approved/acknowledged (`review-fbe2393c0a86a383`); informational warnings: candidate checked out in another worktree and cancellation when source branch is absent. Carry these into T2.
- [x] T2: Implement explicit candidate promotion to one linear `starter` commit pinned to candidate SHA/tree/base/source, with no intermediate candidate commits and no mutation on stale identity. Focused Bats 27/27 and `git diff --check` passed; independent verification found blocked post-promotion retirement, fixed with verified cancellation and regression coverage. Commit: pending; native review assessment pending. Worktree guards and cancellation without source branch covered.
- [ ] T3: Update operator/consumer docs and applicable regression tests, run maintainer unit suite and check-only validation. Document local cutover procedure without executing remote operations; record commit and review outcome.

## Progress

T1 closed on `feat/linear-starter-release-candidates`; T2 implementation and focused checks observed. No remote operations. Original local `starter` remains at `42b5d16`; next: close T2 work-unit commit, then T3. T1 rollback: revert `00b92df`. T2 rollback: revert its promotion script, Task command, candidate lifecycle fix, focused tests, and documentation.
