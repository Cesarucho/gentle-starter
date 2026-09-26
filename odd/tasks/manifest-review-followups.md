# Manifest review followups

T1 implementation and isolated verification are complete; final commit acceptance
remains pending. Both followups, regression coverage, and documentation form one
coherent work unit for one final Conventional Commit. No PR is planned.

## Authority and baseline

- Project: `gentle-starter`.
- Repository locator: `odd/tasks/manifest-review-followups.md`.
- Full Engram mirror: `odd/manifest-review-followups/tasks`.
- Branch: `feat/container-lifecycle-semantics`.
- Initial HEAD: `929716b1bc27f5a5844e08f79cb0ca247e2a3cdf`.
- Initial clean worktree, branch, and HEAD were rechecked before this tracking write.
- Scope: seven nontrivial source/test files plus preparatory reading.
- Forecast: 100–180 authored additions plus deletions; actual source/tests/docs:
  118 additions + 32 deletions = 150 lines, excluding this initial tracking file.
  `delivery_strategy: ask-on-risk`; the 400-line review budget is advisory.
- Implementation and verification are complete. This is a precommit snapshot;
  staging, commit creation, and review are not claimed as completed.
- RDD: globally on, as supplied in the task context. Any new review requires its
  own candidate and authority decision. Never reuse `review-48f516ac7167929f`;
  no review PASS or receipt is claimed here.
- No Gentle AI investigation or repair, remote work, builds, downloads, or real
  Docker operations. Do not access or change live `.env`, `.env.d`, or manifests.

## T1 — Respect selected doctor mode and remove unused projection input

Status: **implemented and verified; commit pending**. The semantic snapshot and
applied-identity contract are preserved while correcting mode dispatch and
simplifying its projection call boundary.

### Scope

1. Make doctor respect the selected execution path: `run_host` supplies `check`,
   and `run_container` supplies `runtime`. Keep automatic context detection
   unchanged; the snapshot helper must not override an explicit mode.
2. Remove the unused `inputs` parameter from `project_manifest` and update every
   caller, including the 12 calls in `compose-manifest-test.py`, the fixture
   generator, and the lifecycle harness. Retain the hashes returned by `selection`
   and `compose_model`, and retain both `check_preparation_inputs` checks.
3. Add mismatch regressions and mocked lifecycle success-path coverage; update
   relevant documentation in this same unit without changing security semantics.

Primary source/test boundary:

- `.taskfiles/scripts/doctor.sh`
- `.taskfiles/scripts/compose-manifest.py`
- `.devcontainer/test/unit/doctor.bats`
- `.devcontainer/test/unit/compose-manifest-test.py`
- `.devcontainer/test/unit/manifest-fixture.py`
- `.devcontainer/test/lifecycle/starter-lifecycle.py`
- `.devcontainer/test/unit/starter-lifecycle-test.py`

Preparatory reading includes those seven files, the host-bind and volume-repair
fixtures, quality task definitions, and relevant existing ODD and manifest docs.
Additional documentation paths were declared before editing:

- `docs/en/optional-integrations.md` — explicit versus automatic doctor selection.
- `odd/tasks/semantic-volume-manifest.md` — correct the prior detected-context wording.

### Acceptance

- [x] Explicit host mode uses stored-snapshot `check` even in detected container context.
- [x] Explicit container mode uses `runtime` even in detected host context.
- [x] Auto mode preserves its existing host/container selection behavior.
- [x] Mismatch regressions preserve applied-identity rejection and security checks;
  host success does not claim applied mounts or current desired configuration.
- [x] All projection callers use the reduced signature, including all 12 unit calls.
- [x] Selection/model hashes and both preparation concurrency checks remain intact.
- [x] Mocked lifecycle success-path coverage exercises the updated projection call.
- [ ] Tests and relevant documentation ship with both followups in one final
  Conventional Commit; exact commit identity and results are recorded at closure.

## Verification evidence

No strict TDD policy is configured according to the supplied existing ODD context.
The voluntary RED/GREEN mismatch regressions are not an enabled-mode
claim. RED ran before source edits: doctor tests 2 and 3 failed respectively at
line 72 (`[ "${status}" -eq 0 ]`) and line 86
(`[ "${status}" -eq "${rejected}" ]`); the other five tests passed. Exit 1,
elapsed under one second. Both failed success status assertions because the helper
redispatched by detected context instead of respecting the selected mode.

Command/fixture effects and quality configuration were inspected before execution.
RED and GREEN used `env -i`, system PATH
`/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`, temporary `HOME`,
`TMPDIR`, `DOCKER_CONFIG`, and `DOCKER_HOST` pointing to a nonexistent Unix socket.
`LANG=C.UTF-8`, `PYTHONDONTWRITEBYTECODE=1`, and `GIT_OPTIONAL_LOCKS=0` were set.
Each command had a 120-second TERM deadline and 10-second kill grace; outer tool
timeout was 1000000 ms. Only synthetic Compose config was resolved; daemon,
build/up, installer, and privilege operations were doubled. No live env/state or
manifest access occurred. Owned scratch below `/tmp/opencode` was removed.

Required foreground commands, unchanged:

```bash
bats .devcontainer/test/unit/doctor.bats
python3 -B .devcontainer/test/unit/compose-manifest-test.py -v
bats .devcontainer/test/unit/host-bind-preparation.bats
bats .devcontainer/test/unit/volume-repair.bats
python3 -B .devcontainer/test/unit/starter-lifecycle-test.py -v
task quality:full
git diff --check
```

| Command | Final result | Elapsed |
| --- | --- | --- |
| Doctor Bats | 7 PASS | 1 s |
| Compose manifest Python | 39 PASS | 14.985 s (15 s wall) |
| Host-bind preparation Bats | 12 PASS | 8 s |
| Volume repair Bats | 17 PASS | 3 s |
| Lifecycle Python | 16 PASS | 0.018 s (under 1 s wall) |
| `task quality:full` | PASS: ShellCheck, shfmt, Markdown (17 files, zero issues) | 2 s |
| `git diff --check` | PASS | under 1 s |

GREEN total: 91 tests, zero failures/skips; batch elapsed 29 seconds, no timeout.
Precommit snapshot checks were rerun in the same isolated environment:
`git diff --check` passed, and `task quality:full` passed all three checks
(ShellCheck, shfmt, Markdown; 17 Markdown files, zero issues). No tests were rerun
for this documentation-only finalization; the 91-test result is the prior GREEN run.
Final mutating formatting (`shfmt -w` on doctor.sh) preceded the final checks.
The lifecycle success regression uses real projection/validation with a synthetic
model and rejects accidental unmocked subprocess execution. Security validators,
applied-identity gate, selection/model hash tuples, and both preparation token
checks were left unchanged; their existing negative tests passed.

Runtime evidence: mocked lifecycle success-path proof passed. Real container
build/start/connect/recreate proof is not authorized and is not claimed; synthetic
coverage cannot establish that runtime boundary. Quality was confirmed check-only.

## Rollback and delivery

Rollback only T1 changes in the seven named source/test files, its documented
documentation paths, and this tracking record; preserve all baseline lifecycle
and semantic-manifest work. Before commit, remove only T1 hunks. After the planned
single commit, revert that commit only with authorization. No live-state rollback
is needed or authorized because this task must not change live state.

Proposed final message: `fix(manifest): respect doctor mode and simplify projection`.
Commit creation remains pending verification and applicable review decisions.
After the single commit, obtain its identity with:

```bash
git log -1 --format=%H -- odd/tasks/manifest-review-followups.md
```

Record the final hash and outcome in the Engram session closure. Do not embed a
self-referential commit hash here or create a second commit solely to record it.

## Next step and skill resolution

Implementation and verification are complete; commit and review outcomes remain
pending. Keep final commit acceptance unchecked in this precommit snapshot and
record the eventual delivery outcome in Engram without rewriting this snapshot.

`skill_resolution: paths-injected`; these exact skill files were read:

- `/home/ubuntu/.config/opencode/skills/work-unit-commits/SKILL.md`
- `/home/ubuntu/gentle-starter/.agents/skills/markdown-documentation/SKILL.md`
- `/home/ubuntu/.config/opencode/skills/cognitive-doc-design/SKILL.md`
- `/home/ubuntu/.config/opencode/skills/rdd-defect-workflow/SKILL.md`
