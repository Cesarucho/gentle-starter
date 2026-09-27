# Prepare the consumer branch locally

Use a clean checkout of the committed source. The preparation script does not
fetch, push, check out another branch, or read uncommitted source changes.

```bash
task --taskfile .maintainer/Taskfile.yml distribution -- --source dev --target starter
```

For a first release, `starter` must not exist; the script creates the branch
without switching away from the source. For a later release, check out the
existing `starter` branch first, then run the same command. The source must
advance the source recorded in the previous release. To prepare from a refactor
branch instead, pass its exact local branch name as `--source`; subsequent
updates must descend from that commit.

Each release constructs its tree from the committed source with root README,
identity (including `AGENTS.md.TEMPLATE`), maintainer tooling, and planning
paths excluded. The template remains tracked and unchanged in the dev source;
it is omitted only from the published `starter` tree. It retains the
source commit in the release ancestry. A source-only update still records the
new source parent and marker even when the sanitized tree is unchanged; a
rerun with that source is a no-op. Consumer-owned README, workflows, and
planning files are never rewritten by the distribution step. Git merges shared
paths normally; if one conflicts, the script stops and preserves the merge
state. Inspect `git status`, resolve and commit the conflict manually, or use
`git merge --abort`. Never reset a consumer repository to resolve an update.

Verify the local branch tree before any separately authorized publication:

```bash
git ls-tree -r --name-only starter
git merge-base --is-ancestor dev starter
bats .maintainer/test/unit/starter-distribution.bats
```

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
task --taskfile .maintainer/Taskfile.yml test:starter:lifecycle -- --daemon-visible-scratch /absolute/scratch-parent
```

The existing parent must be outside the source repository and visible at the same
absolute path to the **local** Docker daemon at `/var/run/docker.sock`. The flag
is the operator's explicit confirmation of that mapping, not an automatic probe.
Inside a devcontainer, use a sibling under the mounted workspace, not an arbitrary
container-private `/tmp` directory. Remote Docker contexts are not reused. Missing
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

Automatic cleanup runs after success, failure, and handled SIGINT/SIGTERM, using
the same ownership engine as explicit recovery below. Cleanup failure makes the
test fail without replacing its separate stage/status diagnostic. SIGKILL cannot
run a finalizer; the durable inventory supports later recovery instead.

## Recovering test-owned resources

Start with a read-only preview from the **original source worktree**:

```bash
task --taskfile .maintainer/Taskfile.yml test:starter:clean
task --taskfile .maintainer/Taskfile.yml test:starter:clean -- --run RUN_UUID
# After reviewing that run's scope, explicitly authorize deletion:
task --taskfile .maintainer/Taskfile.yml test:starter:clean -- --apply --run RUN_UUID
# Also discard its compact diagnostics, only after resources are verified gone:
task --taskfile .maintainer/Taskfile.yml test:starter:clean -- --apply --run RUN_UUID --forget
```

`RUN_UUID` is printed by the participating test or recovery preview. The
explicit lifecycle and image-contract builds, and recovery, are not invoked by
`task test`, the maintainer `test:starter` suite, or `task validate`.
Normal unit execution does include
mock tests of the cleaner, not an invocation of live recovery.

**Scope:** the base lifecycle harness and the Docker image-contract fixture in
`.maintainer/test/operational/image-contract.bats` register their resources.
The latter has a unique run tag and
`finally` cleanup even when build/assertion fails. Other suites retain their own
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
or images, and failed/unverifiable cleanup. Recovery records remain until resources
are proven gone; successful runs retain compact diagnostics indefinitely until
explicit `--forget`. Diagnostics contain bounded structured stage, exit, test, and
cleanup outcomes—not raw command lines, environment, Compose output, inspect dumps,
or excerpts from arbitrary logs. Raw build logs stay only in disposable private
scratch. If filesystem cleanup fails, those logs may remain there along with the
ownership marker; the report names the exact scratch scope for manual inspection.
Do not remove ownership metadata or escalate to global cleanup when uncertain.
Interrupted registration can leave a directory whose marker was not completed;
recovery refuses to guess ownership. This is a scoped operational aid, not a commit
gate or a universal no-residue guarantee.
