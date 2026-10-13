# Registry permissions and operational verification

## Objective and authorized scope

Implement design observation 3167: ordinary 0755 test registry with private
artifacts, preservation of ignored files and Git metadata, read-only operational
preflight, sanitized diagnostics, and a producer-only operational verification skill.
Preserve existing ownership, identity, immutable-module and exact permission grants.

User authorizes local code, documentation, skill and unprivileged tests only.
No staging, commits, push, real registry migration, privileged tests, real Docker
execution, remote access, version-policy changes or global skill changes.
The agent runs in CONTAINER against the HOST bind-mounted checkout.

## Baseline and planning

- Branch: `feat/runtime-directory-policy`.
- HEAD: `36a186e9a3a866ed2fa383b94a3f7ac0ebb71441`.
- Initial index/worktree: clean; remote inspected without network operations.
- `AGENTS.md` and full observation 3167 read before implementation.
- Precreation inventory: `odd/tasks/` empty; existing archives remain unchanged.
- Delivery: local unstaged diff only; commits explicitly prohibited.
- Forecast: four coordinated units, likely over 400 authored changed lines.
  No PR or chain planning is authorized or required for this local delivery.
- Route: delegated direct for each unit; unfamiliar multi-file behavior and
  preparation-for-writing trigger delegation. One writer at a time.
- Test policy: default meaningful deterministic RED → GREEN → REFACTOR;
  no invented mode configuration or proof. Passive docs use structural checks.

## Tasks and acceptance

- [x] A — Registry and normalization. Create registry 0755 even with umask077;
  retain safe legacy modes without migration; refuse unsafe ownership, symlinks
  and writes; preserve private records/scratch/snapshots. Preserve literal ignored
  files/symlinks and Git administration across all normalization passes while
  retaining tracked index modes. Include focused regression tests and docs.
- [x] B — Read-only preflight. Share parsing and validation before registration;
  explicit preflight has no registration, scratch/probe/build/config mutation.
  Preserve exact supported adapter contracts and explicit operational authority.
- [x] C — Sanitized diagnostics and proof-selection docs. Fixed stage/reason/
  next-step output, no secrets/raw exceptions, original versus cleanup failure;
  retain module freeze order and exact generated-Dockerfile grant.
- [x] D — Producer-only operational-verification skill. Generic thin body,
  local harness reference, MIT attribution, narrow ignore exception, AGENTS
  registration and consumer exclusion regression; do not change classifier.
- [x] V — Focused independent verification and structural readback; reconcile
  all proof limitations, native review state and archive/mirror before closure.

## Checks and evidence

After fixture inspection, run with `PYTHONDONTWRITEBYTECODE=1`:

- `python3 .maintainer/test/unit/test-resources-test.py`
- `python3 .maintainer/test/unit/starter-lifecycle-test.py`
- `python3 .maintainer/test/unit/generated-dockerfile-read-test.py`
- `python3 .devcontainer/test/unit/runtime-directory-permissions-test.py`
- Selected nonprivileged diagnostics and Bats cases only.
- Effective explicit-file Markdown lint, frontmatter/local links, ignore checks,
  `git diff --check` and index/worktree readback.

Distribution fixtures currently create Git commits; do not execute those fixtures
under current authorization. Use nonmutating structural proof or report missing
fixture execution. No live Docker preflight or lifecycle proof is authorized.
Native review mode must be read without changing it; unavailable is not approval.

## Progress and next step

Exploration completed with exact candidate surfaces and safe runner evidence.
A implemented with observed RED and GREEN: resources 60, adapter 61, runtime 54,
lifecycle 59, selected ignored-file diagnostic 1 tests passed; diff check passed.
Parent reran resources: 60 passed. All changes unstaged; no real migration.
RDD mode refused unsafe authority permissions; no repair performed. Risk assessment
returned high/unassessable because the new task record is untracked. Independent
verification is required; no native approval claimed.
B implemented with observed RED (unrecognized --preflight) then GREEN: lifecycle
79, adapter 61, resources 60 and one Task dry-route Bats case passed; diff check
passed. Metadata queries are bounded and fixed-local; all tests mock Docker.
No live metadata or preflight execution was performed. Unit B exceeds the advisory
400-line size because the coherent validation, regression tests and docs stay together.
C implemented with observed RED then GREEN: adapter 66, lifecycle 83, resources
60 and two selected secrecy diagnostics passed; diff check passed. Original and
cleanup failures are independently sanitized; freeze ordering and native transport
remain covered. A diagnostic fixture required locale isolation and was rerun green.
Unit C slightly exceeds the advisory size to retain tests and documentation.
D implemented: MIT generic skill and local reference, registration/ignore exception,
distribution fixtures/assertions, unchanged classifier. Pure structural classifier
checks passed before/after creation; no meaningful RED exists for unchanged classifier.
Full distribution Bats remains skipped because its setup stages and commits.
Frontmatter/local links/ignore checks passed; body estimated 450 tokens (tokenizer
unavailable). Effective Markdown lint ran from temporary cwd over three absolute
paths and passed, correcting an earlier one-file-only coverage result. Native skill
registry refresh succeeded (21 skills), generated ignored index and mirror updated.
Independent verification found no candidate correctness findings in inspected A–D.
Observed final tests: resources 60, lifecycle 83, adapter 66, runtime 54,
three selected diagnostics and one Task routing Bats case: 267 passing tests.
Explicit effective Markdown lint checked six files, zero issues. Independent pure
classifier, frontmatter, local links and four ignore checks passed. Parent repeated
runtime 54 after verification; diff check passed, index empty and HEAD unchanged.
Verifier command mistakes (unittest module invocation and initial AST lookup)
executed no successful proof; corrected bounded checks passed without source edits.

Authorized local implementation and nonprivileged verification are complete.
Full distribution Bats and staged-overlay fixtures were deliberately excluded under
the no-staging/no-commits instruction; pure classifier proof does not replace release
publication proof. Docker metadata/preflight/probe/build/start/recreate/cleanup,
privileged and remote proofs, real registry migration and native RDD approval were
not performed. These exclusions do not authorize later operations. Native mode
refusal was preserved; independent technical verification is not native approval.
No implementation/product decisions remain pending within the authorized scope.
All source changes remain unstaged/uncommitted for owner review; no delivery commits
or PR boundaries exist. Next recommended human action: inspect the local diff in
VS Code; any live operation, migration, commit or publication needs fresh consent.
Closed local work record archived after scope/evidence reconciliation, preserving
history. No current navigation links required relocation; mirror locator updated.
Recovery mirror topic: `odd/operational-verification-harness-hardening/tasks`.
Current locator: `odd/archive/operational-verification-harness-hardening.md`.
