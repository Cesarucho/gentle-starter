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
