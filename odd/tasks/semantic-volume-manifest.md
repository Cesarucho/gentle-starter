# Semantic volume manifest validation

Source implementation, tests, and documentation are complete. The user accepted
the operational limits below and authorized one coherent commit with
`delivery_strategy: exception-ok` and human-approved `size:exception`; no chain.
No further feature scope is pending. Native review was declined, not passed.

## Authority and delivery

- Project: `gentle-starter`; mirror #1686: `odd/semantic-volume-manifest/tasks`.
- Repository locator: `odd/tasks/semantic-volume-manifest.md`.
- Branch: `feat/container-lifecycle-semantics`; baseline:
  `b575a36c043361e8489a60eb9e3d7704d03567d0`.
- Delivery identity: the commit containing this document. Its exact hash and
  final staged counts are recorded separately in the Engram commit receipt.
- Scope: schema producer/validator, five production consumers, coupled fixtures,
  tests, and documentation together. No installer, provider, version-policy,
  dependency, activation, or Docker layer changes.
- The existing 14-file source/tests/docs diff is 540 additions and 139 deletions;
  this tracking document is the fifteenth file. The coherent schema transition
  exceeds the advisory 400-line budget; splitting by file type would ship
  incompatible halves. The user explicitly approved the size exception.
- Baseline lifecycle work and the user's root README deletion remain untouched.
  Closure edits only this tracking document; no source behavior edits, push, PR,
  network, installation, daemon operation, or live state access are authorized.

## Implemented contract

| Schema 3 field | Contract |
| --- | --- |
| `schema` | Integer `3`; booleans, legacy, and unknown schemas rejected. |
| `service` | Nonempty, NUL-free selected service. |
| `files` | Ordered, unique, canonical repository-relative Compose paths. |
| `project_name_fingerprint` | SHA-256 of the host-authoritative resolved project name. |
| `volumes` | Canonical bind records sorted by unique canonical target. |
| `id` | Digest of exactly schema, service, files, project fingerprint, volumes. |
| `snapshot_digest` | Separate digest of the complete stored object except this field. |

Records contain exactly `type: bind`, `source`, `source_fingerprint`, `target`,
`managed`, boolean `read_only`, and `bind: {create_host_path: false}`. Managed
sources are safe `.env.d`-relative paths; external sources are stored as `external`.
Host paths are normalized lexically before hashing, without resolving external
symlinks or persisting external paths. Unsafe paths, malformed types/hashes,
unknown fields, duplicate targets, and tampering fail closed.

Only omitted `read_only` defaults to false. Resolved `create_host_path` must be
explicitly false; omitted, true, and non-boolean values fail closed, as do
propagation, SELinux, and consistency options. Non-bind volumes remain outside
this bind-only projection. Integrity is not signing or full container attestation.

Raw selection/file/default-env hashes, including absence, are ephemeral host
concurrency tokens, never persisted inputs. Selection parses and hashes the same
bytes. Preparation resolves Compose once, checks existing-container identity before
directory preparation, and rechecks tokens before preparation and immediately
before atomic publication. A concurrent edit preserves the previous snapshot;
safely created empty directories need not be rolled back after a late failure.

Runtime validates shape, both digests, and `GENTLE_VOLUME_MANIFEST_ID` without
reading live env/selection, requiring host paths, or invoking Compose. Repair uses
the same checked response. Setup, owner activation, passive mounts, and enabled
writable-key SSH override gates remain intact. Doctor uses its selected mode:
explicit container checks applied identity; explicit host checks the stored snapshot.
Only auto mode selects between these checks using detected context. Host doctor and
`install:volumes` report only the last host-prepared snapshot, not current desired
configuration or proof of applied mounts.

Legacy schemas require intentional host `task container:recreate`; loading never
migrates them. Root `.env` application values apply on recreate, not restart.
Task's five managed keys remain `APP_NAME`, `APP_PORT`, `OPENCODE_PORT`, `SSH_PORT`,
and `HOST_UID`.

## Verification and recovery evidence

- Final isolated recovery: **72 PASS**, zero failures/skips/exclusions: full Python
  suite 39 (14.606 s), host-bind preparation 12, doctor/repair 21.
- `task quality:full` and `git diff --check`: PASS after final source edits and
  again after tracking-only updates. Quality includes ShellCheck, check-only shfmt,
  and Markdown lint (17 files, zero issues).
- Parent semantic tests: 12 PASS. Independent verifier repeated Python 39,
  host-bind 12, and diff checks: PASS, zero skips, candidate unchanged.
- Tests cover semantic identity stability/change, canonical normalization, strict
  rejection, tampering, applied identity, concurrency before mutation/publication,
  host-independent runtime, checked dispatch, activation, SSH gates, and legacy
  rejection without mutation. Real Compose resolves temporary fixtures only;
  container, Dev Container CLI build/up, installation, and privilege calls are stubbed.
- Recovery commands: `python3 -B .devcontainer/test/unit/compose-manifest-test.py`,
  `bats .devcontainer/test/unit/host-bind-preparation.bats`, and
  `PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/doctor.bats .devcontainer/test/unit/volume-repair.bats`.
  Batches used `env -i`, reviewed system PATH, isolated HOME/DOCKER_CONFIG/TMPDIR
  below `/tmp/opencode`, and a nonexistent Docker socket. GREEN had a 300000 ms
  supervisor and 120 s per command with 10 s grace; no timeout occurred.
- Voluntary tests-first RED preceded implementation and recovery. Initial quality
  failure SC2120/SC2119 was fixed by explicitly passing `runtime`, without
  suppressions. Earlier 24/25 functional results are historical, not final proof.
- The creation-flag defect was proven preexisting in baseline `b575a36`: Compose
  5.5.1 preserves explicit false but can omit true; `get(..., False)` was unsafe.
  Requiring explicit false fixes it without extra resolution or parser workarounds.
  Real configuration was supported on Compose 5.5.1; older versions are untested.
- Closure requires fresh `git diff --check` and `task quality:full`, each under a
  120000 ms supervisor, before committing. Any failure stops delivery.

## Native review status

Blocked review `review-9e38f802d731f2b7` was abandoned with explicit user consent;
there were no results or findings. The abandon record status was not approval.
For the corrected candidate, the user selected “Omitir esta vez”; exact status
`declined_this_candidate` was confirmed for target
`7f474b866160d0838c611d6e7b6cba33d6f6f682c7cd31521875ad94a4af55e2`.
There is no native review receipt or PASS. Global RDD remains enabled; this
tracking-only closure does not reopen the declined candidate or prompt again.
Review-system diagnosis is independent future work, not remaining feature scope.

## Deferred operational limits and rollback

Actual container migration, build, live runtime integration, and `validate:full`
against the legacy manifest were **not run and are not PASS**. They remain
separately authorized operational work, not source-completion blockers under the
user's explicit acceptance. No actual `.env`, `.devcontainer/.env`, `.env.d`, or
manifest was accessed during closure. Historical env-hash mismatch does not prove
a source bug; those bytes remain unknown and untouched.

Rollback removes this schema/consumer/tests/docs unit while preserving baseline
lifecycle work. After a separately authorized migration, source rollback would
also require intentional host recreation for the earlier schema.

## Skill resolution

Implementation/recovery used add-tool, design-patterns, clean-code,
work-unit-commits, cognitive-doc-design, and markdown-documentation as recorded
in the preceding work. Closure loaded the exact requested work-unit-commits,
cognitive-doc-design, and markdown-documentation files. Code, tests, and docs
remain one behavioral work unit. No child agents or new native review were used
for closure.
