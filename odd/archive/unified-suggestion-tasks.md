# Unified optional suggestion tasks

## Goal and authorization

Rename `task skills:suggest` to `task suggest:skills`; add interactive
`task suggest:tools` and combined `task suggest:all`. The owner chose selection
and confirmation, not automatic activation of every suggested tool.

## Scope and constraints

Add a consumer opt-in catalog containing the owner's exact 15 tools, separately
from `.maintainer/starter-tools.json` publication defaults. Enable selected tools
additively in `03-enabled/` using the existing shared lock and dependency planner.
Preserve producer activation, core, Compose, policy and archived history.
No primary staging, commits, publication, actual Skills downloads/installation,
network, builds, Docker or lifecycle work. Mocked Skills and isolated installer/Git
fixtures are authorized. RDD remains off clone-local.

Suggested tools: `2060-node-test.sh`, `2050-node-mermaid.sh`,
`2040-node-contracts.sh`, `2110-go-debug.sh`, `2210-cli-plantuml.sh`,
`2220-cli-c4-plantuml.sh`, `6020-cli-opentofu.sh`, `5020-cli-graphviz.sh`,
`5010-cli-gitleaks.sh`, `2100-runtime-go.sh`, `2400-python-graphify.sh`,
`2200-runtime-java.sh`, `4100-tool-pulseaudio-utils.sh`,
`4000-tool-ssh-client.sh`, `5000-cli-glow.sh`.

## Tasks and routing

- [x] U01: Rename the public skills task and introduce interactive tool suggestions.
- [x] U02: Add multi-root activation and combined selection/confirmation safely.
- [x] U03: Verify publication preservation, document behavior and archive.

One delegated writer owns U01/U02: preparation and multiple non-trivial files
require delegation. U03 uses independent verification and parent closure.
Default test-first applies with observed RED/GREEN. No separate strict mode is
known. Focused Bats uses mocked Skills CLI and disposable local trees; supervisor
timeout 600000 ms. Forecast 600–1000 authored lines including tests; heuristic
advisory, delivery `ask-on-risk` deferred until explicit commit/PR authorization.

## Acceptance and proof

New task names are visible in help; old task is removed, historical records kept.
Both selectors retain number/comma selection, all/none and one confirmation.
Validate all selected roots and the whole dependency projection before mutation;
apply multi-root enables under one shared lock and roll back only owned links.
Required dependencies activate; companions do not. Existing custom aliases and
unselected tools are retained; repeat activation is idempotent.
Combined task gathers both selections and validates before side effects, uses one
confirmation and sequential stages. Tool activation precedes Skills CLI calls;
skills failures remain partial success, never cross-system atomicity. Report
which stage changed state and do not undo unrelated pre-existing tools.
No actual installer execution or runtime uninstall/rebuild is implied.
CLI arguments stay injection-safe; published tools catalog/scripts/docs survive
filtering while publication defaults remain the existing four entries.
Focused skills/activation/dependency/new selectors/combined/distribution Bats,
syntax/lint/check-only formatting, JSON/Markdown and whitespace checks must pass.

## Progress

Starting clean HEAD `5d6eef114ee3520aa270c154d4f666bfc0117c98`, branch `dev`.
Read-only mapping confirms all 15 aliases exist; their optional dependencies are
within the list and foundation/core. Parent inspected existing selectors and
single-root activation.

### Initial writer outcomes (CONTAINER)

U01 behavior is implemented: the public `skills:suggest` task is removed;
`suggest:skills`, `suggest:tools` and `suggest:all` are exposed. The consumer
recommendations contain the exact 15 requested names and order. The shared
frontend retains numeric/comma/all/none selection and one confirmation; the direct
skills-name script interface remains available. U01 stays unchecked because the
now-unreferenced `.taskfiles/skills.yml` is an empty taskfile awaiting parent
deletion: the writer's safety contract prohibits filesystem deletion operations.
This is not a compatibility alias or a remaining product decision.

U02 is implemented and verified: all roots are normalized and checked before
planning, then one batch revalidates and applies under the existing directory
lock. Existing single-root operations and publication imports remain compatible.
The combined flow validates both catalogs before menus, keeps a confirmation
snapshot, activates tools before sequential Skills calls, skips skills on tool
failure, and reports retained tool activation after partial skills failure.

Documentation and publication-preservation tests are updated. U03 remains
parent-owned: independent verification, orphan taskfile deletion, reconciliation,
review disposition and archival are not writer closure. No primary aliases,
core, configuration, policy, Compose, publication defaults or archives were edited.
All changes remain unstaged and uncommitted; no real installs, network, builds,
Docker or lifecycle operations were run.

### Test-first evidence

- Initial test collection exposed authored test syntax errors; these were fixed
  before the meaningful RED, not counted as behavior RED.
- RED: the focused runner below reported 9 failures among 57 tests. Existing
  batch validation ignored a bad second root, and the batch did not create all
  roots. New public task-name assertions failed. New frontend cases failed because
  its file was absent; those discovery failures are not meaningful behavior RED.
- GREEN: the same focused runner passed 57/57 after implementation and 70/70 after
  triangulation. All 36 distribution tests passed.
- Triangulation covers mandatory second-root refusal, lock participation,
  dependency order, cycles, owned-link rollback, replacement ownership, signals,
  fresh planning, custom aliases, idempotence, core reuse, cancellation/EOF,
  injection-safe Task arguments, snapshots, stage ordering and partial failure.

### Observed verification commands

All Bats commands ran in the foreground with an outer timeout of 600000 ms.

```bash
env PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/skills-suggest.bats .devcontainer/test/unit/install-activation.bats .devcontainer/test/unit/install-dependencies.bats .devcontainer/test/unit/tools-suggest.bats .devcontainer/test/unit/suggest-all.bats
# PASS: 70/70
env PYTHONDONTWRITEBYTECODE=1 bats .maintainer/test/unit/starter-distribution.bats
# PASS: 36/36, including exported selector/catalog/guide bytes and four defaults
bash -n .taskfiles/scripts/skills-suggest.sh .taskfiles/scripts/suggest.sh && shellcheck .taskfiles/scripts/skills-suggest.sh .taskfiles/scripts/suggest.sh .devcontainer/test/unit/skills-suggest.bats .devcontainer/test/unit/install-activation.bats .devcontainer/test/unit/tools-suggest.bats .devcontainer/test/unit/suggest-all.bats .maintainer/test/unit/starter-distribution.bats
# PASS: nameref SC2034 annotated; isolated Bats SC2030/SC2031 annotated
shfmt -d .taskfiles/scripts/skills-suggest.sh .taskfiles/scripts/suggest.sh .devcontainer/test/unit/skills-suggest.bats .devcontainer/test/unit/install-activation.bats .devcontainer/test/unit/tools-suggest.bats .devcontainer/test/unit/suggest-all.bats && shfmt -i 2 -sr -d .maintainer/test/unit/starter-distribution.bats
# PASS: check-only; maintainer indentation/redirection spacing preserved
env PYTHONDONTWRITEBYTECODE=1 python3 -c 'import ast,json; from pathlib import Path; paths=[".taskfiles/scripts/skills-catalog.py",".taskfiles/scripts/tools-catalog.py",".devcontainer/install/lib/selection.py"]; [ast.parse(Path(p).read_text(),filename=p) for p in paths]; doc=json.loads(Path(".devcontainer/install/recommended-tools.json").read_text()); assert set(doc)=={"version","tools"} and doc["version"]==1 and len(doc["tools"])==len(set(doc["tools"]))==15; assert json.loads(Path(".maintainer/starter-tools.json").read_text())==["2080-browser-playwright.sh","3030-ai-pi-coding.sh","3040-ai-gentle-shell.sh","3070-ai-gga.sh"]; print("Three Python ASTs valid; fifteen unique recommendations and unchanged four defaults")'
# PASS: AST without bytecode; exact order additionally asserted in focused Bats
markdownlint-cli2 .devcontainer/docs/optional-skills.md .devcontainer/docs/optional-tools.md .devcontainer/docs/README.md odd/tasks/unified-suggestion-tasks.md
# PASS: zero issues; repository config adds its normal documentation globs
git diff --check
# PASS
git diff --quiet HEAD -- .devcontainer/install/03-enabled .devcontainer/install/02-core-tools .devcontainer/install/available .devcontainer/config .devcontainer/setup.sh .devcontainer/tool-versions.conf .devcontainer/Dockerfile .devcontainer/devcontainer.json .devcontainer/docker-compose.yml odd/archive .maintainer/starter-tools.json
# PASS: foreign tracked bytes and modes match the clean baseline
```

Earlier ShellCheck warnings were corrected/annotated and rerun successfully.
An initial shfmt invocation without `-sr` flagged pre-existing maintainer
redirection spacing; the convention-preserving invocation above passed without
normalizing unrelated lines. `markdownlint` is not installed; the available
`markdownlint-cli2` completed the Markdown check.

### Parent-authorized executable-mode correction (CONTAINER)

Independent verification found that `read_catalog` rejected nonregular/symlink
targets but did not check executable mode bits. Recommendations and batch
activation could therefore accept `0644` installer roots or required dependencies.

The bounded correction adds `validate_executable_closure`, shared by the tools
catalog loader and locked `plan-many`/`enable-many` paths. It statically checks
executable bits on each requested root and required transitive dependency,
including reused core. It runs before any plan is printed or aliases are applied,
and repeats against current files after confirmation. It does not run installers,
change global `read_catalog`, follow companion edges, or change single-root APIs.

Six additional tests cover nonexecutable roots/dependencies, core reuse,
unrelated/companion exclusions, single-root compatibility, rejection before
either combined menu, and mode changes during confirmation that prevent every
tool alias and Skills CLI call. All chmod operations affect disposable fixtures.

- RED: the exact focused Bats command above observed five intended mode-gate
  failures among 76 tests before implementation; the other 71 tests passed.
- GREEN: the same command passed 76/76 after the correction. The exact distribution
  command passed 36/36.
- The exact Bash/ShellCheck, check-only shfmt, AST/JSON, Markdown and Git whitespace
  commands above were rerun successfully after the final source edits. No mutating
  normalization was required. Supervisor timeout remained 600000 ms.
- Correction-start SHA-256 snapshots of all already-edited paths outside this
  correction scope matched afterward. Protected real activation/core/catalog,
  configuration/policy/Compose, default tools and archive bytes/modes still match
  HEAD, checked with the exact `git diff --quiet HEAD -- ...` command above.
- Parent deleted `.taskfiles/skills.yml` before this correction; its absence was
  verified and preserved. U01 is now complete, superseding the initial orphan
  cleanup limitation. U02 remains complete; U03 review/reconciliation/archival
  remain parent-owned and pending. Changes remain unstaged and uncommitted.

## Parent final reconciliation and closure

Independent verification confirmed the mode finding resolved, with 76/76 focused
tests and 36/36 distribution tests passing. Bash syntax, ShellCheck with disclosed
annotations, check-only formatting, Python AST/JSON, Markdown and whitespace
checks passed. The parent repeated the exact 76-test focused command successfully.
No additional blocker remained. RED chronology above is observed writer evidence,
not independently replayed RED.

The three interactive tasks use selection followed by confirmation. Combined
selection validates both catalogs and tool projection before side effects, enables
tools first and reports any later Skills failure as partial success. Existing
single-root operations and publication APIs remain compatible. The recommendation
catalog contains the exact 15 owner entries and order; the separate publication
defaults retain their four entries. No real producer aliases or installers were
modified or executed. Skills still require the published recommendation catalog;
development-lock fallback is intentionally absent, as in the previous selector.

RDD readback remained off clone-local. Native assessment was unavailable because
of undeclared untracked scope and treated conservatively as high; independent
technical verification above passed. Disposition is `disabled/unmanaged`, not
native approval. No real Skills installation, network, build, Docker, lifecycle
or publication proof was authorized or claimed.

U01–U03 are complete for the authorized local feature. Parent archived this record
at `odd/archive/unified-suggestion-tasks.md` and updated/read back its full mirror
under the stable topic. Changes remain unstaged and uncommitted at the starting
HEAD. Historical records, owner configuration, aliases, core, policy and Compose
are preserved. Next: owner reviews the local diff before any commit or publication.
