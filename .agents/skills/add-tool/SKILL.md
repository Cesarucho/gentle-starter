---
name: add-tool
description: "Trigger: add or replace managed dev tool, change tool provider, activation, provisioning, or state lifecycle. Route and verify repository tooling changes."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract

Use for managed-tool additions/replacements, provider/mechanism, default activation, runtime provisioning, and state lifecycle. Exclude app dependencies, personal hooks, config-seed-only, ordinary enable/disable, and mechanical version/digest bumps unless trust/provider/architecture/lifecycle/updater semantics change.

## Hard Rules

- Treat current files and closest installers/tests as authoritative.
- Follow architecture: groups/COPY, naming/order, locked closure, state separation, host preparation/applied identity, independent Compose; IDEs attach only.
- Classify provider/intent; only `tools:update` resolves versions/integrity or mutates policy. No installer defaults/build discovery.
- Route exact runtime directory modes/creation to `.devcontainer/config/runtime-directory-permissions.json`; never duplicate installer mkdir/chmod or repair bind-root ownership.
- For each added or changed tool, check its executable directory against `CONTAINER_BASE_PATH` in `.env.example`; update only when necessary, preserving directory order without duplicates and managed OpenCode PATH priority.
- Fail closed on architecture; verify all supported architectures before direct publication. Require explicit approval to weaken trust/lifecycle controls.

## Decision Gates

| Change class | Route |
| --- | --- |
| New tool | Closest provider/tests |
| Mechanical bump | Existing checks; no invented RED |
| Enable/disable | Helper; verify alias/target/order; stop |
| Provider/mechanism/lifecycle | Characterize; focused RED/GREEN |
| Removal | Trace every surface before deletion |
| Config/state | Seeding/lifecycle; no default installer |
| Runtime directory | Policy create/skip; separate root/ownership/file/security owners |
| App/personal | Stop; package manager/hook |

## Execution Steps

1. Classify/reroute; run `scripts/inspect-install-tree.sh [repository]`.
2. Load applicable references; reuse real implementations.
3. Apply provider/updater, trust/rollback, state and verification contracts. Check runtime full applicable preflight, bound-root mapping, activation and creation-only ordering before tool use.
4. Ship code/tests/docs together; refresh registry officially only for metadata changes.

## Output Contract

Return classification/files/validation/risks; relevant trust/architecture/state/updater, RED/GREEN, host-preparation/review-burden evidence. No retroactive RED. Runtime: rule/applicability/mapping/ordering/preservation evidence.

## References

- `references/architecture.md`
- `references/decision-matrix.md`
- `references/supply-chain.md`
- `references/verification.md`
- `references/runtime-directories.md`
