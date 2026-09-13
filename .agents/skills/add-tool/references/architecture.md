# Repository tool architecture

## Inspect before editing

Run `scripts/inspect-install-tree.sh` from this skill directory, then read the paths it reports. Derived repositories may rename tasks, disable tools, change slot order, or omit a surface. Treat current files—not this reference—as authoritative.

## Extension surfaces

1. **Catalog:** `.devcontainer/install/available/` owns both core and optional tool installers. Start from the closest real installer; use the canonical repository template only as a skeleton. `01-foundation/` is OS/bootstrap only; personal tools belong in `04-hooks/`.
2. **Activation:** `02-core-tools/` holds mandatory canonical symlinks; `03-enabled/` holds optional symlinks. Targets keep category-rich names; aliases use discovered `NN-tool.sh` slots. Build order is explicit Dockerfile group order, then lexical filename order. Dependencies may cross from core to optional consumers, never the reverse. Reject duplicate canonical installers across groups.
3. **Enable helper:** enable/disable modifies only `03-enabled/` and refuses core tools. Inspect `preferred_enabled_name` before choosing an optional alias. Intentional core customization must coordinate core aliases, selective Dockerfile source/helper COPY inputs, and their consistency tests. Keep project identity, optional selectors/sources, and hooks downstream of the cached `core-tools` stage.
4. **Version policy:** `.devcontainer/tool-versions.conf` contains user-editable
   `TOOL_*_VERSION` intent followed by generated exact `LOCK_*` values and
   checksums. `deps:update` is the sole mutation authority. Installers retain
   URLs, paths, architecture gates, permissions, and verification, but never
   local version/checksum defaults or release discovery.
   Go Task is a narrow existing external APT-managed core bootstrap exception:
   it stays outside policy to preserve the foundation/cache boundary. Do not use
   it as precedent for a new unmanaged tool.
5. **Persistent state:** classify each bind as passive or installer-owned. Every repository-managed source uses Compose long syntax with `bind.create_host_path: false` and is prepared before Docker by the host-user `prepare-bind-mounts.sh`/Python path. Passive mounts stop there; installer-owned mounts also require `compose_target_to_install_scripts`, an enabled runtime-safe installer, and idempotent repair tests. Mapping values are installer basenames without `.sh`.
6. **Config seeding:** baseline user configuration belongs in a versioned `<tool>-config/` tree wired through the repository's copy-on-first-run helper. Preserve existing user files. Never restore the legacy symlink pattern.

## Lifecycle

Build installers normally run as root with `DEVCONTAINER_PHASE=build`. PostCreate and volume repair normally run as the development user with `DEVCONTAINER_PHASE=runtime`. A script may run repeatedly in both phases. Detect the actual repository contract before assuming user, HOME, copied build path, or workspace path.

Runtime-only tools must explicitly skip build and reject accidental root execution when user ownership matters. Global binary installation must not invoke commands that create or rewrite user configuration.

Host Task preparation lets Docker Compose resolve the service and ordered files
from JSONC. Keep full config in memory; atomically publish only the versioned
volume projection with input/source fingerprints. Normalize managed sources to
workspace-relative `.env.d` paths. Create only missing components as the host
user with exact mode `0755`; preserve existing paths and descendants and reject
symlinks, files, and foreign ownership. Never prepare external sockets as
directories. Runtime requires fresh repository inputs and the creation-time
manifest identity before any mutation; desired mounts alone are insufficient.
Check producer completion before dispatch, not through unchecked process
substitution. Use JSON or NUL records, never delimiter splitting or base64 eval.

Select independent Pi, SSH-agent, SSH-server, and audio overrides manually in
`devcontainer.json`; installer enable/disable integration is deferred. Mount
changes require Task recreation, package changes Task rebuilding. SSH client is
downstream/default; server needs both installer and persisted-key override.
Pulse clients are downstream/optional; `HOST_UID` only locates the host socket
after the host guard, never container identity. Preserve foundation cache inputs.
Keep the external Pulse socket at `/pulse-native` with `PULSE_SERVER=unix:/pulse-native`;
DinD startup can hide binds beneath `/tmp` with tmpfs. Preserve read-only binding
and `create_host_path: false`; never prepare the socket as managed state. Apply
this mount/environment change with host `task container:restart`, not a package rebuild.

## Lessons from Gentle AI

- Install the CLI binary only; do not run configuration-mutating setup or sync commands.
- Validate version policy and architecture digest before an exact-version early exit.
- Replace stale binaries through a staged file; retain and restore the previous binary if final verification fails.
- Bound retries and preserve the previous installation on every download, digest, extraction, or verification failure.
- Test the canonical enabled slot and doctor contract; avoid stale hardcoded catalog counts.
- Old running containers do not prove a new image install. Use a temporary PATH for isolated tests and rebuild only through the documented host or host-simulation flow.

## Local skill lifecycle

Inspect the derivative's skill tasks before adding project-authored skills. This repository distinguishes external skills in `skills-lock.json` from project-authored names in `.agents/local-skills.txt`; `task skill:prune` preserves the union and `task skill:validate` verifies both. If a derivative lacks this manifest contract, do not invent external lock metadata: add and test an explicit local-skill preservation mechanism or document the pruning risk.
