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

## Authorized isolated lifecycle extension

- [x] L7: Candidate-only root `.env` injects `en_GB.UTF-8` and `Europe/Madrid`;
  generated `.devcontainer/.env`, runtime `LOCALE`/`LANG`/`LC_ALL`/`TZ`,
  generated locale availability, and `/etc/localtime` are checked after start
  and recreation. The default fixture is replaced only in this isolated test;
  production defaults are unchanged. No primary `.env` or container is touched.
- [x] L8: Focused mocked lifecycle Bats and diff check passed (2/2 tests);
  the separate Python discovery command found zero tests because the filename
  does not match Python's importable module naming convention.
- [x] L9: Run the explicitly authorized isolated lifecycle command after disk
  and daemon preflight; record stage, elapsed time, run ID, cleanup and cache
  delta. No retries were needed.
- [x] L10: Commit the bounded harness, regression test, and evidence without
  staging the user-owned README; mirror this entire document in Engram.

Forecast before launch: one full image build, start and recreate may take tens
of minutes and download tools; shared cache (42.87 GB before launch) remains.
Docker server 29.8.1-1 and cached ubuntu:24.04 confirmed; `/tmp/opencode` had
16 GB free and root filesystem 1.4 TB free. The scratch exact-byte probe must
pass before candidate creation; no global prune or primary container action.
Actual command: `time task --taskfile .maintainer/Taskfile.yml
test:starter:lifecycle` passed in 2m26.853s, including exact-byte scratch bind
probe, candidate build, start, connection, recreation, managed-state and
primary-source preservation. The locale assertion passed both after start and
after recreation, checking candidate root and generated values, four runtime
environment keys, `locale -a`, and `/etc/localtime` link. Run ID:
`06586dcd-b8a1-4c0c-b016-aaf66ef8781d`; inventory preview reports
`test=passed stage=verify cleanup=removed`. Owned containers, network, images,
and scratch were removed and verified. Shared cache remains, increasing from
42.87 GB to 46.51 GB (+3.64 GB reported). No primary container action.
Post-run focused Bats passed 2/2; `git diff --check` passed. Rollback boundary:
the lifecycle harness, its mocked regression tests, and this ODD evidence only.
