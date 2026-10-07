# Starter regression fixtures

## Objective

Repair nine diagnosed release-test failures caused by stale fixture contracts,
without changing production behavior or weakening safety assertions.

## Authorized scope and constraints

- `.devcontainer/test/unit/codegraph-test.py`
- `.devcontainer/test/unit/opencode.bats`
- `.devcontainer/test/unit/config-export.bats`
- `.devcontainer/test/unit/gentle-shell.bats`
- `.devcontainer/test/unit/tools-update.bats`

The owner authorized repairs, verification, and a commit. Preserve the excluded
untracked SSH-client alias. No real network, Docker, build, lifecycle, agent,
consumer trust, or production configuration operations. Local isolated fixture
Git operations and temporary offline package installation are permitted.

## Tasks and routing

- [x] F01: Update seed/plugin, synthetic catalog, and Shell-default test contracts.
- [x] F02: Complete exact-version provider mocks and current scoped-update tests.
- [x] F03: Verify the targeted work unit independently and commit with evidence.

F01 and F02 use one delegated writer: preparation and five non-trivial test files
require delegation. F03 uses independent verification plus parent Git delivery.
Default applicable test-first: observe current failures, then GREEN and refactor
with passing tests. No separate strict TDD configuration has been verified.

Forecast: under 300 authored changed lines; `ask-on-risk` delivery strategy.
The 400-line planning guideline is advisory, not a reason to omit assertions.

## Acceptance and checks

- All nine diagnosed failures pass against current production contracts.
- Preserve missing-owner, preference-preservation, passive-bind, exact-provider
  identity, and unrelated-policy tampering protections with meaningful assertions.
- Run the five focused suites (including CodeGraph's Bats wrapper), focused
  ShellCheck/shfmt, Markdown checks on this record, and `git diff --check`.
- Use bytecode suppression and explicit 600000 ms test supervisor timeouts.
- Report all omitted and unavailable proof; fixtures do not prove real runtime.
- Native review is user-owned and does not grant publication authority.

## Evidence and next step

Starting source: `d2bf01eac29224bbbd6e6b525e304a59df9cb00b` on `dev`.
Read-only diagnosis reproduced all nine failures and recovered safe coverage:
456 passing, nine failing, 24 pending Bats entries; Compose inner proof partial.
At diagnosis, no implementation existed; the bounded writer was next to observe
RED and repair fixtures.
RC and starter promotion remain blocked until required proof is reconciled.

### Worker implementation evidence (CONTAINER)

Worktree: `/home/ubuntu/gentle-starter`, container `devd2bf01e`; observed branch
`dev` and HEAD match the starting source above. Only the five authorized test
files and this record were edited. The untracked SSH-client alias was preserved;
no primary-worktree staging, commit, push, or reference switch occurred.

F01 now checks both current CodeGraph MCP seeds and their no-download/update/
telemetry environment; native ODD agents and review transport replace retired
SDD plugin expectations. The export catalog includes a disabled Shell owner,
with explicit missing-owner rejection before runtime reads or writes. Recursive
export uses `opencode-example.json` and retains six-file byte comparisons and
telemetry/state exclusions. Shell's genuinely absent baseline is synthetic;
disabled/enabled seeding preserves preferences, and the producer-selected bind
retains exact passive semantics with no runtime owner.

F02 adds only literal CodeGraph 1.6.0 and Vitest 9.9.9 metadata responses to the
offline curl stub. Four wrong-name/version scenarios reject at identity validation
and preserve policy bytes/mode. The extracted Engram scope test passes
`scoped-update` and its four `UPDATE_KEYS`; an allowed-change control passes while
unrelated intent and comment mutations both reject at the byte-scope guard.

Exact verification commands, each with a 600000 ms supervisor timeout:

```bash
# RED, initial GREEN, and post-refactor GREEN: same five-suite command.
env PYTHONDONTWRITEBYTECODE=1 bats \
  .devcontainer/test/unit/codegraph.bats \
  .devcontainer/test/unit/opencode.bats \
  .devcontainer/test/unit/config-export.bats \
  .devcontainer/test/unit/gentle-shell.bats \
  .devcontainer/test/unit/tools-update.bats

env PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/codegraph-test.py

shellcheck -s bash -e SC2016,SC2030,SC2031,SC2034,SC2314 \
  .devcontainer/test/unit/opencode.bats \
  .devcontainer/test/unit/config-export.bats \
  .devcontainer/test/unit/gentle-shell.bats \
  .devcontainer/test/unit/tools-update.bats

shfmt -d .devcontainer/test/unit/opencode.bats \
  .devcontainer/test/unit/gentle-shell.bats \
  .devcontainer/test/unit/tools-update.bats && \
  shfmt -i 2 -d .devcontainer/test/unit/config-export.bats

markdownlint-cli2 odd/tasks/starter-regression-fixtures.md
git diff --check
```

- RED: 115 Bats entries, 106 passing, nine failing, zero skipped. Direct Python:
  16 tests, 15 passing and one missing-seed error.
- Initial and post-refactor GREEN: 117 Bats entries, all passing, zero failures
  or skips. Direct post-refactor Python: 16 passing, zero failures/errors/skips.
- Focused ShellCheck passes with the listed exclusions for existing literal
  snippets, sourced-variable/Bats subshell diagnostics, and existing negated
  assertions. Unexcluded ShellCheck reports those diagnostics, including existing
  non-final negated assertions; this is not unexcluded lint proof.
- Formatting passes with existing indentation (two spaces for config-export,
  tabs for the other three files). Bare shfmt initially proposed whole-file
  config-export reindentation; that unrelated formatting was not applied.
- Markdownlint and final diff whitespace checks pass.

Effects were temporary offline fixtures, synthetic package/archive bytes, and
isolated fixture Git history. No real endpoints, downloads, tool installations,
Docker/build/lifecycle, actual agents, consumer trust, or production config
operations ran. Runtime harness proof is N/A for this fixture-only work unit;
these checks do not establish real runtime or full release readiness.

Skill resolution: loaded the requested installed `work-unit-commits` and
`cognitive-doc-design` instructions. Used the parent's approved focused fallback
for missing project clean-code/Markdown skills; no skills were installed.

Rollback boundary: the five authorized test-file diffs and this task evidence;
production behavior is unaffected. F03 remains pending parent independent
verification, native review disposition, and authorized commit. The parent owns
ODD closure/archive and later RC proof reconciliation.

### Parent closure evidence (CONTAINER)

On 2026-10-06 the owner explicitly authorized disabling RDD for this clone
after repeated native consent UI unavailability. Mode readback confirmed
`off (decided by clone_local)`; global mode remains on. This is
`disabled/unmanaged`, not review approval or candidate consent. Assessment
was unassessable because of undeclared untracked files and was treated as high;
an independent verifier repeated the required functional checks instead.

Independent verification on the final five-file repair passed: 117 Bats entries,
zero failures/skips; 16 Python tests; focused ShellCheck with the documented
exclusions; both check-only shfmt commands; and `git diff --check`.
The parent spot check repeated the 16 Python tests successfully before commit.
Unrelated OpenCode JSON key ordering and Shell changelog preference changes
were inspected by the verifier and did not affect these assertions.

Authorized repair commit: `1df82914e28320cbf738eb103fcd3ceb1b7fc95c`,
`fix(test): align regression fixtures with current starter contracts`, on `dev`.
It contains exactly the five authorized test files: 120 additions, 29 deletions.
The SSH-client alias and both unrelated configuration diffs were excluded and
preserved. No push, PR, release promotion, or operational lifecycle ran.

F01–F03 are complete for the authorized fixture repair. The parent archived this
record at `odd/archive/starter-regression-fixtures.md`; historical commands and
earlier pending-state evidence above are retained. Real runtime and broader RC
proof remain outside this completed work unit; release readiness is not claimed.
