# Add optional Gentle Shell v4

## Objective and scope

Provide optional `3040-ai-gentle-shell.sh` with the verified `gentle-pi@4.0.0`
package and its independent private Gentle AI v4.0.0 bundle. This replaces no
retired provisioning and reuses no abandoned v3.7 draft. The problem is that
skipping npm postinstall leaves a missing private binary, while running it
uncontrolled does not meet repository policy or root-to-ubuntu permissions.

Include dependencies, transactional composite lock resolution, installer,
fail-closed managed launcher, focused fixtures, and concise user documentation.
Do not alter global OpenCode/Gentle AI or activate companions automatically.
The resumed scope below supersedes the original manual-setup and Pi-bind limits.

### Resumed ready-to-use scope and authorization

Provide isolated `~/.gentle-shell` agent/config persistence, opinionated missing-only
defaults (fullscreen and Gentleman-Cute), repository-controlled provisioning, and
the pinned runtime-only Engram Pi adapter. Reuse exact policy-managed global Pi
and the existing Engram binary/storage; never copy credentials or databases, use
`--link`, run native setup, or migrate personal configuration. Keep process HOME
unchanged for Engram. Optional installation and Compose selection remain separate.

Route: resumed delegated single writer; multi-file/provider/lifecycle triggers
`add-tool`. All five requested skill files were read again. User no-commit override
wins over work-unit-commits; no children, staging, commits, publication, Docker,
build/lifecycle, real HOME installation, ambient credentials, or remote execution.
Technical artifacts are English. The prior approved/burned review covers only old
bytes, not this resumed scope. TDD remains unknown/unconfigured: ordinary focused
Bats checks, not strict RED. The approximately 400-line advisory is not a gate or
a reason to compress code or split artificial tasks. Preserve completed GS4-01–07.

Parent isolated public-install proof is accepted without repeating downloads:
`gentle-pi@4.0.0` with `--legacy-peer-deps --ignore-scripts` had 80 dependency
entries, no Earendil/typebox copies; managed Pi 0.99.2 loaded 18 Shell extensions
plus the pinned Engram adapter without errors/warnings; native isolated `--version`
reported Shell 4.0.0/Pi 0.99.2. No session, API, database or real HOME was touched.
This is loader/version evidence, not ready-to-use provisioning/persistence proof.

| ID | Resumed task | Status | Acceptance / evidence |
| --- | --- | --- | --- |
| GS4-08 | Reuse exact managed Pi; retain private bundle guards | Verified (local) | Exact canonical global npm root/package/CLI probe; no peer copies; Pi-only update fixture passes |
| GS4-09 | Provision isolated missing-only defaults and pinned adapter | Verified (local/loader) | Automatic postCreate shared seeder, read-only runtime validator, byte-preserved preferences, malformed paths and no-migration fixtures pass; parent real loader proof retained |
| GS4-10 | Add passive Shell persistence and activation-gated seed | Verified (mock) | Independent disabled Compose selection; mocked host root ownership/preservation and applied manifest identity pass; actual bind/recreation not run |
| GS4-11 | Normalize, verify and document resumed behavior | Verified (local) | Final selected suite 99/99; syntax, ShellCheck, repository and Markdown checks pass; owner review/runtime proof remain separate |

Rollback boundary: resumed managed-Pi/provisioning helpers, Shell baseline/adapter,
optional Compose override and seed branch, associated focused tests and docs. Keep
prior composite locks and unrelated completed work. Final closures require observed
checks; owner retains review authority and operational proof remains unauthorized.

### Resumed implementation evidence and next step

#### Accepted configuration ownership correction

User correction: configuration copying belongs to activation-gated postCreate
`setup.sh` and its existing `seed_config_tree`, not Dockerfile/image installation
or launcher-owned seeding. Remove only the added Dockerfile config COPY and the
installer's image-baseline dependency. Keep image-owned read-only path/JSON and
pinned-adapter validation; validate Shell paths before the existing seeder and
validate readiness afterward. Do not globally harden/refactor the generic seeder.
The launcher must never seed a home or depend on `/opt` baseline configuration;
missing readiness must point to automatic container postCreate recovery, not
manual `gentle-shell setup`. Preserve all remaining v4 behavior and constraints.

Route: bounded configuration-ownership correction under `add-tool`; exact add-tool
and markdown-documentation skills reread. No children, staging, commits, native
review, Docker execution, real HOME installation or migration. Earlier 99-test
proof applies to preceding bytes only; corrected bytes require the same focused
suite, changed syntax/Node/ShellCheck checks, `task validate` and diff checks.
Correction status: implemented and bounded re-verification passed. Dockerfile
now has no diff: only the added config COPY was removed. The installer retains
the immutable read-only validator but has no config source/baseline dependency.
Its adapter hash metadata is independent of mutable persisted configuration;
the generic copier remains unchanged. Corrected fixtures extract only
`seed_config_tree` and `setup_versioned_configs` into isolated temporary HOME and
workspace paths; they never source complete postCreate or invoke real sudo,
Docker, npm/network, databases or credentials. They prove disabled seeding,
missing-profile read-only failure, automatic seed, preserved preferences, rejected
unreviewed source files, pinned checks and image installation with no baseline.

Correction commands and observed results (all exit 0):

```bash
shfmt -w .devcontainer/setup.sh .devcontainer/install/available/3040-ai-gentle-shell.sh .devcontainer/test/unit/gentle-shell.bats
bash -n .devcontainer/setup.sh .devcontainer/install/available/3040-ai-gentle-shell.sh .devcontainer/test/unit/gentle-shell-fixture.bash
shellcheck .devcontainer/setup.sh .devcontainer/install/available/3040-ai-gentle-shell.sh
node --check .devcontainer/install/lib/gentle-shell-provision.mjs
node --check .devcontainer/install/lib/gentle-shell-launcher.mjs
node --check .devcontainer/install/lib/gentle-shell-bundle.mjs
bats .devcontainer/test/unit/gentle-shell.bats .devcontainer/test/unit/gentle-shell-state.bats .devcontainer/test/unit/tools-update.bats .devcontainer/test/unit/tool-policy.bats .devcontainer/test/unit/install-dependencies.bats .devcontainer/test/unit/install-selection.bats .maintainer/test/unit/guide-links.bats
task validate
git diff --check
markdownlint-cli2 odd/tasks/add-gentle-shell-v4.md .devcontainer/docs/gentle-shell.md
git diff -- .devcontainer/Dockerfile .devcontainer/setup.sh
git diff --cached --stat
```

The corrected focused set passes 99/99, `task validate` reports zero errors and
warnings, Markdown lint reports zero issues, and the index is empty. Formatting
ran before final source checks. Real postCreate/image/session/Engram/bind proof
remains excluded; no operational completion or new review approval is claimed.

The optional installer uses `--legacy-peer-deps --ignore-scripts`, records the
privileged global npm Pi root, and validates exact package/CLI identity rather
than ambient PATH. Shell/private integrity is independent of Pi metadata so
Pi-only updates do not reject a valid immutable Shell destination. Duplicate
Earendil/typebox dependencies and both shared/isolated development registrations
are refused. No new policy locks or provider discovery were needed.

The launcher uses upstream public parse/version/invocation exports, not native
mutating bootstrap. Normal HOME remains intact for the existing Engram instance;
Gentle config and agent sessions are isolated under the passive Shell root.
Runtime-only Engram 0.1.16 adapter files and license were fetched unchanged from
the supplied immutable v2.2.1 commit, with explicit SHA-256 provenance. No native
setup, unpinned companion installer, initializer, credentials or database copies
are used. Fresh defaults are fullscreen/Gentleman-Cute; existing settings/config
bytes are preserved. Seeding belongs only to activation-gated automatic postCreate
via `seed_config_tree`; the launcher validates readiness without copying files.

Observed checks (all exit 0 unless noted):

- `shfmt -w` on changed shell/fixture files ran before final checks.
- `bash -n` on setup, installer, updater and shared fixture; `shellcheck` on
  changed production shell; `node --check` on bundle/launcher/provision helpers.
- The original six-suite Bats command plus `gentle-shell-state.bats`: 99/99 pass.
  The state fixture mocks Compose resolution/container checks, never Docker.
  An initial 93-test run exposed a fixture missing mandatory core Engram;
  corrected the fixture to reflect the actual core tree, then reran successfully.
- Actual SRI-verified Shell 4.0.0 public parser/invocation exports: isolated env,
  spaced arguments, exact CLI invocation and Pi subcommand ordering pass without
  a session, runtime API, CLI or database invocation.
- Adapter `sha256sum --check SHA256SUMS`: all four runtime files and license pass.
- `task install:list`, `task install:doctor`, `task install:volumes`: pass;
  optional activation stays unchanged and volume output is the old snapshot.
- `task validate`: pass, zero diagnosis errors/warnings and strict quality pass.
- Explicit task/provenance Markdown lint and `git diff --check`: pass.
- `git diff --cached --stat`: empty; no staging, commits or publication.

Limits: prompt-history capture is forced off because upstream v4.0.0 hardcodes
the shared Pi history root; no upstream patch or HOME redirection is performed.
The native exit resume-hint handoff is not provided by the managed wrapper;
ordinary Pi session resume remains available. Actual enabled image installation,
session/Engram tool calls, Docker binds/recreation, cross-architecture execution
and the full starter suite were not run. These local/mocked results are not
operational ready-to-use proof. Parent loader/version evidence is reused, not
claimed as execution of this new launcher/bootstrap. No required local check is
failing. Next step: owner review of all resumed bytes; operational proof requires
separate authorization. The old approved/burned review does not cover this diff.

## Execution contract

- Route: delegated single writer; a new managed provider and multiple code,
  policy, fixture, and documentation surfaces trigger `add-tool`.
- Skills read: add-tool, context7-mcp, cognitive-doc-design,
  markdown-documentation, work-unit-commits (exact paths supplied by the user).
- User override: all changes remain unstaged and uncommitted; no PR, publication,
  push, child agents, remote execution, Docker, actual installation, or user
  HOME/session migration. No native review lifecycle in this worker.
- TDD mode: not configured. Existing ODD records identify it as unknown;
  `openspec/config.yaml` is absent and the registry declares no TDD mode.
  Runner source: `.maintainer/tasks/test.yml`, Bats unit/integration suites.
  Ordinary focused characterization and regression checks; no strict-TDD claim.
- Preliminary forecast: 350–550 authored lines in one coherent uncommitted work
  unit. Rollback boundary: the new Shell installer/helpers/tests/docs and its
  dependency/policy/updater registrations; unrelated files remain untouched.
- Network forecast: public npm tarball plus two Linux archives, up to 120 MB
  downloads and 250 MB temporary disk, 1–5 minutes; no installed/cache state.
  Full updater is inventory-wide, not selective; forecast separately before use
  with an external timeout of at least ten minutes. Do not fabricate locks.

## Tasks and acceptance checks

| ID | Task | Status | Evidence / check |
| --- | --- | --- | --- |
| GS4-01 | Inspect install, policy, tests, state, upstream contracts | Complete | Inspector passes; clean dev at afdeff4565b0712b3244f9e4b0c3b4da6e422886 |
| GS4-02 | Verify npm SRI and both archive/binary hashes | Complete | Public bytes match all upstream pins; no binaries executed |
| GS4-03 | Register and resolve composite policy transactionally | Complete | Scoped authoritative bootstrap generated seven locks; two transactional tests pass |
| GS4-04 | Implement optional installer and guarded launcher | Complete | Eight mocked installer/launcher tests pass; no real installation claimed |
| GS4-05 | Cover installer, updater, dependency and policy contracts | Complete | Final inspected focused suite: 87/87 pass; no real installation |
| GS4-06 | Document activation, setup and persistence limits | Complete | Guide, index and extension links pass Markdown/link checks |
| GS4-07 | Normalize and run authorized safe checks | Complete (bounded) | Syntax, ShellCheck, 87 Bats checks, repository checks pass; full runtime proof excluded |

## Verified sources and trust

- npm registry `gentle-pi/4.0.0`: bin `gentle-shell`, Node >=22.19.0,
  Pi >=0.99.1; gitHead `1f35ab1e4ff78f41ce6102cd961e7889a9f1cf69`.
- SHA-512 SRI verified over the actual npm tarball:
  `sha512-ZG/diWBSKPfjU4MjiHVUXxHWQvDSRS2dvpPCma4ZINuV+8UGdZAPHca6vcK27FLAAG7crlJpwdWOcwVNW4rh/Q==`.
- Linux amd64 archive SHA-256:
  `5f4417cf29c969c86da4799942fd673368840901be1bb09c779a12d7ed6096ea`.
- Linux amd64 binary SHA-256:
  `50ba217b5138c1a9c7d5bf2f79931b1bb89b89c4cf650dcd7ee037657c88158d`.
- Linux arm64 archive SHA-256:
  `1383b040c95cfc69206660d73c21907b14ad70ab913f410917c54f43d3147e57`.
- Linux arm64 binary SHA-256:
  `6703704f0c4a5b70c36fbdc44db641e810871cab16bc28040d06aa1d10704ad3`.
- npm installer module matches the v4.0.0 raw tag bytes, SHA-256
  `bc2da0585026fa538f0c6ae0cf50463767c175b71d0dfdb582a88cbe894c84ca`.
- These are byte-integrity checks against npm/upstream same-boundary pins, not
  independent signature, attestation, or publisher-identity verification.
- Private layout: `.gentle-ai/v4.0.0/gentle-ai`, canonical compact
  `integrity.json` fields ordered version, asset, assetSha256, binarySha256,
  followed by one newline. Root-created 0700/0600 is insufficient for ubuntu.
- Upstream permits environment and persistent `dev-binary.json` overrides;
  setup also has binary/pin/installer test overrides and automatic recovery.
  Managed entry must reject these rather than silently changing trust.
- Passive `.pi` Compose override exists. Default launcher config/state under
  `.gentle-shell` is not covered by that mount; document this limitation.
- Global config: orchestrator `openai/gpt-6.1-sol`, low reasoning; general has
  no explicit model and denies child tasks. Runtime worker is gpt-6.1-sol.

## Original implementation evidence (historical)

Implemented and verified within authorized local boundaries. No product blocker
or additional user decision remains. Next step is owner review of the unstaged
diff; real image/build/session proof needs separate authorization. No default
activation, new mount, global OpenCode change, or HOME migration was introduced.

The scoped bootstrap appends only the seven absent Shell locks and preserves
unrelated bytes/mode; later ordinary updates resolve Shell with the inventory.
The guarded launcher uses upstream resolver and argument-parser exports,
preserves native runtime/home selection, rejects development trust overrides,
and disables automatic setup/recovery. Manual native setup remains available.

Public `pi-pretty@0.6.27` metadata revealed non-optional Pi peers. The private
npm prefix therefore includes adjacent Pi at the existing Pi policy lock, and
the launcher verifies that package/version. This duplicates global Pi but
avoids npm choosing an untracked runtime preferred by the native launcher.

The authored implementation exceeded the preliminary 350–550-line forecast;
it remains one coherent review unit, not a commit or publication request.

### Implementation commands and results

- `env -u GH_TOKEN -u TOOLS_UPDATE_USE_GH_AUTH task tools:update -- --bootstrap-gentle-shell`:
  exit 0, external timeout 600000 ms. Pre-launch forecast: about 22 MB downloads,
  under 75 MB temporary disk, 1–3 minutes. Actual artifact hashes match the
  source evidence below; all seven locks generated by the sole policy authority.
  Policy diff contains only Shell intent and seven Shell locks; unrelated locks
  are unchanged. Bootstrap transient files were cleaned by its EXIT trap.
- `shfmt -w` on the changed installer/updater and Shell/dependency fixtures:
  pass, performed before final tests. `bash -n` on installer/updater/shared
  fixture, `node --check` on both new mjs helpers, and `shellcheck` on changed
  production shell scripts: all exit 0.
- Final foreground Bats command (exit 0, 87/87 pass):

  ```bash
  bats .devcontainer/test/unit/gentle-shell.bats \
    .devcontainer/test/unit/tools-update.bats \
    .devcontainer/test/unit/tool-policy.bats \
    .devcontainer/test/unit/install-dependencies.bats \
    .devcontainer/test/unit/install-selection.bats \
    .maintainer/test/unit/guide-links.bats
  ```

- Initial broader 81-test run: one transport-diagnostic ordering regression.
  Moved normal Shell discovery last; subsequent 84-, 85-, and final 87-test
  runs passed. No retrospective strict-TDD claim.
- Actual SRI-verified npm artifact unpack/probe using `gentle-shell-archive.py`
  and `node --input-type=module`: exit 0. Verified real runtime exports,
  controlled resolver environment/missing-bundle error and native package-root
  parsing. No real binary or native CLI was invoked. Probe bytes are retained
  under `/tmp/opencode/gs4-artifact-probe`, not installed in the environment.
- Final inspector: exit 0, 39 catalog entries, 13 aliases unchanged, 35 intents
  and 58 locks; no broken/invalid/unsafe aliases.
- `task install:list`, `task install:doctor`, `task install:volumes`: exit 0.
  Shell appears inactive with Node/Pi requirements; volume snapshot unchanged.
- `task validate`: exit 0, zero diagnosis errors/warnings; strict formatting
  and Markdown checks pass. Explicit task-document Markdown lint also passes.
- `bats --filter 'optional Gentle Shell' .devcontainer/test/integration/tools.bats`:
  exit 0, one expected disabled-tool skip; not installed-runtime proof.
- `git diff --check`: exit 0. `git status --short` includes only intended
  implementation/documentation files; `git diff --cached --stat` is empty.

### Explicitly excluded proof

- Full `task --taskfile .maintainer/Taskfile.yml test:starter` was not run.
  Only the inspected mock suites above were selected; full transitive fixture
  safety has not been established under no-install/no-lifecycle boundaries.
- Real tool installation, Docker/build/lifecycle, native Shell launch/setup,
  user migration, remote execution, publication and native review were not run.
- `task test` remains application-owned and unconfigured (observed exit 2).
  No application, installed-runtime, cross-architecture execution, or new
  persistence proof is claimed. There is no remaining failing implementation
  check in the selected authorized suite.

### Historical exploration commands and results

- `git status --short`, `git branch --show-current`, `git rev-parse HEAD`,
  `git remote -v`: clean initial dev and exact HEAD verified; remotes inspected
  locally only. Origin is the expected GitHub SSH URL; no remote execution.
- `bash .agents/skills/add-tool/scripts/inspect-install-tree.sh /home/ubuntu/gentle-starter`:
  exit 0; 38 catalog installers, 13 active aliases, no invalid/broken aliases.
- Three `curl -fsSL --max-time 180 -o /tmp/opencode/gentle-shell-v4-*` public
  artifact downloads: exit 0 under external 600000 ms timeout. Total retained
  temporary bytes: 22,228,148. No extraction to HOME or binary execution.
- `sha256sum` on both archives and `tar -xOf ... gentle-ai | sha256sum`:
  exit 0; exact hashes above. `openssl dgst -sha512 -binary ... | openssl
  base64 -A`: exit 0; exact npm SRI above. Installer-module npm/tag hashes match.
- `bats .devcontainer/test/unit/tool-policy.bats .devcontainer/test/unit/tools-update.bats`:
  exit 0; all 59 existing tests pass, inspected mocked providers and scratch
  policy files. These do not test a Gentle Shell implementation.
- `task install:list`, `task install:doctor`, `task install:volumes`: pass.
  Volumes reports the last host-prepared snapshot, not new persistence proof.
- `task validate`: pass; container diagnosis reports zero errors/warnings,
  formatting and Markdown checks pass. No lifecycle or application proof.
- `task test`: expected exit 2, application tests are not configured.
- `markdownlint-cli2 odd/tasks/add-gentle-shell-v4.md`: exit 0; 21 files,
  zero issues. No source normalizer or `bash -n` applies to this docs-only diff.
- Plain `jq` inspection of global `opencode.json`: exit 4 on the existing
  trailing comma at line 389; model fields instead read directly. No config edit.
- Exploration `git status --short`: only this untracked task document;
  `git diff --cached --stat`: empty. No staging or commits.

## Coordinated Engram 3.0.0 upgrade

Authorized single-writer multi-file/provider/API update under `add-tool`; no
children or commits. Preserve all historical completed tasks and uncommitted v4
work. Technical artifacts are English. Ordinary focused checks only; TDD remains
unknown/unconfigured. The 400-line advisory must not compress code or omit tests.

| ID | Task | Status | Acceptance / checks |
| --- | --- | --- | --- |
| GS4-12 | Add minimal scoped Engram policy authority | Verified (mock) | Existing resolvers/atomic publication; four scoped tests cover exact/current selector, rollback, unrelated bytes/mode, symlink and out-of-scope rejection |
| GS4-13 | Resolve official Engram 3.0.0 archives | Verified (bytes) | Anonymous authoritative scoped transaction; both downloaded architecture hashes and safe archive layouts match; no downloaded binary execution |
| GS4-14 | Pin official runtime adapter 0.2.0 and safe recovery | Verified (local) | Immutable runtime byte match, manifest/image pins aligned; four Node dispatch/schema checks and scratch adapter-only backup/reseed preserve custom bytes/preferences |
| GS4-15 | Audit compatibility and verify coordinated bytes | Verified (bounded) | Focused 105/105 plus six installer fixtures, syntax/lint/repository checks pass; older OpenCode client gaps and actual storage/runtime proof remain explicit |

Constraints: no actual installation or replacement of installed Engram/Pi, real
HOME writes, personal database reads/migration, credentials/authenticated sessions,
Docker/build/lifecycle, staging, publication or native review/authority changes.
No inventory-wide update or hand-authored generated locks. Keep postCreate
activation-gated pre-seed validation, unchanged generic seeder, readiness validation,
image-owned read-only pins and launcher without seeding; no Dockerfile config COPY.
Retain process HOME and existing Engram storage; no duplicate binary/database or
`pi-engram init`. Preserve missing-only preferences and fail closed on custom edits.

Resolution forecast: public metadata and two Linux archives, at most 300 MB
downloads and 1 GB temporary disk under `/tmp/opencode`, planned 10 minutes with
explicit outer timeout 600000 ms. Check public asset sizes before archive downloads;
stop if the budget is exceeded. Anonymous public access only, no ambient gh auth.
Rollback boundary: scoped updater branch/tests, Engram intent/three locks, adapter
runtime/provenance/pins, focused recovery/API tests and corresponding documentation;
do not remove or rewrite prior v4 work. Prior tests/loader proof do not prove new
bytes. Full suite, application tests and operational runtime proof remain excluded.

### Coordinated upgrade outcomes

Before the first source edit, GS4-12–15 were appended here and the complete document
was saved to `odd/add-gentle-shell-v4/tasks` (observation 2509, no truncation), then
read back from both file and memory. All five exact skill paths were read again.
The information gate was explicitly cleared for the minimal scoped authority;
no whole-inventory update was executed. This is an uncommitted cohesive work unit.
The unchanged official adapter diff exceeds the 400-line advisory; no source,
tests or explanation were minified to fit it.

`--update-engram [exact-version]` reuses the existing release/hash discovery and
atomic publisher. The optional version changes editable Engram intent inside the
same transaction as its three locks; no manual policy mutation was needed. Without
a version it uses the existing selector and existing baseline rules. A dedicated
scope check compares all unrelated bytes, including comments; publication preserves
mode. Fixture failures retain original intent/locks/mode, and symlink policies,
bad arguments, incomplete/unstable releases and out-of-scope changes are rejected.

Pre-download public release metadata reported Linux amd64 7,738,070 bytes and
arm64 7,101,554 bytes (14,839,624 total), below the recorded 300 MB budget. Scoped
resolution and downloads each used outer timeout 600000 ms and scratch/cache under
`/tmp/opencode/gs4-engram3`; no gh credential lookup or ambient token was used.
Observed retained scratch after safe extraction: 55,610,592 bytes, below 1 GB.
No timeout occurred. Updater transient candidates were removed by its normal trap;
public verification archives/source/cache remain in that bounded scratch scope.

Generated and independently byte-verified archive SHA-256:

- amd64: `22bbfd81ee9071a04d446f653842c383a3101b594e8829519a63a7c747602e69`
- arm64: `69c717dfbf10733af0493c706954f40e37cf6545687c2c1903e4b1462c16cdad`

Official annotated v3.0.0 tag object
`fcf2eb5b6fe445c19a2e5568612a0a421f0fd5e1` resolves to immutable commit
`15a2f78885d7ad8ced23b2d1d88383e9bb472c17`; its `plugin/pi/package.json`
reports 0.2.0. All four runtime files/root license match immutable raw bytes;
only index.ts changed from the old adapter. Its SHA-256 is
`387555a903d64f2d4c9145499bd34d3f5c616f310e0bc89f49c23e2f2189880f`.
The unsigned tag and same-publisher hashes do not establish independent attestation.

The adapter now sends required `expected_project`, uses acknowledged resume and
capability-checked satellite registration, and removes cloned-manifest startup
import. Its upstream server launch opts into autosync according to existing cloud
configuration; no configuration/credentials were seeded. Existing adapter bytes
remain fail-closed, never silently replaced. The guide documents explicit
adapter-only review/backup/move outside extension discovery followed by normal
postCreate reseeding; scratch fixtures retain custom adapter bytes and preserve
preferences. No database, sign-in, session or personal configuration is moved.

Compatibility audit: seeded OpenCode JSON commands use `engram mcp --tools=agent`
and obtain tool schemas from the installed binary after restart. The repository
OpenCode event plugin has no HTTP observation PATCH/DELETE path, but still lacks
upstream 2.x dual-major entry, resume and strict acknowledgement handling and retains
manifest auto-import. It was not edited/executed; global/personal clients were not
inspected or repaired. The official tagged filesystem policy rejects known Linux
NFS/SMB/CIFS before storage mutation, but permits unknown types/detection failures;
neither a bind mount nor those accepted cases certify SQLite safety. Existing
storage/mounts remain unchanged, with no personal database contents read/migration.

Observed commands and results (exit 0 unless stated):

```bash
env -u GH_TOKEN -u GITHUB_TOKEN -u TOOLS_UPDATE_USE_GH_AUTH TMPDIR=/tmp/opencode/gs4-engram3 DEPS_UPDATE_GITHUB_API_CACHE_DIR=/tmp/opencode/gs4-engram3/github-api task tools:update -- --update-engram 3.0.0
shfmt -w .taskfiles/scripts/tools-update.sh .devcontainer/test/unit/tools-update.bats .devcontainer/test/unit/gentle-shell.bats .devcontainer/test/unit/direct-archive-installers.bats
env -u GH_TOKEN -u GITHUB_TOKEN -u TOOLS_UPDATE_USE_GH_AUTH bats .devcontainer/test/unit/gentle-shell.bats .devcontainer/test/unit/gentle-shell-state.bats .devcontainer/test/unit/tools-update.bats .devcontainer/test/unit/tool-policy.bats .devcontainer/test/unit/install-dependencies.bats .devcontainer/test/unit/install-selection.bats .maintainer/test/unit/guide-links.bats
bats --filter 'Engram' .devcontainer/test/unit/direct-archive-installers.bats
node --test .devcontainer/test/unit/gentle-shell-adapter-test.mjs
bash -n .taskfiles/scripts/tools-update.sh .devcontainer/setup.sh .devcontainer/install/available/3010-ai-engram.sh .devcontainer/install/available/3040-ai-gentle-shell.sh .devcontainer/test/unit/gentle-shell-fixture.bash
shellcheck .taskfiles/scripts/tools-update.sh .devcontainer/setup.sh .devcontainer/install/available/3010-ai-engram.sh .devcontainer/install/available/3040-ai-gentle-shell.sh
node --check .devcontainer/install/lib/gentle-shell-provision.mjs
node --check .devcontainer/install/lib/gentle-shell-launcher.mjs
node --check .devcontainer/install/lib/gentle-shell-bundle.mjs
node --check .devcontainer/test/unit/gentle-shell-adapter-test.mjs
task install:list
task install:doctor
task install:volumes
task validate
git diff --check
markdownlint-cli2 odd/tasks/add-gentle-shell-v4.md .devcontainer/docs/gentle-shell.md .devcontainer/config/gentle-shell/agent/extensions/engram/PROVENANCE.md
```

Focused Bats: 105/105. Engram installer fixtures: 6/6 with synthetic binaries only.
Node adapter checks: 4/4, parsing complete 0.2.0 TypeScript and executing extracted
real schema/dispatch with injected transport; no initializer or loader session.
Node emits its expected experimental stripTypeScriptTypes warning. All three
adapter JS files also pass `node --check`; `sha256sum --check SHA256SUMS` reports
all five files OK. Actual downloaded archives pass the existing Engram archive
validator, extracting only the root binary to scratch without execution. Repository
validation reports zero errors/warnings; explicit Markdown lint reports zero issues.
Installed diagnosis still reports Engram 2.2.1, proving no current binary replacement
was performed. Volume output remains the existing snapshot, not storage safety proof.
Dockerfile diff and index remain empty. Formatting preceded final source checks.

Limits/next step: owner review of all coordinated bytes; separately authorize real
upgrade/backups/storage classification/process restart and end-to-end memory proof.
Full starter suite, application test (known unconfigured exit 2), installed adapter
loader/session, Docker/build/bind/recreation and cross-architecture binary execution
were not run. Native review target/lineage and pending START consent were untouched;
the parent must preflight the changed candidate before any future native review.

Final public transport revalidation (exit 0, outer timeout 600000 ms) used a scratch
wrapper executing `curl -q` to suppress implicit personal curl configuration:

```bash
env -u GH_TOKEN -u GITHUB_TOKEN -u TOOLS_UPDATE_USE_GH_AUTH TMPDIR=/tmp/opencode/gs4-engram3 DEPS_UPDATE_CURL=/tmp/opencode/gs4-engram3/public-curl DEPS_UPDATE_GITHUB_API_CACHE_DIR=/tmp/opencode/gs4-engram3/github-api task tools:update -- --update-engram 3.0.0
```

It reported `No changes`. The first scoped transaction used the updater's existing
curl invocation; no claim is made about absence of implicit curl configuration on
that first call. No such configuration was inspected. All direct artifact/source
downloads explicitly used `curl -q`. This revalidation did not replace any installed
tool or alter policy bytes.

## Local completion authorization and evidence — 2026-10-02

The user now explicitly authorizes the local `test/gentle-shell-v4` branch,
local feature/evidence commits and a filtered `starter-rc-gentle-shell-v4`
candidate sourced from that branch against existing `starter`. This overrides
earlier no-commit restrictions for this completion phase only; historical
sections remain evidence of their original scope. No network, remote/auth,
Docker, installation, personal database/credential access, publication, PR,
promotion or native review restart is authorized in this phase.

| ID | Completion task | Status | Evidence / acceptance |
| --- | --- | --- | --- |
| GS4-16 | Record authorized isolated operational proof | Complete (bounded) | Run and limits below; memory 2551 |
| GS4-17 | Verify and commit coordinated local work unit | In progress | Test branch created from afdeff4565; focused checks and commit identity pending |
| GS4-18 | Prepare a new filtered local RC | Planned | Clean committed source, new custom target, protected refs unchanged; identity pending |

### Accepted isolated operational proof

Memory 2551 records the authorized scratch run
`0f20d4c4-2430-41ff-890b-801b35878159`, completed in **3m44.288s**.
Observed versions were Shell 4.0.0, Pi 0.99.2 and Engram 3.0.0. The actual Pi
compiled extension loader loaded **22 tools**. Synthetic UI/session inputs
used the real Engram HTTP transport/server and a synthetic database: save,
search, update, read and delete passed; PATCH/DELETE owner-negative cases
returned 400, 409 and 404. Recreation changed container identity while
preserving Shell settings/session-sentinel hashes and a synthetic Engram
observation. Cloud autosync was disabled and no personal data was used.

Verified owned-resource cleanup removed the run's containers, network, images
and scratch; retained shared cache is not complete disk removal. Full primary
preservation hashing passed, with primary dev/HEAD/index unchanged. The
scratch-only Buildx hook granted read access to the exact generated Dockerfile;
this successful narrowly entitled retry is **not a fix for the primary Bake
gap**. Interactive provider/LLM and bundled CLI flows remain unproved. No
operational rerun occurs during local commit preparation.

### Commit boundary and review authority

The accepted smallest honest behavioral unit keeps installation, composite
policy, guarded launch, provisioning, pinned Engram 3 adapter, persistence,
tests and documentation together. Pre-evidence-update scope was 34 paths and
4,583 changed lines: 2,042 authored and 2,541 unchanged vendored runtime/license
lines. A future PR needs an explicit size exception or a separately agreed
review strategy; no artificial splitting, minification or test deletion is
used. A small follow-up evidence commit may record the observed feature commit
identity without inventing a self-referential future hash.

The prior 34-path/4,583-line native review candidate was refused for context
budget, then explicitly declined by the user. Native review is **skipped, not
PASS**; no review approval or delivery authority is claimed. Global RDD remains
enabled; consent for these local commits while candidate scope is disabled
does not approve that candidate. Informational review is not delivery authority,
and unchanged bytes do not automatically reopen native review.

Rollback boundary: the coordinated Shell installer/helpers, baseline/adapter,
optional Compose override, setup branch, dependency registrations, Shell locks,
scoped Engram updater/locks, associated tests and guides; preserve unrelated
prior committed dev work. The filtered consumer RC also includes prior dev
changes since published source cfc8f0e, not only this feature. Keep existing
`starter`, `dev` and stale `starter-rc` unchanged; do not use `--base-absent`.

### Current verification and identities

Ordinary focused functional checks apply; TDD is still unknown/unconfigured.
Required foreground checks are the seven focused Bats suites, Engram-only
direct-installer fixtures, Node adapter checks, `task validate`, explicit
task/guide/provenance Markdown lint and `git diff --check`. Results and the
observed feature commit identity are pending and will be recorded after actual
execution. Feature commit message:
`feat(tools): add isolated Gentle Shell v4 with Engram 3`.
Candidate generation is planned only after the source is clean and committed;
RC identities belong in separate handoff memory after source freeze.
