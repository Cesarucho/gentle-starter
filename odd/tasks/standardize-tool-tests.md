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
