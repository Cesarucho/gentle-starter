# Tool decision matrix

## Classify first

| Question | Decision |
| --- | --- |
| Is this an application dependency? | Stop; use the application's package manager, not the devcontainer catalog. |
| Is it personal or site-specific? | Use the derivative's hook/local mechanism, not a shared default. |
| Does it need Node and expose a stable package version? | Prefer exact pnpm/npm installation; inspect global-bin ownership and required lifecycle scripts. |
| Does upstream publish per-architecture release artifacts? | Use a direct binary installer with exact version, explicit architecture map, integrity verification, staging, and rollback. |
| Is only an official curl installer supported? | Treat it as provider-managed; document floating behavior and trust boundary. Pin only if the installer bytes or signature are verifiably fixed. |
| Must it write into the development user's HOME? | Make it runtime-only and unprivileged. |
| Is it supplied by apt/provider repository? | Do not add cosmetic `TOOL_*` pins the installer cannot enforce. |

## Select surfaces

| Need | Add | Do not add |
| --- | --- | --- |
| Available on demand | Catalog installer | Enabled link unless default activation is approved |
| Default active | Unique discovered enabled symlink; canonical helper mapping/test when needed | Category prefix copied into enabled name |
| Exact policy | Enforced `TOOL_*` key and policy diagnostic | Unused declaration |
| User defaults | Config seed tree and explicit setup wiring | Config writes in the binary installer |
| Persistent mutable state | Bind mount, owner mapping, runtime repair test | Volume for ordinary static configuration |
| Runtime integration | Focused setup/doctor/integration test | Unconditional network mutation on every start |

## Version semantics

Use names that match behavior:

- `*_VERSION`: exact package or artifact.
- `*_INSTALL_VERSION`: provider selector, such as an SDK identifier.
- `*_REQUIRED_VERSION`: observable minimum/required output.
- `*_MAJOR`: intentionally tracked major channel.
- `latest`: explicit, reviewed non-reproducibility.

Resolve values in this order: existing installer environment override, matching `TOOL_*` value, then a temporary local fallback during migration. Prefer a `--print-version-policy` mode so tests can inspect resolution without installing.

## Architecture gate

Discover supported repository and upstream architectures. Normalize host values through the repository helper, map each supported architecture explicitly to artifact name and integrity material, and fail closed before network access for unknown architectures. Never reuse one architecture digest for another.

## Update automation gate

Add a tool to `deps:update` only when discovery is deterministic, stable-channel filtering is explicit, every coupled trust input is updated atomically, candidate validation happens before replacement, and review remains meaningful. Keep it manual for same-release-boundary digests, signatures requiring human identity review, provider-managed channels, `latest`, major selectors, or tools whose update would execute/install code.
