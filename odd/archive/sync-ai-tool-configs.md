# Sync selected AI tool configuration

The owner now authorizes local commits of all reviewed pending work, without RC
generation, promotion or publication. The configuration/native-startup work unit
includes its related evidence and documentation in source commit
`e8503f3c9f8faf4f8a5cacde059ea3444fb342ee`. No new native review PASS is claimed.
The latest native consent target
`feccfa5aa2d73e01398b756079d85d190b8636c98e2c2dcd412604db24d76dc6`
was explicitly declined; the current authorization is for local commits only.

The owner authorized implementation of config diff/export mapping and explicitly
approved Pi and Gentle Shell trust files and the Shell home marker. No second
approval question is required. This document records, rather than grants, authority.

## Status

| Task | Status | Outcome |
| --- | --- | --- |
| CFG-01 | Complete | Read-only baseline mapping and owner inventory |
| CFG-02 | Complete | Manifest, one seed call, existing export review hint |
| CFG-03 | Complete | Actual isolated commands and static checks; no live proof |
| CFG-04 | Closed local scope; full mirror saved | Documentation and preservation proof |

Mirror: pending. Previous save failed because session registration could not be
confirmed. One final full-content save/readback attempt is permitted; no invented
session identity, registration, or retry loop. The local file remains authoritative.
Mirror topic: `odd/sync-ai-tool-configs/tasks`, project: `gentle-starter`.
Final full-content save failed: `gentle-engram could not confirm Engram session
registration for engram_mem_save`. No observation ID/readback exists; no retry
or session registration was attempted. Local progress is not blocked.

## Authorization and preservation

- Single writer, no children. Allowed changes: manifest, exporter, minimum seed
  support, `.devcontainer/docs/configs.md`, and this same task document.
- No owner config or policy edits, normalization, restored deletions, new tool
  selectors, dependencies, wrappers, backups, or testing framework.
- No primary staging/commits/ref changes/publication, runtime HOME inspection or
  export, credentials/auth/database export, Bats, build, Docker, or npm resolution.
- Read-only unauthenticated pinned public source inspection is authorized solely
  for preference storage evidence. No operational network/build proof occurred.
- Disposable Git commits/staging under `/tmp/opencode` support real dirty-guard
  checks only; primary index and refs are untouched.

Before source writes, 84 protected config/policy paths were captured, including
bytes, modes, directories, deletions/untracked owner Git status and policy bytes.
The post-check matched exactly. Combined SHA-256:
`c4e74e1b674ddb9e23a58b5ae70027c36e370947c165cd39a5f554db33c4662c`.
Evidence: `/tmp/opencode/cfg-preserve.py` and `cfg-protected.json`.
Owner global Gentle AI 4 hashes were neither resolved nor rewritten.

## CFG-01 — Mapping evidence

Initial manifest lacked Shell, OpenCode example and Pi Gentle AI mappings, and
excluded Pi trust. Existing tasks already forward `CLI_ARGS`; they remain unchanged.
Initial branch: `test/gentle-shell-v4`; HEAD:
`7ad95d4c055e5dcdc9c17bc9e411eae784150215`. Owner changes predated this feature.
Prior host RC results are owner reports, not independent proof from this work.

## CFG-02 — Implementation

| Runtime root | Seed root under `.devcontainer/config/` | Selected files / gate |
| --- | --- | --- |
| `~/.config/opencode` | `opencode` | Added `opencode-example.json`; always participates |
| `~/.pi/agent` | `pi/agent` | Settings and approved trust; Pi 3030 enabled |
| `~/.gentle-shell` | `gentle-shell` | Config; agent settings, subagents, trust, marker; Shell 3040 enabled |
| `~/.pi/gentle-ai` | `pi/gentle-ai` | Models, persona, profiles JSON; Shell 3040 enabled |

Shell paths are exactly `config.json`, `agent/settings.json`,
`agent/subagents.json`, `agent/trust.json`, and `agent/.gentle-shell-home`.
Approved broad `/home/ubuntu` and Pi `/tmp` grants remain unchanged; marker
creation/version metadata is accepted. No blanket sensitive-file exemption exists.

Pinned Shell 4 source at `1f35ab1e4ff78f41ce6102cd961e7889a9f1cf69`,
`lib/agent-home.ts`, `lib/agent-profiles.ts`, and `extensions/gentle-ai.ts`
confirms the preference default and `GENTLE_PI_CONFIG_HOME` replacement-root API.
Local artifact cache was unavailable. A guessed `lib/config.ts` URL returned 404;
the pinned tree and actual APIs supplied evidence instead. Custom override roots
remain outside preset seeding/export scope. No native runtime execution is claimed.

Added one existing seed helper call inside Shell activation. No installer change.
Review hint now derives participating seed paths. Retired SDD command/prompt/skill
families, removed collaboration/review skill folders, shared SDD conventions and
the SDD result plugin are excluded. The latest owner manifest removes four former
exclusions: the old default-agent marker and non-SDD example are root candidates
only; the two old OpenAI profiles remain eligible under `profiles/**` if present
at runtime. Those owner choices were not reversed. Other recursive families remain
managed.

## CFG-03 — Executed proof

Command: `python3 -B /tmp/opencode/cfg-proof.py`. Final run passed eight reported
checks using the actual exporter, real Git and copied catalog/Dockerfile authority,
and the official selection planner in scratch only. All scratch runs were cleaned.
This historical proof and its independent follow-up preceded the owner's four
exclusion removals; they are not fresh proof that those four paths remain excluded.

- Inactive real owner gates skip Shell/preferences; activation resolves Pi/Node.
- Managed new/modified diffs, byte-exact export (whitespace included), approved
  trust/marker and all three preference files, relative paths and custom commands.
- Missing file/root preserves existing seed; no invented preference settings.
- Credentials/auth, sessions/history, database/cache/log inputs and retired
  OpenCode paths do not export.
- Dirty worktree and index refuse before runtime symlink inspection; original
  destination bytes remain unchanged. Managed symlink and unsafe seed parent
  fail with no outside writes.
- Actual scratch `task --exit-code config:diff -- --repo ... --home ...` returns
  expected 1; `task config:export` forwards the same flags and succeeds.
- Python AST parsing succeeds without production bytecode.

Two earlier fixture runs failed: missing Dockerfile core authority, then an
unsupported wildcard-prefix exclusion (`skills/sdd-*/**`). Copied real authority
and explicit retired skill folders corrected them; no functions were mocked.
`bash -n`, ShellCheck, install-tree inspection and `git diff --check` passed.
`markdownlint` executable was absent; use installed `markdownlint-cli2` instead.
`markdownlint-cli2 .devcontainer/docs/configs.md odd/tasks/sync-ai-tool-configs.md`
passed: 22 files scanned through repository configuration, zero issues.
Primary index is empty. No live HOME export, framework, Docker or build was run.
Raw copy, path guards and per-file atomic replacement remain unchanged; this is
not whole-batch rollback proof or a transaction guarantee.

## CFG-04 — Delivery and next steps

Config documentation describes exact roots, gates, trust portability, exclusions,
dirty refusal, missing-runtime preservation and per-file/nontransactional behavior.
Owner review and explicit local commit authorization are now complete. Real export
still refuses dirty participating seeds; do not bypass that guard or run an export
against personal HOME during commit preparation.
No additional Shell installer is needed for this request. Future RC generation
and publication, custom-root support and optional old-resource cleanup are separate
human decisions, not feature gates. Parent retains review-switch authority.

## Current local commit checks and rollback boundary

`python3 -B /tmp/opencode/local-commit-audit.py static`, `bash -n`, ShellCheck
and read-only `shfmt -d` on `.devcontainer/setup.sh` passed. The manifest parsed;
all four changed Python files passed AST parsing without bytecode. The Bats fixture
passed in-memory declaration-normalized Bash syntax only; no body or suite ran.
Read-only install-tree inspection found 39 installers, 15 aliases, no naming,
target or slot errors, and 35 intents/53 locks. Credential-marker inspection found
no suspected literal credential; commented `change-me` examples and environment
references are not credentials. The first scratch audit attempted strict JSON
parsing of producer JSONC and failed; correcting only that scratch assertion to
leave JSONC byte-protected allowed the audit to pass, with no source change.

Rollback unit: the selected AI configuration, manifest/export hint/seed call,
global Gentle AI 4 owner policy, optional Pi/Shell aliases, guarded host entry,
environment examples and their README/configuration evidence belong together.
Publication helper policy and producer Compose selection form the next unit.
No artificial split of upstream configuration deletions is used for a line budget;
these local units do not approve a future oversized PR.

Owner-data baseline covers 81 entries, including exact bytes/modes and deletions
for owner configs, manifest, policy, producer JSON and README. Snapshot SHA-256:
`7b33656eca79d8be749444fa25eb5cb8a3a905bdaba4d5297acb6a40839e8238`.
Whole-worktree `git diff --check` exits 2 solely on protected producer JSON line 49
trailing whitespace. That byte remains unchanged by explicit owner instruction;
other staged source must pass whitespace checking. Live runtime/TUI, installs,
builds, Docker, Bats, network and publication checks are intentionally not rerun.
This evidence is not native publication PASS. Memory mirror remains pending;
no Engram retry or invented identity is used.

## Local commit outcome

- `e8503f3c9f8faf4f8a5cacde059ea3444fb342ee` —
  `feat(ai): seed selected configurations and enable native Shell startup`.
  Git reports 88 files (89 literal paths with the detected example rename),
  1,205 additions and 7,805 deletions. The coordinated owner baseline and retired
  upstream files stay in one behavior unit; no oversized-PR approval is inferred.
- `f2f5ff643673ed1d1ea6f24db4c33ac7d6d613b4` —
  `feat(distribution): version the four-entry Compose publication policy`.
  Nine files, 545 additions and 71 deletions; publication implementation only.

Both normal commits succeeded using existing Git identity; no active hooks were
configured and none were bypassed. Source-unit one staged whitespace check exited
0; unit two exited 2 solely on the preserved producer JSON line 49 warning, and
its check excluding that path exited 0. Markdown lint selected 24 files with zero
issues. The complete deletion audit verified all 56 deleted blobs against HEAD,
including 7,159 removed lines. Its first scratch assertions mishandled Markdown
`---` lines and no-final-newline blobs; correcting only the scratch parser passed.
After both source commits, all 81 owner-data entries matched the snapshot above,
all non-source refs matched, and the worktree/index were clean. This final
evidence-only document update records actual source IDs, not its own future ID.
No RC/publication, remote operation or new runtime proof was performed.

## Parent reconciliation and archive disposition

The parent reconciled and marked the authorized local configuration/export scope
complete on 2026-10-06. Archive locator: `odd/archive/sync-ai-tool-configs.md`.
Source `e8503f3` is a verified ancestor of HEAD `45fd4e4`.
The owner's four removed exclusions remain authoritative; earlier proof predates
them. All bounded-proof, per-file atomicity and preservation limitations above
remain intact. Latest native consent was declined, not PASS. No personal HOME,
RC, publication or new runtime verification is claimed or required for this scope.
Historical mirror failures above remain historical. Successful full-content save
recovered observation `2970` under `odd/sync-ai-tool-configs/tasks`; final body
readback evidence belongs in the closure task and handoff. No session identity was
invented or registered. A03 and final closure remain parent-owned.
