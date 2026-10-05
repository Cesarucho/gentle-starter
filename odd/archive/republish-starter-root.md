# Republish corrected starter as a new root

## Objective and scope

Publish committed `dev` to the authorized `origin/dev`, retire the verified old local and remote `starter`, then generate, inspect, promote, and publish a new independent root `starter` from corrected `dev`. Cancel the local candidate only after exact remote publication proof. Preserve backup and unrelated branches and worktrees.

## Constraints and route

- ODD TDD mode unknown; this is a non-code release, so use focused local checks, immutable Git IDs, and filtered-tree comparison rather than inventing a failing test.
- Route inline: remote mutations are limited to configured SSH `origin` at `git@github.com:Cesarucho/gentle-starter.git` and only `dev` and `starter`. No Docker, build, lifecycle, PR, or other remote work.
- Stop on any unexpected state or failed mutation; record partial evidence and preserve state. Do not retry remote writes blindly.
- Initial expected state: clean `dev` at `94c869f0983caff304d174e33be39058b86baa48`, remote `dev` at `078ae5e2b375a54c3ffced2f21b2a7838142496e`, both `starter` refs at `c5c7c4b360661a11bd16d6df1f9e35687849bba3`; no `starter-rc`; backup at `42b5d16`; no worktree on `starter`. Recheck before mutation.

## Tasks and acceptance checks

- [x] R1: Recorded and read back this task and its full Engram mirror (`odd/republish-starter-root/tasks`). Committed the planning unit to `dev` as `cb56a334a0375fb1252cf1cb2e6f79363df1d226`; source worktree was clean before candidate generation.
- [x] R2: `git diff --check` passed, `markdownlint-cli2 .devcontainer/README.md` reported zero issues, and `git fsck --no-reflogs --connectivity-only` exited 0 (dangling objects reported). Confirmed remote, refs, worktrees, backup, corrected README, and the single-path filtered-tree difference.
- [x] R3: Published and verified `origin/dev` at `cb56a334a0375fb1252cf1cb2e6f79363df1d226`. Deleted old `origin/starter` with an exact lease pinned to `c5c7c4b360661a11bd16d6df1f9e35687849bba3` and verified absence. `git branch -d starter` refused because the independent root was not merged into `dev`; stopped. After the user's renewed authorization and state checks, the parent removed only the old local `starter` with `git branch -D starter`.
- [x] R4: Generated `starter-rc` at `6782b71cc61396bed6b6f63086a684de4b35b49d` with `--base-absent`. Verified zero parents, source trailer `cb56a334a0375fb1252cf1cb2e6f79363df1d226`, zero base trailer, and tree `43ce2b6bcd78eedba33dee0c7f7dc2496a940a74`. Diff against old tree `a9b7e0a3fcb80692367f380695bf1cc5d00f0c6f` changed only `.devcontainer/README.md` wording; diff check, Markdown lint (zero issues), and connectivity check passed.
- [x] R5: Promoted the exact candidate/tree/source with absent base to new root `starter` at `438b4bb30f3c1ec63208d302af66f27776cac204`. Verified zero parents, identical tree, and release-source trailer. Published `starter:starter` and verified exact `origin/starter` SHA; canceled local `starter-rc` only afterward.
- [x] R6: Record exact identities and checks here and in Engram, and report remote/local status. Final evidence commit remains local; it does not change the published source commit.

## Progress

The new release is a root commit sourced from `cb56a334a0375fb1252cf1cb2e6f79363df1d226`, which matches published `origin/dev`. The backup remains `42b5d16442ba7d02fffa42bf0eca2564cd4a5783`; unrelated branches and worktrees were untouched. No build, Docker, or lifecycle run was performed. Runtime harness: N/A for this non-code Git release; focused tree/ref checks are the release proof. Rollback boundary for this evidence unit is this task document only; published remote refs need a separate authorized recovery plan, not an implicit rollback. The final evidence commit is local to `dev` and is not part of the published source or `starter` tree.
