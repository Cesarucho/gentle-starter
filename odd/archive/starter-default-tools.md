# Published starter tool defaults

## Objective and rationale

Publish a fixed optional installer preset independent of the producer branch's
enabled aliases. Preserve historical candidate/release identity verification.

## Authorized scope

- `.maintainer/scripts/starter-source.py`
- `.maintainer/scripts/starter-candidate.py`
- `.maintainer/scripts/starter-promote.py`
- `.maintainer/test/unit/starter-distribution.bats`
- `.maintainer/README-distribution.md`
- `.devcontainer/docs/install-tree.md`
- This feature record and its archive/mirror.

The published optional preset contains exactly these canonical aliases:
`2080-browser-playwright.sh`, `3030-ai-pi-coding.sh`,
`3040-ai-gentle-shell.sh`, `3070-ai-gga.sh`, `4000-tool-ssh-client.sh`,
and `4100-tool-pulseaudio-utils.sh`.

Change only the generated committed-source candidate tree, not the producer's
activation. Keep core aliases and Compose policy unchanged. Preserve unrelated
configuration edits and the untracked SSH-client alias. No primary commit,
staging, push, publication, network, Docker/build, or real lifecycle operations.
Disposable local Git fixtures are authorized for focused verification.

## Tasks and routing

- [x] D01: Add versioned preset generation and historical identity compatibility.
- [x] D02: Prove producer-independent defaults, failure safety, and publication.
- [x] D03: Document defaults, independently verify, and archive the feature.

D01/D02 use one delegated writer: unfamiliar preparation and multiple non-trivial
files trigger delegation. D03 uses independent verification and parent closure.
Applicable test-first policy: observe focused deterministic RED before behavior
changes, then GREEN and refactor. No separately configured strict TDD is known.
Runner: `PYTHONDONTWRITEBYTECODE=1 bats .maintainer/test/unit/starter-distribution.bats`.

Forecast: approximately 350–550 authored changed lines, primarily regression
coverage; generated files excluded. Delivery strategy: `ask-on-risk`, deferred
until explicit commit/delivery approval. No commits are authorized for this new
feature. The size guideline is advisory and must not reduce assertions.

## Acceptance and checks

- New RC and starter trees contain exactly six optional Git symlinks with
  canonical targets, independently of producer optional selections.
- Validate committed installer identity/modes and dependency projection without
  running installers or changing the producer worktree/index/references.
- Reject missing/invalid inputs before candidate or release reference mutation.
- Historical unmarked and Compose-policy-2 identities retain original semantics;
  new preset policy is explicit and same-source migration is supported.
- Existing Compose selection and core installation remain unchanged.
- Focused RED/GREEN, full distribution Bats, applicable Python/Bats lint/format,
  Markdown lint, and `git diff --check`; supervisor timeout 600000 ms.
- RDD is explicitly off clone-local; no native review or approval claim.

## Evidence and next step

Starting HEAD: `45fd4e4f8a52a6373ddc0b22598bfba7d59f994a`, branch `dev`.
Explorer mapped shared filtering and identity consumers; parent spot-checked
`starter-source.py` and ran the add-tool install-tree inspection successfully.
Current producer includes Glow, which must not enter the published preset.

### D01 implementation outcome

New candidates/releases carry `Starter-Optional-Preset: 1` after the unchanged
Compose-policy-2 marker. The private committed-source index removes all producer
optional entries and writes exactly six canonical `120000` symlinks without
trailing newlines. A read-only Git-path adapter reuses the local `selection.py`
catalog, core/COPY, graph and ordering validators over committed data. No source
Python or installer is executed. Catalog installers must be regular `100755`
objects, and the exact six-plus-core projection must satisfy dependencies.

Historical unmarked and Compose-policy-2 generations retain the original optional
tree and skip the new validation. Strict metadata parsing, candidate ancestry,
same-source migration/no-op, promotion, prior-release verification and cancellation
all propagate the independent preset identity. Documentation explains publication
defaults without changing producer activation or Compose integration policy.

### D02 observed evidence and limitation

- RED: `PYTHONDONTWRITEBYTECODE=1 bats --filter 'published optional preset' .maintainer/test/unit/starter-distribution.bats`
  failed all three initial new tests before implementation: absent preset,
  accepted missing catalog input and absent committed-input normalization.
- GREEN/TRIANGULATE: the same exact focused command passed all six final tests.
  Cases cover empty/different/extra producer selections, exact modes/target bytes,
  committed versus dirty inputs, core/catalog preservation, missing/nonexecutable
  or symlink catalog targets, unsatisfied dependencies, cycles, core disagreement,
  historical tree oracles, same-source transitions, no-op, forged/unknown metadata,
  RC/starter equality and unchanged refs/index/worktree on failure.
- `PYTHONDONTWRITEBYTECODE=1 bats .maintainer/test/unit/starter-distribution.bats`:
  all 31 tests passed, including the final post-lint rerun, with supervisor 600000 ms.
- `shellcheck -s bash .maintainer/test/unit/starter-distribution.bats`: final PASS.
  Initial diagnostics prompted explicit Bats `run !` assertions, quoted Git tree
  expressions and a Bats 1.5 minimum. Only SC2030/SC2031 are disabled, because
  shared helpers intentionally set approval variables inside each test's subshell.
- `shfmt -d -i 2 -ci -sr -ln bats .maintainer/test/unit/starter-distribution.bats`:
  final PASS. Initial default-redirection/style checks reported differences;
  the final check preserves this file's established style and spaces heredocs.
- Python syntax check without bytecode: PASS for all three edited Python files:

  ```bash
  PYTHONDONTWRITEBYTECODE=1 python3 -c 'import ast; from pathlib import Path; paths = [Path(".maintainer/scripts") / name for name in ("starter-source.py", "starter-candidate.py", "starter-promote.py")]; [ast.parse(path.read_text(), filename=str(path)) for path in paths]; print("PASS: syntax parsed for three edited Python files")'
  ```

- `markdownlint-cli2 .maintainer/README-distribution.md .devcontainer/docs/install-tree.md odd/tasks/starter-default-tools.md`:
  PASS, zero issues; repository configuration also includes its usual guide globs.
- `git diff --check`: PASS, including the updated feature record.

One extra full-suite invocation accidentally used
`PYTHONDONTWRITECODE=1 bats .maintainer/test/unit/starter-distribution.bats`.
It passed 31 tests but did not prevent Python bytecode output. Cache files are
present under `.maintainer/scripts/__pycache__/` and
`.devcontainer/install/lib/__pycache__/`; no pre-run cache snapshot establishes
which files were already present. Cleanup is outside the writer's allowed edit
surfaces and deletion authority, so the writer leaves them untouched and reports
partial. D02 remains open for parent reconciliation of this housekeeping issue,
not because any final required behavior check fails.

The unrelated `.gitignore` gained a Playwright ignore entry during the delegation;
the writer did not edit it. The original two configuration edits and untracked
SSH alias remain untouched. No primary staging, commits, refs, publication,
network, installer execution, Docker/build or real lifecycle work was performed.
Authored source/tests/docs exceed the advisory 400-line guideline; assertions and
coherent historical compatibility coverage were retained rather than compressed.

Next: parent independently verifies the change, reconciles cache housekeeping and
D02, then owns D03/closure/archive. No commit approval exists for this feature.
Real runtime and release readiness remain outside this work unit.

### Parent reconciliation and closure

Independent verification repeated all six focused tests and all 31 distribution
tests successfully, plus the exact ShellCheck, style-matched shfmt, AST, Markdown
and whitespace checks above. The parent repeated the six focused tests as a final
spot check. RED remains observed writer evidence, not independently replayed RED.

Read-only cache inspection confirmed no tracked bytecode. Existing `__pycache__/`
ignore rules cover the reported caches independently of the unrelated Playwright
ignore addition. These ignored bytes do not enter committed-source generation or
the authorized diff. The parent reconciled D02 by preserving ignored housekeeping
with unknown provenance, without deletion or claims of baseline cache cleanliness.
This is not acceptance of an unavailable functional proof: all required checks
passed, and cache removal is outside this feature's deliverable.

The implementation changes six existing source/test/documentation files,
539 additions and 59 deletions, plus this record. All changes remain unstaged and
uncommitted on `dev` at the starting HEAD. The producer optional aliases, both
unrelated configuration edits, the unrelated `.gitignore` edit, and untracked
SSH-client alias are preserved and excluded from this feature's intended diff.

RDD readback remained off clone-local. Assessment was unavailable because of
undeclared untracked scope, conservatively treated as high; independent technical
verification passed. Review disposition is `disabled/unmanaged`, not native
approval. No real publication, installer, network, Docker or lifecycle proof ran.

D01–D03 are complete for authorized local implementation. Parent archived the
record at `odd/archive/starter-default-tools.md`, retaining historical evidence
and updating the full stable-topic mirror. Next: owner reviews the unstaged diff
before authorizing any commit or publication. Delivery strategy remains deferred;
there is no pending authorized implementation or product decision in this feature.
