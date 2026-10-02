# Optional Gentle Shell v4

Gentle Shell is available but **disabled by default**. It installs the npm
package `gentle-pi`, whose executable is `gentle-shell`, and a verified,
package-private Gentle AI binary. Global Gentle AI and OpenCode are unchanged.

## Enable and use

1. Run `task install:enable -- 3040-ai-gentle-shell`. The dependency planner
   reuses core Node/Engram and enables Pi before Shell.
2. For persistence, uncomment `./config/compose/docker-compose.gentle-shell.yml`
   in `.devcontainer/devcontainer.json`. This is separate from activation.
3. Rebuild and start through the normal host workflow:
    `task container:rebuild && task container:up`.
4. Check `gentle-shell --version`, then launch `gentle-shell`. No manual native
   setup is needed. The managed home is `~/.gentle-shell/agent`, not `--link`.
   Node >=22.19.0 and the exact policy-managed Pi version are required.

Installation never runs npm lifecycle scripts, native setup, or a session.
Activation-gated postCreate `setup.sh` uses the existing `seed_config_tree` to
copy versioned baseline files only when absent. Configuration stays in the
workspace; neither Dockerfile nor the build installer copies an image baseline.
Fresh settings use fullscreen, Gentleman-Cute and an explicit
codemode builtin exclusion. Existing config/settings bytes remain unchanged;
malformed JSON, symlinks and conflicting Shell package declarations fail safely.
The launcher never seeds or repairs a home, and `gentle-shell setup` is disabled.
Missing configuration reports that automatic postCreate setup must finish; use
the host recreation workflow rather than manual Shell setup. Linked/custom homes
and runtime overrides are rejected. Sign in directly in the isolated profile;
credentials are never copied.

An image-owned read-only validator retains pinned adapter hashes and isolation
checks. Setup validates source/target paths before the shared seeder and validates
readiness afterward; launch validates the persisted profile without workspace or
image-baseline copying. Existing generic seeding behavior is otherwise unchanged.

The runtime-only Engram Pi adapter is vendored unchanged at v3.0.0 commit
`15a2f78885d7ad8ced23b2d1d88383e9bb472c17` (adapter 0.2.0), with license,
provenance and SHA-256 manifest. It uses `/usr/local/bin/engram` and existing
Engram storage with the normal process HOME and a localhost server. No database,
binary, initializer or credentials are duplicated; `pi-engram init` is never run.
Core Engram and the adapter are upgraded together in repository policy, not by
running native setup. Adapter-launched servers opt into upstream cloud autosync
only according to existing Engram configuration; no cloud credentials are seeded.

## Integrity and recovery

`task tools:update` resolves the npm version/SHA-512 SRI and both Linux
amd64/arm64 private archive and binary SHA-256 pins as one transaction. It checks
actual artifact bytes, package identity, engine metadata, and archive entry
types. These same-boundary integrity checks are not independent publisher
signature or attestation verification. No binary is executed by the updater.

The installer uses `npm --legacy-peer-deps --ignore-scripts`, explicitly installs the pinned private
binary and canonical manifest, makes root-created content readable/executable
by ubuntu, verifies through the upstream runtime resolver, and only then
publishes the managed command. Normal dependency integrity remains npm-owned.
Peer installation is disabled: the managed Pi loader supplies its own API.
The installer records the canonical global npm Pi root and exact
`LOCK_PI_CODING_AGENT_VERSION`; the launcher validates that package/CLI directly,
never selecting ambient PATH or an override. Duplicate Earendil/typebox copies
in the private prefix are refused. Pi-only policy updates refresh runtime
metadata without replacing or rejecting valid immutable Shell/private bytes.
It stages new versions and refuses to silently delete damaged existing versions.

At each managed launch, the private bundle is checked before native code runs.
Environment development binary/pin/installer overrides, persistent
`dev-binary.json` registrations (including malformed registrations), and
`--package-root` are rejected. Missing or damaged private bundles require an
explicit image repair/rebuild; neither global Gentle AI fallback nor automatic
binary recovery is allowed. This is a managed entry-point guard, not a sandbox
against users deliberately bypassing the launcher or modifying package code.

## Persistence

The optional long-syntax bind maps host `.env.d/.gentle-shell` to
`/home/ubuntu/.gentle-shell`, including config, agent sessions, isolated sign-ins
and Gentle preferences (`GENTLE_PI_CONFIG_HOME` is isolated inside that root).
Host Task preparation creates and validates the root as the host user before
Docker and publishes the applied manifest. The root is passive: no runtime
owner mapping, recursive chown or repair is introduced. The existing Pi bind
does not persist Shell. Enabling Shell does not select either override.

Without the Shell override, state is container-local and may be lost on
recreation. Existing Pi/Engram/personal configuration is never migrated.
Prompt-history capture is forced off because v4.0.0 hardcodes its history root
under `~/.pi`; normal isolated Pi sessions still persist. The upstream package
is not patched, and process HOME is not redirected. The managed launcher uses
public argument/invocation exports rather than native mutating bootstrap;
native exit resume-hint handoff is not provided (Pi session resume still works).

### Adapter upgrade recovery

An existing 0.1.16 adapter cannot update/delete observations against Engram 3.0.0:
it omits the required owner assertion. Both launch and pre-seed validation reject
old or modified runtime bytes instead of silently retaining an incompatible adapter.
There is no automatic overwrite, even for a known old pin.

Before a separately authorized environment upgrade, stop Shell/Pi and review the
existing `~/.gentle-shell/agent/extensions/engram` directory. Move **only that
directory** to a new, nonexistent backup path outside `agent/extensions` (for
example `~/.gentle-shell/adapter-backups/engram-before-0.2.0`). Do not delete it or
overwrite a previous backup. Keep config/settings, sessions, sign-ins and
`~/.engram` in place. Custom edits remain in the backup for review; they are never
automatically merged into a pinned adapter. Do not restore old runtime bytes into
the active extension while using Engram 3.0.0.

Rerun the normal host Task recreation workflow so activation-gated postCreate
seeds the absent adapter from the upgraded repository. It preserves existing
preferences byte-for-byte. The launcher remains read-only. Review the new manifest
and restart agent/MCP processes; this repository change does not upgrade a running
server or personal configuration. This recovery was tested only in scratch homes.

### Engram 3.0.0 compatibility and storage

Use `task tools:update -- --update-engram 3.0.0` to change only Engram's intent and
three locks atomically. Omitting the version resolves the current Engram selector.
Unrelated policy bytes and file mode are preserved; no inventory-wide update is
needed. Release metadata supplies the hashes; verify downloaded archives against
those hashes before any separately authorized installation.

Engram 3.0.0 requires `expected_project` for MCP `mem_update`/`mem_delete` and for
HTTP PATCH/DELETE observation query parameters. Missing/invalid assertions yield
400, owner mismatch 409, missing observation 404. It is an ownership assertion,
not authentication. The adapter supplies it; agents must assert the actual owner.
Seeded OpenCode MCP commands already invoke `engram mcp --tools=agent`, so a fresh
process receives the installed binary's schema. The repository OpenCode event
plugin has no HTTP observation update/delete path, but remains an older plugin:
it lacks the upstream dual-major OpenCode 2.x entrypoint, resume handling and
strict acknowledgement checks, and retains cloned-manifest auto-import. It was
audited, not upgraded or executed here. Existing seeded/personal clients are not
automatically overwritten or proven compatible. Review them before runtime use.

Keep SQLite/WAL storage on a **local filesystem** and retain owner-managed backups
before a real upgrade. Upstream's Linux startup guard rejects known NFS/SMB/CIFS;
unknown filesystem types and detection failures remain allowed, not certified safe.
A bind mount or successful doctor result alone does not prove local storage.
The existing Engram bind/storage path is unchanged; no actual backing filesystem
or personal database was inspected. No doctor repair, cloud upgrade, import or
database migration is run by this coordinated repository update.

See the [official Engram 3.0.0 release and upgrade checklist](https://github.com/Gentleman-Programming/engram/releases/tag/v3.0.0).

## Maintainer bootstrap

When introducing this tool into a policy with no Shell locks, run
`task tools:update -- --bootstrap-gentle-shell`. This first-time path resolves
all seven Shell locks atomically and preserves all unrelated policy bytes and
intent. It refuses partially or fully present Shell locks; subsequent updates
use ordinary `task tools:update`. Do not edit generated locks manually.
