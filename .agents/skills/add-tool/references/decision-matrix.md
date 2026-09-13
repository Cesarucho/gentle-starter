# Provider and surface matrix

## Provider patterns: route to real code

| Pattern | Closest repository example |
| --- | --- |
| Ubuntu apt distribution | `01-foundation/10-system.sh`, `40-cli-graphviz.sh` |
| Third-party apt/PPA | `20-runtime-node.sh`, `40-php-lang.sh`; do not copy Task's narrow core-bootstrap exception |
| npm/pnpm global | `20-runtime-pnpm.sh`, `40-node-markdownlint.sh` |
| Python isolated venv/pipx-like | `40-python-graphify.sh` |
| Go binary/build or prebuilt | `20-runtime-go.sh`, `40-go-debug.sh` |
| PHP/Composer | `40-php-lang.sh`, `40-php-test.sh` |
| SDK/provider manager | `20-runtime-java.sh` |
| Direct GitHub release archive/binary | `30-ai-opencode.sh` (image-owned, checksum-verified), `30-ai-gentle-ai.sh`, `40-cli-gitleaks.sh` |
| Runtime-only user install | `30-ai-engram.sh` |

Read the example and its focused unit/integration tests. Reuse `lib/common.sh`; do not copy a second framework into the skill.

## Select surfaces

| Need | Add | Do not add |
| --- | --- | --- |
| Available on demand | Catalog installer | Enabled link unless default activation is approved |
| Default active | Unique discovered enabled symlink; canonical helper mapping/test when needed | Category prefix copied into enabled name |
| Managed version policy | One editable `TOOL_*_VERSION`, complete provider strategy and generated `LOCK_*` outputs | Unregistered intent or installer-owned resolution |
| User defaults | Config seed tree and explicit setup wiring | Config writes in the binary installer |
| Passive mutable state | Long-syntax managed bind and host preparation coverage | Installer mapping or runtime repair |
| Installer-owned mutable state | Managed bind, owner mapping, enabled runtime-safe installer, repair tests | Container-side mount-root ownership repair |
| Runtime integration | Focused setup/doctor/integration test | Unconditional network mutation on every start |

State is **none** unless persistence is required. A passive bind is populated by the application and has no repair mapping. Installer-owned state additionally maps the target to an enabled, runtime-safe, idempotent installer.

## Version semantics

First classify the provider: SDKMAN, Node channel, PHP series, kubectl minor,
npm tag/range, Composer constraint, v-prefixed release, PlantUML year lane, or
coupled Playwright components. Segment count alone is NEVER a strategy.

Use names that match behavior:

- `TOOL_*_VERSION`: user intent; `latest` is resolved only by `deps:update`.
- `LOCK_*_VERSION`: exact package, provider candidate, or artifact.
- `LOCK_*_REQUIRED_VERSION`: exact observable requirement.
- `LOCK_*_MAJOR` or `LOCK_*_SERIES`: provider-owned exact channel representation.
- `LOCK_*_SHA256*`: generated exact build integrity.

For each new managed tool, add exactly one editable `TOOL_*_VERSION` intent,
register a complete provider strategy in `deps:update`, and generate every exact
version, provider representation, and integrity value the installer needs as
`LOCK_*`. Installers and other consumers may honor approved environment
overrides, then consume required locks read-only and fail closed when they are
missing. They never resolve editable intent, discover releases, or carry local
version/checksum fallbacks. Prefer a `--print-version-policy` mode so tests can
inspect consumed lock values without installing.

## Architecture gate

Discover supported repository and upstream architectures. Normalize host values through the repository helper, map each supported architecture explicitly to artifact name and integrity material, and fail closed before network access for unknown architectures. Never reuse one architecture digest for another.

## Update automation gate

Every managed tool intent must have one safe, explicit strategy registered in
`deps:update`. Discovery must be deterministic, stable-channel filtering
explicit, and every coupled trust input updated in one atomic replacement.
Reject intent when its provider cannot interpret it safely. If a provider
cannot yet be implemented safely, fail the proposed managed addition and keep
the tool outside the managed install tree; never defer resolution to an
installer.

The existing Go Task installer is not a general alternative to this gate. It is
an external APT-managed core bootstrap needed to invoke repository workflows;
Cloudsmith owns its package version and signed APT integrity, and its placement
preserves the foundation/cache architecture. New tools still require the normal
managed-policy route unless a separate architecture decision explicitly
approves another bootstrap exception.
