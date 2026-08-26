# `.devcontainer/`

Devcontainer configuration. Read this top-down.

For deep-dive material (the install/ convention, the volume
contract, config seeding, the FAQ), start at
[`docs/en/extending.md`](../docs/en/extending.md) and follow the
links from there.

## What's in here

| Path | Purpose |
|---|---|
| `Dockerfile` | Base image + build-time setup. Iterates `install/01-core/`, `install/02-enabled/`, `install/03-hooks/` in order. |
| `devcontainer.json` | VS Code Dev Containers integration. `postCreateCommand` runs `setup.sh`. |
| `docker-compose.yml` | Service definition. Stateful bind mounts live here. |
| `install/` | Build-time install scripts. See `docs/en/install-tree.md`. |
| `test/` | BATS test suite. Run `task test:all` to verify the environment. |
| `pi-config/` | Versioned baseline config for Pi and Gentle-AI. Seeded to `~/.pi/` on first run. |
| `opencode-config/` | Versioned baseline config for OpenCode. Seeded to `~/.config/opencode/` on first run. |
| `setup.sh` | postCreate entry point. Handles workspace permissions, config seeding, Pi workspace trust, gitconfig wiring. |
| `setup-volumes.sh` | Sourced by `setup.sh`. Owns the bind-mount → install-script repair contract for installer-owned state. |
| `Taskfile.yml` (sibling) | Root project task entry. Includes `container:`, `install:`, etc. |

## The three systems

The devcontainer has three extension surfaces:

1. **Install scripts** (`install/`) — build-time tools and
   dependencies. Adding a new tool or a new runtime lands here.
   Deep dive in [`docs/en/install-tree.md`](../docs/en/install-tree.md).

2. **Stateful volumes** (`docker-compose.yml` + `setup-volumes.sh`)
   — bind mounts that survive rebuilds. Installer-owned targets trigger
   their repair scripts; passive state mounts persist without repair.
   Deep dive in [`docs/en/install-volumes.md`](../docs/en/install-volumes.md).

3. **Config files** (`<name>-config/` + `seed_config_tree` in
   `setup.sh`) — versioned baseline configs copied to the runtime
   path on first run. Deep dive in
   [`docs/en/configs.md`](../docs/en/configs.md).

The comprehensive view (how the three systems interact, a worked
example adding Redis end-to-end, and the FAQ) is in
[`docs/en/extending.md`](../docs/en/extending.md).

## Adding a new tool's baseline config (the short version)

For the full convention, see
[`docs/en/configs.md`](../docs/en/configs.md). The one-paragraph
version:

1. Create `.devcontainer/<name>-config/` with the file tree that
   mirrors the tool's runtime config location.
2. Add a `seed_config_tree` call to `setup_versioned_configs()`
   in `setup.sh` with the absolute target. Targets outside `$HOME`
   auto-escalate to `sudo` — no flag needed.

Example: adding a baseline postgresql config:

```text
.devcontainer/postgres-config/16/main/pg_hba.conf
#   runtime: /etc/postgresql/16/main/pg_hba.conf
```

```bash
# in setup.sh
seed_config_tree "${WORKSPACE_DIR}/.devcontainer/postgres-config" "/etc/postgresql/16/main"
```

For personal, non-versioned additions, use a `<name>-config.local/`
suffix (gitignored, see the parent `.gitignore`).
