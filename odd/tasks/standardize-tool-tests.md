# Standardize tool-test contracts incrementally

Standardize test-only policy probes and npm family fixtures in bounded work units.
Installer behavior, activation, policy ownership, and runtime state remain unchanged.

## Authority and current state

- Current owner approval supersedes the historical no-commit restrictions below:
  create exactly two local work-unit commits, policy probes then npm fixture.
  Native review remains pending; prior preflight is not binding or a delivery gate.
  No push, PR, branch creation, or tracker is authorized. Historical proof remains
  intact; the chosen feature-branch-chain is future review planning only.
- Repository: `/home/ubuntu/gentle-starter`.
- Verified starting boundary: `a16d34d`, branch `test/gentle-shell-v4`, clean worktree.
- STT-01's five-path diff must be preserved. Current consent continues npm
  implementation while STT-01 native review is pending; authorized paths are
  recorded under STT-02, including this document and its complete Engram mirror
  `odd/standardize-tool-tests/tasks` in project `gentle-starter`.
- No staging, commits, branch switches, Docker, network, builds, installer/config/
  policy/activation changes, new SDD artifacts, or child delegation are authorized.
- Delivery strategy: `ask-on-risk`. Commit: **PENDING explicit owner approval**.
  The accepted unstaged/uncommitted delivery overrides automatic work-unit commits.
- RDD is globally on (`/home/ubuntu/.gentle-ai/state.json`, `rdd_mode: on`).
  No review lifecycle has started; this plan is not a review receipt or delivery gate.

## Selected work unit

Choose the Phase 3A policy-resolution loops in `common.sh.bats`, plus the missing-lock
probe in `tool-policy.bats`. They already exercise the same public
`--print-version-policy` boundary. A shared invocation helper has immediate consumers
in two existing suites without reorganizing the catalog or migrating every family.

The direct-archive family already has provider-shaped archives, checksum failures,
byte/mode preservation, signal cleanup, and BATS multi-destination rollback. Its
fixtures should not be generalized into a universal provider abstraction now.
Repeated integration probes are real candidates but depend on installed tools and
selection semantics; defer them rather than widening this offline first unit.

Existing `unit/install-fixture.bash` owns activation setup. Do not overload that
helper with policy probes or replace `integration/install-selection.sh`.

## TDD evidence and execution mode

- Effective ODD TDD mode: **ON**, source: current explicit user consent,
  "Sí, usar TDD". This supersedes the preparation's unresolved mode, not configuration.
- Observe RED on new helper contract tests before adding the missing helper;
  implement minimally for GREEN, then refactor the two existing consumers.
  Do not create `openspec/config.yaml` or invoke `sdd-init`.
- Runner: installed Bats; focused commands below run existing test cases directly.
  `.maintainer/tasks/test.yml` defines broader starter Bats suites, not TDD policy.
  Root `task test` deliberately exits 2 until application tests are configured.
- Existing-test refactoring requires a passing exact focused baseline immediately
  before consumer edits. Never label that characterization baseline RED.

## Checklist

- [x] **STT-01 — Share policy probes with two existing consumers.**
  Functional implementation complete; native review pending; commit PENDING approval.
  Route: **delegated** to this bounded implementation executor by the parent;
  no child delegation is launched.
  Evidence: two nontrivial existing suites (680 and 82 lines), new helper and
  helper-contract tests, environment-isolation design, and exception preservation.
  This is not a one-file mechanical edit.
  - Scope: add `.devcontainer/test/helpers/version-policy.bash` and
    `.devcontainer/test/unit/version-policy-helper.bats`; migrate only the two
    Phase 3A loops in `.devcontainer/test/unit/common.sh.bats` and the missing-lock
    test in `.devcontainer/test/unit/tool-policy.bats`. Update this document with
    the helper's minimal onboarding example, actual verification, and diff count.
  - Helper contract: accept an explicit installer path, explicit policy path,
    and explicit environment arguments; invoke only `--print-version-policy`
    under Bats `run`, preserving `status`, `output`, and `lines`. Callers retain
    assertion ownership and specify their own unset/override variables.
  - Fixtures: use `BATS_TEST_TMPDIR` for new policy/installer fixtures; no global
    shell state, installer sourcing, eval, duplicated catalog, installer-source
    parsing, or automatic discovery. Keep case lists local to existing tests.
  - Acceptance: both existing suites actually call the helper; all current
    assertions and case coverage survive, including Playwright's two output
    lines, CLI unset behavior, environment precedence, and missing-lock message.
    Existing per-tool exceptions outside this slice remain untouched.
  - Add offline helper tests using synthetic print-policy executables for
    success, nonzero status, multiline output, unset/override propagation, and
    paths containing spaces. Do not install tools or alter production behavior.
  - Checks: rerun the exact baseline immediately before refactoring, then run
    the exact final focused commands below; record actual results, not promises.
  - Commit evidence remains PENDING; do not stage or commit without owner approval.

## Verification boundary

Read-only inspector verified by reading its complete Bash/Python implementation:

```bash
bash .agents/skills/add-tool/scripts/inspect-install-tree.sh /home/ubuntu/gentle-starter
```

Result: exit 0; 39 installers, 15 aliases, 88 policy keys; no invalid names,
duplicate prefixes/slots, broken aliases, or unsafe aliases.

Exact baseline, executed once during preparation with a 120-second outer timeout:

```bash
bats --filter 'Phase 3A|installer fails closed when required lock data is missing' .devcontainer/test/unit/common.sh.bats .devcontainer/test/unit/tool-policy.bats
```

Result: exit 0, **3/3 PASS**. The loops cover six installers per scenario.
Inspected each selected installer's pre-print path: shared policy loading and
assignments precede printing/exiting; installation paths are not reached.
Fixture writes are restricted to Bats temporary directories.

Final checks executed after all source edits:

```bash
bash -n .devcontainer/test/helpers/version-policy.bash
bats .devcontainer/test/unit/version-policy-helper.bats
bats --filter 'Phase 3A|installer fails closed when required lock data is missing' .devcontainer/test/unit/common.sh.bats .devcontainer/test/unit/tool-policy.bats
git diff --check
git diff --stat
git status --short
```

Use a 120-second outer timeout for each Bats invocation. No downloads or build
cost expected; only short-lived local subprocesses and temporary fixture files.
Do not run all of `common.sh.bats`: its fetch tests contact external URLs.
Do not substitute `test:starter`, `task validate`, integration tools, or lifecycle
tasks for this bounded proof. Runtime harness: **N/A**, test-only policy invocation;
this does not prove image build or installed-tool health.

## Forecast, risks, and rollback

- STT-01 forecast: 140–220 authored additions plus 45–75 deletions, including
  helper, contract tests, two consumers, and onboarding/evidence updates:
  **185–295 changed lines**. Preparation document is additional authored work;
  count it in the eventual delivery total rather than hiding it as generated.
- 400 changed lines per task is advisory, not permission to compress code.
  Ask on scope/risk growth or an honest over-budget forecast; do not migrate
  more families merely to justify the helper.
- Risks: ambient environment leakage, Bats `run` scope, weakened multiline
  assertions, and accidental installer execution. Explicit argument forwarding,
  synthetic fixtures, retained assertions, and print-only calls address them.
- Clean-code assessment of this slice: approximately 7/10; repeated invocation
  and source-policy extraction obscure intent. Aim for explicit readable helpers
  and retained behavioral assertions, not a generic test framework.
- Rollback boundary: remove the two new helper files and revert only STT-01 hunks
  in the two consumer suites and this document. No installer, policy, catalog,
  task-runner, activation, or runtime-state changes belong to this unit.
- Skill resolution: required exact-path `add-tool`, `clean-code`, and
  `work-unit-commits` loaded first; `cognitive-doc-design` and
  `markdown-documentation` loaded for this artifact. Classification: test-only
  refactoring preparation, not provider/provisioning change. No SDD skill invoked.

## Implementation evidence and onboarding

TDD source is current user consent, runner Bats. Observed sequence:

| Stage | Command | Observed result |
| --- | --- | --- |
| RED | `bats .devcontainer/test/unit/version-policy-helper.bats` | Exit 1; gathering fails because the helper does not exist. No helper implementation existed. |
| GREEN | Same helper-suite command after adding the helper | Exit 0; 5/5 PASS. |
| Baseline before consumer edits | Exact focused baseline above | Exit 0; 3/3 PASS, not RED. |
| Refactor/final | `bash -n .devcontainer/test/helpers/version-policy.bash` | Exit 0. |
| Refactor/final | Helper-suite command | Exit 0; 5/5 PASS. |
| Refactor/final | Exact focused baseline above | Exit 0; 3/3 PASS. |
| Final inspection | `git diff --check`, `git diff --stat`, `git status --short` | Exit 0 each; only authorized paths changed, nothing staged. |

The RED was a genuine missing-helper load failure, not five individually executed
assertion failures. Five behavior tests subsequently ran in GREEN and final checks.
No source normalization was needed: new files follow four-space test formatting,
consumer edits retain surrounding formatting. No source edits followed final checks;
only this evidence document and its mirror were updated.

Load the helper from a Bats suite and keep assertions at the call site:

```bash
load ../helpers/version-policy.bash

run_version_policy "${installer}" "${policy_file}" \
    -u PLAYWRIGHT_CLI_VERSION PLAYWRIGHT_VERSION=9.9.9
[ "$status" -eq 0 ]
[ "${lines[0]}" = PLAYWRIGHT_VERSION=9.9.9 ]
```

The helper's first two arguments are explicit paths; remaining arguments use
`env` syntax (unset options before assignments). The explicit policy path is
authoritative even if a forwarded assignment attempts to replace it. Bats results
remain in the caller; the helper never sources an installer or owns assertions.

Both existing suites now consume the helper. All existing assertions are unchanged:
six Phase 3A cases per loop, Playwright's exact multiline output and CLI unset,
environment override precedence, and missing-lock status/message. No duplicate
catalog or new source parsing was introduced. Contract tests also cover paths and
values containing spaces, nonzero exit 42, multiline `lines`, and caller isolation.

Candidate remains an unstaged worktree on `test/gentle-shell-v4` at `a16d34d`:
two modified consumer suites, two new helper/test files, and this new document.
Native review is pending; there is no frozen native candidate or review receipt.
Actual diff including untracked files: 302 additions + 9 deletions = 311 authored lines.
Rollback remains the bounded five-path STT-01 change described above.

## Independent verification and native-checking blocker

The parent supplied independent verifier evidence; this documentation-only update
records that evidence without rerunning tests or starting a review lifecycle.
Each verifier command had a 120000ms outer timeout:

| Exact independent command | Observed result |
| --- | --- |
| `bash -n .devcontainer/test/helpers/version-policy.bash` | Exit 0. |
| `bats .devcontainer/test/unit/version-policy-helper.bats` | Exit 0; 5/5 PASS. |
| `bats --filter 'Phase 3A\|installer fails closed when required lock data is missing' .devcontainer/test/unit/common.sh.bats .devcontainer/test/unit/tool-policy.bats` | Exit 0; 3/3 PASS. |
| `git diff --check` | Exit 0. |

The independent verifier confirmed every existing assertion and case list was
preserved. The parent's separate helper spot check also passed 5/5.
Independent functional verification is complete; overall native checking is partial.

Native review is **NOT started, frozen, or approved**. Global mode remains **on**.
The initial native assessment was high/unassessable because intended untracked
files had not been declared. Selectorless STATUS returned `collect` with
`intended_untracked_selection_required` and schema
`gentle-ai.review-intended-untracked-selection/v1`. Installed help/assets did not
document the selection JSON fields, so no guessed selection was submitted.
The exact three eligible intended untracked paths are:

- `.devcontainer/test/helpers/version-policy.bash`
- `.devcontainer/test/unit/version-policy-helper.bats`
- `odd/tasks/standardize-tool-tests.md`

Native review remains **pending / blocked** on a documented selection shape;
do not disable review or fabricate PASS. No review lifecycle, staging, or commits
are authorized by this evidence update. Commit remains PENDING owner approval.

## Local commit verification

Before committing, both helper suites passed 5/5 independently with outer timeout
120000ms each. Existing independent 24/24 functional evidence remains accepted;
no full suites, network, Docker, build, or native review lifecycle was run.
STT-01's initial document snapshot ends here; STT-02 appends its own cohesive
section in the second commit without changing any reviewed source bytes.

## STT-02 — Prepare a closed npm family fixture

Implementation authorization: current user explicitly permits source edits only
to `.devcontainer/test/helpers/npm-fixture.bash`,
`.devcontainer/test/unit/npm-fixture-helper.bats`,
`.devcontainer/test/unit/gentle-shell.bats`, and
`.devcontainer/test/unit/node-contracts.bats`, plus this document/mirror.
Chosen review deliveries: STT-01 policy probes, then STT-02 npm family fixture.
`chain_strategy: feature-branch-chain`; future tracker/child chain only after
separate approval. No branches, staging, commits, or PRs now. RDD remains on;
independent npm work is authorized with STT-01 native review still pending.

- [x] **STT-02 — Share npm command capture and sandbox with two installer suites.**
  Functional implementation and independent verification complete; native review
  remains pending. TDD is ON from current explicit user choice; runner is Bats.
  Source changes follow the explicit four-path authorization above.
  Route: delegated bounded implementation when authorized; triggers are a new
  cross-suite fixture, subprocess isolation, and two distinct tool contracts.
  No child delegation, second feature identity, or SDD artifacts.

### Selected consumers and proposed API

Select `.devcontainer/test/unit/gentle-shell.bats` and
`.devcontainer/test/unit/node-contracts.bats`: both simulate global npm install
and npm root, with local package state. Gentle AI uses direct release archives,
not npm. Defer pnpm: its fixture executes ownership provisioning; it has no
npm-root behavior and is a less cohesive first pair.

Proposed new files: `.devcontainer/test/helpers/npm-fixture.bash` and
`.devcontainer/test/unit/npm-fixture-helper.bats`. Proposed call-site syntax:

```bash
load ../helpers/npm-fixture.bash
setup_npm_fixture "${BATS_TEST_TMPDIR}/npm sandbox"
# Consumer writes its own common.sh/BASH_ENV and npm_fixture_dispatch callback.
run_npm_fixture "${INSTALLER}" "${consumer_env}" FAIL_NPM=1
[ "$status" -ne 0 ]
```

`setup_npm_fixture ROOT` creates fixture-local home, tmp, bin, and npm call log;
sets `NPM_FIXTURE_ROOT`, `NPM_FIXTURE_CALLS`, and `NPM_FIXTURE_RUNTIME` for the runner.
That runtime defines fake `npm`, captures each invocation in a separate numbered
NUL-delimited argv file, and calls consumer-defined `npm_fixture_dispatch "$@"`.
Missing dispatcher/unexpected commands fail closed; never fall through to real npm.
`run_npm_fixture INSTALLER ENV_FILE [NAME=value ...]` uses Bats `run env -i`, an
explicit local utility PATH, fixture HOME/TMPDIR, and the caller's BASH_ENV.
Caller stubs explicitly source the fixture runtime; helper plumbing alone is not
acceptance. Reject overrides of sandbox-owned environment keys. Preserve Bats
status/output/lines and parent environment. Do not source installers or use eval.

### Stable acceptance and TDD checks

- Both existing suites use the shared fake npm, argv capture, and sandbox.
  Remove both local npm implementations; retain privileged-command adapters and
  tool-specific dispatch callbacks. Record removed duplicated plumbing and show
  that a third npm consumer needs only its local policy/dispatch/assertions, not
  another command recorder or sandbox. A run wrapper alone does not satisfy this.
- Keep Shell's tarball byte comparison, SRI, native script flags, package/bin
  metadata, version failure, readable bundle, passive state, and no CLI probing.
  Keep contracts' exact packages/versions, logger mode, reuse/preservation,
  root failure, and symlink refusal. No universal versions, flag normalization,
  source parsing, discovery, or duplicate catalog.
- Preserve contracts' current adapter semantics: `npm "$@"` forwards a leading
  `npm` on install, while root passes `root -g`. Capture raw argv; do not silently
  normalize that test convention or change production behavior.
- First add synthetic Bats contract cases, observe genuine RED, then minimal
  GREEN: success/multiline and exit 42 propagation; raw argv with spaces; missing
  or rejecting dispatcher; sandbox HOME/TMPDIR and reserved-key rejection;
  parent/ambient environment isolation; independent roots and repeated capture.
  Synthetic callbacks write only inside Bats temporary directories.
- Re-run the exact passing baseline immediately before consumer edits. Translate
  call-log assertions to exact argv checks without losing any existing assertion.

### Safe baseline and exact next checks

Read both full suites and both installer paths before execution. Shell copies its
installer and substitutes common.sh; fetch copies synthetic bytes, npm is fake,
and remaining node/chmod operations target temporary files. Contracts uses a
closed BASH_ENV, premarks common.sh loaded, and permits only fixture npm and the
fixture logger mkdir. No real npm, privilege escalation, network, Docker, or build.

Executed once with outer timeout `120000ms`, exit 0, **11/11 PASS**:

```bash
bats --filter 'Shell verifies local SRI|Shell bad SRI|Shell missing or malformed SRI|Shell root-created private bundle|Shell runtime passive mount|Shell failed npm|Shell unsupported architecture|contracts ' .devcontainer/test/unit/gentle-shell.bats .devcontainer/test/unit/node-contracts.bats
```

The read-only add-tool inspector also exited 0: 39 installers, 15 aliases,
88 policy keys, no naming/alias errors. Final syntax (executed; results below):

```bash
bash -n .devcontainer/test/helpers/npm-fixture.bash
bats .devcontainer/test/unit/npm-fixture-helper.bats
bats --filter 'Shell verifies local SRI|Shell bad SRI|Shell missing or malformed SRI|Shell root-created private bundle|Shell runtime passive mount|Shell failed npm|Shell unsupported architecture|contracts ' .devcontainer/test/unit/gentle-shell.bats .devcontainer/test/unit/node-contracts.bats
bats .devcontainer/test/unit/version-policy-helper.bats
bats --filter 'Phase 3A|installer fails closed when required lock data is missing' .devcontainer/test/unit/common.sh.bats .devcontainer/test/unit/tool-policy.bats
git diff --check
git diff --stat
git status --short
```

Each Bats invocation requires an explicit outer `120000ms` timeout. Expected cost:
seconds, short-lived local processes and temporary files; zero downloads/builds.
Inspect new execution paths before running. Runtime harness N/A: mocked installer
contracts are not installed-tool, image, or lifecycle proof.

### Forecast, rollback, and pending authority

Existing STT-01 delivery was **311 authored changed lines** (302 additions + 9
deletions), including this untracked document. STT-02 preparation adds about
110–130 lines; implementation forecasts 180–260 additions and 35–65 deletions
across helper, contract suite, two consumers, and evidence: **215–325 more**.
Combined forecast **636–766 lines**, above 400: report meaningful slice boundary
STT-01 policy probes versus STT-02 npm fixture plus both consumers and tests.
`ask-on-risk` remains active; slicing is a review proposal, not permission to
commit/create PRs. Owner approval remains pending; never code-golf to fit.

Rollback STT-02 alone: remove its two proposed files, revert only its hunks in
gentle-shell.bats/node-contracts.bats and this section/authority update; preserve
all STT-01 files, evidence, and native blocker. Pending checks: documented native
selection/review and owner commit approval. Implementation authorization,
RED/GREEN, consumer verification, and measured diff are recorded below.
Risks: environment sanitization hiding intended overrides, callback not loaded in
subprocess, argument boundary loss, and accidental ambient npm. Closed dispatch,
raw capture, reserved keys, and synthetic negative cases are mandatory controls.
Skill resolution: all five requested exact paths read before work; test-only
family preparation, no provider/state/updater changes. No upgrades or staging.

### STT-02 implementation evidence

Observed RED: `bats .devcontainer/test/unit/npm-fixture-helper.bats` exited 1
at gathering because npm-fixture.bash did not exist; no behavioral cases ran.
Minimal implementation GREEN: same command exited 0, 5/5 PASS. The exact
11-case baseline above passed immediately before consumer edits, not RED.
Final commands above ran once each after source formatting inspection:
syntax exit 0; npm helper 5/5; selected consumers 11/11; STT-01 helper 5/5;
STT-01 policy probes 3/3. Every Bats call used outer timeout 120000ms.
No unexpected failures. New sources use four spaces; touched consumer lines
retain surrounding indentation. No source edits followed final verification.

Both consumers now use shared fake npm, raw argv files, and isolated env -i
execution. Local npm bodies became trusted tool dispatch callbacks; Shell's
privileged command log remains for existing assertions. New exact argv checks
supplement rather than replace assertions. Contracts' leading npm is retained.
Third-tool onboarding: load npm-fixture.bash, setup a Bats-local root, source
NPM_FIXTURE_RUNTIME from local stubs, define npm_fixture_dispatch, and pass only
explicit tool variables to run_npm_fixture. No new recorder/sandbox is needed.
The helper reserves isolation keys and provides a failing executable npm fallback.
Capture is serial per fixture; concurrent npm calls are outside this contract.

Measured before this evidence addition: 620 authored changed lines including
untracked files: STT-01 311; STT-02 309 (130 document additions and 179 source
changes). This evidence/status update adds further authored documentation;
final exact count is reported in the executor result. Two chosen review deliveries
remain policy probes then npm fixture, feature-branch-chain, approval pending.
Independent functional verifier confirmed syntax exit 0, npm helper 5/5,
selected consumers 11/11, STT-01 helper 5/5, focused probes 3/3, and diff-check
pass; each Bats call used outer timeout 120000ms. Parent npm-helper spotcheck
also passed 5/5. Full consumer diffs preserve tests/assertions and add raw argv
checks. These are trusted callbacks with serial capture, not a hostile sandbox.
STT-02 is functionally complete; native review remains blocked on undocumented
intended-untracked selection schema. RDD stays ON; no approval or receipt exists.
Explicit consent to continue npm with prior review pending and both chosen
feature-branch-chain deliveries remains recorded; owner commit approval pending.
No source edits followed final checks; this update changes only document/mirror.
No installed-tool, image, or runtime proof. STT-02 rollback preserves STT-01.

### Approved local commit evidence

STT-01: `8e5b43e64927d12cf3aaf8b463da2aa53b4a0679`, parent
`a16d34d513154708dc792776549988936dc980d8`, message
`refactor(tests): share installer version-policy probes`; 317 additions + 9
deletions = 326 authored changed lines, including 237 document lines.
STT-02 is the immediately following local commit containing its helper, contract
suite, both npm consumers, and this appended section. Its final hash is recorded
separately in Engram to avoid circular self-hash edits or an extra evidence commit.
Future review boundaries are `a16d34d..8e5b43e`, then `8e5b43e..STT-02`.
Both complete work units remain below the 400-line budget; no source compression
or rewriting was used. All eight source blob hashes match the pre-commit snapshot.
Native review is pending, not approved; no native lifecycle was invoked here.
No push, PR, branch/tracker creation, amendment, or third commit is authorized.
