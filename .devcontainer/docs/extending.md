# Extending the project

This is the comprehensive guide for adding new functionality to the
devcontainer. It covers the four extension surfaces that compose a new
contribution, ties them together with a worked example, and answers
the questions that come up most often.

The four extension surfaces are:

1. **[The install tree](install-tree.md)** — build-time scripts that
   install tools and dependencies during image build.
2. **[The volume contract](install-volumes.md)** — host-prepared bind mounts;
   installer-owned targets also dispatch runtime-safe repair scripts.
3. **[Config seeding](configs.md)** — baseline config files
   versioned in `.devcontainer/config/<name>/` and copied to their
   runtime path on first run.
4. **[Tool-version policy](../tool-versions.conf)** —
   editable `TOOL_*_VERSION` intent and final generated `LOCK_*` values
   in `.devcontainer/tool-versions.conf`.
   Installers retain URLs, architecture, permissions, idempotency, integrity
   verification, and version checks. Approved environment variables may
   override generated locks; otherwise installers require `LOCK_*` values and
   fail closed. They never resolve editable intent or carry local
   version/checksum defaults.

Each surface has a deep-dive document or ADR.

This file is the entry point and the FAQ. If you only have time to read one
doc, read this one.

## The extension surfaces in one diagram

```text
   BUILD PHASE (Dockerfile)                RUNTIME PHASE (setup.sh)
   ──────────────────────                ──────────────────────
   run groups: 01-foundation → 02-core-tools → 03-enabled → 04-hooks
       find each *.sh in group      ──▶  setup_versioned_configs
       DEVCONTAINER_PHASE=build            seed_config_tree
       bash "${script}"                     (Pi and OpenCode config)
                                       ──▶ setup_pi_workspace_trust
                                           git config wiring
                                       ──▶ repair_installed_volumes
                                           yq docker-compose.yml
                                           for each bind mount target,
                                              run each enabled owner with
                                              DEVCONTAINER_PHASE=runtime
```

The same install script can run twice in one container lifetime:
once at build (to install the tool globally) and once at postCreate
(if its target volume is empty or its config target doesn't exist).
The script's idempotency guard at the top of the body decides
whether each call is a no-op or actually does work.

## Worked example: adding Redis as a dev tool

You're working on a project that uses Redis for caching. You want
`redis-cli` available in every rebuild, a baseline `redis.conf`
that you can version, and the data to survive across rebuilds.
This touches the install, config, and volume surfaces.

### Step 1: install — `install/available/7000-tool-redis.sh`

The script downloads and installs the redis packages via apt. It
skips itself if redis is already present.

```bash
#!/usr/bin/env bash
# 7000-tool-redis.sh — install redis-server and redis-cli.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

if devcontainer_has_cmd redis-cli && devcontainer_has_cmd redis-server; then
    devcontainer_log_info "redis already installed: $(redis-cli --version)"
    exit 0
fi

devcontainer_log_info "Installing redis"
devcontainer_run_as_root apt-get update
devcontainer_run_as_root apt-get install -y --no-install-recommends \
    redis-server redis-tools

devcontainer_log_info "redis installed: $(redis-cli --version)"
```

Enable it for default activation:

```bash
cd .devcontainer/install/03-enabled
ln -s ../available/7000-tool-redis.sh 7000-tool-redis.sh
```

### Step 2: config — `.devcontainer/config/redis/redis.conf`

Create the versioned source:

```text
.devcontainer/config/redis/redis.conf
#   runtime: /etc/redis/redis.conf
```

Wire it in `.devcontainer/setup.sh`:

```bash
setup_versioned_configs() {
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/config/pi" "${HOME}/.pi"
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/config/redis" "/etc/redis"
}
```

The `seed_config_tree` helper detects that `/etc/redis` is outside
`$HOME` and escalates to `sudo` for the `cp` and `mkdir` automatically
— no flag, no extra wiring on your part.

### Step 3: volume — installer-owned bind + repair mapping

In `docker-compose.yml`:

```yaml
volumes:
  - type: bind
    source: ../.env.d/.redis
    target: /var/lib/redis
    bind: { create_host_path: false }
```

`task container:up` derives and creates this source as the host user before
Docker starts. Redis owns this state, so it also needs the repair mapping below.

In `.devcontainer/lifecycle/setup-volumes.sh`'s `compose_target_to_install_scripts`:

```bash
"${HOME}/.redis" | "/var/lib/redis")
    scripts_ref+=("7000-tool-redis")
    ;;
```

### Step 4: verify

```bash
task install:list          # shows 7000-tool-redis in 03-enabled
task install:volumes       # shows ../.env.d/.redis -> /var/lib/redis owned by 7000-tool-redis
task container:rebuild     # builds with all three changes
task container:up          # creates/starts the updated environment

# inside the container:
which redis-cli             # /usr/bin/redis-cli
redis-cli --version         # 7.x.x
cat /etc/redis/redis.conf | head -3   # the versioned baseline (copied)
ls /var/lib/redis            # data dir, persists across rebuilds
```

The three relevant surfaces are now wired together. Future rebuilds preserve
your customisations in `/etc/redis/redis.conf` and in the data dir,
and the postCreate hook re-seeds anything that was deleted.

## FAQ

### How do I add a new install script?

Copy `.devcontainer/install/templates/install-script.sh` to
`.devcontainer/install/available/BBPP-category-tool.sh`, fill in
the variables, install, and verify sections, and preserve mode `0755`.
Choose a related block and free two-digit position; full prefixes are unique,
with gaps allowed. Declare prerequisites in `dependencies.conf`, then use
`task install:enable -- BBPP-category-tool` for default optional activation.
The helper creates canonical-named aliases for missing required dependencies,
reuses core, and never activates companions. It validates the complete projection
under a shared enable/disable lock before changing links. Valid custom aliases
retain their names; execution remains layer first, filename second. See
[install-tree.md](install-tree.md) for validation and rollback boundaries.

### How do I add a new stateful volume?

First classify the mount as passive or installer-owned. Both use Compose long
syntax with `bind.create_host_path: false`; `task container:up` prepares managed
`.env.d` sources as the unprivileged host user before Docker starts.

An installer-owned target additionally needs three pieces to agree:

1. The target-to-script mapping: a case in
   `compose_target_to_install_scripts` in
   `.devcontainer/lifecycle/setup-volumes.sh`.
2. The runtime-safe install script in `.devcontainer/install/available/`.
3. A valid symlink in `02-core-tools/` or `03-enabled/` when that owner should be active.

The mapping remains a declaration of potential owners. Runtime repair follows
only enabled owners, regardless of their ordered alias name, and ignores broken
symlinks.

A passive state mount, such as OpenCode's `~/.local/share/opencode`, has no
installer mapping because the application owns and populates it.
Run `task install:volumes` to see whether a target has an installer
mapping. For an unmapped target, confirm separately whether it is passive
or missing a required mapping. See [install-volumes.md](install-volumes.md)
for the deep reference.

### How do I add a new tool's baseline config?

Create a `.devcontainer/config/<name>/` directory with the file
tree that mirrors the tool's runtime config location. Add a
`seed_config_tree` call to `setup_versioned_configs` in
`setup.sh`. Targets outside `$HOME` are handled automatically (the
helper escalates to `sudo`). See
[configs.md](configs.md) for the deep reference.

### How do I keep my personal changes out of git?

`.env.d/` is in `.gitignore`. Anything you drop in `.env.d/.pi/`,
`.env.d/.engram/`, etc. is per-clone and won't be committed.

### Why do my files in `install/` keep getting their mode changed to 0755?

The workspace is bind-mounted into the devcontainer, so the
Dockerfile's `chmod 0755 ./.devcontainer-install -type f -name "*.sh"`
in the image also affects the source files on the host. The
project's convention is `0755` for all install scripts in the
source tree (matching the chmod in the image), and the
`task install:doctor` task doesn't flag mode as a failure. If you
see the mode being reset between builds, that's expected — it's
the bind mount contract.

### What's the difference between build and runtime?

`DEVCONTAINER_PHASE=build` is the value the Dockerfile sets when
it runs each install script during image construction. Build phase
runs as root inside the image; the script typically uses
`apt-get install`, downloads tarballs, and writes to `/usr/local/`.

`DEVCONTAINER_PHASE=runtime` is the value `setup.sh` sets when
it re-runs an install script at postCreate via
`repair_installed_volumes` or a tool-specific runtime hook. Config
files are copied separately by `setup_versioned_configs`; that helper
does not invoke installers. Runtime phase runs as ubuntu; the script typically does user-scoped installs
(`npm install -g` for ubuntu, `/usr/local/bin/` for image-owned direct binaries, etc.)
or skips itself entirely if the tool is already installed.

A script can be the same for both phases, with the idempotency
guard at the top making the difference a no-op when the tool is
already there. Or a script can branch on the phase:

```bash
if devcontainer_is_build; then
    devcontainer_log_info "Skipping user-scoped step during image build"
    exit 0
fi
# runtime-only install steps here
```

`3040-ai-pi-gentle.sh` and `3010-ai-engram.sh` are real examples of
this pattern.

### What happens if I delete `.env.d/` and rebuild?

The volume-repair contract kicks in for installer-owned targets.
For `.env.d/.pi/`, `repair_installed_volumes` can re-run
`3040-ai-pi-gentle.sh` with `DEVCONTAINER_PHASE=runtime` when it is enabled; its
idempotency guards decide what work is needed. Pi Coding is image-owned, while
Pi Gentle remains the runtime owner of packages under `~/.pi`. Disabling it
does not uninstall packages already persisted in `.env.d/.pi`. Passive
mounts are different: OpenCode recreates its
own mutable share state as it runs, so no repair installer is mapped.

This is the same distinction on a fresh clone: installer-owned mounts
are repaired by postCreate, while passive mounts start empty and are
populated by their application.

### How do I reset to the project's defaults?

For a config file: `rm <target>/<file>` then recreate. The
`seed_config_tree` guard re-copies the baseline from the versioned
source.

For the runtime data of a stateful volume: the volume repair
contract doesn't reset data — that's deliberate, to avoid
accidentally wiping your work. If you really want a clean slate,
rename `.env.d/<vol>/` to `.env.d/<vol>.bak` and recreate. The next
startup will see an empty bind mount and re-seed whatever the
owning install scripts do at runtime.

For the real devcontainer, `task container:rebuild` removes its container and
builds the image only; run `task container:up` afterward to start it. Neither step
resets persistent bind data. `container:restart` preserves the existing container;
use `container:recreate` to remove and start it with changed configuration. Review that workflow
separately from test recovery. Global Docker pruning is not a normal reset or test
cleanup procedure: it can affect unrelated projects and shared cache.

### How do I run the test suite?

`task test` belongs to the application. Configure `tasks.test.cmds` in the root
`Taskfile.yml`; until then it fails with instructions. Run shared environment
checks using [BATS](https://github.com/bats-core/bats-core):

```bash
bats .devcontainer/test/unit/*.bats
```

`validate` and `install:doctor` are environment/repository checks, not
application test proof. `common.sh.bats` covers
`common.sh` helpers (phase detection, logging, fetching, version extraction,
version comparison, idempotency), `tools-update.bats` covers the tool-version
policy updater and direct-release checksum behavior, and `gentle-ai.bats` covers
Gentle AI's generated architecture digests, bounded download retries, canonical
enabled slot, rollback, and exact-version idempotency. Maintainers edit
`TOOL_GENTLE_AI_VERSION`; `task tools:update` resolves accepted intent and
atomically fills the exact version and both generated Linux digests from its
Release Assets API.
For registered conventional SemVer strategies (npm, PyPI, Composer, and direct
releases, including Terraform), a complete bare `X.Y.Z` baseline advances with
its lock. For example, an original `2.6.0` floor permits `2.7.0`, but not `3.0.0`;
validation always uses the original intent before advancing it. This also applies
when the lock already contains the resolved version. Bare `0.x.y` retains the
existing same-major resolver policy.

`latest`, major/minor lanes, `=` exact pins, and provider-specific strings retain
their exact spelling. **kubectl and PlantUML are exceptions:** their three-part
floors stay user-declared, with resolution constrained to the selected minor or
year respectively. Node/PHP channels and SDKMAN candidates do not advance as
SemVer baselines. No VCS/ref strategy is currently registered; unsupported refs
still fail closed, and numeric-looking tags alone do not establish eligibility.

One atomic replacement publishes the validated locks and eligible baselines;
the summary reports both kinds of changes. An update is not installation or
runtime test evidence. Review the diff before separately rebuilding and testing.

Metadata or asset validation failure leaves the policy unchanged. These
same-release-boundary digests support reproducible byte integrity; they are not
independent publisher verification. Every editable intent is registered with
one explicit updater strategy; unsupported providers fail closed rather than
remaining manual. The updater, policy, installer library, and this guide are
part of the consumer branch. Integration tests in
`.devcontainer/test/integration/tools.bats` verify that the expected tools are
present after setup (core, Go, Java, Node, AI tools, and environment variables).

Optional checks follow canonical installer targets, not alias names or the
presence of a binary. Disabled tools skip; enabled but missing tools fail.
Two integration tests (`GOROOT` and `DEVCONTAINER_PHASE`) also skip
when run outside the devcontainer — this is by design; they need
the lifecycle environment variables. The rest run anywhere.

BATS itself is installed by the `1000-test-bats.sh` script in
`install/available/`, linked from `install/03-enabled/` for
default activation.

### Disposable container checks without mounts

Use disposable containers for focused validation without changing the primary
worktree or current container: inspect non-secret filesystem/configuration metadata,
permissions, or process behavior; run a script, test suite, or CLI command; or check
a minimal application, reproduction, or proof of concept.

In Docker-in-Docker (DinD), the client must reach the intended running server daemon.
The daemon hosts the containers; client-local paths are not automatically paths on
that daemon's host. Build-context transfer and `docker cp` move reviewed inputs
without host bind mounts; `docker exec` runs commands in the disposable container.
Use a reviewed existing image or build a disposable image from a public-only context.
This procedure is illustrative, not a complete harness or a new canonical Task mode.

1. **Scope and authorize.** Freeze the image/context and synthetic fixtures; record
   their identity. Exclude real data, HOME, credentials, auth/environment files, and
   sockets. Do not mount the primary worktree or current container's state. Forecast
   downloads, build/run time, disk use, and retained shared cache; obtain operational
   authorization. Set bounded producer timeouts and an outer deadline with cleanup
   headroom using the [timeout guidance](#execution-timeouts-for-operational-checks).
2. **Register resources.** Assign unique owned names/tags and record resource IDs
   incrementally in a durable inventory outside disposable scratch. Register work
   before side effects and arrange cleanup for success, failure, and interruption.
    An external registry needs its matching cleanup driver; labels alone do not
    establish ownership or authorize deletion.
3. **Create, start, and execute.** Avoid binds and privileged mode. Default to
   `--network none` where the workload permits; separately authorize bounded network
   access, services, and published ports when needed, including build-time access.
   Copy only reviewed fixtures. Use explicit intended user, HOME, and working
   directory for `docker exec`, and report that identity with the result. Root is
   legitimate for root-specific tests, administrative setup, or diagnosis; it does
   not substitute for application proof under the application's intended user.
   Never relax permissions or change ownership to mask a failure.
4. **Capture and finalize.** Retain bounded public results and sanitized stage/exit
   evidence, not secret output, full environment dumps, or unrestricted inspection
   output. Keep build, execution/assertion, cleanup, and primary-preservation outcomes
   separate. Build success or stdout alone is not a pass; blocked, failed,
   not-tested, and interrupted/incomplete outcomes remain distinct. Record elapsed
   time and successful steps before any bounded, authorized retry with a new frozen
   candidate if corrected. Stop containers and remove only verified run-owned
   resources; verify cleanup through the applicable
    resource registry. Hard kills may prevent finalization. Stop on uncertain
    ownership, daemon mismatch, or permission failure; never use global pruning.

Illustrative fragments **inside that registered, supervised workflow**, not a
complete harness: `image`, `container`, and `run_id` are inventory-assigned identities;
`fixture` and `results` are reviewed client-local input and empty output directories.
The image already provides `check_user`, writable `check_home` and `check_dir`, `sh`,
and `sleep infinity`, with no declared volumes. The fixture is readable by that user
and supplies `check.sh`, which runs the selected check and writes only a bounded,
public `result.txt`. The supervisor must capture exit status and finalize even if a
command fails; registration, optional build, and finalizer implementation are omitted:

```bash
docker create --name "$container" --label "org.gentle-starter.test-run=$run_id" \
  --network none --user "$check_user" --env "HOME=$check_home" \
  --workdir "$check_dir" --entrypoint sleep "$image" infinity
docker cp "$fixture/." "$container:$check_dir/"
docker start "$container"
docker exec --user "$check_user" --env "HOME=$check_home" --workdir "$check_dir" \
  "$container" sh ./check.sh
docker cp "$container:$check_dir/result.txt" "$results/result.txt"
docker stop --time 10 "$container"
```

The finalizer must also remove the registered container and any exclusively owned
image/resources, reporting deliberately retained shared cache separately. This
proves only the selected workload and any explicitly asserted start/stop behavior:
not canonical devcontainer or foundation-build equivalence, host binds, managed
state, full-stack behavior, or other architectures. Volumes, recreation, and
persistence require a separate explicit scenario; copying files out is not
persistence proof.

### Execution timeouts for operational checks

Before authorized network/build checks, explicitly set the timeout in the external
execution tool or supervisor rather than relying on short defaults. Use these
**starting guidelines**, not universal or code-enforced limits:

| Planned work | Starting work budget |
| --- | --- |
| Each real `task tools:update` call | 10 minutes per call |
| Combined updater + build + verification flow | 30 minutes for the flow |

Adapt the budgets to cache state, network conditions, and download scope, and
include them in the pre-launch cost forecast. These are external execution
settings, not new Task flags or a claim that tasks expose configurable timeouts.
Set the outer hard deadline beyond the planned work/soft budget, reserving time
for graceful shutdown and cleanup. SIGKILL or another hard kill cannot guarantee
that cleanup runs.

When a run times out, report **interrupted/incomplete proof**, not automatically a
provider, build, or functional bug. Record the interrupted stage, elapsed time,
known outcomes, and cleanup status; preserve evidence from steps that already
succeeded without labelling the interrupted run PASS. Inspect remaining processes
and registered resources before a bounded continuation with a revised forecast
and explicit timeout. Do not enter endless automatic reruns.

If manual recovery is needed, use the registered resource owner or supervisor
within its documented scope; never use global pruning as timeout recovery.

### How do I write a test for a new helper?

Add a new `@test` block to
`.devcontainer/test/unit/common.sh.bats`. The file sources
`common.sh` at the top; use `export -f` to mock shell functions:

```bash
@test "my helper returns correct value" {
    some_function() { echo "mocked output"; }
    export -f some_function
    run bash -c "source '${COMMON_SH}' && my_helper some_function && printf '%s' \"\${DEVCONTAINER_TOOL_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "expected" ]
}
```

Run `bats .devcontainer/test/unit/common.sh.bats` to validate
locally before committing.

### Why do my symlinks in `~/.pi/` keep coming back?

If you deleted the symlink and rebuilt, but a fresh symlink
appeared at the same path, you're on the pre-`seed_config_tree`
behavior. As of the current build, the function copies real files,
not symlinks. If you still see symlinks, you may have an old
build's state; run
`docker exec ${APP_NAME}-run rm -f ~/.pi/agent/{settings,mcp}.json ~/.pi/gentle-ai/{banner,models,persona}.json`
to clear the legacy symlinks, then `bash /home/ubuntu/${APP_NAME}/.devcontainer/setup.sh`
inside the container. See the migration section in
[configs.md](configs.md) for the full procedure.

### The devcontainer CLI is missing on my host

Inside the devcontainer image, `@devcontainers/cli` is a core
dependency (script `2030-tool-devcontainer-cli.sh`) — you don't need to
reinstall it inside the container.

From the host, `task container:*` still requires the CLI to be
installed on the host machine. Install it with
`sudo npm install -g @devcontainers/cli`. The `task doctor:host`
command checks for it and reports a warning if it's missing.

## See also

- [install-tree.md](install-tree.md) — the install/ convention in depth
- [install-volumes.md](install-volumes.md) — the volume repair contract in depth
- [configs.md](configs.md) — config seeding in depth
- [`.devcontainer/README.md`](../README.md) — tour of the .devcontainer/ directory
