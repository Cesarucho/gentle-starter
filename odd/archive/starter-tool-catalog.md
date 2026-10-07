# Editable starter tool suggestions

## Goal and authorization

Provide one editable JSON list of optional tools used as default suggestions in
new published starter trees, independently of producer activation. No preset
versions, append-only history, consumer migrations or update support framework.
Consumers manage ordinary Git merges and decide which changes to keep.

## Scope and constraints

Add `.maintainer/starter-tools.json`; edit the three publication Python helpers,
`.maintainer/test/unit/starter-distribution.bats`, `.maintainer/README-distribution.md`
and `.devcontainer/docs/install-tree.md`. Initial list: Playwright, Pi, Gentle
Shell, GGA and SSH client; no PulseAudio. Preserve core tools, producer aliases,
Compose and prior archived history. No staging, commit, publication, remote,
network, installer, Docker or lifecycle operations. Offline Git fixtures allowed.

## Tasks

- [x] S01: Load a mutable committed-source list and normalize published aliases.
- [x] S02: Verify editing/removal, provenance safety and unchanged producer state.
- [x] S03: Document consumer responsibility, independently verify and archive.

S01/S02 use one delegated writer for preparation and multi-file implementation;
S03 uses independent verification and parent closure. Default deterministic
test-first: observed focused RED/GREEN and full distribution Bats. No separate
strict mode is known. Supervisor timeout 600000 ms. Forecast 250–450 authored
lines; heuristic advisory, `ask-on-risk` delivery deferred until commit approval.

## Acceptance

Exactly the list's optional aliases are generated as canonical Git symlinks;
entries may be added, removed or replaced, including an empty list. Validate
schema, installer modes, core exclusion and declared dependencies without
auto-activation. Read each catalog from its source commit, not dirty files.
Retain existing provenance, exact-tree, approval and CAS safeguards; legacy
unmarked identities use their original transform. Any normalization marker is
producer algorithm identity, not a catalog version or consumer migration policy.
Git may merge clean changes automatically or expose conflicts; no promise that
every update conflicts or preserves consumer customizations automatically.
Run focused/full Bats, ShellCheck, check-only shfmt, AST/JSON, Markdown and
whitespace checks. RDD is off clone-local; no native approval is claimed.

## Progress

Clean start at `27a0b74452442d8d9705290668e3eb12e767544b`, branch `dev`.
Parent inspected the committed-source private-index filter. Prior catalogue
attempts remain rolled back and archived; this is a new minimal work unit.
The writer implemented the editable committed-source list and private-index alias
replacement. Shared local core/dependency validation reads committed objects
through a read-only adapter; no source Python or installer is executed.
`Starter-Tools-Normalization: 1` propagates through candidate/release identity,
approval, historical-tree recomputation and cancellation. Unmarked and Compose2
historical identities retain their original aliases without reading a list.

## Observed verification

- RED: focused Bats initially ran six tests; five failed for intended missing
  normalization/validation behavior and the existing dirty-source guard passed.
- GREEN/triangulation: focused Bats passes all 11 catalog tests. Coverage includes
  exact newline-free canonical symlinks, mutable/empty lists, schema/mode/target
  rejection, dependencies/cycles/order/core authority, source pinning after an
  installer removal, historical candidate and release oracles, strict metadata
  and ref-lock failure preservation.
- Full distribution Bats passes all 36 tests, retaining the 25 baseline fixtures,
  including ordinary consumer clean merges and manual-conflict regression.
- ShellCheck passes after explicit exclusions for literal Git braces, Bats test
  isolation and optional helper argument dispatch. Its first run also exposed
  unreliable bare `!` assertions; a checked negative-command helper now makes
  those baseline and new absence assertions effective.
- Check-only shfmt passes after its reported spacing changes were applied.
- AST parsing passes for all three Python helpers without bytecode creation.
- JSON validation passes: regular 0644 file, array, five unique canonical strings.
- Markdownlint passes (the repository configuration includes 23 documentation
  files); whitespace checking passes.
- Exact baseline Git comparison outside allowed paths and the staged comparison
  are empty. Producer aliases/core, owner configuration, policy, Compose and
  archives retain their tracked bytes and Git modes. Branch remains `dev`; HEAD
  remains `27a0b74452442d8d9705290668e3eb12e767544b`. No primary staging, commit,
  ref update, publication, network, build or lifecycle operation was performed.

Executed commands (Bats supervisor timeout 600000 ms each):

```bash
PYTHONDONTWRITEBYTECODE=1 bats --filter 'tool catalog' .maintainer/test/unit/starter-distribution.bats
PYTHONDONTWRITEBYTECODE=1 bats .maintainer/test/unit/starter-distribution.bats
shellcheck -s bash .maintainer/test/unit/starter-distribution.bats
shfmt -d -i 2 -ci -sr -ln bats .maintainer/test/unit/starter-distribution.bats
markdownlint-cli2 .maintainer/README-distribution.md .devcontainer/docs/install-tree.md odd/tasks/starter-tool-catalog.md
git diff --check
```

AST/JSON checks used read-only `python3 -c` calls, not imports of the helpers or
`py_compile`. The tracked implementation/docs/test diff is 533 additions and
51 deletions, plus the new seven-line list and this record; the advisory forecast
was exceeded to retain meaningful historical and failure-case coverage.

## Parent handoff

S03 remains pending: the minimal consumer-responsibility documentation is written,
but independent verification, review disposition and ODD archival remain
parent-owned. Changes are unstaged and uncommitted. RDD is off clone-local;
implementation test success is not native review approval or publication proof.

## Parent closure evidence

Independent technical verification passed all 11 catalog tests and all 36
distribution tests, ShellCheck with disclosed SC1083/SC2030/SC2031/SC2119/SC2120
exclusions, style-matched check-only shfmt, three Python AST checks, exact JSON
array/mode checks, Markdown and whitespace checks. No blocking defect was found.
The parent repeated the 11 focused tests successfully as a spot check.
Initial RED remains observed writer evidence, not independently replayed RED.

The result is one editable JSON array, not versioned presets. Entries can be
changed or deleted without retention mandates, including an empty selection.
Recorded source commits supply historical list data solely for producer identity
verification; no consumer migration or update support framework exists.
Consumers own their ordinary Git merge and conflict decisions.

RDD remained off clone-local. Native assessment was unavailable because of
undeclared untracked scope and treated conservatively as high; the independent
technical verification above passed. Disposition is `disabled/unmanaged`, not
native approval. Physical permission-bit history, real publication and operational
lifecycle proof were not established or required by this local implementation.

S01–S03 are complete for the authorized local feature. The parent archived the
record at `odd/archive/starter-tool-catalog.md` and updated/read back the full
stable-topic mirror. Source, tests, documentation and new list remain unstaged and
uncommitted at the starting HEAD. Prior archives, producer aliases, core, policy,
configuration and Compose remain unchanged. Next: owner reviews the local diff
before explicitly authorizing any commit or publication.

## Owner-approved four-tool selection follow-up

The owner removed SSH client from `.maintainer/starter-tools.json` and explicitly
requested a commit. The current array contains exactly Playwright, Pi Coding,
Gentle Shell and GGA, without SSH client or PulseAudio. This supersedes the initial
five-tool suggestion above, not its historical verification evidence. The writer
left the owner file and previously committed producer SSH activation unchanged.
The two current catalog guides now match the four-tool selection; SSH availability
and independent Compose caveats remain intact. The existing editable-list positive
test now also exercises that exact four-tool array. Synthetic five-tool fixtures
and SSH negative/historical identity coverage remain valid and unchanged.

No new implementation behavior was required: the generic editable array already
supports removal. RED is therefore not applicable to this owner-data/documentation
correction. Focused GREEN passed 11 tests and full regression passed 36 tests,
including the added four-tool case and alternate/negative selections.

Executed in CONTAINER `/home/ubuntu/gentle-starter`, with a 600000 ms supervisor
timeout for each command:

```bash
PYTHONDONTWRITEBYTECODE=1 bats --filter 'tool catalog' .maintainer/test/unit/starter-distribution.bats
PYTHONDONTWRITEBYTECODE=1 bats .maintainer/test/unit/starter-distribution.bats
shellcheck -s bash .maintainer/test/unit/starter-distribution.bats
shfmt -d -i 2 -ci -sr -ln bats .maintainer/test/unit/starter-distribution.bats
PYTHONDONTWRITEBYTECODE=1 python3 -c 'import ast,json,pathlib,stat; root=pathlib.Path("."); files=[root/".maintainer/scripts"/name for name in ("starter-source.py","starter-candidate.py","starter-promote.py")]; [ast.parse(path.read_text(),filename=str(path)) for path in files]; path=root/".maintainer/starter-tools.json"; expected=["2080-browser-playwright.sh","3030-ai-pi-coding.sh","3040-ai-gentle-shell.sh","3070-ai-gga.sh"]; assert json.loads(path.read_text()) == expected; mode=path.lstat().st_mode; assert stat.S_ISREG(mode) and stat.S_IMODE(mode) == 0o644; print("PASS: three Python ASTs; exact four-tool JSON array; regular 0644 mode")'
markdownlint-cli2 .maintainer/README-distribution.md .devcontainer/docs/install-tree.md odd/archive/starter-tool-catalog.md
git diff --check
```

Bats, ShellCheck, shfmt and AST/JSON checks passed. Markdownlint checked 23 files
with zero issues; `git diff --check` passed. AST parsing created no bytecode;
JSON validation confirmed the exact ordered four strings and regular 0644 mode.
RDD remains off clone-local; no native review approval is claimed. Primary staging
and commit remain parent-owned; commit identity is pending and must not be inferred
from the starting HEAD. No primary commit, branch change, publication, network,
installer, build, Docker or lifecycle operation was performed by the writer.
