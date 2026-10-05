# Show manual skill workaround after selected installs

Display the user's exact three commands after confirmed `task skills:suggest`
installation attempts. This temporary, user-requested workaround is manual;
the user monitors the patch. Do not infer a cause or an upstream issue.

## Scope and recovery

- One local work unit: selector output, focused mocked and distribution tests,
  and optional-skills guide. Roll back only those additions and this task document.
- Preserve every pre-existing owner, SSH onboarding, and release-doc change,
  including frontend-design, skills-lock.json, and tool-versions.conf bytes.
- Normal installs retain `--agent universal --copy -y`. The user's manual
  commands retain their explicit `-a opencode -y` flags without substitution.
- No staging, commits, push, review, installs, network, builds, Docker, or delegates.
  Distribution tests use disposable local Git fixture commits only.
- TDD mode is not established by configuration; no RED/TDD claim.
- Runtime proof: mocked Skills CLI only; real installation is not authorized.

## Tasks and checks

- [x] M01 Inspect selector control flow, guides, tests, and release filtering.
- [x] M02 Show the block only after actual confirmed attempts, including partial
  failure; preserve nonzero failure status and no output on early exits.
- [x] M03 Prove exact displayed commands, no extra CLI calls, selection behavior,
  and universal normal installs with local mocks.
- [x] M04 Normalize, run requested checks, and verify preserved owner bytes.

Required checks:

- `bats .devcontainer/test/unit/skills-suggest.bats`
- `bats .maintainer/test/unit/starter-distribution.bats`
- `shfmt -d .taskfiles/scripts/skills-suggest.sh`
- `shellcheck .taskfiles/scripts/skills-suggest.sh`
- `markdownlint-cli2 --no-globs .devcontainer/docs/optional-skills.md odd/tasks/skills-manual-workaround.md`
- `git diff --check`

## Evidence and locator

Repository: `/home/ubuntu/gentle-starter`.
Document: `odd/tasks/skills-manual-workaround.md`.
Engram full-document mirror: `odd/skills-manual-workaround/tasks`.

## Local verification

Formatting was checked before functional verification with
`shfmt -d .taskfiles/scripts/skills-suggest.sh .devcontainer/test/unit/skills-suggest.bats`:
already normalized, no edits needed.

- Selector Bats: PASS, 10/10 tests; exact manual command block, universal installs,
  no extra CLI calls, partial/sole failure exit 1, and early-exit silence.
- Distribution Bats: PASS, 25/25 tests; added exact-byte published selector,
  catalog helper, and guide preservation fixture. No actual release generated.
- Required selector shfmt and ShellCheck: PASS.
- Required two-file Markdown lint: PASS, zero issues.
- `git diff --check`: PASS.
- Version policy: `bash -n` and the existing restricted
  `devcontainer_load_tool_versions` parser PASS; no updater invoked.
- SHA-256 matched all 18 pre-existing modified/untracked files before and after.
  Index remained empty; HEAD remained `b64b5fe2a4cc89aab4ee2f8720710f9cc596e2d5`.
- Authored implementation/tests/guide: 94 additions + 2 deletions = 96 lines,
  plus this task document. Owner changes are excluded from this work-unit count.

Limitations: real installs, upstream compatibility, SSH runtime, and a real release
are unverified. The preserved version policy comments still say `deps:update`,
while Task exposes `tools:update`; this pre-existing naming drift is not repaired.
No cause, upstream issue, automatic execution, TDD, or review verdict is claimed.

Skill resolution: loaded repository `add-tool` and `markdown-documentation`, plus
`cognitive-doc-design` and `work-unit-commits`. Classified as manual skill guidance,
not managed installer/provider/state work. No install group or lock change needed;
explicit no-commit authorization overrides the work-unit skill's commit default.
