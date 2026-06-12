# Extending the project

This is the comprehensive guide for adding new functionality to the
devcontainer. It covers the three systems that compose a new
contribution, ties them together with a worked example, and answers
the questions that come up most often.

The three systems are:

1. **[The install tree](install-tree.md)** — build-time scripts that
   install tools and dependencies during image build.
2. **[The volume contract](install-volumes.md)** — bind mounts
   declared in `docker-compose.yml` that the postCreate hook
   re-populates by running the install scripts that own each target.
3. **[Config seeding](configs.md)** — baseline config files
   versioned in `.devcontainer/<name>-config/` and copied to their
   runtime path on first run.

Each system has its own deep-dive doc. This file is the entry point
and the FAQ. If you only have time to read one doc, read this one.

## The three systems in one diagram

```text
   BUILD PHASE (Dockerfile)                RUNTIME PHASE (setup.sh)
   ──────────────────────                ──────────────────────
   for group in 01-core 02-enabled 03-hooks:
       find each *.sh in group      ──▶  setup_versioned_pi_config
       DEVCONTAINER_PHASE=build            seed_config_tree
       bash "${script}"                     (pi-config -> ~/.pi)
                                       ──▶ setup_pi_workspace_trust
                                           git config wiring
                                       ──▶ repair_installed_volumes
                                           yq docker-compose.yml
                                           for each bind mount target,
                                              run owning script with
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
This touches all three systems.

### Step 1: install — `install/available/30-tool-redis.sh`

The script downloads and installs the redis packages via apt. It
skips itself if redis is already present.

```bash
#!/usr/bin/env bash
# 30-tool-redis.sh — install redis-server and redis-cli.
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
cd .devcontainer/install/02-enabled
ln -sfn ../available/30-tool-redis.sh 30-tool-redis.sh
```

### Step 2: config — `.devcontainer/redis-config/redis.conf`

Create the versioned source:

```text
.devcontainer/redis-config/redis.conf
#   runtime: /etc/redis/redis.conf
```

Wire it in `.devcontainer/setup.sh`:

```bash
setup_versioned_pi_config() {
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config" "${HOME}/.pi"
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/redis-config" "/etc/redis"
}
```

The `seed_config_tree` helper detects that `/etc/redis` is outside
`$HOME` and escalates to `sudo` for the `cp` and `mkdir` automatically
— no flag, no extra wiring on your part.

### Step 3: volume — bind mount + repair mapping

In `docker-compose.yml`:

```yaml
volumes:
  - ../env/.redis:/var/lib/redis
```

In `setup-volumes.sh`'s `compose_target_to_install_scripts`:

```bash
"${HOME}/.redis" | "/var/lib/redis")
    scripts_ref+=("30-tool-redis")
    ;;
```

### Step 4: verify

```bash
task install:list          # shows 30-tool-redis in 02-enabled
task install:volumes       # shows ../env/.redis -> /var/lib/redis owned by 30-tool-redis
task container:rebuild     # builds with all three changes

# inside the container:
which redis-cli             # /usr/bin/redis-cli
redis-cli --version         # 7.x.x
cat /etc/redis/redis.conf | head -3   # the versioned baseline (copied)
ls /var/lib/redis            # data dir, persists across rebuilds
```

The three systems are now wired together. Future rebuilds preserve
your customisations in `/etc/redis/redis.conf` and in the data dir,
and the postCreate hook re-seeds anything that was deleted.

## FAQ

### How do I add a new install script?

Copy `.devcontainer/install/templates/install-script.sh` to
`.devcontainer/install/available/NN-categoria-tool.sh`, fill in
the variables, install, and verify sections, and link from
`02-enabled/` if it should be active by default. See
[install-tree.md](install-tree.md) for the full convention.

### How do I add a new stateful volume?

Three things have to agree (in different files, by the way):

1. The bind mount itself: declared in
   `.devcontainer/docker-compose.yml` under `services.container-svc.volumes:`.
2. The target-to-script mapping: a case in
   `compose_target_to_install_scripts` in
   `.devcontainer/setup-volumes.sh`.
3. The install script (which also runs at runtime when the volume
   is empty): in `.devcontainer/install/available/`, optionally
   linked from `02-enabled/`.

Run `task install:volumes` after editing the case to verify the
contract is in sync. See
[install-volumes.md](install-volumes.md) for the deep reference.

### How do I add a new tool's baseline config?

Create a `.devcontainer/<name>-config/` directory with the file
tree that mirrors the tool's runtime config location. Add a
`seed_config_tree` call to `setup_versioned_pi_config` in
`setup.sh`. Targets outside `$HOME` are handled automatically (the
helper escalates to `sudo`). See
[configs.md](configs.md) for the deep reference.

### How do I keep my personal changes out of git?

Two patterns:

- **Bind mounts in `env/`**: `env/` is in `.gitignore`. Anything you
  drop in `env/.pi/`, `env/.engram/`, etc. is per-clone and won't
  be committed.
- **Personal config sources**: use a `<name>-config.local/`
  suffix; the pattern `*-config.local/` is in `.gitignore`. Drop
  your files there, add a `seed_config_tree` call with `|| true`
  to `setup_versioned_pi_config`, and the line is harmless even
  if the directory doesn't exist yet.

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
it re-runs the install script at postCreate, either via
`setup_versioned_pi_config` (for config files) or via
`repair_installed_volumes` (for stateful bind mounts). Runtime
phase runs as ubuntu; the script typically does user-scoped installs
(`npm install -g` for ubuntu, `~/.local/bin/` for Engram, etc.)
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

`30-ai-pi-gentle.sh` and `30-ai-engram.sh` are real examples of
this pattern.

### What happens if I delete `env/` and rebuild?

The volume-repair contract kicks in. With `env/.pi/` empty,
`repair_installed_volumes` notices the target is empty and re-runs
`30-ai-pi-coding.sh` and `30-ai-pi-gentle.sh` with
`DEVCONTAINER_PHASE=runtime`. The scripts' idempotency guards
decide what's actually done (typically "nothing, the binaries
are already installed, but the npm packages and the trust.json
might need touching").

This is the same thing that happens on a fresh clone: the
volume mounts come up empty, and the postCreate hook populates
them. The dev environment is "self-healing" with respect to the
stateful bind mounts, up to the idempotency contract of each
install script.

### How do I reset to the project's defaults?

For a config file: `rm <target>/<file>` then rebuild. The
`seed_config_tree` guard re-copies the baseline from the versioned
source.

For the runtime data of a stateful volume: the volume repair
contract doesn't reset data — that's deliberate, to avoid
accidentally wiping your work. If you really want a clean slate,
rename `env/<vol>/` to `env/<vol>.bak` and rebuild. The next
startup will see an empty bind mount and re-seed whatever the
owning install scripts do at runtime.

For the whole dev environment: `docker system prune -a` (drops
all images, builds, and volumes) and `task container:rebuild`
from scratch. Heavy hammer; usually you only need one of the
above.

### How do I run the test suite?

The project uses [BATS](https://github.com/bats-core/bats-core)
(Bash Automated Testing System) for shell-based tests.

```bash
task test:unit         # unit tests for common.sh helpers (36 tests)
task test:integration  # integration tests for installed tools (24 tests)
task test:all          # both suites together
task test:install      # install BATS if not present
task test:help         # show available test tasks
```

Unit tests live in `.devcontainer/test/unit/common.sh.bats` and
cover the `common.sh` helpers (phase detection, logging, fetching,
version extraction, version comparison, idempotency). Integration
tests in `.devcontainer/test/integration/tools.bats` verify that
the expected tools are present after setup (core, Go, Java, Node,
AI tools, and environment variables).

Two integration tests (`GOROOT` and `DEVCONTAINER_PHASE`) skip
when run outside the devcontainer — this is by design; they need
the lifecycle environment variables. The rest run anywhere.

BATS itself is installed by the `10-bats.sh` script in
`install/available/`, linked from `install/02-enabled/` for
default activation.

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
`docker exec code-run rm -f ~/.pi/agent/{settings,mcp}.json ~/.pi/gentle-ai/{banner,models,persona}.json`
to clear the legacy symlinks, then `bash /home/ubuntu/code/.devcontainer/setup.sh`
inside the container. See the migration section in
[configs.md](configs.md) for the full procedure.

### The devcontainer CLI is missing on my host!

Inside the devcontainer image, `@devcontainers/cli` is a core
dependency (script `20-tool-devcontainer-cli.sh`) — you don't need to
reinstall it inside the container.

From the host, `task container:*` still requires the CLI to be
installed on the host machine. Install it with
`sudo npm install -g @devcontainers/cli`. The `task doctor:host`
command checks for it and reports a warning if it's missing.

## See also

- [install-tree.md](install-tree.md) — the install/ convention in depth
- [install-volumes.md](install-volumes.md) — the volume repair contract in depth
- [configs.md](configs.md) — config seeding in depth
- [`.devcontainer/README.md`](../../.devcontainer/README.md) — tour of the .devcontainer/ directory
