# Select a scoped Starter operational proof

Use the existing maintainer harness from the **CONTAINER producer repository
root**, currently `/home/ubuntu/gentle-starter`. The HOST owns this bind-mounted
checkout; it is not an independent clone. Recipes below are **not execution
authorization**. This skill and reference are producer-only, excluded from the
consumer tree; `add-tool` remains distributed.

## Choose evidence before commands

| Need | Command | Boundary |
| --- | --- | --- |
| Application behavior | `task test` | Application-owned; fails as not configured until the owner replaces `tasks.test.cmds`. Inspect the configured command and effects first. |
| Starter regression | `task --taskfile .maintainer/Taskfile.yml test:starter` | Maintainer-only unit/integration, not live lifecycle. Derived applications need not satisfy Starter editorial/distribution tests. Inspect fixtures: some commit synthetic Git history or build/run lifecycle operations. |
| Repository quality | `task validate` | HOST preflight is partial; CONTAINER runs diagnosis and strict quality. Neither is application or full runtime proof. `install:doctor` is not application proof either. |
| Operational readiness | Lifecycle `--preflight` recipe below | Separately authorized metadata queries only, not runtime proof. |
| Runtime persistence | `task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle` | Separately authorize one scenario, cost forecast, exact-byte probe and effects; base coverage is deliberately reduced. |
| Registered resource recovery | `task --taskfile .maintainer/Taskfile.yml test:starter:clean` | Read-only preview by default; apply/deletion requires one selected run and explicit authority. |
| Real environment | `task container:*` | Normal HOST workflow, not test cleanup; up/recreate can build, restart preserves the container. |

For normal changes, the **CONTAINER producer repository root** baseline is below.
Inspect and select safe fixtures when execution permissions are restricted;
this baseline does not authorize operational effects or expensive tests.

```bash
task install:list
task install:doctor
task install:volumes
task validate
task --taskfile .maintainer/Taskfile.yml test:starter
```

Inspect current source, selected installers, Dockerfile, hooks, installed toolchain
and canonical writable scratch parent before authorizing execution. Hook counts
are not a behavioral audit or a universal secret scan. Never inspect ambient
credentials to discover authority. Ordinary **HOST** `task container:*` commands
belong at the authorized host checkout root, not in this CONTAINER; never bypass
the primary checkout's host guard. HOST commands must skip in the active CONTAINER.
Harness HOST simulation is scratch-only: `FORCE_HOST_CONTEXT=1` requires an
explicitly authorized independent temporary repository copy, never the primary
worktree for destructive bootstrap tests. For ad hoc copies, use a daemon-visible
mounted workspace; the registered harness instead uses its canonical, exact-byte
probed scratch parent described below and in the authoritative
[lifecycle contract](../../../../.maintainer/README-distribution.md#explicit-base-lifecycle-proof).
Do not infer another host path or daemon topology. The CONTAINER simulates a HOST
for that fixture; clone/build/up evidence is separate from optional consumer
inside-container/nested-daemon proof.

## Authorize destinations and effects

| Destination | Required effect scope |
| --- | --- |
| Primary shared HOST checkout | Authorize only intended edits/queries; preserve HEAD, index and unrelated state. A primary commit grant does not authorize fixture commits. |
| Owned isolated Git fixture | Authorize temporary paths plus synthetic staging, commits and refs when required. A fixture grant never authorizes primary staging or commits. |
| Consumer fixture / local daemon | Consumer proof needs isolated Git history authority **and** privileged Features authority, including declared containers, volumes and cache retention. |
| Implicit output | Account for bytecode, logs, inventories, locks, private HOME/configuration and tool outputs before launch; keep them inside the authorized destination. |

These are separate grants, not implied global, remote or credential consent.
Inspect the chosen existing fixture's effects before selecting its command.
Permission to edit instructions does not authorize running their recipes.

## Read-only readiness recipe

After explicit authority to query the fixed local daemon, from the **CONTAINER
producer repository root**:

```bash
PYTHONDONTWRITEBYTECODE=1 task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle -- --preflight
```

This shares parsing/validation with execution but creates no registry, inventory,
lock, scratch, private HOME, Docker configuration, candidate or probe container.
It performs no pull/build/start, hook execution, environment-file resolution,
permission repair or review-mode change. External queries have 10-second timeouts
and a 256 KiB output limit. Only `unix:///var/run/docker.sock` is selected; inherited
contexts, hosts, configurations, agents and credentials are not discovered.

Checks include safe registry metadata (or planned `0755` creation), public inputs,
cached `ubuntu:24.04`, Compose exactly `5.5.1` or `5.6.0`, Dev Containers exactly
`0.89.0`, and a responding Buildx version query. Unsupported selectors or shapes
fail closed. JSON exit `0` means metadata readiness; exit `1` means rejection.
Keep fixed `stage`, `reason` and `next_step` evidence. The first failure's suggested
next step grants no installation, pull, repair or execution authority.

Prefix local Python and Task preflight, runtime and recovery recipes with
`PYTHONDONTWRITEBYTECODE=1` to prevent checkout `__pycache__`/`.pyc` output.
This process-only suppression fits the operation's existing authorization:
no global configuration mutation or additional approval is needed for it.
It neither bypasses permission guards nor makes other command effects read-only.

## Prove the intended rejection

For negative checks, require all three: the expected numeric exit, the intended
stage/specific diagnostic, and unchanged protected state. An earlier guard failure
is not success for a later permission, daemon or ownership assertion. Compare
protected bytes, modes, HEAD/index or resource identity as applicable to the case.

Inspect current query contracts when using Git stubs: new real-Git queries need
faithful fixture responses. Assert the precise branch diagnostic rather than any
nonzero exit or broad error substring. Prefer existing fixture assertions; this
guidance adds no fixture implementation or runtime framework.

## Explicit runtime proof

After separate operation authorization and forecast, from the **CONTAINER
producer repository root**, the smallest base recipe is:

```bash
PYTHONDONTWRITEBYTECODE=1 task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle
```

Default scratch is a generated `/home/ubuntu/starter-test-<UUID>`; an alternative
existing canonical parent requires `--daemon-visible-scratch ABSOLUTE_PARENT`
and must remain outside source and Git metadata. Registration precedes the
cached-image exact-byte read-only bind probe. Probe identity and removal must be
verified before candidate creation/build; no pull or build supplies a missing
probe image. Missing parent, image, daemon visibility or verified cleanup fails
closed. Readiness never proves daemon-visible bytes or cleanup.

The expensive base scenario proves build/start/connect/recreate and managed-state
preservation only. It automates those operational full-validation items, not a
seventh test layer, and is not included in `test:starter` or `validate`. Follow the
[base lifecycle contract](../../../../.maintainer/README-distribution.md#explicit-base-lifecycle-proof)
for the deliberately reduced sandbox coverage.

Select only one justified scenario: base persistence, `--attachment` Task/CLI
identity, `--runtime-directories` synthetic SSH/authority modes without published
ports, or `--consumer` filtered fixture/nested DinD. Consumer fixtures commit Git
history and invoke privileged Features; they require that separate authority.
The exact generated-Dockerfile adapter is separately consented, only with
attachment/runtime; it adds no broad read grant or native review approval.
Optional Pi, SSH login, audio and GUI proofs remain separate.

Forecast downloads, build time, disk, hook effects and retained shared cache.
For network/build checks, explicitly set the external execution tool or supervisor
timeout rather than relying on short defaults. Starting guidance is 10 minutes
per real `task tools:update` call or 30 minutes for a combined updater/build/
verification flow, adjusted for cache, network and download scope before launch.
These are guidelines, not Task flags, enforced limits or promised pass budgets;
keep the outer hard deadline beyond the planned work/soft budget for shutdown and
cleanup. Follow the authoritative
[timeout guidance](../../../../.devcontainer/docs/extending.md#execution-timeouts-for-operational-checks).
For runtime directories the documented starting estimate is 5–15 minutes warm
or 20–45 minutes cold, 2–8 GiB incremental cache and 0.5–2 GiB cold downloads.
Reforecast for current inputs. Set an external soft budget and longer hard
deadline (for example 45/60 minutes for that scenario); these are not Task flags.
Hard kills may bypass finalization. Timeout means incomplete proof, not a
provider, build or functional diagnosis; preserve successful stages and inspect
processes and registered resources before any bounded, separately authorized
continuation.

## Report execution and timing

Use `not-started` when a required helper is unavailable before launch; this is
neither a proof attempt nor a failed runtime test. Use `failed` for an observed
rejection, `interrupted` for incomplete execution, and `verified` only for all
required stage assertions and cleanup evidence. Readiness is a separate boundary.
Do not retry blindly: preserve the first failure and inspect registered state
before separately authorized bounded continuation.

Report numeric exit and observed elapsed time with the existing shell's `time`
builtin or an available monotonic-clock helper; do not install a timer or require
`/usr/bin/time`. If either value was not captured, mark it `unknown`.
Historical durations are evidence, not forecast promises. Keep the hard deadline
longer than the soft budget for graceful shutdown; report original and cleanup
failures independently even when timeout finalization runs.

## Retention and failure evidence

Successful runs automatically clean run-owned resources and require verified
removal; shared build cache remains. Failures/interruptions retain private scratch,
inventory, logs and identified owned resources. The finalizer stops only verified
running owned containers; a hard kill may bypass it. Consumer DinD
keeps two Feature state volumes deliberately, not owned or removed by recovery.
Together with retained shared cache, this is not full removal.
Uncertain daemon identity, ownership or permissions stop recovery, never trigger
sudo, global pruning, authority repair or mode changes.

Account separately for resources **created**, **observed**, **removed (verified)**,
**retained (intentional)** and **unknown**. Record identity at creation through
existing fixture entry/teardown or registered inventory; prefer that evidence to
polling or `/proc` scraping. No-error teardown alone proves no removal. If only
some roots were captured, report that coverage and keep uncaptured roots unknown;
do not infer all roots disappeared. State cleanup confidence and its evidence.
This is an evidence contract, not a request to implement another tracker.

After separate query authorization, preview from the **CONTAINER original source
worktree root**:

```bash
PYTHONDONTWRITEBYTECODE=1 task --taskfile .maintainer/Taskfile.yml test:starter:clean -- --run RUN_UUID
```

Use the emitted run UUID, not a guessed resource prefix. Preview does not delete
or stop resources; apply/deletion and forgetting need separate authorization and
verified scope. `--apply` requires one selected `--run`; `--forget` additionally
requires `--apply --run` and verified resource absence. The scoped engine covers
participating lifecycle and image-contract fixtures, not arbitrary scripts or
hook resources. This helper is neither a delivery gate nor commit authorization.
Follow the authoritative
[recovery contract](../../../../.maintainer/README-distribution.md#recovering-test-owned-resources)
for examples and retention effects. Report original failure separately from
cleanup failure; either prevents PASS. Use sanitized stage/reason/next-step fields and private inventory
locators; review and redact retained logs before sharing, never paste raw secrets.

## Permission migration is a separate operation

Before an authorized mode migration, verify the canonical path, no symlink,
ownership/identity and exact mode scope. Already-compliant state is a no-op.
A separately authorized registry-root migration from `0700` to `0755` is
nonrecursive: preserve every descendant's private mode and all existing gates.
Repairing a RAR authority directory to its required `0700` mode is a separate
operation, never an automatic part of registry migration or a response to failed
readiness. These examples authorize
no actual mode change, escalation or review toggle.

## Offline explicit-file Markdown verification

From a **CONTAINER temporary check directory** outside the shared checkout, use
the installed offline Markdownlint CLI. Copy the producer root's effective
`.markdownlint-cli2.yaml` rules into a temporary check configuration, removing
only the `.agents/**` ignore. Keep all other ignores/rules; use `--no-globs` and
the absolute paths of this skill and reference (optionally the parent task record).
Read the reported actual file count: require two authored files, or three with
the record. Root defaults ignore `.agents/**`, so a zero-file result is no proof.
Do not install tools, use networked `npx`, or execute operational recipes to lint.

For this producer path, after preparing that temporary configuration, the offline
recipe below checks both authored files. Run from
**CONTAINER `/tmp/opencode`**, not the primary checkout:

```bash
markdownlint-cli2 --config /tmp/opencode/skillguidance-markdownlint-cli2.yaml --no-globs /home/ubuntu/gentle-starter/.agents/skills/operational-verification/SKILL.md /home/ubuntu/gentle-starter/.agents/skills/operational-verification/references/starter-harness.md
```

Optionally append the current parent-record path and expect three checked files;
do not edit that record as part of skill verification. This recipe must report
`Linting: 2 files`,
not the CLI's separate issue-file count in `Summary: 0 issues in 0 files`.

## Authoritative local details

Read the [distribution and lifecycle guide](../../../../.maintainer/README-distribution.md)
for exact scenario, adapter, preflight, diagnostics and recovery contracts.
