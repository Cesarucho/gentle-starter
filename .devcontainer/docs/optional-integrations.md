# Select optional container integrations

Use `task container:*` on the host to prepare, create, and recreate the container.
IDEs may attach afterward; Reopen/Rebuild in Container and `initializeCommand`
are not supported creation paths.

## Quick path

The new consumer persistence preset selects base Docker, core tools, Pi and Shell
in that order. Other integrations are commented in generated consumer defaults,
even when active in the producer. Consumers may customize their owned selection
later. Pi and Shell remain optional catalog tools, not mandatory core installers.

1. Uncomment any additional files in the ordered `dockerComposeFile` array in
   `.devcontainer/devcontainer.json`. Keep the base first and
   `config/compose/docker-compose-core-tools.yml` immediately afterward.
2. Enable any required catalog installer separately with `task install:enable`.
   Installer enable/disable does **not** select Compose files.
3. Run `task container:recreate` for mount/environment changes, or
   `task container:rebuild && task container:up` when changing installed packages.
   Attach your IDE again. Restart preserves the existing container and configuration.

| Compose file | Purpose | Installer requirement |
| --- | --- | --- |
| `config/compose/docker-compose.pi.yml` | Persist passive `.env.d/.pi`; never installs Pi | Pi Coding is default-enabled; re-enable separately if disabled |
| `config/compose/docker-compose.gentle-shell.yml` | Persist passive `.env.d/.gentle-shell`; never installs Shell | Gentle Shell is default-enabled; re-enable separately if disabled |
| `config/compose/docker-compose.codegraph.yml` | Persist the root project's SQLite index | Enable `3060-ai-codegraph`; initialize manually |
| `config/compose/docker-compose.ssh-agent.yml` | Host agent socket and `SSH_AUTH_SOCK=/ssh-agent` | Default OpenSSH client; no server required |
| `config/compose/docker-compose.ssh-server.yml` | SSH port and persisted host keys | Enable `4010-tool-ssh-server`, rebuild, then up |
| `config/compose/docker-compose.audio.yml` | Host Pulse socket and `PULSE_SERVER=unix:/pulse-native` | Enable `4100-tool-pulseaudio-utils` for `paplay`, rebuild, then up |

The base retains image/build, service identity, application port, environment,
and the applied-manifest identity. The active core-tools override owns the four
existing Gentle AI, Engram, OpenCode and Git configuration binds plus the OpenCode
port. Moving overrides into `config/compose/` does not change relative sources:
Compose resolves them from the first file's `.devcontainer/` directory, not the
override directory. Check the current `dockerComposeFile` selection rather than
assuming any optional integration is active. Recreate through Task after this
file-layout change even though existing mount sources and targets are unchanged.
No data is migrated.
Existing Pi data is never deleted when disabled. Pi configuration is seeded only
with Pi Coding enabled; no Pi extension configuration or packages are provisioned.

## Optional outbound SSH and manual host trust

Select `config/compose/docker-compose.ssh-agent.yml` independently of installer
activation. Start and populate your host agent yourself and export a daemon-visible
`SSH_AUTH_SOCK`, then run `task container:recreate` on the host. Restart does not
apply the new mounts. No SSH server is required.

The override mounts only the external agent socket and per-clone `.env.d/.ssh`
at `/home/ubuntu/.ssh`; it never mounts host `~/.ssh` or copies private keys.
Task creates new managed `.ssh` roots as 0700, preserves safe existing contents
and modes, and refuses unsafe roots with exact-path remediation rather than
repairing them. This is passive state with no runtime ownership repair.
Disabling the override or recreating the container does not delete that state.

Only an interactive TTY opened by `task container:connect` shows local onboarding.
It preserves readable `~/.bashrc` and checks the applied manifest, expected socket,
and existing plain or hashed GitHub entries without printing keys or writing trust.
Socket existence does not prove responsiveness or loaded keys. Entry presence
does not prove valid trust; revoked or differing records and lookup errors require
manual inspection. IDE terminals, nested ordinary shells, and other entrypoints
do not run this welcome.

When trust is missing, manually run:

```bash
ssh -o StrictHostKeyChecking=ask -T git@github.com
```

Compare the displayed fingerprint with [GitHub's official fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints)
before accepting. Never bypass a changed or revoked key. Authentication and host
trust are separate; GitHub's successful authentication message can accompany exit
status 1 because it does not provide shell access. After intentional recreation,
repeat the manual check to verify persisted trust. Startup never runs SSH,
`ssh-keyscan`, `ssh-add`, network checks, or automatic acceptance.

## Optional CodeGraph

1. Run `task install:enable -- 3060-ai-codegraph`.
2. Uncomment `./config/compose/docker-compose.codegraph.yml` in
   `.devcontainer/devcontainer.json` for dedicated per-clone state.
3. On the host, run `task container:rebuild && task container:up` (or `task container:recreate` if the
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

Use `task tools:update`, then rebuild and up for upgrades, not `codegraph upgrade`.
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

1. Run `task install:enable -- 3070-ai-gga`, then rebuild and up on the host.
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
layout, and installs only the runtime sources under `/opt/gga`; use rebuild then up for
upgrades rather than GGA's upstream installers.

## Host prerequisites

The base host prerequisites are sufficient to build the selected image tools.
The installers in `install/available/` and active
aliases in `install/03-enabled/` do not imply matching host CLI installations:
Playwright, GGA, OpenSSH clients, Pulse clients, and infrastructure CLIs run in
the container. Only selected integrations need additional host resources:

**Base ports:** the generated `APP_PORT` and `OPENCODE_PORT` must be available
on the Docker host for the base and core-tools Compose files. Task writes these
values to `.env`; the ports are published even without optional integrations.

**SSH agent (outbound authentication only):** when selecting the agent override,
start an agent on the host, load the keys you intend to use, and export a valid
`SSH_AUTH_SOCK` visible to the Docker daemon. The override mounts that socket
and sets the container variable; the OpenSSH client is an image tool. No host
SSH server or incoming container SSH is required.

**SSH server (incoming access):** select the server file AND enable its
installer, then rebuild and up. Missing either prevents automatic server
preparation/start. The generated `SSH_PORT` must be available on the host; it
publishes container port 22 on all host interfaces. Host keys stay under
`.env.d/.ssh-server`. Set `SSH_AUTHORIZED_KEYS` in the local `.env` to valid
public keys before expecting key-based login; absent/empty input removes derived
authorization, while nonempty input is validated and atomically replaces the
managed file. There is no key migration or new credential persistence. A remote
client needs an SSH client and network access to the host, not a host-side
server CLI. Restrict access to trusted networks.

**Audio:** selecting the audio override requires an accessible Pulse-compatible
host socket at `/run/user/<host-uid>/pulse/native`. Task generates `HOST_UID`
only after its host guard; it is never container identity and there is no
`HOST_GID`. The socket is read-only and uses `create_host_path: false`.
Package availability does not prove
socket permissions, server compatibility, or audible host playback.
Enable the Pulse client installer only if you need container commands such as
`paplay`; installing it alone does not create a host audio server or socket.

The container endpoint is `/pulse-native`, outside `/tmp`: Docker-in-Docker
startup can mount tmpfs over `/tmp`, hiding socket binds beneath it. Apply this
mount/environment correction with `task container:recreate` on the host; it does
not require rebuilding packages that are already installed.

Neither socket integration promises universal Docker Desktop support. Confirm
host OS, daemon socket sharing, server permissions, and session availability.
External sockets are never created, chmodded, or chowned as directories.
Provider logins, API keys, and cloud credentials are specific to the workflows
you choose (for example AI providers or infrastructure deployment); they are
not prerequisites for installing the base devcontainer or every catalog tool.

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
fingerprinted only in memory to detect concurrent host preparation edits. Raw input
hashes are never persisted. Service `env_file` supplies container environment, not
Compose bind interpolation. The root `.env` is the application's `env_file`: changing
it does not update an existing container's environment. Use intentional host
`task container:recreate` to apply changed values; restart does not apply them.
Task still manages only `APP_NAME`, `APP_PORT`, `OPENCODE_PORT`, `SSH_PORT`, and
`HOST_UID`, preserving unrelated keys. Host-shell changes require host preparation.

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
`.devcontainer/.volume-manifest.json`. Schema 3 separates semantic mount `id` from
`snapshot_digest`, which checks the complete stored object. Identity covers the
service, ordered file selection, project-name fingerprint, and canonical bind
records sorted by unique target. Env edits, additions, deletions, and comments do
not change identity when those resolved semantics stay the same. Source, target,
read-only, service, selection, or project changes do change it.

Managed sources become safe workspace-relative `.env.d/...` paths. Source
fingerprints use lexically normalized host paths, without resolving external
symlinks or storing external paths, credentials, or the full environment. Bind
options beyond `create_host_path: false` are rejected, including propagation,
SELinux, and consistency options. Omitted `read_only` defaults to false, but
resolved `bind.create_host_path` must be explicitly false. Missing creation flags
(including normalized true and short syntax) fail closed; ambiguous output from
other Compose versions is rejected rather than assumed safe.
Directory preparation retains exact ownership, symlink, and mode checks; concurrent
input changes block preparation or publication, preserving the previous snapshot.

**Migration:** legacy schemas require intentional host `task container:recreate`.
Never rewrite a legacy manifest to authorize an existing container. Missing or
invalid snapshots fail before runtime repair; there is no live Compose fallback.
Host preparation resolves desired configuration and rejects an existing-container
identity mismatch before preparing directories or publishing a snapshot.

Task passes `id` at creation as `DEVCONTAINER_BIND_MANIFEST_ID`. Runtime validates strict
shape and identity before any managed-state or SSH mutation. There is no legacy
token fallback. HOST attachment entrypoints use existing generated configuration
read-only: the exact running target may attach with sanitized warnings for bind
drift, missing identity, or invalid/unapplied snapshots, without preparation or
automatic recreation. Stopped or absent targets use strict `container:up`; lookup,
inspection, unsupported state, and concurrent configuration changes block.
All six attachment entrypoints skip completely inside the CONTAINER.

The identity covers bind semantics, not full `.env` bytes. Runtime environment
changes can still require intentional HOST `task container:recreate`, even when
the bind identity agrees. Missing generated configuration requires HOST
`task container:up`; attachment does not regenerate it.

Runtime validates strict snapshot shape, both digests, and that applied identity,
then repairs from those
same checked records. It does not read live env, selected files, host paths, or
Compose. This is bind-contract integrity, not signing or full container configuration
attestation; named volumes and application environment are outside this identity.

`task validate` selects by detected context (or `FORCE_HOST_CONTEXT=1` for
host-path testing). Inside the container it checks applied identity and runs
strict repository quality; on the host it checks prerequisites and the stored
snapshot, and reports that its result is partial. Host validation and `task install:volumes`
report only the **last host-prepared snapshot**, not current desired configuration
or proof of applied mounts. Return to the host and recreate after mount changes.

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
