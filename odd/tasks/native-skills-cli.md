# Native Skills CLI workflow

## Objective
Replace the project-specific `task skill:*` surface with the native Skills CLI while keeping the repository-authored `add-tool` skill available and versioned.

## Problem and decisions
- The native CLI can update a locked external skill from old to new content, but `skills remove --skill '*' -y` deletes locally authored `add-tool` even when listed in `.agents/local-skills.txt`.
- Use native commands for external skills, remove by explicit name only, review Git changes, keep `.agents/skills/add-tool/` tracked, and remove the obsolete local manifest and Task wrappers.
- Preserve existing user edits in README.md, .gitignore and .env.example. User explicitly accepts removal of `*-config.local/` and `.base-backup/` ignore rules; do not restore them. `.claude/` is now ignored. Do not commit unrelated .env.example edits unless work actually changes that file.

## Scope and verification
- Authorized: Skills Task include/wrapper/script/manifest, directly affected guidance and tests, and relevant existing README/.gitignore edits. No remote operations, Docker builds, real skill updates or wholesale cleanup.
- Route: delegated direct writer (4+ files to map and 2+ nontrivial edits). TDD mode for ODD unknown; Bats runner `bats .devcontainer/test/unit/add-tool-inspector.bats` and applicable maintainer suite. Do not infer strict TDD from SDD cache.
- Delivery strategy: feature-branch-chain, selected by the user after the deletion-heavy diff crossed the ~400-line review heuristic. No PR or push is authorized. Keep a coherent replacement of commands, tests, and documentation rather than deleting safeguards to meet a number; the future PR boundary and any size exception remain a delivery decision.

## Tasks
- [x] NS-1: Remove `task skill:*` entry points, wrapper script, and local manifest; retain `add-tool` and move its independent inspector tests to a focused file. Acceptance: Task surface no longer exposes skill commands, add-tool inspector remains covered, native CLI and tracked local skill remain available. Checks: focused Bats, `task --list`, scoped `git diff --check`.
- [x] NS-2: Replace all affected user-facing and maintainer guidance with native CLI commands, explicit-name removal and Git review safeguards; preserve user's README and `.gitignore` changes, reconcile any local-config guidance affected by the accepted ignore removal. Acceptance: no actionable `task skill:*` references remain; README and local docs match the new workflow; `.env.example` user edits remain intact. Checks: documentation/reference search, `task validate:full`, maintainer suite where safe.

## Progress
- 2026-09-27: Created branch `refactor/native-skills-cli` from local dev `e275b66` without losing user edits; no source changes for this feature yet.
- 2026-09-27: NS-1 focused add-tool inspector Bats 5/5 and `task --list` passed; tracked `add-tool` and external lock unchanged. NS-2 README contract Bats 6/6, README Markdown check and `task validate:full` passed after formatting-only normalization. Maintainer suite passed 436 unit and 18 integration, with 16 integration skips. Global `git diff --check` remains blocked by pre-existing trailing whitespace in the user's unrelated `.env.example` edit; scoped check for work-unit paths passed. Docker runtime: N/A, only local skill commands/documentation/test routing changed. Rollback boundary: removed Skills Task/script/manifest, relocated inspector test, affected guidance and README/.gitignore user edits (not `.env.example`).
- Next: commit one coherent command+test+guidance work unit; record identity and native risk/review outcome, keeping `.env.example` outside the commit.
