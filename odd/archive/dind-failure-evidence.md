# DinD failure evidence retention

## Objective

Preserve inspectable evidence from failed or interrupted DinD test runs without leaving run-owned containers running or preventing subsequent tests.

## Problem and constraints

- Successful tests retain their existing automatic verified cleanup.
- Failed/interrupted tests retain private inventory, scratch, logs, and identified owned resources. Record running owned containers and stop them safely without removing them; never act on uncertain ownership.
- Deletion and forgetting evidence require explicit operator request and existing ownership verification; no global prune, remote operations, or real Docker test without separate forecast and authorization.
- Scope: scripts/tests in `.maintainer/test/lifecycle/`, `AGENTS.md`, and repository documentation (including this task file). User additionally authorized updates to the four conflicting expectations in `.maintainer/test/unit/`; no global configuration.
- Branch `feat/dind-failure-evidence` from clean local `dev` at `c59e0e2`; original linked worktree untouched. TDD mode not established; use focused hermetic tests. Delivery strategy: ask-on-risk. Forecast: roughly 300–500 authored lines; ~400 per work unit is advisory only.

## Tasks

- [x] DFE-1 (delegated): Failure/interruption retention and verified owned-container stop implemented; successful cleanup preserved. Hermetic regression tests pass (7 cases); existing resource (41) and lifecycle (20) unit tests pass after authorized adjustment of four conflicting expectations.
- [x] DFE-2 (delegated): Recovery semantics and operator/agent documentation updated, including privacy and hard-kill limits. Preview/apply/forget checks included in hermetic regression suite; markdownlint and diff checks pass.

## Progress and verification

- Initial map: unconditional lifecycle cleanup erased scratch/task.log on failures; the durable inventory recorded only bounded outcomes. Four conflicting assertions in existing Python unit tests were subsequently authorized for adjustment; new cases belong under `.maintainer/test/lifecycle/`.
- Local real Docker/build execution deferred pending separate forecast and authorization.
- One cohesive work unit includes both tasks because recovery safety and retention share the same ownership invariant. Rollback boundary: the lifecycle producer/ownership changes, focused tests, AGENTS.md and maintainer guide. Independent read-only audit found no concrete high-severity defect; seven hermetic regression cases passed independently. No real Docker/build run.

## Next step

Record work-unit commit and native risk outcome. A real Docker lifecycle proof requires a separate cost forecast and explicit authorization.
