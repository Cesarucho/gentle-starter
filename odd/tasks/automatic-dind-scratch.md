# Automatic DinD scratch selection

## Objective
Run the explicit maintainer base lifecycle test without asking for a scratch path or daemon-visibility attestation in the supported local Docker-in-Docker topology.

## Problem and constraints
- The CLI currently treats `--daemon-visible-scratch` as an operator promise; a client-visible path may not contain the same bytes from the daemon's perspective. Docker access and matching path text are insufficient proof.
- Generate a unique test-owned scratch directory beneath `/home/ubuntu` per run, before build. Prove the daemon reads a fresh random marker from that exact path through a temporary read-only bind; do not infer visibility from daemon identity, mount namespace, or `docker info` alone.
- Use only the pinned local Unix Docker socket, a suitable already-cached image, `--network none`, no credentials/agent/session, no pull/build for the probe. Register and clean owned probe resources through the existing lease/ownership engine; abort before expensive build if proof or verified cleanup fails. Preserve scoped recovery and compatibility with the explicit scratch-parent flag where safe.
- Keep checkout modes normal (`0644`/`0755`) even when the test inventory is `0700` and records are private. Do not chmod an existing source worktree or repair unsafe existing records silently.
- Local branch `feat/automatic-dind-scratch` from `dev` at `c2cc757` in a separate clean worktree. Original host-feature worktree and its uncommitted README/manifest edits stay untouched. No push, PR, remote operation, real lifecycle build, or scope expansion to optional integrations.
- TDD mode not established; run focused hermetic unit tests and check-only documentation formatting. Delivery strategy ask-on-risk; initial forecast 300–500 authored lines, with the ~400-line figure advisory for work-unit sizing, not a code limit.

## Tasks
- [x] ADS-1 (delegated writer: ownership, probe and tests): Added test-owned, registered, cleanup-verified exact-path daemon bind probe using cached `ubuntu:24.04` only; generates a non-secret marker and checks exact bytes through a read-only, no-network bind. Unit tests cover success/failure with ownership and cleanup boundaries. Checks: `python3 .maintainer/test/unit/test-resources-test.py` 40 passed (parent reran), `git diff --check`; live Docker N/A for this primitive unit, ADS-2 wiring still required before operational proof. Commit pending.
- [ ] ADS-2 (delegated writer: CLI and docs): Default to generated `/home/ubuntu/starter-test-<UUID>` with no path prompt, run probe before lifecycle build and preserve optional explicit parent safely. Update CLI/Task help, AGENTS.md and maintainer guide for authorization, scope, umask versus inventory permissions, topology/fallback and limits. Focused tests, markdownlint and diff check pass. Commit pending.

## Progress and verification
- Read-only exploration found dockerd in the devcontainer but in a different mount namespace from the client; a prior statement that namespaces matched was incorrect. Exact-byte bind proof is required for the generated directory.
- ADS-1 implementation is confined to `test_resources.py` and its hermetic unit tests; rollback boundary is the probe method and new test cases. It does not yet change the lifecycle CLI or start a build. Reviewed boundary starts at `c2cc757`; per-task assessed tier/outcome and commit evidence pending.

## Next step
Commit ADS-1 and assess its work-unit candidate, then wire ADS-2; synchronize full progress to Engram after each task.
