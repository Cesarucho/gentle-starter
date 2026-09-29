# Republish locale-aware starter as a new root

## Objective and scope

Publish committed locale-aware `dev`, replace the old independent `starter` root by deleting the exact old remote ref and local branch, then create, inspect, promote, and publish a new root release. Preserve all unrelated branches, worktrees, and the backup.

## Constraints and route

- ODD TDD mode unknown; this is release orchestration, not application code. Use focused Bats, diff checks, Markdown lint, and immutable Git IDs. Prior isolated custom-locale Docker proof passed; do not rebuild.
- Authorized remote is configured SSH `git@github.com:Cesarucho/gentle-starter.git`, limited to `origin/dev` push and `origin/starter` deletion/publication. No other remote or Docker operations.
- Accepted: replacing `starter` history and the blank line in `.env.example`.
- Stop on any mismatch, failed mutation, or unknown result. Never blindly retry. Final evidence is committed locally, not pushed without separate approval.
- Expected preflight: clean `dev` at `7f62e964bfc5c500b2fc63e7b9023cab0867ad6d`; remote `dev` at `759dece7418816471d86bb7d9976dde559fb52fe`; local and remote `starter` at `438b4bb30f3c1ec63208d302af66f27776cac204`; no `starter-rc`; backup `backup/starter-before-linear` at `42b5d16442ba7d02fffa42bf0eca2564cd4a5783`; no worktree on `starter`.

## Tasks and acceptance checks

- [x] L1: Write and read back this plan and its full Engram mirror (`odd/republish-locale-starter/tasks`); commit plan on `dev` as `docs(odd)` before publishing, pinning source SHA.
- [x] L2: Run focused 36 Bats, `git diff --check`, and Markdown lint. Record exact commands/results and compare expected old release with locale feature files.
- [x] L3: Recheck refs and worktrees, push `dev` and verify remote SHA. Delete remote `starter` using exact old-SHA lease and verify absence. Verify local SHA and worktree ownership before deleting local `starter` with `git branch -D`.
- [x] L4: Create candidate with `--base-absent`; verify full RC, tree, source/base trailers, root status, and filtered tree against committed `dev` and old release feature files.
- [x] L5: Promote exact approved RC/tree/source with absent base; verify new root, filtered tree, and publish with explicit `git push origin starter:starter`. Verify remote exact SHA before canceling RC.
- [x] L6: Record exact evidence in this file and Engram mirror; commit final evidence locally and report pending unpushed `dev` evidence.

## Progress

Release published; final evidence is local to `dev` and must not be pushed without separate authorization. Runtime harness: N/A for release orchestration; prior isolated custom-locale proof exists. Rollback boundary for this evidence unit: this document only; changing the published release requires separately authorized recovery.

### Release evidence

- Plan commit and published source: `d5af28abd66c181a1209ba6df8cd0f3b46b8fc79`. The local `origin/dev` tracking ref matched this SHA before the evidence commit. The old starter was `438b4bb30f3c1ec63208d302af66f27776cac204`; backup branch `backup/starter-before-linear` remains `42b5d16442ba7d02fffa42bf0eca2564cd4a5783`.
- The prior release run recorded focused Bats **36/36**, diff checks and Markdown lint with zero issues; the old and new filtered trees differed in eight expected locale-related files. Those exact test commands were not preserved in this document and were not rerun during final recovery. A final `git diff --check` passed; a final direct `markdownlint odd/tasks/republish-locale-starter.md` attempt could not run because `markdownlint` is not installed in this shell.
- Candidate `f4f9e7bccf6ce784d106ccb872b411a8bc74c148` has tree `b889ec5eb2e1986173a7ba3a4eaca4af4f8e5261`, no parent, source trailer `d5af28abd66c181a1209ba6df8cd0f3b46b8fc79`, and absent-base trailer `0000000000000000000000000000000000000000`.
- Published root `5b31df82016c4fbc843ca42dd6e7cf2cc96076fe` has the same tree, no parent, and source trailer `d5af28abd66c181a1209ba6df8cd0f3b46b8fc79`. The user reported publication after a read-only check found remote `starter` absent. A fresh `git ls-remote --heads origin starter` independently returned exactly `5b31df82016c4fbc843ca42dd6e7cf2cc96076fe refs/heads/starter` before RC cancellation.
- After publication, `task --taskfile .maintainer/Taskfile.yml distribution:candidate -- --cancel` reported `Canceled starter-rc at f4f9e7bccf6ce784d106ccb872b411a8bc74c148; release unchanged.` A subsequent `git show-ref --heads` succeeded, contained `starter` at the release SHA, and did not contain `starter-rc`; `git show-ref --verify --quiet refs/heads/starter-rc` confirmed absence. `dev` was clean at the source SHA before this documentation edit.

### Local ref conflict and recovery

Promotion initially reported success but left `.git/refs/heads/starter [conflicted]` instead of a resolvable `starter`; publication stopped. Its exact bytes were preserved in `.git/starter-conflicted-ref.backup`. Following a local ref repair, a push failed with `src refspec starter does not match any`: a second rename had produced `.git/refs/heads/starter [conflicted 2]`. Publication stopped again without retry. After external synchronization was paused, the second renamed ref was compared byte-for-byte with the original backup, preserved in the distinct `.git/starter-conflicted-ref-second.backup`, and removed; `git update-ref` restored `starter` using expected-absent semantics. `git show-ref --heads` succeeded twice across a five-second stability interval. The cause of the external renames was not established. Both `.git` backups and the backup branch are intentionally retained; no cleanup, rebuild, or unrelated ref mutation was performed in the final recovery.

The earlier focused 36-Bats, filtered-tree comparison, and Markdown lint outcomes were not reproduced in this final recovery; the prior custom-locale lifecycle proof was not rerun. The final local evidence commit must not be confused with another remote publication.
