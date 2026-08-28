# Safe starter updates

Derived projects can adopt and apply Gentle Starter releases without joining
Git histories or surrendering ownership of project files. The workflow admits
an exact signed release, plans declarative file operations, and leaves every
commit to the project owner.

The initial source is Git only. A release is an exact annotated semantic tag
named `starter/vX.Y.Z`; branches, mutable refs, GitHub Releases, and the GitHub
API are not release inputs.

## Quick path

Run these commands from the root of the derived project's clean Git worktree.
Replace the source and release with values published by the starter
maintainers.

```bash
# First prove that the current files match an admitted baseline.
task starter:adopt -- \
  --source https://github.com/gentleman-programming/gentle-starter.git \
  --release starter/v1.0.0

# Commit the retained evidence and state marker after reviewing them.
git status --short

# Inspect a later release and every blocker without changing project state.
task starter:check -- \
  --source https://github.com/gentleman-programming/gentle-starter.git \
  --release starter/v1.1.0

# Apply only after check passes and the proposed release is understood.
task starter:update -- \
  --source https://github.com/gentleman-programming/gentle-starter.git \
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
| `starter:adopt` | Prove that an unmarked project exactly matches a selected admitted baseline. | Writes retained evidence and `.starter/state.json` only after trust, ownership, path, and managed-fingerprint checks pass. |
| `starter:check` | Revalidate current evidence and report drift, trust, worktree, ownership, path, and migration-chain blockers. | Does not change project files or Git/container state. Reports all blockers it can evaluate. |
| `starter:update` | Apply a complete admitted migration chain to an adopted project. | Requires `--yes`, journals before mutation, updates only allowed paths, and writes state last. |

All three commands require `--source` and an exact `--release`. Optional
`--project-root`, `--policy`, and `--key` arguments support explicit repository
and trust-material selection. Invalid usage exits before acquisition or project
writes.

The commands never merge histories, checkout or rebase upstream commits,
execute fetched files, mutate `origin`, start containers, resolve conflicts,
silently overwrite drift, or create commits. Executable bits, filenames such
as `requirements.txt`, and script-like Markdown do not make payload content
executable; fetched content remains data.

## Release admission and governance

### Client admission proof

The Git source adapter admits a release only when all required bindings agree:

- the selector is exactly `starter/vX.Y.Z` and names an annotated tag;
- the tag signature resolves to a signer allowed by the pinned public-key
  policy for that release version;
- revocation and rotation rules allow that signer;
- the tag object, peeled commit, tree, manifest object, and declared digests
  agree; and
- the manifest and retained object closure can be revalidated.

Unsigned, malformed, revoked, unpinned, mutable, or mismatched candidates fail
closed before project state is created or advanced.

### Governance is not admission proof

Maintainers should protect the `starter/v*` tag namespace in GitHub, restrict
tag creation and deletion, require reviewed publication, and audit each
release. Those controls reduce publisher mistakes and account compromise.

They are governance, NOT client admission proof. A client cannot prove from
fetched Git objects that a GitHub ruleset was active when a tag was published.
The client therefore verifies the signature, pinned signer policy, immutable
Git identities, and content bindings independently. A protected but invalid tag
is still rejected, and client output must not claim that tag protection was
verified.

### Pinned signer, rotation, and revocation

`.starter/trust/policy.json` and `.starter/trust/release-key.asc` are the local
trust root. The policy identifies allowed signer fingerprints and their release
windows; rotations and revocations are explicit policy data, not network
discovery or unattended key replacement.

For a planned rotation, publish and review policy that introduces the new
public signer through an already trusted release before using the new signer.
Bound old and new signer validity to deliberate release windows. For a
revocation, update the pinned policy through the normal reviewed project trust
path and stop admitting the revoked signer. Never accept a key merely because
it is attached to a GitHub account or returned by a keyserver.

## Verified payload boundary

After Git-specific verification, the adapter emits a versioned,
transport-neutral verified payload. Lifecycle code consumes that payload rather
than Git tags, commits, trees, packs, or keyrings directly. It carries neutral
source and release identities, the verified manifest and payload references,
the signer-policy result, and opaque retained-evidence references.

This boundary keeps admission separate from state, manifest parsing, planning,
migration, journaling, and rollback. A future source adapter may acquire bytes
differently, but it must produce the same verified contract and cannot weaken
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

## Production signer bootstrap

The first production release establishes a long-lived trust boundary. Complete
this checklist before publishing its tag:

1. Create and hold the signing private key in controlled signing infrastructure,
   preferably an offline system, hardware token, or HSM with documented backup
   and recovery. Never commit or distribute the private key with the starter.
2. Independently verify that the committed public key and fingerprint policy
   are the intended production trust root. Replace pre-production material
   before publication when necessary.
3. Define signer access, release approval, audit retention, emergency
   revocation, and planned rotation responsibilities. Test recovery without
   exposing private key material.
4. Build the manifest and immutable Git object bindings, then create the exact
   signed annotated `starter/vX.Y.Z` tag with the controlled signer.
5. Verify the tag through the same client admission path before publication.
   Record the tag, peeled commit, manifest digest, signer fingerprint, and
   approval evidence.
6. Configure GitHub tag protection as an additional publisher control and
   audit the final publication. Do not substitute that control for client
   cryptographic admission.

Signer rotation is a release process, not an automatic client feature. If the
current key is suspected to be compromised, stop publication and distribute a
reviewed revocation/trust update through a channel that does not depend on a
new signature from the compromised key.

## After `task project:init`

`task project:init` creates the derived project's explicitly confirmed,
parentless root commit, but it does not admit a starter release. It removes
inherited `.starter/state.json`, baseline, evidence, and journals while keeping
the updater commands, trust policy, and declarative distribution assets. The
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
should document their selected starter source, release cadence, signer policy,
and ownership exceptions in their own durable docs without weakening these
boundaries.
