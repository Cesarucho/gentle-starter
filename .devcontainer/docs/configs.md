# Config seeding with `seed_config_tree`

`setup.sh` ships a parallel mechanism for *config files*: a
`seed_config_tree` helper that copies baseline configs from
`.devcontainer/config/<name>/` to their runtime path. It is
copy-on-first-run (idempotent, preserves user customisations across
rebuilds) and auto-escalates to `sudo` for targets outside `$HOME`.
The base Pi `config/pi/agent/` mapping is seeded only when Pi Coding is enabled.
No Pi extension packages are provisioned. Gentle Shell activation also seeds
`config/gentle-shell/` to `~/.gentle-shell/` and the selected
`config/pi/gentle-ai/` preferences to `~/.pi/gentle-ai/`, preserving existing files.
OpenCode configuration is seeded when enabled, to
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
git diff -- .devcontainer/config/opencode .devcontainer/config/pi .devcontainer/config/gentle-shell
```

The runtime files are authoritative and are copied byte-for-byte. Export never
deletes seed files: a missing runtime file remains only a report item, including
newly managed seed-only files. Manual seed edits are not export input. A deleted
seed file can reappear from stale runtime configuration on a later explicit
export after the seed deletion has been committed, unless explicitly excluded.
The retired baseline paths listed in the manifest are excluded to prevent that.

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
| OpenCode | `~/.config/opencode/` → `.devcontainer/config/opencode/` | Always |
| Pi Coding | `~/.pi/agent/` → `.devcontainer/config/pi/agent/` | `3030-ai-pi-coding.sh` enabled |
| Gentle Shell | `~/.gentle-shell/` → `.devcontainer/config/gentle-shell/` | `3040-ai-gentle-shell.sh` enabled |
| Pi Gentle AI | `~/.pi/gentle-ai/` → `.devcontainer/config/pi/gentle-ai/` | `3040-ai-gentle-shell.sh` enabled |

Pi ownership requires a valid `03-enabled/` alias resolving to the canonical
installer, including custom alias names. The shared installer catalog, core,
dependency, and order checks run read-only; no binary/version probes, installer
execution, or automatic installation is involved. Invalid or broken aliases are
errors, not disabled statuses.

Disabled groups print `skipped` and their runtime and seed roots are not scanned,
even if stale or unsafe. Skips alone do not require review. An enabled group whose
runtime root is absent prints `enabled-runtime-missing` and makes diff return `1`,
even with no seed files; permission or other I/O errors still return `2`. Export
retains seed files and returns `0` on success, including when no copies are needed.

Pi export manages `settings.json` and the explicitly approved `trust.json`;
legacy MCP and subagent files are not exported. Gentle Shell manages only
`config.json`, `agent/settings.json`, `agent/subagents.json`, `agent/trust.json`,
and `agent/.gentle-shell-home`. Trust includes the owner's broad container grants
(`/home/ubuntu`, and Pi `/tmp`); exports do not narrow or sanitize these grants.
The marker is static creation/version metadata, not authentication state.
Review path portability and trust scope before distributing these files.

Pi Gentle AI manages only `models.json`, `persona.json`, and `profiles.json`.
Native Shell 4 source (`1f35ab1e4ff78f41ce6102cd961e7889a9f1cf69`,
`lib/agent-home.ts`, `lib/agent-profiles.ts`, and `extensions/gentle-ai.ts`)
confirms this default preferences root. `GENTLE_PI_CONFIG_HOME` replaces that
root in native Shell; custom override roots are outside this preset's seeding
and export scope. Shell's agent home does not relocate these shared preferences.
Bare Pi activation alone does not seed or export Gentle AI preferences.

### Managed paths and exclusions

Both tasks use the same allowlist and exclusions in
`.devcontainer/config-export.json`, including managed `opencode-notifier.json`
and `opencode-example.json`. OpenCode `commands/`, `plugins/`, `profiles/`,
`prompts/`, and `skills/` remain recursive: new portable files need no enumeration.
Other root files remain candidates; neither Git tracking nor a `.json` extension
makes them eligible for export. Candidates are never copied automatically.
Retired SDD commands/prompts/skills and shared SDD conventions, the SDD result
plugin, and the removed collaboration/review skill folders are explicitly
excluded. The owner removed four former exclusions: the old default-agent marker
and non-SDD example are root candidates only, while the two removed OpenAI profiles
remain eligible under `profiles/**` if present at runtime. Other files in the
recursive families retain their existing mapping.
`opencode.jsonc` is excluded from both tasks and is no longer shipped as a seed;
its unique settings are not merged into `opencode.json`. Existing runtime
`~/.config/opencode/opencode.jsonc` files are left untouched and may remain
active: neither export nor seeding automatically deletes them.

The root `.gentle-ai-telemetry-runtime.json` and
`plugins/telemetry-runtime.ts` are excluded from diff and export, even if a
versioned seed copy exists. Other managed plugins remain eligible. This does not
change first-run seeding from `.devcontainer/config/opencode/`; neither command
deletes existing seed or runtime files.

`.git` (file or directory), `node_modules`, and JSONC `opencode.jsonc` are mandatory
exclusions at any depth, even if a managed pattern would match.
OpenCode's known credential, session, state, log, cache, and generated
profile-history boundaries are also excluded at any depth. Pi retains its
owner-specific state exclusions. Manifest `**/boundary/**` patterns include the
boundary itself at any depth, including the root and symlink entries, so exclusion
happens before traversal or content reads.

Exclusions override managed patterns. Review every Git
diff before committing because allowlisted configuration may still contain
project-specific or sensitive values.

For the comprehensive view (how config seeding, install scripts, and
volume repair interact, plus a worked example), see
[`extending.md`](./extending.md).

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

### Case 1: a new file in `config/pi/`

You're adding a new Pi agent config or splitting an existing one
into multiple files. No `setup.sh` change, no new wiring — just
drop the file under `config/pi/` with the same relative path it
should have at runtime. The first time the user rebuilds and the
target doesn't exist, the file is copied. After that, the user's
customisations stay put.

```text
# Example: a new Pi agent config
.devcontainer/config/pi/agent/banner-presets.json
#   runtime: ~/.pi/agent/banner-presets.json
```

Commit the file. On the next postCreate setup, a fresh or existing clone
copies it if Pi Coding is active and the target file is absent. An existing
target is left untouched, whether it was seeded previously or written by
the tool.

### Case 2: a new tool whose config is in `$HOME`

You're adding kubectl, vscode, or any tool whose config lives in
the user's home (e.g. `~/.kube/config`, `~/.config/Code/User/settings.json`).
Three steps:

1. **Create the source root** with the file tree that mirrors the
   tool's runtime config location:

   ```text
   # Example: baseline kubectl config
   .devcontainer/config/kubectl/config
   #   runtime: ~/.kube/config
   ```

2. **Add one line** to `setup_versioned_configs` in `setup.sh`:

   ```bash
   setup_versioned_configs() {
       # Existing enabled-aware Pi and OpenCode mappings omitted here.
       seed_config_tree "${WORKSPACE_DIR}/.devcontainer/config/kubectl" "${HOME}/.kube"
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
.devcontainer/config/postgres/16/main/pg_hba.conf
#   runtime: /etc/postgresql/16/main/pg_hba.conf
```

```bash
setup_versioned_configs() {
    # Existing enabled-aware Pi and OpenCode mappings omitted here.
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/config/postgres" "/etc/postgresql/16/main"
}
```

## Idempotency: how it behaves across rebuilds

| Scenario | What happens |
|---|---|
| First run, target dir is empty | Every file is copied. |
| First run, target dir is empty BUT the tool already wrote some files at the target (e.g. `pi` wrote `mcp.json` after a `/login`) | The tool-written files already exist at the target; they stay. Only files the tool hasn't written yet get copied. |
| Subsequent runs | Existing targets stay unchanged; new source files with missing targets are copied when their tool is active. |
| User deletes a target file and rebuilds | The file is re-copied from the source (back to baseline). |
| User wants to "reset to defaults" for one file | `rm <target>/<file>` then `task container:up` (or re-run `setup.sh` inside the container). |

The "only copy if missing" rule is what makes the convention safe
for personal customisations: the user's edits to a target file
survive every rebuild until they explicitly delete the file.

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

Some existing users may still have legacy symlinks. If a link resolves to
an existing file, the new function's `if [ -e ]` guard leaves it alone.
If you have these links and want regular files instead, remove only the
confirmed legacy links and re-run `setup.sh`:

```bash
docker exec ${APP_NAME}-run rm -f ~/.pi/agent/settings.json
docker exec ${APP_NAME}-run bash /home/ubuntu/${APP_NAME}/.devcontainer/setup.sh
```

After that, the base settings file is a regular file owned by ubuntu and
editable freely. Existing extension configuration is not removed or reseeded.
