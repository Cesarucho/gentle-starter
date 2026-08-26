# ADR 0002: Centralize tool version policy

**Status:** Accepted, 2026-08-24  
**Amends:** ADR 0001 section 6; the install tree, ownership, and execution order remain unchanged

## Context

Version policy was distributed across installer-local defaults. This made it difficult to audit exact versions, provider selectors, minimum observable versions, major channels, and intentionally floating policies. It also mixed the location of policy with the scripts that implement installation.

Java demonstrates why a single generic version field is insufficient: SDKMAN consumes `25-tem`, while `java --version` reports major version `25`. Scripts that install several tools need several independent declarations. Some artifacts, such as C4-PlantUML, have no reliable version command and continue to use an installer-owned marker.

## Decision

`.devcontainer/tool-versions.conf` is the canonical declarative policy file. Keys describe their real semantics:

- `*_VERSION`: exact package or artifact version;
- `*_INSTALL_VERSION`: provider-specific install selector;
- `*_REQUIRED_VERSION`: observable required or minimum version;
- `*_MAJOR`: major release channel;
- literal `latest`: an explicit floating, non-reproducible policy.

Tools receive only the fields they need. The first migration covers Java, Engram, C4-PlantUML, Spectral, Redocly, and AsyncAPI CLI. Remaining catalog entries will move in later reviewable units; existing local fallbacks are transitional.

### Policy and mechanism remain separate

The central file contains no commands, version-check commands, shell fragments, URLs, paths, artifact names, architecture logic, permissions, recovery, or idempotency mechanisms. Installers retain responsibility for installation, detection, comparison, functional validation, privilege handling, architecture, URLs, artifacts, and recovery.

Checksums normally remain next to direct-download logic. C4-PlantUML is the narrow exception: `TOOL_C4_PLANTUML_VERSION` and `TOOL_C4_PLANTUML_SHA256` are an atomic policy pair because its codeload archive does not publish a separate upstream checksum manifest. `task deps:update` downloads the archive for the selected stable 2.x tag, computes its digest, validates the complete candidate policy, and replaces the policy file atomically. The installer still owns the archive URL and verification mechanism.

### Assignment-only format and loader security

The format permits only blank lines, comments, and quoted non-empty scalar assignments whose keys begin with `TOOL_`. `devcontainer_load_tool_versions` parses lines and assigns values with `printf -v`. It never uses `source` or `eval` on the policy file.

The loader rejects malformed assignments, commands, functions, `export`, foreign keys, duplicate keys, command substitutions, backticks, trailing shell syntax, and empty values. Parsing errors identify the file and line.

### Precedence

Installers resolve values in this order:

1. an existing installer environment variable, including Docker `ARG`/`ENV` overrides;
2. the corresponding `TOOL_*` declaration;
3. a local fallback during migration.

For example, `ENGRAM_VERSION=...` remains authoritative over `TOOL_ENGRAM_VERSION`. Existing Docker override points remain; the project does not duplicate every version as a build argument.

### Build and runtime resolution

The Dockerfile copies `tool-versions.conf` into `/home/ubuntu/.devcontainer-install/` before copying `install/`. At runtime, scripts execute from the repository's `.devcontainer/install/` tree and find `.devcontainer/tool-versions.conf` relative to `common.sh`, not the current working directory. `DEVCONTAINER_TOOL_VERSIONS_FILE` provides an explicit path for tests and exceptional callers.

### Special cases

- Java declares `TOOL_JAVA_INSTALL_VERSION="25-tem"` and `TOOL_JAVA_REQUIRED_VERSION="25"`.
- Major channels, such as NodeSource's Node channel, use `*_MAJOR` when migrated.
- `latest` remains explicit and non-reproducible; migration must not silently pin it.
- Multi-tool installers consume multiple keys, as `40-node-contracts.sh` does.
- Artifacts without a CLI version command may use local markers. C4-PlantUML also centralizes its digest as the documented atomic-pair exception.
- Ubuntu core apt packages receive no invented versions without a real repository or snapshot pinning policy.

### Provider-managed and deferred tools

A `TOOL_*` key exists only when its installer enforces the declared policy. Omitting a key is intentional when centralization would be cosmetic or would require a separate provider or supply-chain redesign.

| Tool | Status | Reason |
| --- | --- | --- |
| BATS | Centralized | The installer consumes the exact `v${BATS_VERSION}` Git tag. |
| OpenCode | Provider-managed; central version omitted | An exact pnpm installation requires an explicit global-bin layout and narrowly approved lifecycle scripts. The official installer remains until that design is proven separately. |
| Glow | Provider-managed; central version omitted | The Charm apt repository selects the candidate; migration to a verified upstream artifact is deferred. |
| Ansible Core | Provider-managed; central version omitted | The apt candidate remains authoritative; moving to pipx is a separate provider and trust-boundary decision. |
| Graphviz | Provider-managed; central version omitted | Ubuntu Noble apt intentionally owns dependency integration and security updates. |
| Composer | Deferred; central version omitted | Exact PHAR installation requires a separately reviewed digest or attestation workflow. |

No cosmetic `TOOL_*` declaration is added for an installer that cannot enforce it.

### Automated dependency updates

`task deps:update` updates only an explicit allowlist. Its initial npm-registry
scope is Pi Coding Agent, Skills, the twelve Gentle Pi packages,
markdownlint-cli2, Mermaid CLI, Playwright, Spectral, Redocly, and AsyncAPI.
It queries that registry through pnpm. Its direct-release scope is stable C4
2.x, Terraform 1.x, Gitleaks 8.x, Pulumi 3.x, OpenTofu 1.x, Terragrunt 1.x,
kubectl 1.36.x, PlantUML 1.2026.x, and Delve v1.x.

Gentle AI is intentionally manual: its exact version and both Linux architecture
digests are reviewed and changed together so a dependency update cannot silently
replace the binary trust anchor with data from the same release boundary.
Engram, BATS, and Graphify are also outside the initial updater scope, as are
provider-managed tools. Java, Node, PHP, PHPUnit, major channels, and
literal `latest` policies remain unchanged. The command discovers and validates
all candidates before one atomic policy-file replacement; it does not install
packages, rebuild the container, commit, push, or publish changes.

## Consequences

### Positive

- Version policy becomes reviewable and auditable in one place.
- Names distinguish exact versions, selectors, requirements, and channels.
- Existing environment and Docker overrides continue to work.
- Installer mechanisms and integrity controls stay close to the operations they protect.

### Trade-offs

- During migration, central declarations and local fallbacks temporarily coexist.
- Assignment-only parsing is intentionally less expressive than shell.
- Floating policies remain reproducibility risks, now made explicit rather than silently changed.
- Version changes still rely on each installer's idempotency behavior.
- The C4-PlantUML digest records the bytes observed during update discovery; it is not an independent upstream attestation.

## Migration plan

1. Add the policy file, restricted loader, Docker copy, validation task, and parser/path/precedence tests.
2. Migrate representative cases: Java, Engram, C4-PlantUML, and the three node-contract CLIs.
3. Inventory and migrate the remaining exact, major, selector, required, and `latest` policies in small reviewable units, then remove duplicated local defaults and validate required keys.
4. Add `task install:versions` reporting and reasonable audits for unused, missing, duplicate, empty, or still-local version declarations.

## Rejected alternatives

- **Commands or shell fragments in configuration:** mixes policy with mechanism and expands the execution surface.
- **Unvalidated `source`:** executes arbitrary shell and violates the data-only contract.
- **YAML, JSON, or TOML initially:** requires another parser for a small scalar dataset and complicates bootstrap.
- **`.tool-versions`, mise, or asdf:** does not model provider selectors, artifact-only tools, npm bundles, checksums, and apt channels without adopting a new installation mechanism.
- **Keeping distributed defaults indefinitely:** preserves the auditability problem and prevents the central file from becoming canonical.
