# Optional Gentle Shell v4: native npm integration

## Current intent and authorization

The owner now authorizes local behavioral/evidence commits on
`test/gentle-shell-v4` and native guarded refresh of `starter-rc-gentle-shell-v4`
against `starter`. No publication, remote/auth access, Docker, build, installation,
network, updater execution, Bats, mocks or suites are authorized in this phase.
Preserve all existing executable and owner configuration bytes and modes.

Shell 4 installs the exact SRI-verified npm tarball globally with native lifecycle
scripts and executable. Activation requires standard Pi and core Node/npm, not
Engram. Core Engram 3 remains independent. Native first launch sets up Shell's own
agent automatically, without `--link` or a separate user setup command.

The owner baseline contains Shell `.gitkeep` and `gentle-tmp/.gitkeep` only; these
are intentionally copied. Preserve the owner's actual Pi model/provider settings.
The repository does not seed a Shell theme or fullscreen preference. Native setup
owns generated settings/theme and companions, which are not independently pinned.
Compose selection remains separate from installer activation.

## Stable tasks and current acceptance

| ID | Task | Status | Acceptance |
| --- | --- | --- | --- |
| GS4-17 | Record current authorization | Verified | Same task document and full memory mirror read back before other artifact edits |
| GS4-18 | Native installation and policy discovery | Verified operationally | Shell 4 SRI, native npm scripts, ubuntu execution and standard Pi 1 observed |
| GS4-19 | Remove bespoke integration and baselines | Verified | Bespoke integration removed; owner placeholders retained; seed hook and Compose retained |
| GS4-20 | Verify current bytes | Operational and documentation proof complete | Final Pi 1 proof below; lint/static checks passed; no current Bats claim |
| GS4-21 | Delete migration and fixture residues | Prior bounded proof | Earlier cleanup retained; no new fixture or framework |
| GS4-22 | Defer versioned configuration until user discovery | Verified operationally | Owner Pi settings, placeholders and native preferences survive recreation |

## Verification and pending work

Final registered run `7b442143-4d8d-4af5-8589-bd1064f69c91` passed in
3m18.109s (build 142.838s, start 7.132s, setup 25.082s, recreate 8.917s).
Managed `/usr/bin/pi` and native Shell's selected Pi were both 1.0.0; Shell and
private Gentle AI were 4.0.0. Real npm 11.19.1 postinstall exited zero; exact
tarball SRI and ubuntu executable mode 0755 were verified.

Normal `gentle-shell -- --version` triggered successful native auto-setup with
correct Shell home and provisioning records 4.0/4.0. Observed companions were
gentle-engram 0.2, pi web 0.35 and pi btw 0.7.1, not repository locks. Core Engram
reported version 3; no `~/go/bin/engram` existed before or after recreation despite
the upstream log. Adjacent Pi 1 versions are observations, not global lock
enforcement or a shared-binary guarantee.

Recreation replaced container `d75e37857131` with `170ec0fdb052`, preserving native
preferences, provisioning records, a synthetic session sentinel, both placeholders
and owner Pi configuration. Standard Pi had no Gentle plugins; its existing files,
hashes, symlinks, modes and ownership were preserved. Two empty upstream cache
directories were allowed, not plugins. Shared native `.gentle` state, backups and
telemetry do not establish global-home isolation. Synthetic data only: no LLM,
provider interaction or interactive Engram API proof.

The registered inventory reports exit zero and removed owned resources. Prepared
source (21 MB) and private inventory remain; shared cache (28.74 GB), older stopped
runs and DinD volumes were retained. The operational actor reported zero running
containers. A scratch-only Dockerfile `fs.read` permission adjustment does not fix
the primary Bake gap. No primary configuration mutation is claimed.

Earlier scoped `task tools:update -- --update-pi 1.0.0` published only Pi intent
and lock, both 1.0.0; repeat execution reported no changes. This Pi-specific
argument is not a generic updater interface: a generic tool selector is deferred.
Neither it nor the Shell package SRI pins Shell's internal dependency tree.

Earlier 93/93 Bats and other bounded checks remain historical evidence only,
not verification of the latest dependency changes. Current Markdown lint passed
(22 files selected by existing CLI configuration), as did read-only `shfmt -d`,
`git diff --check` and empty-index checks. Only the existing Shell dependency case
title, Pi alias assertion and selected-alias count were corrected; no test ran.
The protected config/install/setup/policy/updater/selection snapshot matches before
and after (`b61b7eb320e0bf50b59c2ca1eb4c7de2bdc5810c7744f9ffe908af5a61eddedc`).
Local commits and RC refresh are authorized. The current native candidate
`71421e` (34 paths, 4,823 changed lines) was explicitly declined: review is
**skipped, not PASS**. Global RDD remains unchanged; local commit consent is not
native approval. Do not restart review solely for unchanged executable content.

## Local commit and candidate boundary

Keep native installation, bespoke integration removal, Pi 1 policy/scoped updater,
owner-approved configuration, static test references and docs in one coherent
behavioral work unit. Rollback of that commit restores the preceding implementation;
no rollback is executed. The deletion-heavy scope is not artificially split.
Feature commit identity is pending actual commit execution, never invented.
A small evidence-only commit may then record that observed identity.

Pre-commit boundary is `ab7eb3a83335afaa0585a41a756e50dc51d261d0`.
Only the recognized RC `26b4f609c6b015de9acfcfa30de38ad08a018bb7` may advance
through native candidate guards; base is
`ef2f71e5255fb47a1389667a4b1a3e428e4dac5d`. Keep `dev`, `starter` and old
`starter-rc` unchanged. Stop on stale identity/base/source guards; no force,
cancel, reset, promotion or publication. RC outcome belongs in handoff memory
after the committed source freezes. Historical details remain in Engram 2509.
