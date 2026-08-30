# Safe starter updates

Derived projects can adopt and apply Gentle Starter releases without joining
Git histories or surrendering ownership of project files. The workflow admits
an exact annotated release, validates its integrity bindings, plans declarative
file operations, and leaves every
commit to the project owner.

The initial source is Git only. A release is an exact annotated semantic tag
named `starter/vX.Y.Z`; branches, mutable refs, GitHub Releases, and the GitHub
API are not release inputs.

Release maintainers should use the separate
[Gentle Starter release guide](./starter-releases.md). This guide covers only
derived-project adoption, checks, and updates.

## Quick path

The normal clone path admits its originating release during initialization:

```bash
task project:init

# Discover the latest release and inspect every blocker without changing state.
task starter:check

# Discover, admit, review, and confirm the latest exact release.
task starter:update

# Select an exact target but keep interactive confirmation.
task starter:update -- --release starter/v1.1.0

# Use deterministic noninteractive automation only with an exact target.
task starter:update -- --release starter/v1.1.0 --yes

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
| `starter:adopt` | Recover or deliberately adopt an unmarked project that exactly matches a selected baseline. | Writes retained evidence and `.starter/state.json` only after integrity, ownership, path, and managed-fingerprint checks pass. |
| `starter:check` | Discover the latest exact release, revalidate current evidence, and report drift, integrity, worktree, ownership, path, and migration-chain blockers. | Does not change project files or Git/container state. Reports all blockers it can evaluate. |
| `starter:update` | Discover or select, admit, review, and apply a complete migration chain. | Prompts before mutation unless an exact `--release` is paired with `--yes`; journals before mutation, updates only allowed paths, and writes state last. |

`starter:adopt` requires an exact `--release`.
`starter:check` normally reads the adopted release from `.starter/state.json`,
discovers exact annotated `starter/vX.Y.Z` tags through Git ref discovery, and
inspects the highest stable SemVer release. Pass `--release starter/vX.Y.Z` to
bypass discovery and inspect one selector deterministically.

`starter:update` uses the same bounded discovery for its normal interactive
path. It validates current evidence, drift, the clean worktree, candidate
admission, and the complete migration plan before asking
`Apply starter/vX.Y.Z? (y/N)`. Only `y` or `Y` confirms; Enter, EOF, and every
other response abort without project mutation. Discovery and acquisition happen
once before the prompt. The exact selector, candidate directory, evidence, tag,
commit, tree, manifest, payload, envelope, and plan identities are frozen and
revalidated for application, so remote changes during the prompt cannot change
the selected target or bytes. `--yes` is accepted only with an exact
`--release`; this preserves deterministic unattended automation.

Commands acquire releases from `https://github.com/Cesarucho/gentle-starter.git`
by default. Optional `--source URL` overrides that default explicitly; for example,
`--source https://github.com/Cesarucho/gentle-starter.git`. Optional
`--project-root` supports explicit project selection. Invalid usage exits before
acquisition or project writes.

Discovery is bounded and accepts only advertised exact tags that also have the
corresponding peeled ref, excluding lightweight tags, prerelease-like names,
branches, and unrelated refs. The selected highest release is then admitted by
the normal `GitTagSource/v1` path. If that release fails admission, check reports
the blocker and does not fall back. A current release equal to latest is up to
date; a current release ahead of latest is not downgraded.

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

The canonical lifecycle-v2 inventory is
`.starter/distribution/ownership.json`. The shared prepared-release validator
enforces its exact schema and supported ownership declarations. The release manifest,
admitted payload, and retained Git evidence bind the inventory path and digest
(and Git evidence also records its blob identity). Offline revalidation
therefore uses the exact policy admitted with the release, never mutable live
workspace policy.

Every declarative `copy`, `delete`, or `fusion` operation has an ownership
class and an expected pre-change fingerprint. **Every unlisted path is
`project-owned`.** V2 inventories admit exact entries only; future descendants
remain project-owned until a release enumerates them. Duplicates, overlaps, and
ancestor ambiguity are invalid.

| Class | Meaning | Update behavior |
|---|---|---|
| `managed` | The starter owns the registered path and its expected contents. | May change only when the current fingerprint exactly matches the migration precondition. Drift blocks the operation. |
| `fusion` | The path has an explicitly declared starter-managed composition contract. | May change only through the declared fusion operation and exact fingerprint checks. It is not automatic conflict resolution. |
| `project-owned` | The derived project owns the path. | Planning rejects any attempted starter write or deletion. The user resolves changes manually. |

### Producer change semantics

The following classes are the normative interpretation of producer changes.
Only M and F are ownership entries; P is the exact-inventory default, while G
and `removed` describe exclusion and producer-to-derived transformation.

| Producer classification | Create or modify | Delete | Move or rename | Mode-only change |
|---|---|---|---|---|
| M (`managed`) | Requires an exact inventory entry, payload bytes, and a `copy` operation with exact before/after state. | Requires an exact inventory entry and `delete` operation with an exact precondition. | Classify both paths; authorize deletion of the old target and creation of the new target independently. | Requires a `copy` operation whose fingerprints record the old and new modes. |
| P (`project-owned`) | Remains outside starter payload and operations; the project decides whether to adopt the producer change. | Starter deletion is forbidden. | Neither side gains authority from Git rename detection; starter operations remain forbidden. | Starter mode changes are forbidden. |
| F (`F-manual/v1`) | Requires an exact F declaration, payload, BASE/OURS/THEIRS fingerprints, and a complete `fusion` operation. | Unsupported unless a future declared composition contract defines deletion semantics. | No implicit rename authority; each side needs independently valid lifecycle semantics. | Must be represented completely by the supported F contract and exact fingerprints; otherwise it is unsupported. |
| G (`generated`) | Must not appear in ownership, payloads, migrations, or the derived release tree. Runtime lifecycle code may create it only in its defined transaction role. | Not distributed; recovery owns only transaction-proven generated state. | Never converts into a distributable path. | Not a release operation. |
| `removed` (producer-only) | Not applicable in the derived tree. | The deterministic derived-tree transformation removes the producer-only surface; it does not authorize deletion from an existing consumer. | Classify the destination separately; Git rename detection grants no authority. | Not distributed. |

Inventory membership is exact and release-bound. There are no managed or fusion
prefixes, and migration descriptors cannot authorize their own targets. Any
path absent from the exact M/F entries is P, including future descendants of a
listed directory. Content, presence, and mode are all fingerprinted lifecycle
state; a change in any one of them must be represented explicitly.

P is immutable to starter transactions. G is excluded from consumer release
artifacts. F is all-or-nothing: its declaration, supported contract, payload,
operation, and fingerprints must agree before planning. M and F writes begin
only after a durable journal exists, use compare-and-swap checks during apply
and rollback, retain ambiguous journals for inspection, and write the new state
marker last. Producer-only removal changes the prepared consumer snapshot but
does not bypass those transaction rules for already-derived projects.

Unknown ownership classes, duplicate or colliding targets, incomplete or
ambiguous migration chains, duplicate edges, cycles, downgrades, target
mismatches, absolute paths, traversal, and symlink escapes all fail before
writes. A prepared v2 release carries the ordered predecessor graph needed to
prove reachability from the installed version. Its final edge carries the
complete target-snapshot operation set; earlier selected edges establish the
admissible lineage and are retained in the plan's ordered migration IDs. The
updater never treats a convenient destination as permission to overwrite it.

The v2 inventory enumerates the baseline and ownership markers, updater
implementation, approved devcontainer runtime files, derived documentation,
every approved installer in that release, and isolated updater tests. It uses
no managed prefixes. `Taskfile.yml`, enabled-install links, hooks, local tool
configuration, other task infrastructure, agent configuration, project
identity, application files, and every unlisted path remain project-owned.

The two initial shared-configuration candidates are
`.devcontainer/devcontainer.json` and `.devcontainer/docker-compose.yml` under
`F-manual/v1`. They use exact BASE/OURS/THEIRS equality rules and never perform
an automatic textual or structured merge. Concurrent changes on both sides
produce an immutable proposal and require explicit acceptance. Resolution is
all-or-nothing across pending F paths through `--take-starter`,
`--keep-project`, `--continue`, or `--abort`; these choices never authorize a
write to project-owned or generated paths, and managed drift remains blocking.

Derived projects use the canonical `gentle-starter` remote from
`.starter/source.json`. `origin` remains independent. A URL mismatch fails
closed and is never overwritten. Inspection, parsing, planning, and confirmation
only validate metadata and read an existing matching remote; an absent remote is
not created. `project:init` is the authorized creation boundary: it adds the
canonical remote to the staged Git configuration that is committed by its
rollback-capable initialization transaction. Release acquisition uses isolated
refs rather than project tags, pulls, merges, or rebases. Once an update
candidate is frozen, the updater does not fetch or rediscover it.

Consumer lifecycle contracts are v2-only. Release payloads, manifests,
migrations, plans, journals, and state markers using v1 or unknown schemas are
rejected rather than migrated. Development consumers created before lifecycle
v2 must be recreated with the current `task project:init`. The v2 state marker
is persisted last, after content and retained evidence; crash recovery uses the
same compare-and-swap rules as every other transaction-owned path.

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

`task project:init` detects the originating release before rewriting history. It
prefers the single exact annotated `starter/vX.Y.Z` tag whose peeled commit is
`HEAD`; `--release starter/vX.Y.Z` resolves unavailable or ambiguous identity.
The exact release is acquired and admitted through `GitTagSource/v1`, then the
post-cleanup managed and fusion baseline is proven before any history mutation.
The parentless root includes `.starter/state.json`, the managed baseline,
canonical ownership inventory, updater machinery, and retained evidence.

Automatic discovery is intentionally local and bounded. Missing tags, shallow
clones without the required tag, malformed candidates, and multiple matching
releases fail closed with explicit `--release` guidance. Explicit selection may
acquire only that exact tag from the existing origin; it never changes the
origin URL. `--no-starter-adopt` exists only for deliberately unmarked projects.
Standalone `starter:adopt` remains an advanced recovery path for those projects.

The initialization workflow does not merge or import starter history and never
pushes. A blank origin response preserves the current
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
