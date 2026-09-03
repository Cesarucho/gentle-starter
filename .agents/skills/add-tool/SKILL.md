---
name: add-tool
description: "Trigger: add or replace managed dev tool, change tool provider, activation, provisioning, or state lifecycle. Route and verify repository tooling changes."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract

Use for repository-managed dev-tool additions/replacements, provider or mechanism changes, default activation, runtime provisioning, and persistent-state lifecycle integration. Exclude application dependencies, personal hooks, config-seed-only work, ordinary enable/disable, and mechanical version/digest bumps unless trust, provider, architecture, lifecycle, or updater semantics change.

## Hard Rules

- Run `scripts/inspect-install-tree.sh [repository]`; treat current files and closest real installer/tests as authoritative.
- Keep installation, copy-on-first-run configuration, and mutable state separate. Classify state as none, passive, or installer-owned.
- Preserve fail-closed architecture gates and host-prepared long-syntax binds with `create_host_path: false`; never repair bind-root ownership at runtime.
- Obtain explicit approval before weakening trust or lifecycle controls.

## Decision Gates

| Change class | Route |
| --- | --- |
| New tool | Inspect architecture; choose closest provider pattern and tests |
| Mechanical version/digest | Use existing policy/updater/installer checks; do not invent RED |
| Enable/disable only | Use install helper; validate alias, target, and order; stop |
| Provider/mechanism/lifecycle | Characterize current behavior, then focused RED/GREEN |
| Removal | Trace activation, policy, state, updater, tests, and docs before deletion |
| Config/state only | Route to config seeding or state lifecycle; no installer by default |
| App/personal dependency | Stop; use application package manager or personal hook |

## Execution Steps

1. Classify the change first; stop or reroute excluded work.
2. Inspect the tree, then load only the relevant references.
3. Select the closest real provider example and test; do not duplicate an implementation.
4. Apply proportional trust, rollback, state, architecture, updater, and verification controls.
5. Refresh the registry through its official mechanism only when metadata changed.

## Output Contract

Always return classification, changed files, validation, and residual risks. Include trust, architecture, state, updater, RED/GREEN, host-preparation, or review-burden evidence only when relevant. Never report RED retroactively.

## References

- `references/architecture.md`
- `references/decision-matrix.md`
- `references/supply-chain.md`
- `references/verification.md`
