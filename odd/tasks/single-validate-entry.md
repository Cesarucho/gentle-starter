# Single public validation entry

## Objective
Expose one context-aware `task validate` entry point without conflating a host preflight with complete in-container environment and strict repository-quality checks.

## Problem and scope
- Today `doctor` diagnoses detected host/container context; `validate` adds optional quality checks and `validate:full` requires all quality tools. The names expose multiple guarantees to consumers.
- Authorized: simplify Task routing, internal helper visibility, host guidance, related tests and docs. Keep actual application tests and operational Docker lifecycle separate.
- Preserve the user's pending `.env.example` edits byte-for-byte and leave them outside work-unit commits. No remote work, Docker builds or lifecycle checks.
- Route: delegated direct; implementation and tests/docs span multiple nontrivial files. TDD for ODD unknown (SDD cache does not set this mode); Bats focused runner `.devcontainer/test/unit/doctor.bats` plus Task-facing fixtures.
- Delivery: ask-on-risk, ~400 authored lines per task advisory only; forecast small-to-medium, review cumulative diff before commit.

## Acceptance contract
- `task validate` detects host/container using existing doctor auto-detection and `FORCE_HOST_CONTEXT` testing override.
- Host: required prerequisites and snapshot diagnostics; always explain full environment inspection and strict quality run inside container, without implying host success is complete proof.
- Container: environment diagnosis plus strict ShellCheck, shfmt and markdownlint checks; missing tools fail, not skip.
- Hide legacy doctor/quality helper tasks and `validate:full` from the public Task surface without breaking internal invocation. Remove or migrate documented direct calls and test contracts. Application tests and Docker remain independent.

## Tasks
- [x] SV-1: Implement one public context-dispatched validation path with host notice and strict container quality; preserve exact context semantics. Verify focused host/container Task routing and existing doctor fixtures.
- [x] SV-2: Hide obsolete public helpers, update docs/help and focused tests for one public validation entry. Verify Task list, focused suites, `task validate` in current container, and maintainer suite where safe; record limitations of physical-host coverage.

## Progress
- 2026-09-27: Mapped current graph and created branch `refactor/single-validate-entry` from local dev `e275b66` while preserving the user's `.env.example` edit. No source edits yet.
- 2026-09-27: Integrated seven required host prerequisite checks from earlier local work (without its separate task record), so host preflight does not regress. Focused doctor Bats passed 12/12; forced-host `task validate` from inside the container showed partial guidance and 0 errors; actual container `task validate` ran strict quality and passed. `task --list` excludes doctor/quality helpers and `validate:full`. Maintainer suite passed 449 unit and 18 integration, with 16 integration skips. Scoped `git diff --check` passed; global check remains affected by the user's unrelated trailing whitespace in `.env.example`. Physical-host run not performed. Runtime Docker harness: N/A; this change only routes diagnosis and static quality. Rollback boundary: Task routing, doctor script, focused tests and directly affected docs/help; `.env.example` excluded.
- 2026-09-27: Work-unit commit `74d2109` (`refactor(validate): expose one context-aware check`) includes all routed checks, tests, docs and prior seven-host-prerequisite coverage. Native committed-only assessment was high; the user granted four-lens review. Lineage `review-fe8bf1fb8a821a33` approved without blockers and was exactly acknowledged/burned. One nonblocking documentation observation found obsolete warning-level CLI wording; follow-up corrects this without changing the acknowledged candidate. No push or PR.
- Next: commit the documentation clarification and record; `.env.example` remains untouched. Physical-host validation remains unverified in this container session.
