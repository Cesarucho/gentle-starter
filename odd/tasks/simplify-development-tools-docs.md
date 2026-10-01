# Simplify development tools documentation

## Objective and scope

Keep one representative PostgreSQL 16 prompt in the README's Add development
tools body, ending before Manage skills. Move the other scenarios into Extension
examples before the extending guide's diagram; preserve its Redis worked example.
Preserve all unrelated local edits, especially existing-project.md.

## Route and forecast

Route: delegated documentation work due to multi-file scope and preparation;
executed by the assigned agent without further delegation. Passive prose makes
TDD inapplicable. Forecast: fewer than 400 changed lines, local checks only, no
downloads, builds, installs, remote operations, staging, or commits. Commits remain
pending owner approval; no review is performed.

## Tasks

- [x] Inspect local diffs, relevant configuration, and focused baseline checks.
- [x] Simplify the README and add concise guide examples within the allowed scope.
- [x] Run focused checks, verify preservation, and record proof in this task and Engram.

## Checks and baseline proof

- `git diff --check -- README.md .devcontainer/docs/extending.md`: failed;
  README trailing whitespace at lines 375, 430, 556, 557, 560, and 563.
- `markdownlint-cli2 README.md .devcontainer/docs/extending.md`: failed;
  9 README issues (4 MD009 and 5 MD031). Repository configuration expands the
  command to 20 files; no other file reported issues.
- `bats .maintainer/test/unit/guide-links.bats .maintainer/test/unit/readme-contract.bats`:
  7 passed, 1 failed (README repository tree local-state label, line 19).
  The startup callout test passed; no quickstart-heading failure occurred.

## Initial completion proof (before cleanup authorization)

- `git diff --check -- README.md .devcontainer/docs/extending.md`: failed only
  on pre-existing README whitespace at lines 375 and 430; no new whitespace issues.
- `markdownlint-cli2 README.md .devcontainer/docs/extending.md`: failed only
  on pre-existing README MD009 at line 375 (20 files checked; 1 issue).
- Focused Bats: 7 passed, 1 failed, identical to baseline; the tree-label
  assertion remains the only failure. No tests were changed.
- Preservation inspection confirms unchanged user diffs outside the README body,
  unchanged existing-project.md, and an intact Redis example. The index is empty.
- Source edits: 58 added and 54 removed lines relative to the initial worktree;
  this task adds 52 lines, for 164 changed lines total, below the 400-line forecast.
- No new failures. Full green checks remain blocked by unrelated existing
  whitespace and the tree-label mismatch, deliberately left untouched.

Repository locator: `/home/ubuntu/gentle-starter`;
task: `odd/tasks/simplify-development-tools-docs.md`;
Engram topic: `odd/simplify-development-tools-docs/tasks`.

## Authorized final cleanup

The owner extended the plain-prose route to remaining README whitespace, the
repository-tree textual assertion, stale skills-task evidence, and verification
of existing-project.md. No SDD, native review actors, further delegation, skills
behavior changes, installed-skill edits, staging, commits, network, or builds.

- [x] Inspect starting status and diffs against HEAD
  `b27e831ad4fd6f3d3bcc6fb6eb72e09c30ffdb35` on
  `feat/skills-universal-installs`; index empty.
- [x] Preserve existing user edits in README and existing-project.md. Earlier
  prompt simplification and extending examples were already in the starting
  worktree; HEAD is the base, not the ownership boundary.
- [x] Remove two remaining README trailing-whitespace instances; retain the
  user's `* Local environment state` wording and match it in readme-contract.
- [x] Render the user's existing-project state-location table as Markdown rather
  than a Bash code fence; leave its prose, paths, and warning unchanged.
- [x] Correct the stale skills-task next step and distinguish historical checks
  from current documentation proof.

### Latest verification

- `git diff --check`: PASS, no output.
- `markdownlint-cli2 README.md .devcontainer/docs/extending.md .devcontainer/docs/existing-project.md AGENTS.md odd/tasks/skills-catalog-universal-installs.md odd/tasks/simplify-development-tools-docs.md`:
  PASS; `Linting: 22 files`, no issues. Repository globs expand the six paths.
- The same command with `--no-globs`: PASS; `Linting: 6 files`, no issues.
- `bats .maintainer/test/unit/guide-links.bats .maintainer/test/unit/readme-contract.bats`:
  PASS, 8/8 tests.
- Installed markdownlint-cli2 0.23.3 source separates the checked-file count from
  the summary's issue-bearing file count. Historical `0 issues in 0 files`
  alone was insufficient evidence, not proof that zero files were checked.
- No operational or application proof was attempted. Owner review remains
  pending; no content rewrite or semantic guarantee was added for state copying.

## Accepted SSH selection correction

- [x] Replace the guide's claim that the SSH-agent override is already selected
  with optional availability, host prerequisites, and explicit `dockerComposeFile`
  selection independent of installer enable/disable. No configuration changed.
- [x] Cancel only verified `starter-rc` at
  `b4df354edd499dd190cbd437a0c412add5cb7221` using
  `task --taskfile .maintainer/Taskfile.yml distribution:candidate -- --cancel`
  before editing; cancellation requires a clean worktree. Its source was
  `b64b5fe2a4cc89aab4ee2f8720710f9cc596e2d5`, tree
  `7fe26399f6623502d119a5508d901d546bae1782`, and pinned base
  `f11a05661d5773db7a435e562f2f539a3448e161`; `starter` remains unchanged.
- [x] `git diff --check`: PASS, no output.
- [x] `markdownlint-cli2 --no-globs .devcontainer/docs/extending.md odd/tasks/simplify-development-tools-docs.md`:
  PASS, 2 files linted, 0 issues.
- [x] `bats .maintainer/test/unit/guide-links.bats .maintainer/test/unit/readme-contract.bats .maintainer/test/unit/starter-distribution.bats`:
  PASS, 32/32 tests; temporary local Git fixtures only.
- [ ] Owner inspects and authorizes a source commit; edits remain unstaged and
  uncommitted. Only after committing and restoring a clean worktree, regenerate
  with `task --taskfile .maintainer/Taskfile.yml distribution:candidate`.

No candidate was regenerated from the old source. No network, build, Docker,
download, SSH trust change, remote operation, promotion, tag, or review was run.
