# Privileged fixtures and consumer DinD proof

## Objective and scope

Repair the authorized OpenCode Bats fixture contract and execute the existing
privileged and consumer DinD proofs without weakening production guards.
Only source edit authorized: `.devcontainer/test/unit/opencode.bats`.
No primary checkout staging, commits, push, authority repair or remote operations.
Synthetic Git commits/refs are authorized only in consumer isolated scratch.
The CONTAINER shares the HOST checkout. Registry is already owned and 0755;
no migration is needed and no permission repair is authorized for RAR authority.

## Baseline and problem

HEAD `36a186e9a3a866ed2fa383b94a3f7ac0ebb71441`, branch
`feat/runtime-directory-policy`; index empty and previous A–D edits preserved.
Precreation inventory: `odd/tasks/` empty.
Prior privileged run: exit 1, 1.342 seconds, 11 failures / 4 TAP successes.
Git stub omits administrative paths; obsolete structural heading breaks a test.
Two negative tests pass through the wrong early guard and need precise assertions.
Consumer metadata preflight was ready; actual DinD remains unexecuted.

## Tasks and acceptance

- [x] F — Update only the Git stub, structural matcher and negative assertions.
  Keep production unchanged; prove intended failure branches, not any nonzero exit.
  Route: delegated direct, preparation for an unfamiliar write triggers delegation.
- [x] P — Repeat `PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/opencode.bats`
  once; report actual privileged behavior and cleanup. Outer timeout 10 minutes.
  Separate independent verification and parent spot check retain honest evidence.
- [x] D — Execute existing `PYTHONDONTWRITEBYTECODE=1 task --taskfile
  .maintainer/Taskfile.yml test:starter:lifecycle -- --consumer` once after P.
  Forecast: 60-minute soft budget / 90-minute outer limit; several GiB possible
  downloads/cache. Exact-byte cached probe and scoped resource ownership required.
  Two DinD Feature volumes are intentionally retained; no global pruning.
- [x] V — Reconcile scope, outcomes, failure/cleanup limitations and local Git state.
  Archive only completed scope with full Engram mirror readback; no invented PASS.

## Verification and constraints

Prior observed fixture failures are RED evidence, not new production regressions.
Use applicable default test-first policy; passive records use structural checks.
Do not rerun Docker or expensive tests blindly; stop at the first failed guard.
Temporary privileged install/chown/remove applies only to identified test fixtures.
No real checkout setup, unrelated permission changes or credentials inspection.
Native RDD status was unavailable due unsafe authority permissions; preserve state,
use independent technical verification and never call it native approval.
Delivery remains an unstaged local diff; user prohibits work-unit commits.
Forecast fixture edit under 150 authored lines, not a code-size acceptance gate.
Recovery topic: `odd/privileged-fixtures-and-consumer-dind/tasks`.
Current locator: `odd/archive/privileged-fixtures-and-consumer-dind.md`.
F implemented in the authorized fixture only; production/index/HEAD unchanged.
First post-edit suite: 14 passed / 1 failed, exit 1, 2.850 seconds. The remaining
new log assertion matched `.gitignore` as `.git`; no expensive blind retry occurred.
Surgical path-boundary correction then passed five synthetic matcher checks and
the affected privileged test once (exit 0, 0.449 seconds). Prior metadata/content/
symlink assertions remain intact. Teardown reported no errors; exact temporary
root removal was not independently captured in these two writer runs.
Independent final suite: 15 passed, 0 failed/skipped, exit 0, 2.859 seconds.
No assertion weakening found; checkout snapshots and index/HEAD remained unchanged.
Thirteen captured fixture roots were absent afterward; two short-lived roots were
not captured and 115 environment observations were permission denied. Native
teardown reported no errors; full independent cleanup proof is not claimed.
Parent repeated the affected test once: passed; diff check passed. Record lint
passed but repository globs caused 23 files to be checked, not just this record.
Native mode still refused unsafe authority and risk assessment was high/unassessable;
independent technical proof is not native approval, no repair/toggle performed.
Consumer proof executed once: exit 0, 152.201 seconds, run
`fe5ffdaa-08f8-427a-8448-be514f59c8a5`. Supervisor soft budget 3600 seconds,
outer timeout 5400000 ms; no timeout occurred. An unavailable `/usr/bin/time`
wrapper exited 127 before launch; Bash timing supervised the sole real invocation.
Mandatory cached-image exact-byte bind probe preceded candidate preparation.
Filtered release clone/build/start, absence of HOST Docker socket bind, distinct
nested daemon and nested `hello-world` as ubuntu passed. This does not prove base
recreate/runtime-directory scenarios, optional integrations or native review.
Native finalization reported five removed entries and three retained entries.
Exact scratch independently absent. Parent repeated selected-run read-only recovery
preview: passed inventory; only shared cache and two Feature state volumes retained.
Compact inventory/lock/diagnostics remain private. No apply/forget/global prune ran.
Primary before/after diff/status/untracked hashes matched, index empty and HEAD
unchanged. Registry remained owner/group 1000:1000 and 0755; no migration performed.

Authorized fixture repair and both requested test scenarios are complete. No source
changes beyond the authorized fixture, no primary commits/push, authority repair,
review-mode changes or remote execution occurred. Privileged fixture cleanup
visibility remains limited as documented above; complete removal is not claimed.
DinD state retention is intentional, not an unresolved cleanup failure. No pending
implementation or product decision remains within this feature scope. Record
archived after reconciliation; no other current navigation references needed moving.
Next recommended human action: review the unstaged local diff before any commit.
Deleting retained Feature volumes or repairing real RAR authority needs separate
explicit authorization and scoped ownership evidence.
