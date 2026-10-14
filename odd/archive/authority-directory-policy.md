# Keep authority permissions directory-only

Status: owner accepted; archived. Current locator:
`odd/archive/authority-directory-policy.md` (formerly
`odd/tasks/authority-directory-policy.md`). Full memory mirror: observation
#3236, topic `odd/authority-directory-policy/tasks`.

Retain the three explicit workspace authority directories at `0700` with
`missing: "skip"` and the conditional SSH directory rule. The user approved
removing only the newly added `gen-0000000001.json` rule at `0600` and replacing
the fixed test catalog with configurable schema/contract validation. After the
parent observed RED, the parent authorized changes and reported full GREEN.
This policy selects exact directories, not files or file patterns.

## Specification and acceptance

- Validate shipped version 1 declarations against the actual schema, without
  duplicating a fixed list of directories in tests. The earlier exact-catalog
  requirement is superseded, not an ongoing acceptance constraint.
- Fixture-owned rules cover behavior and named security invariants. Adding,
  removing, or changing valid directory rules requires no test catalog edits.
- Regular file targets fail directory-only preflight before any mode changes;
  `.json` suffixes are structurally valid directory names, not schema errors.
- Authority absence, including absent nested children, never creates state.
- Unsafe existing ancestors fail before any mode change; no implicit repair.
- Document exact, nonrecursive, directory-only selection: no glob expansion or
  file-mode management. Preserve existing descendant/file safety coverage.
- Preserve the user's valid `v1` and `rdd-mode` additions and all unrelated work.

## Authorized scope and route

Implementation edit surfaces (historical):

- `.devcontainer/config/runtime-directory-permissions.json`
- `.devcontainer/test/unit/runtime-directory-permissions-test.py`
- `odd/tasks/authority-directory-policy.md`

Current archival edit surfaces: former `odd/tasks/authority-directory-policy.md`
and [archived record](authority-directory-policy.md) at
`odd/archive/authority-directory-policy.md`.

Route: delegated preparation and multifile evidence; the parent owns isolated
fixture execution, cleanup, review, and any separately authorized commit.
Both existing guides are already correct and are outside the resumed edit scope.
Forecast: fewer than 200 changed lines in one focused work unit.
This archival bookkeeping turn authorizes only the former task record, its
archived destination, and full memory mirror; source/policy edits and test
execution are not authorized here. The parent owns the authorized commits.
No parser/schema expansion, live permission application or repair, daemon,
installation, OpenCode edits, staging, or commits. Seven pre-existing modified
OpenCode files are outside scope and must remain untouched. Preserve other tasks.

## Tasks

- [x] 1. Prepare exact shipped-policy and nested absence/unsafe-ancestor tests;
  parent runs focused RED before any policy or documentation change.
- [x] 2. After observed RED, remove only the literal file-pattern rule, update
  both guides, and obtain parent-owned GREEN and triangulation evidence.
- [x] 3. Resume the full local/memory record; prepare configurable-catalog RED,
  isolated regular-file rejection, and valid `.json`-named directory tests.
- [x] 4. Parent executes the configurable-policy regression and reports RED:
  exit 1, all four valid variants fail the rigid catalog assertion.
- [x] 5. After parent instruction, replace the rigid shipped-policy assertion
  with schema validation and remove only `gen-0000000001.json` from policy.
- [x] 6. Parent runs the full fixture suite: 59 tests, exit 0 in 1.195s;
  independent read-only verification reports no blockers.

- [x] 7. Owner accepts the feature and requests commits of all changes, including
  the preserved OpenCode edits: "Hagamos commit de los cambios".
- [x] 8. Archive the full record and refresh its memory mirror and locator.
- [ ] 9. Parent creates the two planned work-unit commits and records identities;
  no worker staging or commit execution is authorized.

Tasks 1–2 and their proof below are historical completed work, not proof of the
resumed acceptance criteria. The newly added literal file rule is now removed.

## Resumed proof evidence (parent-observed RED and GREEN)

The new configurable-policy regression supplies valid fixture-owned baseline,
added, removed, and changed declarations to the original shipped-policy test.
Parent reported exit 1: all four valid variants failed its fixed
`assertCountEqual`. This is observed catalog-coupling RED before production
policy removal, not a schema rejection of file-looking names.

GREEN implementation replaces the rigid assertion with `assert_valid_policy_text`,
shared by `test_shipped_policy_has_valid_schema` and the configurable regression.
It parses with the real `unique_object` duplicate-key hook and calls the real
schema validator without a directory catalog. Existing invalid-schema tests
remain intact. No test method invokes another test method.

Removed only the production `gen-0000000001.json` rule; preserved the authority
root, `v1`, `rdd-mode` and SSH rules. Static inspection of `open_relative` shows
regular-file targets propagate `NotADirectoryError` from `O_DIRECTORY`; only a
file at the workspace `.git` component is wrapped as `ValueError`. The isolated
test now requires that precise exception and `ENOTDIR`, not a broad catch.

Parent-owned focused RED runner:

```bash
TMPDIR=/tmp/opencode PYTHONDONTWRITEBYTECODE=1 python3 -B .devcontainer/test/unit/runtime-directory-permissions-test.py PolicyTests.test_shipped_policy_validation_accepts_configurable_directory_rules
```

Parent-owned security triangulation runner:

```bash
TMPDIR=/tmp/opencode PYTHONDONTWRITEBYTECODE=1 python3 -B .devcontainer/test/unit/runtime-directory-permissions-test.py PolicyTests.test_regular_file_target_rejected_before_any_mode_changes PolicyTests.test_json_named_directory_is_a_valid_directory_target PolicyTests.test_unselected_applicable_file_blocks_scoped_ssh_preflight_and_apply
```

Existing wrong-type coverage already exercises unselected regular files. The
new isolated case checks both `skip` and `create`, target/file metadata and
payload preservation, and preflight before earlier valid rules mutate. No helper
or schema change is needed, so no new helper RED is claimed. Historical RED for
the unwanted file rule supports its removal; schema cannot distinguish a file
from a valid directory by its suffix alone. All mutations belong to temporary
fixtures; the worker executes no tests or live chmod.

Parent reported full GREEN using the exact full-suite runner below: 59 tests
passed, exit 0 in 1.195s. This includes configurable-policy variants, regular-file
rejection, valid `.json`-named directories and existing security triangulation.
Parent also reported `git diff --check` exit 0. The historical 56-test result
below remains previous-requirement evidence, not the resumed GREEN result.

## Resumed verification and owner disposition

Parent reported independent read-only verification confirming the revised
configurable schema contract and regular-file rejection with no blockers.
RDD off via `clone_local` was confirmed. Native assessment is unassessable because
the task record is untracked; no native approval is claimed. Owner acceptance
and archival are now complete; commit execution remains parent-owned. No staging,
commits, source edits, test execution or OpenCode changes occur in this archival
bookkeeping turn.

## Historical proof plan and evidence (previous requirements)

The existing assertion checks only presence, so it misses extra shipped rules.
The helper splits paths literally and opens directories with `O_DIRECTORY`;
`gen-*.json` does not select matching files. Synthetic helper fixtures declare
their own rules; the production extra rule affects the exact shipped-policy
assertion, not those fixtures.

Observed RED (parent-reported, from repository root):

```bash
TMPDIR=/tmp/opencode PYTHONDONTWRITEBYTECODE=1 python3 -B .devcontainer/test/unit/runtime-directory-permissions-test.py PolicyTests.test_single_policy_contains_explicit_conditional_ssh_creation
```

Exit 1: expected extra `gen-*.json` rule with mode `0600`. After this evidence,
removed only that rule and updated both guides. The three authority directory
rules and conditional SSH creation remain intact.

Triangulation runner (parent only):

```bash
python3 -B .devcontainer/test/unit/runtime-directory-permissions-test.py PolicyTests.test_nested_authority_skip_never_creates_missing_directories PolicyTests.test_nested_authority_unsafe_ancestor_blocks_all_mode_changes PolicyTests.test_exact_private_repair_idempotence_preserves_descendants PolicyTests.test_symlink_components_and_insecure_ancestors_rejected PolicyTests.test_unexpected_owner_and_non_enoent_never_skip
```

No tests have been executed by the worker. Fixtures use `TemporaryDirectory`
and unittest cleanup; these commands never apply policy to real authority state.
The focused runners avoid CLI subprocess tests and bytecode writes (`-B`).

Observed full GREEN (parent-reported; isolated fixtures and cleanup):

```bash
TMPDIR=/tmp/opencode PYTHONDONTWRITEBYTECODE=1 python3 -B .devcontainer/test/unit/runtime-directory-permissions-test.py
```

Exit 0: 56 tests passed in 1.401s, including the prepared nested absence,
unsafe-ancestor and existing preservation/security triangulation cases.
Parent also reported `git diff --check` exit 0. The worker did not run tests.

## Historical verification and owner disposition

Parent reported independent read-only `gentle-ai-verify` confirmation of all
scoped requirements, with no blockers. This is independent verification, not
a native review approval claim.

Parent reported RDD mode off via `clone_local` (global mode on); no repair or
review was requested. Assessment remains high/unassessable because this task
record is untracked. Final acceptance and archive disposition remain owner-owned.
No staging or commits were performed; no user commit request exists. The user's
OpenCode edits remain untouched for a future owner-authorized commit.

## Next step

Owner continuation: "Hagamos commit de los cambios". The parent will commit all
authorized changes in two independently reviewable work units:

1. Directory-policy fix, its guides/tests, and this archived record:
   `.devcontainer/config/runtime-directory-permissions.json`,
   `.devcontainer/docs/install-volumes.md`, `.devcontainer/docs/extending.md`,
   `.devcontainer/test/unit/runtime-directory-permissions-test.py`, and
   `odd/archive/authority-directory-policy.md`. This unit keeps behavior,
   regression proof and documentation together; its rollback boundary excludes
   the unrelated OpenCode changes. Runtime evidence is isolated fixture proof,
   not live authority permission application.
2. Preserved user OpenCode configuration/instruction edits: the seven modified
   files under `.devcontainer/config/opencode/`. This is a separate user-owned
   work unit; no feature-suite proof or native approval is asserted for it.

Commit identities are pending parent execution, not fabricated here. Completed
resumed full-suite runner (parent-reported):

```bash
TMPDIR=/tmp/opencode PYTHONDONTWRITEBYTECODE=1 python3 -B .devcontainer/test/unit/runtime-directory-permissions-test.py
```

Resumed RED and GREEN are parent-reported; functional verification is complete.
The worker ran no tests and must not stage, commit, change RDD mode, or touch the
seven OpenCode edits. Historical evidence remains intact; owner acceptance is
recorded. Parent commit execution is the remaining continuation.
