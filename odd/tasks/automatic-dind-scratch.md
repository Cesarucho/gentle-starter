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
- [x] ADS-1 (delegated writer: ownership, probe and tests): Added exact-path bind probe in `cb1bae6` with 40 passing unit tests. An independent verifier caught missing unique-name verification before container removal; follow-up `ee73483` verifies exact container ID/name and fails closed on mismatches, with 41 unit tests passing (parent reran). ADS-2 must still wire failure cleanup before any build. Runtime harness N/A until ADS-2 wiring; rollback boundary is the probe method and unit cases.
- [x] ADS-2 (delegated writer: CLI and docs): Defaults to generated `/home/ubuntu/starter-test-<UUID>` with no path prompt, probes before candidate creation/build, preserves optional explicit parent with the same proof, and runs scoped cleanup before outcome persistence on probe failure. Updated CLI/Task help, AGENTS.md and maintainer guide for authorization, scope, clone umask versus inventory permissions, topology/fallback and limits. Checks: resource unit tests 41 passed, lifecycle unit tests 19 passed (parent reran), markdownlint 0 issues, `git diff --check`; live runtime proof pending explicit operational authorization. Commit pending.

## Progress and verification
- Read-only exploration found dockerd in the devcontainer but in a different mount namespace from the client; a prior statement that namespaces matched was incorrect. Exact-byte bind proof is required for the generated directory.
- ADS-1 first commit `cb1bae6` assessed high risk; user declined native review for this candidate only. Separate verifier returned partial for missing probe-name identity. Follow-up `ee73483` assessed high risk, received separate explicit user consent, native four-lens review approved and acknowledged with authority burned. Failure cleanup must be wired by ADS-2 before any build. Reviewed boundary for the acknowledged follow-up is `ee73483`; first unit remains declined.
- ADS-2 source changes are confined to lifecycle orchestration, candidate clone umask, focused tests, Task help and operator/agent documentation. Rollback boundary is those six files. No Docker container or build executed for this work unit; the probe is not an implicit test authorization.

## Next step
Commit ADS-2, assess candidate and preserve evidence. If live proof is desired, forecast and seek separate operational authorization.
