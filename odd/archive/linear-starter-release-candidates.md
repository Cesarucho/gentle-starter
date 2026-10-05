# Linear starter release candidates

## Objective and scope

Publish filtered consumer releases through a testable `starter-rc` branch without exposing producer history or candidate iteration commits in `starter`. Local implementation only: no fetch, push, remote branch deletion, or live container lifecycle. Existing unpublished `starter` may be replaced locally only after fixture proof; keep its ref until explicit cutover approval.

## Constraints

- Keep committed-source filtering and consumer-owned file protection.
- An approved candidate is identified by immutable commit/tree and previous `starter` tip; canceled candidates never publish.
- `starter` starts at a root commit and advances by one-parent release commits only. Consumers retain normal merge updates.
- TDD mode: unknown (no ODD setting established; SDD cache does not apply). Run ordinary focused Bats checks; runner `bats .maintainer/test/unit/starter-distribution.bats`.
- Route: delegated direct writer; source, tests, and docs are multiple nontrivial files; read preparation belongs to writer. Delivery strategy: ask-on-risk; user chose feature-branch-chain for future PR delivery. Forecast ~450–800 authored lines; 400-line work-unit figure advisory, not a cap. Proposed PR boundaries (not created): T1 `00b92df` (~299 lines), T2 `ff5e6c3` (~368 lines), T3 work-unit commit (~155 lines), each depending on the previous branch; tracker draft/no-merge until integration. No remote action is authorized.

## Tasks

- [x] T1: Implement isolated linear candidate creation/update with provenance and canceled-candidate semantics. Acceptance: filtered tree, no source parent, repeat no-op, source-only advance, safe refusal on unexpected refs. Focused Bats 21/21, `git diff --check` passed; independent verification found a symbolic-ref mutation risk, fixed and regression-tested. Commit: `00b92df`. Native committed-only tier high, candidate review granted and approved/acknowledged (`review-fbe2393c0a86a383`); informational warnings: candidate checked out in another worktree and cancellation when source branch is absent. Carry these into T2.
- [x] T2: Implement explicit candidate promotion to one linear `starter` commit pinned to candidate SHA/tree/base/source, with no intermediate candidate commits and no mutation on stale identity. Focused Bats 27/27 and `git diff --check` passed; independent verification found blocked post-promotion retirement, fixed with verified cancellation and regression coverage. Commit: `ff5e6c3`. Native tier high, review granted and approved/acknowledged (`review-45da74c4b3a73a1c`); informational warning: previous release tree not checked against recorded filtered source. Carry into T3.
- [x] T3: Updated operator/consumer docs and regression tests, including prior-release tree validation and two consumer merges preserving local commits; local cutover is documented but not executed. Focused Bats 29/29, maintainer suite 488/488 unit and 34/34 integration (optional-tool skips), `task validate` passed with 0 diagnosis/lint issues, `git diff --check` passed; independent verifier PASS with no blocking defect. Commit `d000576`, native tier high, review granted and approved/acknowledged (`review-5ede0d7a65fc7417`).

## Progress

T1–T3 closed on `feat/linear-starter-release-candidates`; no remote operations. Original local and remote `starter` remain at `42b5d16`. Running authored change count exceeds the ~400 delivery planning heuristic (T1 299, T2 368, T3 159); user selected feature-branch-chain, with boundaries above. Next: review the three commits and explicitly authorize a separate local cutover when ready. No real `starter-rc` or new `starter` was created. Remote publication requires separate destination, operation, and credential/session authorization. Rollback: revert `d000576`, `ff5e6c3`, then `00b92df` if reverting the full feature.
