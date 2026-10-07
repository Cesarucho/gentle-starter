# Versioned starter preset catalog

## Goal and authorization

Provide an editable catalog of immutable optional-tool presets so future default
changes do not invalidate older candidate/release trees. Preset 1 is unpublished
and contains Playwright, Pi, Gentle Shell, GGA and SSH client, not PulseAudio.
The earlier six-tool archive is retained as historical evidence.

## Scope and constraints

Modify the three `.maintainer/scripts/starter-{source,candidate,promote}.py`
helpers, `.maintainer/test/unit/starter-distribution.bats`,
`.maintainer/README-distribution.md`, `.devcontainer/docs/install-tree.md`;
add `.maintainer/starter-presets.json`. Preserve producer activation, Compose,
unrelated configs/ignore edits and untracked SSH alias. No primary staging,
commit, publication, network, installers, Docker or lifecycle execution.
Offline disposable local Git fixtures are authorized. RDD remains off clone-local.

## Tasks and checks

- [x] C01: Introduce validated committed-tooling catalog and historical resolution.
- [x] C02: Protect append-only mappings and test evolution/atomic failures.
- [x] C03: Document workflow, independently verify and archive the record.

C01/C02 use one bounded writer: multi-file preparation and behavior require
delegation. C03 uses an independent verifier and parent closure. Default test-first
policy applies: observed focused RED, GREEN and passing refactor; no separately
configured strict TDD is known. Runner: distribution Bats, timeout 600000 ms.
Forecast approximately 500–900 authored changed lines including fixtures;
size heuristic is advisory. `ask-on-risk` delivery deferred until commit approval.

## Acceptance

Catalog selects a current ID and retains exact historical mappings. Read committed
catalog from the tooling checkout, not dirty files or ambient source repository.
Recorded IDs resolve historical selections; explicit absence keeps legacy producer
selection. New mapping/current changes migrate same-source candidates safely.
Reject malformed catalogs, unknown IDs, mapping edits/deletions, incomplete
ancestry and mismatched policies before reference updates. Validate selected
installers/dependencies from recorded source without executing source code.
Prove tooling/source ownership with isolated repositories. Full distribution
Bats, ShellCheck, check-only shfmt, bytecode-free AST checks, Markdown and diff
checks must pass. Real runtime/release readiness is not claimed.

## Progress

Starting HEAD `45fd4e4` on `dev`; previous default implementation and PulseAudio
removal remain unstaged. Pulse removal observed RED 1/6 failure, GREEN 6/6 and
full 31/31, with focused lint passing. Parent spot-checked the current five-tool
mapping. Writer implementation is complete; independent verification, disposition
and archival remain parent-owned under C03. No approval or release readiness is
claimed. All edits remain unstaged; RDD remains off clone-local.

## Implementation evidence

The schema-1 catalog selects preset `"1"` with five canonical aliases. Helpers pin
committed tooling HEAD from their own location, ignore dirty/untracked catalogs,
and cache catalog validation per operation. Explicit historical IDs resolve exact
retained mappings; explicit absence preserves producer selection for both legacy
Compose generations. Omitted preset selects current. Promotion emits the verified
identity. A same-source 1-to-2 transition creates a candidate child; stale preset-1
promotion refuses, retained cancellation works, and releases remain linear.

The ancestry checker visits the complete reachable tooling DAG, reads catalog
blobs at path-change/root/merge boundaries and parses each distinct blob once.
Every parent mapping must survive unchanged; additions and current changes are
allowed. Tests reject mutation, deletion, catalog removal, invalid ancestors,
edit/revert, merge-side loss and shallow/missing ancestry before source ref updates.
Source commits may predate the catalog. Selected mappings use recorded source
installer/dependency data and local validators, never source executable code.
Older maps need not fit today's source. Alias order is normalized deterministically.
This guards local reachable history, not discarded/rewritten publication history.

### Observed verification in CONTAINER

All Bats commands used a 600000 ms supervisor timeout and offline disposable Git
source/tooling repositories; scripts and catalog were committed only in fixtures.

- RED: `PYTHONDONTWRITEBYTECODE=1 bats --filter 'preset' .maintainer/test/unit/starter-distribution.bats`
  observed 6/7 passing, with the new migration test failing because old preset-1
  promotion still succeeded after tooling selected preset 2.
- GREEN/TRIANGULATE/REFACTOR: the same focused command passed 14/14 after the final
  changes, including schema types/duplicate keys, policy ownership/pinning,
  atomic failures, historical compatibility and source-specific validation.
- `PYTHONDONTWRITEBYTECODE=1 bats .maintainer/test/unit/starter-distribution.bats`:
  passed 39/39 after the final changes.
- `shellcheck -s bash .maintainer/test/unit/starter-distribution.bats`: passed.
- `shfmt -d -i 2 -ci -sr -ln bats .maintainer/test/unit/starter-distribution.bats`:
  passed with no formatting diff.
- Bytecode-free AST verification passed for all three Python helpers:

  ```bash
  python3 -c 'import ast, pathlib; [ast.parse(pathlib.Path(p).read_text(), filename=p) for p in (".maintainer/scripts/starter-source.py", ".maintainer/scripts/starter-candidate.py", ".maintainer/scripts/starter-promote.py")]; print("AST: 3 files passed")'
  ```

- JSON syntax/schema verification passed with current 1 and five aliases:

  ```bash
  PYTHONDONTWRITEBYTECODE=1 python3 -c 'import importlib.util, pathlib; p=".maintainer/scripts/starter-source.py"; s=importlib.util.spec_from_file_location("source", p); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); d=m.parse_presets(pathlib.Path(".maintainer/starter-presets.json").read_text()); assert d["current"] == "1" and len(d["presets"]["1"]["aliases"]) == 5; print("JSON schema: preset 1, five aliases passed")'
  ```

- `markdownlint-cli2 .maintainer/README-distribution.md .devcontainer/docs/install-tree.md odd/tasks/starter-preset-catalog.md`:
  passed with zero issues (23 files, including configured repository globs).
- `git diff --check`: passed with no whitespace errors.

No network, dependency installation, installer, Docker or lifecycle proof ran.
Production operations intentionally fail closed until the owner commits the
catalog to tooling; fixture passes do not authorize a primary commit or promotion.
Unrelated config/ignore edits, the SSH alias and six-tool archive were preserved.
Next: parent independently verifies C03, resolves review/commit authority and
archives only after reconciliation; the worker does not close this record.

## Parent closure evidence

Independent technical verification passed all 14 preset tests and all 39
distribution tests, ShellCheck, style-matched check-only shfmt, three Python AST
checks, catalog schema validation, Markdown and whitespace checks. No blocking
implementation finding remained. Parent spot check repeated the 14 preset tests
successfully. RED chronology remains observed worker evidence, not replayed RED.

RDD remains off clone-local. Native assessment could not classify undeclared
untracked scope and was conservatively treated as high; independent verification
was performed. Disposition is `disabled/unmanaged`, not native approval.

C01–C03 are complete for the authorized local change. The parent archived this
record at `odd/archive/starter-preset-catalog.md` and updated/read back its full
mirror under `odd/starter-preset-catalog/tasks`. Prior six-tool historical record
is retained; the current unpublished preset has five tools, excluding PulseAudio.
Producer activation, Compose and unrelated edits remain unchanged. No staging,
primary commit, publication or runtime operations were performed.

Next: owner reviews the unstaged diff before authorizing a commit. Publication
helpers intentionally refuse production use until the catalog is committed to
tooling; isolated tests establish the implementation, not release readiness.
