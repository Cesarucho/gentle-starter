# Optional skills catalog: universal installs

## Objective

Stop recommending `rfc-specification` in future published starter trees and
install selections from `task skills:suggest` into the shared `.agents/skills/`
location.

## Problem and rationale

The optional-skills selector currently passes `--agent pi`, which places skills
under `.pi/skills/`. The project-wide location for universal Skills CLI installs
is `.agents/skills/`. `rfc-specification` should no longer appear in the
published recommendation catalog, without removing any already installed local
copy.

## Authorized scope

- Remove the `rfc-specification` recommendation from `skills-lock.json` only.
- Change the selector and direct-install documentation from `pi` to `universal`.
- Align test expectations and repository guidance with the universal target.
- Do not remove installed skills or alter catalog schema/generation behavior.

## Constraints

- `skills-lock.json` remains the release source for the generated published
  catalog; do not hand-maintain `.devcontainer/skills/recommended.json` on dev.
- Preserve `--copy` behavior.
- Installed Skills CLI 1.7.0 supports `--agent universal` and maps it to
  `.agents/skills/`.
- TDD mode: unknown; run the focused existing tests and static checks.

## Tasks

- [x] T1 — Update the optional-skill recommendation lock and selector to use
  the universal agent target. Route: delegated; trigger: two non-trivial files
  plus write preparation.
- [x] T2 — Align focused selector tests and user/developer documentation with
  the universal target. Route: delegated; trigger: multiple non-trivial files.
- [x] T3 — Run focused tests and static checks; record observed results. Route:
  delegated verification action.

## Acceptance criteria

- Future published starter catalogs omit `rfc-specification`.
- `task skills:suggest` invokes Skills CLI with `--agent universal` while
  retaining `--copy`.
- Focused tests expect the universal agent target.
- Direct install and repository guidance point to `.agents/skills/` via
  `--agent universal`.
- No installed skill directory is removed by this change.

## Progress and verification

Completed on `feat/skills-universal-installs` before committing:

- `bats .devcontainer/test/unit/skills-suggest.bats` — PASS: 8/8 tests.
- `bats .maintainer/test/unit/starter-distribution.bats` — PASS: 24/24 tests.
- `shfmt -d .taskfiles/scripts/skills-suggest.sh` — PASS: no output.
- `markdownlint-cli2 .devcontainer/docs/optional-skills.md AGENTS.md` — PASS:
  0 issues in 0 files.
- `git diff --check` — PASS: no output.

The selector now preserves `--copy` while using `--agent universal`, which
installs selected external skills under `.agents/skills/`. The
`rfc-specification` entry was removed only from `skills-lock.json`; the existing
local `.agents/skills/rfc-specification/` directory remains untouched.

## Next step

Delegate the bounded multi-file implementation and run focused verification.
