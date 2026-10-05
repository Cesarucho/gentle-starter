# Finish devcontainer documentation review

## Scope

Correct only the identified findings in `configs.md`, `install-tree.md`,
`extending.md`, and the docs index. Preserve unrelated worktree changes and
leave all edits unstaged and uncommitted. Do not run remote or Docker operations.

## Progress

- [x] Clarify config seeding on subsequent setup and conditional legacy links.
- [x] Replace stale optional-tool inventory with a durable description.
- [x] Correct Bats placement and link updater policy from the test section.
- [x] Index the optional-skills guide.
- [x] Verify source claims, markdownlint, diff hygiene, and protected files.

## Review evidence

The existing-project exit-1 row says reserved paths exist and routes to manual
integration; it does not certify a clean worktree. No edit is authorized there.

Config unit: checked `setup.sh` lines 63-101 and 141-151: setup copies each
missing target from the active tool's source on every run; existing targets
remain unchanged. Legacy symlinks are possible, not universal.

Install-tree unit: inspected `03-enabled/` (Playwright, GGA, SSH client,
PulseAudio utilities, Glow) and `02-core-tools/` (Bats present). Removed the
fragile optional-tool enumeration; `task install:list` is the inspection path.

Extending unit: checked Bats alias in `02-core-tools/` and existing policy link
target `tool-versions.conf`; added a short navigation link near test coverage.

Index unit: verified `optional-skills.md` exists and describes opt-in
suggestions and installation; linked it in the docs index.

Final verification: `markdownlint-cli2 '.devcontainer/docs/**/*.md'` linted
20 files with 0 issues; `git diff --check` passed. Reviewed scoped diff and
status: only the four requested guides and this task file were changed by
this work; the existing unstaged changes in `devcontainer.json`, `AGENTS.md`,
and `existing-project.md` remain outside scope. No runtime/container proof was
attempted. The linked policy file exists, but its header still mentions the
old `deps:update` spelling; that pre-existing policy inconsistency is outside
this docs-only scope.
