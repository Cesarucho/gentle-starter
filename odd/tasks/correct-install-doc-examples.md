# Correct executable install documentation examples

## Objective and scope

Fix misleading executable examples only in `.devcontainer/docs/install-volumes.md`
and `.devcontainer/docs/extending.md`. Preserve unrelated dirty edits in
`.devcontainer/devcontainer.json` and `.devcontainer/docs/existing-project.md`.
No remote or Docker operations, source changes, or unrelated documentation edits.

## Route and acceptance checks

- Feature branch `docs/correct-install-doc-examples` created from `dev` at
  `038bd018cb3e293d7438ecac72619a0b19367448` before edits and commits.
- V1: Use a unique valid `BBPP-category-tool` catalog name, match the target
  mapping and runtime log, activate via `task install:enable -- <canonical-name>`,
  and replace the SQLite-to-jq host example with simple host access.
- V2: Activate Redis through the Task helper; illustrate its config seed as
  an additional guarded line within the existing enabled-aware function,
  without claiming the sketch is a complete installer or runtime proof.
- Check both guides with `markdownlint-cli2`, `git diff --check`, and relevant
  static checks for examples and paths. No container/runtime harness: docs-only
  changes and Docker prohibited.
- Deliver each completed unit as a conventional commit with scoped docs and
  this task evidence; keep the full Engram mirror `odd/correct-install-doc-examples/tasks`
  synchronized after each task. Never stage the two unrelated dirty files.

## Tasks and progress

- [x] V1: Correct volume guide examples, verify and commit scoped work unit.
- [ ] V2: Correct Redis guide examples, verify and commit scoped work unit.

## Evidence

V1: Chose `7100-data-postgresql` after checking all 39 catalog basenames;
the path is free. The example uses the same canonical name in the copy,
mapping, enable command, and expected logs. Removed SQLite-to-jq and warned
that dispatch does not initialize state by itself. Focused checks:
`markdownlint-cli2 .devcontainer/docs/install-volumes.md .devcontainer/docs/extending.md`
reported 0 issues (configuration also selected other repository Markdown);
`git diff --check` passed; `test ! -e
.devcontainer/install/available/7100-data-postgresql.sh` passed.
Runtime harness: N/A, docs only and Docker prohibited. V1 rollback boundary:
the volume guide and this task evidence. Commit identity recorded below.

V2 pending. Rollback boundary: extending guide and its task evidence.
