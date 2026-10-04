# Prepare linear consumer releases locally

## Isolated candidate preparation (local only)

Integrate the release code into `dev` separately before preparing a release;
this feature branch alone does not make it available on `dev`. The old local and
remote `starter` refs are absent, and no new `starter-rc` or `starter` release has
been published. A local `backup/starter-before-linear` preserves the old ref at
`42b5d16`; it is not a release base. With a clean checkout and committed `dev`,
run `task --taskfile .maintainer/Taskfile.yml distribution:candidate -- --base-absent`
for the first local candidate. For later releases, omit `--base-absent` to pin the
existing local `starter` as the base. The command does not change `starter`, the
checkout, or remotes. Inspect the candidate
commit message for `Starter-Candidate-Source` and `Starter-Candidate-Base`, and
inspect its tree before any separate promotion. The first candidate is a root;
subsequent candidate commits have only the preceding candidate as parent. A
source-only advance creates a new candidate even when its filtered tree is
unchanged. Repeating the same source under the current policy is a no-op. For an initial release with
no local `starter` ref, pass `--base-absent` explicitly to candidate creation
and cancellation. Never use this flag when `starter` already exists.

To discard a candidate, run
`task --taskfile .maintainer/Taskfile.yml distribution:candidate -- --cancel --base-absent`
for the first candidate (omit `--base-absent` for later releases).
This deletes only a verified local candidate ref; it refuses a changed base or
unrecognized candidate. After cancellation, a new candidate starts from a new
root. Candidate preparation is not publication; promotion to a linear `starter`
release is not performed by this command. After reviewing the candidate,
record its full commit SHA, tree SHA, source SHA from the candidate marker, and
the exact base SHA (or `absent` for a new release ref). Promote locally with:

```bash
task --taskfile .maintainer/Taskfile.yml distribution:promote -- \
  --approved-rc FULL_RC_SHA --expected-tree FULL_TREE_SHA \
  --expected-base FULL_BASE_SHA_OR_absent --expected-source FULL_SOURCE_SHA
```

Promotion refuses a moved or canceled candidate, mismatched tree/source/base,
unrecognized release history, symbolic refs, dirty checkout, or a
release checked out in any worktree. It verifies the entire candidate chain,
filtered trees for every previous release against its recorded source, and
previous release source ancestry; it then creates one root
release (initial) or one commit with the prior release as its sole parent and
compare-and-swap updates the local release ref. It does not require the source
branch to be checked out or at the approved source tip. No remote is touched.
After promotion, `starter-rc` remains pinned to the approved candidate but its
base is stale. Cancel the verified candidate with
`task --taskfile .maintainer/Taskfile.yml distribution:candidate -- --cancel`
before preparing another; the new local `starter` exists, so do not pass
`--base-absent`. Cancellation
verifies that the new release published that candidate. A canceled candidate
cannot be promoted. Neither candidate creation, cancellation, nor promotion
fetches, pushes, or deletes remote refs. Verify the local root release and its
tree after first promotion. Any remote publication requires separate review and
explicit authorization for destination, operation, and credential/session.
Future consumer clones of the new root will not share ancestry with `dev` or
with the old unpublished branch.

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
normalizer, including exact tree recomputation for every ancestor. No other filter
policy changes. Unknown, duplicate or malformed markers fail closed; there is no
legacy creation switch. New promotion requires an explicitly current candidate.
Historical RC `28a42cc55…` and release `ef2f71e5…` remain valid history, not an
approval to publish the new preset. A legacy same-source RC can gain a current-policy
child only if that committed source already contains all four active entries;
source equality is allowed by the unchanged ancestry check. Otherwise commit a
new source first. Source/base pins, approved IDs, exact trees, parent provenance
and compare-and-swap remain required. No primary publication has been performed
for this change. The reduced base lifecycle fixture below intentionally stays two.

## Explicit base lifecycle proof

For an explicit **consumer release/DinD smoke** instead of the reduced base
scenario, run `task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle -- --consumer`
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
The separate `.git/starter-test-runs/` inventory stays private at `0700`.

Only synthetic environment files and a private empty host HOME are supplied:
no inherited SSH keys, agent sockets, Pulse endpoints, Docker credentials, or
authorized-key variables. Known runtime/credential paths are excluded from the
overlay; this is **not a universal secret scanner**. Review custom source code,
hooks, Dockerfile, and base Compose before explicitly executing privileged builds.
External binds, named Compose volumes, custom services/resources, and escaping
symlinks are rejected rather than guessed into a safe mapping.

Noninteractive `docker exec` as ubuntu proves connection without an SSH server.
The harness compares applied manifest identity and actual managed mounts, checks
bind-root ownership/modes, writes unique markers, then verifies a new container ID
and marker persistence after recreation. Public tracked/untracked bytes, full modes,
symlink targets, branch, HEAD, index, and primary status are checked; excluded secret
environment contents are never hashed. Source preservation is checked on failure
as well as success. Mock regressions cover failure/interrupt cleanup; a successful
live cycle does not itself inject every possible operational failure.

Successful tests automatically clean up through the ownership engine. Failed
tests and handled SIGINT/SIGTERM retain private scratch, `task.log`, inventory,
and identified owned resources; they verify and stop running owned containers
without removing them. Uncertain ownership prevents a stop. A failed run does
not block a new run with a distinct UUID. SIGKILL and supervisor hard kills
cannot run a finalizer: resources may still be running and the inventory may
be incomplete. Set a realistic timeout beyond the forecast build/cleanup budget,
then inspect the record and preview before authorizing recovery.

## Recovering test-owned resources

Start with a read-only preview from the **original source worktree**:

```bash
task --taskfile .maintainer/Taskfile.yml test:starter:clean
task --taskfile .maintainer/Taskfile.yml test:starter:clean -- --run RUN_UUID
# After reviewing that run's scope, explicitly authorize deletion:
task --taskfile .maintainer/Taskfile.yml test:starter:clean -- --apply --run RUN_UUID
# Also discard its diagnostics, only after resources are verified gone:
task --taskfile .maintainer/Taskfile.yml test:starter:clean -- --apply --run RUN_UUID --forget
```

`RUN_UUID` is printed by the participating test or recovery preview. The
explicit lifecycle and image-contract builds, and recovery, are not invoked by
`task test`, the maintainer `test:starter` suite, or `task validate`.
Normal unit execution does include
mock tests of the cleaner, not an invocation of live recovery.

**Scope:** the base lifecycle harness and the Docker image-contract fixture in
`.maintainer/test/operational/image-contract.bats` register their resources.
The latter has a unique run tag and retains failure evidence even when a build
or assertion fails. Other suites retain their own
fixture cleanup; arbitrary commands, custom hook resources, unlabelled resources,
and the real devcontainer are not automatically adopted by this helper.

The private local store is `starter-test-runs/` beneath
`git rev-parse --path-format=absolute --git-common-dir` (normally
`.git/starter-test-runs/`). It is outside removable scratch, untracked Git metadata,
and shared by linked worktrees; each record remains bound to its original canonical
source worktree. No Git configuration or index changes are needed. The store is
mode `0700`, records/leases are `0600`; imports and default preview do not create or
repair records. An exclusive lease prevents concurrent recovery of a running test.

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
