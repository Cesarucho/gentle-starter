# Ignore installed external skills

Status: closed and archived under parent authorization; native review skipped for this candidate, not approved.
Repository locator: `odd/archive/ignore-external-skills.md`.
Engram mirror: `odd/ignore-external-skills/tasks` (project `gentle-starter`).

## Authorized boundary

One cohesive ignore-policy, index, and documentation migration. Add
`.agents/skills/*` and `!.agents/skills/add-tool/` to `.gitignore`; remove only
currently tracked external skill entries with `git rm --cached`, preserving
every local skill path, byte, mode, and symlink. Retain the original seven
tracked `add-tool` files. Preserve installed `rfc-specification` as ignored,
local-only content absent from `skills-lock.json`; do not re-add its lock entry.
Compact existing sections only: root `AGENTS.md` Project skill lifecycle,
`README.md` skills notes, and `.devcontainer/docs/optional-skills.md`.

Keep lock, add-tool, runtime/release scripts, registry, RC state, unrelated edits,
and refs unchanged. No installs, network, builds, delegation, commit, or push.
Only authorized external index removals may be staged; leave prose unstaged.

## Verified starting state and forecast

- CONTAINER checkout: `test/gentle-shell-v4`, HEAD
  `aa52cef24f89b81c2cd6d5f8ecb41d31f7a5e0c7`; worktree and index initially clean.
- Origin is configured; inspected metadata only, with no remote operation.
- Route 4: delegated writer for four policy/docs paths plus the index migration;
  this worker does not delegate further.
- Forecast: fewer than 100 authored prose lines; 132 installed external files,
  857,653 indexed bytes, 27,843 indexed lines removed from the index only.
  These vendored dependency removals are not authored source deletions; report
  actual volume, without a size-only stop. Seven add-tool index files remain.
- TDD unknown/not established. Structural migration proof is applicable;
  runtime harness N/A because runtime behavior and installation are unchanged.
- Rollback boundary: restore only this policy/docs diff and original external
  index entries from the captured baseline; never overwrite local skill files.

## Tasks

- [x] 1. Implement policy, index migration, and compact documentation together.
  Before mutation capture a full `.agents/skills/` manifest (all paths including
  directories, file SHA-256, lstat modes/types, and symlink targets without
  following links), original add-tool index inventory, lock hash, refs, status,
  and protected/unrelated file and index snapshots. Select external paths from
  `git ls-files -z`, excluding add-tool, and use only `git rm --cached` on them.
- [x] 2. Verify structural invariants and report evidence for parent closure.
  Require identical before/after skill manifests, add-tool inventory, lock,
  protected/unrelated snapshots, and refs. Require exactly the original seven
  add-tool paths tracked under skills; every external path ignored and add-tool
  not ignored. Report exact staged deletion volume and unstaged authored diff.
  Parent alone reconciles results, updates this record and full mirror, and
  archives safely under `odd/archive/ignore-external-skills.md` with readback.
  Do not claim review approval or require a commit for this authorized scope.

## Verification commands (CONTAINER; not run during preparation)

```bash
git ls-files --stage -z -- .agents/skills/add-tool/
git ls-files -z -- .agents/skills/
git check-ignore --no-index -- .agents/skills/rfc-specification/SKILL.md
git check-ignore --no-index -- .agents/skills/add-tool/SKILL.md
sha256sum skills-lock.json
markdownlint-cli2 --no-globs AGENTS.md README.md .devcontainer/docs/optional-skills.md
git diff --check
git diff --cached --check
git diff --stat
git diff --cached --numstat
git status --short
git show-ref
```

The add-tool check-ignore command must exit 1; external paths must exit 0.
Check all external and add-tool paths, not just these examples. Capture and
compare manifests/snapshots using a deterministic local helper outside source;
SHA-256 alone does not prove directory modes or symlink preservation.

Optional distribution proof is pending fixture/effect inspection and parent
selection of an exact anchored Bats filter. The proposed broad filter is not
approved as-is: current test names include `candidate keeps filtered skills and
refuses stale or unexpected refs` and `published starter preserves skills
selector and guide bytes`; fixture coverage is not real RC/lifecycle proof.
No actual tests were run in preparation.

## Implementation evidence

- Delegated writer loaded markdown-documentation, cognitive-doc-design, and
  work-unit-commits at the requested paths; no further delegation occurred.
- Baseline captured before source/index mutation at
  `/tmp/opencode/skills-migration-baseline.json`; deterministic no-follow helper
  `/tmp/opencode/skills-migration-proof.py` records directories, lstat modes,
  file SHA-256/bytes, and symlink targets. All 164 skill paths remain identical.
- Exactly 132 explicit external index paths removed with `git rm --cached`;
  all local content retained. Staged volume: 857,653 bytes / 27,843 lines.
  All 152 external tree paths ignored; add-tool paths and parent skills
  directory not ignored. Original seven add-tool index entries unchanged.
- All 296 protected tracked file snapshots and protected index entries,
  unrelated untracked inventory, refs, branch, and HEAD unchanged. Lock retains
  11 names, excluding rfc-specification; SHA-256
  `5a91a47283e78e5a2c5616fb2711affd5fc5e083dd558d0ff0ba34e5f8b67bca`.
- Historical writer snapshot: four policy/docs paths, 16 additions, zero deletions;
  all unstaged. Superseded current counts are recorded below.
  No skill content normalization, runtime/release/registry/RC changes, installs,
  network, builds, host operations, primary-checkout commits, or pushes.
- `markdownlint-cli2 --no-globs AGENTS.md README.md .devcontainer/docs/optional-skills.md`:
  v0.23.3, three files, zero issues. Both Git diff whitespace checks passed.
- Inspected setup, selected tests, and candidate/promote/source helpers:
  temporary local Git fixtures only, no Docker/network. Fixture commits and
  refs are isolated, not delivery commits or primary-checkout RC operations.
  With `PYTHONDONTWRITEBYTECODE=1`, each command passed exactly one test:

```bash
bats --filter '^candidate keeps filtered skills and refuses stale or unexpected refs$' .maintainer/test/unit/starter-distribution.bats
bats --filter '^published starter preserves skills selector and guide bytes$' .maintainer/test/unit/starter-distribution.bats
```

The earlier optional-selection paragraph records preparation history; these
exact filters were subsequently authorized and executed. Parent alone handles
RDD assessment/preflight, native review, and eventual closure/archive. No
lifecycle proof was requested or claimed. Final structural checks are rerun
after this record update; full mirror uses the same stable topic with readback.

## Independent current verification before fresh review preflight

- CONTAINER: inspected the helper before execution. Its `verify` branch is
  read-only; capture and migrate branches were not run. `python` was unavailable;
  `PYTHONDONTWRITEBYTECODE=1 python3 /tmp/opencode/skills-migration-proof.py verify`
  passed against the existing baseline without code or index mutation.
- All 164 local skill paths, hashes, lstat modes/types, and symlink targets match
  the baseline. Exactly 132 original external entries remain staged as cached
  deletions; 27,843 indexed lines / 857,653 indexed bytes. All 152 external tree
  paths are ignored; the skills parent and add-tool paths are not ignored.
- Original seven add-tool index entries, 296 protected tracked byte/mode
  snapshots, protected index, unrelated untracked inventory, refs, branch, and
  HEAD match the baseline. Lock bytes/hash remain unchanged with 11 names;
  installed rfc-specification remains local-only and absent from the lock.
- Current policy/docs diff contains only `.gitignore`, `AGENTS.md`, and
  `.devcontainer/docs/optional-skills.md`: 12 additions, zero deletions, unstaged.
  README has no current diff: its earlier four-line note is no longer present
  in the diff, consistent with reversal of that exact approved worker note.
  Change provenance is unknown; no actor attribution is established. Preserve
  current README bytes; neither undo nor reapply it. AGENTS and the guide are
  self-contained, so no replacement README note is needed.
- Current markdownlint-cli2 v0.23.3 check of AGENTS, README, and the guide passed
  (three files, zero issues). Both current Git whitespace checks passed.
- Both exact local-Git fixture tests above remain historical passing evidence,
  not newly executed proof. Protected runtime/test files are unchanged, so no
  costly rerun was performed. No runtime, lifecycle, network, install, or remote
  proof is claimed. TDD remains unknown/not established; the parent reports a
  high native assessment, not review approval.
- Parent-reported native consent: the user selected `Omitir esta vez` for target
  `c05d0c...`, but the exact decline returned `stale_target_identity` /
  `not_started` after tree drift. Review was NOT successfully skipped; no review
  authority or closure is established. This is a stale-candidate/native-choice
  blocker, not a structural migration failure. Parent must perform fresh review
  preflight on the current candidate before obtaining an applicable choice.
- This worker changes only this task record and full mirror #2805. No additional
  staging, source/runtime changes, refs, commits, archives, installs, network,
  or delegation. Historical evidence remains intact; parent alone closes ODD.

## Final parent reconciliation and authorized archive

- Parent reconciled the completed authorized migration and authorized this
  record-only closure/archive. Both implementation tasks remain completed.
  Current source scope is three policy/docs files, 12 additions, zero deletions;
  README has no diff and its current bytes are preserved. Historical four-file,
  16-addition evidence and the earlier stale-target drift remain above.
- Parent reports the latest exact native decline succeeded for candidate
  `sha256:a30d6cdae194b556b20f1fea8b72ba42aea36a369afeb593606346feeb7385b8`:
  action `declined`, consent `declined_this_candidate`. This supersedes the
  earlier stale-choice blocker for closure. Native review was skipped for this
  candidate only; no review authority or approval exists. Future review remains on.
- Parent accepted the writer's two anchored Bats passes (one test each), lint,
  whitespace checks, independent structural proof, and parent spot-diff/tracked
  inventory checks. No new tests or reviews were run for archival. TDD remains
  unknown/not established; no runtime or lifecycle proof is claimed or required
  for this unchanged-runtime migration.
- Pre-archive structural verification passed: all 164 local skill paths equal
  baseline, seven add-tool index entries identical, lock's 11 names unchanged
  with rfc-specification absent but locally preserved, all 152 external paths
  ignored with parent/add-tool not ignored, protected files/index and refs intact,
  and exactly 132 original cached removals retained.
- Archive destination was absent and navigation search found only this record's
  own locator. Historical content is preserved at the new locator; full mirror
  #2805 retains topic `odd/ignore-external-skills/tasks`. Source bytes, README,
  index, skills, lock, and refs are not modified by this record operation.
- Post-archive verification compares the existing baseline with only the new
  authorized untracked archive locator excluded from unrelated inventory.
  Read back the archive and full mirror; the former task path must be absent.
  No additional staging, commits, remote operations, or delegation are authorized.
