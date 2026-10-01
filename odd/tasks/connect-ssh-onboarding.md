# Connect-only manual SSH onboarding

Persist manually verified GitHub host trust in optional managed `.ssh` state.
Only `task container:connect` receives a dedicated interactive startup file;
ordinary shells and all other entrypoints remain unchanged.

## Route and constraints

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
- [ ] C05 Owner reviews the unstaged diff and authorizes any later commit.

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
