# Remove the skills manual workaround

## Authorization and baseline

Preparation only: this record and its full Engram mirror precede source writes.
The owner authorized removing the temporary notice and three displayed
`skills add ... -a opencode -y` commands after `skills:suggest`, reporting an
upstream fix from a host RC test. This is owner-reported context, not independently
verified upstream evidence; no issue URL was supplied.

Verified starting state: clean `test/gentle-shell-v4`, HEAD `c91e925`.
Repository locator: `odd/archive/remove-skills-manual-workaround.md`.
Full mirror topic: `odd/remove-skills-manual-workaround/tasks` in `gentle-starter`.

## Route, scope, and safeguards

Implementation route: one assigned writer because four files require edits;
the writer does not delegate. One coherent work unit,
forecast fewer than 150 authored additions plus deletions; delivery `ask-on-risk`.
The forecast is advisory, not a hard cap or size-only stop. Stop for scope expansion
or unexpected real risk. No staging or
commits without explicit owner approval; no review approval is implied.

Allowed source scope:

- `.taskfiles/scripts/skills-suggest.sh`: remove only the displayed workaround.
- `.devcontainer/test/unit/skills-suggest.bats`: replace workaround expectations
  with absence assertions while preserving functional coverage.
- `.devcontainer/docs/optional-skills.md`: remove the temporary workaround section.
- `.maintainer/test/unit/starter-distribution.bats`: test title and fixture wording
  only; preserve byte-identity assertions and distribution behavior.

Preserve selected installs with `--agent universal --copy`, explicit consent,
cancellation, validation, continuation after partial failure, and failure exits.
Archived history stays untouched. No actual skills install, RC ref changes in the
real checkout, host-folder operations, remote execution, downloads, or builds.
Distribution verification uses isolated local Git fixtures, not the real RC.
Rollback boundary: only the four-file workaround-removal diff, preserving all
unrelated work and this planning history.

TDD policy is unknown/not established from source configuration; do not infer it
from Bats or another framework. Ordinary functional proof uses mocked installs;
real upstream/host runtime proof is not part of this removal.

## Tasks and outcomes

- [x] **RSW-01 — Implement one coherent removal.** Remove the notice, all three
  commands, and obsolete guide/test wording. Assert their absence after success,
  partial failure, and sole failure; retain selection/consent/cancellation/exit
  behavior and exact universal install calls. Outcome: implemented in four files.
- [x] **RSW-02 — Verify the same work unit.** Run every check below, record exact
  results and limitations, inspect full diff and authored line count, and confirm
  only authorized sources changed. Outcome: all seven required checks passed.
- [x] **RSW-03 — Reconcile and hand back.** Update this record and full mirror,
  read back both, and report owner-review status. Parent alone handles authorized
  ODD closure/archive after reconciliation; no automatic commit, stage, or PR.
  Outcome: parent reconciled evidence and authorized closure/archive; executed
  as a record-only handoff, with commit remaining the owner's decision.

## Exact writer checks (CONTAINER, repository root)

```bash
bats .devcontainer/test/unit/skills-suggest.bats
bats --filter 'published starter preserves' .maintainer/test/unit/starter-distribution.bats
bash -n .taskfiles/scripts/skills-suggest.sh
shfmt -d .taskfiles/scripts/skills-suggest.sh .devcontainer/test/unit/skills-suggest.bats
shellcheck .taskfiles/scripts/skills-suggest.sh
markdownlint-cli2 --no-globs .devcontainer/docs/optional-skills.md
git diff --check
```

## Preparation evidence

Relevant script, guide, mocked selector tests, and distribution byte-preservation
fixture inspected. Workaround is display-only and appears before the final failure
exit; removing it must not mask failures. Required skills loaded:
`markdown-documentation`, `cognitive-doc-design`, and `work-unit-commits`.
Preparation stops after record/mirror readback; no source implementation performed.

## Implementation evidence

The owner subsequently authorized this assigned writer to implement the four-file
removal without further delegation. The earlier preparation statement is historical.
No source normalization was required after the targeted patch.

All exact checks above ran in the foreground:

- Selector Bats: PASS, 10/10 tests, mocked Skills CLI only.
- Filtered distribution Bats: PASS, 1/1 matching test actually executed;
  renamed title is `published starter preserves skills selector and guide bytes`.
- `bash -n`: PASS, no output.
- `shfmt -d`: PASS, no diff.
- `shellcheck`: PASS, no output.
- Guide markdownlint: PASS, 1 file linted, 0 issues.
- `git diff --check`: PASS, no output.

Full tracked diff inspected: only four authorized source paths, 15 additions and
38 deletions (53 authored changed lines). This new task record is additional
planning/evidence, not part of that source count. Distribution changes are only
the test title and fixture commit description; byte assertions remain unchanged.
Archived records are untouched; the real checkout index remains empty.

Ordinary functional proof confirms universal copied install arguments, consent,
validation, cancellation, success, partial failure continuation, and sole failure
status. No actual skill install, real RC mutation, host operation, network, build,
SDD initialization, lifecycle proof, native review, staging, or commit performed.
Upstream repair remains owner-reported. Parent handles native review with RDD on
and ODD closure; these passing checks do not grant review approval.

Implementation skills: `clean-code`, `markdown-documentation`,
`cognitive-doc-design`, and `work-unit-commits`, loaded before writing.

## Final parent-authorized closure

The parent reported reconciliation of scope and all seven writer checks, plus
parent spot checks passing selector Bats 10/10 and `git diff --check`.
The parent reported completed four-lens native review, approved without blockers:

- Frozen candidate:
  `sha256:b1e423e1013fdda1e6856dba8dd48a826a153df2ec9374b64a4b64c08ed9ef4b`.
- Review lineage: `review-573c26c5dcc94912`.
- R2 informational suggestion: the unchecked closure item correctly awaited parent.
- Successful acknowledgement schema: `gentle-ai.review-acknowledged/v1`;
  action `acknowledged`, authority burned/consumed.
- Consumed revision:
  `sha256:58ceb822aa715e7ea46819d8653a6cbc88a7fa1c4ffdd0bcb62fc15398b2399d`.

The parent explicitly authorized this final record-only closure and archive move.
Approval covers the frozen source and preclosure document, not a new review of
this final archive/evidence handoff. Historical evidence above is preserved.
The former task locator was `odd/tasks/remove-skills-manual-workaround.md`;
current navigation and the full mirror use the archived locator above.

No source edits or formatting, another native review, functional test reruns,
staging, commits, pushes, real RC ref changes, host operations, network, or
delegation were authorized or performed for this handoff. Structural verification
checks archive existence/mode, absence of the former task path, unchanged four
source SHA-256 hashes/modes against the prehandoff baseline, empty index, whitespace,
and local/full-mirror readback. Commit remains an owner decision.
