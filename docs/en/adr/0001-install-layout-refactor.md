# ADR 0001: Install-layout refactor

**Status:** Accepted, 2026-06-11
**Supersedes:** the legacy `.devcontainer/scripts/` layout and the
`ln -sfn` config-seeding pattern in `setup.sh`

## Context

Before this refactor, the devcontainer had three issues that
compounded over time:

1. **No opt-in mechanism.** Every script in
   `.devcontainer/scripts/` ran on every build. There was no way
   to enable or disable a script without editing the Dockerfile
   or moving files.
2. **No shared helpers.** Each script reimplemented the same
   idioms (`dpkg --print-architecture`, `curl -fsSL`, `sudo`/root
   toggling, `set -euo pipefail`).
3. **Pi config was a symlink that kept breaking.** Several tools
   (notably Pi and some MCP servers) write their config files
   with "atomic replace" semantics, which silently turns the
   symlink at `~/.pi/agent/mcp.json` into a regular file on
   first write. `setup.sh` had a defensive re-link dance
   (`setup_versioned_pi_config` was called twice in the
   pipeline) to paper over this.

The project also lacked any way to add baseline configs for new
tools (Redis, kubectl, vscode, etc.) without editing
`setup.sh` to add a hardcoded `(source, target)` pair per file.

## Decision

The refactor introduced the following coordinated changes, all
landing in commits `f5e9679` through `c11d975` plus follow-ups.

### 1. Three-group runtime layout under `install/`

```text
.devcontainer/install/
├── 01-core/                # mandatory, runs in every build
├── 02-enabled/             # symlinks to active available/ scripts
├── 03-hooks/               # user extensions (intentionally not gitignored)
├── available/              # opt-in catalog (numbered 00-99, .disabled suffix)
├── lib/                    # shared helpers (common.sh)
└── templates/              # install-script.sh template
```

The Dockerfile iterates `01-core/`, `02-enabled/`, `03-hooks/`
in that order (`for group in 01-core 02-enabled 03-hooks`). Within
each group, scripts are sorted by filename; the numeric prefix on
each script controls the in-group order. The group prefixes
themselves (`01-`, `02-`, `03-`) are a visual hint, not
load-bearing for ordering.

The `find` uses `-L` to follow symlinks, which is how
`02-enabled/` (all symlinks) actually gets the script bodies to
run.

### 2. `lib/common.sh` with a re-source guard

13 helpers: phase detection, architecture normalization, command
checks, fetch + integrity, privilege escalation, install, logging.
The re-source guard at the top makes the file safe to source from
any script multiple times. See the header comment in
`lib/common.sh` for the full contract.

### 3. `templates/install-script.sh`

The canonical starting point for new install scripts. Shebang,
`set -euo pipefail` (with a documented carve-out for SDKMAN
subshells), `: "${VAR:=default}"` for variables, idempotency
guard via `devcontainer_has_cmd`, install + verify sections. Copy,
fill, validate, place in `available/`.

### 4. `seed_config_tree` for config seeding (copy, not symlinks)

Replaces the legacy symlink-based config seeding. Walks the source
tree, copies each file to the equivalent path under the target,
but only if the target does NOT already exist (idempotent,
preserves user customizations). When the target is outside
`$HOME` (e.g. `/etc/postgresql/16/main`, `/etc/redis`), the helper
escalates to `sudo` for `cp` and `mkdir` automatically.

The `seed_config_tree` helper is the single building block for
config seeding. Adding a new tool's baseline config = create
`<name>-config/` + add one `seed_config_tree` call to
`setup_versioned_pi_config` in `setup.sh`. The source tree IS
the manifest.

### 5. `setup-volumes.sh` extracted from `setup.sh`

The volume-repair contract (parse `docker-compose.yml` for bind
mounts, map target paths to owning install scripts, re-run those
scripts at runtime) lived in `setup.sh` and was opaque. It now
lives in its own file (`.devcontainer/setup-volumes.sh`) which
`setup.sh` sources. The header of `setup-volumes.sh` documents
the three-piece contract (compose volume + case in
`compose_target_to_install_scripts` + install script) and the
step-by-step for adding a new stateful volume.

### 6. Library version defaults in scripts, not in the Dockerfile

The Dockerfile's `ENGRAM_VERSION`, `NODE_MAJOR`, and
`PLAYWRIGHT_VERSION` ARGs lost their defaults. The canonical
default now lives in the install script that consumes the value
(30-ai-engram.sh, 20-runtime-node.sh, etc.). The ARGs remain so
users can still override via `docker build --build-arg VAR=...`,
and the runtime `ENV` propagation still works. The locale
(`LOCALE`) and timezone (`TZ`) ARGs keep their defaults because
they set the runtime `LANG`/`LC_ALL`/`TZ` ENVs, which a script
cannot reach.

### 7. `devuser` removed

The project uses `ubuntu` as the single devcontainer identity.
The `HOST_UID`/`HOST_GID` ARGs in the Dockerfile and the
`devuser` creation block in `90-post-setup-users.sh` were
removed.

### 8. Dead `PLATFORM_ARCH` removed

The `PLATFORM_ARCH` ARG and its matching `ENV` had no consumer
anywhere in the project. Removed.

### 9. `install/03-hooks/` intentionally NOT gitignored

Scripts dropped in `03-hooks/` show up in `git status`. The
user can decide what to do (commit as project-level opt-in by
moving to `available/`, or leave untracked as personal).
Rationale: tools like `git status --ignored` are sufficient for
the user who wants to ignore the directory's contents.

### 10. Discoverability layer

Four surfaces catch a contributor at different moments:

- `install/templates/install-script.sh` — a "State and volumes"
  section in the header.
- `.devcontainer/docker-compose.yml` — a comment above
  `volumes:` pointing to `setup-volumes.sh` and
  `task install:volumes`.
- `task install:volumes` — prints the live bind-mount →
  owning-script contract.
- `docs/install-volumes.md` — the deep reference.

The same discoverability pattern was later applied to the
config-seeding system (`docs/configs.md`, the `seed_config_tree`
helper, etc.).

### 11. Documentation under `docs/en/` (with `docs/es/` mirror)

`docs/en/` is canonical; `docs/es/` is the Spanish translation.
Files: `README.md` (index), `extending.md` (the comprehensive
guide), `install-tree.md`, `install-volumes.md`, `configs.md`.
Plus `AGENTS.md` at the repo root for AI-facing context.

## Consequences

### Positive

- **Extensibility.** Adding a new tool (install + config + volume)
  is now a matter of three files in known places plus one or
  two `seed_config_tree` calls. No more hand-editing
  `setup.sh` with hardcoded pairs.
- **Idempotency.** All three systems are idempotent: install
  scripts use `devcontainer_has_cmd` guards, the config seeder
  uses `if [ -e ]` skips, the volume repair re-runs scripts
  with `DEVCONTAINER_PHASE=runtime` and lets each script's
  idempotency guard decide. A rebuild is a no-op for any state
  that's already correct.
- **Discoverability.** Four surfaces (template header, compose
  comment, `task install:volumes`, deep doc) catch a
  contributor at different moments of the journey. AGENTS.md
  at the repo root gives any coding agent the high-level
  context in one read.
- **No more symlink dance.** `seed_config_tree` creates real
  files. Atomic-replace by tools no longer breaks anything. The
  pipeline can call `setup_versioned_pi_config` once, not twice.

### Trade-offs accepted

- **Source files in `install/` are mode 0755.** The workspace
  is bind-mounted into the devcontainer, so the Dockerfile's
  `chmod 0755` over the COPY target also affects the source
  tree. This is by design, not a bug, but it means every
  `git status` after a rebuild shows a mode change on every
  install script.
- **No auto-update of user customizations.** If the project
  updates `pi-config/agent/mcp.json` upstream, users who have
  edited their `~/.pi/agent/mcp.json` don't get the update (the
  seeder respects the existing file). This is deliberate: the
  project is a starter, not a SaaS; users fork and customize.
  A `task pi:diff-config` was proposed to help with this but
  the user opted out.
- **Bind mounts, not named volumes.** The project uses
  host bind mounts for `~/.pi`, `~/.engram`, etc. so the user
  has direct physical access (`cat env/.pi/agent/mcp.json`,
  `cp -r env/ backup/`). The trade-off: state lives in the
  working tree (per-clone, not per-machine) and is in
  `.gitignore`. A `task env:backup` / `task env:restore` pair
  was designed and tested but the user chose to defer it.
- **Three `install/03-hooks/` files in `git status`.** Scripts
  dropped there are not auto-ignored. Trade-off accepted for
  explicit visibility.

### Deferred (not part of this decision)

- `task env:backup` and `task env:restore` — designed, tested,
  reverted at the user's request. The conversation history has
  the full design.
- `task pi:diff-config` — proposed, opted out.
- Spanish translation of `docs/en/install-volumes.md` and
  `.devcontainer/README.md` — decided against.
- OpenSpec adoption (`openspec/changes/...`) — the user
  explicitly chose to keep `openspec/` untracked for now.

## Verification

The refactor was validated at multiple points:

- `task install:up` rebuilds the image and runs the postCreate
  hook. The 13 build-phase `Running:` lines fire in the right
  order; 3 `Volume repair:` lines fire in the postCreate log.
- All 14 tools present in the container after rebuild: `curl`,
  `jq`, `git`, `task`, `node`, `npm`, `pnpm`, `go`, `gofmt`,
  `java`, `javac`, `pi`, `engram`, `skills`.
- `task validate` and `task validate:full` both exit 0 with
  0 errors, 0 warnings.
- `task install:volumes` prints the live contract.
- `task install:list` prints the active scripts and enabled
  symlinks.
- `task install:doctor` reports `ok: install layout`.

The pre-refactor baseline (the original Fase 0 of the spec) had
the same 14-tool set. The refactor is behavior-preserving for
the existing build; it changes the layout, the extensibility
surface, and the postCreate wiring, but not the tool set.
