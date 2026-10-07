# Owner-controlled mutable starter presets

## Goal and authorization

Replace the unpublished append-only catalog with editable/removable preset
definitions. Consumers receive normal Git updates and resolve their own diffs.
Keep existing historical release verification without catalog retention mandates.

## Scope and constraints

Edit the three `.maintainer/scripts/starter-{source,candidate,promote}.py` helpers,
`.maintainer/test/unit/starter-distribution.bats`, `.maintainer/README-distribution.md`
and `.devcontainer/docs/install-tree.md`. Current catalog content stays unchanged:
five tools, no PulseAudio. Preserve all archives, other active records, producer
activation, Compose and unrelated work. No staging, commit, publication, remote,
network, installer, Docker or lifecycle operations. Offline Git fixtures permitted.

## Tasks

- [ ] M01: Resolve editable catalogs from recorded source commits.
- [ ] M02: Prove edits/deletions retain historical identity and ordinary safeguards.
- [ ] M03: Document consumer Git semantics, independently verify and archive.

Route M01/M02 to one writer: multi-file preparation and implementation require
delegation. M03 uses independent verification and parent closure. Default test-first
applies with observed focused RED/GREEN and distribution Bats; timeout 600000 ms.
No separately configured strict mode is known. Forecast 300–600 authored lines;
heuristic advisory, delivery `ask-on-risk` deferred until explicit commit approval.

## Acceptance

No append-only, mapping-deletion or tooling-shallow catalog restrictions. New
candidates select current from their pinned source commit. Historical marked
identities reconstruct from their recorded source's catalog; explicit absent
markers preserve legacy behavior without catalog reads. Promotion verifies the
approved source, not later defaults. Retain schema, committed-input, installation,
dependency, exact-tree, approval, ordinary ancestry and compare-and-swap safeguards.
Consumers merge upstream normally; conflicting changes are resolved manually,
without automatic activation or preference-preservation guarantees.
Focused/full distribution Bats, ShellCheck, check-only shfmt, AST/JSON/Markdown and
whitespace checks must pass. RDD is off clone-local; no review approval is claimed.

## Progress

Starting HEAD `45fd4e4`, branch `dev`; previous catalog work remains unpublished
and unstaged. Parent verified existing immutable guard and spot-checked the map.
Next: writer implements source-bound catalogs and mutation/deletion regressions.

## Owner-requested rollback boundary

The owner cancelled implementation and explicitly requested rollback of all
preset-catalog work, retaining every unrelated change and the independently
authorized fixed five-tool publication defaults. No further catalog implementation
is authorized before the rollback checkpoint is reconciled.

The cancelled writer partially changed source/tests; documentation still described
the previous catalog contract. These bytes are not verified completed work.
Restore the original fixed-preset helper/test/doc baseline, including the later
PulseAudio removal; delete only the new preset JSON artifact. Preserve history in
archived records, appending supersession evidence rather than deleting it.
M01–M03 above are superseded, not completed. Route rollback to the original bounded
writer, followed by independent verification. No HEAD reset, broad clean, staging,
commit, publication or mutation of unrelated configuration/archives is permitted.

- [ ] R01: Reconstruct fixed five-tool baseline and remove catalog implementation.
- [ ] R02: Verify preservation and restored 6/31 focused/full tests independently.
- [ ] R03: Record rollback, reconcile mirrors and archive this superseded record.

## Final parent-reconciled disposition

CANCELLED/SUPERSEDED by the owner's final rollback request covering both the
preset catalog and fixed five-tool publication defaults. This later instruction
supersedes the earlier fixed-default retention boundary above; it authorizes
only rollback, not a restart or renewed catalog implementation.
Repository locator: `odd/archive/mutable-starter-presets.md`.

- The cancelled mutable writer's partial source/test edits were rejected, not
  completed implementation. M01–M03 and R01–R03 retain their original unchecked
  history; archival is R03 disposition evidence, not proof of those old plans.
- The parent restored `.maintainer/scripts/starter-source.py`,
  `.maintainer/scripts/starter-candidate.py`,
  `.maintainer/scripts/starter-promote.py`,
  `.maintainer/test/unit/starter-distribution.bats`,
  `.maintainer/README-distribution.md`, and `.devcontainer/docs/install-tree.md`
  to exact HEAD `45fd4e4` worktree bytes. The new preset JSON artifact is absent.
- This document-only worker independently confirmed all six files match HEAD
  before archival. No source implementation was reintroduced, and no fresh
  6/31 focused/full test PASS is claimed after restoration.
- Unrelated owner configuration, SSH alias, and previous archives are preserved.
  No restart, installs, Docker lifecycle, staging, commit, remote action, or
  native review approval is authorized or claimed by this disposition.
