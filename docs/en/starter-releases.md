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

The canonical release manifest is
`.starter/distribution/manifest.json`. Set its release version and selector to
the intended `X.Y.Z` and `starter/vX.Y.Z`, then ensure its payload and migration
entries bind the committed files under `.starter/distribution/`.

Commit the complete distribution before creating the release. The command
rejects uncommitted or untracked changes and any distribution asset that does
not match the manifest's path, size, or digest.

## Create and validate the local release

```bash
task starter:release -- X.Y.Z
```

The command:

1. validates the repository, clean-worktree, version, manifest, payload, and
   migration preconditions;
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
