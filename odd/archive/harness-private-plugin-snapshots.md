# Harness private plugin snapshots

## Subsequent explicitly authorized live proof

On 2026-10-06 the owner separately authorized one fresh CONTAINER run with
`--attachment --allow-generated-dockerfile-read`. Registered run
`60745f4b-32bf-43bd-9305-6b5408f0459d` completed successfully in 3m 31.126s,
08:38:41.805–08:42:12.931 UTC, without a retry or timeout. Inventory records
`stage=verify`, `exit=0`, `test=passed`, `outcome=removed`.

Observed live proof covered the fresh exact-byte cached-image bind probe and its
removal, private native snapshots and selection, exact generated-file read adapter,
build/up/recreate, managed-state and locale/timezone checks, actual Task/CLI payload
in the exact ubuntu workspace/container, running desired-bind drift and tokenless
warnings with identity/mount/state preservation, stopped/absent strict startup,
and both deliberate duplicate-locale rejections. This supersedes earlier unproved
runtime statements only for that tested isolated scenario, not arbitrary hosts.

Read-only post-run checks found no remaining recorded or run-labelled resources
on the same local daemon; scratch was absent. Shared build cache and compact
private inventory remain intentionally retained at
`.git/starter-test-runs/60745f4b-32bf-43bd-9305-6b5408f0459d.json`.
No manual cleanup, global permission/configuration changes or old-run access
occurred. Primary HEAD, branch, index, implementation diff bytes and protected
tool-policy checksum remained unchanged; no source edits or commits were made
during execution. This added record is post-run evidence bookkeeping only.

The result proves simulated HOST behavior inside the isolated CONTAINER fixture,
not the user's actual host or consumer DinD. Private native execution worked;
separate runtime version receipts were not retained, and vendor authenticity is
not claimed. No further execution is pending for this successful run.

## Parent reconciliation and implementation closure

The authorized private-snapshot implementation is complete. Current locator:
`odd/archive/harness-private-plugin-snapshots.md`; full recovery mirror remains
`odd/harness-private-plugin-snapshots/tasks` in project `gentle-starter`.
Earlier preparation, incomplete and pending statements below are historical and
superseded by this closure; no history was removed.

The owner explicitly accepted the current locally installed native bytes as the
trust source for this isolated fixture. Snapshot checks prove consistency with
that source, not vendor authentication or harmless binaries. Group-write is
accepted only for bounded origin ingestion; private selection and generated
inputs retain strict validation. No installed binary was copied or executed here,
and no global permissions, installers, policy or ownership schema were changed.

Final writer checks passed: 43 lifecycle, 54 adapter and 52 ownership tests.
A fresh independent functional verifier repeated all 149 tests successfully,
observing synthetic publication, frozen-byte bootstrap, private selection,
pre-producer refusal, preserved desired-core drift and unchanged native-delegation
arguments. The parent also repeated all 54 adapter tests. No failing required
command remains; the corrected earlier assertion failure is preserved below.
All effects were temporary synthetic files or mocked process/native/daemon calls.

Native candidate `sha256:333a130f55a04476e2f81d32ed6e40c26e013a81b6c2450795bc1efacd449cd9`
covered the five tracked implementation/test/README paths, excluding only this
passive untracked recovery record. The owner declined its native review; the exact
invocation returned `action: declined` and `consent: declined_this_candidate` for
that target. Assessment remained high, so independent functional verification was
performed. No native review approval or receipt is claimed; future reviews remain
enabled and mode was not toggled.

The parent independently verified `.devcontainer/tool-versions.conf` SHA-256
`5dbe8b2e35ce97317c7def31614354b0477b48661181018097cb8324c23c5198` after
the verifier reported that particular check unavailable. It matches exactly.
HEAD remains `df43bc20b530bbdc22b032b19d5000a200c7749c`; changes remain unstaged
and uncommitted for owner review. No commit, push, PR or runtime retry occurred.
There are no external navigation links to update; the current locator below is
updated and the full mirror is read back after archival.

Actual native discovery, executable relocation, protocol compatibility and live
attachment remain unproved. A new isolated operational run is optional, separately
authorized future work with a renewed cost/environment forecast, not an unfinished
part of the approved implementation-only scope. Retained failed-run evidence is
untouched. Optional Markdown lint and full operational suites were not run.

## Objective and current authorization

Prepare a bounded implementation map for private, verified copies of the current
locally installed Compose and Buildx. This phase changes this ODD record only;
implementation and all execution remain pending with the parent.

The owner accepts these installed bytes as a limited local trust source, not as
provider-authenticated artifacts. Matching hashes prove snapshot integrity, not
vendor provenance or absence of malicious source bytes.

CONTAINER workspace: `/home/ubuntu/gentle-starter`, the host bind-mounted checkout.
Observed branch: `test/gentle-shell-v4`; clean starting HEAD:
`df43bc20b530bbdc22b032b19d5000a200c7749c`.
Protected `.devcontainer/tool-versions.conf` SHA-256:
`5dbe8b2e35ce97317c7def31614354b0477b48661181018097cb8324c23c5198`.
Remotes were read locally only; no remote connection was attempted.

No production writes, binary copies, permission changes, Docker commands (including
help/version), native plugin execution, daemon probes, builds, network, installs,
cleanup, retries, remote work, staging, commits, or children are authorized here.
TDD remains OFF by explicit owner decision. RDD is reported globally ON; the parent
owns review authority and must not infer PASS or toggle it from this preparation.

This is a maintainer harness fixture, excluded from managed-tool replacement.
Do not change installers, tool policy, global Docker configuration, or activation.

## Current code evidence

- `generated-dockerfile-read.py:122–145` reads installed natives through `Inputs`,
  pins two binaries and three candidate files, and points private Docker config
  at the repository `narrow-plugins` directory.
- `Inputs:65–105` rejects group/world-writable ancestors and files. Keep this
  contract for private destinations, configuration, and generated inputs.
- `binding:148–164` requires system-native parent directories and exactly five
  pins. It must instead validate an exact private layout and complete pin set.
- `compose_override:222–255` compares `/proc` parent executable to the pinned
  Compose path. The discovered private Compose must be that actual executable.
- `delegate:329–360` preserves non-Bake argv and adds only the existing exact
  generated-file grant for validated Bake. Keep both behaviors and no recursion.
- The nine-line repository plugin entry loads the adapter and imports
  `test_resources.py`; moving it without fixing dependencies is not safe.
- `starter-lifecycle.py:311–317` prepares once before build;
  `Lifecycle.task:191–193` directly invokes `ownership.produce` for each task.
  Adapter checks cannot prevent Docker fallback when the adapter itself is missing.
- `test_resources.py:361–392` owns the stopped-producer handshake;
  `check_scratch:535–548` supplies the existing scratch identity/marker contract.
  No ownership-engine schema change is currently justified.
- The focused unit file uses synthetic binaries and mocks daemon, subprocess,
  native exec, signals and process inspection. No test body ran in this phase.

Previously supplied observations, not re-probed here: installed native ancestors
are `ubuntu:docker` mode `2775`, binaries mode `0775`, static Go amd64; Compose
5.5.1, Buildx 0.37.2 and Dev Containers CLI 0.89.0.

## Bounded implementation design

In a separately authorized implementation, accept only `docker-compose` and
`docker-buildx` from the two existing canonical system plugin directories.
Traverse from a trusted root using directory-relative `O_DIRECTORY|O_NOFOLLOW`
descriptors, rejecting symlink components and symlink binaries. Require directory
and binary owners to be root or the current user; accept existing group-write
only in this snapshot-ingestion path. Require executable regular files with the
existing 128 MiB bound. An open descriptor is an identity anchor, not immutable
content: compare descriptor identity before/after bounded reads, directory chain
identity and final membership against the held descriptors, and reject changes.
Never accept an arbitrary origin, chmod a source, or weaken `Inputs`.

Derive all destinations from the existing ownership record's exact scratch home,
checking scratch identity and marker without calling a daemon. Use private
exclusive staging and no-overwrite atomic publication; reject collisions.
Hash source bytes and independently read/hash destination bytes before publishing
pins. Directory modes are `0700`, JSON files `0600`, natives `0500`.

Private layout under the owned `HOME/.docker`:

```text
config.json                 cliPluginsExtraDirs contains only this plugins path
generated-read.json         exact binding and startup pins
plugins/docker-compose      native private snapshot, directly discovered
plugins/docker-buildx       private deterministic adapter launcher
native/docker-buildx        native private snapshot, never a discovery directory
```

Prefer a generated launcher with absolute known repository adapter/helper paths
rather than copying an expansive repository tree. Before importing either source,
validate both using bounded no-follow reads and expected owner/mode/hash identity;
load the validated bytes without a pathname reread, using explicit module setup
and no arbitrary import search fallback for `test_resources`. Pin the launcher
itself, both dependencies, private config, natives and candidate inputs; enumerate
exact permitted pin paths rather than merely adjusting the old pin count.
If verified-byte module loading cannot be achieved within this bound, report the
gap rather than silently trusting repository imports or copying more code.

Bindings must validate exact run-home paths against the existing inventory and
require native Compose at `plugins/docker-compose`, Buildx at
`native/docker-buildx`, and the adapter at `plugins/docker-buildx`. Validate the
config's exact JSON selection and all startup pins before delegation and recheck
before exec. Preserve original non-Bake argv/stdin/environment with no new allow
flag. Keep native metadata delegation, not protocol emulation.

**Concrete scope gap:** a guard before each lifecycle task producer is needed to
reject missing or changed config/plugins before Docker can select system fallback.
Preparation alone and checks inside the missing plugin cannot provide that proof.
The smallest explicit route is an opt-in check in `Lifecycle.task`, calling the
adapter's private-selection validation before `ownership.produce`. This adds
`starter-lifecycle.py` to the proposed four-file implementation boundary. Parent
approval is required before this fifth-file change; do not change the ownership
engine or smuggle a PATH/task wrapper in as an unreviewed alternate route.

This remains cooperative, not a sandbox: the same user can race pathname-based
selection or execution after final checks. Private ownership, byte pins and
timestamps do not authenticate vendors or prevent malicious same-user races.

## Stable tasks, routes and acceptance

- [x] HPS-01 — Read adapter, entry point, lifecycle call sites, ownership contract,
  focused tests and README; verify local baseline and protected policy hash.
- [x] HPS-02 — Write this preparation record and full project-scoped mirror.
- [x] HPS-03 — Parent reconciled the pre-producer scope gap under the owner's
  explicit private-copy/coherent-selection authorization; see the implementation
  authorization below. This does not prove completed implementation or native review.
- [x] HPS-04 — Implement descriptor-relative source ingestion, bounded stable
  snapshot reads and private exclusive publication with owned-root preparation
  wiring; synthetic verification recorded below, not live/native proof.
- [x] HPS-05 — Generate private entry, pin/load exact adapter/helper bytes, bind
  exact private paths, coherent selection and unchanged delegation; functional
  synthetic evidence recorded below, not parent review or feature closure.
- [x] HPS-06 — Add parent-approved pre-producer guard; preserve default/consumer
  paths and ownership schema. Missing/changed private selection must prevent
  producer launch, not merely refuse after Docker starts.
- [x] HPS-07 — Update focused synthetic tests and README with accepted trust,
  exact modes/layout, fallback prevention and cooperative race limitations.
- [x] HPS-08 — Parent authorizes safe verification, records actual results,
  reconciles native review requirements and delivery; no live proof inferred.

Primary four implementation files (not edited in this phase):

1. `.maintainer/test/lifecycle/generated-dockerfile-read.py`
2. `.maintainer/test/lifecycle/narrow-plugins/docker-buildx`
3. `.maintainer/test/unit/generated-dockerfile-read-test.py`
4. `.maintainer/README-distribution.md`

Additional necessary route awaiting approval:
`.maintainer/test/lifecycle/starter-lifecycle.py` and its existing
`.maintainer/test/unit/starter-lifecycle-test.py` for focused guard assertions.
Use at most four assigned files and two write targets per delegated work batch;
the parent schedules dependent batches, with tests and docs kept in the same
behavioral review unit. This worker launches no children.

Acceptance includes group-writable installed-source ingestion only; ancestor/file
symlink rejection; wrong owners/types; oversize reads; source descriptor/membership
replacement; mutation during read; destination collision and hash mismatch;
exact destination modes; no source mutation; exact config/private-path binding;
launcher/dependency/native/config tampering and disappearance; Compose executable
binding; no native recursion; unchanged metadata/non-Bake forwarding; original
Bake structural refusals; and pre-producer fallback prevention. Tests must use
synthetic files with all native execution, daemon, subprocess and process effects
mocked. Instrument failed preparation to prove no environment publication.

## Verification and delivery boundary

Current evidence: local Git status/branch/HEAD/remotes and policy SHA-256 match the
supplied baseline; code paths above were read. No unit baseline was executed.

Proposed CONTAINER commands, not run or authorized by this document:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/generated-dockerfile-read-test.py
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/starter-lifecycle-test.py
git diff --check
sha256sum .devcontainer/tool-versions.conf
git status --short
```

Before authorizing either test file, inspect its complete current effects and
mock boundaries, especially new launcher tests; no subprocess may reach native
plugins, Docker or the ownership cleanup engine. The second suite needs separate
effect inspection; it was not fully audited here. A future synthetic run creates
and removes its own temporary files, so it is outside this no-copy/no-cleanup phase.
Runtime harness proof is **not run: explicitly forbidden**, not N/A or PASS.

Forecast: approximately 400 authored changed lines is advisory and uncertain;
dependency loading and the pre-producer guard may exceed it. Delivery is
`ask-on-risk`: report real line count and cohesive scope before expanding. Do not
minify, remove evidence/tests, or artificially split inseparable behavior. No
commit, stage, branch change, publication or native review execution is authorized.

Rollback boundary: remove only the eventual harness snapshot/selection changes,
their focused tests and README additions; retain prior adapter behavior and all
historical ODD records. This record stays active; only the parent may reconcile
and archive completed authorized work. Never mutate existing archives.

Full mirror topic: `odd/harness-private-plugin-snapshots/tasks`, project
`gentle-starter`; repository locator:
`odd/archive/harness-private-plugin-snapshots.md`.

## Implementation authorization superseding the preparation-only boundary

The parent explicitly authorizes one coherent six-file implementation in the
CONTAINER checkout. The earlier four-file/two-write-target batch heuristic is
not a parent limit and does not require splitting this inseparable behavior.
The exact source/test/documentation paths are:

1. `.maintainer/test/lifecycle/generated-dockerfile-read.py`
2. `.maintainer/test/lifecycle/narrow-plugins/docker-buildx`
3. `.maintainer/test/unit/generated-dockerfile-read-test.py`
4. `.maintainer/test/lifecycle/starter-lifecycle.py`
5. `.maintainer/test/unit/starter-lifecycle-test.py`
6. `.maintainer/README-distribution.md`

This ODD record and its full mirror may also be updated. HPS-03 is resolved;
`test_resources.py` remains read-only and its ownership schema is unchanged.
TDD is OFF; source-prior proof is No. Normal safe synthetic tests and their own
temporary fixture creation/removal are authorized. Actual installed native
binary copies belong only to future live harness code, not this execution.
Current-local-byte trust proves integrity only, never vendor authentication.

The authorized foreground checks each have an explicit 120000 ms timeout:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/generated-dockerfile-read-test.py -v
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/starter-lifecycle-test.py -v
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/test-resources-test.py -v
```

Inspect all effects before tests; native execution, daemon, subprocess and
metadata process effects must remain mocked. Local AST parsing, Git diff/status
inspection and protected-policy hashing are authorized. No Docker, native plugin
execution (even help/version), real installed binary copying, global permission
changes, weakened Inputs, installer/tool-policy changes, network, remotes,
builds, probes, live retries, retained-resource cleanup, staging, commits,
pushes, PRs, children or child review are authorized. Existing archives, failed
run history and resources remain untouched. RDD remains globally ON with the
parent handling review authority; no toggles, closure or archival by this worker.

Private-selection validation before every relevant producer, including direct
connect startup/active paths, must not validate temporary current desired-core
drift as a startup-byte failure. Warning-only running attachment remains valid.
The same-user post-check race remains cooperative, not a sandbox.

## Worker outcome: implementation incomplete

The worker read all five requested skills, the complete local record and full
mirror #2869, both adapter/lifecycle source files, the thin plugin entry, all
three authorized test files and the ownership engine through its scratch/probe
contract. No source, test or maintainer README changes were made. HPS-04 through
HPS-08 remain pending; no authorization gap is asserted and no new question is
required. The parent retains the coherent six-file implementation scope.

Observed local checks: branch and HEAD match the supplied baseline; the protected
policy SHA-256 matches; `git diff --check` passed. Initial and final Git status
show only this untracked ODD record, not a completely clean worktree. Tracked
source diff count is zero. All three requested test commands remain NOT RUN;
there is no test PASS, source-prior test proof, AST proof or live/native proof.
The full mirror was updated in place and read back; update operations do not
capture prompts. Nothing was staged, committed, archived or remotely executed.

## Bounded HPS-04 batch: reader/publication helpers verified

The owner explicitly narrowed this continuation to two source-write targets:
`.maintainer/test/lifecycle/generated-dockerfile-read.py` and
`.maintainer/test/unit/generated-dockerfile-read-test.py`, plus ODD tracking.
Launcher, preparation wiring, lifecycle guards and README changes remain for the
next batch by the same writer. TDD remains OFF; no RED/source-prior run occurred.

Added `NativeSnapshot`, `bounded_native_read`, `verify_snapshot_destination` and
`publish_native_snapshot`. The origin allowlist and two native names stay closed.
The reader holds no-follow directory descriptors from root, permits group-write
only for accepted local origins, rejects unsafe owner/type/world-write/nonexec
inputs, bounds reads to 128 MiB, and rechecks descriptor and directory-relative
membership before publication. Directory timestamps are excluded so unrelated
sibling creation does not cause false replacement failures. Private parent mode
is exactly 0700; exclusive staging is independently read/hashed at mode 0500
before no-overwrite link publication. Generic `Inputs` remains unchanged.

Helpers are inert unless explicitly called. Future preparation must derive and
validate the destination from the owned run/scratch contract; this batch does
not wire that ownership check, bindings, environment publication or live copies.
No actual installed binaries were read/copied/executed. All tests use synthetic
temporary files with subprocess, daemon commands and native execution guarded.
This proves accepted-byte integrity only, not vendor trust or a same-user sandbox.

Observed CONTAINER verification with explicit 120000 ms foreground timeout:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/generated-dockerfile-read-test.py -v
git diff --check
sha256sum .devcontainer/tool-versions.conf
```

Initial suite: 40 tests, one ERROR because the dangling-destination-link assertion
expected `FileExistsError`, whereas strict `Inputs` correctly refused it earlier
with `Unsafe`. Corrected the assertion and added two destination-tamper tests.
Final suite: **42 tests passed (0.183 seconds)**, including 17 new snapshot tests
and all 25 existing adapter regressions. `git diff --check` passed; protected
policy SHA-256 remains the recorded value. No required command remains failed.
The other two suites were not run in this narrowed batch. Tracked authored diff:
355 additions, zero deletions across the two approved source/test paths; the
untracked ODD record is additional tracking content, not part of that Git count.

HPS-04 remains partial until owned-root preparation wiring is verified; HPS-05
through HPS-08 remain unchecked. No stage/commit, child, archive, live proof or
review approval. Next unit: private launcher/validated-byte loading and exact
selection binding, then preparation wiring and pre-producer validation.

## Owned-root preparation and HPS-05 bootstrap batch

The owner authorized this next unit in the same two source/test files plus ODD
tracking. No repository entry, lifecycle, README, ownership engine, installer or
tool-policy file was changed. The old repository entry remains unchanged but is
no longer selected by the prepared private configuration.

`prepare` validates current inventory, existing scratch marker/inode and held
lease using the existing `Run` contract, without calling Docker. It derives the
exact run home/candidate, creates exclusive private configuration and native
directories, publishes synthetic-tested snapshots via the HPS-04 helper, and
publishes environment selection only after full private validation and input
rechecks. Copy/collision failures preserve the existing lifecycle environment.
The owned private Compose executable is `plugins/docker-compose`; the native
Buildx executable is `native/docker-buildx`, distinct from the discovery launcher.

Nine exact allowed paths are derived by `selection_paths`: two natives, config,
launcher, adapter/helper dependencies and three original candidate inputs. All
private modes are exact (directories 0700, JSON 0600, executable copies/launcher
0500). `validate_selection` checks private selection without daemon/producer
authority or comparing current desired candidate bytes. Candidate pin declarations
remain bounded/typed/strict; Bake preserves its original byte/argv checks and
allows restored core bytes as before.

The deterministic private launcher embeds exact binding and dependency pins.
Its standard-library bootstrap opens parents and files using no-follow descriptors,
checks bounded owner/mode/identity/hash snapshots and freezes BOTH source payloads
before compiling either. It explicitly installs the verified `test_resources`
module for adapter import, restores prior module state afterward, and suppresses
bytecode. No module pathname is reread for compilation, ambient custom import
fallback or repository tree copy is used. A missing binding environment variable
is supplied from the embedded path for internal Docker metadata discovery; a
foreign override is refused. Non-Bake metadata uses the copied native with
unchanged argv/stdin/environment and no active Bake authority requirement.

Observed CONTAINER command, explicit foreground timeout 120000 ms:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/generated-dockerfile-read-test.py -v
git diff --check
sha256sum .devcontainer/tool-versions.conf
```

First observed suite: **51 tests passed (0.472 seconds)**. Added held-lease,
scratch marker/inode, group-writable preparation and frozen-byte/path-disappearance
coverage; final observed suite: **54 tests passed (0.493 seconds)**. No failed
required command in this batch. All process/native/daemon effects are mocked;
only synthetic files were copied, and repository dependency tampering is simulated
without modifying source files. `git diff --check` passed; protected hash and
HEAD remain unchanged. Cumulative tracked authored count: **764 additions and
35 deletions (799 changed lines)** in two files; no minification/artificial split.
The untracked ODD record is additional tracking content outside that Git count.

HPS-04 and HPS-05 implementation checks are now satisfied by bounded synthetic
evidence. HPS-06 pre-producer lifecycle integration, HPS-07 documentation and
HPS-08 parent verification/review/delivery reconciliation remain pending. No
live/native compatibility, sandbox guarantee, vendor authentication, review
approval, staging/commit, child, closure or archival is claimed. Next unit:
wire `validate_selection` before relevant lifecycle producers, including direct
connect paths, preserving default/consumer and warning-only running drift.

## HPS-06 bounded pre-producer integration

Authorized writes were limited to `.maintainer/test/lifecycle/starter-lifecycle.py`,
`.maintainer/test/unit/starter-lifecycle-test.py` and this tracking record.
The already prepared adapter is retained only after successful preparation.
One shared `validate_private_selection` calls its read-only `validate_selection`
for opt-in runs and returns immediately for default/consumer runs. It does not
require active producer identity, call a daemon or inspect current desired core.

All base post-preparation producer routes are covered: `task`, direct
`connect_payload`, `owned_operation` and missing-token fixture creation.
Connection and Docker fixture routes validate before preliminary Docker effects
and again immediately before producer invocation. Initial candidate preparation
precedes private selection and remains unchanged; consumer producer routes remain
unchanged. The ownership engine/schema and exact producer argv/environment/stage
semantics were not modified. Connection validation failure cannot be mistaken for
the intentional stopped/absent startup error, even with a stale synthetic exit.

The complete lifecycle suite and previously inspected adapter/resource mock
boundaries were reviewed before execution. New guard tests mock adapter validation
and prove caller ordering/refusal across task, running/stopped/absent connection,
and fixture producer routes. Actual private-file validation/tampering and drift
behavior remain covered independently by the adapter suite. Only synthetic
temporary fixtures and mocked subprocess/native/daemon effects were used.

Observed foreground CONTAINER commands, each timeout explicitly 120000 ms:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/starter-lifecycle-test.py -v
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/generated-dockerfile-read-test.py -v
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/test-resources-test.py -v
git diff --check
sha256sum .devcontainer/tool-versions.conf
```

Results: lifecycle **43 passed (0.050 seconds)**, adapter **54 passed (0.498
seconds)**, resources **52 passed (0.116 seconds)**. All required commands passed
on their first execution in this batch; no failure/correction history to report.
The resources suite printed an expected recovery-refusal diagnostic in a passing
negative test; it performed no real retained-resource cleanup. Diff check passed;
protected policy hash and HEAD remain unchanged. HPS-06 source/test authored count:
145 additions and one deletion (**146 changed lines**). Cumulative tracked count:
909 additions and 36 deletions (**945 changed lines**) across four files, plus
the untracked ODD tracking record. Changes remain unstaged and uncommitted.

HPS-06 is implemented with bounded synthetic evidence, not native compatibility,
runtime proof, review approval or whole-feature closure. HPS-07 README documentation
and HPS-08 parent reconciliation remain pending. No Docker, real native binary
copy/execution, build/network/global chmod, child, archive or ownership engine
change occurred. Next unit is the parent-directed documentation update before
freeze; no native worker or operational proof is authorized.

## HPS-07 documentation and final bounded implementation evidence

This final unit changed only `.maintainer/README-distribution.md` and ODD tracking.
The README now documents exact private layout/modes, nine-path selection, verified
bootstrap, pre-producer refusal, accepted local group-writable origin trust,
strict unchanged destination Inputs, existing run-owned cleanup/retention, and
same-user post-check races. Root ownership is not immutability; hashes prove local
snapshot integrity, not vendor authentication or harmless binaries. Actual native
copies and discovery/relocation compatibility remain future authorized live work.
The exact future CONTAINER recipe is documented but was not executed. The legacy
repository thin entry remains unchanged and is not selected by prepared runs;
the generated private launcher is used instead. The existing exact generated-file
read entitlement and default/consumer behavior remain unchanged.

After documentation edits and mock-effect inspection, final foreground checks
used explicit 120000 ms timeouts for each command:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/starter-lifecycle-test.py -v
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/generated-dockerfile-read-test.py -v
PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/test-resources-test.py -v
git diff --check
sha256sum .devcontainer/tool-versions.conf
git status --short
git diff --stat
```

Final results: **43 lifecycle (0.042 seconds), 54 adapter (0.499 seconds),
52 ownership (0.099 seconds), all 149 passed**. These are synthetic/mock proofs,
not actual plugin discovery, native relocation or live protocol/runtime proof.
No command failed in this unit; prior HPS-04 exception-assertion correction remains
preserved in history. Diff check passed; protected SHA-256 and HEAD match baseline.
Optional markdownlint was not run; no download or auto-fix was attempted.
README count: 67 additions/9 deletions. Cumulative tracked authored count:
976 additions/45 deletions (**1021 changed lines**) across five files; the untracked
ODD record is additional tracking/history, excluded from that Git count.

HPS-04 through HPS-07 are implemented/documented with observed bounded evidence.
HPS-08 remains unchecked for parent review/delivery reconciliation; there is no
worker closure or archival. All changes remain unstaged/uncommitted. No actual
installed native copying/execution, Docker/build/probe/network, global chmod,
ownership schema mutation, retry, retained-resource cleanup or child occurred.
Next step: parent review/freeze reconciliation under existing RDD authority.
