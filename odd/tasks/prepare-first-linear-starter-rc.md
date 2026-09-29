# Prepare first linear starter candidate

## Objective and scope

Integrate the reviewed local feature branch into local `dev` by fast-forward, verify it, then prepare and inspect the first local filtered `starter-rc` using `--base-absent`. User authorized these local steps, not a real `starter` promotion, remote push, PR, or Docker lifecycle.

## Constraints

- Preserve `backup/starter-before-linear` at `42b5d16`; old local and remote `starter` are absent.
- Keep producer worktree/index clean before candidate generation. No live remote operation.
- ODD TDD mode unknown in project; use ordinary Bats and maintainer test suite. Route inline for Git state/fast-forward; delegate verification if necessary. Delivery strategy previously selected feature-branch-chain; no PR authorized.

## Tasks

- [x] I1: Fast-forwarded local `dev` from `48c84a9` to feature tip `3ed5a21` after confirming ancestry and clean worktree. Focused Bats 21/21 and `task validate` (0 errors/warnings, 0 Markdown issues) passed; `git diff --check` passed. Full `test:starter` not run at this boundary: verifier inspection found live HTTPS fetches in its unit suite, incompatible with this run's no-remote constraint. Prior feature run passed 480 unit tests and 34 integration tests (17 optional skips). Existing feature commits retained; no merge commit.
- [x] I2: On clean `dev`, ran `distribution:candidate -- --base-absent` once. Local `starter-rc` = `c3d80a30b6cc10c94a0f43fdce5135730a39b329`, root with zero parents; tree `3af2fc38a3e2faf093de3ea577041a57c8fe6eb9` independently matched `filtered_tree(96ed75233d8e040b82af1bd31b96920febe6e572)` and generated catalog. Source marker pins `96ed75233d8e040b82af1bd31b96920febe6e572`; base marker is all zeros. Local `starter` absent, backup `42b5d16` intact, no remote operation; worktree clean at inspection. Candidate not promoted or published.
- [x] I3: Audited I2 in a disposable local clone. Found root `task help` advertised excluded `.maintainer/Taskfile.yml` (command exited 100 in clone). Fixed in `Taskfile.yml` with regression test commit `5a77a5c` (RED observed before fix, GREEN 22/22 Bats after); native committed-only assessment medium `under_budget` (18 lines), no review launched. Advanced local `starter-rc` to `cdcec88327d49f122f98ae9901719d8b1f993e67` (parent `c3d80a3`, source `5a77a5c`, zero base). Independent verifier confirmed tree `a9b7e0a3fcb80692367f380695bf1cc5d00f0c6f` matches filtered source and 12-skill catalog, 275 paths, no dev ancestry; disposable clone `task help` and `task --list` both exited 0, no missing maintainer command, worktrees clean and clone removed. No Docker or remote proof.

## Progress

I1–I3 complete. Latest candidate is pinned to source `5a77a5c` and tree `a9b7e0a3fcb80692367f380695bf1cc5d00f0c6f`; earlier root candidate remains its parent but neither was promoted. Later documentation-only `dev` progress commits do not implicitly change candidate. Next: choose explicitly whether to advance/cancel it or promote this pinned candidate locally. No new `starter` release or remote publication exists. The full `test:starter` suite was not rerun in this no-remote step; focused Bats and `task validate` passed. No Docker lifecycle proof was run.
