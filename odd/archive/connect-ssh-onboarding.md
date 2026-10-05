# Connect-only manual SSH onboarding

Persist manually verified GitHub host trust in optional managed `.ssh` state.
Only `task container:connect` receives a dedicated interactive startup file;
ordinary shells and all other entrypoints remain unchanged.

## Current local commit authorization

The owner explicitly authorized two local work-unit commits: the SSH comparison
fix with its tests and this record, and the owner-edited OpenCode configuration.
This current authorization overrides earlier no-commit constraints below; those
sections remain historical snapshots. Commit creation is still pending and
belongs to the parent, not this bounded preparation worker.

- [x] C05 Owner approval granted for these two current local commit scopes.
  This records owner authorization, not native review approval.
- [ ] Parent creates the two authorized commits after preparation.
- SSH unit: `.taskfiles/scripts/container-connect.bash`,
  `.devcontainer/test/unit/container-connect-test.py`, and this document.
- OpenCode unit: `.devcontainer/config/opencode/opencode.json` only. The owner
  manually fixed the JSON; current parsing and semantic comparison against HEAD
  confirm exactly 20 fallback-agent profiles removed, with retained content
  unchanged. No configuration or source changes are authorized for this worker.
- Exclude `.devcontainer/install/03-enabled/4000-tool-ssh.sh` from both units;
  leave the existing untracked alias untouched and unstaged.
- Native review preflight was attempted but did not reach START or approval.
  Status remains pending: `intended_untracked_selection_required`. No review
  execution, approval, or provider repair is claimed; none is invoked here.
- Worker boundary: edit only this document and mirror it to Engram #2425;
  foreground check-only normalization and local checks only. No staging, commits,
  push, network, remote access, Docker, source/config edits, subdelegation, or
  native review invocation. TDD remains unconfigured; these are ordinary tests.
- Rollback boundaries: revert the SSH unit independently of the owner OpenCode
  unit; restore only removed fallback profiles for the OpenCode unit. Neither
  rollback includes the excluded alias or unrelated work.

### Current preparation evidence

Observed `dev` at `cfc8f0e7e34cb0889a13e12b313a1b4d98561ab3`; index unchanged
and cached diff empty. No commits were created by this preparation worker.

- Foreground normalization/check-only first:
  `shfmt -d .taskfiles/scripts/container-connect.bash .devcontainer/test/unit/container-connect.bats`:
  exit 0, no differences; no formatter writes.
- `PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/container-connect-test.py`:
  exit 0; 10 plain/hashed algorithm cases and all retained controls passed;
  timeout 0.753s, PID 12156, SIGKILL reaped, no live or waitable child.
- `bats .devcontainer/test/unit/container-connect.bats`: exit 0, 1/1 passed.
- `bash -n .taskfiles/scripts/container-connect.bash`: exit 0, no diagnostics.
- `shellcheck -s bash .taskfiles/scripts/container-connect.bash .devcontainer/test/unit/container-connect.bats`:
  exit 0, no diagnostics.
- `shfmt -d .taskfiles/scripts/container-connect.bash .devcontainer/test/unit/container-connect.bats`:
  exit 0, no differences.
- `markdownlint-cli2 --no-globs odd/tasks/connect-ssh-onboarding.md`:
  exit 0, 1 input file, 0 issues.
- `git diff --check`: exit 0, no diagnostics.
- JSON proof: `json.loads` accepts both current configuration and HEAD;
  semantic equality after removing precisely the 20 fallback profiles proves
  all retained agents and other configuration unchanged.
- Bounded secret scan: full tracked candidate diff checked for private-key
  headers, common GitHub/AWS credential patterns, and quoted credential
  assignments; no matches. This is heuristic, not a comprehensive secret audit.
- Runtime boundary: local PTY fixtures only; actual SSH authentication, agent
  responsiveness, consumer persistence and Docker lifecycle remain unverified.

## Historical route and constraints

- Multi-file implementation triggers the delegated route; the assigned writer
  executes directly, with no further delegation or agent/review usage authorized.
- TDD mode: not established by explicit configuration; ordinary focused tests,
  no invented RED evidence. Forecast: approximately 400 changed lines per task,
  advisory rather than a cap. Local tests only; no downloads or operational proof.
- Source: `dev`, `b64b5fe2a4cc89aab4ee2f8720710f9cc596e2d5`.
  The canceled `starter-rc` is not regenerated. Preserve pending release-doc
  corrections in `extending.md` and `simplify-development-tools-docs.md`.
- No staging, commits, push, network, Docker, builds, lifecycle tests, automatic
  trust acceptance, private-key mounts, global shell hooks, or runtime chown.

## Tasks

- [x] C01 Inspect current helpers, skills, state, and test effects; publish this plan.
- [x] C02 Add applied-manifest eligibility, passive optional SSH state, and safe
  host preparation with focused local tests.
- [x] C03 Add connect-only startup preserving readable `.bashrc`, local socket
  and read-only known-host checks, with manual guidance and focused tests.
- [x] C04 Document activation, persistence and manual verification; normalize
  sources before functional tests, record exact local results and preservation.
- [ ] C05 At this historical snapshot, owner review and later commit authorization
  were pending; current scoped approval is recorded above.

## Checks

- [x] K01 One validated applied snapshot proves canonical override and both binds.
- [x] K02 New `.ssh` root is 0700; safe existing data/modes survive; unsafe roots
  fail with remediation, without repair. Other new managed directories stay 0755.
- [x] K03 Interactive TTY only; socket existence is not agent responsiveness.
- [x] K04 Plain/hashed lookup suppresses keys; presence is not valid trust;
  revocation, conflicts and lookup errors are visible. No forbidden commands run.
- [x] K05 Startup failures are nonfatal; `.bashrc` and ordinary nested shells survive.
- [ ] K06 All touched-shell ShellCheck passes: existing fixture warnings remain.

## Local verification

Normalization ran before functional tests:
`shfmt -w .taskfiles/scripts/container-connect.bash .devcontainer/test/unit/container-connect.bats .devcontainer/test/unit/host-bind-preparation.bats .devcontainer/test/unit/volume-repair.bats`.

Observed PASS commands:

- `PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/compose-manifest-test.py ManifestTests.test_connect_agent_applied_snapshot_only -v`: 1 test.
- `PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/compose-manifest-test.py ManifestTests.test_agent_override_static_independence -v`: 1 test; local YAML only.
- `bats --filter 'SSH root direct preparation' .devcontainer/test/unit/host-bind-preparation.bats`: 1 test.
- `bats --filter 'SSH client trust state' .devcontainer/test/unit/volume-repair.bats`: 1 test; local fixture mapping only.
- `bats .devcontainer/test/unit/container-connect.bats`: 1 wrapper test covering
  local PTY gating, plain/hashed/revoked/conflicting/error entries, no forbidden
  calls, preserved bashrc, nested shell and nonfatal eligibility failures.
- `bash -n .taskfiles/scripts/container-connect.bash`.
- `shellcheck -s bash .taskfiles/scripts/container-connect.bash .devcontainer/test/unit/container-connect.bats`.
- `shfmt -d .taskfiles/scripts/container-connect.bash .devcontainer/test/unit/container-connect.bats .devcontainer/test/unit/host-bind-preparation.bats .devcontainer/test/unit/volume-repair.bats`.
- `markdownlint-cli2 --no-globs .devcontainer/docs/optional-integrations.md odd/tasks/connect-ssh-onboarding.md`: 2 files.
- `git diff --check`.

Full touched-shell ShellCheck reports existing SC2155/SC2016 in host-bind and
SC2016/SC2034/SC1091 in volume-repair; unrelated lines were not repaired.
No configured TDD RED, real agent responsiveness, authentication, persistence
across actual recreation, or full Compose merge proof is claimed.
The two pending owner-edited files were never written; index and HEAD unchanged.

## Evidence and locator

Inspected fixtures: existing host-bind Bats invokes real Docker Compose and is
not authorized as a whole; existing Python suite contains Docker/Task cases.
Select only hermetic cases and new direct preparation cases. Operational proof
and actual GitHub authentication remain manual and unverified here.

Repository: `/home/ubuntu/gentle-starter`.
Document: `odd/tasks/connect-ssh-onboarding.md`.
Engram full-document mirror: `odd/connect-ssh-onboarding/tasks`.

## Accepted advisory R3-pty-timeout

- [x] Owner authorized this nonblocking advisory before commits/publication.
  Scope: only the local Python PTY fixture and this task record; all other
  approved candidate bytes remain unchanged. No delegation or new review.
- [x] Add the regression first, then replace the blocking read with a nonblocking
  descriptor and selector using the remaining monotonic deadline (default 5s).
  The final child wait shares that deadline. Timeout/exception cleanup sends
  TERM, waits at most 0.25s, then sends KILL and waits at most 1s; PTY descriptors
  close in `finally`. Unexpected read errors propagate after cleanup.
- [x] Regression uses only a local Python child, prints its PID, ignores TERM,
  and blocks in `signal.pause()`. A 0.5s override proves timeout, KILL return
  status, PID absence via `kill(pid, 0)`, and reaping via `waitpid`.
  No sleeps, real agent, network, Docker, builds, or SSH execution are added.
- Normalization: manually normalized new Python imports and whitespace and
  Markdown wrapping before functional checks; existing shell bytes untouched.
  Configured TDD remains unestablished. Regression was authored first; the old
  unbounded reader was not executed with a hanging child, so no RED is claimed.
- [x] `bats .devcontainer/test/unit/container-connect.bats`: PASS, 1 wrapper test.
- [x] `PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/container-connect-test.py`:
  PASS, all prior assertions retained. Timeout elapsed 0.753s for PID 83061;
  SIGKILL return status, `alive=false`, and no waitable child all verified.
- [x] `git diff --check`: PASS.
- [x] `markdownlint-cli2 --no-globs odd/tasks/connect-ssh-onboarding.md`: PASS,
  1 input file, 0 issues (the CLI summary reports 0 files with issues).
- Rollback boundary: remove only this advisory section and the PTY timeout
  helper/regression changes in `container-connect-test.py`; prior proof remains.
  Operational SSH/authentication/persistence proof remains out of scope.

## Authorized correction: algorithm-scoped host-key comparison

Historic sections above remain snapshots, not current branch or proof claims.
Current preparation observed `dev` at `cfc8f0e7e34cb0889a13e12b313a1b4d98561ab3`.

- Route: delegated (two nontrivial source/test files and preparation trigger);
  this assigned writer works directly without further delegation or native review.
- Scope: `.taskfiles/scripts/container-connect.bash`,
  `.devcontainer/test/unit/container-connect-test.py`, and this document only.
- Acceptance: compare blobs per algorithm regardless of ordering or comments;
  different algorithms and identical duplicates do not warn, same-algorithm
  differing blobs warn, and revoked records warn independently. Retain privacy,
  nonfatal startup, eligibility, TTY, bashrc, and forbidden-call controls.
- Fixtures: temporary HOME and local key generation only; plain/hashed
  ED25519/RSA/ECDSA, commented duplicates, interleaved conflicts and revocation.
- Forecast: fewer than 200 authored changed lines, advisory, one cohesive work
  unit. Delivery: ask-on-risk if scope or forecast becomes unsafe; no staging,
  commit or publication authorization. Owner retains review authority.
- TDD is not explicitly configured: ordinary focused testing, regressions first
  and safe observed pre-fix failure; no claimed configured strict mode.
- No network, remote access, ambient agent inspection/calls, real consumer trust
  edits, Docker, builds, or broad lifecycle suites. Preserve initial unrelated
  OpenCode configuration and untracked SSH alias bytes, index and HEAD.
- [x] F01 Add comparison regressions, observe safe focused failure, then fix
  algorithm-scoped comparison and normalize source.
- [x] F02 Run all seven required foreground checks, record exact outcomes and
  preservation proof, then re-mirror and read back the complete document.
- Rollback: remove only this correction section, algorithm comparison changes,
  and its regression fixture additions; preserve prior behavior and snapshots.
- Relative locator: `odd/tasks/connect-ssh-onboarding.md`.
  Full-document mirror: `odd/connect-ssh-onboarding/tasks` (Engram #2425).

### Correction evidence

- Regression-first command:
  `PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/container-connect-test.py`:
  expected pre-fix exit 1, `AssertionError: ('mixed algorithms', False)`.
  The bounded timeout control passed (0.753s); no configured strict TDD claimed.
- Normalization: `shfmt -w .taskfiles/scripts/container-connect.bash` passed
  before final functional checks; Python additions use existing formatting.
- Post-fix focused Python command passed: ten new plain/hashed cases and all
  retained controls; bounded timeout 0.752s, SIGKILL reaped, no live child.
- Final foreground commands all passed:
  - `PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/container-connect-test.py`:
    ten new cases plus retained controls; timeout 0.753s, child reaped.
  - `bats .devcontainer/test/unit/container-connect.bats`: 1/1 wrapper test.
  - `bash -n .taskfiles/scripts/container-connect.bash`: no diagnostics.
  - `shellcheck -s bash .taskfiles/scripts/container-connect.bash .devcontainer/test/unit/container-connect.bats`:
    no diagnostics; historic K06 concerns other fixtures and is unchanged.
  - `shfmt -d .taskfiles/scripts/container-connect.bash .devcontainer/test/unit/container-connect.bats`:
    no differences.
  - `markdownlint-cli2 --no-globs odd/tasks/connect-ssh-onboarding.md`:
    1 input file, 0 issues.
  - `git diff --check`: no diagnostics.
- Preservation: before/after SHA-256 matched for unrelated OpenCode bytes
  (`5a66faf62c1128715531023faa4491ba2beab636a4a7bfc6994aaf3b4f67cd93`)
  and untracked SSH alias target bytes
  (`f296eaa560a6135621163e71c763492b909ef49f0ddb424ec763c0ee7cbb9f4a`);
  alias remains `../available/4000-tool-ssh.sh`. Raw index hash remains
  `c7fd9a874da9153fafb22ef1cdc9a755c313bac3b516f409b0845dcabe2ba342`;
  HEAD unchanged and cached diff empty. Nothing staged or committed.
- Runtime boundary: local PTY harness only. Actual SSH authentication, agent
  responsiveness, consumer trust, Docker/build/lifecycle and publication remain
  unverified and forbidden. No native review; parent owns subsequent review.
