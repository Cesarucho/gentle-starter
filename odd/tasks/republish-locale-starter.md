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

- [ ] L1: Write and read back this plan and its full Engram mirror (`odd/republish-locale-starter/tasks`); commit plan on `dev` as `docs(odd)` before publishing, pinning source SHA.
- [ ] L2: Run focused 36 Bats, `git diff --check`, and Markdown lint. Record exact commands/results and compare expected old release with locale feature files.
- [ ] L3: Recheck refs and worktrees, push `dev` and verify remote SHA. Delete remote `starter` using exact old-SHA lease and verify absence. Verify local SHA and worktree ownership before deleting local `starter` with `git branch -D`.
- [ ] L4: Create candidate with `--base-absent`; verify full RC, tree, source/base trailers, root status, and filtered tree against committed `dev` and old release feature files.
- [ ] L5: Promote exact approved RC/tree/source with absent base; verify new root, filtered tree, and publish with explicit `git push origin starter:starter`. Verify remote exact SHA before canceling RC.
- [ ] L6: Record exact evidence in this file and Engram mirror; commit final evidence locally and report pending unpushed `dev` evidence.

## Progress

Pending preflight and local checks. Runtime harness: N/A for release orchestration; prior isolated custom-locale proof exists. Rollback boundary: this planning/evidence document only; remote publication requires separately authorized recovery.
