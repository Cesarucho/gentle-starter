# Prepare first linear starter candidate

## Objective and scope

Integrate the reviewed local feature branch into local `dev` by fast-forward, verify it, then prepare and inspect the first local filtered `starter-rc` using `--base-absent`. User authorized these local steps, not a real `starter` promotion, remote push, PR, or Docker lifecycle.

## Constraints

- Preserve `backup/starter-before-linear` at `42b5d16`; old local and remote `starter` are absent.
- Keep producer worktree/index clean before candidate generation. No live remote operation.
- ODD TDD mode unknown in project; use ordinary Bats and maintainer test suite. Route inline for Git state/fast-forward; delegate verification if necessary. Delivery strategy previously selected feature-branch-chain; no PR authorized.

## Tasks

- [ ] I1: Fast-forward local `dev` from `48c84a9` to feature tip after confirming ancestry, clean checkout and worktree assignments; run focused and applicable maintainer checks. Record observed results and commit boundary (existing feature commits, no synthetic merge).
- [ ] I2: On clean `dev`, run `distribution:candidate -- --base-absent` once; inspect root parents, filtered tree, source/base markers, ref state and backup. Do not promote or publish; record candidate identity and evidence.

## Progress

Not started. Feature tip `a04832d`; local `dev` at `48c84a9`, confirmed ancestor; backup present at `42b5d16`. Next: mirror, fast-forward local dev, verify, then prepare candidate.
