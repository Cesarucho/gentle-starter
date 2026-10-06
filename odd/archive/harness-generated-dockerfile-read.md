# Harness-only generated Dockerfile read adapter

## Parent reconciliation and implementation closure

Authorized implementation, ownership extension and local commit grouping are
complete. Current locator: `odd/archive/harness-generated-dockerfile-read.md`.
Recovery mirror: `odd/harness-generated-dockerfile-read/tasks`, project
`gentle-starter`. All prior sections remain historical evidence, not current
pending implementation or delivery restrictions.

The owner approved the six coherent local commit groups after the full-diff
grouping review. Groups 1–5 are committed:

| Group | Commit | Verified scope |
| --- | --- | --- |
| 1 | `278852943aee52f9e44c6142f2a325f12554a58e` | Running attachment and bind identity; 338 changed lines |
| 2 | `a8d339c2789142dfcd9d02874561333482fe9d0d` | Isolated Task attachment scenario; 400 changed lines |
| 3 | `53b8456d8c97c4565be6e8f9199f1bc4322f250b` | Registered producer identity; 184 changed lines |
| 4 | `19cf58d60af60d55015d2978cb7707d38284502e` | Optional exact-file adapter; 903 changed lines |
| 5 | `e30553e12d4ced17cc49471a6beb83ca0ddece80` | Unchanged owner version/lock edits; 40 changed lines |

Each implementation boundary was materialized from its exact indexed Git tree
before commit. Independent verifiers confirmed bytes, file types, symlink targets
and Git executable modes. Extraction umask changes literal tar permission bits,
not the Git mode identity. Independent focused checks passed: group 1, 59 tests;
group 2, 32; group 3, 52; group 4, 60 (25 adapter and 35 lifecycle). Group 4's
writer also passed all 52 ownership tests, for 112 focused checks at that boundary.
Group 5 passed full structural inspection, assignment validation, staged-blob
equality and the protected SHA-256 check. No test failure is outstanding.

Candidate 1 native review was explicitly declined for that candidate only.
Candidate 2's selected decline invocation refused before mutation because global
RDD was OFF. The parent confirmed OFF and did not reactivate or invoke later
reviews. Native assessment classified group 3 high and group 5 medium; group 4's
initial assessment was unavailable due to inventory selection and therefore treated
as high with independent verification. A later group 4–5 range assessment was
high. These assessments and functional checks are not native review approval;
delivery remains disabled/unmanaged by review policy.

All source bytes are preserved, including the owner's tool-policy SHA-256
`5dbe8b2e35ce97317c7def31614354b0477b48661181018097cb8324c23c5198`.
No push, PR, merge, Docker build, native plugin execution, operational retry, or
retained-run cleanup occurred during commit grouping. The previously failed live
run remains retained and unmodified. Native forwarding and real attachment proof
are still unproved. HGDR-06 is optional, separately authorized future work, not an
unfinished part of the approved implementation-only scope.

Group 6 commits these reconciled audit records; its identity is recorded in the
session handoff after creation, rather than attempting a self-referential hash.
No current navigation references outside this record needed updating. Parent
archival and full mirror readback precede the final delivery report. Next optional
step: authorize a fresh isolated attachment run with the explicit exact-file read
selector after a renewed cost/environment forecast; never silently retry.

## Objective and current authority

Prepare an optional durable adapter that grants Bake read access to exactly one
validated Dev Containers-generated Dockerfile during the base attachment proof.
Implementation is authorized for a later source-writing phase; this worker phase
creates this record only. No source implementation or operational proof is complete.
Only the parent may close or archive this ODD record.

- Execution context: CONTAINER, repository `/home/ubuntu/gentle-starter`.
- Observed branch: `test/gentle-shell-v4`.
- Observed HEAD: `3ee68e2d5330072e875317a07b3e4bae5f93e749`.
- TDD: **OFF**, current explicit user choice **No** retained. Tests are still required;
  no test-first workflow or review approval is inferred.
- Delivery: `ask-on-risk`; leave edits unstaged and uncommitted for owner diff approval.
- No Docker invocation, including `info`, build, network, installation, remote action,
  staging, commit, retry, cleanup, or child agent is authorized in this phase.
- A future live proof requires separate explicit authorization and a cost forecast.

Preserve all prior dirty attachment/scenario and owner files. In particular, preserve
`.devcontainer/tool-versions.conf` SHA-256
`5dbe8b2e35ce97317c7def31614354b0477b48661181018097cb8324c23c5198`.
Do not modify or clean failed run `cf8e6de7-c745-4ab2-9721-3e7a4a2966c5`, its
scratch, inventory, logs, or resources. Prior native byteprobe success and retained
build failure are historical evidence, not authority to replay a producer.

## Bounded design

Propose harness selector `--allow-generated-dockerfile-read`, accepted only together
with `--attachment`, rejected with `--consumer` or without attachment before run
registration. Keep the existing default and `--daemon-visible-scratch ABSOLUTE_PARENT`
behavior. This is a new harness flag, not an invented Compose or Buildx option.

Use one small Python adapter with explicit validation helpers and a thin executable
`docker-buildx` entry point. Select it through `cliPluginsExtraDirs` in the isolated
run's private Docker config, with explicit `DOCKER_CONFIG` for the producer.
No global config, consumer configuration, tool installation, or default activation.
Do not change the ownership inventory schema unless the existing contract genuinely
cannot express the required binding; report that risk before expanding scope.

### Authorization checks before granting Bake access

1. Validate native Buildx's canonical executable path, regular-file type, owner,
   non-writable-by-untrusted-users mode, and SHA-256 pinned from the actual executable
   at future run startup. Do not hardcode the scratch adapter's historical hash as
   durable policy. Recheck before delegation; refuse executable replacement.
2. Require the fixed local endpoint and matching registered daemon identity using
   the ownership contract during a separately authorized live run. An environment
   variable alone is not daemon proof. This preparation never invokes Docker.
3. Reuse private inventory validation, scratch inode/owner marker and candidate
   bindings. Require armed, pending base run, eligible producer stage and no completed
   exit. Bind invocation to the live registered worker's process ancestry/session
   and process start identity, not merely `worker > 0`, PID existence, or a label.
   Retained/completed runs and stale/replayed producers must fail closed.
4. Bound stdin size; accept only the known Compose-to-Bake JSON/argv shape, one
   `container-svc` target, exact candidate context, expected image and run label.
   Reject unknown input files, alternate targets/groups, overrides or options that
   could alter paths/access. Preserve only the exact expected candidate-context
   read grant; add exactly `--allow fs.read=<validated generated regular file>`.
5. Bind the immediate Compose parent, project, candidate base/core Compose inputs,
   and exactly one CLI-generated build override to the same live producer. Validate
   the override's Dockerfile reference structurally; filename pattern alone is not
   provenance. Inspect actual installed shapes before codifying the accepted grammar.
6. Validate canonical generated file and parent ownership, no symlinks or special
   files, bounded size, and no group/world writes. Require the candidate base bytes
   exactly once in the supported generated layout, with only the validated metadata
   prefix/suffix and expected base/target relationship. A substring plus an arbitrary
   suffix is insufficient. Reject unsupported Features or changed generation shape.
7. Reject foreign/additional contexts, inline Dockerfiles, secrets, SSH, network/device
   entitlements and every broad/write/wildcard filesystem grant, including alternate
   argv encodings. Reject unknown Bake access-bearing fields instead of silently
   forwarding them. No filesystem directory grant for generated inputs.

### Delegation and race limits

Delegate plugin metadata (`docker-cli-plugin-metadata`) and every non-Bake command
unchanged to the validated native Buildx, preserving argv, stdin, environment and
exit behavior. Non-Bake paths must never append or transform permissions. Native
plugin protocol support is required; do not emulate its metadata JSON.

Freeze validated stdin bytes in a bounded descriptor for native delegation. Read
files without following symlinks; compare descriptor identity, mode, owner and hash
and revalidate pathname/parent/inventory/process identities immediately before exec.
Pin the native executable's actual bytes for this run and detect replacement.
The generated file remains an exact pathname read by native Buildx: pre-exec checks
cannot eliminate a malicious same-user post-check pathname replacement. State this
limitation explicitly; this is a narrow cooperative harness adapter, not a security
sandbox. Do not claim file hashes or process labels prove otherwise. If the accepted
producer shape cannot be bound adequately, stop rather than broaden the grant.

## Authorized future source roots and stable tasks

| ID | Work | State / acceptance |
| --- | --- | --- |
| HGDR-01 | Preparation and full record mirror | Prepared; source remains unchanged |
| HGDR-02 | Opt-in parser and isolated config wiring | Implemented; 35 lifecycle tests pass; defaults and consumer unchanged |
| HGDR-03 | Narrow adapter and native delegation | Implemented; exact grammar and mocked delegation only; native forwarding unproved |
| HGDR-04 | Mocked positive/rejection tests | Verified locally; 25 source-backed adapter tests pass; no real Docker execution |
| HGDR-05 | Documentation and bounded local checks | Documentation updated; focused checks recorded below; no live proof |
| HGDR-06 | Separately authorized fresh live attachment proof | Not authorized now; never reuse failed run |

Future files, all under the maintainer harness boundary:

- `.maintainer/test/lifecycle/starter-lifecycle.py`: selector and isolated wiring.
- `.maintainer/test/lifecycle/generated-dockerfile-read.py`: proposed focused adapter.
- `.maintainer/test/lifecycle/narrow-plugins/docker-buildx`: proposed thin entry point.
- `.maintainer/test/unit/starter-lifecycle-test.py`: selector/config regression cases.
- `.maintainer/test/unit/generated-dockerfile-read-test.py`: proposed mocked adapter suite.
- `.maintainer/README-distribution.md`: explicit opt-in, boundaries and live-proof recipe.

Read `.maintainer/test/lifecycle/test_resources.py` as ownership authority; mutation
is not planned. No `.devcontainer/`, `.taskfiles/`, installer, consumer, or global
Docker configuration source changes. Preserve existing edits within the allowed
files rather than replacing them wholesale.

Routing triggers: design-patterns for adapter structure; work-unit-commits for
cohesive source/tests/docs and rollback; markdown-documentation and cognitive-doc-design
for documentation. If tool provisioning/provider ownership changes become necessary,
stop and load add-tool rather than expanding this harness-only task. If external CLI
documentation is needed, load context7-mcp; no network in this phase. No delegated
agent is launched. Parent-only ODD closure and native review authority remain intact.

## Acceptance and rejection evidence required

- Positive fixture: supported metadata-only generated Dockerfile, exact candidate,
  live mocked producer and override; native receives identical input plus one exact
  generated-file read grant. Valid metadata/non-Bake calls delegate unchanged.
- Default/selector fixtures: no adapter without opt-in; reject consumer combination,
  standalone opt-in, malformed flags and config escaping the isolated run home.
- Ownership fixtures: foreign record/candidate/project/daemon, unarmed or retained
  run, exited worker, reused PID/start time, unrelated parent and stale override fail.
- Input fixtures: multi-target, foreign context, altered Dockerfile relationship,
  duplicate base bytes, unsupported metadata/Features, symlink/special file, wrong
  owner/mode, oversized/malformed JSON, duplicate JSON keys and changed file fail.
- Permission fixtures: broad/read-directory/write/fs.* grants, secrets/SSH/network/
  devices, additional contexts, inline Dockerfile and access-changing argv fail.
- Race fixtures: input, override, record, executable or producer replacement before
  delegation fails; mocked native exec only. Assert no native exec on rejection.
- Preserve owner hash and baseline dirty work; no real daemon proof claimed by mocks.

## Exact local verification and effects

Run from the CONTAINER repository root only after future implementation and effect
inspection. These are planned commands, not commands executed during preparation.

```bash
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/starter-lifecycle-test.py
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/generated-dockerfile-read-test.py
git diff --check -- .maintainer/test/lifecycle .maintainer/test/unit .maintainer/README-distribution.md odd/tasks/harness-generated-dockerfile-read.md
sha256sum .devcontainer/tool-versions.conf
git diff --stat
git status --short
```

The inspected existing Python runner mocks subprocess entry points and creates
temporary synthetic fixture files; its unittest cleanup removes only its own
temporary fixtures. The new runner must follow the same model, mock producer,
daemon and exec boundaries, and be inspected before execution. Neither may invoke
Docker, Task lifecycle, installers, network, commits or retained-run cleanup.
Git checks and hashing are read-only; bytecode generation is disabled.
Do not run aggregate Task suites: they include other effects outside this scope.
Live runner recipe remains pending HGDR-06 authorization, with downloads/time/disk/
cache forecast and explicit external timeout before launch.

## Workload, delivery and rollback

Forecast authored additions/deletions: adapter and entry point 180–260 / 0; wiring
35–65 / 5–15; tests 150–230 / 0–10; documentation 20–40 / 0–5. This record adds
about 190 lines. Total forecast exceeds 400 authored changed lines; 400 is advisory,
not permission to compress checks or omit tests. One coherent adapter behavior unit
keeps code/tests/docs together. Use `ask-on-risk` if actual scope or review workload
requires a delivery decision; no automatic PR slicing, staging or commit.

Rollback removes only the newly added adapter, selector/config wiring, associated
new tests and documentation from this work unit. Preserve pre-existing attachment
tests/scenario and ownership behavior. No failed scratch cleanup is part of rollback.

## Preparation evidence and next step

Current local inspection confirmed branch/HEAD, dirty baseline, preserved owner hash,
existing isolated HOME/local endpoint, attachment/consumer parser exclusion, and the
stopped-producer registration/lease handshake in `Run.produce`. Installed CLI package
is 0.89.0. Native Buildx file hash is
`982ca20490b45ed1ec8d99795974d3d874a358f75938c9c237305010e6b7e548`.
Installed plugins are binaries; no textual plugin help/source was available in their
directory and no plugin help executable was invoked. Prior investigation reports
Compose 5.5.1 and Buildx 0.37.2; those versions are not newly executed proof here.

The scratch adapter at
`/home/ubuntu/shell-retry-QW0zZttK/source/.maintainer/test/lifecycle/narrow-plugins/docker-buildx`
was read as evidence only. Its hardcoded daemon/version/hash, positive worker PID,
substring checks and pre-exec pathname validation are not a durable authority model.
No Docker, build, live test, source write, retry or cleanup occurred in preparation.

Next: parent reads back this record and full Engram mirror, then implements
HGDR-02–05 within existing authorization. Keep HGDR-06 blocked on separate consent.

## Implementation scope checkpoint

HGDR-02–05 implementation was authorized, but remains **blocked / partial** at
the ownership boundary. No adapter, selector, config wiring, or new tests were
written. Only this checkpoint was appended; earlier dirty source is preserved.

`test_resources.py:83–95` validates a closed inventory schema. Its producer
registration (`311–330`) records only `process.pid`, saves the inventory, and
releases the stopped worker. It does not record a process-start identity.
`check_worker` (`457–465`) checks process-group presence for recovery, not the
identity of an active invocation. A start time first observed by the adapter
cannot establish that it belongs to the originally registered producer: it pins
the process currently occupying that PID instead. An exclusive lease alone is
not the missing registered process-start evidence.

The required PID-reuse rejection therefore lacks a registration-time anchor in
the existing ownership contract. No alternate producer identity authority or
copied producer engine was introduced. Parent review must resolve whether a
bounded ownership-contract extension is authorized before implementation resumes;
this worker does not expand the source allowlist or mutate ownership metadata.

Observed safe check in CONTAINER, with explicit 120000 ms supervisor timeout:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/starter-lifecycle-test.py
```

Result: **PASS, 32 tests, 0.041 seconds**. Fixture inspection confirmed temporary
synthetic files and fail-fast mocks for `check_output`, `run`, and `Popen`.
No new adapter runner exists, so its planned command was not executed. No native
plugin discovery, Bake forwarding, daemon, live attachment, or new adapter
functional proof is claimed. No Docker invocation, network, retained-run access,
cleanup, staging, commit, PR, or child agent occurred. HGDR-06 remains unauthorized;
only the parent may close or archive this record.

Read-only checks also passed: the scoped `git diff --check` command listed above,
`sha256sum .devcontainer/tool-versions.conf` (preserved expected hash),
`git diff --stat`, and `git status --short`. The stat reports earlier tracked dirty
work, not this worker's authorship; this worker appended 42 documentation lines.
Two patch-context mismatches while removing a transient documentation typo made
no changes; the corrected patch succeeded before final checks. No test failed.

## Approved producer identity extension

The user explicitly approved the recommended bounded ownership extension before
resuming source implementation. The preceding checkpoint is historical evidence;
its scope blocker is **superseded by this approval**, not deleted or treated as
completed implementation. HGDR-02–05 are now authorized together with HGDR-07 below.
HGDR-06 remains optional future live work and is not authorized.

| ID | Work | State / acceptance |
| --- | --- | --- |
| HGDR-07 | Pin stopped producer identity before release | Implemented; 52 ownership tests pass; legacy evidence remains readable |

Added source authority: `.maintainer/test/lifecycle/test_resources.py` and the
related isolated runner `.maintainer/test/unit/test-resources-test.py`. Reuse the
existing lease and stopped-worker handshake; never create a parallel ownership
engine. Record the original worker PID/start/session identity before release,
validate the typed anchor, and clear it when inactive. Missing legacy anchors
remain valid for existing read-only preview/recovery policy but cannot authorize
the new adapter. Never fabricate an anchor or rewrite retained old inventories.
PID reuse must not permit signaling an unrelated group. Tests must prove durable
record-before-release and no release after failed identity/save/reuse checks.

All earlier execution restrictions, preservation rules, TDD OFF, unstaged delivery
and parent-only closure remain unchanged. This approval adds no Docker execution,
network, cleanup, commit, native review, or live-proof authority.

## Implementation and observed functional evidence

HGDR-02–05 and HGDR-07 now have local implementation and isolated functional
evidence. Earlier preparation and blocked checkpoints above remain historical;
they are not current implementation status. Parent reconciliation/review/closure
has not occurred. No archive or delivery action is authorized.

The additive optional `producer` anchor records typed PID/start-ticks/session/boot
identity in the existing inventory before handshake release. It is rechecked
before release and before signaling the original unreaped child group, then
cleared when inactive. Old records are neither migrated nor assigned fabricated
anchors; existing preview/recovery policy remains in place. Adapter authorization
requires the new complete anchor and an active existing ownership lease.

The adapter accepts a deliberately closed fixture JSON/argv grammar. Local CLI
source and retained generated files established the metadata-only 0.89.0 Dockerfile
and structural Compose override shape; those files were read, never changed or
replayed. Native Compose's actual Bake JSON/argv emission was not executed or
confirmed. Any unrecognized field or option, including additional native metadata
output options, fails closed. A future authorized live run may expose unsupported
native shapes; this implementation never broadens grants automatically.

All focused commands ran foreground in CONTAINER with explicit 120000 ms tool
timeouts, after inspection of fail-fast subprocess, daemon, exec, signal and
process fixtures. Temporary-file cleanup is limited to each runner's synthetic
fixtures; no retained-run inventory, scratch or resources were mutated.

| Exact command | Final observed result |
| --- | --- |
| `PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/starter-lifecycle-test.py` | PASS: 35 tests, 0.042 s |
| `PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/generated-dockerfile-read-test.py` | PASS: 18 tests, 0.128 s |
| `PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/test-resources-test.py` | PASS: 52 tests, 0.110 s; expected synthetic recovery-refusal diagnostic |

Initial focused passes were 34/15/52 tests before adding more isolated coverage;
final passes above include that coverage. No required test command failed and no
RED evidence is claimed. One combined patch-context mismatch made no changes and
was corrected before verification. New adapter/source entry points were normalized
to `0755` before the final functional checks. No aggregate suite, native plugin,
Docker command, live scenario, network, installer, remote channel, staging,
commit, cleanup of retained runs, or child agent was used.

An additional passing adapter fixture covers sanctioned restoration of candidate
core Compose bytes after desired-bind drift. Startup candidate pins require exact
bytes/owner/mode, while each invocation pins full descriptor/path identity until
exec; native executable startup pins remain strict, including replacement checks.
This preserves the existing attachment scenario without accepting changed core
content. Intermediate 35/17/52 passes preceded this added fixture; final commands
above were rerun after the correction, without any failed test command.

Read-only repository checks passed: the scoped `git diff --check` command listed
above, `sha256sum .devcontainer/tool-versions.conf` (exact protected hash),
`git diff --stat`, and `git status --short`. The tracked stat includes preserved
earlier dirty work; new untracked adapter/test files are not included in that stat.
An AST-only parse of the three new Python entry points passed without executing
them; all three reported mode `0755`. Native discovery/forwarding and full live
behavior remain unproved, not inferred from AST or mocks.

Authored source/test/README changes for this resumed phase total 962 added/deleted
lines, plus the ODD record update. This exceeds the advisory forecast; no checks
were compressed, and no delivery action or automatic slicing was performed.

## Published-source contract reconciliation

The user authorized this bounded reconciliation based on independent verification,
not a native-review correction. Ownership source/model is unchanged in this phase.
Read-only public Context7 and web-fetch tools were authorized; no network shell
command, Docker/Buildx/Compose invocation, remote execution or live run was used.
The preceding fixture-only grammar claim is historical, not native compatibility
evidence. The following published version code supplies documentary evidence.

| Exact public source URL | Functions / documentary contract |
| --- | --- |
| <https://raw.githubusercontent.com/docker/compose/v5.5.1/pkg/compose/build_bake.go> | `bakeArgs`: `bake --file - --progress rawjson --metadata-file PATH --allow fs.read=CONTEXT` in that order; `bakeMetadataPath`: absent `os.TempDir()/compose-build-metadataFile-UUID.json`; `doBuildBake`: direct plugin executable with JSON stdin |
| <https://raw.githubusercontent.com/docker/compose/v5.5.1/pkg/compose/build_bake.go> | `bakeTarget` uses `omitempty`; `prepareBakeBuild` emits configured values; `bakeOutputs` defaults to `["type=docker"]`; `dockerFilePath` canonicalizes the directory |
| <https://raw.githubusercontent.com/docker/compose/v5.5.1/pkg/compose/build.go> | `getImageBuildLabels` adds Compose version/project/service labels to build labels |
| <https://raw.githubusercontent.com/docker/compose/v5.5.1/pkg/api/labels.go> | Label names and `ComposeVersion` core-version normalization (`5.5.1`, not `v5.5.1`) |
| <https://raw.githubusercontent.com/docker/compose/v5.5.1/pkg/compose/shellout.go> | `prepareShellOut` removes the plugin reexec marker for standalone Buildx; `propagateDockerEndpoint` supplies the context/host and TLS variables when applicable |
| <https://raw.githubusercontent.com/docker/cli/v29.8.1/cli-plugins/manager/manager.go> | `PluginRunCommand` uses `os.Args[1:]` unchanged, so `docker compose ...` retains the leading `compose` token in the plugin process |
| <https://raw.githubusercontent.com/docker/compose/v5.5.1/cmd/main.go> | `main` supports direct standalone invocation; Go argument conversion does not rewrite the kernel's original cmdline |
| <https://raw.githubusercontent.com/docker/buildx/v0.37.2/cmd/buildx/main.go> | `runStandalone` versus `runPlugin`; native owns metadata and argument parsing |
| <https://raw.githubusercontent.com/docker/buildx/v0.37.2/go.mod> | Embedded Docker CLI dependency is `v29.7.2+incompatible` |
| <https://raw.githubusercontent.com/docker/cli/v29.7.2/cli-plugins/plugin/plugin.go> | `RunningStandalone` uses the reexec marker; `newPluginCommand` registers the plugin subcommand |
| <https://raw.githubusercontent.com/docker/buildx/v0.37.2/commands/bake.go> | `bakeCmd`/`runBake`: explicit stdin file, rawjson entitlement checks, metadata output and default group resolution; no adapter permission broadening |

The canonical parent grammar now strips at most one leading `compose` token;
direct executable form remains supported, but arbitrary Docker global prefixes
and duplicate tokens fail closed. Compose's Bake shell-out is unprefixed `bake`
with no reexec marker. A canonical Docker CLI `buildx bake` form requires that
marker; original native argv/environment are preserved on delegation.

The minimal JSON whitelist requires context, Dockerfile, fixed args, exact tags,
the run plus Compose version/project/service labels and `["type=docker"]` output.
An optional target must equal `dev_containers_target_stage`. Zero-value platform,
cache, attestation and similar fields are omitted by the published Go type for
this reduced fixture, not accepted generically; present non-base/access-bearing
fields fail closed. `annotations` is not a 5.5.1 `bakeTarget` JSON field.

The original native metadata output argument is constrained to an absent canonical
`/tmp/compose-build-metadataFile-UUIDv4.json`, including rejection of dangling
symlinks; absence and parent identity are rechecked before exec. No output file is
created by the adapter, and no filesystem write or directory grant is appended.
Default/empty context is accepted; foreign context and TLS/certificate overrides
are rejected without changing metadata/non-Bake forwarding.

Local package metadata reports moby-cli `29.8.1`, moby-compose `5.5.1`, and
moby-buildx `0.37.1`; this differs from the earlier historical Buildx `0.37.2`
report and does not prove the pinned binary's runtime version. Published 0.37.1
`cmd/buildx/main.go` was also read and has the same standalone/plugin entry logic.
No executable was launched to settle installed binary identity/version. Two
auxiliary guessed source paths returned 404; the required contracts above were
retrieved at their correct published paths, not filled in from guesses.

Source-backed fixtures replace the earlier manually invented Bake flags/minimal
labels. They test exact metadata output constraints, standalone/plugin forms,
Compose parent prefixes, output/stage restrictions and non-base field rejection.
All execution/process boundaries remain mocked. Documentary contract agreement
is not observed native forwarding or live attachment proof; HGDR-06 remains
unauthorized and parent-only review/closure/archive authority is unchanged.

Reconciliation functional checks, foreground CONTAINER with explicit 120000 ms
timeouts, after mode normalization and mocked fixture inspection:

| Exact command | Observed result |
| --- | --- |
| `PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/starter-lifecycle-test.py` | PASS: 35 tests, 0.043 s |
| `PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/generated-dockerfile-read-test.py` | PASS: 25 tests, 0.193 s |
| `PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/test-resources-test.py` | PASS: 52 tests, 0.113 s; expected synthetic refusal diagnostic |

No required test failed. One combined patch-context mismatch made no changes and
was corrected before normalization and verification. TDD remains OFF; no RED or
native review evidence is inferred. Earlier scenario and ownership edits remain
unchanged in this phase. Runtime compatibility/live forwarding remain unproved.

Scoped `git diff --check` passed. Protected tool-policy SHA-256 remains exactly
`5dbe8b2e35ce97317c7def31614354b0477b48661181018097cb8324c23c5198`;
`git diff --stat` and `git status --short` were read-only checks of preserved work.
AST-only parsing passed for adapter/tests; executable modes remain `0755`.

Authored source/test/README changes in this reconciliation total 152 added/deleted
lines, plus this ODD update. No staging, commit, archive or native review occurred.

## Approved six-commit delivery checkpoint

The user subsequently approved six proposed local work-unit commits with indexed
boundary verification. This supersedes earlier no-staging/no-commit delivery
restrictions only for those approved groups; historical evidence is preserved.
TDD remains OFF. No push, PR, live Docker, network, installation, source semantic
fix, child review orchestration, or ODD closure/archive is authorized here.

This worker is authorized for group 1 only: `fix(container): attach to running
targets without preparing binds`. Include the complete current diffs in
`.devcontainer/docker-compose.yml`, `.devcontainer/docs/optional-integrations.md`,
`.devcontainer/test/unit/{compose-manifest-test.py,devcontainer-tasks.bats,doctor.bats,tool-ownership.bats,volume-repair.bats}`,
`.taskfiles/devcontainer.yml`, and `.taskfiles/scripts/compose-manifest.py`, plus
only the `assert_state` creation-token rename in
`.maintainer/test/lifecycle/starter-lifecycle.py`. Exclude its shlex, no-trunc,
attachment-scenario and adapter hunks. Rollback is exactly this behavior boundary,
not later harness, ownership, policy, or ODD work.

Groups 2–6 remain the parent's approved plan and are not authorized for this worker.
The delegated instructions identify protected tool policy as group 5; they do not
provide the other groups' exact messages/path boundaries, so this record does not
invent them. Parent reconciliation must retain the complete six-group plan before
proceeding. Keep this record and other ODD documents out of group 1.

Before committing, materialize `git write-tree` with `git archive` into an owned
isolated `/tmp/opencode` fixture, preserving tracked executable modes and symlinks.
Run the two explicitly authorized focused commands there with 120000 ms foreground
timeouts; never treat complete-worktree tests as boundary proof. Record the exact
tree, results and commit below. Native assessment/review remains parent-owned and
must occur after this commit before the next group. Live runtime proof is N/A for
this authorization: only inspected local/mocked fixtures may execute.

### Group 1 observed commit evidence

- Commit: `278852943aee52f9e44c6142f2a325f12554a58e`.
- Parent: `3ee68e2d5330072e875317a07b3e4bae5f93e749`.
- Indexed and committed tree: `090d3611b57a47d7d676a730967ef156556abe84`.
- Exact message: `fix(container): attach to running targets without preparing binds`.
- Scope: the ten paths above; 288 additions, 50 deletions, 338 changed lines.
  Staged full diff/raw modes reviewed; all ten remain `100644`; no secrets found.
- Fixture: `/tmp/opencode/commit1-index-UFDV2Pnb`, materialized exclusively from
  the indexed tree via `git archive`; no later-group worktree hunks included.
- Foreground CONTAINER checks, each with explicit 120000 ms tool timeout:
  `PYTHONDONTWRITEBYTECODE=1 bats .devcontainer/test/unit/devcontainer-tasks.bats .devcontainer/test/unit/container-connect.bats .devcontainer/test/unit/volume-repair.bats`
  passed all 40 tests, no skips;
  `PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/compose-manifest-test.py SemanticManifestTests AttachmentTests -v`
  passed all 19 tests in 0.051 s.
- `git diff --cached --check` passed. Commit ran without bypassing hooks or amend;
  observed committed tree exactly equals the verified indexed tree. Index is empty.
- Source-byte fingerprint (tracked and untracked source, excluding ODD) remained
  `15e53eeb25665b98b7073aeccef9673ef4ff7456` before staging and after commit.
  Protected tool-policy SHA-256 remains the exact value documented above; it is
  uncommitted. All later worktree changes remain present; only this record changed.
- No push, PR, live Docker, network, install, child/native review, or retained-run
  mutation. Isolated fixture is retained pending narrowly scoped cleanup.
- Skill resolution: `work-unit-commits` and `markdown-documentation` loaded.
  Parent native assessment/review and complete six-plan reference reconciliation
  remain pending; no next group, ODD closure, or archive was performed.

### Group 2 authorization, review status and observed evidence

The user authorized group 2 only for this continuation. Parent reports independent
verification of 59 tests against group 1's exact committed tree. The user explicitly
declined native review of candidate 1: `declined_this_candidate`, risk **high**,
candidate-scoped decline only. This is not review approval or a future-candidate
waiver. Each subsequent current commit has a separate parent-owned review decision.

The supplied six-group references are: group 1 attachment (338 changed lines),
group 2 isolated attachment scenario (400), group 3 producer identity (184), group 4
adapter (903), group 5 owner tool policy (40), and group 6 audit records (740).
Exact messages supplied here are group 1's recorded message and group 2's message
below; no exact message for groups 3–6 was supplied, so none is invented.

- Commit: `a8d339c2789142dfcd9d02874561333482fe9d0d`.
- Parent: `278852943aee52f9e44c6142f2a325f12554a58e`.
- Indexed and committed tree: `0a395bdaea49c7f2fd481e775a76730e21b000e3`.
- Message: `feat(test): add isolated Task attachment lifecycle scenario`.
- Paths: `.maintainer/README-distribution.md`,
  `.maintainer/test/lifecycle/starter-lifecycle.py`, and
  `.maintainer/test/unit/starter-lifecycle-test.py`; **392 additions, 8 deletions**.
- Git plumbing reconstructed only the indexed intermediate blobs from reviewed
  final content. Complete staged diff and modes reviewed; all three remain
  `100644`, no secrets found. Adapter selectors/imports/preparation, three
  `test_generated_read` methods, optional adapter documentation, producer identity,
  owner tool policy, and ODD records are excluded. No new ownership anchor needed.
- Indexed tree materialized with `git archive` in
  `/tmp/opencode/commit2-index-S2FShdp6`, preserving tracked modes and symlinks.
  Foreground CONTAINER command with explicit 120000 ms timeout:
  `PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/starter-lifecycle-test.py -v`
  **PASS: 32 tests, 0.040 s**, local/mocked execution only. No live runtime proof;
  live scenario is N/A under current no-Docker authorization.
- `git diff --cached --check` passed. Normal commit without hook bypass/amend;
  committed tree exactly matches the tested indexed tree; index is empty.
- Source-byte fingerprint excluding ODD remained
  `15e53eeb25665b98b7073aeccef9673ef4ff7456` before staging and after commit.
  All final source worktree bytes and later-group edits remain unchanged; protected
  tool-policy SHA-256 remains the documented exact hash, uncommitted.
- Rollback boundary is this three-file attachment scenario/tests/documentation
  unit only, preserving group 1 and all later work. Fixture retained; no cleanup.
- Skills: `work-unit-commits`, `markdown-documentation` loaded. No Docker, network,
  source semantic edits, push/PR, child/native review, ODD closure or archive.
  Parent review decision for candidate 2 remains pending before any next group.

### Group 3 evidence and corrected current review authority

Parent confirms global RDD OFF; do not enable RDD or invoke native review.
Candidate 1's exact action was `declined`. Candidate 2's user selection was omit,
but its native decline invocation was refused `rdd_disabled` at `pre_native`,
without mutation. No review approval or receipt exists for that invocation.
These actual outcomes clarify the earlier pending/candidate-decline descriptions;
history remains intact. Parent independently verified candidate 2's exact Git
tree/modes and 32 tests. Literal archive permission differences under umask are
not a Git executable-mode identity error. TDD remains OFF; normal tests required.

- Authorized group 3 only; commit `53b8456d8c97c4565be6e8f9199f1bc4322f250b`.
- Parent `a8d339c2789142dfcd9d02874561333482fe9d0d`.
- Indexed and committed tree `45446720cf32f386b240faaef68026ecc06fccb8`.
- Message: `fix(test): pin producer identity before releasing lifecycle workers`.
- Only `.maintainer/test/lifecycle/test_resources.py` and
  `.maintainer/test/unit/test-resources-test.py`: **173 additions, 11 deletions**.
  Complete staged diff/secrets/modes inspected; both remain Git mode `100644`.
- Git archive fixture `/tmp/opencode/commit3-index-RyJgRhPv`; no later-group hunks.
  Foreground CONTAINER commands, explicit 120000 ms timeout each:
  `PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/test-resources-test.py -v`
  **PASS: 52 tests, 0.114 s**, including expected mocked recovery-refusal diagnostic;
  `PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/starter-lifecycle-test.py -v`
  **PASS: 32 tests, 0.041 s**. Inspected subprocess/signal/proc and Docker boundaries
  are mocked; no live Docker or real producer proof claimed.
- `git diff --cached --check` passed; normal commit without attribution, hook bypass
  or amend. Committed tree equals tested indexed tree; index empty.
- Source-byte fingerprint excluding ODD remains
  `15e53eeb25665b98b7073aeccef9673ef4ff7456`; final source worktree bytes and protected
  tool-policy SHA-256 are unchanged. Adapter, owner policy and ODD work remain local.
- Rollback boundary: this two-file producer-identity/handshake unit only. Fixture
  retained; no retained-run mutation/cleanup, network, push/PR, child/native review,
  RDD enablement, source semantic edits, group 4, ODD closure or archive.
- Skills loaded: `work-unit-commits`, `markdown-documentation`. Parent assessment
  remains separate from functional proof; RDD OFF grants no invented review approval.

### Group 4 observed evidence

Parent reports independent exact Git-byte/mode verification and 52 passing tests
for group 3; risk remains high, RDD globally OFF. No native review or enablement.
The user approved this smallest cohesive 903-line group without artificial splitting.

- Commit `19cf58d60af60d55015d2978cb7707d38284502e`;
  parent `53b8456d8c97c4565be6e8f9199f1bc4322f250b`;
  tested/committed tree `538529aa4f8cb5f0a1c57ff7604f7c435ffcce2e`.
- Message: `feat(test): allow exact generated Dockerfile reads in attachment proofs`.
- Six paths: `.maintainer/README-distribution.md`,
  `.maintainer/test/lifecycle/starter-lifecycle.py`,
  `.maintainer/test/unit/starter-lifecycle-test.py` (unchanged Git mode `100644`),
  `.maintainer/test/lifecycle/generated-dockerfile-read.py`,
  `.maintainer/test/lifecycle/narrow-plugins/docker-buildx`, and
  `.maintainer/test/unit/generated-dockerfile-read-test.py` (new Git mode `100755`,
  preserving existing executable worktree files). **902 additions, 1 deletion**.
- Complete staged diff, new scripts, secrets and modes inspected; no credential
  values found. No semantic source edit, normalization or formatter executed.
- Git archive indexed fixture `/tmp/opencode/commit4-index-nRn7Jf5e`.
  Foreground CONTAINER commands, each explicit 120000 ms timeout:
  `PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/starter-lifecycle-test.py -v`
  **PASS: 35 tests, 0.043 s**;
  `PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/generated-dockerfile-read-test.py -v`
  **PASS: 25 tests, 0.196 s**;
  `PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/test-resources-test.py -v`
  **PASS: 52 tests, 0.115 s**, expected synthetic recovery-refusal diagnostic.
  All execution/process/daemon boundaries mocked; native forwarding/live proof
  remains unproved. Documented same-user pathname race limitation retained.
- Cached diff whitespace check passed; normal commit, no hook bypass/amend or AI
  attribution. Committed tree exactly matches tested index; index empty.
- Sorted-path source-byte fingerprint excluding ODD, before/after commit:
  `915a2e91032f42aba6074d99d407d2b037849d93`. The older enumeration fingerprint
  cannot be compared directly after untracked files become tracked. An auxiliary
  old-order reconstruction first rejected unsupported `ls-tree` exclude magic,
  then failed equality because its enumeration differs; neither mutated files.
  No test or required commit check failed. All six paths now match final worktree
  content; only owner tool policy and two ODD records remain dirty/untracked.
  Protected policy SHA-256 remains the documented exact value, uncommitted.
- Rollback is this six-file optional adapter/wiring/tests/docs unit, preserving
  earlier attachment/identity behavior. Fixture retained; no Docker/Buildx/Compose/
  native plugin execution, network, remote work, installation, cleanup, push/PR,
  child/native review, groups 5/6, ODD closure or archive.
- Skills loaded: `work-unit-commits`, `markdown-documentation`. Parent assessment
  and later authorized delivery remain pending; keep RDD OFF.

### Group 5 owner-policy evidence

- Owner explicitly approved committing the existing complete tool-policy bytes,
  not regenerating intent/locks or running an updater. Group 5 only executed.
- Commit `e30553e12d4ced17cc49471a6beb83ca0ddece80`;
  parent `19cf58d60af60d55015d2978cb7707d38284502e`;
  structurally checked indexed/committed tree `c1f821fccfdde1699fc858a834f06dc2e5c4e82b`.
- Message: `chore(tools): update owner-managed versions and locks`.
- Only `.devcontainer/tool-versions.conf`, **20 additions, 20 deletions**,
  unchanged Git mode `100644`; complete file and staged diff inspected for secrets.
- Foreground CONTAINER checks with explicit 120000 ms tool timeout: cached diff
  whitespace check PASS; `sha256sum .devcontainer/tool-versions.conf` matches
  `5dbe8b2e35ce97317c7def31614354b0477b48661181018097cb8324c23c5198` before/after.
  Git staged blob equals actual file blob. Staged Git-object stdin structural
  validation PASS: 88 unique, quoted, non-empty TOOL/LOCK assignments, TOOL intent
  before LOCK fields, lowercase 64-hex SHA256 values, no executable interpolation.
  Structural inspection is not provider checksum authenticity, installed-version,
  application, or runtime proof. No policy file was sourced or executed.
- Normal commit without hook bypass/amend/attribution; committed tree matches
  checked index, index empty. Final source bytes unchanged, sorted-path fingerprint
  `915a2e91032f42aba6074d99d407d2b037849d93`; owner policy is now committed unchanged.
  Only the two ODD records remain untracked; no implementation source remains dirty.
- Group 4 self-verification totals 112 tests. Its separate independent worker's
  result is pending/not consumed here; no independent PASS or review approval
  inferred. RDD stays OFF. No native review, enablement, Docker, network, installs,
  remote execution, updater, generated-lock rewrite, push/PR, child launch, group 6,
  ODD closure or archive. No fixture or runtime test required for this structural
  owner-policy boundary; rollback is only this file's committed existing diff.
- Skills loaded: `work-unit-commits`, `markdown-documentation`. Parent must reconcile
  independent group 4 evidence before separately authorizing group 6.
