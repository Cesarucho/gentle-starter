# Prepare linear consumer releases locally

## Isolated candidate preparation (local only)

With a clean checkout and committed `dev`, run
`task --taskfile .maintainer/Taskfile.yml distribution:candidate` to create or
advance `starter-rc`. The command reads the current local `starter` as its pinned
base; it does not change `starter`, the checkout, or remotes. Inspect the candidate
commit message for `Starter-Candidate-Source` and `Starter-Candidate-Base`, and
inspect its tree before any separate promotion. The first candidate is a root;
subsequent candidate commits have only the preceding candidate as parent. A
source-only advance creates a new candidate even when its filtered tree is
unchanged. Repeating the same source is a no-op. For an initial release with
no local `starter` ref, pass `--base-absent` explicitly to candidate creation
and cancellation. Never use this flag when `starter` already exists.

To discard a candidate, run
`task --taskfile .maintainer/Taskfile.yml distribution:candidate -- --cancel`.
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
unrecognized or legacy release history, symbolic refs, dirty checkout, or a
release checked out in any worktree. It verifies the entire candidate chain,
filtered trees for every previous release against its recorded source, and
previous release source ancestry; it then creates one root
release (initial) or one commit with the prior release as its sole parent and
compare-and-swap updates the local release ref. It does not require the source
branch to be checked out or at the approved source tip. No remote is touched.
After promotion, `starter-rc` remains pinned to the approved candidate but its
base is stale. Cancel the verified candidate with
`distribution:candidate -- --cancel` before preparing another; cancellation
verifies that the new release published that candidate. A canceled candidate
cannot be promoted. Neither candidate creation, cancellation, nor promotion
fetches, pushes, or deletes remote refs. The existing `distribution` and
`distribution:producer` commands remain available but are deprecated for new
linear releases; they retain their legacy
source-parent and merge behavior until a later task replaces them.

## Local cutover from the unpublished legacy branch

The old local `starter` created by `distribution` has a `dev` source parent; it
cannot be used as the base of a linear release. There are no consumers yet, but
do not assume a clone of the new `starter` shares ancestry with `dev` or with
the old unpublished branch. Cutover is a separate, explicitly authorized LOCAL
operation; do not run it as part of candidate preparation or promotion.

1. Inspect `git status --short --branch`, `git worktree list`, and
   `git show-ref --verify refs/heads/starter`. Require a clean checkout and no
   worktree using `starter`; record its full SHA. Preserve it with
   `git branch backup/starter-before-linear starter` and verify both refs point
   to the recorded SHA. Do not delete the backup during cutover.
2. Only after explicit authorization to replace the local unpublished ref,
   verify the branch SHA still matches the recorded SHA, then run
   `git branch -d starter` if Git accepts it, or `git branch -D starter` only
   with explicit approval for forced deletion of this verified local ref.
   Never delete an unknown, moved, checked-out, or remote branch.
3. With `starter` absent, prepare `distribution:candidate -- --base-absent`.
   Review the candidate commit, filtered tree and source marker. Promote with
   `--expected-base absent` and the other full approved IDs shown above.
   Verify the release has zero parents, its tree matches the candidate, and
   the backup still points to the old SHA. Cancel the published candidate
   only after verifying publication. Retain the backup until a separate
   authorization to remove it after verifying the new release and any
   consumer migration; do not automatically delete old refs.

No remote operation is performed by these tasks or by this playbook. Publishing
or replacing a remote branch needs its own destination, credential/session,
review, and explicit authorization. Existing clones of the old branch would
not gain ancestry with a new root; migrate them deliberately rather than
assuming an ordinary merge will work.

## Legacy distribution commands (not for linear releases)

From a clean producer checkout, commit the source changes on `dev` first (or
pass another committed local source branch explicitly).
Keep the existing local `starter` branch available (not checked out in another
worktree), then prepare it without switching branches:

```bash
task --taskfile .maintainer/Taskfile.yml distribution:producer -- --source dev --target starter
git status --short --branch
git log --oneline --decorate -5 starter
git diff dev...starter --stat
git ls-tree -r --name-only starter
git merge-base --is-ancestor dev starter
bats .maintainer/test/unit/starter-distribution.bats
```

Review the resulting branch tree and ancestry before any publication. The
producer task uses a temporary target checkout and normally removes it afterward;
on conflict it aborts that merge and reports failure. If addition or cleanup fails,
it reports the original error and cleanup uncertainty separately. A dirty or
unverifiable checkout may remain at the reported temporary path; inspect it and
the target ref before retrying. The task checks the target HEAD on failure and
does not claim it was preserved when it changed or cannot be verified.
Resolve the divergence deliberately before retrying. It never fetches or
pushes. If publication is separately authorized, a human may push explicitly:

```bash
git push origin starter
```

Replace `origin` only with the reviewed, authorized destination. The producer
task requires an existing `starter` and committed source that advances the
previous release source. A different source branch may be passed explicitly
if it descends from that source. For an initial release, the original direct
`distribution` task still creates a missing target from a clean source checkout.
The original direct `distribution` task still accepts a target checkout that
contains `.maintainer/` and retains merge conflicts for manual resolution.
The filtered published `starter` checkout does not contain that Taskfile; do
not invoke the direct task from it.

Each release constructs its tree from the committed source with root README,
identity (including `AGENTS.md.TEMPLATE`), maintainer tooling, and planning
paths excluded. The template remains tracked and unchanged in the dev source;
it is omitted only from the published `starter` tree. Legacy distribution retains
the source commit in the release ancestry. A source-only update still records the
new source parent and marker even when the sanitized tree is unchanged; a
rerun with that source is a no-op. Consumer-owned README, workflows, and
planning files are never rewritten by the distribution step. Git merges shared
paths normally; on conflict the producer task aborts the temporary merge and
checks the target HEAD. The direct task instead retains merge state for
manual resolution or `git merge --abort`. Never reset a consumer repository to
resolve an update.

The release includes only `.agents/skills/add-tool/` from the source skill tree.
It excludes the source `skills-lock.json` and generates
`.devcontainer/skills/recommended.json` from the committed source lock, with
each external skill's name, source, and skill path. No Skills CLI installation
occurs during distribution. A consumer-added skill directory and lock remain
outside the release tree and survive later merges. When migrating a previously
distributed skill tree, unchanged old external skills are removed; edits to
those tracked paths or the old lock cause a Git conflict rather than being
silently discarded. Resolve conflicts deliberately if retaining those paths,
or abort the merge to restore the consumer branch.

Git stores regular-file mode as executable or non-executable, not arbitrary
POSIX permission bits. LICENSE and the dev-source AGENTS.md.TEMPLATE retain
their Git blobs and executable flags; local checkout umask determines exact
read permissions. The template is not included in the starter tree.

## Explicit base lifecycle proof

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
features (including nested Docker and GitHub CLI) are omitted. Pi coding/Gentle and
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
