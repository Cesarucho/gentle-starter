# Republish corrected starter as a new root

## Objective and scope

Publish committed `dev` to the authorized `origin/dev`, retire the verified old local and remote `starter`, then generate, inspect, promote, and publish a new independent root `starter` from corrected `dev`. Cancel the local candidate only after exact remote publication proof. Preserve backup and unrelated branches and worktrees.

## Constraints and route

- ODD TDD mode unknown; this is a non-code release, so use focused local checks, immutable Git IDs, and filtered-tree comparison rather than inventing a failing test.
- Route inline: remote mutations are limited to configured SSH `origin` at `git@github.com:Cesarucho/gentle-starter.git` and only `dev` and `starter`. No Docker, build, lifecycle, PR, or other remote work.
- Stop on any unexpected state or failed mutation; record partial evidence and preserve state. Do not retry remote writes blindly.
- Initial expected state: clean `dev` at `94c869f0983caff304d174e33be39058b86baa48`, remote `dev` at `078ae5e2b375a54c3ffced2f21b2a7838142496e`, both `starter` refs at `c5c7c4b360661a11bd16d6df1f9e35687849bba3`; no `starter-rc`; backup at `42b5d16`; no worktree on `starter`. Recheck before mutation.

## Tasks and acceptance checks

- [ ] R1: Record and read back this task and its full Engram mirror (`odd/republish-starter-root/tasks`). Commit this release planning unit to `dev` with a Conventional Commit. Confirm clean source before candidate generation.
- [ ] R2: Run focused checks (`git diff --check`, `markdownlint-cli2 .devcontainer/README.md`, `git fsck --no-reflogs --connectivity-only`); inspect corrected README and source/old-release filtered-tree differences. Confirm old refs, configured remote, worktrees, and backup again.
- [ ] R3: Push committed `dev` to `origin/dev` and verify exact remote SHA. Delete only old `origin/starter` with a lease pinned to its observed SHA; verify absence. Delete old local `starter` with `git branch -d` after confirming no worktree uses it.
- [ ] R4: Run `distribution:candidate -- --base-absent` from clean `dev`; inspect full candidate ID, zero parents, source/base trailers, tree, and filtered diff versus old `starter`. Stop if changes exceed corrected README wording or expected distribution effects.
- [ ] R5: Promote using exact observed `--approved-rc`, `--expected-tree`, `--expected-base absent`, and `--expected-source`; verify new local root, tree and source trailer. Push `starter:starter` to authorized origin, verify remote SHA, then cancel only local `starter-rc`.
- [ ] R6: Report exact SHAs, checks, remote and local status, and remaining documentation/mirror follow-up. Keep final evidence updates local unless a later authorized push is explicitly within scope.

## Progress

Planning recorded before the first mutation; no release mutation performed yet. Runtime harness: N/A for non-code Git release; rollback boundary is only the newly authored task documentation (remote ref publication requires a separate recovery plan, never an implicit rollback).
