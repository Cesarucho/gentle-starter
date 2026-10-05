# Standardize tool-test contracts incrementally

**Completed:** shared policy probes and closed npm installer contracts, STT-01–09.
Latest independent focused proof: **44/44 PASS**. This is unit-contract evidence,
not installed-tool, browser, ownership, image, or runtime health proof.

Current implementation boundary: `08831698b80e91a7e4415b0199530690aef35c3f`,
branch `test/gentle-shell-v4`. Local commit identities were verified for this
editorial update. Test and native outcomes below are previously observed evidence
supplied by the parent, not reruns or newly queried receipts.

## Objective and scope

Reduce duplicated policy invocation and npm fixture plumbing while preserving
each tool's actual installer contract, assertions, case coverage, and exceptions.
Do not replace provider-specific fixtures with a universal framework.

- Shared helpers own invocation, sandboxing, and raw command capture; consumers
  own descriptors, rejecting dispatch callbacks, adapters, and assertions.
- Installer behavior, policy ownership, activation, config, and runtime state
  remain unchanged. No production fix is part of this feature.
- TDD is ON by explicit user consent for implementation, using Bats. Genuine
  fixture RED and characterization GREEN are distinct; never manufacture RED.
- This shortening is documentation-only: no tests, native review, source edits,
  staging, commits, branches, push, PR, network, Docker, or installation actions.

## Completed work units

| Task | Outcome | Local commit(s) |
| --- | --- | --- |
| STT-01 | Shared explicit version-policy invocation; retained Phase 3A and missing-lock assertions | `8e5b43e` |
| STT-02 | Shared isolated npm fixture; Shell and contracts consumers preserve raw argv and tool distinctions | `478618b` |
| STT-03 | HOME advisory investigated and closed as false positive; source change N/A | No fix commit; closure documented in later cleanup |
| STT-04 | Phase 3C-A helper migration, proven policy overlap removal, combined Pi presence/executable signals | `1f4ac07` |
| STT-05 | pnpm migration with guarded fixture-local ownership requests and rejecting dispatch | `eb2bc94` |
| STT-06 | markdownlint and Dev Container CLI prerequisite/reuse/install/failure contracts | `9fa4f81` |
| STT-07 | Vitest and Skills distinctions, Node isolation, direct/root npm and probe assertions | `3209c52` |
| STT-08 | Pi exact package/flags, prerequisites/reuse/probes and swallowed-failure characterization | `9876ff2` |
| STT-09 | Mermaid private prefix, render/failure/safety contracts and remapped-wrapper argument coverage | `7cf1491`, `0883169` |

STT-03 needed no hardening or negative control: setup already exported the same
fixture HOME that the child runner used. The advisory omitted unchanged setup.
STT-04 retained the Shell root-adapter signal and all eight Phase 3C-A rows per loop.

## Relevant files and fixture pattern

- [Policy helper](../../.devcontainer/test/helpers/version-policy.bash) and
  [contract tests](../../.devcontainer/test/unit/version-policy-helper.bats):
  explicit installer/policy paths and env arguments; retain Bats status/output/lines.
- [npm fixture](../../.devcontainer/test/helpers/npm-fixture.bash) and
  [contract tests](../../.devcontainer/test/unit/npm-fixture-helper.bats):
  fixture HOME/TMPDIR, `env -i`, reserved-key rejection, serial NUL-delimited argv
  capture, and fail-closed dispatch. Trusted callbacks are not a security sandbox.
- Consumers: [Shell](../../.devcontainer/test/unit/gentle-shell.bats),
  [contracts](../../.devcontainer/test/unit/node-contracts.bats),
  [pnpm](../../.devcontainer/test/unit/pnpm.bats), and the
  [five-tool npm matrix](../../.devcontainer/test/unit/npm-installers.bats).
- [Mermaid suite](../../.devcontainer/test/unit/mermaid-installer.bats): exact
  request whitelists and fixture-only fixed-path mapping; separate for readability.
- Policy consumers: [common](../../.devcontainer/test/unit/common.sh.bats) and
  [tool policy](../../.devcontainer/test/unit/tool-policy.bats). Cleanup also touches
  [updater tests](../../.devcontainer/test/unit/tools-update.bats) and
  [Pi integration assertions](../../.devcontainer/test/integration/tools.bats).

For another npm consumer: load the shared helper, set up a Bats-local root,
source its runtime in local stubs, define a rejecting `npm_fixture_dispatch`,
and pass explicit tool controls to `run_npm_fixture`. Do not add a second recorder
or sandbox, normalize raw argv, discover a catalog, or source an installer.

## Recorded verification

As of implementation HEAD `0883169`, latest independent evidence totals **44/44**:
16 Pi/npm matrix cases + 13 Mermaid cases = 29; both helper suites = 10;
selected policy cases = 5. Exit 0 for all three Bats invocations; each had an
outer `120000ms` timeout. These commands are recorded evidence, not commands run
during this editorial update:

```bash
bats .devcontainer/test/unit/npm-installers.bats .devcontainer/test/unit/mermaid-installer.bats
bats .devcontainer/test/unit/npm-fixture-helper.bats .devcontainer/test/unit/version-policy-helper.bats
bats --filter 'Phase 3A|Phase 3C-A|installer fails closed when required lock data is missing' .devcontainer/test/unit/common.sh.bats .devcontainer/test/unit/tool-policy.bats
```

No unfiltered network-capable common/updater suite, broader integration, build,
or lifecycle proof is implied. The archive retains exact earlier baselines,
RED/GREEN sequences, restored oracle controls, and per-unit checks.

## Native review and delivery boundaries

All listed local commits received owner approval. Native outcomes are scoped,
approved and acknowledged; authority is burned and cannot be reused:

| Reviewed slice | Consumed transaction |
| --- | --- |
| STT-02 npm fixture | `review-29298acad71abd58` |
| STT-04/05, exact pnpm candidate tree at `eb2bc94` | `review-3b9a42423b0dbc16`; wrong-host session explicitly abandoned first |
| Combined STT-06/07 medium slice through `3209c52` | `review-66d4de6a5596e67c` |
| Combined STT-08/09 through `0883169` | `review-b5e955560543828b` |

STT-01 has no claimed standalone native coverage. Last acknowledged reviewed
boundary is `0883169`. The final combined review target is
`sha256:95916a183a0b2d80c059d032f98e112874e861822de4bdd0cc60d1a9eae1cf27`;
consumed revision is
`d648f0bebda835c46fdc3ab8f2f5c4882c24f36065f11fea5b154078adb617a1`.
No receipt was recreated or queried for this update. Native approval does not
authorize a push, PR, new branch, or this documentation commit.

## Limits and pending follow-ups

- Pi is intentionally absent in the current environment; the earlier integration
  lookup failure was reported, not repaired or relabeled PASS.
- Pi's unchanged installer can exit 0 after failed/missing `--version` probes,
  including mocked npm success without a CLI. This known gap is characterized,
  not fixed; any production correction needs separate authorization.
- Mermaid renders are synthetic. Ownership/mode operations are mocked requests;
  generated config bytes and fixture modes are checked. Only two absolute paths
  are remapped in a wrapper copy; the original absolute wrapper is never executed.
- Actual Pi installation, browser/render integration, real ownership, and image/
  runtime proof remain outside unit scope and require separate authorization.
- Pending now: owner review/approval of this documentation-only diff. No new
  implementation requirements are accepted by this summary.

## History, rollback, and future planning

The [complete historical ledger](archive/standardize-tool-tests-0883169.md) is an
exact 1,022-line attachment from HEAD `0883169`, not a second feature or plan.
Its historical PENDING labels and old authority statements are superseded by this
current status; preserve the attachment unchanged. Historical Engram observations
remain intact; the current short document is mirrored at topic
`odd/standardize-tool-tests/tasks` in project `gentle-starter`.

Editorial rollback: restore the main document from the exact archive and remove
only this newly added attachment. Implementation rollback remains bounded by each
task's test/helper hunks and dependency relationships, never production state.
Future `feature-branch-chain` slicing is planning only, not authorization to create
branches or PRs. Preserve readable safety coverage rather than compressing it to
fit the advisory 400-line budget; detailed historical proposals remain archived.

## Authorized preparation: STT-10 and STT-11

This appended plan supersedes the earlier "no new implementation requirements"
statement only for the two tasks below; completed work and history stay unchanged.
Preparation HEAD: `c3a1534be498c4818ac64ab1f2498ca248593b82`, branch
`test/gentle-shell-v4`; the worktree was clean before this append.

**Explicit user authorization:** test-only implementation, TDD ON, with Bats as
the explicitly selected runner. No installer or production common-helper changes.
No real apt, sudo, network, Docker, staging, or commits. This step updates only
this document and its existing full Engram mirror; no source changes yet.

Routing: delegated preparation/writer for multiple nontrivial files, followed by
bounded implementation and independent verification. This preparation agent must
not launch child agents. Routing is a future handoff, not evidence of execution.

### STT-10 — Closed shared APT fixture and self-tests

- [ ] Implement `.devcontainer/test/helpers/apt-fixture.bash` and
  `.devcontainer/test/unit/apt-fixture-helper.bats` as one cohesive test work unit.
- [ ] Own isolated HOME/TMPDIR, explicit installer invocation, clean environment,
  reserved-key rejection, serial raw NUL-delimited argv capture, and rejecting
  dispatch. Consumers own tool descriptors, mocks, adapters, and assertions.
- [ ] Close command dispatch: reject unknown commands/arguments, never fall through
  to host apt/sudo or inherited PATH; all mutation remains fixture-local. Trusted
  callbacks are not a security sandbox. Do not source an installer in the test shell.
- [ ] Write genuine failing helper tests first, then prove GREEN, including unsafe
  overrides, unexpected requests, isolation, capture fidelity, and failure propagation.

Rollback boundary: only the new helper and its self-test file, before consumers
depend on it. Runtime harness: N/A for real installation; fixture execution is
the unit boundary, not proof of installed binaries or container health.

### STT-11 — Graphviz and Ansible shared installer contracts

- [ ] Add `.devcontainer/test/unit/apt-installers.bats`, consuming STT-10 without
  a second recorder or sandbox. Execute unchanged installer scripts via the fixture.
- [ ] Characterize reuse, default and overridden package, ordered update/install,
  exact `install -y --no-install-recommends` argv, update/install failures, and
  missing post-install CLI. Reuse must issue no APT request.
- [ ] Preserve distinctions: Graphviz uses `dot -V` with stderr merged; Ansible
  uses `ansible --version` and logs its first line. Cover both reuse and installed
  probe paths, including observed failure behavior without assuming stricter exits.
- [ ] Keep characterization GREEN separate from genuine helper RED; report existing
  production gaps rather than fixing installers or `.devcontainer/install/lib/common.sh`.

Inspected sources: `.devcontainer/install/available/5020-cli-graphviz.sh` and
`.devcontainer/install/available/6000-cli-ansible.sh`. Both use the production root
adapter for APT requests; fixture adapters must intercept those requests locally.
Rollback boundary: only the new consumer suite; STT-10 remains independently useful.
Runtime harness: N/A for real APT execution, explicitly outside authorization.

### Verification and review forecast

Exact planned source checks, not run during this documentation-only preparation:

```bash
bats .devcontainer/test/unit/apt-fixture-helper.bats .devcontainer/test/unit/apt-installers.bats
bash -n .devcontainer/test/helpers/apt-fixture.bash
shellcheck .devcontainer/test/helpers/apt-fixture.bash
shfmt -d .devcontainer/test/helpers/apt-fixture.bash
```

Focused editorial checks (also required after implementation):

```bash
markdownlint-cli2 --no-globs odd/tasks/standardize-tool-tests.md
git diff --check
```

Forecast: three new nontrivial test files plus this document; approximately
350–650 authored changed lines across two dependent work units, with low confidence
until implementation. Expect local unit/static checks in seconds to a few minutes;
use an explicit 120000ms outer timeout per focused invocation and report timeout
as incomplete proof. No downloads, builds, or installation costs are authorized.
The 400-line threshold is review advice, not an acceptance cap: retain readable
safety cases and report actual size rather than compressing coverage to fit.

No commit is planned pending owner review and explicit approval of the reviewed
diff. Work-unit skill commit advice does not override this boundary. Native review,
branches, PRs, and remote operations are not authorized by this preparation.
Task count: **11 total, 9 completed, 2 pending**; no new test result is claimed.
Preparation rollback: remove only this appended section and reconcile the mirror;
do not restore the historical archive or remove it for this change.

### Observed implementation: STT-10

STT-10 implemented locally, uncommitted. Helper tests were written before the
helper: `bats .devcontainer/test/unit/apt-fixture-helper.bats` exited 1 with
`not ok 1 bats-gather-tests` (missing helper). This is genuine missing-implementation
RED, not six executed assertion failures. After implementation the same command
exited 0, **6/6 PASS**; expected missing-command probes emitted Bats BW01 warnings.
Closed PATH exposes only fixture stubs and read-only `dirname`; direct child Bash
preserves installer errexit. Full final checks and STT-11 remain pending.

### Observed implementation: STT-11 and final verification

STT-11 implemented locally in `.devcontainer/test/unit/apt-installers.bats`.
Its first characterization run was GREEN: **9/9 PASS**, exit 0, against byte-equal
installer copies (`cmp` in each setup). No artificial production RED was introduced.
Both tools swallow failed version probes in logging on reuse and installation;
direct fixture probes exit 43 while installers exit 0. This is characterized,
not repaired. Graphviz stderr and Ansible first-line logging remain distinct.

Observed commands, each foreground with explicit `120000ms` outer timeout:

| Command | Exact result |
| --- | --- |
| `bats .devcontainer/test/unit/apt-fixture-helper.bats` | RED exit 1 (missing helper), then GREEN exit 0, 6/6 |
| `bats .devcontainer/test/unit/apt-installers.bats` | Exit 0, 9/9 |
| `bats .devcontainer/test/unit/apt-fixture-helper.bats .devcontainer/test/unit/apt-installers.bats` | Exit 0, 15/15 after helper format normalization |
| `bats .devcontainer/test/unit/npm-fixture-helper.bats .devcontainer/test/unit/npm-installers.bats .devcontainer/test/unit/mermaid-installer.bats` | Exit 0, 34/34 |
| `bash -n .devcontainer/test/helpers/apt-fixture.bash` | Exit 0 |
| `shellcheck .devcontainer/test/helpers/apt-fixture.bash` | Exit 0, no findings |
| `shfmt -d .devcontainer/test/helpers/apt-fixture.bash` | Exit 0, no diff after `shfmt -w` |
| `markdownlint-cli2 --no-globs odd/tasks/standardize-tool-tests.md` | Exit 0, 0 issues |
| `git diff --check` | Exit 0 |

APT suites emit BW01 warnings for deliberately asserted exit-127 absent commands;
these are reported, not suppressed. No real APT, sudo, network, Docker, install,
or broad suite ran. Trusted callbacks and explicit fixture-local chmod are not
a hostile-code sandbox. Unit execution is not installed-tool/runtime health proof.

The preparation checkboxes and pending count above are historical forecasts,
superseded by these outcomes: **11 total, 11 implemented**, awaiting owner review.
STT-10 rollback removes its helper/self-tests only after removing the dependent
STT-11 suite; STT-11 rollback removes only its consumer suite. Production installers,
common helper, and policy have no differences. No staging, commits, branches, push,
PR, or native approval is claimed. Parent owns subsequent native RDD handling.

### STT-12 — Distinguish zero arguments from one empty argument

Next authorized task: test-only recorder advisory fix, TDD ON with explicit Bats.
Record bare `apt-get` as an existing empty file with zero decoded entries, and
`apt-get ""` as exactly one NUL with one empty entry. Verify dispatch argc 0/1
and serial calls. Write the assertion test first and observe RED before changing
the helper; then create captures unconditionally and print only when argc > 0.
No root canonicalization, callback split, production edits, child agents, network,
real apt/sudo, Docker, staging, commits, or native review are authorized.
Prior `review-c14c4a76232cd0e1` authority is burned for its previous exact target;
the parent handles new-candidate native risk without reusing that lineage.

Status: **12 total, 12 implemented, awaiting owner review**. Required foreground checks
each use `120000ms`: focused APT suites, npm/Mermaid regression, helper syntax,
ShellCheck, shfmt (normalize before final checks), ledger markdownlint, diff check.
Rollback: only STT-12 helper/test hunks and this appended tracking section;
preserve STT-10/11 files and history. Runtime harness: N/A, real installation is
outside authorization; local fixture execution is the unit boundary.

Observed STT-12 evidence (each invocation foreground, outer `120000ms`):

| Check | Exact result |
| --- | --- |
| `bats --filter 'distinguishes zero arguments from one empty argument' .devcontainer/test/unit/apt-fixture-helper.bats` | RED exit 1, 0/1: line 42 `[ ! -s "${APT_FIXTURE_CALLS}/1" ]` failed; after minimal fix GREEN exit 0, 1/1 |
| Focused APT command listed above | Exit 0, 16/16 (7 helper + 9 installer); expected BW01 absent-command warnings |
| npm/Mermaid regression command listed above | Exit 0, 34/34 |
| Helper `bash -n`, `shellcheck`, `shfmt -d` | Each exit 0; no findings/diff after `shfmt -w` |

The new test proves zero bytes/zero entries versus exactly one NUL/one empty
entry, dispatch argc 0/1, and serial files 1/2 with no third call. No refactor
was needed. Only the recorder guard, one self-test, and this tracking section
changed; the consumer suite and all pre-existing authorized work are preserved.
Final ledger `markdownlint-cli2 --no-globs odd/tasks/standardize-tool-tests.md`
exited 0 with 0 issues; `git diff --check` exited 0. Mirror #2611 preserves the
full ledger at `odd/standardize-tool-tests/tasks`; readback verifies this section.

## Authorized remaining APT workflows

Current authorization supersedes earlier preparation-only limits for test work:
all nine remaining workflows are authorized; STT-19 is the current execution slice.
Verified starting HEAD: `14fb163bfa19c9cc59040d7c07e34d8977bc618b`,
branch `test/gentle-shell-v4`, clean worktree. Production installers, common,
policy, and the Graphviz/Ansible dispatcher remain unchanged.

| Batch | Workflow tasks | Status |
| --- | --- | --- |
| STT-13 | SSH client build; PulseAudio utils build; SSH server BUILD branch only | Implemented, awaiting owner review |
| STT-14 | Node NodeSource bootstrap | Implemented, awaiting owner review |
| STT-15 | Glow repository and key writes | Implemented, awaiting parent review |
| STT-16 | PHP PPA and Composer | Implemented, awaiting parent review |
| STT-17 | PHP debug direct INI paths | Implemented, awaiting parent review |
| STT-18 | Graphify venv and pip | Implemented, awaiting parent review |
| STT-19 | Mermaid APT failure coverage, preserving existing coverage | Implemented, awaiting parent review |

Chosen route: delegated implementation/preparation for multiple nontrivial tests;
no child agents. TDD ON by explicit user authorization; exact runner: Bats.
Characterization may begin GREEN; new fixture safety assertions must prove actual
assertion RED before implementation. Native review remains parent-owned.
No staging or commits until owner approval of the reviewed diff; no push, PR,
remote delivery planning, real APT/sudo/network/Docker, or broad suites.

STT-13 uses a separate phase-aware consumer suite, shared closed environment/PATH
and raw NUL capture. All mutations are fixture-local. Forecast: approximately
250–400 authored lines, seconds to minutes, zero downloads/builds. The 400-line
threshold is advisory, never a reason to omit safety or compress code.

Exact safe checks, each foreground with outer `120000ms`:

```bash
bats .devcontainer/test/unit/apt-build-installers.bats
bats .devcontainer/test/unit/apt-build-installers.bats .devcontainer/test/unit/apt-fixture-helper.bats .devcontainer/test/unit/apt-installers.bats
bats .devcontainer/test/unit/npm-fixture-helper.bats .devcontainer/test/unit/npm-installers.bats .devcontainer/test/unit/mermaid-installer.bats
```

Normalize any new Bash helper before final `bash -n`, `shellcheck`, and `shfmt -d`.
Also run ledger `markdownlint-cli2 --no-globs` and `git diff --check`.
Rollback: remove only the new build consumer/helper and this appended tracking;
retain all prior suites. Real runtime harness N/A: this is unit build-branch
contract proof, not installation, server startup, audio, or container health.

### Observed STT-13 outcome

Added `.devcontainer/test/unit/apt-build-installers.bats` and the consumer-only
`.devcontainer/test/helpers/apt-build-consumer.bash`. Reused the shared APT helper
unchanged. All three installer copies are byte-compared in setup. Existing
compose-manifest success tests and SSH ownership/startup runtime tests were read,
not changed or run; new coverage adds closed safety and failure contracts.

The exact focused Bats command above first executed three safety tests against
minimal fixture stubs: exit 1, **0/3**, each failing `[ "$status" -eq 98 ]`
(lines 38, 51, 61). After implementing rejecting root/phase/ordered dispatch,
the same command passed **3/3**. Added unchanged-installer characterization
started GREEN honestly: focused final **8/8**, combined APT **24/24**,
npm/Mermaid regression **34/34**, all exit 0 with outer `120000ms`.

Exact requests: `update -qq`, then `install -y -qq` with only the selected package.
Update status 41 prevents install; install status 42 prevents false success.
Client/Pulse runtime is a silent zero-call noop; server runtime is never executed.
Unknown commands/argv/packages/order reject; ambient runtime CLIs are unavailable.
Expected BW01 warnings come from asserted exit-127 absence probes, not failures.

Initial ShellCheck found SC1090 for the dynamic shared runtime source; added the
standard `source=/dev/null` directive. Final static/editorial checks are recorded
below after execution. Remaining six workflows stay pending in distinct batches;
their provider/path adapters require inspection and assertion-first safety tests,
not an assumed universal dispatcher. No later batch was implemented.

Final commands (foreground, outer `120000ms`), each exit 0:

```bash
shfmt -w .devcontainer/test/helpers/apt-build-consumer.bash
bash -n .devcontainer/test/helpers/apt-build-consumer.bash
shellcheck .devcontainer/test/helpers/apt-build-consumer.bash
shfmt -d .devcontainer/test/helpers/apt-build-consumer.bash
markdownlint-cli2 --no-globs odd/tasks/standardize-tool-tests.md
git diff --check
```

No ShellCheck findings or formatting diff; markdownlint reports 0 issues.
Git status contains only the two new test files and this ledger (unstaged).
Production tree/shared APT helper/Graphviz-Ansible suite diff is empty.
Mirror #2611 is updated in full at the existing topic, then read back.

### Observed STT-14 outcome

Added `.devcontainer/test/helpers/apt-node-consumer.bash` and
`.devcontainer/test/unit/apt-node-installer.bats`; installer copies are byte-equal.
The separate NodeSource consumer reuses shared closed invocation and APT capture.
Root `bash -` consumes a literal inert payload as data; no shell is launched,
and the payload marker never runs. Exact locked-major URL, bootstrap argv,
bootstrap-before-install state, and sole APT install argv are asserted.
No explicit APT update exists in the unchanged installer; none is invented.

Genuine safety assertion RED: focused Bats exit 1, **0/1**, line 30
`[ "$status" -eq 98 ]` against a minimal root callback. Implemented fixture
then passed; characterization first ran GREEN **11/11**, final **12/12**.
Combined Node/build/helper/Graphviz-Ansible suites: exit 0, **36/36**.
npm/helper/Mermaid regression: exit 0, **34/34**. Each invocation was foreground
with outer `120000ms`. Expected BW01 warnings reflect direct exit-127 probes.

Initial ShellCheck failed SC2034/SC2016; documented installer-consumed policy
state and deliberately literal payload directives resolve those findings.
After normalization, `bash -n`, `shellcheck`, and `shfmt -d` each exit 0.
Final ledger markdownlint exits 0 with 0 issues; `git diff --check` exits 0.
Final checks PASS. Intentional assertion RED and corrected initial lint findings
remain development history, not pending failures or a partial final outcome.

Observed gaps: existing Node is reused even on major mismatch; reuse and final
logging swallow failing/missing Node/npm probes. Policy failure stops before
reuse. Bootstrap/APT failures stop installation/success respectively. Curl
failure yields fixture pipeline status 98 because its consumer rejects empty
input; this is not a claim about downloaded NodeSource script behavior.
No explicit prerequisite helper is called. Existing central-policy matrices
already cover policy resolution/override; this consumer does not duplicate them.
Product corrections need separate authorization; none were chosen or applied.

Rollback removes only the Node helper/suite and STT-14 ledger changes.
Real runtime harness N/A: no installation or NodeSource downloaded-script proof.
SSH/Pulse work and all five later pending batches remain unchanged. Parent owns
risk/consent. Previous SSH/Pulse+Node native review was approved and acknowledged:
`review-fe406336960d9de3`, target `b22e495...`, consumed revision
`95aa3d84c5678fb461cc3bdd4e2f0c068c02cc8b60abc18acbf525d1d124365d`.
Authority is burned; no-npm reuse advisory is a nonblocking follow-up, with no
change authorized in this batch. These are parent-supplied receipts, not queries.

### STT-15 — Authorized Glow-only implementation

Historical preparation before source writes; completed outcome follows. Preserve SSH/Pulse+Node uncommitted files.
Use the unchanged shared APT fixture and byte-equal Glow installer copy; intercept
all root requests as inert data, never execute the nested repository shell text.
TDD Bats ON: assertion-first safety RED, then GREEN and characterization.
No production/common/installer edits, staging, commits, network, real APT/sudo/gpg,
downloaded shell, Docker, or child agents. Native review remains parent-owned.
PHP, PHP debug, Graphify, and Mermaid batches remain pending.

### Observed STT-15 outcome

Added `.devcontainer/test/helpers/apt-glow-consumer.bash` and
`.devcontainer/test/unit/apt-glow-installer.bats`. Shared APT plumbing is unchanged.
The root adapter validates exact argc, raw arguments, independent multiline script
literal, operands, and six-stage ordering before recording NUL-delimited requests.
The repository script is never evaluated or sourced; mkdir and repository writes
produce fixture markers only. No `/etc` write, curl, gpg, or nested shell executes.

Focused command `bats .devcontainer/test/unit/apt-glow-installer.bats` first exited
1, **0/1**, with a real line-27 assertion failure `[ "$status" -eq 98 ]` against
a minimal root callback, not a load failure. After implementation it exited 0,
**11/11**. Final checks PASS; expected RED is retained as development evidence.

Exact final commands, foreground with outer `120000ms` per invocation:

```bash
bats .devcontainer/test/unit/apt-glow-installer.bats
bats .devcontainer/test/unit/apt-glow-installer.bats .devcontainer/test/unit/apt-node-installer.bats .devcontainer/test/unit/apt-build-installers.bats .devcontainer/test/unit/apt-fixture-helper.bats .devcontainer/test/unit/apt-installers.bats
bats .devcontainer/test/unit/npm-fixture-helper.bats .devcontainer/test/unit/npm-installers.bats .devcontainer/test/unit/mermaid-installer.bats
shfmt -w .devcontainer/test/helpers/apt-glow-consumer.bash
bash -n .devcontainer/test/helpers/apt-glow-consumer.bash
shellcheck .devcontainer/test/helpers/apt-glow-consumer.bash
shfmt -d .devcontainer/test/helpers/apt-glow-consumer.bash
markdownlint-cli2 --no-globs odd/tasks/standardize-tool-tests.md
git diff --check
```

Results: focused **11/11**, combined APT **47/47**, npm/Mermaid **34/34**;
all exit 0. Syntax, ShellCheck, formatting, and editorial checks exit 0 with no
findings/diff; expected BW01 warnings reflect deliberately asserted exit 127.

Coverage includes four exact APT requests, repository between calls 2/3, reuse
with zero root/APT requests and one first-line probe, defaults/explicit overrides,
six distinct synthetic stage failures (41–46), absent CLI exit 1 with no probe,
and swallowed failed/missing probes on install/reuse with direct status proof.
Keyring override alone preserves the default repository signed-by value.
Hostile/altered script, argc, delimiter, shell spelling, operands, packages,
command order, and executable fallback are rejected without execution.

Limitations: synthetic repository-stage failure is not real curl/gpg pipeline
proof. Trusted callbacks are not a hostile-code sandbox; real installation and
runtime harness are N/A outside authorization. No production fixes or native
review ran. PHP, PHP debug, Graphify, and Mermaid remain pending.
Rollback removes only the two Glow files and STT-15 ledger hunks; preserve all
SSH/Pulse+Node and shared fixture work. Full mirror #2611 is reconciled/read back.

### STT-16 — PHP PPA and Composer

Historical preparation before source writes; observed outcome follows. All remaining APT scope is authorized; this
slice executes PHP tests only. Preserve uncommitted build/Node/Glow work.
TDD ON with explicit Bats; shared APT transport and production files stay unchanged.
Exact callbacks remap only `/tmp/composer-setup.php` to fixture-local inert bytes;
root PHP records the request without executing downloaded code or writing `/usr`.
No real APT/sudo/network/Docker, staging, commits, remote work, or child agents.
PHP debug STT-17, Graphify STT-18, and Mermaid STT-19 remain pending.

### R3-node-reuse-npm-proof — Authorized follow-up

Separate explicitly authorized test-only follow-up, not a native correction.
Prior `review-200204f1a8f3d78b` was approved, acknowledged, and burned; never reuse
its authority. Parent owns review; no review invocation is authorized here.
Route: delegated implementation of two nontrivial files, no child agents.
TDD ON, explicit runner Bats: add assertions, observe assertion RED, then implement.
Scope: Node consumer npm adapter, Node suite, this ledger and full mirror #2611.
Append raw NUL argv before availability/failure checks; prove no npm on either
reuse major and exactly `--version` on successful installation. Preserve local
oracles/all 12 tests. No production, installation, network, Docker, staging,
commits or remote work. Rollback only these hunks; runtime harness N/A.
Explicit checks foreground `120000ms`: Node Bats RED 11/13, exit 1 (argv assertions
49/74, not load failure), GREEN 13/13, exit 0; npm/Mermaid regression 36/36, exit 0.
New test proves append through unavailable/failing npm (127/43). Isolation inspected.
Helper already normalized; bash syntax/ShellCheck/shfmt and ledger markdownlint/
diff checks exit 0. Expected BW01 warnings. Implemented; parent review pending.

### STT-20 — Shared raw argv assertion

Authorized narrow test-only consolidation across seven APT suites; delegated
multi-nontrivial-file route, no child agents. TDD ON, explicit runner Bats.
Objective: measurable net physical source-line reduction including helper,
imports and positive/negative self-tests, retaining all 75 installer declarations
and local expected vectors/callbacks. Baseline seven suites: 1,399 lines.
No production, fixture/callback centralization, npm/Compose/Mermaid migration,
real APT/sudo/network/Docker, staging, commits or remote operations.
Foreground checks use outer `120000ms`; no downloads or builds. Rollback only
STT-20 assertion/import/call-site hunks, new helper/self-tests and this section.
Runtime harness N/A: local synthetic unit contracts only.

Parent-supplied previous candidate `0ebb72f376b4ef488f0da1f3512fb25f4b9fedfa`,
final review `review-ea75d4b5eba9b309`, approved/acknowledged and burned revision
`08406fbb315e8756f9e80e256bb0c50ef7b4e59afbff454816b7996b0a5cca48`.
Changed bytes require a new candidate and parent-owned review; no receipt reuse.
Status: **20/20 implemented**, STT-20 awaiting parent review; historical pending
labels are superseded. Loaded clean-code, cognitive-doc-design and work-unit-commits;
explicit no-commit authorization overrides skill commit advice.

Observed assertion TDD command: `bats .devcontainer/test/unit/argv-assertions.bats`.
RED exit 1, **1/3** against a loadable return-zero stub: real failures at line 32
(extra argument accepted) and line 39 (missing file accepted), not load failures.
GREEN exit 0, **3/3**, including final expanded zero/empty and truncated-tail checks.
Helper guards immediately return nonzero on missing/read failure, unterminated
tail, count or element mismatch, including conditional invocation. Raw spaces,
backslashes, multiline values, order and local independent vectors remain intact.

Migration: all 46 call sites directly use `assert_recorded_argv`; no wrappers.
Exact declarations remain **75 before/after**: 9 + 8 + 12 + 11 + 11 + 11 + 13.
Seven suite lines: **1,399 → 1,329** (each loses 10). Removed 77 duplicated
physical lines including separator blanks; added 7 imports, 16 helper lines and
50 self-test lines: **1,399 → 1,395**, net source reduction **4 lines**.
Call-site renames change no line count. Ledger tracking is separate: **+57 lines**;
this is not a total-repository reduction claim. Existing 14-path work is retained.

Final foreground proof, outer `120000ms` each, all exit 0:

```bash
bats .devcontainer/test/unit/apt-installers.bats .devcontainer/test/unit/apt-build-installers.bats .devcontainer/test/unit/apt-node-installer.bats .devcontainer/test/unit/apt-glow-installer.bats .devcontainer/test/unit/apt-php-installer.bats .devcontainer/test/unit/apt-php-debug-installer.bats .devcontainer/test/unit/apt-graphify-installer.bats .devcontainer/test/unit/apt-fixture-helper.bats .devcontainer/test/unit/mermaid-installer.bats .devcontainer/test/unit/argv-assertions.bats
bats .devcontainer/test/unit/npm-fixture-helper.bats .devcontainer/test/unit/npm-installers.bats .devcontainer/test/unit/mermaid-installer.bats
bash -n .devcontainer/test/helpers/argv-assertions.bash
shellcheck .devcontainer/test/helpers/argv-assertions.bash
shfmt -d .devcontainer/test/helpers/argv-assertions.bash
markdownlint-cli2 --no-globs odd/tasks/standardize-tool-tests.md
git diff --check
```

Combined **100/100** = existing 97 + 3 self-tests; regression **36/36**.
Final expanded self-tests separately reran **3/3**. Helper normalized before
static checks; no findings/diff. Expected BW01 warnings are asserted exit-127
probes, not pending failures. Inspected rejecting fixture dispatch and bounded
remapping before execution. Production/shared transport and existing helper
declarations remain unchanged; no real installation/runtime health proof implied.
Full mirror #2611 is reconciled and read back; native review remains parent-owned.

### Final authorized APT status: STT-19

This final status supersedes historical pending labels: **19/19 tasks implemented**;
all nine authorized remaining workflows have unit coverage. Parent-owned final
candidate review and owner diff approval remain pending; no authority is reused.
Earlier uncommitted build/Node/Glow/PHP/PHP debug/Graphify files are preserved.

Extended only `.devcontainer/test/unit/mermaid-installer.bats`, retaining all 13
historical cases and the existing dedicated fixture. The closed root adapter now
returns explicit update/install statuses only after exact argument validation;
raw NUL capture, isolated HOME/TMPDIR/PATH, and shared helpers stay unchanged.
No universal APT adapter or duplicate suite was added.

Assertion-first RED: `bats .devcontainer/test/unit/mermaid-installer.bats` exited
1, **13/15**, with real status assertions at lines 206/216 failing before failure
injection existed. After two adapter returns, GREEN was **15/15**, exit 0.
The unchanged installer propagates update 41 before install and install 42 before
npm, render, prefix/config/wrapper requests or success. Tests assert ordered raw
update/install vectors, all nine original prerequisite packages and flags, absent
private CLI/config/public wrapper (including link), no user/render/version calls,
and temporary smoke cleanup. No product failure or production fix was found.

Final foreground commands, each with outer `120000ms`:

```bash
bats .devcontainer/test/unit/mermaid-installer.bats
bats .devcontainer/test/unit/apt-graphify-installer.bats .devcontainer/test/unit/apt-php-debug-installer.bats .devcontainer/test/unit/apt-php-installer.bats .devcontainer/test/unit/apt-glow-installer.bats .devcontainer/test/unit/apt-node-installer.bats .devcontainer/test/unit/apt-build-installers.bats .devcontainer/test/unit/apt-fixture-helper.bats .devcontainer/test/unit/apt-installers.bats .devcontainer/test/unit/mermaid-installer.bats
bats .devcontainer/test/unit/npm-fixture-helper.bats .devcontainer/test/unit/npm-installers.bats .devcontainer/test/unit/mermaid-installer.bats
shellcheck -s bats -e SC2030,SC2031,SC2155 .devcontainer/test/unit/mermaid-installer.bats
shfmt -ln bats -d -i 4 .devcontainer/test/unit/mermaid-installer.bats
markdownlint-cli2 --no-globs odd/tasks/standardize-tool-tests.md
git diff --check
```

Results: **15/15**, **97/97**, **36/36**, exit 0. Final scoped static/editorial
checks pass. Initial unrestricted ShellCheck exposed historical SC2155 and Bats
SC2030/SC2031 diagnostics plus two new SC2155 declarations, corrected locally;
the final command explicitly excludes the remaining historical diagnostics.
One existing loop spacing line was normalized for shfmt. No new helper exists;
`bash -n` on Bats is inappropriate and was not run. Expected combined-suite BW01
warnings are asserted exit-127 probes, not unresolved test failures.

Unit completion is not runtime health: real APT/npm/browser/render, ownership,
build/image/lifecycle and broader integration checks were not run or authorized.
Trusted fixture callbacks are not a hostile-code sandbox. Separate nonblocking
Node curl/no-npm and Composer-path advisories remain unchanged. No production,
installer/common/policy changes, system mutation, staging, commit, remote work,
native review or child agents occurred. Rollback removes only STT-19 Mermaid test
hunks and this final ledger section; retain earlier work. Full mirror #2611 is
reconciled and read back before handoff.

### Observed STT-18 outcome

Added `.devcontainer/test/helpers/apt-graphify-consumer.bash` and
`.devcontainer/test/unit/apt-graphify-installer.bats`. Before source writes, the
existing ledger and full mirror #2611 were reconciled to STT-18 in progress and
read back. Earlier build/Node/Glow/PHP/PHP debug files are preserved unchanged.
Each setup byte-compares its unchanged installer copy; no remapping is necessary.

Genuine safety RED: `bats .devcontainer/test/unit/apt-graphify-installer.bats`
exited 1, **0/1**, on line 23 `[ "$status" -eq 98 ]` against a loadable inert
root callback. After rejecting callbacks, initial characterization was GREEN
**11/11**; final focused proof is **13/13**, exit 0. Syntax, ShellCheck and
`shfmt -d` pass after normalization. Initial SC2016 findings were resolved with
a targeted directive for intentionally literal generated callback code.

Contracts cover Python presence and exact Python 3.10 gate before root requests;
policy failures before reuse; both-CLI reuse before Python with version mismatch;
either CLI alone requiring install; configurable version/install directory/bin
directory; exact ordered APT, deletion, venv, pip and two symlink vectors;
seven propagated failures; both missing executable postconditions; swallowed CLI
probe errors with direct status proof; unsafe paths, vectors and symlink rejection.
No pip upgrade or configurable distribution/APT package exists: actual requests
are `update`, `install -y --no-install-recommends python3-venv`, then one
`pip install --no-cache-dir graphifyy==VERSION`. No contracts are invented.

Final foreground checks use outer `120000ms` per invocation:

- Focused Graphify Bats: **13/13**, exit 0.
- Combined Graphify/PHP debug/PHP/Glow/Node/build/APT helper/APT installers:
  **82/82**, exit 0, in `.devcontainer/test/unit/` using the named suites.
- npm helper/npm installers/Mermaid regression: **34/34**, exit 0.
- New helper `bash -n`, `shellcheck`, `shfmt -d`: exit 0, no findings/diff.
- Ledger `markdownlint-cli2 --no-globs` and `git diff --check`: exit 0, no issues.

Safety: deletion, venv creation, pip and links are inert exact-whitelisted requests,
not filesystem/installation proof. Synthetic executable CLI callbacks are created
only inside Bats fixtures; postchecks use their executable bits. No real Python,
venv, pip, APT, sudo, network, Docker or system links execute. Partial progress is
recorded without fake rollback. Trusted callbacks are not a hostile-code sandbox.
Real installed-tool/runtime proof is N/A. Product corrections are not authorized.

Rollback removes only these two Graphify files and STT-18 ledger hunks. Mermaid
STT-19 stays pending. Parent-supplied `review-6a9ca62c27e3fdf2`, target
`5475d605...`, was approved, acknowledged and burned at revision
`0b4c6d3c619c6434aa40f20dd27f6717595070ce305ebc92716fd9b75a024374`.
It is not reused or queried. Node advisories remain separate nonblocking follow-ups.
No native review, child agent, staging, commit or remote operation ran.

### Observed STT-17 outcome

Added `.devcontainer/test/helpers/apt-php-debug-consumer.bash` and
`.devcontainer/test/unit/apt-php-debug-installer.bats`. Shared APT transport and
earlier build/Node/Glow/PHP files remain unchanged. All execution mutations stay
inside Bats temporary fixtures; no original installer execution or system write.

Safety assessment before execution: the installer directly redirects into one
fixed `mods-available/xdebug.ini` assignment, with no configurable root. Setup
transforms only that exact complete assignment line into a fixture-local root,
requires exactly one match, independently reverses the line, and `cmp` verifies
reconstruction against the original. Snapshot comparisons in setup/teardown prove
the original stays unchanged. This is remapped-copy, not byte-equal execution.
Literal heredoc stdin goes through a bounded real `cat`; independent expected
INI bytes are compared with `cmp`. No symlink targets real `/etc`.

Genuine safety RED: focused Bats exit 1, **0/1**, line 53 assertion
`[ "$status" -eq 98 ]` against a loadable inert root stub. Implemented adapters
then passed **1/1**. Initial expanded characterization was **10/11** because the
direct failure probe reused the module-count state; resetting that fixture-local
counter corrected the test setup. Final focused **11/11**, combined APT **69/69**,
npm/Mermaid **34/34**, all exit 0. No pending final failure is implied.

Contracts: PHP prerequisite and actual major/minor probes precede reuse; package
series derives from PHP, ignoring requested series. Exact APT order/flags are
`update -qq`, then `install -y --no-install-recommends php<series>-xdebug`.
Loaded-module reuse preserves INI and issues zero APT requests. Statuses 41/42
stop before INI writes; version errors propagate. Missing INI warns without
creating it; missing postinstall module exits 1 after configuration without rollback.
Failed module probes are treated as absence; a final logging probe failure is
swallowed. No CLI/FPM-specific INI writes exist: sentinel files stay unchanged.
Unknown root/package/order/PHP/grep/cat/mkdir vectors and ambient fallback reject.

Exact final commands, foreground with outer `120000ms` per invocation:

```bash
bats .devcontainer/test/unit/apt-php-debug-installer.bats
bats .devcontainer/test/unit/apt-php-debug-installer.bats .devcontainer/test/unit/apt-php-installer.bats .devcontainer/test/unit/apt-glow-installer.bats .devcontainer/test/unit/apt-node-installer.bats .devcontainer/test/unit/apt-build-installers.bats .devcontainer/test/unit/apt-fixture-helper.bats .devcontainer/test/unit/apt-installers.bats
bats .devcontainer/test/unit/npm-fixture-helper.bats .devcontainer/test/unit/npm-installers.bats .devcontainer/test/unit/mermaid-installer.bats
shfmt -w .devcontainer/test/helpers/apt-php-debug-consumer.bash
bash -n .devcontainer/test/helpers/apt-php-debug-consumer.bash
shellcheck .devcontainer/test/helpers/apt-php-debug-consumer.bash
shfmt -d .devcontainer/test/helpers/apt-php-debug-consumer.bash
markdownlint-cli2 --no-globs odd/tasks/standardize-tool-tests.md
git diff --check
```

Syntax, ShellCheck and formatting passed without findings/diff. Earlier combined
APT suites emit expected BW01 warnings for asserted exit 127; new focused suite
does not. Final ledger markdownlint reports 0 issues; `git diff --check` exits 0.
Trusted callbacks are not a hostile-code sandbox. Real runtime harness is N/A:
no real APT/sudo/network/Docker or installed-extension health proof is authorized.
Rollback removes only the two PHP debug files and STT-17 ledger hunks.
Graphify STT-18 and Mermaid STT-19 remain pending.

Parent-supplied review `review-6f013af191e7f3c4`, target `a1d632...`, was approved,
acknowledged and burned at revision
`c0b7f7dbf9de4676630746406d691ec0ba1463d73f1004953b2d24e2d16c4445`.
It is not reused or queried. Fixed Composer path clarity and Node no-npm recorder/
curl masking advisories remain separate nonblocking follow-ups. No native review,
staging, commit, remote operation, or child agent ran. Parent owns review handling.

### STT-16 historical review and implementation evidence

Parent-supplied cumulative review was approved, acknowledged, and burned:
`review-6a062b66bad15027`, target `54e1fc...`, consumed revision
`8e73448a695a8624321e5e9f18b02fc302a09b2c3f370e4bbdffce7c47b9b214`.
Do not reuse it. Node curl masked-downstream and no-npm recorder advisories are
nonblocking follow-ups, not fixes in this slice. Native review is parent-owned.

### Observed STT-16 outcome

Added `.devcontainer/test/helpers/apt-php-consumer.bash` (139 lines) and
`.devcontainer/test/unit/apt-php-installer.bats` (200 lines). Byte-equal installer
copies execute under unchanged APT transport, closed environment/PATH, and raw
NUL capture. Exact root vectors are independently authored; curl/root PHP/rm
accept only the fixed Composer operands, mapping bytes/cleanup into the fixture.
Downloaded marker stays inert; no host `/tmp` installer or `/usr` path is written.

Focused safety test first exited 1, **0/1**, line 26 assertion
`[ "$status" -eq 98 ]` against a minimal loadable root stub. Adapter implementation
then passed **1/1**. Added characterization first ran GREEN **11/11**.
Ordered requests include two `update -qq` cycles, prerequisite
`software-properties-common`, and five PHP packages with exact
`install -y --no-install-recommends` flags. Default fixture lock and explicit
series override, policy failure/missing lock, six terminating failures (41, 42,
44–47), and deliberately tolerated PPA statuses 43/127 are covered.

Observed unchanged gaps: PHP presence skips Composer even if missing and ignores
series mismatch; Composer presence alone does not skip bootstrap. No separate
prerequisite guard or Composer reuse branch exists. Failed/missing PHP/Composer
probes are swallowed by logging on installation/reuse, with direct status proof.
No production correction is chosen. Provider health and real Composer bootstrap
are not proven; trusted callbacks are not a hostile-code sandbox.

Exact final commands, foreground with outer `120000ms` per invocation:

```bash
bats .devcontainer/test/unit/apt-php-installer.bats
bats .devcontainer/test/unit/apt-php-installer.bats .devcontainer/test/unit/apt-glow-installer.bats .devcontainer/test/unit/apt-node-installer.bats .devcontainer/test/unit/apt-build-installers.bats .devcontainer/test/unit/apt-fixture-helper.bats .devcontainer/test/unit/apt-installers.bats
bats .devcontainer/test/unit/npm-fixture-helper.bats .devcontainer/test/unit/npm-installers.bats .devcontainer/test/unit/mermaid-installer.bats
shfmt -w .devcontainer/test/helpers/apt-php-consumer.bash
bash -n .devcontainer/test/helpers/apt-php-consumer.bash
shellcheck .devcontainer/test/helpers/apt-php-consumer.bash
shfmt -d .devcontainer/test/helpers/apt-php-consumer.bash
markdownlint-cli2 --no-globs odd/tasks/standardize-tool-tests.md
git diff --check
```

Results: PHP **11/11**, combined APT **58/58**, npm/Mermaid **34/34**, exit 0.
Final static/editorial checks exit 0 with no findings/diff; expected BW01 warnings
are deliberately asserted exit-127 probes. Assertion RED is development evidence,
not a pending failure. Shared fixture, production, and earlier consumers unchanged.
Rollback removes only the PHP helper/suite and STT-16 ledger hunks. Real runtime
harness N/A outside authorization. No native review, staging, or commit ran.
PHP debug STT-17, Graphify STT-18, and Mermaid STT-19 remain pending.
