# Add-tool Runtime Directory Guidance

## Objective and authorized scope

Teach add-tool to route managed runtime directory creation and modes to the unified policy instead of duplicating installer mkdir/chmod. Add concise decision rules and a local reference; preserve installation, file modes, root preparation, ownership and tool-specific security boundaries.

## Constraints

- Edit only add-tool skill and its new runtime-directory reference; English artifacts.
- Preserve existing implementation and user AGENTS.md edits. No staging, commits, publishing, Docker, network or runtime permission repair.
- Keep metadata/triggers unchanged unless necessary. Use creation-only lifecycle, explicit create/skip/intermediates and validated optional applicability.

## Tasks

- [x] S1: Update skill and reference, verifying current policy contracts and local links.
  - Route: delegated direct; preparation and two nontrivial artifacts require one bounded writer.
- [x] S2: Independent instruction-contract verification, reconcile and archive with full mirror readback.

## Checks and progress

- TDD exception: instruction/reference edits have no meaningful runtime RED; structural and contract readback are applicable.
- Checks: frontmatter, sections, body budget, local links, correspondence to actual helper/schema/setup, git diff --check.
- Active-record precreation inventory: odd/tasks empty. Baseline dev c2c0f87 with prior uncommitted feature and owner AGENTS.md changes.
- Forecast approximately 70–120 authored lines. Delivery: local unstaged/uncommitted review under repository policy; no work-unit commit without explicit reviewed-diff approval.
- Native mode previously unreadable; assess conservatively and independently verify if unassessable. No native approval claimed.
- S1: skill adds hard rule, decision gate, execution/output evidence and local reference. New reference matches create/skip, conditional applicability and specialized safety boundaries. Metadata unchanged; no registry refresh required.
- Writer structural assertions, local links, inspector and diff checks pass. Body measured 907 lexical proxy units (not exact model tokens); no local tokenizer. Parent reran check-only Markdown lint and diff check successfully; stdout reports one stdin input, zero issues in zero files, so preserve that reporting limitation.
- Native assessment high/unassessable due to existing untracked inventory; independent verification required under unknown-mode fallback. No review receipt.
- Next step: independent S2 verification and reconciliation.

## Closure reconciliation

- Independent verification confirmed policy correspondence, preserved critical rules and specialized boundaries. One bounded compaction reduced body to 265 words, 2446 bytes and 513 lexical proxy units; approximate character/4 estimate 612 tokens. No installed tokenizer, so exact budget not certified; conservative headroom accepted as measurement limitation.
- Effective installed markdownlint library checked both files with repository config: two files, zero issues; malformed in-memory negative control detected. Parent independently reran effective lint and diff check successfully. Earlier CLI stdin results checked zero files and are withdrawn as lint proof.
- Writer proved frontmatter unchanged using git show HEAD; metadata and paths unchanged, no registry refresh required. All local references exist; detailed constraints retained in existing references and clearly labeled cross-surface section of new reference.
- Instruction-only TDD exception applies; no runtime/application tests or authority repair performed. Native assessment high/unassessable and mode unavailable handled by independent instruction verification, no receipt claimed.
- No pending in-scope implementation or decisions. Archived to odd/archive/add-tool-runtime-directories.md; no navigation links reference former tasks locator. Existing runtime changes and owner AGENTS.md preserved; all changes unstaged/uncommitted.
- Next recommended action: owner reviews skill diff and reference.

## Owner-approved delivery

- Skill/reference commit: `58492f6afb90e11de6d59a747ae14920fed6aa22` (`docs(add-tool): route runtime directories through unified policy`).
- Delivery branch: `feat/runtime-directory-policy`; no push performed. Depends on runtime policy commit `9ef579d4a6a829369c8669e2e2f367da96a2ab49`.
- Includes the two reviewed reference corrections for Engram build/runtime phases and host private-source modes. Metadata unchanged; no registry refresh. Owner AGENTS.md and private evidence excluded; proposed operational-test skill not created in this unit.
