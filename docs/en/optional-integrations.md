# Select optional container integrations

Use `task container:*` on the host to prepare, create, and recreate the container.
IDEs may attach afterward; Reopen/Rebuild in Container and `initializeCommand`
are not supported creation paths.

## Quick path

1. Uncomment the required files in the ordered `dockerComposeFile` array in
   `.devcontainer/devcontainer.json`. Keep the base first and
   `compose-config/docker-compose-core-tools.yml` immediately afterward.
2. Enable any required catalog installer separately with `task install:enable`.
   Installer enable/disable does **not** select Compose files.
3. Run `task container:restart` for mount/environment changes, or
   `task container:rebuild` when changing installed packages. Attach your IDE again.

| Compose file | Purpose | Installer requirement |
| --- | --- | --- |
| `compose-config/docker-compose.pi.yml` | Persist `.env.d/.pi`; never installs Pi | Enable Pi Coding and optionally Pi Gentle |
| `compose-config/docker-compose.codegraph.yml` | Persist the root project's SQLite index | Enable `3060-ai-codegraph`; initialize manually |
| `compose-config/docker-compose.ssh-agent.yml` | Host agent socket and `SSH_AUTH_SOCK=/ssh-agent` | Default OpenSSH client; no server required |
| `compose-config/docker-compose.ssh-server.yml` | SSH port and persisted host keys | Enable `4010-tool-ssh-server` and rebuild |
| `compose-config/docker-compose.audio.yml` | Host Pulse socket and `PULSE_SERVER=unix:/pulse-native` | Enable `4100-tool-pulseaudio-utils` for `paplay` and rebuild |

The base retains image/build, service identity, application port, environment,
and the applied-manifest identity. The active core-tools override owns the four
existing Gentle AI, Engram, OpenCode and Git configuration binds plus the OpenCode
port. Moving overrides into `compose-config/` does not change relative sources:
Compose resolves them from the first file's `.devcontainer/` directory, not the
override directory. Existing SSH/audio selections remain active; Pi and CodeGraph
start disabled. Recreate through Task after this file-layout change even though
existing mount sources and targets are unchanged. No data is migrated.
Existing Pi data is never deleted when disabled. Pi configuration is seeded only
with Pi Coding enabled; Gentle AI alone does not create `~/.pi/gentle-ai`.

## Optional CodeGraph

1. Run `task install:enable -- 3060-ai-codegraph`.
2. Uncomment `./compose-config/docker-compose.codegraph.yml` in
   `.devcontainer/devcontainer.json` for dedicated per-clone state.
3. On the host, run `task container:rebuild` (or `task container:restart` if the
   CLI was already built and only mounts changed), then attach as `ubuntu`.
4. In the workspace root, run `codegraph init`, then `codegraph status --json`.
   Review the project's indexing scope before initialization. No startup hook
   indexes code, installs agent instructions, or starts CodeGraph automatically.
5. Optionally enable the existing `mcp.codegraph` entry in your active OpenCode
   configuration and fully quit/restart OpenCode. The versioned SDD and non-SDD
   seeds both ship it disabled. Copy-on-first-run seeding preserves existing
   configuration: existing users must merge this entry deliberately.

The passive bind maps `.env.d/.codegraph` to the workspace's `.codegraph/`.
Task prepares the source on the host; CodeGraph writes SQLite as `ubuntu`, with
no installer repair mapping or runtime `chown`. A failed writable-state check
requires correcting that exact host path, not relaxing ownership controls.
SQLite needs its whole directory, including WAL/SHM sidecars, not a DB-only mount.

The workspace itself already persists; this override organizes state separately
and avoids sharing the host's root index. It hides, but does not migrate or delete,
any preexisting workspace `.codegraph/`. Each clone gets independent state. The
mount covers only the root project's index, not separate monorepo subprojects.
Do not share it across concurrent containers or Windows/WSL environments. Stop
writers before backing it up. The database can grow with the indexed repository.
Disabling the tool or override does not delete its state.

`CODEGRAPH_DIR` accepts only a project-root directory name, not an absolute or
nested relocation. `~/.codegraph` is global auxiliary state, not the project DB.
There is no database server, extra port, or database service to deploy.

The image uses exact npm package/bundle versions, with lifecycle scripts disabled,
and verifies Linux amd64/arm64 bundle metadata, parser/schema files, the bundled
SQLite runtime and CLI version before publishing its launcher. npm integrity is
provider-delegated; it is not a repository-pinned artifact attestation. The launcher
executes the installed bundle directly, never the npm shim's cache/download fallback.
It defaults `CODEGRAPH_TELEMETRY=0` and `CODEGRAPH_NO_UPDATE_CHECK=1`, and enforces
`CODEGRAPH_NO_DOWNLOAD=1`; these settings affect CodeGraph only, even without its
Compose override. MCP explicitly carries the same opt-outs.

Use `task tools:update` and rebuild for upgrades, not `codegraph upgrade`.
`TOOL_CODEGRAPH_VERSION="=1.6.0"` is an exact pin. Only the updater generates
its lock, including first registration. Do not run `codegraph install` or the CLI
without arguments to configure agents: upstream also edits instruction files.
Any future project-specific agent guidance must be authored and approved
separately; this integration never adds automatic `AGENTS.md` blocks.

### Verification boundaries

The selected-tool integration test independently checks for loopback-only network
isolation. Otherwise it requires permission to create a network namespace:

```bash
bats --filter 'selected CodeGraph' .devcontainer/test/integration/tools.bats
```

It tests the actual binary against the lock, indexes an isolated fixture, queries
a known symbol, reopens the persisted SQLite index with a fresh HOME, and checks
that another project is not initialized. Temporary state is removed and fixture
process groups are terminated. Namespace denial fails; it is not an offline PASS.

For explicitly authorized recreation proof, `integration/codegraph-fixture.py`
also accepts `VERSION init ABSOLUTE_PROJECT` and `VERSION check ABSOLUTE_PROJECT`.
Run these in two sequential disposable, network-disabled containers using the
same caller-owned project/state mounts and the built image, as `ubuntu`. Each
run has a fresh temporary HOME. The caller must own and clean up those mounts;
the explicit modes do not delete caller state. This is separate from the reduced
base lifecycle test and has not been implied by static or unit checks.

Budget roughly 300 MB installed per platform plus npm/build caches and project
state. A cold starter build costs more. Forecast time/downloads and resource
cleanup before invoking builds or recreation; see [execution timeouts](extending.md#execution-timeouts-for-operational-checks).

Upstream evidence: [v1.6.0 release](https://github.com/colbymchenry/codegraph/releases/tag/v1.6.0),
[bundling](https://github.com/colbymchenry/codegraph/blob/v1.6.0/BUNDLING.md),
[directory contract](https://github.com/colbymchenry/codegraph/blob/v1.6.0/src/directory.ts),
and [privacy/update controls](https://github.com/colbymchenry/codegraph/blob/v1.6.0/TELEMETRY.md).

## Optional Gentleman Guardian Angel (GGA)

1. Run `task install:enable -- 3070-ai-gga`, then rebuild on the host.
2. In the project where you want reviews, run `gga init`, choose and configure a
   provider, then run `gga install` only after reviewing the Git-hook change.

The image supplies the policy-pinned Bash CLI only. It does not run upstream
`install.sh`, `gga init`, or `gga install`; it creates no `.gga`, Git hook, cache
volume, or OpenCode dependency. GGA configuration, provider CLIs, hooks, and its
default per-user cache are intentionally project/user-owned. `gga version` reports
the image policy version without initializing project or user state.

`task tools:update` resolves the selected stable release tag to its immutable Git
commit and source archive SHA-256 before updating the policy transactionally. The
installer downloads that commit archive, verifies its digest and expected Bash
layout, and installs only the runtime sources under `/opt/gga`; use a rebuild for
upgrades rather than GGA's upstream installers.

## Host prerequisites

**SSH agent:** start an agent on the host and export a valid `SSH_AUTH_SOCK` that
the Docker daemon can bind. The override supplies both the socket mount and its
container environment variable. This is independent of incoming SSH access.

**SSH server:** select the server file AND enable its installer. Missing either
prevents automatic server preparation/start. The generated `SSH_PORT` publishes
container port 22; host keys stay under `.env.d/.ssh-server`. Authorization remains
derived from `SSH_AUTHORIZED_KEYS`: absent/empty removes derived authorization;
nonempty input is validated and atomically replaces the managed file. There is
no key migration or new credential persistence.

**Audio:** requires an accessible Pulse-compatible host socket at
`/run/user/<host-uid>/pulse/native`. Task generates `HOST_UID` only after its host
guard; it is never container identity and there is no `HOST_GID`. The socket is
read-only and uses `create_host_path: false`. Package availability does not prove
socket permissions, server compatibility, or audible host playback.

The container endpoint is `/pulse-native`, outside `/tmp`: Docker-in-Docker
startup can mount tmpfs over `/tmp`, hiding socket binds beneath it. Apply this
mount/environment correction with `task container:restart` on the host; it does
not require rebuilding packages that are already installed.

Neither socket integration promises universal Docker Desktop support. Confirm
host OS, daemon socket sharing, server permissions, and session availability.
External sockets are never created, chmodded, or chowned as directories.

## Desired and applied volume contracts

Docker Compose resolves the selected service and ordered files on the host using
`config --format json`; it owns merging, interpolation, and base-file-relative
paths. Full config (including resolved service environment) stays in memory and
is never written to a temporary file or printed by the resolver.

### Supported resolution inputs

Keep all Compose definitions in the explicit ordered `dockerComposeFile` list.
The host validates raw YAML with the repository's supported yq adapter before
resolution. `extends` (including same-file inheritance) and `include` are rejected;
put complete service overrides in the selected files instead. Compose still owns
merging, YAML anchors, and ordinary volume interpolation such as `${SSH_AUTH_SOCK}`.

Only default repository `.env` files are supported for interpolation;
`COMPOSE_ENV_FILES` is rejected, including assignments in those files. The workspace,
first Compose file directory, and `.devcontainer` `.env` contents (or absence) are
fingerprinted. Service `env_file` remains supported: it supplies container environment,
not Compose bind interpolation. Host-shell changes still require host preparation.

Task exports one validated `COMPOSE_PROJECT_NAME` for preparation, name lookup,
build, and Dev Container CLI creation. Its precedence is the host environment
(after sourcing `.devcontainer/.env`), the last selected literal top-level `name`,
then the sanitized workspace basename plus `_devcontainer`. A project name in
the workspace `.env` alone does not override this authority. Interpolated top-level
names are unsupported; use `COMPOSE_PROJECT_NAME` instead. Literal service and
`container_name` values remain supported. Names must start with a lowercase letter
or digit and contain only lowercase letters, digits, underscores, or hyphens.

This follows the CLI's supported environment authority, not an invented CLI flag:
[Dev Container CLI 0.89.0 project-name resolution](https://github.com/devcontainers/cli/blob/v0.89.0/src/spec-node/dockerCompose.ts).

### Published and applied identity

After successful host preparation, Task atomically publishes the ignored
`.devcontainer/.volume-manifest.json`. Schema 2 records the selected service,
ordered file names, repository and project-name fingerprints, and minimal bind records.
Schema 1 manifests are rejected; prepare and recreate through Task to replace them.
Absolute managed sources become workspace-relative `.env.d/...` paths. Host
source fingerprints track volume interpolation changes without persisting raw
host credentials or the full environment; external source paths are not stored.
Directory preparation retains exact ownership, symlink, and mode checks.

Missing, malformed, or stale manifests fail before runtime mutation or installer
dispatch. There is no base-file fallback. Run `task container:up` on the host to
recover; use `task container:restart` when an existing container has old mounts.
Host entry tasks resolve afresh even when the container is already running.

The desired manifest is **not proof of applied mounts**. Task passes its identity
into the container at creation as `GENTLE_VOLUME_MANIFEST_ID`. Startup requires
that identity to match the current manifest before any repair. A changed desired
contract cannot authorize repair inside an old container. Diagnostics report the
desired contract only. Container validation checks repository hashes, not the
host absolute root, host `HOME`, or container `SSH_AUTH_SOCK`; it cannot verify
the current host shell. Return to the host and recreate after override changes.

## Notification evidence and limits

Keep OpenCode and notifier configuration under user control. These integrations
do not rewrite either `opencode.json`, `opencode.jsonc`, or notifier settings.
Do not assume an `@latest` plugin declaration or an `osascript` sound command is
present without inspecting the actual configuration.

Reported isolated user testing with Ubuntu Ghostty, OpenCode 1.18.30, and notifier
0.2.8 observed OSC 9 visual notifications and sound through compatible Pulse
`paplay`; BEL had no observed effect. Event-level notifier options may override
global settings, so inspect the event configuration as well. This is user
evidence, not verification of the final host/container integration.
