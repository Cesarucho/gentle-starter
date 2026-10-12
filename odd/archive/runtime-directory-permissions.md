# Runtime Directory Permissions

## Objective and problem

Apply declarative, exact-directory runtime permissions after mounts are available. Gentle AI rejects its clone-local authority at mode 0755; workspace normalization can overwrite private directory modes.

## Authorized scope and constraints

- Add a JSON policy and guarded runtime helper; default workspace authority mode 0700, missing skip.
- Resolve workspace separately and writable managed Compose directory binds from the validated applied manifest; use managed source paths as stable root identifiers.
- No recursive repair, creation, ownership changes, sudo, symlink following, remote operations, real Docker builds or lifecycle runs.
- Preserve host-prepared bind roots and all policy-controlled subtrees during existing normalization and tracked-mode restoration.
- Cover create, Dev Container start and public restart. Do not migrate SSH or local-parent provisioning.
- Repository policy overrides automatic work-unit commits: leave changes unstaged/uncommitted until owner approves reviewed diff.

## Tasks

- [x] T1: Implement policy/helper, lifecycle integrations, focused tests and documentation as one coherent work unit.
  - Route: delegated direct; preparation and multiple non-trivial files trigger delegation.
  - Acceptance: exact 0700 repair, idempotence, absent skip, strict schema/root/path validation, no-follow ownership checks, mode-only changes, protected descendants, failure propagation and lifecycle wiring.
- [x] T2: Independently verify, reconcile evidence and archive this record.
  - Route: delegated verification; review mode unreadable initially, treated as unknown.

## Verification

- Applicable default test-first policy: observe failing deterministic fixture tests before implementation, then GREEN and refactor.
- New isolated Python helper suite plus safe Bats manifest, restart and volume tests.
- `PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/compose-manifest-test.py -v`
- `PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/compose-manifest.bats .devcontainer/test/unit/devcontainer-tasks.bats .devcontainer/test/unit/volume-repair.bats`
- Parent focused spot check and native risk assessment; independent verifier if high/unassessable.
- Real Docker lifecycle/build proof not authorized. No application test proof claimed.

## Progress and delivery

- Baseline: dev, c2c0f87, initially clean worktree.
- Initial `gentle-ai review mode status` failed on unsafe authority permissions; mode unknown. No preference change authorized.
- Delivery strategy: single local uncommitted change for owner review; no PR or publishing planned. Forecast approximately 400–700 authored lines including security tests; advisory budget, not a reason to omit coverage.
- Commit evidence: pending explicit owner approval, not required for local implementation closure.
- Writer implemented helper, JSON policy, lifecycle wiring, subtree exclusions, tests and documentation. Writer observed deterministic RED then GREEN; parent and independent verifier reran 17 helper tests successfully.
- Independent verifier: 41/41 focused Bats tests pass; shell syntax and diff checks pass. Full Compose checks fail on pre-existing Pi model assertion: HEAD test expects gpt-5.6-sol while unchanged HEAD configuration contains gpt-6.1-sol. Out-of-scope baseline failure remains disclosed, not fixed.
- Native assessment high/unassessable because untracked inventory not declared; no native review started, no approval claimed. Mode read remains unavailable due to existing unsafe authority. Actual runtime policy has not been applied to the current authority.
- Real lifecycle/build proof and privileged fixtures remain unexecuted; only isolated wiring/security fixtures verified.
- During independent verification AGENTS.md appeared modified outside allowed writer surfaces. Diff adds the precreation ODD inventory gate already present in injected instructions. Origin unknown; preserve it unchanged.
- Next step: ask owner whether AGENTS.md change is theirs, then reconcile remaining proof and archive only when closure is safe. T2 pending; no completion claimed.

## Closure reconciliation

- Owner confirmed the AGENTS.md change is theirs; preserve it as independent local work, outside this implementation.
- Local implementation and independent focused verification complete. Parent spot check also passed all 17 helper tests. No implementation or product decisions remain pending within the authorized scope.
- Baseline Compose model assertion failure is an unrelated follow-up, not a candidate-caused regression. Full regression suite is not reported as passing.
- Native RDD mode was unavailable; unknown-mode verification path used writer checks plus independent verification for high/unassessable risk. No native approval or receipt claimed, no mode preference changed.
- Real Docker lifecycle, privileged fixtures and application tests remain outside performed proof. Current mounted authority permissions have not been repaired by executing the helper.
- Archived as odd/archive/runtime-directory-permissions.md after reconciliation; no current navigation references required changes.
- All changes remain unstaged/uncommitted on dev under repository policy. Next recommended action: owner review of the local diff; actual runtime application is a separate action.

## Authorized revision: creation-only policy

- User clarified that automatic permission application should occur only on creation/recreation, not on each start/restart. This supersedes recurring enforcement above; prior evidence remains historical.
- [x] T3: Remove postStart and Docker restart application, update affected tests/docs, and verify creation-only coverage.
  - Route: delegated direct; existing multi-file behavior, tests and documentation require a bounded writer.
  - Preserve setup preflight, exclusions and apply, helper, JSON default rule, all other local changes and user-owned AGENTS.md.
  - Verification: focused Python and Bats suites, shell syntax and diff checks; no actual Docker or authority repair. Test-first regression for absence of recurring hooks.
- [x] T4: Independently verify revision, reconcile and rearchive the same feature record and mirror.
- Delivery remains local, unstaged and uncommitted. T3 writer observed RED then GREEN: 19 Python tests, 41 Bats tests, shell syntax and diff checks pass. Parent reran all 19 Python tests and diff check successfully; devcontainer.json and public restart Taskfile match HEAD again. Next step: independent T4 verification.
- Revision closure: independent verifier reran 19/19 Python and 41/41 Bats successfully, diff check passed, confirmed setup protections remain and creation-only docs match behavior. No new blockers; original baseline and operational-proof limitations remain disclosed above.
- Final locator: odd/archive/runtime-directory-permissions.md. No navigation links reference the tasks locator. No actual runtime repair, commits, staging or publishing performed. Next step: owner review of local diff.

## Authorized revision: explicit directory creation

- Add missing:create for explicit owned subdirectories, creating privately before applying final modes; missing intermediates require explicit create rules. Keep authority missing:skip, no recursive implicit provisioning, no sudo/chown/bind-root mutation, creation-only lifecycle.
- Migrate only compatible SSH host-key child provisioning through a scoped policy when SSH is enabled and its bind applied. Keep SSH root and authorization preparation, local-parent ownership recovery, build installation and host bind provisioning separate.
- [x] T5: Implement create semantics, safe parent-child planning, scoped SSH child migration, focused tests and documentation.
  - Route: delegated direct; preparation and multiple nontrivial files require one bounded writer.
  - Verification: deterministic RED/GREEN Python and Bats fixtures; no actual runtime repair, network, builds or Docker lifecycle. Preserve user AGENTS.md and all unrelated edits.
- [x] T6: Independent verification and reconciliation, then rearchive and read back full mirror.
- Forecast: approximately 300–600 additional authored lines including security regression tests; advisory only. Changes remain unstaged/uncommitted; no publishing or automatic commits authorized.
- Owner selected contract B: runtime SSH_CONFIG_DIR must match the validated applied SSH target; reject unbound overrides before mutation and adapt fixtures, without a legacy fallback.
- Writer observed RED then GREEN: 34 Python tests, 41 general focused Bats, 13 SSH ownership fixtures and 12 stubbed SSH startup fixtures pass; shell syntax and diff checks pass. Parent reran all 34 Python tests and diff check successfully.
- Native mode read still fails on existing unsafe authority; risk assessment high/unassessable due to undeclared untracked inventory. Use independent verification for unknown-mode path; no authority repair or receipt claimed.
- Next step: independent T6 verification; creation is nontransactional and narrow same-user races are documented, not represented as atomic.
- T6 closure: independent 34 Python, 41 general Bats, 13 SSH ownership and 12 stubbed startup tests pass; syntax and diff checks pass. No in-scope defects or product decisions remain. Permissive umask exercised; restrictive ambient umask preservation assessed structurally, not a separate execution scenario. Original baseline/lifecycle/native-proof limitations remain disclosed.
- Final revision preserves creation-only integration, authority missing:skip, SSH root/authorization and local-parent recovery. SSH child now created by scoped policy; unbound overrides refused under explicit user choice B.
- Reconciled record rearchived to odd/archive/runtime-directory-permissions.md; no current navigation references require changes. All edits remain unstaged/uncommitted, AGENTS.md preserved. Next action: owner reviews local diff, not automatic runtime application.

## Authorized revision: consolidated policy

- Consolidate rules into runtime-directory-permissions.json; remove the SSH-only policy file. Add explicit validated optional-tool applicability, not silent skipping of unknown roots. Applicable invalid targets still fail closed.
- Preserve creation-only lifecycle, explicit create/skip semantics, contract B target validation before mutation, bind-root and ownership boundaries, current authority skip and independent user AGENTS.md.
- [x] T7: Implement single-policy applicability, update helper/SSH integration, tests and documentation.
  - Route: delegated direct; preparation and multiple nontrivial files require one writer.
  - Checks: deterministic RED/GREEN focused Python/Bats, shell syntax and diff check; no Docker/network/actual authority repair.
- [x] T8: Independent verification, reconcile and rearchive with full mirror readback.
- T7 implementation: unified JSON with strict when.enabled_installer applicability; generic root selection/expected-target validation; setup validates deferred SSH-root privacy without applying it, SSH installer owns root recovery then selected child apply. Parent removed obsolete unused SSH JSON.
- Writer observed RED then GREEN: 44 Python, 41 general Bats, 14 SSH ownership and 12 startup fixtures pass; shell syntax and diff checks pass. Parent reran44 Python and diff check after deletion successfully. Native mode remains unreadable; high/unassessable assessment uses independent verification fallback, no receipt.
- Next step: independent T8 verification. Local changes remain unstaged/uncommitted; no commits or publishing authorized.
- Independent verification found a full-policy filesystem gap before selected mutation. One scoped correction reproduced four RED regressions and now validates all applicable filesystem rules through a metadata-only plan before selection, rechecking safety immediately before apply; unselected modes remain unchanged.
- Final independent checks: 50 Python, 41 general Bats, 15 SSH ownership and 12 startup fixtures pass; shell syntax and diff check pass. Parent spot check reran50 Python successfully. Setup ordering is SSH preparation, general policy application, then SSH startup; no recurring hooks.
- Consolidation complete: one JSON, explicit enabled_installer applicability, no obsolete SSH policy file or executable references. No pending in-scope work or product decisions; original baseline/native/real-lifecycle limitations remain disclosed. AGENTS.md preserved, no staging/commits/runtime authority repair.
- Rearchived to odd/archive/runtime-directory-permissions.md with full mirror reconciliation. Next recommended step: owner review of the local diff.

## Owner-approved delivery

- Implementation commit: `9ef579d4a6a829369c8669e2e2f367da96a2ab49` (`feat(runtime): centralize exact directory permission policy`).
- Delivery branch: `feat/runtime-directory-policy`, created from `dev` at `c2c0f8724cc503bbc0d67e397e365e5e5ade4d48`; no push performed.
- Precommit review found the OpenCode policy-helper mock still expected three arguments. Its strict signature now matches five-argument exclusions/apply and seven-argument enabled-SSH exclusions. Direct executable branch tests observed RED before correction; independent verification passed18 accepted/rejected cases without setup, teardown or sudo. Full privileged OpenCode suite remains skipped, not claimed PASS.
- Final focused rerun passed50 Python helper tests and41+15+12 Bats tests; maintainer proof is recorded separately. Owner AGENTS.md and all private Git evidence excluded. Registry0755 changes and the new operational-test skill remain future work, not part of this delivery.
