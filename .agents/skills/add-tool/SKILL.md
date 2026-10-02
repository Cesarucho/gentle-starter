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
- Select the execution group explicitly: OS/bootstrap in `01-foundation`, mandatory tool aliases in `02-core-tools`, optional aliases in `03-enabled`, personal hooks in `04-hooks`. Core changes require coordinated selective Dockerfile COPY inputs; enable/disable is optional-only.
- Name catalog installers `BBPP-category-tool.sh`: related block `BB`, position `PP`, unique four-digit prefix; gaps are allowed. Generate aliases with the identical basename; preserve valid custom aliases and layer-first, filename-second order.
- Declare real dependencies only in `dependencies.conf`. Enable the required transitive closure, reuse core, repair active consumers, and never autoactivate companions. Validate the whole projection under the shared enable/disable lock before mutation; roll back only operation-created links.
- Keep installation, copy-on-first-run configuration, and mutable state separate. Classify state as none, passive, or installer-owned.
- Preserve fail-closed architecture gates and host-prepared long-syntax binds with `create_host_path: false`; never repair bind-root ownership at runtime.
- Obtain explicit approval before weakening trust or lifecycle controls.
- Classify every tool by provider and intent strategy. Only `tools:update` may
  resolve versions or integrity and modify the single policy file.
- Never add installer-local version/checksum defaults or build-time discovery.
- Keep Compose selection independent from installer activation; do not integrate
  overrides into enable/disable. Require Task host preparation and applied
  manifest identity before runtime state repair; IDEs attach only.

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
4. Register the intent and every generated lock output exactly once
   in the transactional updater; reject unsupported provider semantics.
5. Apply proportional trust, rollback, state, architecture, updater, and verification controls.
   Direct artifacts require all supported architectures before publication.
6. Keep implementation, tests, and user-facing documentation in one work unit.
7. Refresh the registry through its official mechanism only when metadata changed.

## Output Contract

Always return classification, changed files, validation, and residual risks. Include trust, architecture, state, updater, RED/GREEN, host-preparation, or review-burden evidence only when relevant. Never report RED retroactively.

## References

- `references/architecture.md`
- `references/decision-matrix.md`
- `references/supply-chain.md`
- `references/verification.md`
