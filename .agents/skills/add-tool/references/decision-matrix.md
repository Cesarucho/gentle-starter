# Provider and surface matrix

## Provider patterns: route to real code

| Pattern | Closest repository example |
| --- | --- |
| Ubuntu apt distribution | `01-core/10-system.sh`, `40-cli-graphviz.sh` |
| Third-party apt/PPA | `20-runtime-node.sh`, `40-php-lang.sh` |
| npm/pnpm global | `20-runtime-pnpm.sh`, `40-node-markdownlint.sh` |
| Python isolated venv/pipx-like | `40-python-graphify.sh` |
| Go binary/build or prebuilt | `20-runtime-go.sh`, `40-go-debug.sh` |
| PHP/Composer | `40-php-lang.sh`, `40-php-test.sh` |
| SDK/provider manager | `20-runtime-java.sh` |
| Direct archive/binary | `30-ai-gentle-ai.sh`, `40-cli-gitleaks.sh` |
| Provider script | `30-ai-opencode.sh` (accepted provider trust boundary) |
| Runtime-only user install | `30-ai-opencode.sh`, `30-ai-engram.sh` |

Read the example and its focused unit/integration tests. Reuse `lib/common.sh`; do not copy a second framework into the skill.

## Select surfaces

| Need | Add | Do not add |
| --- | --- | --- |
| Available on demand | Catalog installer | Enabled link unless default activation is approved |
| Default active | Unique discovered enabled symlink; canonical helper mapping/test when needed | Category prefix copied into enabled name |
| Exact policy | Enforced `TOOL_*` key and policy diagnostic | Unused declaration |
| User defaults | Config seed tree and explicit setup wiring | Config writes in the binary installer |
| Passive mutable state | Long-syntax managed bind and host preparation coverage | Installer mapping or runtime repair |
| Installer-owned mutable state | Managed bind, owner mapping, enabled runtime-safe installer, repair tests | Container-side mount-root ownership repair |
| Runtime integration | Focused setup/doctor/integration test | Unconditional network mutation on every start |

State is **none** unless persistence is required. A passive bind is populated by the application and has no repair mapping. Installer-owned state additionally maps the target to an enabled, runtime-safe, idempotent installer.

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
