# Add GGA installer

## Objective

Make Gentleman Guardian Angel (GGA) available as an optional, image-owned devcontainer CLI without configuring project hooks, project configuration, or persistent cache automatically.

## Problem and rationale

GGA is a pure Bash CLI distributed as source files, rather than as verified release binaries. The install tree needs a policy-managed, reproducible source installation that follows the catalog activation and supply-chain controls.

## Scope and constraints

- Add an optional catalog installer named `3070-ai-gga.sh`.
- Pin a stable release version, resolved tag commit, and source archive SHA-256 in the centralized policy.
- Extend the transactional version updater as the sole lock mutation authority.
- Do not add a volume, run `gga init`, install a Git hook, or add an OpenCode dependency.
- Preserve unrelated local changes already present in the worktree.

## Delivery and checks

- Route: delegated direct — multiple non-trivial installer, updater, test, and documentation files; add-tool supply-chain inspection is required.
- TDD: disabled/unknown; use focused regression checks and report their observed result.
- Delivery strategy: ask-on-risk. Forecast: one work unit, likely below 400 authored changed lines.

## Tasks

- [x] GGA-1 Add policy-managed GGA source installer, launcher, updater resolution, focused tests, and activation/documentation updates.
  - Acceptance: `gga` is optional and image-owned; the source archive is commit-and-digest pinned; no project state is created at build time.
  - Checks: focused Bats suites for updater/installer/activation, `task validate` when practical.
  - Route evidence: delegated writer; touches more than two non-trivial files and requires preparation reads.

## Progress and verification evidence

- Implemented optional `3070-ai-gga.sh`; installed source is pinned to GGA 2.10.1 commit `1124c3672f082c56b033c4e23a30e95d0e8cd593` and SHA-256 `fb681f48706be5ee8f7d1efd558fdfacbc7757aaf4ca9d8fd05fce4c44d7d004`.
- `bats .devcontainer/test/unit/gga.bats .devcontainer/test/unit/install-dependencies.bats .devcontainer/test/unit/tools-update.bats`: passed (67 tests; parent spot check).
- `task install:doctor`, `task install:versions:validate`, `task install:list`, installer policy diagnostic, and `git diff --check`: passed.
- `task validate`: blocked by 13 pre-existing `README.md` markdownlint failures; no GGA-file failure observed.
- Commit evidence: pending.

## Next step

Stage only GGA work-unit paths, commit it, then assess the committed slice for receipt-driven review.
