# General selective tool updates

## Objective and rationale

Add `task tools:update -- --only name1,name2` to update selected managed tools
without unrelated provider discovery, downloads, authentication, or publication.
Unfiltered updates keep existing behavior. Existing selective modes stay compatible.

## Authorized scope and constraints

Updater implementation, deterministic tests, task descriptions, and current extension
documentation only. Preserve existing uncommitted tool policy updates byte-for-byte.
No live updater runs, installations, activation, builds, lifecycle, commits, or push.
Use canonical lowercase policy identities; reject malformed, unknown, duplicate,
or combined-mode selections before side effects. Playwright includes library and CLI.
Keep complete architecture integrity sets, version constraints, atomic publication,
and existing normal baseline advancement. Do not expand activation dependencies.

## Route and delivery

One coherent work unit, delegated direct. Trigger: multi-file updater behavior change
and implementation preparation. Forecast: 400–650 authored changed lines including
tests; advisory estimate only, do not remove proof or artificially split for size.
Delivery strategy: ask-on-risk. No commit authorized; if later committing beyond
the delivery budget, resolve delivery strategy then. RDD was last observed clone-off;
read current status at verification. Parent owns closure and archival.

## Checklist and acceptance

- [x] T1: Implement generic selection and provider-scoped discovery with deterministic
  RED then GREEN, preserving full-update and legacy mode behavior.
- [x] T2: Document names, grouped ownership, invocation and rejection semantics.
- [x] T3: Run focused regression/quality checks, independently verify as applicable,
  preserve prior policy edits, and reconcile/ archive this record.

## Verification

Default test-first policy: runnable deterministic Bats selection tests must show RED
before implementation and GREEN afterward. Run updater, policy, and lock-retirement
unit suites; shell syntax, ShellCheck, docs quality, git diff checks. Mock all provider
requests. No application test or live download/install proof claimed.

## Progress and recovery

Exploration complete; implementation pending. Initial feature boundary a8ddd7e.
Prior local policy update is unrelated work to preserve. Locator:
`odd/archive/selective-tool-updates.md`; mirror topic `odd/selective-tool-updates/tasks`.

### Implementation and observed evidence

T1/T2 implementation is ready for parent review, not feature closure. Strict
`--only LIST` parsing precedes side effects. Discovery retains existing provider
order and npm behavior. Selected publication reuses the atomic byte-scope guard,
complete integrity sets, and original-intent baseline advancement. Playwright owns
both components; other grouped intents remain independent. Registered initial
locks can be added only for selected tools. Offline validation checks the full
inventory without provider prerequisites or authentication.

- RED: `bats --filter 'only|select' .devcontainer/test/unit/tools-update.bats`
  observed seven new selection failures and eight existing passes before behavior edits.
- GREEN: the same command passed all 15 tests after implementation; expanded
  selection coverage subsequently passed all 18 tests after formatting.
- Final regression: `bats .devcontainer/test/unit/tools-update.bats .devcontainer/test/unit/tool-policy.bats .devcontainer/test/unit/tools-retire-locks.bats`
  passed all 92 tests. The actual retirement suite is `tools-retire-locks.bats`.
  Every canonical identity was tested against complete full-update outputs and
  an independent allowed-provider call list. Additional cases cover strict parsing,
  local/npm prerequisites, GitHub-only authentication, Playwright pairing, selected
  bootstrap, baseline normalization/pins/partials, unrelated bytes/mode, idempotency,
  later-provider failure, publication failure, and full/legacy regressions.
- `bash -n .taskfiles/scripts/tools-update.sh` passed.
- `shellcheck .taskfiles/scripts/tools-update.sh` initially reported parser loop
  variable and conditional warnings; corrected, then passed with no findings.
- `shfmt -w .taskfiles/scripts/tools-update.sh` normalized only the allowed source.
- `task validate` passed container diagnosis and strict quality; diagnosis reported
  zero errors and 11 missing optional skill warnings. No build/lifecycle ran.
- `shfmt -d .taskfiles/scripts/tools-update.sh` passed check-only formatting.
- `markdownlint-cli2 --config .markdownlint-cli2.yaml odd/tasks/selective-tool-updates.md`
  passed all 23 configured/explicit Markdown files with zero issues.
- `git diff --check` passed.
- Preserved policy SHA-256 before and after:
  `b4c4cb7a3e92ab7938ffadebe15ae07a0f4f5d51b2a6453b3c117b4f092df278`.
- Source/tests/task-help/docs tracked diff: 554 additions, 74 deletions (628 lines),
  excluding this pre-existing untracked record and unrelated policy edits. This is
  an advisory review-size report, not authorization to commit or split artificially.

T3 remains open for parent-owned independent verification, current RDD disposition,
closure reconciliation, and archival. No native review, live network update,
live installation, build, lifecycle, staging, commit, remote action, or archive performed.

### Legacy Pi coverage follow-up

Parent-reported independent verification passed the original 92 tests and found
no correctness blocker, but identified missing execution coverage for
`--update-pi exact-version`. Added two deterministic compatibility regressions
and an exact public-registry Pi metadata fixture; updater source is unchanged.
No meaningful RED applies: this is coverage of established behavior, not a
behavior change. The success test proves only the Pi lock and bare intent change,
unrelated bytes and mode survive, repeat execution is idempotent, and the sole
provider call is exact Pi metadata, even with GitHub authentication opted in.
The parsing test rejects missing/extra arguments, partials, tags, pin notation,
prereleases, whitespace, and unsafe values before provider/auth/temp side effects.

- `bats --filter 'legacy update-pi' .devcontainer/test/unit/tools-update.bats`:
  passed both tests.
- `bats .devcontainer/test/unit/tools-update.bats .devcontainer/test/unit/tool-policy.bats .devcontainer/test/unit/tools-retire-locks.bats`:
  passed all 94 tests.
- `git diff --check`: passed.
- Policy SHA-256 remains
  `b4c4cb7a3e92ab7938ffadebe15ae07a0f4f5d51b2a6453b3c117b4f092df278`.

T3 closure and archival remain parent-owned; no source change, live update,
native review, staging, or commit was performed in this follow-up.

## Parent closure

Authorized behavior, documentation, and checks are complete. Parent reconciled
writer evidence with independent 92-test/ShellCheck verification and the independent
two-test legacy Pi follow-up. The expanded 94-test run is writer-observed evidence.
Parent syntax and diff checks passed; no correctness blocker remains. Existing policy
edits retain their required SHA-256. Live providers, installations, and application
proof were not run and are outside this implementation's verification scope.
RDD remains clone-local off; unassessable native risk was treated as high for
independent verification. No native review or receipt is claimed. Changes remain
unstaged/uncommitted. Parent archived this record, preserving historical evidence.
Owner subsequently approved local commits and the over-budget exception: preserve
the filter, tests, and documentation as one coherent commit (`exception-ok`).
The independent policy refresh was committed separately as `1e1dff6`.
No push or PR is authorized; prior unstaged-state statements are historical evidence.
