# Retire repository-managed Pi Gentle

Current owner approval supersedes historical no-staging/no-commit constraints below:
one cohesive local retirement commit on existing `dev`; no remote permission.
RDD preflight: requested; structured selection of both new files pending; no START,
review approval, or native PASS. Verified evidence: writer 171 Bats + 6 Python;
independent 35 PASS. No new Gentle Shell or actual HOME uninstall is authorized.

## Objective and boundary

Remove `3040-ai-pi-gentle.sh` and its exclusive provisioning FIRST, without
installing a replacement. This recovery plan starts from verified clean
`dev` at `2baf171`; preserve existing commits. No abandoned plan is input.
The checkpoint-only restriction is superseded by explicit authorization to
implement R01–R03. Changes remain unstaged and uncommitted for owner review.

- Preserve base Pi `3030`, core Engram `3010`, and core Gentle AI `3020`.
- Preserve Pi model preferences, workspace trust, and passive `.pi` Compose state.
- Do not uninstall user packages, edit user HOME, or delete persisted state.
- Do not create `3040-ai-gentle-shell.sh`; that name is reserved for later work.
- No staging, primary-repository commits, pushes, network, installs, or Docker.

## Verified map and routing

The removal trigger routes through `add-tool`. Prior delegated mapping covered
four surfaces and two writer surfaces; this unit launches no children.
Baseline source inspection confirmed these exclusive policy stems:
`GENTLE_PI`, `PI_SUBAGENTS`, `PI_INTERCOM`, `PI_WEB_ACCESS`, `PI_LENS`,
`RPIV_TODO`, `RPIV_ASK_USER_QUESTION`, `RPIV_BTW`, `GENTLE_ENGRAM`,
`PI_MCP_ADAPTER`, and `PI_TERMINAL_THEME`.
Retire their `TOOL_*_VERSION` intents and `LOCK_*_VERSION` outputs, npm specs,
managed-key inventory, and strategy registrations; preserve unrelated locks.
Remove `config/pi/gentle-ai/` and exclusive agent MCP/subagent configuration,
package lists, HUD/theme/extension settings, not base model preferences.
At HEAD, `setup.sh` seeded Gentle config with `3030` plus `3020`, without `3040`:
removing only the installer would leave active provisioning behind.

## Recovery tasks

- [x] **R01 — Offline policy retirement with focused tests.**
  Add a small explicit `tools:update --retire-locks KEY...` transaction, not a
  permanent `3040` migration framework. The original updater had no offline prune.
  Route before authentication/provider requirements; never discover candidates.
  Reject malformed, duplicate, still-managed, or otherwise unsafe requested keys;
  never automatically prune unknown locks. Retire only explicit absent-intent,
  absent-inventory keys. Specify repeat/no-op behavior in focused RED/GREEN tests.
  Reuse same-directory candidate, scope/policy/inventory validation, mode
  preservation, cleanup, and atomic publication; adapt scope for exact deletions.
  Prove unrelated bytes survive and failures leave the original unchanged.
  Remove exclusive intent/registry entries and invoke this authority for all 11
  locks; no manual generated-LOCK deletion or full network update. Keep tests and
  updater usage documentation with this behavior; record the final small design.
- [x] **R02 — Remove exclusive catalog, config, lifecycle, tests, and docs.**
  Remove installer/dependency/activation references, Gentle config trees and
  export mappings, setup seeding, and `.pi` installer-owner repair mapping.
  Keep the bind passive. Delete `pi-gentle-idempotency.bats` and the six exclusive
  Gentle Pi tests in `common.sh.bats`; retain unrelated shared-library coverage.
  Update active interop/config-export/volume/selection/policy fixtures and docs.
  Add focused regression proof that `3030` plus `3020` no longer seeds Gentle
  extensions, while base Pi preferences/trust and core tools remain intact.
  Fixture-only temporary Git initialization/commits in config-export tests are
  authorized local functional testing, never primary-repository Git mutation.
- [x] **R03 — Check active references and orphan-free closure.**
  Inventory tracked active scripts/configs/tests/docs for retired IDs, package
  provisioning, policy stems, export roots, and owner mappings. Historical ODD
  records may retain names; do not erase history to manufacture zero matches.
  Record exact selected commands/results, retained base surfaces, and exclusions.
  Leave every implementation change unstaged and uncommitted for owner review.

## Verification and review evidence

Strict TDD is not configured. Practical regression-first testing covered the new
retirement semantics; ordinary functional checks covered mechanical removal.
`task test` is unconfigured, not application proof.
The writer must inspect effects and select exact safe Bats cases before running
`bats --filter '<reviewed case regex>' .devcontainer/test/unit/<existing-file>.bats`.
Never run all `common.sh.bats` (real-network cases) or the broad maintainer suite
(Docker fixtures). Use network/auth-denying stubs for updater regression cases.
Inspect Task effects before `task install:list`, `task install:doctor`,
`task install:volumes`, or `task validate`; choose direct offline validation or
read-only script checks when their context would require prohibited effects.
The results below are observed local evidence, not lifecycle or application proof.

Forecast: roughly 1,500 mostly deleted lines; seven inspected installer/test/
Gentle-config files alone total 652 lines. The 400-line review budget is advisory
per cohesive unit, not a hard deletion cap. No PR/commit is planned; ask-on-risk
applies to future delivery decisions, not permission to perform authorized removal.
Rollback boundaries: R01 updater/policy transaction; R02 exclusive provisioning;
R03 verification evidence. Restore each reviewed diff without rewriting history.

## Implementation evidence

Route: delegated multi-file removal through `add-tool`, including its architecture,
verification, and supply-chain references. Also loaded `work-unit-commits`,
`cognitive-doc-design`, and `markdown-documentation`. No children or native review
were launched; no PR or commit is planned. The advisory review budget did not
truncate tests or scope.

R01 uses explicit eligible keys, never discovery or automatic pruning. Package,
strategy, managed-inventory, and editable-intent registrations must be absent.
Already absent eligible keys are documented no-ops. The updater validates the
original generated-section layout and candidate policy/inventory, removes only
requested assignment bytes, preserves survivor order/mode, and publishes a
same-directory candidate atomically with existing EXIT cleanup. The shared
`validate_scope` helper independently rechecks exact retirement bytes after
candidate validation; a tampered-candidate regression failed before that guard
and passes afterward.

The initial positive retirement regression failed before implementation. All nine
final retirement cases pass, including denied provider/auth paths, exact survivor
bytes without a final newline, unsafe requests, Task forwarding, and failed
publication preserving the original. The generated policy was retired only with:

```bash
task tools:update -- --retire-locks LOCK_GENTLE_PI_VERSION LOCK_PI_SUBAGENTS_VERSION LOCK_PI_INTERCOM_VERSION LOCK_PI_WEB_ACCESS_VERSION LOCK_PI_LENS_VERSION LOCK_RPIV_TODO_VERSION LOCK_RPIV_ASK_USER_QUESTION_VERSION LOCK_RPIV_BTW_VERSION LOCK_GENTLE_ENGRAM_VERSION LOCK_PI_MCP_ADAPTER_VERSION LOCK_PI_TERMINAL_THEME_VERSION
```

R02 deleted the installer, standalone suite, eight exclusive JSON configs, and six
shared-library tests. Base Pi settings retain model/provider/thinking, changelog,
and terminal preferences. Pi seeding/trust, core Node/Engram/Gentle AI, Pi's Engram
companion declaration, Dockerfile core COPY inputs, and passive Pi Compose bind
are preserved. Neither alias group contained a resolved retired-installer alias.
Setup no longer seeds extension config even with `3030` plus `3020` enabled.
Export manages only base settings and leaves legacy runtime files untouched.

### Exact local checks

| Command or selection | Observed result |
| --- | --- |
| `task install:list` | PASS; retired catalog entry absent |
| `task install:doctor` | PASS; canonical layout/dependencies intact |
| `env -u GH_TOKEN -u TOOLS_UPDATE_USE_GH_AUTH task install:versions:validate` | PASS |
| `task install:volumes` | PASS; stored snapshot only, Engram owner intact; Pi not selected in this snapshot |
| `bats .devcontainer/test/unit/tools-update.bats` | 51 PASS; isolated provider/auth stubs; supervisor timeout 600000 ms |
| `bats .devcontainer/test/unit/tool-policy.bats .devcontainer/test/unit/install-dependencies.bats` | 20 PASS |
| `bats .devcontainer/test/unit/volume-repair.bats .devcontainer/test/unit/config-export.bats .devcontainer/test/unit/tools-retire-locks.bats` | 59 PASS (18 + 32 + 9) |
| Base Pi integration selection below | 2 SKIP; base Pi inactive; no Pi CLI execution |
| `PYTHONDONTWRITEBYTECODE=1 python3 .maintainer/test/unit/starter-lifecycle-test.py LifecycleTests.test_base_selection_removes_optional_activation_and_private_mounts -v` | 1 PASS; static fixture inventory, not lifecycle execution |

The base Pi integration selection and offline shared-library selection were:

```bash
bats --filter '^ai: pi is (installed|executable)$' .devcontainer/test/integration/tools.bats
bats --filter '^(re-source guard:|devcontainer_phase |devcontainer_is_|devcontainer_has_|devcontainer_log_|devcontainer_verify_sha256 |tool versions |approved environment |generated lock |Dockerfile preserves |Java installer |Engram installer |Docker-style Engram |Phase 3[A-B] |Phase 3C-A |BATS installer )' .devcontainer/test/unit/common.sh.bats
```

The shared-library selection passed 41 cases.

Five named Compose tests passed with no Docker or real installation:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 .devcontainer/test/unit/compose-manifest-test.py ManifestTests.test_runtime_dispatch_is_checked_and_activation_is_canonical ManifestTests.test_optional_installers_are_downstream_and_do_not_install_each_other ManifestTests.test_pi_seeding_is_gated_and_preserves_existing_state ManifestTests.test_core_config_seeding_copies_missing_files_without_pi_or_user_overwrite ManifestTests.test_base_pi_and_core_gentle_seed_only_base_preferences_and_preserve_trust -v
```

Initial combined fixtures had three stale expectations (passive-report wording
and two managed MCP exports); corrected cases passed in the final 59-case run.
`opencode.bats` lost only two orphan fixture seeds; its sudo/ownership setup suite
was not executed. Base config/trust behavior is covered by the named pure tests.

After the retirement-specific scope guard was added, the unchanged update scope
path was rechecked with
`bats --filter '^baseline scope guard rejects tampering and rechecks the original compatibility floor$' .devcontainer/test/unit/tools-update.bats`:
one PASS. No provider or authentication call escaped the existing fixture stubs.

### Quality and closure

- `bash -n` passed all four changed shell scripts. Changed Bats files passed
  `bash -n` after the installed `/usr/local/libexec/bats-core/bats-preprocess`
  with `BATS_ROOT=/usr/local`, `BATS_LIBDIR=lib`, and pipeline `pipefail`.
  An initial unsupported `bats --preprocess` attempt was not syntax evidence.
- ShellCheck passed the changed production shell, retirement suite, and export
  suite. Full changed-file ShellCheck remains PARTIAL due to HEAD-confirmed
  diagnostics: `tools-update.bats` SC2034 at 30, SC2314 at 489/642/848/1030,
  SC2030/SC2031 at 926–1013; `common.sh.bats` SC2317 and SC2016 at
  166/235/243/283/290/365/369/373/875/876, SC2314 at 877;
  `volume-repair.bats` SC2016 in existing child-shell literals;
  `opencode.bats` SC2314 at 331, SC2016 at 362/367, SC2034 at 439;
  integration `tools.bats` SC2016 at 149. Locations here refer to HEAD.
- `shfmt -d` passed production scripts, retirement/volume/OpenCode suites;
  `-i 2` passed config-export and `-i 4` passed integration tools. Full formatting
  remains PARTIAL: HEAD already contains mixed indentation in `common.sh.bats`
  and heredoc/case formatting in `tools-update.bats`; no unrelated normalization.
- `python3 -m json.tool` passed all three surviving changed JSON files.
- Explicit Markdown coverage is all eight changed docs/taskdoc; zero issues.
  `git diff --check` passed; HEAD remains `2baf171`, primary index unchanged.
- Tracked active-reference inventory retains only negative regression fixtures,
  protective runtime exclusions, and existing cross-harness OpenCode agent/shared
  skill references to external Pi adapters; none provisions the retired tool.
  Historical ODD/CHANGELOG/ADR records are retained, not erased for zero grep.
- No user HOME package/config/state removal, new tool activation, release upgrade,
  real providers/network, Docker, real lifecycle, staging, commit, push, or history
  rewrite occurred. Broad `task validate`, maintainer suites, and application
  proof were not run. Product replacement remains explicitly out of scope.
