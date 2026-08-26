# Repository tool architecture

## Inspect before editing

Run `scripts/inspect-install-tree.sh` from this skill directory, then read the paths it reports. Derived repositories may rename tasks, disable tools, change slot order, or omit a surface. Treat current files—not this reference—as authoritative.

## Extension surfaces

1. **Catalog:** `.devcontainer/install/available/` owns project installers. Copy the repository's own template when present. Do not place optional project tools in `01-core/` or personal tools in the versioned catalog.
2. **Activation:** `.devcontainer/install/02-enabled/` is an ordering layer of symlinks. The target keeps a category-rich name; the link uses a unique discovered `NN-tool.sh` slot. Build order is Dockerfile group order, then lexical filename order.
3. **Enable helper:** inspect `preferred_enabled_name` in the repository's install helper. Add a mapping and a contract test when a stable canonical enabled name is required; otherwise enabling may recreate the catalog basename and break intended order.
4. **Version policy:** `.devcontainer/tool-versions.conf` contains quoted `TOOL_*` scalar policy only. Installers retain URLs, commands, paths, architecture logic, checks, permissions, retries, and recovery.
5. **Runtime repair:** a stateful bind mount requires agreement among compose, `compose_target_to_install_scripts`, and an idempotent runtime-safe installer. Mapping values are installer basenames without `.sh`.
6. **Config seeding:** baseline user configuration belongs in a versioned `<tool>-config/` tree wired through the repository's copy-on-first-run helper. Preserve existing user files. Never restore the legacy symlink pattern.

## Lifecycle

Build installers normally run as root with `DEVCONTAINER_PHASE=build`. PostCreate and volume repair normally run as the development user with `DEVCONTAINER_PHASE=runtime`. A script may run repeatedly in both phases. Detect the actual repository contract before assuming user, HOME, copied build path, or workspace path.

Runtime-only tools must explicitly skip build and reject accidental root execution when user ownership matters. Global binary installation must not invoke commands that create or rewrite user configuration.

## Lessons from Gentle AI

- Install the CLI binary only; do not run configuration-mutating setup or sync commands.
- Validate version policy and architecture digest before an exact-version early exit.
- Replace stale binaries through a staged file; retain and restore the previous binary if final verification fails.
- Bound retries and preserve the previous installation on every download, digest, extraction, or verification failure.
- Test the canonical enabled slot and doctor contract; avoid stale hardcoded catalog counts.
- Old running containers do not prove a new image install. Use a temporary PATH for isolated tests and rebuild only through the documented host or host-simulation flow.

## Local skill lifecycle

Inspect the derivative's skill tasks before adding project-authored skills. This repository distinguishes external skills in `skills-lock.json` from project-authored names in `.agents/local-skills.txt`; `task skill:prune` preserves the union and `task skill:validate` verifies both. If a derivative lacks this manifest contract, do not invent external lock metadata: add and test an explicit local-skill preservation mechanism or document the pruning risk.
