# `.devcontainer/`

Devcontainer configuration. The files here describe what the
container looks like, what gets installed, and what base configs
are seeded at startup. Read this top-down.

## What's in here

| Path | Purpose |
|---|---|
| `Dockerfile` | Base image + build-time setup. `COPY install/` and the `for group in 01-core 02-enabled 03-hooks` loop run the install scripts. |
| `devcontainer.json` | VS Code Dev Containers integration. `postCreateCommand` runs `setup.sh`. |
| `docker-compose.yml` | The service definition. Stateful bind mounts live here. See [Bind mounts and the volume contract](#bind-mounts-and-the-volume-contract). |
| `install/` | Build-time install scripts. See [The install tree](#the-install-tree) and `docs/install-volumes.md`. |
| `pi-config/` | Versioned baseline config for Pi and Gentle-AI. Seeded to `~/.pi/` on first run. |
| `setup.sh` | postCreate entry point. Handles workspace permissions, Pi config seeding, Pi workspace trust, gitconfig wiring. |
| `setup-volumes.sh` | Sourced by `setup.sh`. Owns the bind-mount → install-script repair contract. |
| `Taskfile.yml` (sibling) | Root project task entry. Includes `container:`, `install:`, etc. |

## The install tree

```text
install/
├── 01-core/         # mandatory, runs in every build
├── 02-enabled/      # symlinks to active available/ scripts
├── 03-hooks/        # user extensions (read its README before adding)
├── available/       # opt-in catalog (numbered 00-99, .disabled suffix)
├── lib/             # shared helpers (common.sh, sourced by every script)
└── templates/       # install-script.sh template for new scripts
```

Build phase iterates `01-core/`, then `02-enabled/`, then `03-hooks/`,
each sorted by filename. Available/ is the catalog; only the symlinks
in `02-enabled/` actually run. See `install/03-hooks/README.md` and
`docs/install-volumes.md` for the deeper contracts.

## Bind mounts and the volume contract

The `volumes:` block under `services.container-svc` lists stateful
bind mounts (`../env/.pi:/home/ubuntu/.pi` and friends). At postCreate,
`setup-volumes.sh` parses the block and re-runs the install scripts
that own each target with `DEVCONTAINER_PHASE=runtime`. The contract
has three pieces that all have to agree:

1. The bind mount itself (in `docker-compose.yml`).
2. The target-to-script mapping (in `compose_target_to_install_scripts`
   inside `setup-volumes.sh`).
3. The install script (in `install/available/`, optionally linked from
   `02-enabled/`).

Run `task install:volumes` to see the live contract. See
`docs/install-volumes.md` for the full picture.

## Adding a new tool's baseline config

The convention is "the source tree under `.devcontainer/` IS the
manifest". For each tool you want to baseline, create a
`<name>-config/` directory with the file tree that mirrors the
tool's runtime config location, then add a one-line `seed_config_tree`
call to `setup_versioned_pi_config()` in `setup.sh`. Three cases:

### Case 1: a new file under the existing `pi-config/`

Zero edits to `setup.sh`. Just drop the file under `pi-config/` with
the same relative path it should have at runtime. On the next
`task container:up`, if the runtime target doesn't exist, it gets
copied. If it already exists (user customisation), it stays.

```text
# Example: add a new Pi agent config
.devcontainer/pi-config/agent/banner.json   <-  runtime: ~/.pi/agent/banner.json
```

### Case 2: a new tool whose config is in $HOME

Add a source root, add a `seed_config_tree` call with `HOME` as the
target root (no sudo needed).

```text
# Example: baseline kubectl config
.devcontainer/kubectl-config/config    <-  runtime: ~/.kube/config
```

In `setup.sh`:

```bash
setup_versioned_pi_config() {
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config" "${HOME}/.pi"
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/kubectl-config" "${HOME}/.kube"
}
```

### Case 3: a new tool whose config is in /etc (or any system path)

Same as Case 2, but the target is an absolute system path. The
helper detects the path is outside `$HOME` and escalates to `sudo`
for the copy and the directory creation.

```text
# Example: baseline postgresql config
.devcontainer/postgres-config/16/main/pg_hba.conf   <-  runtime: /etc/postgresql/16/main/pg_hba.conf
```

In `setup.sh`:

```bash
setup_versioned_pi_config() {
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config" "${HOME}/.pi"
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/postgres-config" "/etc/postgresql/16/main"
}
```

### Idempotency: how it behaves across rebuilds

`seed_config_tree` is idempotent. It only copies a file if the
target does NOT already exist. Concretely:

| Scenario | What happens |
|---|---|
| First run, target dir is empty | Every file is copied. |
| First run, target dir is empty BUT the user has run the tool before (e.g. logged in with `pi`, which writes `mcp.json` and `trust.json`) | The tool-written files already exist at the target; they stay. Only files the tool hasn't written yet get copied. |
| Subsequent runs | Nothing changes (all targets already exist). |
| User deletes a file at the target and rebuilds | The file is re-copied from the source (back to baseline). |
| User wants to "reset to defaults" for a file | `rm <target>/<file>` then `task container:up`. |

The "only copy if missing" rule is what makes the convention safe
for personal customisations: the user's edits to a target file
survive every rebuild until they explicitly delete the file.

## Personal config additions (gitignored)

The `pi-config/` tree is shared. If you want to add baseline configs
that are personal to your clone (not committed), use a
`<name>-config.local/` suffix. The pattern `*-config.local/` is in
`.gitignore` so the directory stays untracked. Same wiring as Case 2
or 3 above; the helper's `if [ ! -d "${source_root}" ]; then return 0`
silently handles a missing local source root, so the line can be
added even before the directory exists.

```bash
setup_versioned_pi_config() {
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config" "${HOME}/.pi"
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/postgres-config" "/etc/postgresql/16/main"
    # Personal: not committed, exists only on this clone.
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config.local" "${HOME}/.pi" || true
}
```

## How to verify what gets seeded

After a `task container:up`, the build log shows the files that
were copied for the first time. The runtime side: `task install:volumes`
prints the volume contract; for config seeding there's no equivalent
task yet (open `setup.sh` to see the current list of seeded
directories).
