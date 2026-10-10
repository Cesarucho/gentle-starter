# Add optional OpenSpec catalog support

## Objective and scope

Add the image-owned `@fission-ai/openspec` npm CLI as optional catalog
installer `3080-ai-openspec.sh`, with Node/npm dependency and stable 1.x intent.
State classification: none. Project initialization remains an explicit user action.
No activation, configuration, Compose, Dockerfile, global installation, build,
container lifecycle, branch, staging, commit, or remote operations are authorized.

## Work unit and route

One coherent implementation work unit: installer, policy/updater, tests, and docs.
Delegated implementation route; trigger: multi-file managed-tool addition.
Delivery strategy: ask-on-risk; forecast: approximately 300–400 authored lines.
Forecast: focused mocked tests and read-only checks take several minutes.
Scoped generation uses modest public npm registry metadata access, no archives,
with a 600000ms execution timeout; unrelated locks and intent must stay unchanged.
Ordinary updater execution is prohibited. Scoped temporary publishing is approved.
Commits remain pending explicit owner approval; parent owns review and closure.
Rollback boundary: remove this optional catalog registration, scoped route, and
associated tests/docs together; preserve all unrelated policy bytes.

## Acceptance and checklist

- [x] Add exact-lock npm installer, executable mode, runtime no-op, version
  verification, idempotence, and print-policy support.
- [x] Declare dependency on `2000-runtime-node.sh`; keep tool inactive.
- [x] Register editable `TOOL_OPENSPEC_VERSION="1"` and generated lock ownership.
- [x] Add metadata-only `--update-openspec`, preserving unrelated bytes and mode.
- [x] Observe deterministic RED then GREEN for installer and scoped updater.
- [x] Test stable 1.x selection over prereleases/2.x, bootstrap, invalid metadata,
  no matching versions, parsing, and absence of unrelated provider calls.
- [x] Generate the lock only through `task tools:update -- --update-openspec`.
- [x] Run required verification and report every result, including inactive skip.
- [x] Parent reconciled authorized scope and verification evidence and archived the record.

## Checks and remaining proof

Required: focused Bats installer/updater/policy/dependency/activation tests;
`bash -n`, ShellCheck; updater validation; install list, doctor, versions validation,
volumes; `task validate`; filtered OpenSpec integration check.
Actual npm installation and active-container CLI proof are not authorized.
The integration check may skip because the optional tool remains inactive.

## Evidence

Initial worktree: clean `dev`, HEAD `22d6d2154acff4c4eea1fc81b7e171ff8397b7a5`.
Install-tree inspection passed; catalog slot 3080 is unused.
Repository locator: `odd/archive/add-openspec.md` (formerly `odd/tasks/add-openspec.md`).
Engram mirror topic: `odd/add-openspec/tasks`.

RED: `bats --filter openspec .devcontainer/test/unit/openspec.bats
.devcontainer/test/unit/tools-update.bats` observed four intended failures before
implementation (missing installer and missing scoped route). GREEN: same focused
selection passed all seven tests. Final expanded focused suite passed 121 tests.
Scoped metadata generation produced `LOCK_OPENSPEC_VERSION="1.14.1"` with no
unrelated lock or intent updates. npm lifecycle scripts are not disabled; actual
installation compatibility remains unproven because global installation is forbidden.

Final verification passed: focused Bats across openspec, tools-update, tool-policy,
install-dependencies, and install-activation; `bash -n` and ShellCheck for installer
and updater; `task tools:update -- --validate`; `task install:list`;
`task install:doctor`; `task install:versions:validate`; `task install:volumes`;
`task validate`; `git diff --check`.
ShellCheck initially reported SC2015; an explicit conditional fixed it before final
verification. `task validate` reported zero errors and 11 missing optional-skill
warnings. `bats --filter openspec .devcontainer/test/integration/tools.bats` exited
successfully with one disabled-selection skip: not actual installation proof.
Changes remain unstaged and uncommitted; independent review and archival are parent-owned.

## Parent closure

Authorized catalog implementation is complete; actual installation and active-image
proof remain outside this scope, not claimed as verified. Independent verification
reran all 121 focused tests and scoped ShellCheck successfully. Parent reran
`bash -n` and `git diff --check` successfully. No candidate-caused blocker was found.
RDD is off by clone-local preference; no native review was started and no approval
receipt is claimed. Native assessment was unassessable due to undeclared untracked
files and treated as high for independent verification, not as a low-risk result.
Implementation evidence remains worker-reported where not independently rerun.
Authored implementation footprint reported by writer: 316 additions, 2 deletions.
No delivery slices or commits were created; owner approval is required for commits.
Archived by parent after reconciliation. Next action: owner reviews the unstaged diff.
