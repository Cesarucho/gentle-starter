---
name: add-tool
description: "Trigger: add tool, install CLI, provision devcontainer dependency, extend dev tooling. Add tools safely by inspecting the repository's install catalog, version policy, tests, and lifecycle contracts."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract

Use when adding or changing repository-managed development tooling, especially when the repository has an install catalog, enabled ordering layer, version policy, or devcontainer lifecycle. Do not use for application dependencies or personal hook customizations.

## Hard Rules

- From this skill directory, run `./scripts/inspect-install-tree.sh [repository]` before proposing files, names, slots, versions, or test counts.
- Apply strict TDD: record RED, implement GREEN, triangulate edge cases, then refactor.
- Keep installation mechanism separate from user configuration and mutable state.
- Never weaken an existing trust boundary, pin, digest, signature check, rollback, or architecture gate.
- Keep the change reviewable; split unrelated migrations and report changed lines.

## Decision Gates

| Tool/source | Required path |
| --- | --- |
| npm package | Exact package version; inspect pnpm/npm global layout and lifecycle scripts |
| GitHub binary | Exact release, architecture mapping, independent trust decision, staged replacement |
| Official script | Treat as provider-managed unless its bytes/signature are independently pinned |
| Runtime-only | Skip build, run unprivileged, and make repeated postCreate execution safe |
| Baseline config | Use copy-on-first-run config seeding; never hide it inside binary installation |
| Mutable state | Add compose mount, repair mapping, and runtime-safe owner together |

## Execution Steps

1. Read `references/architecture.md` and inspect the derived repository.
2. Classify the tool with `references/decision-matrix.md`; choose the closest existing installer.
3. Define policy and trust controls with `references/supply-chain.md`.
4. Add failing focused tests from `templates/`, then implement from `templates/install-script.sh`.
5. Wire catalog, optional enabled slot, `preferred_enabled_name`, config, volume, doctor, docs, and updater only when applicable.
6. Execute `references/verification.md`; refresh the official skill registry if skills changed.

## Output Contract

Return classification, files changed, RED/GREEN evidence, validations, residual risks, unsupported architectures, updater decision, change line count, and the next reviewer action. Never commit, push, publish, or rebuild destructively without authorization.

## References

- `references/architecture.md`
- `references/decision-matrix.md`
- `references/supply-chain.md`
- `references/verification.md`
