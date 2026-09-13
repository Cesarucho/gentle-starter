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
   versioned in `.devcontainer/<name>-config/` and copied to their
   runtime path on first run.
4. **[Tool-version policy](adr/0003-unified-tool-policy-ownership.md)** —
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
cd .devcontainer/install/03-enabled
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
setup_versioned_configs() {
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/pi-config" "${HOME}/.pi"
    seed_config_tree "${WORKSPACE_DIR}/.devcontainer/redis-config" "/etc/redis"
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
    scripts_ref+=("30-tool-redis")
    ;;
```

### Step 4: verify

```bash
task install:list          # shows 30-tool-redis in 03-enabled
task install:volumes       # shows ../.env.d/.redis -> /var/lib/redis owned by 30-tool-redis
task container:rebuild     # builds with all three changes

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
`.devcontainer/install/available/NN-categoria-tool.sh`, fill in
the variables, install, and verify sections, and link from
`03-enabled/` if it should be active by default. See
[install-tree.md](install-tree.md) for the full convention.

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

Create a `.devcontainer/<name>-config/` directory with the file
tree that mirrors the tool's runtime config location. Add a
`seed_config_tree` call to `setup_versioned_configs` in
`setup.sh`. Targets outside `$HOME` are handled automatically (the
helper escalates to `sudo`). See
[configs.md](configs.md) for the deep reference.

### How do I keep my personal changes out of git?

Two patterns:

- **Bind mounts in `.env.d/`**: `.env.d/` is in `.gitignore`. Anything you
  drop in `.env.d/.pi/`, `.env.d/.engram/`, etc. is per-clone and won't
  be committed.
- **Personal config sources**: use a `<name>-config.local/`
  suffix; the pattern `*-config.local/` is in `.gitignore`. Drop
  your files there, add a `seed_config_tree` call with `|| true`
  to `setup_versioned_configs`, and the line is harmless even
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

`30-ai-pi-gentle.sh` and `30-ai-engram.sh` are real examples of
this pattern.

### What happens if I delete `.env.d/` and rebuild?

The volume-repair contract kicks in for installer-owned targets.
For `.env.d/.pi/`, `repair_installed_volumes` can re-run
`30-ai-pi-gentle.sh` with `DEVCONTAINER_PHASE=runtime` when it is enabled; its
idempotency guards decide what work is needed. Pi Coding is image-owned, while
Pi Gentle remains the runtime owner of packages under `~/.pi`. Disabling it
does not uninstall packages already persisted in `.env.d/.pi`. Passive
mounts are different: OpenCode recreates its
own mutable share state as it runs, so no repair installer is mapped.

This is the same distinction on a fresh clone: installer-owned mounts
are repaired by postCreate, while passive mounts start empty and are
populated by their application.

### How do I reset to the project's defaults?

For a config file: `rm <target>/<file>` then rebuild. The
`seed_config_tree` guard re-copies the baseline from the versioned
source.

For the runtime data of a stateful volume: the volume repair
contract doesn't reset data — that's deliberate, to avoid
accidentally wiping your work. If you really want a clean slate,
rename `.env.d/<vol>/` to `.env.d/<vol>.bak` and rebuild. The next
startup will see an empty bind mount and re-seed whatever the
owning install scripts do at runtime.

For the real devcontainer, `task container:rebuild` removes its container and
builds/starts it again; it does not reset persistent bind data. Review that workflow
separately from test recovery. Global Docker pruning is not a normal reset or test
cleanup procedure: it can affect unrelated projects and shared cache.

### How do I run the test suite?

`task test` belongs to the application. Configure `tasks.test.cmds` in the root
`Taskfile.yml`; until then it fails with instructions. Initialization does not
change this routing or automatically select inherited tests.

Starter maintainers use [BATS](https://github.com/bats-core/bats-core)
(Bash Automated Testing System) explicitly:

```bash
task test:starter:unit         # starter behavior and distribution contracts
task test:starter:integration  # core and selected installed tools
task test:starter              # both maintainer suites together
task test:install      # install BATS if not present
task test:help         # show available test tasks
```

`test:unit`, `test:integration`, `test:test`, and `test:all` are deprecated
maintainer aliases. The unit suite includes lifecycle/build fixtures; inspect
tests before running them in a restricted environment. README/ADR/catalog
checks remain starter-only and can require original distribution docs; derived
applications need not satisfy them. `validate` and `install:doctor` are
environment/repository checks, not application test proof.

Unit tests live in `.devcontainer/test/unit/`: `common.sh.bats` covers
`common.sh` helpers (phase detection, logging, fetching, version extraction,
version comparison, idempotency), `deps-update.bats` covers the dependency
policy updater and direct-release checksum behavior, and `gentle-ai.bats` covers
Gentle AI's generated architecture digests, bounded download retries, canonical
enabled slot, rollback, and exact-version idempotency. Maintainers edit
`TOOL_GENTLE_AI_VERSION`; `task deps:update` resolves accepted intent and
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
remaining manual. This behavior remains available after `task project:init`
because the task files, updater, policy, installer
library, and this guide survive in the derived project. Integration tests in
`.devcontainer/test/integration/tools.bats` verify that the expected tools are
present after setup (core, Go, Java, Node, AI tools, and environment variables).

Optional checks follow canonical installer targets, not alias names or the
presence of a binary. Disabled tools skip; enabled but missing tools fail.
Two integration tests (`GOROOT` and `DEVCONTAINER_PHASE`) also skip
when run outside the devcontainer — this is by design; they need
the lifecycle environment variables. The rest run anywhere.

BATS itself is installed by the `10-bats.sh` script in
`install/available/`, linked from `install/03-enabled/` for
default activation.

### Explicit base lifecycle proof

`test:starter:lifecycle` replaces the removed `test:pi-lifecycle`; it no longer
proves Pi. Run it only with explicit operational authorization, outside the normal
`task test`, `task test:starter`, and `task validate:full` routes:

```bash
task test:starter:lifecycle -- --daemon-visible-scratch /absolute/scratch-parent
```

The existing parent must be outside the source repository and visible at the same
absolute path to the **local** Docker daemon at `/var/run/docker.sock`. The flag
is the operator's explicit confirmation of that mapping, not an automatic probe.
Inside a devcontainer, use a sibling under the mounted workspace, not an arbitrary
container-private `/tmp` directory. Remote Docker contexts are not reused. Missing
commands or unsupported base customization fail rather than selecting a fallback.

**Cost forecast:** one explicit `container:build`, then `container:up`, then
`container:restart` through Task in a unique candidate. Expect significant CPU,
disk, network downloads, and potentially minutes of build/setup time. Restart has
no explicit package rebuild step, but devcontainer startup may build according to
its own cache logic. This automates full-validation build/start/connect/recreate
and persistent-state/error/source-preservation items, not a new test layer.
Initialization proof and targeted Pi, SSH, audio, GUI integrations remain separate.

The fixture copies current public source changes into independent Git metadata
without remotes. In the **candidate only**, it selects `docker-compose.yml` and
`container-svc`, retains the current base build and managed writable binds, and
replaces the attach configuration with the standard workspace mount, ubuntu user,
and setup command. Optional Compose overrides, custom attach settings, and CLI
features (including nested Docker and GitHub CLI) are omitted. Pi coding/Gentle and
SSH-server activation links are removed in the candidate; other selected installers
and user hooks remain trusted build inputs. Original selections are untouched.

Only synthetic environment files and a private empty host HOME are supplied:
no inherited SSH keys, agent sockets, Pulse endpoints, Docker credentials, or
authorized-key variables. Known runtime/credential paths are excluded from the
overlay; this is **not a universal secret scanner**. Review custom source code,
hooks, Dockerfile, and base Compose before explicitly executing privileged builds.
External binds, named Compose volumes, custom services/resources, and escaping
symlinks are rejected rather than guessed into a safe mapping.

Noninteractive `docker exec` as ubuntu proves connection without an SSH server.
The harness compares applied manifest identity and actual managed mounts, checks
bind-root ownership/modes, writes unique markers, then verifies a new container ID
and marker persistence after restart. Public tracked/untracked bytes, full modes,
symlink targets, branch, HEAD, index, and primary status are checked; excluded secret
environment contents are never hashed. Source preservation is checked on failure
as well as success. Mock regressions cover failure/interrupt cleanup; a successful
live cycle does not itself inject every possible operational failure.

Automatic cleanup runs after success, failure, and handled SIGINT/SIGTERM, using
the same ownership engine as explicit recovery below. Cleanup failure makes the
test fail without replacing its separate stage/status diagnostic. SIGKILL cannot
run a finalizer; the durable inventory supports later recovery instead.

### Execution timeouts for operational checks

Before authorized network/build checks, explicitly set the timeout in the external
execution tool or supervisor rather than relying on short defaults. Use these
**starting guidelines**, not universal or code-enforced limits:

| Planned work | Starting work budget |
| --- | --- |
| Each real `task deps:update` call | 10 minutes per call |
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

If manual recovery is needed, use the
[registered-resource recovery procedure](#recovering-test-owned-resources) within
its ownership scope; never use global pruning as timeout recovery.

### Recovering test-owned resources

Start with a read-only preview from the **original source worktree**:

```bash
task test:starter:clean
task test:starter:clean -- --run RUN_UUID
# After reviewing that run's scope, explicitly authorize deletion:
task test:starter:clean -- --apply --run RUN_UUID
# Also discard its compact diagnostics, only after resources are verified gone:
task test:starter:clean -- --apply --run RUN_UUID --forget
```

`RUN_UUID` is printed by the participating test or recovery preview. Neither
`test:starter:lifecycle` nor this recovery command is invoked by `task test`,
`task test:starter`, or `task validate:full`. Normal unit execution does include
mock tests of the cleaner, not an invocation of live recovery.

**Scope:** the base lifecycle harness and the Docker image-contract fixture in
`common.sh.bats` register their resources. The latter now has a unique run tag and
`finally` cleanup even when build/assertion fails. Other suites retain their own
fixture cleanup; arbitrary commands, custom hook resources, unlabelled resources,
and the real devcontainer are not automatically adopted by this helper.

The private local store is `starter-test-runs/` beneath
`git rev-parse --path-format=absolute --git-common-dir` (normally
`.git/starter-test-runs/`). It is outside removable scratch, untracked Git metadata,
and shared by linked worktrees; each record remains bound to its original canonical
source worktree. No Git configuration or index changes are needed. The store is
mode `0700`, records/leases are `0600`; imports and default preview do not create or
repair records. An exclusive lease prevents concurrent recovery of a running test.

Before side effects, the engine records the run UUID, source binding, canonical
scratch scope, local endpoint and actual daemon ID. It registers the sandbox
filesystem identity and ownership marker, verifies project/label/tag absence, then
arms narrowly scoped discovery. Producers wait for their process group to be
recorded before executing. Resource IDs and expected labels are captured
incrementally; scoped discovery also recovers resources created between a Docker
operation and its next inventory write, including restart replacements. Recovery
refuses while a recorded producer process group remains present.

Immediately before removal, the engine rechecks the daemon, resource IDs and
ownership labels; volumes also require their recorded creation identity. Missing
resources are idempotent success, but a failed query is **not** proof of absence.
Conflicting or malformed records, unexpected labels, changed worktree binding,
symlink escapes, and unverifiable filesystem ownership stop cleanup without trying
a broader scope. Containers may be force-removed only by their verified owned IDs;
networks/volumes are removed individually. No global prune or sudo fallback exists.

Owned images are removed without force or parent pruning only when their labels,
recorded ID, unchanged exclusive run tag (or untagged identity), tag-to-ID mapping,
and absence of container users can be verified. The permitted tags are the base
run tag and the exact Dev Containers UID tag derived from the recorded candidate
path, not arbitrary prefix matches. A local repository digest is accepted only
when its repository matches that sole tag and its digest equals the captured image
ID; foreign digest references or additional tags still prevent removal. Shared,
retagged, or otherwise unverifiable images are retained and reported; that is not
a successful complete test cleanup. **Shared build cache is deliberately retained**:
there is no dedicated test builder, so removing it would affect unrelated builds.

Outcomes distinguish removed-and-verified resources, deliberately retained cache
or images, and failed/unverifiable cleanup. Recovery records remain until resources
are proven gone; successful runs retain compact diagnostics indefinitely until
explicit `--forget`. Diagnostics contain bounded structured stage, exit, test, and
cleanup outcomes—not raw command lines, environment, Compose output, inspect dumps,
or excerpts from arbitrary logs. Raw build logs stay only in disposable private
scratch. If filesystem cleanup fails, those logs may remain there along with the
ownership marker; the report names the exact scratch scope for manual inspection.
Do not remove ownership metadata or escalate to global cleanup when uncertain.
Interrupted registration can leave a directory whose marker was not completed;
recovery refuses to guess ownership. This is a scoped operational aid, not a commit
gate or a universal no-residue guarantee.

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
