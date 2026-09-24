# Clean ODD artifacts on initialization

## Objective

Remove the starter's root `odd/` task artifacts from both `task project:init` and `task clean`, without weakening cleanup safety or transactional rollback.

## Scope and constraints

- Treat `odd/` as starter identity material.
- Reject unsafe `odd` path types before recursive deletion.
- Restore `odd/` if `project:init` fails after cleanup.
- Update cleanup help and downstream-tree documentation.
- Preserve unrelated repository content and use focused Bats coverage.

## Delivery and checks

- Route: delegated direct — shared cleanup logic, transactional initialization, tests, and documentation require a bounded writer.
- TDD: disabled/unknown; use focused behavioral Bats coverage.
- Delivery strategy: ask-on-risk; forecast below 400 authored changed lines.

## Tasks

- [x] ODD-CLEAN-1 Remove root `odd/` during clean/init with validation, rollback, documentation, and regression tests.
  - Acceptance: normal clean/init delete `odd/`; dry-run preserves it; rollback restores it; unsafe types refuse without deletion.
  - Checks: focused `project-init` and cleanup Bats suites, `task validate` when practical.

## Progress and verification evidence

- `odd/` is now an identity-cleanup item, validated as a real directory, and included in project-init rollback paths.
- `bats .devcontainer/test/unit/project-init.bats`: passed (22 tests; parent spot check).
- `task validate`: passed.
- `git diff --check`: passed.
- Runtime harness: N/A; this is a repository cleanup transaction covered by isolated Git fixtures.
- Rollback boundary: reverting the cleanup scripts, Task wiring, documentation, and focused fixture tests restores the former preservation behavior.
- Commit evidence: `e9180a4` (`feat(clean): remove starter ODD artifacts`).
- Receipt-driven review: assessed high risk and explicitly declined for this candidate; no review receipt was created.

## Next step

No further implementation is pending.
