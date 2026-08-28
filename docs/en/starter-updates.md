# Safe starter updates

Derived projects can adopt and apply Gentle Starter releases without joining
Git histories or surrendering ownership of project files. The workflow admits
an exact annotated release, validates its integrity bindings, plans declarative
file operations, and leaves every
commit to the project owner.

The initial source is Git only. A release is an exact annotated semantic tag
named `starter/vX.Y.Z`; branches, mutable refs, GitHub Releases, and the GitHub
API are not release inputs.

## Create a release

Run the release command from the clean root of the Gentle Starter repository,
not from a derived project:

```bash
task starter:release -- 1.0.0
```

The committed `.starter/distribution/manifest.json` must declare the same
version and bind every payload and migration asset. After preflight checks, the
command creates the unsigned annotated `starter/v1.0.0` tag with the canonical
Git metadata bindings and immediately admits it through `GitTagSource/v1`.
Failure removes only the operation-created tag when its object identity still
matches.

Release creation and remote publication are deliberately separate. The command
does not push, change a remote, create a commit, or modify tracked files. Review
the summary and publish the exact tag explicitly through the repository's
maintainer workflow.

## Quick path

Run these commands from the root of the derived project's clean Git worktree.
Replace the release with an exact version published by the starter maintainers.

```bash
# First prove that the current files match an admitted baseline.
task starter:adopt -- \
  --release starter/v1.0.0

# Commit the retained evidence and state marker after reviewing them.
git status --short

# Inspect a later release and every blocker without changing project state.
task starter:check -- \
  --release starter/v1.1.0

# Apply only after check passes and the proposed release is understood.
task starter:update -- \
  --release starter/v1.1.0 \
  --yes

# Review and commit the resulting project changes yourself.
git status --short
git diff
```

`starter:adopt` and `starter:update` reject staged, unstaged, or untracked
changes. `starter:check` reports a dirty worktree as a blocker but remains
read-only with respect to project files, Git refs, remotes, commits, and
container state.

## Command contract

| Command | Purpose | Mutation contract |
|---|---|---|
| `starter:release` | Create and locally admit an exact Gentle Starter release. | Creates one local annotated tag after preflight; never pushes or changes files, commits, branches, or remotes. |
| `starter:adopt` | Prove that an unmarked project exactly matches a selected admitted baseline. | Writes retained evidence and `.starter/state.json` only after integrity, ownership, path, and managed-fingerprint checks pass. |
| `starter:check` | Revalidate current evidence and report drift, integrity, worktree, ownership, path, and migration-chain blockers. | Does not change project files or Git/container state. Reports all blockers it can evaluate. |
| `starter:update` | Apply a complete admitted migration chain to an adopted project. | Requires `--yes`, journals before mutation, updates only allowed paths, and writes state last. |

All three commands require an exact `--release`. They acquire releases from
`https://github.com/Cesarucho/gentle-starter.git` by default. Optional
`--source URL` overrides that default explicitly; for example,
`--source https://github.com/Cesarucho/gentle-starter.git`. Optional
`--project-root` supports explicit project selection. Invalid usage exits before
acquisition or project writes.

The commands never merge histories, checkout or rebase upstream commits,
execute fetched files, mutate `origin`, start containers, resolve conflicts,
silently overwrite drift, or create commits. Executable bits, filenames such
as `requirements.txt`, and script-like Markdown do not make payload content
executable; fetched content remains data.

## Release admission

### Client admission proof

The Git source adapter admits a release only when all required bindings agree:

- the selector is exactly `starter/vX.Y.Z` and names an annotated tag;
- the tag object, peeled commit, tree, manifest object, and declared digests
  agree; and
- the manifest and retained object closure can be revalidated.

Malformed, lightweight, mutable, oversized, incomplete, or mismatched
candidates fail closed before project state is created or advanced. This is an
integrity and structural admission contract; it does not authenticate a
publisher.

## Release payload boundary

After Git-specific validation, the adapter emits a versioned,
transport-neutral release payload. Lifecycle code consumes that payload rather
than Git tags, commits, trees, or packs directly. It carries neutral source and
release identities, manifest and payload references, and opaque retained
evidence references.

This boundary keeps admission separate from state, manifest parsing, planning,
migration, journaling, and rollback. A future source adapter may acquire bytes
differently, but it must produce the same release contract and cannot weaken
ownership, clean-worktree, evidence, recovery, or state-last rules. The current
implementation remains Git only; no future adapter is implied to be available.

## Ownership classes

Every declarative `copy`, `delete`, or `fusion` operation has an ownership
class and an expected pre-change fingerprint.

| Class | Meaning | Update behavior |
|---|---|---|
| `managed` | The starter owns the registered path and its expected contents. | May change only when the current fingerprint exactly matches the migration precondition. Drift blocks the operation. |
| `fusion` | The path has an explicitly declared starter-managed composition contract. | May change only through the declared fusion operation and exact fingerprint checks. It is not automatic conflict resolution. |
| `project-owned` | The derived project owns the path. | Planning rejects any attempted starter write or deletion. The user resolves changes manually. |

Unknown ownership classes, duplicate or colliding targets, incomplete migration
chains, absolute paths, traversal, and symlink escapes all fail before writes.
The updater never treats a convenient destination as permission to overwrite
it.

## Recovery and rollback

Successful adoption retains bounded evidence under `.starter/evidence/` and
writes an integrity-bound `.starter/state.json` last. State records neutral
release identities, manifest and migration bindings, managed fingerprints, and
an opaque evidence reference. Revalidation uses the retained admitted tag,
commit, tree, and manifest-bound object closure, so an unavailable remote does
not silently erase provenance.

Before an update changes any managed or fusion path, it creates a durable
journal under `.starter/journals/` with operation-owned pre-state and staged
post-state. Each write and rollback is compare-and-swap guarded:

- if the current file still matches the expected transaction state, recovery
  can restore the proven pre-state;
- if a concurrent or unexplained change makes restoration ambiguous, recovery
  stops and retains the journal for manual inspection; and
- the new state marker is not considered authoritative until the entire
  admitted chain succeeds.

On failure, do not delete a retained journal to make the next command proceed.
Inspect the reported path, preserve project-owned content, and determine why
the current fingerprint differs. Retry only after recovery is complete and the
worktree is clean. The updater does not use Git reset, history rewriting, or an
automatic commit as rollback.

## After `task project:init`

`task project:init` creates the derived project's explicitly confirmed,
parentless root commit, but it does not admit a starter release. It removes
inherited `.starter/state.json`, baseline, evidence, and journals while keeping
the updater commands and declarative distribution assets. The
new project is intentionally unmarked and must run `task starter:adopt` against
an exact release that matches its managed baseline.

The initialization workflow does not merge or import starter history and does
not contact or push to a remote. A blank origin response preserves the current
origin; any separately confirmed origin replacement belongs to
`project:init`, not to the starter update commands. After initialization,
`starter:adopt`, `starter:check`, and `starter:update` still never mutate
`origin` or create commits.

Identity cleanup removes the starter's top-level `docs/` and regenerates
`AGENTS.md` from the project template. `.devcontainer/README.md` remains in the
derived project and carries the short safety contract. Project maintainers
should document their selected starter source, release cadence, and ownership
exceptions in their own durable docs without weakening these
boundaries.
