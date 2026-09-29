# Retire legacy starter distribution

## Objective

Remove obsolete dev-parent distribution commands, scripts, tests and current guidance after the explicitly authorized removal of the old local and remote `starter` refs. Preserve the working linear candidate/promotion workflow and its filtered-tree contract. Historical ODD records remain historical.

## Scope and constraints

- User authorized removal of `origin` `refs/heads/starter` using configured Git SSH session, and local `starter`; no authorization to push `dev`, publish a new remote `starter`, create PRs, or delete other remote branches.
- Old local/remote refs at `42b5d16` were checked; a local `backup/starter-before-linear` remains at that exact SHA. Remote deletion used the expected SHA and was verified absent; local old ref was deleted and verified absent.
- Work on `feat/linear-starter-release-candidates`; keep the backup and do not create/publish a real new `starter` without review of resulting candidate and explicit approval.
- Route: delegated direct writer; >4 relevant files and multiple nontrivial code/tests/docs. ODD TDD mode unknown (prior ODD evidence); run focused Bats and maintainer suite. Delivery strategy ask-on-risk with feature-branch-chain chosen previously; ~400 authored-line heuristic is advisory per work unit, not a code limit. No Docker lifecycle.

## Tasks

- [x] L1: Extracted committed-source filtering and Git helpers to `starter-source.py`; migrated candidate and promotion; removed legacy scripts and Task commands. Verified shared filter equivalence independently. Shared work-unit commit `72f0c72`; native tier high, review approved/acknowledged (`review-21bf88dcabb5de5e`).
- [x] L2: Replaced legacy Bats fixtures/contracts with supported linear candidate/promotion coverage including filtering, catalog refresh, dirty/malformed inputs, conflicts and consumer updates; preserved unrelated-project adoption. Focused Bats 21/21 with zero skips; maintainer suite 480 unit tests passed and 34 integration tests (17 expected optional skips); `git diff --check` passed; independent verifier PASS. Shared work-unit commit `72f0c72`, same native review.
- [x] L3: Removed obsolete active guidance from maintainer/operator/user docs and AGENTS without rewriting historical records; documented absent old starter, first RC `--base-absent`, promotion, and post-publication cancellation. Focused Bats 21/21; maintainer suite 480/480 unit and 34 integration (17 expected optional skips); `task validate` 0 errors/warnings/Markdown issues; `git diff --check` passed; independent verifier PASS. Work-unit commit/native assessment pending.

## Progress

Old local and remote starter deleted; backup preserved. L1/L2 closed together as one coherent migration work unit `72f0c72` (734 authored lines including deletions, not compressed); L3 documentation and checks observed. Next: close L3 commit and assess review due. No new starter published. Rollback L1/L2: revert `72f0c72` without mutating remote refs.
