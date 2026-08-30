# Publish a Gentle Starter release

This maintainer workflow creates and validates one exact local release, then
publishes the branch and tag as separate, explicit Git operations. Nothing in
the release command pushes automatically.

## Prerequisites

- Run from the root of the Gentle Starter source repository, not a derived
  project.
- Configure the intended publication remote. The command checks `origin` by
  default; set `STARTER_RELEASE_REMOTE` only when the publication remote has a
  different name.
- Ensure the worktree and index are clean and `HEAD` contains the complete
  release distribution.
- Choose a stable semantic version in `X.Y.Z` form that does not already exist
  locally or on the publication remote.

## Prepare the committed distribution

### Classify producer changes

Before running preparation, evaluate every path changed since the selected
predecessor. Include creations, content modifications, deletions, moves or
renames, and executable or other mode changes. Use the
[normative producer change semantics](./starter-updates.md#producer-change-semantics)
for class behavior; this section defines the maintainer procedure.

For each changed path:

1. Classify it as `managed` (M), `project-owned` (P), `F-manual/v1` (F),
   `generated` (G), or producer-only `removed`.
2. Treat P as the default. Add every M or F path as an exact entry in
   `.starter/distribution/ownership.json`; never infer ownership from a parent
   directory, a Git diff, or an operation in a migration.
3. For `removed`, update the deterministic producer-to-derived transformation.
   This class removes producer-only surfaces while building the consumer tree;
   it is not a consumer `delete` operation.
4. Keep G paths out of the ownership inventory, release payload, migration
   targets, and derived tree. Generated runtime state is never distributable.
5. Use F only when the path and supported composition contract are declared
   completely. `F-manual/v1` requires exact BASE/OURS/THEIRS fingerprints,
   payload content, and an explicit fusion operation; it never implies a merge.
6. Encode every affected M or F target in the migration with its operation,
   ownership, expected pre-change presence/digest/mode, and resulting
   presence/digest/mode. Creation, deletion, and mode-only changes are explicit
   state transitions.
7. Update derived-tree and lifecycle tests, plus maintainer or consumer docs,
   whenever the distributed surface or behavior changes.

A Git rename is only diff presentation. It grants no lifecycle rename authority.
Model a move as the independently classified old and new paths, with an
authorized deletion and creation only where their classes permit them. A P path
cannot be deleted or replaced by describing it as a rename.

Before preparation, confirm:

- [ ] every changed path and both sides of every move are classified;
- [ ] the exact inventory and producer-only removal transformation are current;
- [ ] G paths are absent from all distributable artifacts;
- [ ] all M/F operations and fingerprints cover content, presence, and mode;
- [ ] F declarations, payloads, and operations are complete and consistent;
- [ ] affected tests and documentation describe the resulting consumer tree.

Build and inspect the deterministic consumer tree first:

```bash
task starter:prepare-release -- X.Y.Z
```

Preparation writes reviewable artifacts only. It removes bootstrap, clean, and
publisher surfaces; rejects generated operational paths; and records the
`derived-tree-transformation/v1` output identity. It never commits, tags, or
pushes. Preparation validates every local prepared release, ignores its own
dot-prefixed staging directories, and selects the highest valid release below
`X.Y.Z`. If none exists, it selects `0.0.0` only as the bootstrap edge for the
first prepared v2 release. The selected predecessor is printed before building.
Malformed, ambiguous, colliding, descending, or broken local chains fail closed;
inference never reads a remote or uses the network.

For an intentional hotfix or branch edge, override inference explicitly:

```bash
task starter:prepare-release -- X.Y.Z --predecessor A.B.C
```

Preparation carries the selected predecessor's migration graph and adds the new
edge, so consumers can prove one ordered v2 chain from their installed version
to the target.

Before carrying that graph, preparation re-admits the complete prepared
predecessor: strict manifest and identity bindings, ownership digest, exact
payload and migration closures, file hashes, sizes, modes, presence, migration
IDs, and unambiguous ascending topology must all validate. Missing, extra, or
tampered predecessor artifacts fail closed; preparation never replaces a stale
binding by hashing the untrusted bytes into the successor.

Preparation builds and validates the complete artifact set in an
operation-owned sibling staging directory beneath
`.starter/distribution/prepared/`, then atomically renames it to `X.Y.Z`.
Failures remove only that staging directory and leave no partial release, so a
retry is safe. A pre-existing final path is ambiguous and is never replaced or
cleaned automatically.

The prepared manifest and all bound assets are written below
`.starter/distribution/prepared/X.Y.Z/`. The manifest binds the exact ownership
inventory, payload closure, migration graph, official source identity, and
derived consumer-tree identity. Unlisted paths remain `project-owned`; the two
declared `fusion` paths use the supported `F-manual/v1` contract.

Review the generated tree, exact ownership inventory, payload closure, final
migration edge, carried migration graph, and manifest together. Confirm that
every classified path has the intended consumer result and that no P, G, or
producer-only removed path became an update target. Preparation validation is a
fail-closed guard, not a substitute for this path-by-path review.

Commit the complete distribution before creating the release. The command
rejects uncommitted or untracked changes and any distribution asset that does
not match the manifest's path, size, or digest.

## Create and validate the local release

```bash
task starter:release -- X.Y.Z
```

The command:

1. invokes the same authoritative prepared-release validator used during
   preparation, proving exact artifacts, identities, ownership and payload
   closure, migration hashes and descriptor semantics, safe owned operation
   paths, and one ascending predecessor-to-target topology;
2. rejects an existing exact local or publication-remote tag;
3. creates the annotated tag `starter/vX.Y.Z` at `HEAD` with canonical commit,
   tree, and manifest bindings; and
4. admits that local tag through `GitTagSource/v1`, the same adapter used by
   consumers.

On success, the local summary reports the selector/tag, commit, tree, manifest
digest, structural/integrity validation status, and pending remote publication.
Review those values before publishing.

## Publish explicitly

Push the reviewed release commit through the normal branch workflow first.
Then push only the exact release tag:

```bash
git push origin <release-branch>
git push origin refs/tags/starter/vX.Y.Z
```

Never use `git push --tags`; it can publish unrelated local tags. The release
command never pushes a branch or tag, changes a remote, creates a commit, or
modifies tracked files.

## Failures, verification, and rollback

Duplicate exact tags fail before creation. If validation fails after the command
creates a tag, it removes only that operation-created tag when the tag object is
still unchanged. Other refs are left intact.

Before publication, inspect the local tag and rerun the release command only
after correcting the reported problem:

```bash
git show --no-patch starter/vX.Y.Z
git ls-remote --tags origin \
  refs/tags/starter/vX.Y.Z 'refs/tags/starter/vX.Y.Z^{}'
```

If an incorrect tag remains local and has not been published, verify its object
and delete that exact tag with `git tag -d starter/vX.Y.Z`, then correct the
distribution and create it again. If it was published, stop and follow the
repository's maintainer recovery process rather than replacing the tag.

This workflow provides structural and integrity validation. It makes no claim
about publisher authentication.
