# Root locale build arguments

## Objective and authority

Make root `.env` the only editable source for `LOCALE` and `TZ`; synchronize only
those keys into generated `.devcontainer/.env` before build/up, and pass them as
Compose build arguments. Baseline: `dev` at `759dece7418816471d86bb7d9976dde559fb52fe`;
feature branch `feat/locale-env-build-args` created with the user's README edits
still uncommitted. Mirror topic: `odd/locale-env-build-args/tasks`.

## Constraints and route

- Preserve all unrelated root/generated environment entries and credentials.
- Preserve the host guard and existing identity generation. Reject malformed
  locale settings before mutating either environment file.
- Preserve every existing user README edit except the locale paragraph; do not
  stage unrelated README hunks. No remote operations or Docker builds.
- Work locally without delegation. TDD mode/source: unknown; ordinary focused
  checks, no strict-TDD claim. Delivery: one coherent work-unit commit for code,
  tests, and versioned example; README correction may remain uncommitted.
- Advisory review budget: ~400 authored lines, without code-golfing tests.

## Acceptance checklist

- [x] L1: Parse only root LOCALE/TZ, with documented syntax, defaults, and
  duplicate/invalid handling; no sourcing arbitrary root environment content.
- [x] L2: Synchronize exactly those two generated keys before build/up; prevent
  exported shell values from overriding root settings during Compose interpolation.
- [x] L3: Compose forwards both values to image build; retain build-time locale
  validation and guard against unsafe timezone/locale input without partial writes.
- [x] L4: Focused fixture tests cover precedence, failure atomicity, defaults,
  and task order without touching the live container or root `.env`.
- [x] L5: `.env.example` and README locale instructions match actual behavior,
  preserving unrelated user README edits and their staging boundary.
- [x] L6: Run requested Bats, markdownlint, diff check and syntax checks; record
  exact outcomes, skips, rollback boundary, and work-unit commit identity.

## Evidence and progress

- Baseline inspected: only `README.md` dirty; remote metadata inspected without
  contacting remotes. Existing Task regenerates identity in both files and sources
  generated `.env`; Compose has APP_NAME only; Dockerfile already has locale defaults.
- Implemented narrow Python parser and generated-only locale synchronization;
  generated values overwrite inherited exported values when Task sources the file.
  Compose forwards the two build arguments. The parser validates the host's
  installed IANA zone; installer still checks locale-gen availability at build
  time; real builds and container tasks were not run.
- First focused Bats run: 33/34 pass; quote/comment parser rejected a valid
  inline comment. Fixed suffix handling; final rerun after precedence assertion:
  34/34 passed. `markdownlint-cli2 README.md .env.example` failed:
  dotenv comment lines are interpreted as Markdown headings; fallback
  `markdownlint-cli2 README.md` passed, 0 issues. `git diff --check` and
  Python AST syntax check passed. No real Docker proof; skipped by authorization.
  Runtime harness: isolated Task fixture exercised actual regeneration; no
  daemon-dependent harness was authorized.
- Rollback boundary: locale parser, Task locale synchronization, Compose build
  arguments, three focused test changes, `.env.example` locale guidance and this
  task document. The README locale paragraph is a separate uncommitted change;
  user's other README hunks remain untouched and unstaged.
- Work-unit commit: `801b823fafc904756d68cd44d902e910f0d9e9d2`,
  `feat(container): forward root locale settings to image builds`. No README
  content was staged or committed. Review candidate is this commit against
  `759dece`; delivery remains one local work unit, no PR or remote operation.
