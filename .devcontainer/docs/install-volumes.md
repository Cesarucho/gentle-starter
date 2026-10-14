# Volumes and the install contract

This document is the deep reference for the stateful-volume contract.
Installer-owned targets tie together the ordered selected Compose files,
`lifecycle/setup-volumes.sh`, and the `install/available/` scripts. Passive
state mounts use only Compose because no installer owns or populates
them. The TL;DR lives in the header of `lifecycle/setup-volumes.sh` and in the
output of `task install:volumes`.

See [optional integrations](./optional-integrations.md) for selection, schema-3
semantic identity, legacy migration, and host socket prerequisites. Runtime repair
uses the applied, integrity-checked snapshot without rereading live env or Compose.
`task install:volumes` reports the last host-prepared snapshot, not current desired
configuration or proof of applied mounts.

> **Looking for the comprehensive view?** Start at
> [`extending.md`](./extending.md), which covers install,
> volumes, and configs together with a worked example and the FAQ.
> This file is the deep dive on the volume contract only.

## Sister contract: config seeding

`setup.sh` ships a parallel mechanism for *config files*: a
`seed_config_tree` helper that copies baseline configs from
`.devcontainer/config/<name>/` to their runtime path. It is
copy-on-first-run (idempotent, preserves user customisations) and
auto-escalates to `sudo` for targets outside `$HOME`. The convention
is documented in [`configs.md`](./configs.md); the rationale is
identical to this one (the source tree IS the manifest).

## The contract in one diagram

```text
selected Compose → host manifest .devcontainer/lifecycle/setup-volumes.sh
┌──────────────────────────────┐         ┌─────────────────────────────────┐
│ services.container-svc       │         │ resolve_compose_volume_targets │
│   volumes:                   │ ──────▶ │   validates the manifest,     │
│     - type/source/target/bind   │         │   emits alternating NUL-      │
│       long-syntax entries      │         │   terminated source, target   │
│     - .../opencode/share:...    │         │ compose_target_to_install_     │
└──────────────────────────────┘         │   scripts(target) -> [names]   │
                                         │                                 │
                                         │ repair_installed_volumes        │
                                         │   filters owners through        │
                                         │   core/optional active aliases  │
                                         │   active owner at runtime       │
                                         └──────────────┬──────────────────┘
                                                        │
                                                        ▼
                                         .devcontainer/install/available/
                                         ┌─────────────────────────────────┐
                                         │ 3010-ai-engram.sh               │
                                         │ (yours here)                    │
                                         └─────────────────────────────────┘
```

For an **installer-owned target**, four pieces participate: the bind mount,
the potential-owner mapping, the available installer, and an active symlink in
`02-core-tools/` or `03-enabled/`. `compose_target_to_install_scripts` deliberately keeps listing
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
- `ls -la .env.d/.engram/` from a host terminal.
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
setup_versioned_configs         # copy enabled tools' missing baseline configs
setup_pi_workspace_trust        # mark the workspace as trusted in trust.json
repair_installed_volumes        # run the enabled Engram state owner
DEVCONTAINER_PHASE=runtime bash 4010-tool-ssh-server.sh  # installer + override enabled
start-sshd                      # after SSH runtime preparation
```

OpenCode's binary is installed in the image. At runtime,
`setup_versioned_configs` seeds its missing configuration only when the
canonical OpenCode installer is enabled; it does not install or update the
binary.

Dev Containers runs with `remoteUser: ubuntu`; its numeric UID projection aligns
the prepared host directories with the container development user. The project
does not use `HOST_UID` or `HOST_GID` build plumbing.
`HOST_UID` is only a host-generated locator for the optional Pulse socket.

`repair_installed_volumes` iterates the targets from
`resolve_compose_volume_targets` and, for each one, calls
`compose_target_to_install_scripts` to find the potential owning scripts. It
then checks both alias groups and runs only active owners with
`DEVCONTAINER_PHASE=runtime`. An empty mapping is an intentional no-op for
passive mounts, while a mapped but disabled owner is intentionally skipped.
For active owners, the script's idempotency guard decides whether the call is a
no-op or actually does work.

The `.pi` bind is passive. Pi Coding remains image-owned and is not dispatched
by volume repair. Existing Pi packages and configuration in `.env.d/.pi` are
preserved; retirement of repository provisioning is not a user-state purge.

So the actual "populate the empty bind mount" moment is inside the
runtime-only branches of the install scripts, not in `lifecycle/setup-volumes.sh`
itself. `lifecycle/setup-volumes.sh` is the dispatch; the scripts are the work.

## Exact-directory runtime permissions

Use [runtime-directory-permissions.json](../config/runtime-directory-permissions.json)
for directories that must retain a specific mode after mounts are available.
The default rules select three exact workspace directories at `0700`, each with
`missing: "skip"`: `.git/gentle-ai/review-mode/rar-authority`, its `v1` child,
and its `v1/rdd-mode` child. Absent directories are never created, and authority
contents are never read. The same policy also
declares SSH child creation, explicitly conditional on installer activation:

```json
{
  "version": 1,
  "rules": [
    {
      "root": "workspace",
      "path": ".git/gentle-ai/review-mode/rar-authority",
      "mode": "0700",
      "missing": "skip"
    },
    {
      "root": "workspace",
      "path": ".git/gentle-ai/review-mode/rar-authority/v1",
      "mode": "0700",
      "missing": "skip"
    },
    {
      "root": "workspace",
      "path": ".git/gentle-ai/review-mode/rar-authority/v1/rdd-mode",
      "mode": "0700",
      "missing": "skip"
    },
    {
      "root": ".env.d/.ssh-server",
      "path": "ssh",
      "mode": "0700",
      "missing": "create",
      "when": {"enabled_installer": "4010-tool-ssh-server.sh"}
    }
  ]
}
```

| Field | Contract |
| --- | --- |
| `root` | `workspace`, or an exact managed source identifier such as `.env.d/.gentle-ai` from the applied Compose manifest |
| `path` | Nonempty relative exact directory, not the root itself; no absolute paths, empty components, `.` or `..` |
| `mode` | Four-character ordinary octal text, `0000` through `0777`; no special bits |
| `missing` | `skip` leaves absent paths alone; `create` provisions only explicitly declared directories. Only `ENOENT` is treated as absence. |
| `when` | Optional exact object `{"enabled_installer": "4010-tool-ssh-server.sh"}` for managed roots. Names must identify a real canonical catalog installer; activation uses valid canonical aliases, including custom names. Unknown names or condition fields are errors even when disabled. |

Each rule selects one literal directory path: no glob expansion, recursive mode
changes, or file-mode management. For example, `gen-*.json` would name a literal
directory, not matching files; file modes remain the file producer's responsibility.
Declare each directory separately; grouped declarations are unsupported.
Nested rules still require safe existing ancestors during full preflight. An
unsafe ancestor fails closed before any mode changes, even if another rule would
make that ancestor private; the policy is not ancestor recovery.

A disabled installer makes its conditional rule **not applicable**, independently
of Compose selection. An enabled installer requires its writable managed root in
the validated applied manifest; an absent or invalid target fails before setup
normalization. Unconditional unknown roots always fail. Conditions do not enable
tools or select Compose overrides. Duplicate and unsafe parent declarations are
checked before applicability filtering.

For a managed bind, a rule such as `root: ".env.d/.gentle-ai"`,
`path: "private-cache"` selects `private-cache` under that bind's **container
target**, not its host path. The manifest must pass snapshot integrity and the
container's `DEVCONTAINER_BIND_MANIFEST_ID` applied-identity gate. Read-only,
external and file mounts are not repair roots. Duplicate JSON keys, duplicate
source mappings, cross-root aliases and crossings into other mounts fail closed.
Parent-child rules within one root are allowed, but a configured parent cannot
be group/world writable. Every missing intermediate needed by `create` must
have its own `missing: "create"` rule; there is no implicit `mkdir -p`.
Workspace rules cannot bypass mount restrictions through `.env.d` source paths.

For example, creating both `private-cache` and its `index` child requires two
rules (their order does not matter):

```json
{
  "version": 1,
  "rules": [
    {"root": ".env.d/.gentle-ai", "path": "private-cache", "mode": "0700", "missing": "create"},
    {"root": ".env.d/.gentle-ai", "path": "private-cache/index", "mode": "0750", "missing": "create"}
  ]
}
```

The helper traverses pinned directory descriptors with `O_NOFOLLOW` and
`O_DIRECTORY`, verifies owner and ancestor safety, validates the entire plan,
then creates missing declared nodes relative to pinned parents with a restrictive
umask and initial mode `0700`. It retains their descriptors and finalizes exact
modes deepest-first after all children are constructed, including `0000` parents
and children. Existing directories receive only the selected exact mode; no
descendant permissions are recursively repaired. Target directories must belong
to the runtime user. Ancestors cannot be group/world writable; absolute system
ancestors may belong to root, including root-owned sticky temporary parents.
Symlink components, wrong types, unexpected owners and permission-denied errors
are failures, not missing-path skips. A file-based `.git` worktree is explicitly
unsupported for the default rule; external Git metadata is never modified.
An unreadable leaf requiring a mode change fails without privilege escalation;
an already-correct `0000` leaf is a metadata-only no-op.
Existing inaccessible parents are not temporarily opened up for traversal or
creation. `validate` and `exclusions` never create directories or change modes.

The helper rechecks ownership, ancestor safety and pinned inode identities before
mutation. Concurrent creation collisions are errors, not entries to adopt;
detected replacements and symlinks fail closed. This is **not a transaction or
full race immunity**: a later error can leave newly created private directories
or already-finalized modes behind, and same-user replacements in narrow syscall
windows cannot all be excluded. It does not delete directories or roll back modes.

During **CONTAINER postCreate**, setup obtains validated exclusions before any
generic normalization. It protects complete policy subtrees (including absent
ones), managed bind-source roots and workspace-contained mount targets from
workspace `chown`, `chmod` and tracked-mode restoration. It applies the policy
after those passes and specialized SSH root recovery, except installer-owned
child application described below. Normalization elsewhere remains unchanged. Descendant modes,
file contents, ownership and host-prepared bind-root modes are preserved.
Exclusions also protect the first absent parent component, so normalization cannot
later rewrite a newly appearing ancestor of a declared subtree.

Automatic policy application occurs only during **CONTAINER postCreate setup**,
on creation/recreation. Later starts and **HOST `task container:restart`** do not
run the permission helper; restart preserves the same container's existing
behavior. A directory skipped because it was missing remains untouched if it is
created later, until the next setup invocation. This is setup-time policy
application, not continuous enforcement.

To validate without changing modes, run inside the **CONTAINER**, using its actual
workspace path:

```bash
python3 .devcontainer/lifecycle/runtime-directory-permissions.py validate "$PWD"
```

### Scoped SSH child provisioning

The optional SSH installer selects `.env.d/.ssh-server` rules from the unified
policy with `--root`, only after the enabled SSH/applied-manifest gate passes.
It creates only `ssh`
under the writable managed `.env.d/.ssh-server` target at `0700`, before host-key
generation. Its explicit condition makes disabled SSH harmless to ordinary setup,
whether or not the optional mount is selected.

Runtime `SSH_CONFIG_DIR` must exactly match the validated applied target; an
unbound override fails before root chmod, directory creation, keys or configuration
writes. Root ownership, type and ancestors are checked without following symlinks;
the installer separately retains its root privacy `chmod 0700` recovery. Setup
uses validation-only `--defer-root .env.d/.ssh-server` to validate that owned root
and its children before normalization without requiring root privacy already be
recovered. No other ancestor checks are relaxed; workspace privacy cannot be
deferred. General application excludes this root with `--exclude-root`, leaving
recovery and child application to SSH preparation. The installer repeats dry-run
validation with `--expected-root SOURCE=TARGET` before any mutation and applies
only its selected root after recovery; unrelated authority rules are not reapplied.
`--defer-root` is refused for `apply`. Cross-root mapping and boundary validation
and filesystem validation still cover all applicable declarations before subset
selection. Unselected symlinks, wrong types, owners and unsafe ancestors block
SSH preparation before root recovery. Full-policy descriptors remain metadata-only
and pinned for a safety recheck before selected application; unselected exact modes
are never applied. General setup application follows specialized SSH recovery so
it can validate every root strictly, before service startup. The
scoped helper never changes bind roots. `~/.ssh` authorization preparation,
local-parent ownership recovery, host bind provisioning and build installation
remain separate. There is no legacy unbound-override fallback.

The general policy is not host bind provisioning, recursive repair or
ownership recovery. Correct unsafe ancestors or unsupported layout deliberately
as the owner; do not use `sudo` or full setup merely to silence a policy failure.

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
      .devcontainer/install/available/7100-data-postgresql.sh
   ```

   Fill the script and preserve mode `0755`. Make build-time installation
   idempotent and runtime repair safe as ubuntu: a binary-presence guard
   alone cannot populate an empty data mount. Follow the installer's version
   policy and declare any prerequisites in `dependencies.conf`.

3. **Add the target-to-script mapping** in
   `.devcontainer/lifecycle/setup-volumes.sh` (the `case` block in
   `compose_target_to_install_scripts`):

   ```bash
    "/home/ubuntu/.postgresql")
        scripts_ref+=("7100-data-postgresql")
        ;;
   ```

4. **Enable the optional script** through the activation helper:

   ```bash
    task install:enable -- 7100-data-postgresql
   ```

5. **Verify the live contract**:

   ```bash
   task install:volumes
   ```

   The output should now show the postgresql target with its potential owning
   script. Its valid `03-enabled/` symlink makes it active for postCreate
   repair.

6. **Rebuild and validate**:

   ```bash
   task container:rebuild
   task container:up
   ```

   The build log should include a `Running: .../7100-data-postgresql.sh`
   line during build, and the postCreate log should include a
   `Volume repair: /home/ubuntu/.postgresql -> 7100-data-postgresql.sh`
   line when the target is in the applied manifest. Confirm the installer's
   runtime branch actually initializes missing state; dispatch alone does
   not prove the data directory was populated.

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
docker exec ${APP_NAME}-run cat ~/.pi/agent/settings.json
```

Or from the host:

```bash
ls -la .env.d/.engram/
cat .env.d/.pi/agent/settings.json
```

(The host-side path is exactly the bind-mount source path.)
