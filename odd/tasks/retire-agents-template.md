# Retire the distributed AGENTS template

## Objective and authority

Prepare the next `starter` update without `AGENTS.md.TEMPLATE` and consolidate
the README's security, changelog, and license links into one Markdown section.
Preserve the user's pre-existing README edits. Local work only: no release,
push, or PR. Branch: `dev`; mirror: `odd/retire-agents-template/tasks`.

- Scope: distribution filtering, focused tests, maintainer guidance, and the
  README. Keep the dev template tracked and unchanged; do not change identity
  cleanup or initialization policy or unrelated user edits.
- TDD: no configured strict mode in the existing project ODD record; use Bats
  for focused regression proof.
- Delivery strategy: `ask-on-risk`; forecast roughly 300–500 authored lines,
  depending on fixture updates. The ~400-line per-task figure is advisory only.

## Tasks

- [x] T1 — Exclude the template from starter creation and updates while retaining
  the tracked dev-source template; update regression fixtures and guidance. Route:
  delegated direct writer (multiple non-trivial files and preparatory reading).
  Acceptance: no template in the generated starter tree, source template retained
  across updates, and existing cleanup/init preservation policy unchanged. Checks:
  `bats .maintainer/test/unit/starter-distribution.bats .maintainer/test/unit/project-init.bats .maintainer/test/unit/readme-contract.bats`,
  `git diff --check`, and applicable repository validation.
- [x] T2 — Consolidate README security, changelog, and license links into one
  concise Markdown section, retaining all pre-existing changes. Route:
  delegated direct writer (read/write overlaps T1 and broader documentation).
  Acceptance: all three destinations remain accessible, with no HTML and no
  lost user edits. Checks: Markdown lint and README contract suite.

## Progress and verification

- The pre-existing README edits to the OpenCode command order, server
  instructions, and Skills warning remain intact and are included with the
  user's explicit commit request.
- The dev template is restored unchanged from HEAD. Cleanup/init scripts, their
  tests, and the lint config retain their original template-preservation policy;
  only starter distribution omits the template. README grouping remains.
- Focused Bats command: 40/40 passed (distribution, project initialization,
  README contract). These tests run cleanup and initialization only in temporary
  repositories; neither command ran against the primary worktree.
- `git diff --check`: passed.
- `markdownlint-cli2 README.md AGENTS.md .maintainer/README-distribution.md
  odd/tasks/consumer-starter-distribution.md odd/tasks/retire-agents-template.md`:
  passed (21 files, zero issues) after the user authorized adding the missing
  blank blockquote line before the OpenCode server list in README.md. The README
  contract suite passed 7/7 and `git diff --check` passed. Full focused Bats
  suites passed 40/40 after the fix.
- No release, remote operation, or primary-tree cleanup/init performed.
- Work-unit commit for T1 and T2: `b8b50ff` (`fix(starter): omit AGENTS
  template from distribution`). Local documentation-only evidence follow-up
  records this commit identity; no remote publication was performed.
