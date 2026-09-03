# Volumes and the install contract

This document is the deep reference for the stateful-volume contract.
Installer-owned targets tie together `docker-compose.yml`,
`setup-volumes.sh`, and the `install/available/` scripts. Passive
state mounts use only Compose because no installer owns or populates
them. The TL;DR lives in the header of `setup-volumes.sh` and in the
output of `task install:volumes`.

> **Looking for the comprehensive view?** Start at
> [`docs/en/extending.md`](./extending.md), which covers install,
> volumes, and configs together with a worked example and the FAQ.
> This file is the deep dive on the volume contract only.

## Sister contract: config seeding

`setup.sh` ships a parallel mechanism for *config files*: a
`seed_config_tree` helper that copies baseline configs from
`.devcontainer/<name>-config/` to their runtime path. It is
copy-on-first-run (idempotent, preserves user customisations) and
auto-escalates to `sudo` for targets outside `$HOME`. The convention
is documented in [`configs.md`](./configs.md); the rationale is
identical to this one (the source tree IS the manifest).

## The contract in one diagram

```text
.docker-compose.yml                    .devcontainer/setup-volumes.sh
┌──────────────────────────────┐         ┌─────────────────────────────────┐
│ services.container-svc       │         │ resolve_compose_volume_targets │
│   volumes:                   │ ──────▶ │   reads the volumes block,     │
│     - type/source/target/bind   │         │   emits source|target pairs    │
│       long-syntax entries      │         │                                 │
│     - .../opencode/share:...    │         │ compose_target_to_install_     │
└──────────────────────────────┘         │   scripts(target) -> [names]   │
                                         │                                 │
                                         │ repair_installed_volumes        │
                                         │   filters owners through        │
                                         │   02-enabled, then runs each    │
                                         │   active owner at runtime       │
                                         └──────────────┬──────────────────┘
                                                        │
                                                        ▼
                                         .devcontainer/install/available/
                                         ┌─────────────────────────────────┐
                                         │ 30-ai-pi-coding.sh              │
                                         │ 30-ai-pi-gentle.sh              │
                                         │ 30-ai-engram.sh                 │
                                         │ (yours here)                    │
                                         └─────────────────────────────────┘
```

For an **installer-owned target**, four pieces participate: the bind mount,
the potential-owner mapping, the available installer, and an active symlink in
`02-enabled/`. `compose_target_to_install_scripts` deliberately keeps listing
potential owners even when one is disabled. At dispatch time, an owner runs
only when a valid symlink—under any ordered alias—canonically resolves to its
script in `available/`; broken symlinks never activate an owner. A **passive
target** intentionally has no mapping or repair script; for example, OpenCode
owns and populates
`~/.local/share/opencode` while it runs.

## Why bind mounts (and not named volumes)

The project uses **host bind mounts** (long-syntax sources such as
`../.env.d/.pi` targeting `/home/ubuntu/.pi`)
rather than Docker named volumes because the primary use case is
**physical access from the host**:

- Edit `.env.d/.pi/agent/models.json` with a host editor.
- `cat .env.d/.engram/.engram.db | jq` from a host terminal.
- `cp -r .env.d/ .env.d.backup/` for an offline snapshot.
- `grep -r` across the whole state tree from the host.

A named volume would force every one of those into a `docker run`/
`docker exec` round trip. The trade-off is real:

| | Bind mount (current) | Named volume |
|---|---|---|
| Persist across rebuild | Yes | Yes |
| Host-side access | Yes (`ls .env.d/`) | No (requires `docker run`) |
| Host editor / grep / cat | Yes | No |
| `cp -r` for backup | Yes | `docker run --rm -v ... tar` |
| Survives `rm -rf` of the clone | No (lives in the repo's working tree) | Yes (Docker-managed) |
| Performance on macOS / Windows | Slower (FS virtualization) | Native |
| UID mismatch host ↔ container | Host preparation verifies ownership before startup | Handled by Docker |
| `git status` shows it | Yes (intentionally — see below) | No |

The `.env.d/` tree is ignored by Git because it contains deliberate,
per-clone, per-checkout state. Use `git status --ignored` when you need to
inspect it through Git.

If at some point the state grows large enough that you don't want it
in the working tree (e.g. multi-GB caches), the natural migration is
**split-by-purpose**: keep the bind mounts for the small, user-facing
config (e.g. `models.json`, `mcp.json`) and add a named volume for
the large, internal caches (e.g. `~/.pi/agent/npm`). Host preparation before
`devcontainer up` handles bind-source UID alignment; named volumes are managed
by Docker and skip that concern.

## How the repair fires

Before container creation, `task container:up` derives managed sources from the
Compose service and safely creates missing directory components under `.env.d`
as the invoking host user. Compose sets `bind.create_host_path: false`, so direct
startup fails instead of silently creating root-owned sources. Existing paths
are inspected without following symlinks; collisions and foreign ownership fail
with exact-path remediation. Existing modes and descendants are preserved; no
recursive or container-runtime ownership repair touches bind roots.

After creation, the `postCreateCommand` runs `bash .devcontainer/setup.sh`:

```bash
setup_versioned_configs         # copy missing Pi and OpenCode baseline configs
setup_pi_workspace_trust        # mark the workspace as trusted in trust.json
repair_installed_volumes        # dispatch repair for installer-owned mounts
run_enabled_opencode_installer
```

Dev Containers runs with `remoteUser: ubuntu`; its numeric UID projection aligns
the prepared host directories with the container development user. The project
does not use `HOST_UID` or `HOST_GID` build plumbing.

`repair_installed_volumes` iterates the targets from
`resolve_compose_volume_targets` and, for each one, calls
`compose_target_to_install_scripts` to find the potential owning scripts. It
then checks `02-enabled/` and runs only active owners with
`DEVCONTAINER_PHASE=runtime`. An empty mapping is an intentional no-op for
passive mounts, while a mapped but disabled owner is intentionally skipped.
For active owners, the script's idempotency guard decides whether the call is a
no-op or actually does work.

For example, disabling `30-ai-pi-gentle` leaves the `.pi` mapping unchanged but
removes that owner from future builds and postCreate repairs. The independently
enabled `30-ai-pi-coding` owner continues repairing the same mount. Disable is
non-destructive: it does not remove Pi packages already persisted in
`.env.d/.pi`, and volume repair does not provide a purge operation.

So the actual "populate the empty bind mount" moment is inside the
runtime-only branches of the install scripts, not in `setup-volumes.sh`
itself. `setup-volumes.sh` is the dispatch; the scripts are the work.

## Adding a new stateful volume (worked example)

Let's say you want to add a PostgreSQL data dir that survives rebuilds.

1. **Add the bind mount** in `.devcontainer/docker-compose.yml`:

   ```yaml
   volumes:
     - type: bind
       source: ../.env.d/.postgresql
       target: /home/ubuntu/.postgresql
       bind: { create_host_path: false }
   ```

2. **Add the install script** in `.devcontainer/install/available/`:

   ```bash
   cp .devcontainer/install/templates/install-script.sh \
      .devcontainer/install/available/40-data-postgresql.sh
   ```

   Fill the script. Make it idempotent (skip if already present) and
   **runtime-safe** (it will be called as ubuntu, not root — the
   `setup.sh` heredoc for SDKMAN is the model).

3. **Add the target-to-script mapping** in
   `.devcontainer/setup-volumes.sh` (the `case` block in
   `compose_target_to_install_scripts`):

   ```bash
   case "${target}" in
       "${HOME}/.pi"        | "/home/${UID}/.pi")
           scripts_ref+=("30-ai-pi-coding" "30-ai-pi-gentle")
           ;;
       "${HOME}/.engram"    | "/home/${UID}/.engram")
           scripts_ref+=("30-ai-engram")
           ;;
       "${HOME}/.postgresql" | "/home/${UID}/.postgresql")
           scripts_ref+=("40-data-postgresql")
           ;;
       esac
   ```

4. **Enable the script** by linking from `02-enabled/`:

   ```bash
   cd .devcontainer/install/02-enabled
   ln -sfn ../available/40-data-postgresql.sh 40-data-postgresql.sh
   ```

5. **Verify the live contract**:

   ```bash
   task install:volumes
   ```

   The output should now show the postgresql target with its potential owning
   script. Its valid `02-enabled/` symlink makes it active for postCreate
   repair.

6. **Rebuild and validate**:

   ```bash
   task container:rebuild
   ```

   The build log should include a `Running: .../40-data-postgresql.sh`
   line during build, and the postCreate log should include a
   `Volume repair: /home/ubuntu/.postgresql -> 40-data-postgresql.sh`
   line.

## Troubleshooting

### "I added a bind mount but the volume is empty after rebuild"

Run `task install:volumes` first. If the target reports no repair
mapping and an installer should populate it, add the missing script
and `compose_target_to_install_scripts` case. If the application owns
the state itself, the mount is passive and an empty directory before
the application first runs is expected.

### "I added the install script but `task install:volumes` doesn't list my volume"

The script exists but the bind mount doesn't, or the
`docker-compose.yml` parse didn't pick it up. Check that the new
volume entry in `docker-compose.yml` is a well-formed long-syntax bind under
`services."container-svc".volumes`, with `source`, `target`, and
`bind.create_host_path: false`.

### "The repair runs but the script fails with 'command not found'"

The runtime script relies on PATH and on tools that may not be
installed yet. Check that the script's own install steps (or
`10-system.sh`) provides everything it needs. Idempotency guards
should be defensive: prefer `command -v` over `devcontainer_has_cmd`
when the script is called in unusual contexts.

### "I want to inspect the runtime state without re-running anything"

`task install:volumes` prints the contract. To inspect what's
actually in a target:

```bash
docker exec ${APP_NAME}-run ls -la ~/.engram/
docker exec ${APP_NAME}-run cat ~/.pi/agent/mcp.json
```

Or from the host:

```bash
ls -la .env.d/.engram/
cat .env.d/.pi/agent/mcp.json
```

(The host-side path is exactly the bind-mount source path.)
