# Select optional container integrations

Use `task container:*` on the host to prepare, create, and recreate the container.
IDEs may attach afterward; Reopen/Rebuild in Container and `initializeCommand`
are not supported creation paths.

## Quick path

1. Uncomment the required files in the ordered `dockerComposeFile` array in
   `.devcontainer/devcontainer.json`. Keep the base first.
2. Enable any required catalog installer separately with `task install:enable`.
   Installer enable/disable does **not** select Compose files.
3. Run `task container:restart` for mount/environment changes, or
   `task container:rebuild` when changing installed packages. Attach your IDE again.

| Compose file | Purpose | Installer requirement |
| --- | --- | --- |
| `docker-compose.pi.yml` | Persist `.env.d/.pi`; never installs Pi | Enable Pi Coding and optionally Pi Gentle |
| `docker-compose.ssh-agent.yml` | Host agent socket and `SSH_AUTH_SOCK=/ssh-agent` | Default OpenSSH client; no server required |
| `docker-compose.ssh-server.yml` | SSH port and persisted host keys | Enable `20-tool-ssh-server` and rebuild |
| `docker-compose.audio.yml` | Host Pulse socket and `PULSE_SERVER=unix:/tmp/pulse-native` | Enable `20-tool-pulseaudio-utils` for `paplay` and rebuild |

The base retains Gentle AI, Engram, OpenCode, Git configuration, image/build,
service identity, and application/OpenCode ports. All optional files start off.
Existing Pi data is never deleted when disabled. Pi configuration is seeded only
with Pi Coding enabled; Gentle AI alone does not create `~/.pi/gentle-ai`.

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
