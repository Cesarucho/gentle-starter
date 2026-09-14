# Config seeding with `seed_config_tree`

`setup.sh` ships a parallel mechanism for *config files*: a
`seed_config_tree` helper that copies baseline configs from
`.devcontainer/<name>-config/` to their runtime path. It is
copy-on-first-run (idempotent, preserves user customisations across
rebuilds) and auto-escalates to `sudo` for targets outside `$HOME`.
The built-in mappings split `pi-config/` by owner: `agent/` is seeded only
when Pi Coding is enabled, while `gentle-ai/` currently requires both Pi Coding
and core Gentle AI (not Pi Gentle). OpenCode configuration is seeded when enabled, to
`~/.config/opencode/`. Activation uses any valid enabled symlink that
canonically resolves to the corresponding available installer.

## Review and export runtime changes

Runtime configuration can evolve after first-run seeding. For an interactive
review, compare the managed runtime files with the versioned baseline without
changing either tree:

```bash
task config:diff
```

The command reports modified, new, and missing-runtime managed files. It also
reports unmanaged candidates from runtime and seed by path, type, and side.
The same relative candidate path is counted once per group, with at most 50 paths
displayed per group. Unknown directories are reported without descending into
them; excluded state is counted without reading or listing its contents.
Exit status is `0` when the
trees agree, `1` when review is needed, and `2` for manifest, security, or I/O
errors. Automation that relies on those statuses must ask Task to preserve the
helper exit code:

```bash
task --exit-code config:diff
```

After reviewing the report, explicitly export runtime configuration:

```bash
task config:export
git diff -- .devcontainer/opencode-config .devcontainer/pi-config
```

The runtime files are authoritative and are copied byte-for-byte. Export never
deletes seed files: a missing runtime file remains only a report item, including
newly managed seed-only files. Manual seed edits are not export input. A deleted
seed file can reappear from stale runtime configuration on a later explicit
export after the seed deletion has been committed.

Before inspecting runtime roots, export refuses if a participating seed area has
tracked, staged, or untracked changes. Disabled Pi areas and unrelated repository
changes do not block it. All participating roots and planned destinations are
checked before any copies. Replacement is atomic **per file**, not across the
batch: a later I/O failure can leave earlier copies applied. Existing destination
modes are preserved; new files receive mode `0644`.

### Participating configuration groups

Both commands resolve the same groups once, before scanning configuration:

| Group | Runtime → seed | Participation |
| --- | --- | --- |
| OpenCode | `~/.config/opencode/` → `.devcontainer/opencode-config/` | Always |
| Pi Coding | `~/.pi/agent/` → `.devcontainer/pi-config/agent/` | `3030-ai-pi-coding.sh` enabled |
| Pi Gentle | `~/.pi/gentle-ai/` → `.devcontainer/pi-config/gentle-ai/` | `3040-ai-pi-gentle.sh` enabled |

Pi ownership requires a valid `03-enabled/` alias resolving to the canonical
installer, including custom alias names. The shared installer catalog, core,
dependency, and order checks run read-only; no binary/version probes, installer
execution, or automatic installation is involved. Invalid or broken aliases and
Pi Gentle without its Pi Coding dependency are errors, not disabled statuses.

Disabled groups print `skipped` and their runtime and seed roots are not scanned,
even if stale or unsafe. Skips alone do not require review. An enabled group whose
runtime root is absent prints `enabled-runtime-missing` and makes diff return `1`,
even with no seed files; permission or other I/O errors still return `2`. Export
retains seed files and returns `0` on success, including when no copies are needed.

This export ownership intentionally differs from the current bootstrap seeding
gate for `pi-config/gentle-ai/` described above. Bootstrap is unchanged.

### Managed paths and exclusions

Both tasks use the same allowlist and exclusions in
`.devcontainer/config-export.json`, including managed `opencode-notifier.json`
and `opencode-non-sdd.json`. OpenCode `commands/`, `plugins/`, `profiles/`,
`prompts/`, and `skills/` remain recursive: new portable files need no enumeration.
Other root files remain candidates; neither Git tracking nor a `.json` extension
makes them eligible for export. Candidates are never copied automatically.
`opencode.jsonc` is excluded from both tasks and is no longer shipped as a seed;
its unique settings are not merged into `opencode.json`. Existing runtime
`~/.config/opencode/opencode.jsonc` files are left untouched and may remain
active: neither export nor seeding automatically deletes them.

The hidden `.gentle-ai-telemetry-runtime.json` is always excluded; public plugin
source such as `plugins/telemetry-runtime.ts` remains managed configuration.
`.git` (file or directory), `node_modules`, JSONC `opencode.jsonc`, and the hidden
telemetry file are mandatory exclusions at any depth, even if a managed pattern
would match. OpenCode's known credential, session, state, log, cache, and generated
profile-history boundaries are also excluded at any depth. Pi retains its
owner-specific state exclusions. Manifest `**/boundary/**` patterns include the
boundary itself at any depth, including the root and symlink entries, so exclusion
happens before traversal or content reads.

Exclusions override managed patterns. Review every Git
diff before committing because allowlisted configuration may still contain
project-specific or sensitive values.

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

2. **Add one line** to `setup_versioned_configs` in `setup.sh`:

   ```bash
   setup_versioned_configs() {
       # Existing enabled-aware Pi and Gentle AI mappings omitted here.
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
setup_versioned_configs() {
    # Existing enabled-aware Pi and Gentle AI mappings omitted here.
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
setup_versioned_configs() {
    # Existing enabled-aware Pi and Gentle AI mappings omitted here.
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
