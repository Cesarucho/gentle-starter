# Nonblocking container attachment

## Parent reconciliation and implementation closure

The authorized attachment implementation and opt-in harness extension are complete.
TDD remains OFF by explicit owner choice. All final focused checks passed: 32
harness unit tests, 22 task/connect tests, 19 semantic/attachment tests, and 18
volume-repair tests (91 total). The parent independently repeated the 32 harness
tests and earlier 7 attachment tests; both passed. No live Docker, build, network,
or lifecycle execution was authorized or performed. Full suites, doctor and
tool-ownership execution remain unrun; mocked proof is not native runtime proof.
These limits match the authorized implementation-only scope, not failed checks.

The expanded frozen candidate received four admitted native reviews without
findings. Exact acknowledgement succeeded for `review-195a378d50363ab7`, target
`sha256:19ef3262eb944b9febaf488c69908c090a1219617dfc1eecbeb8f5f90640a549`,
consumed revision
`sha256:87459825f57e2bda0f2fb59cc94d0b1b3d7cefa82612914a9a314a69f132e149`;
authority is burned. This record's subsequent passive archival is bookkeeping,
not additional reviewed executable content or permission to deliver.

The owner tool-version checksum remains
`5dbe8b2e35ce97317c7def31614354b0477b48661181018097cb8324c23c5198`.
All changes remain unstaged and uncommitted; no commit identity exists. Include
those owner changes only after explicit approval of the reviewed commit scope.
No navigation references outside this record required updating.

NBA-06 is complete for reconciliation and archival; commit creation is conditional
on separate owner approval, not an outstanding implementation requirement.
Next optional action: separately authorize the documented isolated Docker run
after a concrete environment/cost forecast. The run is not claimed as passed.
All sections below preserve historical planning and worker evidence; earlier
pending status and unresolved TDD statements are superseded by this closure.

## Authorized attachment harness extension

Current status: original implementation NBA-02–05 is observed complete (59 focused
tests passed); parent-owned review/closure NBA-06 remains pending. TDD is OFF by
the owner's explicit "No". Historical unresolved-mode statements below are
superseded, not removed. Parent reports native 4R with no findings and acknowledged
burned receipt `review-2c3e69e1476b0255`, target `c170175...`; a subsequent
comment-only change is not new review approval.

The owner additionally authorizes a focused attachment scenario in the registered
isolated lifecycle harness, mocked tests, and directly related maintainer docs.
This delegated preparation/writer route covers four or more files and multiple
nontrivial behaviors. The worker must not delegate again. No Docker, build,
lifecycle, network, installation, update, remote, staging, commit, PR, or native
review execution is authorized. Preserve all existing edits and protected bytes.

- [x] NBA-07: inspect harness/task execution; integrate bounded real Task attachment
  payload with exact candidate/container/workspace/user assertions and preservation
  evidence for drift and missing new token. Retain registered probe/cleanup authority.
- [x] NBA-08: implement isolated mocked harness contracts and run the exact authorized
  focused checks after effect inspection; record actual results and limitations.
- [x] NBA-09: update maintainer invocation/coverage/cost docs, task outcomes and full
  mirror; hand off unstaged changes. Live proof remains pending; parent owns closure.

Attachment proof uses the dirty-worktree candidate, not HEAD alone. Simulated HOST
execution inside CONTAINER is not the user's actual host or consumer DinD proof.
No production test backdoor, compatibility token fallback, global prune, relaxed
probe, or standalone cleanup authority may be introduced. About 400 authored lines
per coherent work unit is advisory; report honest counts without artificial slices.

## Implementation authorization update

Implementation is already authorized by the owner. Effective TDD: **OFF**;
source: current user turn explicitly reports the owner's answer "No" to TDD.
Ordinary functional checks use the exact Bats and SemanticManifestTests runners
listed below, plus local/mocked AttachmentTests after effect inspection. No RED
requirement applies. Earlier unresolved-mode statements below are retained as
preparation history, not current blockers. No staging, commits, push, PR, native
review, Docker, lifecycle/build, network, install/update, or child agents.
Only the parent may archive or close this record. Future commit inclusion of the
owner's protected tool-version changes remains required after explicit approval.

## Objective and status

Allow attachment to the exact running development container despite bind-manifest
drift or a missing creation token, with sanitized warnings and no host mutation.
Preparation is complete; implementation and owner review are pending.
Locator: `odd/archive/nonblocking-container-attachment.md`.
Mirror topic: `odd/nonblocking-container-attachment/tasks`, project `gentle-starter`.

## Baseline and authorization

- CONTAINER workspace: `/home/ubuntu/gentle-starter`, host-owned bind mount.
- Observed branch: `test/gentle-shell-v4`.
- Observed HEAD: `3ee68e2d5330072e875317a07b3e4bae5f93e749`.
- The owner authorized implementation of the reviewed design, including tests
  and directly affected documentation. Only TDD-mode resolution is pending.
- No Docker, lifecycle/build, remote/network, install, or update execution.
- No staging or commits until explicit owner approval of the reviewed diff.
- Preserve `.devcontainer/tool-versions.conf` byte-for-byte. Its existing owner
  changes are intended for future commit inclusion only after that approval.
- Protected SHA256: `5dbe8b2e35ce97317c7def31614354b0477b48661181018097cb8324c23c5198`.
- No orchestration or child agents during preparation. Only the parent may close
  and archive this feature; implementation checkboxes are not review approval.

## Approved behavior

| Condition | Required outcome |
| --- | --- |
| Exact target running, verified snapshot/token agrees | Attach without preparation |
| Exact target running, desired binds drift | Warn and attach without mutation |
| Exact target running, creation token absent | Warn and attach without mutation |
| Exact target running, snapshot missing/invalid | Sanitized snapshot warning; attach |
| Exact target stopped or absent | Strict existing `container:up` path |
| Lookup/inspect failure or malformed/ambiguous inspection | Block; never infer absence |
| Entry invoked inside container | Skip the whole entrypoint before any effects |

Use only `DEVCONTAINER_BIND_MANIFEST_ID`; do not accept the old token name as a
fallback. A legacy running container can attach with a missing-token warning;
that warning must not authorize runtime volume repair, seeding, or SSH mutation.
Never recreate automatically. Recovery advice describes an intentional HOST
action, not permission to execute it. Do not change unrelated lifecycle behavior.

## Implementation map

- `.taskfiles/devcontainer.yml`: replace attachment's eager `ensure-running`
  preparation and `run-devcontainer` identity writes with one shared read-only
  attachment policy. Add whole-entrypoint guards to connect, opencode,
  opencode:server, pi, engram, and gentle-shell. Preserve each exec payload.
- `.taskfiles/scripts/compose-manifest.py`: reuse selection/project/projection
  and strict snapshot validation. Add narrowly scoped attachment inspection and
  warning policy, separate from `prepare` and strict `load_manifest(runtime=True)`.
  Inspect the exact resolved target and its state, not substring name matches or
  successful empty output from a failed pipeline. Sanitize parser/engine failures.
- `.devcontainer/docker-compose.yml` and token consumers/fixtures: rename creation
  token end-to-end without fallback, retaining strict runtime identity matching.
- `.taskfiles/scripts/container-connect.bash`: preserve local welcome behavior,
  applied-snapshot SSH checks, and nonblocking onboarding; no remote probes.
- Tests: `.devcontainer/test/unit/devcontainer-tasks.bats`,
  `compose-manifest-test.py`, and affected token fixtures, including
  `volume-repair.bats`, `tool-ownership.bats`, and `doctor.bats` after effect review.
- Future docs: only the directly affected attachment/token contract in
  `.devcontainer/docs/optional-integrations.md`, subject to implementation scope.

Prefer a small policy boundary shared by all six entrypoints, not six divergent
state machines. Active attachment must not call identity generation, directory
preparation, publication, or strict creation checks as hidden prerequisites.
Avoid globally relaxing helpers used by build/up/restart/remove/recreate.

## TDD source and runner

Effective explicit TDD on/off is **unresolved**, not inferred from old task memory.
Current runtime `/home/ubuntu/.config/opencode/opencode.json` orchestrator prompt
requires resolving mode from project/session configuration or explicit user choice.
Inspected `/home/ubuntu/.gentle-ai/state.json` has no TDD setting; there is no root
`.opencode` or `openspec` configuration. The tracked OpenCode seed describes
test-first defaults, but is not proof that the current runtime selected that mode.
Parent must resolve this ambiguity before implementation and forward the source,
mode, and exact runner. Preparation-only documentation has no meaningful RED.

The actual starter runner is Bats, not root `task test` (which exits 2 as
unconfigured). `.maintainer/tasks/test.yml` defines the full unit runner as
`bats .devcontainer/test/unit/*.bats .maintainer/test/unit/*.bats`; that full
selection is not authorized under the current restrictions.

## Actionable tasks and routes

- [x] NBA-01: inspect current HEAD/configuration/fixtures; create this record and
  read back its full project-scoped mirror. Report effective TDD ambiguity.
- [x] NBA-02: after implementation authorization and TDD resolution, add isolated
  failing behavior contracts covering the table above, all six entrypoint guards,
  exact target/state inspection, sanitized diagnostics, and forbidden writes.
- [x] NBA-03: implement shared attachment policy and token rename with those tests;
  record observed GREEN and focused refactor checks, or the resolved TDD exception.
- [x] NBA-04: prove strict runtime rejection of missing/mismatched/new-vs-old token,
  malformed snapshots, and legacy schema; preserve existing lifecycle sequencing.
- [x] NBA-05: update directly affected docs and tracking evidence; inspect the full
  diff and protected bytes; hand off unstaged work for owner review.
- [x] NBA-06: parent reconciles checks and explicitly accepted unavailable proofs;
  commits only on owner approval. Parent then archives safely, updates navigation
  and the full mirror under the same topic, and reads back both before closure.

Routes for future parent use: worker for bounded policy/test implementation;
verify for exact authorized deterministic checks; explore only if target/state
resolution remains unclear. Trigger delegation only when scope exceeds inline
capacity or independent evidence is needed. Supply exact edit surfaces, protected
bytes, authorization exclusions, TDD source/runner, and this locator. Workers do
not delegate, close, stage, commit, or infer Docker permission. No agents launched.

## Safe verification and observed evidence

Run from the CONTAINER workspace, without `FORCE_HOST_CONTEXT=1` in this checkout:

```bash
PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/devcontainer-tasks.bats .devcontainer/test/unit/container-connect.bats
PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/compose-manifest-test.py SemanticManifestTests -v
git diff --check
sha256sum .devcontainer/tool-versions.conf
git status --short
```

Preparation baseline: first command **20/20 PASS**; semantic class **12/12 PASS**.
These are existing behavior proofs, not RED/GREEN evidence for the new feature.
The Bats selection uses Task dry runs, shell function doubles for lifecycle calls,
mocked OpenCode processes/HTTP, local PTYs, fixture UNIX sockets, and generated
local SSH keys. It never connects to an agent, remote host, or Docker daemon.
The semantic class uses temporary directories and patched external operations;
late-publication races can create fixture state only, cleaned by the fixture.
Python bytecode writes are disabled. Supervisor fixtures briefly create and clean
temporary directories under the workspace, not managed runtime state.

Do not run the complete `compose-manifest.bats` wrapper: its Python suite invokes
real `docker compose version/config`, and one fixture forwards Compose to the real
binary. Do not assume a mocked startup makes the whole suite Docker-free.
Full maintainer suites, `task validate`, install diagnostics, and affected remaining
fixtures require effect inspection before approval; none is claimed as run here.
Any new focused test command must be listed and effect-reviewed before execution.
Native HOST attachment and stopped/absent startup proof remain unavailable under
this authorization. Host path is unknown; no operational recipe invents it.

## Forecast and delivery

- Preparation: one ODD record, local reads, two bounded test selections; no
  downloads/builds/images/shared cache. Expected temporary fixture disk: under
  20 MiB; observed tests completed within their 120-second outer deadlines.
- Implementation forecast: roughly 300–500 authored additions plus deletions
  across policy, six routes, token consumers, tests, and concise docs. This is an
  estimate, not a limit or approval; about 400 lines is advisory review capacity.
- Delivery strategy: `ask-on-risk`. If honest scope materially exceeds capacity
  or creates meaningful migration uncertainty, pause for parent/owner direction.
  No code golf, compressed tests, artificial file-type splits, or automatic PRs.
- Cohesive work unit: attachment policy plus tests, token migration, and directly
  affected docs. Rollback removes that behavior as a unit, never owner version edits.
- Future approved local checks: forecast 1–2 minutes, no network/build/cache;
  set explicit 120-second command timeouts. New fixture costs must be reforecast.
- Runtime boundary exists; mocked evidence does not prove native host execution.
  Report restricted native proof as unavailable, never PASS or silently N/A.
- Record future commit identity only after explicit owner approval of reviewed
  diff, including the preserved version changes if still requested. No commit now.

## Next step

Implementation is authorized. Parent resolves the explicit TDD mode before
delegating the source changes; no further implementation-scope approval is needed.

## Implementation handoff evidence

Current outcome: NBA-02–04 implemented and focused functional checks passed with
TDD OFF (current user authorization update above). NBA-05 documentation and
protected-byte checks completed; independent parent review remains pending.
NBA-06 remains parent-owned and incomplete. Earlier preparation statements and
checkboxes are historical; this handoff is not feature closure or review approval.

- Shared read-only `attachment` operation resolves the exact selected name,
  verifies lookup/inspection/state, and checks concurrent input changes. Running
  targets warn for drift or missing/unapplied/bad snapshots without preparation.
  Stopped/absent targets enter strict up; failures never imply absence.
- All six whole-entrypoint guards are covered. Caller search found
  `run-devcontainer` used only by those six attachments; its identity writes were
  removed without changing build/up/restart/remove/recreate preparation.
- Active token consumers and fixtures use `DEVCONTAINER_BIND_MANIFEST_ID` only.
  Old-name occurrences remain solely in a negative compatibility test and the
  historical archive. Runtime and SSH applied-snapshot checks remain strict.
- Rollback boundary: attachment policy/task routing, active token rename and
  related fixtures/docs as one unit; preserve owner tool-version changes.

Observed foreground commands, each with explicit 120000ms tool timeout:

```text
PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/devcontainer-tasks.bats .devcontainer/test/unit/container-connect.bats — 22/22 PASS
PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/compose-manifest-test.py SemanticManifestTests -v — 12/12 PASS
PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/compose-manifest-test.py AttachmentTests -v — 7/7 PASS
PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/volume-repair.bats — 18/18 PASS
git diff --check — PASS
sha256sum .devcontainer/tool-versions.conf — 5dbe8b2e35ce97317c7def31614354b0477b48661181018097cb8324c23c5198
git status --short — eleven tracked modified files and this untracked record; nothing staged
```

AttachmentTests use only temporary files and patched subprocesses. Volume-repair
effect review verified local fixture installers only, no Docker/network/install.
Doctor and tool-ownership fixtures were read but not executed; doctor contains
forced-host calls from the primary cwd, and additional runtime installer execution
was conservatively left for parent effect review. Native HOST attachment/startup
and full Docker/lifecycle proof are unavailable, not PASS. No native review,
staging, commit, push, PR, or archive occurred. Future commit must include the
unchanged protected owner version edits only after reviewed-diff approval.

Skill resolution: loaded all four exact requested skill files. The owner's
no-commit authorization overrides the work-unit skill's default commit closure;
400 lines remains advisory and no delivery-size branch/PR decision was invoked.

## Attachment harness handoff evidence

NBA-07–09 are implemented with ordinary focused testing, TDD OFF. Checkbox NBA-02
records observed functional contracts, not an invented failing-test/RED run.
NBA-06 remains parent-owned. No archive, closure, new review, or live proof is claimed.

New opt-in `--attachment` retains the existing registration/probe/inventory/cleanup
engine and dirty-worktree overlay. Only the candidate connect payload is adapted;
actual Task policy and CLI execution remain. Drift and tokenless running fixtures
compare exact synthetic applied/generated env, manifest, managed bytes/metadata,
mounts and full IDs. Stopped/absent success and duplicate-locale rejection use
actual connect routing. Tokenless creation reuses the built image and registered
labels/mounts; there is no old-name fallback or primary provisioning bypass.

Final observed foreground commands (each tool timeout 120000ms):

```text
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/starter-lifecycle-test.py -v — 32/32 PASS
PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/devcontainer-tasks.bats .devcontainer/test/unit/container-connect.bats — 22/22 PASS
PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/compose-manifest-test.py SemanticManifestTests AttachmentTests -v — 19/19 PASS
PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/volume-repair.bats — 18/18 PASS
git diff --check — PASS
sha256sum .devcontainer/tool-versions.conf — 5dbe8b2e35ce97317c7def31614354b0477b48661181018097cb8324c23c5198
```

Harness tests block all unmocked check_output/run/Popen calls. Initial harness runs
exposed missing Pi and Gentle Shell Compose fixture copies (30 passes, two errors
each); both fixture omissions were fixed before the final 32-pass run. Not live
coverage: interactive rcfile, other TUI entrypoints, unrelated similarly named
containers, injected engine failures, optional integrations, actual user HOST or
consumer DinD. Docker/build/lifecycle/network/install/update/remote never executed.

Future separately authorized CONTAINER invocation:
`task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle -- --attachment`.
This is simulated HOST inside CONTAINER. Forecast: one explicit base build/recreate,
two successful additional startups and two rejected attempts; CLI may rebuild or
download on startup. Significant image/build disk and minutes of setup, unmeasured;
initial 30-minute soft budget with a longer outer deadline for cleanup, reforecast
after inspecting hooks/cache. Shared build cache/private diagnostics retained.
Running attach bound: 120 seconds; startup: 600 seconds, then 10-second kill grace.
Recipes are not execution authorization.

Coherent rollback: remove optional harness scenario, its mocked contracts and docs;
preserve pre-existing attachment/token implementation and owner tool-version bytes.
Implementation/test/docs authored count: 397 additions plus deletions against HEAD,
excluding the pre-existing two-line harness token rename; ODD tracking is additional.
No artificial slices, code golf or delivery action. All changes remain unstaged.
Skill resolution: all four requested files loaded; no-commit/no-child-agent rules
override skill defaults. Parent review and separately authorized live proof are next.
