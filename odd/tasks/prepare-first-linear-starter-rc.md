# Prepare first linear starter candidate

## Objective and scope

Integrate the reviewed local feature branch into local `dev` by fast-forward, verify it, then prepare and inspect the first local filtered `starter-rc` using `--base-absent`. User authorized these local steps, not a real `starter` promotion, remote push, PR, or Docker lifecycle.

## Constraints

- Preserve `backup/starter-before-linear` at `42b5d16`; old local and remote `starter` are absent.
- Keep producer worktree/index clean before candidate generation. No live remote operation.
- ODD TDD mode unknown in project; use ordinary Bats and maintainer test suite. Route inline for Git state/fast-forward; delegate verification if necessary. Delivery strategy previously selected feature-branch-chain; no PR authorized.

## Tasks

- [x] I1: Fast-forwarded local `dev` from `48c84a9` to feature tip `3ed5a21` after confirming ancestry and clean worktree. Focused Bats 21/21 and `task validate` (0 errors/warnings, 0 Markdown issues) passed; `git diff --check` passed. Full `test:starter` not run at this boundary: verifier inspection found live HTTPS fetches in its unit suite, incompatible with this run's no-remote constraint. Prior feature run passed 480 unit tests and 34 integration tests (17 optional skips). Existing feature commits retained; no merge commit.
- [ ] I2: On clean `dev`, run `distribution:candidate -- --base-absent` once; inspect root parents, filtered tree, source/base markers, ref state and backup. Do not promote or publish; record candidate identity and evidence.

## Progress

I1 integrated and verified locally; `dev` at `3ed5a21` before this progress record, ahead of `origin/dev`; backup present at `42b5d16`, old `starter` absent. Next: commit this record on a feature branch, fast-forward `dev`, then prepare first local candidate from its exact tip.
