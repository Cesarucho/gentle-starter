# Connect message severity

## Objective and scope

Label connect welcome diagnostics with `[info]` or `[warn]` and explicitly
identify an unavailable `ssh-keygen` command before querying host trust.
The reported missing command currently appears as a generic lookup failure.
Expose `WELCOME_LOG_LEVEL` with `info` (default), `warn`, and `off` to filter
only this welcome. Invalid values warn and fall back to `info`; empty is invalid.

Authorized source paths:

- `.taskfiles/scripts/container-connect.bash`
- `.devcontainer/test/unit/container-connect-test.py`
- `.env.example`
- `.devcontainer/docs/optional-integrations.md`

Do not install or activate tools, access a real agent, contact GitHub, modify
consumer trust files, or change global configuration. Preserve the owner's
untracked `.devcontainer/install/03-enabled/4000-tool-ssh-client.sh` alias.
Leave changes unstaged and uncommitted until explicit owner approval.

## Work unit

Forecast: under 250 authored changed lines; delivery strategy: `ask-on-risk`.
Route: delegated direct; preparation and two non-trivial files require a writer.
Test-first applies because deterministic PTY behavior tests exist; no separate
strict TDD configuration has been verified.

- [x] T01: Add deterministic prefix and missing-command regression assertions;
  observe RED, implement labels and capability guard, then observe GREEN.
- [x] T02: Verify preserved safety behavior, run focused quality checks, and
  reconcile native review or explicitly accepted unavailable proof.
- [x] T03: Implement and document `WELCOME_LOG_LEVEL` with observed RED/GREEN
  and deterministic unset, info, warn, off, invalid, empty, and non-TTY cases.

## Acceptance and verification

- Informational prose uses `[info]`; unavailable checks and trust warnings use
  `[warn]`. Supporting command and URL lines remain copyable.
- Missing `ssh-keygen` produces an explicit warning without blocking the shell.
- No agent queries, network operations, automatic installs, or trust mutations.
- Existing hashed/plain records, revocation, conflicts, and TTY gates remain.
- Filter only welcome output; preserve bashrc and nested-shell output. Warning
  guidance remains visible at `warn`. `off` produces no welcome diagnostics.
- Document root `.env` delivery at container creation; HOST recreation applies
  changes, but no recreate/build is authorized by this implementation request.
- Run `bats .devcontainer/test/unit/container-connect.bats`, `bash -n` on the
  rcfile, focused ShellCheck, check-only shfmt, and `git diff --check`.
- Source-mutating normalization must precede final checks and review freeze.

## Progress and evidence

Planning complete. Current branch: `test/gentle-shell-v4`.
Bounded implementation complete in the CONTAINER host-mounted checkout.
The earlier commit request is paused for the newly authorized variable scope;
T02 remains pending parent review reconciliation.

- RED: `env PYTHONDONTWRITEBYTECODE=1 python3
  .devcontainer/test/unit/container-connect-test.py` exited 1 at the new
  missing-command warning assertion before source implementation.
- GREEN: the same command exited 0 after implementation. Hermetic severity,
  missing-command, file-validity, mixed-algorithm, duplicate, conflict,
  revocation, lookup-failure and forbidden-call assertions passed.
- `bats .devcontainer/test/unit/container-connect.bats`: exited 0, 1/1 passed.
- `bash -n .taskfiles/scripts/container-connect.bash`,
  `shellcheck .taskfiles/scripts/container-connect.bash`,
  `shfmt -d .taskfiles/scripts/container-connect.bash`, and
  `git diff --check`: exited 0. Source already matches shfmt normalization.
- Real plain/hashed OpenSSH parser proof explicitly skipped because
  `/usr/bin/ssh-keygen` is absent. Fake lookup fixtures prove diagnostic
  branches only; they are not real-parser evidence. Overall proof is partial.
- `markdownlint-cli2 odd/tasks/connect-message-severity.md`: exited 0;
  repository configuration expanded the check to 22 Markdown files, no issues.
- The untracked SSH-client alias retained Git blob hash
  `c7e5a7f25ff14c7b4600b79b9605963940329437` before and after verification.
- Skills resolved from repository files: `clean-code` and
  `markdown-documentation`. No native START/review actors were invoked.

### T03 implementation evidence

- CONTAINER execution in the host-mounted checkout; no staging, commits, pushes,
  builds, recreation, installs, network, real-agent access, consumer trust access,
  native review actors, or subdelegation.
- RED: `env PYTHONDONTWRITEBYTECODE=1 python3
  .devcontainer/test/unit/container-connect-test.py` exited 1 at the new
  `warn` assertion (`[info]` still present), before welcome source edits.
- GREEN: the same command exited 0 after implementation and again after
  `shfmt -w .taskfiles/scripts/container-connect.bash` normalization.
  No further structural refactor was needed: three local informational guards
  keep the filter minimal, without adding a logger abstraction.
- Deterministic tests sanitize inherited `WELCOME_LOG_LEVEL` and prove unset,
  explicit `info`, `warn` with warning command/URL guidance, `off` with preserved
  bashrc/nested-shell output and no manifest checks, invalid/empty fallback,
  case/whitespace rejection, and silent non-TTY invalid values. Existing
  missing-command, socket, conflict, revocation and forbidden-call guards pass.
- Current real-parser proof ran and passed, including 10 plain/hashed algorithm,
  duplicate, conflict and revocation cases. `/usr/bin/ssh-keygen` is present in
  this execution environment; the earlier recorded SKIP remains historical.
  No tool was installed. The absence-based SKIP branch remains intact.
- `bats .devcontainer/test/unit/container-connect.bats`: exited 0, 1/1 passed.
- `bash -n .taskfiles/scripts/container-connect.bash`,
  `shellcheck .taskfiles/scripts/container-connect.bash`,
  `shfmt -d .taskfiles/scripts/container-connect.bash`, and
  `git diff --check`: exited 0 after normalization.
- `markdownlint-cli2 .env.example .devcontainer/docs/optional-integrations.md
  odd/tasks/connect-message-severity.md` exited 1: dotenv comments were parsed
  as Markdown headings. Appropriate Markdown-only retry,
  `markdownlint-cli2 .devcontainer/docs/optional-integrations.md
  odd/tasks/connect-message-severity.md`, exited 0 (22 files, no issues).
- `.env.example` has a separate welcome section; optional-integrations documents
  exact values, unset default, invalid fallback, welcome-only filtering, and
  HOST root-checkout `task container:recreate` runtime delivery without rebuild.
  This recipe is documentation, not execution authorization; personal `.env`
  was neither read nor edited, and Compose was not edited.
- SSH alias blob hash remains `c7e5a7f25ff14c7b4600b79b9605963940329437`;
  its symlink mode remains 0777. Tracked file modes have no diff.
- `skill_resolution`: repository `clean-code` and `markdown-documentation`
  loaded before edits; global `cognitive-doc-design` loaded for guide editing.

Next step: parent reconciliation of T02 and native review authority.
The writer does not close or archive this record.

## Final parent-reconciled disposition

COMPLETE for the bounded welcome diagnostics and `WELCOME_LOG_LEVEL` scope.
Repository locator: `odd/archive/connect-message-severity.md`.

- The parent reconciled T02 against the documented T03 evidence: 10 real
  plain/hashed parser cases passed, superseding the earlier historical SKIP;
  Bats passed 1/1 and the recorded focused quality checks passed.
- Delivery commit `635dc72` is an ancestor of current HEAD `45fd4e4` on `dev`;
  the scoped implementation remains delivered unchanged. Earlier pending-status
  and next-step prose above is preserved as historical evidence.
- Native review is disabled/unmanaged with RDD off clone-local. This is an
  explicit parent reconciliation, not a native review PASS or approval receipt.
- Closure claims no live SSH, agent, recreation, build, release, or publication
  proof. No behavior tests were rerun for this document-only archive operation.
