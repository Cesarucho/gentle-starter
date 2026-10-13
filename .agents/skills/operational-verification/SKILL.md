---
name: operational-verification
description: "Trigger: operational checks, lifecycle tests, environment verification. Run scoped operational proofs with explicit authorization and cleanup evidence."
license: MIT
metadata:
  author: GentleStarter contributors
  version: "1.0"
---

## Activation Contract

Use for operational/environment/lifecycle proof, not unit TDD or review.

## Hard Rules

- Recipes/readiness never authorize execution.
- Scope authority by destination/effect: primary checkout, isolated fixtures
  and implicit outputs; one grant never substitutes for another.
- Preserve unrelated state; infer no privilege, remote access or cleanup scope.
- Stop at first failed guard; never repair authority, broaden permissions,
  toggle review modes or switch scenarios automatically.

## Decision Gates

| Need | Action |
| --- | --- |
| Readiness | Require query authorization for existing read-only preflight. |
| Runtime | Authorize operation, inputs, destination and resource scope. |
| Failure/interrupt | Preserve evidence; preview ownership before authorized recovery. |

## Execution Steps

1. Select the smallest proof; inspect checkout, environment, toolchain, inputs
   and hooks. Label HOST/CONTAINER paths and shared state.
2. Read local contract; use existing Task entries. State prerequisites
   and exclusions; invent no framework or approval.
3. Require operation authorization; forecast downloads, duration, disk and cache.
   Set external soft and longer hard timeouts allowing cleanup.
4. Run authorized preflight only; distinguish readiness from exact-byte probes,
   builds and ownership proof. Preserve mandatory guards.
5. Execute one bounded authorized proof. Report first failure/timeout stage;
   prove intended behavior/stage, not merely an exit. Inspect registered state
   before separately authorized continuation.
6. Verify cleanup ownership/identity; distinguish removal, retention
   and unverifiable cleanup. Never globally prune.

## Output Contract

Return proof boundary, exact commands/numeric exits, observed elapsed time,
first failure and execution state (not-started/failed/interrupted/verified).
Report cleanup identity, verified removal, intentional retention, unknowns and
confidence separately. Mark unavailable metadata unknown. Separate original/cleanup
failures; redact private logs. Never report incomplete proof as PASS or infer
native RDD approval from execution.

## References

- [Starter harness](references/starter-harness.md)
