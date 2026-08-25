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

The central file contains no commands, version-check commands, shell fragments, URLs, paths, artifact names, architecture logic, checksums, permissions, recovery, or idempotency mechanisms. Installers retain responsibility for installation, detection, comparison, functional validation, privilege handling, architecture, URLs, artifacts, and recovery.

Checksums remain next to direct-download logic. In particular, the C4-PlantUML version is central while its checksum stays in `40-cli-c4-plantuml.sh`.

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
- Artifacts without a CLI version command may use local markers while centralizing only the version.
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
