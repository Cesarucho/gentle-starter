# ADR 0003: Unified tool policy ownership

**Status:** Accepted, 2026-09-09
**Supersedes:** Version ownership and update decisions in [ADR 0002](0002-centralized-tool-version-policy.md)

**Path update:** The historical `01-core` bootstrap directory is now
`01-foundation`; managed tool aliases run separately in `02-core-tools` or
`03-enabled`. This does not change policy/updater ownership. See the
[current install guide](../install-tree.md).

## Decision

`.devcontainer/tool-versions.conf` is the single public policy file. Its top
section contains only user-editable `TOOL_*_VERSION` intent. One clearly marked
generated section at the end contains every exact resolution and digest under
the `LOCK_*` namespace. Users never type generated values or checksums.

`task deps:update` is the sole mutation authority. It validates every intent,
uses an explicit provider strategy, accepts stable releases only, resolves exact
versions, requires every mandatory architecture, validates assets, builds a
complete candidate, and performs one atomic replacement. Failure preserves the
original bytes and mode.

Builds, installers, setup, postCreate, doctor, and validators are read-only
consumers. `latest` is resolved only by `deps:update`. Installers consume the
generated resolutions and never carry local version or checksum defaults.

Go Task is the narrow existing external APT-managed core bootstrap exception.
It is installed in `01-core` because the Task runner is required before
the repository can expose its managed workflows. It deliberately remains
outside `TOOL_*`/`LOCK_*` policy so changing managed tool inputs stays
downstream of the reusable `foundation` layer. The signed Cloudsmith APT
repository selects the Task package version and authenticates package metadata
and integrity. The initial Cloudsmith `setup.deb.sh` repository bootstrap is
trusted through HTTPS and provider delivery; APT signatures do not authenticate
that bootstrap script itself.

This exception does not authorize new unmanaged tools. Other core Ubuntu
packages are collectively provider-managed by the signed Ubuntu APT
repositories rather than registered as individual managed tools. A Task
bootstrap failure remains fail-fast; transient Cloudsmith or network failures
require a manual build retry. The repository has no shared retry policy, so this
decision adds no Task-specific retry loop or options. Gentle AI retains its
separately documented bounded-retry exception.

## Provider strategies

| Provider shape | Intent interpretation |
| --- | --- |
| Conventional SemVer | `latest`, major lane, minor lane, major-compatible baseline, or `=` exact |
| PlantUML CalVer | `latest`, year lane, year-lane baseline, or `=` exact |
| SDKMAN | Explicit Java candidate/distribution syntax |
| Node and PHP | Provider channel or package series |
| kubectl | Minor compatibility lane and matching stable channel |
| npm | Supported stable semantic intents resolved from complete version metadata |
| Composer | Supported stable semantic intents resolved from package metadata |
| GitHub release | Exact-tag lookup or exhaustively paginated stable-lane lookup, canonical asset identity, and generated digest |
| Playwright | Library, CLI, and browser-facing components resolved as one unit |

Segment count never selects a strategy. Unsupported provider syntax fails
closed.

## Integrity boundary

Direct downloads use generated repository-pinned SHA-256 values for every
supported architecture. npm, pip, apt, Composer, and SDKMAN retain
provider-delegated integrity when no stable standalone artifact identity exists;
the policy does not fabricate checksums for those transactions.

## Transaction and workflow

Discovery and validation complete before replacement. Reviewers get one
version/integrity diff and one commit moment:

GitHub exact pins use the provider's exact release endpoint. Compatibility
lanes paginate until the provider returns a short page; malformed responses,
request failures, and the explicit pagination safety bound fail closed instead
of publishing a partial result.

```bash
task deps:update
task container:rebuild
task validate
task test
git diff
git commit
```

Do not commit between update and rebuild. An optional `container:upgrade` may
compose these steps, but it must not commit.

## Consequences

- Fresh clones rebuild from reviewed exact inputs without repository mutation.
- Policy changes invalidate tool layers downstream of `foundation`; the
  foundation cache remains reusable.
- Adding a tool requires provider classification, updater registration,
  integrity handling, tests, and documentation in one work unit.
- Task remains a foundation bootstrap exception, not a precedent for bypassing
  managed policy for new tools.
