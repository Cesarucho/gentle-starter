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
│     - ../.env.d/.pi:~/pi        │         │   emits source|target pairs    │
│     - ../.env.d/.engram:~/engram│         │                                 │
│     - .../opencode/share:...    │         │ compose_target_to_install_     │
└──────────────────────────────┘         │   scripts(target) -> [names]   │
                                         │                                 │
                                         │ repair_installed_volumes        │
                                         │   loops targets, calls each     │
                                         │   owning script with            │
                                         │   DEVCONTAINER_PHASE=runtime    │
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

For an **installer-owned target**, all three pieces must agree at any
moment in time. If you change one, the other two will silently
disagree: the bind mount gets created but its install script never
re-runs. A **passive target** intentionally has no mapping or repair
script; for example, OpenCode owns and populates
`~/.local/share/opencode` while it runs.

## Why bind mounts (and not named volumes)

The project uses **host bind mounts** (`../.env.d/.pi:/home/ubuntu/.pi`)
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
| UID mismatch host ↔ container | Needs care (the project syncs them in `setup.sh`) | Handled by Docker |
| `git status` shows it | Yes (intentionally — see below) | No |

The current `.env.d/` is **not** in `.gitignore`'s default, so `git status`
will list any files you drop there. This is intentional: a file in
`.env.d/` is a deliberate, per-clone, per-checkout piece of state. Use
`git status --ignored` if you also want to see the contents of other
ignored paths.

If at some point the state grows large enough that you don't want it
in the working tree (e.g. multi-GB caches), the natural migration is
**split-by-purpose**: keep the bind mounts for the small, user-facing
config (e.g. `models.json`, `mcp.json`) and add a named volume for
the large, internal caches (e.g. `~/.pi/agent/npm`). The `setup.sh`
permissions logic already handles bind-mount UID alignment; named
volumes are managed by Docker and skip that concern.

## How the repair fires

The `postCreateCommand` in `.devcontainer/devcontainer.json` runs
`bash .devcontainer/setup.sh`. Its relevant ordering is:

```bash
prepare_user_owned_mount_roots # repair exact mount roots before user writes
setup_versioned_configs         # copy missing Pi and OpenCode baseline configs
setup_pi_workspace_trust        # mark the workspace as trusted in trust.json
repair_installed_volumes        # dispatch repair for installer-owned mounts
run_enabled_opencode_installer
```

Docker can create absent bind-mount sources as root-owned directories.
`prepare_user_owned_mount_roots` repairs only the exact user-owned roots:
`~/.pi`, `~/.engram`, `~/.gitconfig-volume`, `~/.local`,
`~/.local/share`, and `~/.local/share/opencode`. Parent paths run before
mounted descendants. The repair never traverses children and rejects an
existing symlink or non-directory before config seeding or installer work.

`repair_installed_volumes` iterates the targets from
`resolve_compose_volume_targets` and, for each one, calls
`compose_target_to_install_scripts` to find the owning scripts. For
each owning script, it runs `bash <script>` with
`DEVCONTAINER_PHASE=runtime`. An empty mapping is an intentional no-op
for passive mounts. For mapped targets, the script's idempotency guard
decides whether the call is a no-op or actually does work.

So the actual "populate the empty bind mount" moment is inside the
runtime-only branches of the install scripts, not in `setup-volumes.sh`
itself. `setup-volumes.sh` is the dispatch; the scripts are the work.

## Adding a new stateful volume (worked example)

Let's say you want to add a PostgreSQL data dir that survives rebuilds.

1. **Add the bind mount** in `.devcontainer/docker-compose.yml`:

   ```yaml
   volumes:
     - ../.env.d/.pi:/home/ubuntu/.pi
     - ../.env.d/.engram:/home/ubuntu/.engram
     - ../.env.d/.postgresql:/home/ubuntu/.postgresql
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

   The output should now show the postgresql target with its owning
   script.

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
volume line in `docker-compose.yml` is well-formed (string form
`source:target[:mode]`, indented under `services."container-svc".volumes:`).

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
