# Prepare linear consumer releases locally

## Happy path: prepare, approve, promote, clean up

Use this producer-only guide from the **CONTAINER repository root** (currently
`/home/ubuntu/gentle-starter`, the same checkout bind-mounted from the HOST).
These commands use local Git only: they do not build, install, fetch or push.
The `.maintainer/` directory is excluded from consumer distributions.

**Prerequisite:** intended source changes are committed on `dev`, and the
producer worktree/index are clean. Integrate implementation changes before
release preparation; uncommitted edits are not publication inputs. Do not check
out `starter-rc` or `starter` in a worktree during mutation.

1. Prepare the RC. Choose the command based on actual local `starter` presence:

   ```bash
   # CONTAINER: initial release ONLY when local starter is absent.
   task --taskfile .maintainer/Taskfile.yml distribution:candidate -- --base-absent
   # CONTAINER: later release when local starter exists; use this instead.
   task --taskfile .maintainer/Taskfile.yml distribution:candidate
   ```

2. Keep the printed full RC, source, tree, pinned base and policy markers.
   Preparation and pending status print the exact promotion command on its own
   line under **Next command (only after explicit review/approval)**, followed by
   a guarded rejection **Alternative**. Commands include custom branch names and
   full pins. The RC remains **unapproved**; printing is not approval.
   Inspect/review/test that captured RC, not whatever `dev` or `starter-rc` points
   to later. For local Git inspection, substitute the captured full RC ID:

   ```bash
   # CONTAINER: replace FULL_RC_SHA with the captured ID, not a mutable ref.
   git show --no-patch --format=fuller FULL_RC_SHA
   git ls-tree -r FULL_RC_SHA
   ```

3. Only after explicit approval, copy the **printed promotion command unchanged**.
   It already contains all four approval pins; no second invocation discovers
   approval from ambient refs. Its shape is:

```bash
# CONTAINER: illustrative shape; prefer the exact printed command.
task --taskfile .maintainer/Taskfile.yml distribution:promote -- \
  --candidate starter-rc --target starter \
  --approved-rc FULL_RC_SHA --expected-tree FULL_TREE_SHA \
  --expected-base FULL_BASE_SHA_OR_absent --expected-source FULL_SOURCE_SHA
```

Promotion verifies the complete candidate chain, exact filtered trees, previous
release history/source ancestry and all four pins. It refuses moved/canceled RCs,
changed bases, malformed/symbolic refs, dirty checkout or a checked-out release.
It creates one root release initially, or one commit whose sole parent is the
previous `starter`, then compare-and-swap updates that local ref. Source may
have advanced after capture without invalidating that approved source pin.

**After promotion:** remove the retained RC before the next cycle:

```bash
# CONTAINER: read-only status prints the current guarded cleanup command.
task --taskfile .maintainer/Taskfile.yml distribution:status
# Copy its distribution:reject command with the captured full expected RC.
# Rejection needs only the captured full RC pin, even after promotion.
```

Status works even with a dirty worktree and classifies local metadata as
`absent`, `pending`, `directly-promoted`, or `inconsistent`. It does not create
objects, indexes, files or refs, recompute filtered trees, or grant approval.
It checks recorded identity/ancestry and a direct publication's parent/tree
match, not full publication correctness. Inconsistent state fails closed without
action commands. The existing promotion/rejection checks remain authoritative.
For `directly-promoted`, **Next command (remove retained RC; starter unchanged)**
contains only the standalone guarded rejection command, never a new promotion.

## Blocked command diagnostics

When candidate preparation refuses a stale RC or status reports `inconsistent`,
the default output shows only the full blocked RC ID and a concise reason,
alongside the original error. For an RC that recorded an absent initial base:

```text
State: inconsistent
Blocked RC: FULL_RC_SHA
Reason: this RC expected no starter release, but starter now exists.
```

`FULL_RC_SHA` is the full ID on the `Blocked RC:` line, not a branch abbreviation.
For metadata details, use read-only status from the **CONTAINER repository root**:

```bash
task --taskfile .maintainer/Taskfile.yml distribution:status -- --verbose
```

`--verbose` also works with candidate preparation; it changes only blocked
diagnostics, not successful reports or mutation guards. The detailed report retains
`RC:`, candidate branch, source/tree/pinned/current-base labels and the metadata-claims
warning. Missing, malformed or unreadable fields are `unavailable`; `absent` means
a recorded initial base or a missing current release ref. The original error and
nonzero exit remain: diagnostics do not validate the full filtered tree,
approve promotion, or authorize deletion. Inconsistent state blocks preparation/
promotion and prints no action commands; no automatic recovery is performed.
It is not itself a barrier to explicitly pinned rejection of a valid candidate.

## Reject an RC instead of promoting it

Before promotion, copy the preparation/status **guarded rejection command**
instead of the promotion command. It requires `--expected-rc FULL_RC_SHA` inside
the helper and uses that exact ID for compare-and-swap deletion. The same single
command discards an initial, later, obsolete or retained promoted RC:

```bash
# CONTAINER: substitute the captured full RC ID, including from Blocked RC.
task --taskfile .maintainer/Taskfile.yml distribution:reject -- --expected-rc FULL_RC_SHA
```

Rejection deletes only the verified local candidate ref, retaining `dev` and
`starter`. It refuses stale pins, dirty checkout, checked-out/symbolic RCs,
corrupted candidate identity, source, tree or provenance chain. The recorded
historical base commit must still be valid, but current `starter` may be absent,
missing, advanced or unrelated; current `dev` may have moved or be absent.
Rejection validates the full candidate chain, not its relationship to today's
release. After promotion it removes the retained RC; **it does not undo the
release**, promote anything, or create a replacement RC.

`--base-absent` remains accepted for rejection compatibility but has no effect
on discard. It still controls initial preparation and legacy
`distribution:candidate -- --cancel`, whose base-presence, stale-base and
legitimate-publication cleanup guards are unchanged. Prefer pinned rejection.

Rollback after promotion is a different decision: make a corrective committed
source and prepare/review a new linear release. Rejection cannot roll back
`starter`; do not force-reset published history as an RC cleanup shortcut.

## Next release and separate publication authority

After rejection, fix/commit `dev` and prepare again; the new RC starts at a root.
While an RC remains pending, preparation advances its candidate-only chain if
source advances. Repeating the same source/current policies is a no-op that
prints the same complete report. A source-only change still creates a new RC
even if the filtered tree is unchanged; prior approval/rejection pins then fail.
After promotion and guarded cleanup, prepare without `--base-absent` to pin
the new `starter`, then repeat the approval steps above.

Optional [consumer lifecycle proof](#explicit-base-lifecycle-proof) requires
separate operational authorization, cost forecast and timeout. It proves its
own committed fixture, **not the exact primary RC**; do not treat a fixture pass
as automatic approval or claim expensive proof from unit tests.
For a separately authorized manual RC build/connect test, use an independent
local clone in a separate **HOST folder**, pinned to the captured RC; the mounted
producer checkout is not that clone. Run `task container:*` on the HOST from that
clone's root, not inside this CONTAINER. No host destination is assumed here.

Remote publication is separate from local promotion and requires explicit
destination/operation/credential-session authority. None of these commands
pushes or deletes remote refs. Future consumer clones should use the published
linear `starter` ancestry, which does not descend from producer `dev`.

## Editable publication tool suggestions

Edit `.maintainer/starter-tools.json` and commit the intended source before
preparing a candidate. This producer-only file is one JSON array of canonical
optional installer basenames; entries may be added, removed or replaced freely,
including `[]`. The initial suggestions are:

- `2080-browser-playwright.sh`
- `3030-ai-pi-coding.sh`
- `3040-ai-gentle-shell.sh`
- `3070-ai-gga.sh`

The filter reads the list from the pinned source commit and replaces the entire
published `03-enabled/` group with exactly those canonical symlinks. It leaves
producer aliases and mandatory core unchanged. Selected targets must be committed
executable regular installers, exclude core, and satisfy the source dependency
graph and execution order; missing prerequisites are rejected, not added.
Compose selection is independent and unchanged by this list. Suggestions are
installation defaults, not mandatory core or runtime auto-enablement.

New identities carry `Starter-Tools-Normalization: 1` after the Compose policy
header. This identifies the producer filtering algorithm, not a preset version
or consumer upgrade policy. Historical identities without the header retain
their original aliases and need no list. Every ancestor is recomputed using its
own recorded source and markers. A same-source historical candidate can gain a
normalized child only when that source already contains a valid list. Promotion
requires an approved normalized candidate, even if the source branch later moves.

The list is excluded from consumer trees with the rest of this directory;
generated aliases are ordinary Git content. Consumers review their Git diff and
choose which changes to keep. Ordinary merges may automatically merge clean
changes; conflicts are resolved manually. There is no guaranteed prompt for
every update, automatic migration, customization-preservation mechanism or
consumer update support framework.

## Compose selection identity

New candidates and releases carry exactly `Starter-Compose-Policy: 2` after
their existing source/base headers. Their committed source must have these four
unique, active entries first, in order:

1. `./docker-compose.yml`
2. `./config/compose/docker-compose-core-tools.yml`
3. `./config/compose/docker-compose.pi.yml`
4. `./config/compose/docker-compose.gentle-shell.yml`

The filter comments every other selection without changing bytes outside the
array. It never activates commented source entries. Pi/Shell persistence is a
default preset, not mandatory core classification; consumers can change their
owned Compose selection. Root `README.md` remains excluded from distribution.

Existing unmarked linear candidate/release identities use the historical two-entry
normalizer, including exact tree recomputation for every ancestor. Tool alias
normalization is identified separately above. Unknown, duplicate or malformed markers fail closed; there is no
legacy creation switch. New promotion requires an explicitly current candidate.
A legacy same-source RC can gain a current-policy
child only if that committed source already contains all four active entries;
source equality is allowed by the unchanged ancestry check. Otherwise commit a
new source first. Source/base pins, approved IDs, exact trees, parent provenance
and compare-and-swap remain required. The reduced base lifecycle fixture below
intentionally stays two.

### Historical identities (not current instructions or approval)

Historical RC `28a42cc55…` and release `ef2f71e5…` document earlier policy history.
They are not current checkout metadata or approval to publish another preset.
Always capture current full IDs from the local helper; never reuse these examples.

## Explicit base lifecycle proof

### Select the proof boundary

These recipes describe evidence, **not authorization to execute**. Invoke from the
**CONTAINER producer repository root**; Task simulates HOST operations only in the
registered scratch candidate. The HOST owns the bind-mounted source checkout and
the local daemon must see the exact scratch bytes. No host path or remote authority
is inferred from this topology.

| Proof | Selector | Evidence and deliberate exclusions |
| --- | --- | --- |
| Base persistence | default | Build/up/direct ubuntu exec/recreate, managed markers and source preservation; no Task attachment or nested daemon |
| Task attachment | `--attachment` | Base plus Task/CLI payload identity, running drift and missing-token preservation, stopped/absent strict startup; no SSH login |
| Runtime/SSH modes | `--runtime-directories` | Synthetic authority and managed SSH root/child/key modes and preservation, no published ports; no real authority repair or remote SSH |
| Consumer nested DinD | `--consumer` | Filtered fixture release clone/build/up and separate inside-container daemon/hello-world; privileged Features, two state volumes retained |
| Optional integrations | separately authorized recipes | Pi, SSH authentication/connectivity, audio, GUI and other integrations require their own prerequisites and scoped proof |

Before execution require reviewed build inputs/hooks, installed tools, authorized
local Docker, a cached probe image and canonical writable scratch parent. Read-only
preflight is metadata readiness only. Forecast downloads, CPU/build time, disk and
retained shared cache for the selected row. Set an **external** supervisor soft
budget and a longer hard deadline allowing finalization; the runtime section below
provides a concrete warm/cold forecast. A timeout is incomplete proof, not PASS.
Success removes only verified run-owned resources. Failure/interruption retains
private evidence; preview one selected run before separately authorized apply.
Never globally prune, repair authority, retry a failed guard or switch proof modes
to turn an error into success. See [recovery](#recovering-test-owned-resources).

For an explicit **consumer release/DinD smoke** instead of the reduced base
scenario, from the **CONTAINER producer repository root**, run
`task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle -- --consumer`
(the same optional `--daemon-visible-scratch ABSOLUTE_PARENT` applies). This
uses the same registered scratch, exact-byte cached-image bind probe, local
daemon identity, success cleanup and failed-run retention described below.
After probing it copies the current public, possibly uncommitted source into
independent fixture Git metadata, commits that fixture, creates and promotes a
filtered root release **only there**, clones that fixture's `starter` without
retaining a remote, then runs `container:build` and `container:up` and checks a
Docker `hello-world` run inside the consumer container. The original release
refs, remotes and source worktree are not used for promotion or cleanup.
Expect a potentially long build, feature downloads, nested image pull, disk
usage and retained shared build cache; authorize live execution separately
and set a supervisor timeout beyond the build and cleanup forecast. The test
does not contain arbitrary build hooks or guarantee no external side effects.
Inspect the current source hooks and build inputs before running it. Report
fixture clone/build/up separately from the optional nested-daemon check. A pass
is scoped consumer evidence, not a universal integration proof. New consumer
runs persist a variant marker before execution. Only these runs may recognize
the two DinD Feature state volumes when their project labels and actual container
mounts match `/var/lib/docker` and `/var/lib/containerd`. They are retained,
never claimed or deleted; unexpected or conflicting volumes stop recovery.
Old inventories without the marker cannot infer consumer identity from names:
their preview fails closed. Retention is not complete removal.

The maintainer-only `test:starter:lifecycle` replaces the removed
`test:pi-lifecycle`; it no longer proves Pi. Run it only with explicit
operational authorization, outside the normal `task test`, `task test:starter`,
and `task validate` routes:

```bash
# CONTAINER: producer repository root; separate operational authorization required.
task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle
# Optional alternative existing parent (still probed):
task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle -- --daemon-visible-scratch /absolute/scratch-parent
```

The default requires an existing canonical `/home/ubuntu` and generates a unique
`/home/ubuntu/starter-test-<UUID>` directory per run. The optional existing,
canonical parent must be outside the source repository and its Git metadata.
Neither path is accepted on an operator's assertion of daemon visibility: after
arming the ownership record and before candidate creation or build, the harness
uses the pinned local Unix Docker socket and cached `ubuntu:24.04` image to read
fresh random marker bytes from the **exact** scratch path via a read-only bind.
The probe uses `--pull=never` and `--network none`, with no image build, network,
credentials, or SSH agent. It verifies the owned probe container's identity and
removal. Visibility is proven only at probe time, not guaranteed for later mounts.
If the parent, cached image, daemon identity, or probe creation/read/removal is
unverifiable, execution fails before any build. A failed probe retains its
private scratch and inventory for inspection; no global prune or automatic
mode switch occurs. Remote Docker contexts are not reused. Missing
commands or unsupported base customization fail rather than selecting a fallback.

**Cost forecast:** one explicit `container:build`, then `container:up`, then
`container:recreate` through Task in a unique candidate. Expect significant CPU,
disk, network downloads, and potentially minutes of build/setup time. Recreate has
no explicit package rebuild step, but devcontainer startup may build according to
its own cache logic. This automates full-validation build/start/connect/recreate
and persistent-state/error/source-preservation items, not a new test layer.
Initialization proof and targeted Pi, SSH, audio, GUI integrations remain separate.

The fixture copies current public source changes into independent Git metadata
without remotes. In the **candidate only**, it selects `docker-compose.yml` plus
`config/compose/docker-compose-core-tools.yml` and
`container-svc`, retains the current base build and managed writable binds, and
replaces the attach configuration with the standard workspace mount, ubuntu user,
and setup command. Optional Compose overrides, custom attach settings, and CLI
features (including nested Docker and GitHub CLI) are omitted. Pi Coding and
SSH-server activation links are removed in the candidate; other selected installers
and user hooks remain trusted build inputs. Original selections are untouched.
The candidate clone uses umask `022` for ordinary `0644` files and `0755`
executables, while the source overlay preserves its existing modes; it does not
apply umask `077` to the whole clone.
The separate `.git/starter-test-runs/` registry is created at `0755`; its records
and leases remain private at `0600`, with scratch directories at `0700`.

Only synthetic environment files and a private empty host HOME are supplied:
no inherited SSH keys, agent sockets, Pulse endpoints, Docker credentials, or
authorized-key variables. Known runtime/credential paths are excluded from the
overlay; this is **not a universal secret scanner**. Review custom source code,
hooks, Dockerfile, and base Compose before explicitly executing privileged builds.
External binds, named Compose volumes, custom services/resources, and escaping
symlinks are rejected rather than guessed into a safe mapping.

Noninteractive `docker exec` as ubuntu proves direct execution, not Task attachment.
The harness compares applied manifest identity and actual managed mounts, checks
bind-root ownership/modes, writes unique markers, then verifies a new container ID
and marker persistence after recreation. Public tracked/untracked bytes, full modes,
symlink targets, branch, HEAD, index, and primary status are checked; excluded secret
environment contents are never hashed. Source preservation is checked on failure
as well as success. Mock regressions cover failure/interrupt cleanup; a successful
live cycle does not itself inject every possible operational failure.

### Read-only lifecycle preflight

After authorization to inspect the fixed local daemon, from the **CONTAINER
producer repository root** (the HOST shares this checkout):

```bash
task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle -- --preflight
# Inspect the separately consented runtime scenario without executing it:
task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle -- --preflight --runtime-directories --allow-generated-dockerfile-read
```

`--preflight` uses the existing lifecycle entry and argument forwarding, not a new
test layer. It shares parsing and checks with normal execution. The latter must
pass these checks **before `Run.create`**, then still register and pass the existing
cached-image exact-byte bind probe before candidate creation or build. Task's
normal candidate preparation and identity exports are unchanged.

Preflight creates no registry, inventory, lock, scratch, private HOME, Docker
configuration, candidate or probe container. It does not pull/build/start images,
run hooks, resolve `.env` files, alter process settings, repair permissions or
change native review mode. It reads public source inputs and filesystem metadata,
plus narrowly selected local Docker/tool metadata. Every external query has a
10-second timeout and rejects output larger than 256 KiB. No raw subprocess output,
exception, daemon ID, image ID, path, environment value or hook name enters its
public report. Separate operational invocation is authorization to query only
`unix:///var/run/docker.sock`; inherited Docker hosts, contexts, configurations,
SSH agents and credentials are not used or discovered. No ambient daemon fallback
is attempted. Do not run even this read-only recipe without local-daemon authority.

The checks cover available tools; repository root; an existing canonical writable
scratch parent outside the source and repository metadata; a safe current-user
registry (including safe legacy modes), or safe planned `0755` creation; selected
public build/installer/hook inputs; the fixed local socket and daemon metadata;
cached `ubuntu:24.04`; and exact Compose `5.5.1`/`5.6.0` and Dev Containers `0.89.0`
metadata. Buildx must answer its version query. The read-consent option additionally
checks fixed system native plugin discovery and admitted Compose metadata without
preparing the adapter or changing any of its execution/freeze gates.

Base/attachment exclude Pi and SSH activation; runtime adds only canonical SSH and
the synthetic port reset. Consumer inspection uses the publisher's current Pi/
Gentle Shell overrides and `starter-tools.json` selection, retaining the published
Features and hooks. Unsupported file-backed integrations, external build contexts,
escaping installer inputs or custom consumer attachment/Feature shapes fail early.
The report counts selected scripts by install group, including hooks; it does not
audit their behavior. **Inspect trusted hooks and Dockerfile and forecast costs
before authorizing execution.** Metadata readiness is not proof of daemon-visible
bytes, Compose reset behavior, a build, native delegation, cleanup or native review
approval. Live adapter protocol and ownership checks remain mandatory.

Exit status is `0` for metadata readiness and `1` for rejection. Both return one
bounded JSON object with this stable schema; no run is registered:

```json
{
  "schema": 1,
  "scenario": "base",
  "readiness": "ready",
  "checks": [{"stage": "tools", "reason": "checked"}],
  "stage": "complete",
  "reason": "metadata-ready",
  "next_step": "run-authorized-proof",
  "run": null
}
```

`scenario` is `base`, `consumer`, `attachment`, `runtime-directories`, or `invalid`
for malformed options. `readiness` is `ready` or `not-ready`. `checks` is the ordered
list of completed checks plus the failing check on rejection; generic success uses
`checked`, registry success uses `registry-safe` or `registry-planned-0755`, and
scope success uses `selected-build-inputs` with a `selected_scripts` group-count
object. Unknown, duplicate and incompatible selectors are rejected by the shared
parser. With `--preflight`, malformed options also return JSON without echoing argv.
Normal malformed invocations retain the existing usage error.

The first failing stage determines a fixed reason and operator next-step code:

| Stage | Reason | `next_step` |
| --- | --- | --- |
| `options` | `invalid-options` | `select-supported-options` |
| `tools` | `tools-unavailable` | `install-required-tools` |
| `source` | `source-unavailable` | `use-repository-root` |
| `scratch` | `scratch-unsafe` | `select-writable-scratch-parent` |
| `registry` | `registry-unsafe` | `inspect-registry-safety` |
| `scope` | `scope-unsupported` | `review-selected-build-inputs` |
| `endpoint` | `local-endpoint-unavailable` | `provide-authorized-local-daemon` |
| `daemon` | `daemon-metadata-unavailable` | `inspect-local-daemon` |
| `image` | `cached-image-unavailable` | `prepare-cached-probe-image` |
| `toolchain` | `toolchain-unsupported` | `use-reviewed-toolchain` |

These codes recommend operator investigation; they never grant repair, permission
changes, an image pull or execution. A ready report uses stage `complete`, reason
`metadata-ready`, and next step `run-authorized-proof`, which still requires the
separate execution authorization and forecast described below.

### Sanitized execution diagnostics

Execution and adapter failures use bounded `run`, `stage`, `reason`, `next_step`
and `evidence` fields. A validated version-4 run UUID is shown when available;
otherwise `run=none evidence=none`. `evidence=run-inventory:UUID` locates the private
`UUID.json` record in the source's Git-common-directory `starter-test-runs/`
registry; its scratch field locates retained logs. No supplied pathname is echoed.
Preflight retains its existing JSON schema and fixed codes above.

| Boundary | Fixed stage | Reason and next step |
| --- | --- | --- |
| Bootstrap environment and frozen modules | `environment`, `modulefreeze`, `moduleload` | `unknown`; `inspect-private-evidence` |
| Adapter guards | `binding`, `environment`, `producer`, `bakeinput`, `composeshape`, `preexec` | `guard-refused` for an explicit refusal, otherwise `unknown`; `inspect-private-evidence` |
| Native exec launch | `nativeexecution` | `execution-unavailable` for an OS launch failure, otherwise `unknown`; `inspect-private-evidence` |
| Lifecycle | `registration`, `registered`, `environment`, `binding`, `probe`, `prepare`, `build`, `up`, `restart`, `recreate`, `verify` | Allowlisted verification check, `interrupted`, or `unknown`; `inspect-private-evidence` |
| Finalization | `cleanup` | `retention-unverified`, `cleanup-unverified`, `outcome-unpersisted`, `primary-changed`, `primary-unverified`, `lease-unclosed`, or `unknown`; `preview-selected-run` |

The stage identifies the failed boundary, not an inferred provider/root cause.
Original failure and cleanup failures are reported separately; either prevents
PASS. Messages never echo argv, environment, headers, trace IDs, input JSON,
exception strings, keys or log dumps. Snapshot details admit only known bounded
integer counts; cleanup transport is summarized without provider text or names.
The native process retains its own stderr and exit contract after exec: the
harness does not rewrite native transport bytes. Both modules are frozen before
either executes; guard/recheck order, raw stdin and the single exact generated
Dockerfile `fs.read` grant are unchanged. Codes propose investigation only, never
repair, automatic retry, permission broadening or execution authority. Treat
private retained logs as sensitive and redact before sharing.

### Synthetic runtime-directory scenario

After separate operational authorization, from the **CONTAINER producer repository
root**, run:

```bash
task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle -- --runtime-directories
```

This selector is incompatible with `--consumer` and `--attachment`. The separately
consented [exact generated-Dockerfile read adapter](#optional-exact-generated-dockerfile-read-adapter)
may be added with `--allow-generated-dockerfile-read`; it is not enabled by default.
The default base proof remains unchanged.
The same optional `--daemon-visible-scratch ABSOLUTE_PARENT` and mandatory
cached-image exact-byte bind probe apply. No build starts if that probe fails.
Task's simulated HOST operations run only in the independent scratch candidate,
never with a guard bypass in the primary checkout.

**Preflight and cost forecast:** inspect current installers, hooks and Dockerfile;
require local Docker, cached `ubuntu:24.04`, a writable canonical scratch parent,
and Compose support for `ports: !reset []`. The candidate selects the canonical
SSH-server installer and managed server override, followed by a candidate-only
port-reset override. Unsupported reset behavior or nonempty resolved ports fails
before build; actual published ports must also be empty after both creations.
Production Compose files in the primary worktree are untouched. Budget roughly
5–15 minutes warm or 20–45 minutes cold, 2–8 GiB incremental disk/cache, and cold
package/tool downloads of roughly 0.5–2 GiB (cache and selected hooks can increase
these estimates). One base/core/optional-SSH build is explicit; up/recreate may
also invoke cached builds. Reserve a 45-minute soft budget and a longer supervisor
deadline, for example 60 minutes, for finalization; reassess if inputs exceed the
forecast. No consumer Features, nested Docker, updater, login or remote SSH proof
is requested by this scenario.

The fixture seeds only the candidate's independent `.git` with a synthetic
`gentle-ai/review-mode/rar-authority` at `0755`, owned safe parents, an innocuous
sentinel and distinct `0750` child/`0640` file modes. Original `.git` metadata and
real authority contents are never copied or inspected; public snapshots still
exclude `.git`. After up/postCreate and replacement/recreate, the proof requires
an actual writable candidate workspace bind, authority `0700`, unchanged parent
metadata, ownership/group, protected bytes and descendant modes.

The separately seeded, runtime-user-owned `.env.d/.ssh-server` bind root starts at
`0755`, with unselected sentinel data and no `ssh` child. The current manifest must
map that exact managed source to `/home/ubuntu/.ssh-server`. PostCreate must leave
the installer-owned root at `0700` and policy-created child at `0700`, preserving
unselected data, ownership and modes. Host/container metadata and synthetic hashes
must match; generated RSA/Ed25519 host-key bytes and modes must survive recreation.
Private bytes and hashes are not printed. A private run-owned HOME and allowlisted
environment exclude inherited credentials, agents and `SSH_AUTHORIZED_KEYS`.
There are no host port publications or SSH logins; container-local service startup
is exercised, not external connectivity or authorization.

Success uses the existing scoped resource cleanup; shared build cache and compact
diagnostics remain. Failure/interruption retains private scratch, inventory and
logs under the existing recovery contract. Generated keys and logs remain sensitive:
review/redact before sharing. This is synthetic lifecycle evidence, **not a Gentle
native receipt, native review approval, real-authority repair, or DinD proof**.

### Focused Task attachment scenario

After separate operational authorization, from the CONTAINER repository root:

```bash
task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle -- --attachment
```

This runs the reduced base lifecycle once, then exercises `container:connect` in
the isolated candidate as a **simulated HOST inside CONTAINER**. It is not proof
on the user's actual host or of consumer/nested Docker. The same optional scratch
parent, exact-byte cached-image probe, registration, inventory, fail-closed
ownership checks, cleanup and retention rules apply. No new cleanup authority exists.

Only the candidate's interactive connect `ARGS` is replaced by a deterministic
noninteractive Bash payload. The actual Task entrypoint, `ensure-running`,
`run-devcontainer`, and `devcontainer exec` remain in use. The payload checks ubuntu,
workspace path, a unique workspace marker, and a container-specific private marker;
the harness independently verifies the exact selected ID. Interactive welcome,
onboarding, other TUI entrypoints, SSH, and optional integrations are not covered.

Running desired-bind drift and a scoped, label-registered tokenless container must
warn and attach without changing the ID, actual mounts, synthetic root/generated
env bytes, applied manifest, or managed file bytes/ownership/modes. This separate
synthetic-state snapshot does not change primary credential exclusions. Intentional
fixture edits are restored between cases. Stopped and absent targets exercise strict
startup through Task; duplicate locale input rejects startup without recreate or
payload. The tokenless case uses the already-built image and scoped safe creation,
not provisioning or an old-token compatibility fallback. Similarly named unrelated
containers, engine-error injection and arbitrary custom mounts are not live-covered.

Cost: one explicit base build/recreate cycle plus two additional strict startup
attempts that succeed and two deliberately rejected attempts. Startup may still
build/download under CLI cache rules; the tokenless fixture uses the existing image.
Expect substantial image/build disk use and minutes of setup time, not measured
here. Allow a 30-minute soft operational budget initially, with a longer outer hard
deadline for cleanup; reforecast from inspected hooks/cache before launch. Running
attachments are bounded at 120 seconds, startup attachments at 600 seconds. Shared
build cache and compact private diagnostics remain retained. Recipes are not permission.

Successful tests automatically clean up through the ownership engine. Failed
tests and handled SIGINT/SIGTERM retain private scratch, `task.log`, inventory,
and identified owned resources; they verify and stop running owned containers
without removing them. Uncertain ownership prevents a stop. A failed run does
not block a new run with a distinct UUID. SIGKILL and supervisor hard kills
cannot run a finalizer: resources may still be running and the inventory may
be incomplete. Set a realistic timeout beyond the forecast build/cleanup budget,
then inspect the record and preview before authorizing recovery.

### Optional exact generated-Dockerfile read adapter

The maintainer harness accepts `--attachment --allow-generated-dockerfile-read`
or `--runtime-directories --allow-generated-dockerfile-read`. The read flag alone,
with `--consumer`, or repeated is rejected before run
registration. Defaults and consumer behavior are unchanged. This selector is not
a native Compose/Buildx flag and does not authorize running the lifecycle recipe.

After separate live authorization and a fresh cost/timeout forecast, add the
selector to the CONTAINER attachment or runtime-directory recipe above. The candidate remains a
simulated HOST inside CONTAINER; never use the primary worktree as a host fixture.
No live proof of this adapter is recorded here.

```bash
# CONTAINER: future live run only after explicit authorization and cost forecast.
task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle -- --attachment --allow-generated-dockerfile-read
# CONTAINER: alternative runtime-directory scenario, not a second authorized run.
task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle -- --runtime-directories --allow-generated-dockerfile-read
```

Consent covers only the exact validated generated Dockerfile from that run's native
invocation, never a directory/root read grant or an entitlement inferred from error
text. The runtime selector retains its SSH/no-port Compose forwarding, exact-byte
probe, synthetic preservation assertions and original resource closure. Its cost
forecast remains 5–15 minutes warm / 20–45 minutes cold, 2–8 GiB incremental cache
and roughly 0.5–2 GiB cold downloads; refresh these estimates and supervisor timeouts
before one authorized fresh attempt. A retained failed run is not resumed or cleaned
by selecting this adapter. Do not disable Bake or change global Docker environment.

**Private selection.** Preparation derives `HOME` from the registered scratch
inventory and verifies its marker, inode and held lease without calling Docker.
Only a future authorized live run copies installed native binaries. Its layout
under that run's `HOME/.docker` is:

| Path | Purpose | Mode |
| --- | --- | --- |
| `config.json` | Exact `cliPluginsExtraDirs` selection | `0600` |
| `generated-read.json` | Owned binding and nine base or eleven runtime path pins | `0600` |
| `plugins/docker-compose` | Private native Compose snapshot | `0500` |
| `plugins/docker-buildx` | Generated deterministic bootstrap | `0500` |
| `native/docker-buildx` | Private native Buildx, outside plugin discovery | `0500` |

The run home, `.docker`, `plugins` and `native` directories are owned by the run
user with mode `0700`. `DOCKER_CONFIG` selects this `.docker`; configuration
contains only `{"cliPluginsExtraDirs": ["<run-home>/.docker/plugins"]}`.
Buildx delegates to `native/docker-buildx`, not its discoverable wrapper, avoiding
wrapper recursion. Compose's actual parent executable must be its private copy.

The nine pinned paths comprise the two natives, config, launcher, exact repository
adapter/helper dependencies and three candidate inputs. Runtime-directory selection
adds only the exact candidate SSH Compose and no-port-reset inputs, pinned during
preparation; the Compose parent must forward both in that order before its generated
build override. Reset bytes must be exactly `ports: !reset []` in the accepted
service fragment, and both inputs retain startup bytes/owner/mode checks plus full
per-invocation identity rechecks. No arbitrary extra Compose file is accepted.
The bootstrap validates
dependency owner/mode/identity/hash through bounded no-follow descriptor reads,
then compiles the verified bytes without a module-path reread or custom import
fallback. It embeds the binding path for internal Docker metadata calls that omit
`HGDR_BINDING`; a foreign provided binding is refused. The legacy repository entry
`test/lifecycle/narrow-plugins/docker-buildx` remains in the tree but is no longer
selected by prepared runs; it is not the generated private entry.

**Accepted local trust.** Only `docker-compose` and `docker-buildx` from
`/usr/libexec/docker/cli-plugins` or `/usr/lib/docker/cli-plugins` are accepted.
Sources must be root/current-user-owned executable regular files, at most 128 MiB,
with no symlink components or world-write permissions. Existing group-write is
accepted only in this origin reader under the owner's explicit trust in current
local bytes. Stable descriptor/ancestry checks and independent destination hashes
prove snapshot integrity, not vendor authentication or benign content. Root
ownership does not make a source immutable. Strict destination/dependency
`Inputs` checks remain unchanged; no installed source or global permissions are
modified, and no plugin installation or global Docker configuration is changed.

**Before launch.** Opt-in Task and direct attachment producers validate private
selection before launch, including running, stopped and absent connection routes.
Missing or changed private inputs refuse launch, not force a system-plugin
fallback or automatic retry. Environment selection is published only after
successful preparation/validation. Private checks do not compare temporary
current desired-core drift: warning-only running attachment remains allowed;
actual Bake still validates candidate startup bytes and producer authority.

All private copies belong to the existing scratch scope. Successful cleanup and
failure retention use the existing inventory/lease engine, not new authority.
On failure, retain and inspect the private run record before authorizing recovery;
do not loosen selection or permissions to continue. The engine pins Linux
PID/start-ticks/session/boot identity before releasing its stopped producer.
Legacy inventories remain readable/recoverable under existing policy; missing
anchors cannot authorize this adapter and are never fabricated.

**Evidence boundary.** Focused synthetic fixtures cover lifecycle, adapter
and ownership contracts, with native execution, subprocess and daemon
effects mocked. This is not actual Docker plugin discovery, native relocation,
protocol compatibility or live lifecycle proof; those need separate authorization.

Bake accepts only bounded duplicate-key-free JSON, one exact `container-svc`
target/default group, the candidate context/image/run label and fixed base build
arguments. Compose 5.5.1's source-backed argv requires stdin, `rawjson` progress,
one fresh `/tmp/compose-build-metadataFile-UUID.json` native result path, and the
exact ordinary context read grant, not additional input files, overrides, arbitrary
targets, secrets, SSH, network/devices, inline Dockerfiles, extra contexts or broad
filesystem/write grants. Unsupported native shapes fail closed rather than being
adapted implicitly. Native Bake JSON/argv forwarding remains unproved without a
separately authorized live run.

The exact admitted Compose producer labels are `5.5.1` and `5.6.0`, not a version
range. Independent pre-change verification of an isolated native Compose `5.6.0`
capture found that its original payload rejected only the version label; changing
that label to `5.5.1` in memory passed all remaining strict argv, schema, build
arguments, context, labels, output, tags and generated-byte checks. The capture used
native Buildx `0.38.0` and Dev Containers `0.89.0`'s matching layout, with zero native
Buildx delegations. This proves the observed controlled producer shape, **not a
native Buildx build, successful lifecycle or general version compatibility**.

Version labels alone never authenticate a producer: all existing binary/input pins,
lease, ancestry, owner/inode/content and exact-file grant checks still apply.
Unknown or malformed versions and incompatible shapes fail closed; no ranges,
global filesystem grants or automatic fallback are admitted. Tracked tests use only
synthetic known-shape fixtures, not private captured JSON, argv, environment or paths.
Historical private capture artifacts remain immutable; their source pins were
independently verified before this edit, not refreshed to claim current readback
after the expected source-hash change. Fresh live proof still requires independent
verification, a renewed cost/timeout forecast and explicit operational authorization.

The native result path is constrained to Compose's UUIDv4 naming contract, absent
including dangling symlinks, with canonical parent identity rechecked before exec.
It adds no `fs.write` entitlement or directory grant. JSON requires the exact
Compose project/service/version labels and `output: ["type=docker"]`; an explicit
`target` may only select `dev_containers_target_stage`. Cache, platform,
attestation and other non-base build fields remain unsupported, even if empty;
`annotations` is not a Compose 5.5.1 `bakeTarget` field. Unknown shapes fail closed.
The pinned Compose parent accepts the canonical leading `compose` plugin token,
or the direct executable form, but no arbitrary Docker global flag prefix.

Documentary sources, not live traces:
[Compose 5.5.1 Bake](https://raw.githubusercontent.com/docker/compose/v5.5.1/pkg/compose/build_bake.go),
[image build labels](https://raw.githubusercontent.com/docker/compose/v5.5.1/pkg/compose/build.go),
[standalone shell-out](https://raw.githubusercontent.com/docker/compose/v5.5.1/pkg/compose/shellout.go),
[Docker CLI 29.8.1 plugin argv](https://raw.githubusercontent.com/docker/cli/v29.8.1/cli-plugins/manager/manager.go),
and [Buildx 0.37.2 entry point](https://raw.githubusercontent.com/docker/buildx/v0.37.2/cmd/buildx/main.go).

The accepted generated layout is Dev Containers 0.89.0's observed metadata-only
prefix/base/suffix and exact build override. Candidate pins, active inventory and
lease, local daemon identity, original producer ancestry/session, immediate pinned
Compose parent, structural override and post-producer file timestamps are checked.
Files are descriptor-read without following symlinks; identity/mode/hash, paths,
parents and process bindings are rechecked before native exec. Validated stdin is
frozen in an unlinked descriptor; native receives one additional exact-file
`fs.read` grant. Metadata and non-Bake commands delegate unchanged to native,
including stdin/environment/exit behavior; the adapter does not emulate metadata.

**Race limit:** Docker selection/native execution and Buildx's generated-file
read still use pathnames. Same-user replacement after final checks cannot be
excluded, including replacement of private copies or their launcher. This
cooperative harness adapter is not a sandbox; hashes, timestamps and labels do
not provide stronger isolation. Features and changed generation layouts require
explicit source review, not broader grants or automatic retries.

## Recovering test-owned resources

Start with a read-only preview from the **CONTAINER original source worktree root**:

```bash
task --taskfile .maintainer/Taskfile.yml test:starter:clean
task --taskfile .maintainer/Taskfile.yml test:starter:clean -- --run RUN_UUID
# After reviewing that run's scope, explicitly authorize deletion:
task --taskfile .maintainer/Taskfile.yml test:starter:clean -- --apply --run RUN_UUID
# Also discard its diagnostics, only after resources are verified gone:
task --taskfile .maintainer/Taskfile.yml test:starter:clean -- --apply --run RUN_UUID --forget
```

`RUN_UUID` is printed by the participating test or recovery preview. The
explicit lifecycle builds and recovery are not invoked by
`task test`, the maintainer `test:starter` suite, or `task validate`.
Normal unit execution does include
mock tests of the cleaner, not an invocation of live recovery.

**Scope:** the base lifecycle harness registers its resources.
The former Docker ARG-to-ENV image-contract fixture has been retired with the
Engram, Node, and Playwright library version overrides. Other suites retain their own
fixture cleanup; arbitrary commands, custom hook resources, unlabelled resources,
and the real devcontainer are not automatically adopted by this helper.

The local registry is `starter-test-runs/` beneath
`git rev-parse --path-format=absolute --git-common-dir` (normally
`.git/starter-test-runs/`). It is outside removable scratch, untracked Git metadata,
and shared by linked worktrees; each record remains bound to its original canonical
source worktree. No Git configuration or index changes are needed. The store is
created at `0755` independently of umask `077`. Existing safe modes, including
`0700` and `0750`, are preserved without migration. Registry validation requires a
canonical, non-symlink directory owned by the current user, owner read/write/search,
and no group/other writes; it does not require directory privacy. Records/leases
remain `0600`, scratch and private children `0700`, and frozen executable snapshots
`0500`. Imports and default preview do not create or chmod the registry or records.
An exclusive lease prevents concurrent recovery of a running test. Setup's generic
normalization excludes Git administration, so it does not migrate an existing store.

Before side effects, the engine records the run UUID, source binding, canonical
scratch scope, local endpoint and actual daemon ID. It registers the sandbox
filesystem identity and ownership marker, verifies project/label/tag absence, then
arms narrowly scoped discovery. Producers wait for their process group to be
recorded before executing. Resource IDs and expected labels are captured
incrementally; scoped discovery also recovers resources created between a Docker
operation and its next inventory write, including recreation replacements. Recovery
refuses while a recorded producer process group remains present.

Immediately before removal, the engine rechecks the daemon, resource IDs and
ownership labels; volumes also require their recorded creation identity. Missing
resources are idempotent success, but a failed query is **not** proof of absence.
Conflicting or malformed records, unexpected labels, changed worktree binding,
symlink escapes, and unverifiable filesystem ownership stop cleanup without trying
a broader scope. Containers may be force-removed only by their verified owned IDs;
networks/volumes are removed individually. No global prune or sudo fallback exists.

Owned images are removed without force or parent pruning only when their labels,
recorded ID, unchanged exclusive run tag (or untagged identity), tag-to-ID mapping,
and absence of container users can be verified. The permitted tags are the base
run tag and the exact Dev Containers UID tag derived from the recorded candidate
path, not arbitrary prefix matches. A local repository digest is accepted only
when its repository matches that sole tag and its digest equals the captured image
ID; foreign digest references or additional tags still prevent removal. Shared,
retagged, or otherwise unverifiable images are retained and reported; that is not
a successful complete test cleanup. **Shared build cache is deliberately retained**:
there is no dedicated test builder, so removing it would affect unrelated builds.

Outcomes distinguish removed-and-verified resources, deliberately retained cache
or images, and failed/unverifiable cleanup. Preview does not write records, stop
containers, or delete files. `--apply --run` is the explicit deletion request;
`--forget` additionally requires `--apply --run` and verified resource absence.
Applying cleanup without forget keeps the compact record; retained images or
unverifiable ownership prevent forgetting. Failed runs preserve private scratch
and raw `task.log` until explicitly cleaned. Treat these files as sensitive:
inspect locally, do not publish or paste logs without reviewing and redacting
secrets. The structured inventory contains bounded stage, exit, test, cleanup,
and previously running IDs—not raw commands, environment, or log excerpts.
Recovery reports the scratch scope if filesystem cleanup fails.
Do not remove ownership metadata or escalate to global cleanup when uncertain.
Interrupted registration can leave a directory whose marker was not completed;
recovery refuses to guess ownership. This is a scoped operational aid, not a commit
gate or a universal no-residue guarantee.
