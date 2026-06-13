# Config seeding with `seed_config_tree`

`setup.sh` ships a parallel mechanism for *config files*: a
`seed_config_tree` helper that copies baseline configs from
`.devcontainer/<name>-config/` to their runtime path. It is
copy-on-first-run (idempotent, preserves user customisations across
rebuilds) and auto-escalates to `sudo` for targets outside `$HOME`.

For the comprehensive view (how config seeding, install scripts, and
volume repair interact, plus a worked example), see
[`docs/en/extending.md`](./extending.md).

## The function

```bash
seed_config_tree(source_root, target_root)
```

- **Walks the source tree** under `source_root` (recursively, any
  depth) and copies each file to the equivalent relative path under
  `target_root`.
- **Skips files that already exist at the target** (idempotency).
  The user's customisations are preserved across rebuilds.
- **Auto-escalates to `sudo`** for `mkdir -p` and `cp` when
  `target_root` is outside `$HOME` (e.g. `/etc/postgresql/16/main`,
  `/etc/redis`).
- **No-op** if `source_root` doesn't exist (lets you add the wiring
  before the directory is created).

## Privilege detection

```bash
local needs_sudo=false
if [ "${target_root:0:1}" = "/" ] \
    && [ "${target_root}" != "${HOME}" ] \
    && [ "${target_root#"$HOME"/}" = "${target_root}" ]; then
    needs_sudo=true
fi
```

Three checks, in order:

1. Is the target an absolute path? If it starts with anything else
   (e.g. `~/.pi` or a relative path), it's a HOME path and the
   running user (ubuntu) can write there.
2. Is the target exactly `$HOME`? That's still a HOME path.
3. Does the target start with `$HOME/`? If yes, it's a HOME
   subpath; still no sudo.

If all three are true, the target is genuinely outside `$HOME`
and the helper escalates. The case for absolute system paths
(`/etc/...`, `/usr/local/...`, etc.) is the common one.

## The three cases

### Case 1: a new file in `pi-config/`

You're adding a new Pi agent config or splitting an existing one
into multiple files. No `setup.sh` change, no new wiring — just
drop the file under `pi-config/` with the same relative path it
should have at runtime. The first time the user rebuilds and the
target doesn't exist, the file is copied. After that, the user's
customisations stay put.

```text
# Example: a new Pi agent config
.devcontainer/pi-config/agent/banner-presets.json
#   runtime: ~/.pi/agent/banner-presets.json
```

Commit the file. The next `task container:up` for a fresh clone
copies it; for an existing clone, it stays in `pi-config/` (the
symlink-or-file in `~/.pi/agent/banner-presets.json` was already
populated by some prior build, or by the tool writing it).

### Case 2: a new tool whose config is in `$HOME`

You're adding kubectl, vscode, or any tool whose config lives in
the user's home (e.g. `~/.kube/config`, `~/.config/Code/User/settings.json`).
Three steps:

1. **Create the source root** with the file tree that mirrors the
   tool's runtime config location:

   ```text
   # Example: baseline kubectl config
   .devcontainer/kubectl-config/config
   #   runtime: ~/.kube/config
   ```

2. **Add one line** to `setup_versioned_pi_config` in `setup.sh`:

   ```bash
   setup_versioned_pi_config() {
       seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config" "${HOME}/.pi"
       seed_config_tree "${WORKSPACE_DIR}/.devcontainer/kubectl-config" "${HOME}/.kube"
   }
   ```

3. **Document the choice** in `.devcontainer/README.md`'s "Adding a
   new tool's baseline config" section, so future contributors know
   the wiring exists.

### Case 3: a new tool whose config is in `/etc` (or any system path)

Same as Case 2, but the target is a system path that ubuntu can't
write to. The helper detects this and escalates to `sudo`
automatically — no flag, no extra wiring on your part.

```text
# Example: baseline postgresql config
.devcontainer/postgres-config/16/main/pg_hba.conf
#   runtime: /etc/postgresql/16/main/pg_hba.conf
```

```bash
setup_versioned_pi_config() {
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config" "${HOME}/.pi"
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/postgres-config" "/etc/postgresql/16/main"
}
```

## Idempotency: how it behaves across rebuilds

| Scenario | What happens |
|---|---|
| First run, target dir is empty | Every file is copied. |
| First run, target dir is empty BUT the tool already wrote some files at the target (e.g. `pi` wrote `mcp.json` after a `/login`) | The tool-written files already exist at the target; they stay. Only files the tool hasn't written yet get copied. |
| Subsequent runs | Nothing changes (all targets already exist). |
| User deletes a target file and rebuilds | The file is re-copied from the source (back to baseline). |
| User wants to "reset to defaults" for one file | `rm <target>/<file>` then `task container:up` (or re-run `setup.sh` inside the container). |

The "only copy if missing" rule is what makes the convention safe
for personal customisations: the user's edits to a target file
survive every rebuild until they explicitly delete the file.

## The `*.local` pattern for personal configs

The `pi-config/` tree is shared. If you want to add baseline
configs that are personal to your clone (not committed), use a
`<name>-config.local/` suffix. The pattern `*-config.local/` is in
`.gitignore` so the directory stays untracked. Same wiring as Cases
2 and 3 above; the helper's `if [ ! -d "${source_root}" ]; then return 0`
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

The `|| true` is defensive — the helper's own guard makes it
unnecessary, but it survives if someone later refactors the helper
and forgets to keep the guard.

## Migration from the legacy symlink approach

Earlier builds of this project used `ln -sfn` to symlink the
versioned source into the runtime location. That worked but had
two pain points:

1. Tools that use "atomic replace" to write their config files
   (notably Pi and some MCP servers) silently break the symlink;
   `setup.sh` had to re-link defensively on every postCreate.
2. User customisations were awkward: editing `~/.pi/agent/settings.json`
   meant the file was a symlink, so the user had to `rm` the
   symlink first, and the next rebuild Backs the customised file
   up to a `.devcontainer-backup.TIMESTAMP`.

The current `seed_config_tree` solves both: real files are
unaffected by atomic-replace, and the user can edit them freely
without breaking anything.

For existing users, the symlinks are still in place (their mtime
predates the switch). The new function's `if [ -e ]` guard
correctly leaves them alone. To migrate, delete the symlinks and
re-run `setup.sh`:

```bash
docker exec ${APP_NAME}-run rm -f \
    ~/.pi/agent/settings.json \
    ~/.pi/agent/mcp.json \
    ~/.pi/gentle-ai/banner.json \
    ~/.pi/gentle-ai/models.json \
    ~/.pi/gentle-ai/persona.json
docker exec ${APP_NAME}-run bash /home/ubuntu/${APP_NAME}/.devcontainer/setup.sh
```

After that, all five files are regular files owned by ubuntu and
editable freely.
