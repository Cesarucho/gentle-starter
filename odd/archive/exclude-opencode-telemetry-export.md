# Exclude OpenCode telemetry from configuration export

## Objective
Exclude OpenCode telemetry runtime files from `task config:diff` and `task config:export` without changing unrelated OpenCode configuration or runtime seeding.

## Scope and constraints
- Branch `feat/exclude-opencode-telemetry` from local `dev` at `08ffdb4`; the original `feat/shared-host-prerequisites` worktree and its uncommitted README and manifest changes stay untouched.
- Reproduce the user's manifest exclusion in this separate worktree: remove root `.gentle-ai-telemetry-runtime.json` from managed entries and exclude it and `plugins/telemetry-runtime.ts`.
- Preserve other plugins, seed content, private runtime files, credentials, and independent seed-on-first-run behavior. No real-HOME export, network, Docker lifecycle, push, or PR.
- Technical artifacts English. TDD mode not established; run ordinary fixture-based Bats and documentation checks.
- Delivery strategy: ask-on-risk; estimated authored change under 200 lines. Review after the coherent work-unit commit according to the user-owned RDD switch.

## Tasks
- [x] OTE-1 (delegated writer; manifest, tests and docs): Applied the user's intended export-only exclusion, aligned fixture manifest and regression tests for `config:diff`/`config:export` including symlink and unrelated plugin cases, and updated `.devcontainer/docs/configs.md`. Acceptance: telemetry runtime and plugin absent from export/diff; unrelated managed plugin still included; seeding unchanged. Checks: focused config-export Bats 32/32 passed (parent reran), `git diff --check`, markdownlint 0 issues; real-HOME export N/A because fixture tests exercise the runtime boundary without touching personal configuration. Work-unit commit `7d73d73`.

## Progress and verification
- Read-only mapping confirms the user's current manifest change is effective: exclusions override managed patterns, and the root classifier exception applies only while explicitly managed. Existing tests/docs still assert prior inclusion policy.
- Writer implemented and verified manifest, fixture manifest, Bats and docs. Exporter source and seeding unchanged. Work-unit rollback boundary: these four paths, with original worktree user edits still untouched.
- Native assessment on `08ffdb4..7d73d73`: medium risk, `review_due=false` (`under_budget`, 157 changed lines). Pending slice retains `08ffdb4` as reviewed boundary; no review consent or receipt was inferred.

## Next step
Ready for local inspection. No push or PR; any later medium work unit should be assessed against the pending slice boundary.
