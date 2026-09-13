# The install/ tree

The `install/` directory under `.devcontainer/` is the catalog of
scripts that the Docker build runs. The build iterates four execution
groups in order, each sorted by filename. This doc explains the
convention and how to add a new install script.

For the comprehensive view (how install/, volumes, and configs
interact, plus a worked example), see
[`docs/en/extending.md`](./extending.md).

## Layout

```text
.devcontainer/install/
├── 01-foundation/          # mandatory OS/bootstrap scripts
├── 02-core-tools/          # mandatory symlinks to available/ scripts
├── 03-enabled/             # optional symlinks to available/ scripts
├── 04-hooks/               # user extensions (visible to Git)
├── available/              # canonical core and optional installer bodies
├── lib/                    # shared helpers (common.sh)
└── templates/              # install-script.sh template for new scripts
```

## The four execution groups

The Dockerfile explicitly invokes the fail-fast runner in this order:

```text
foundation stage:   run-installers.sh 01-foundation
core-tools stage:   run-installers.sh 02-core-tools
devcontainer stage: run-installers.sh 03-enabled
                    run-installers.sh 04-hooks
```

Three things to notice:

- **Group order is fixed by explicit Dockerfile runner calls**, not by
  comparing filenames across groups. Numeric directory prefixes are visual hints.
- **Within each group, scripts are sorted by filename** (default `sort`
  order). The numeric prefix you put on each script controls the
  in-group order. Core and optional aliases use `NN-tool.sh` filenames.
- **`-L` follows symlinks**, which is how both alias groups (all symlinks
  into `available/`) actually gets the script bodies to run.

### `01-foundation/` — mandatory OS/bootstrap

The six foundation scripts (00, 10, 11, 15, 90, 99) seed the timezone,
install base apt packages, generate the configured locale, finalize timezone
data, install go-task, configure ubuntu sudoers, and perform final
cleanup. They are mandatory. Keep managed tool installers in `available/`,
not in this OS/bootstrap layer.

Go Task is the narrow external APT-managed core bootstrap exception described
by [ADR 0003](adr/0003-unified-tool-policy-ownership.md). It remains in foundation and
outside `TOOL_*`/`LOCK_*` policy because repository Task workflows and the
foundation cache boundary depend on it. This existing exception is not a route
for adding new unmanaged tools.

### `02-core-tools/` — mandatory shared tools

Each entry is a canonical symlink into `available/`. Eight essential tools
plus their Node/npm prerequisite run in the cached `core-tools` stage.

Current default order:

```text
10-bats.sh
30-node.sh
40-pnpm.sh
45-markdownlint.sh
50-devcontainer-cli.sh
55-opencode.sh
60-engram.sh
81-gentle-ai.sh
90-skills.sh
```

Node/npm precedes pnpm, markdownlint, the Dev Container CLI, and Skills.
Engram and Gentle AI are standalone binaries; neither requires Go, Java, or Pi.
Bats, OpenCode, and Engram use the shared archive helper and foundation Python 3.
`install:enable` and `install:disable` refuse core tools. To intentionally
customize the base, edit core aliases and the matching selective source/helper
COPY inputs in the Dockerfile, then run the cache-boundary consistency tests.
No generic test requires a fixed catalog or mandatory tool set.

### `03-enabled/` — optional tools

This group runs after all core tools. It retains SSH client, SSH server,
PulseAudio clients, Glow, and Playwright in this checkout; Pi remains disabled.
SSH server and audio still require their separately selected Compose overrides.
Use `task install:disable -- NAME` or `task install:enable -- NAME` here.

Disabling changes the active set for future image builds and postCreate
repairs. It does not uninstall packages from the current container or delete
mutable state already persisted under `.env.d/`. Re-enabling an installer
makes its future lifecycle work active again.

`dependencies.conf` is the central activation contract. `enabled` dependencies
must also be active and ordered earlier; `image` dependencies come from the
foundation layer; `companion` entries describe optional runtime integration.
Both alias groups satisfy activation; a core consumer cannot depend on a later
optional installer. Doctor rejects duplicate canonical targets across groups.
`task install:list` displays these relationships and `task install:doctor`
validates the active set. Engram remains standalone when Pi is disabled.

### `04-hooks/` — user extensions (visible to Git)

Reserved for personal, project-agnostic extensions (a personal VPN
cert installer, a site-specific CLI, etc.). The directory is empty
by default and ships with a README. See `install/04-hooks/README.md`
for the contract.

## `available/` — the catalog

`available/` is the script catalog. Every script in `available/` is a
self-contained install script with no expectation of being enabled.
The numbering convention follows the spec's category ranges:

```text
00-09  pre-setup          (e.g. 00-pre-apt.sh)
10-19  sistema base       (e.g. 10-system.sh, 15-task.sh)
20-39  runtimes y AI      (e.g. 20-runtime-go.sh, 30-ai-engram.sh)
40-49  CLI tools          (e.g. 40-cli-mycli.sh)
50-79  presets opt-in     (e.g. 50-browser-playwright.sh)
80-89  misc
90-98  post-setup         (e.g. 90-post-setup-users.sh)
99     cleanup            (e.g. 99-cleanup.sh)
```

Every script in `available/` is a self-contained install script
with no expectation of being enabled. A script runs if and only if
there is a symlink to it in `02-core-tools/` or `03-enabled/`.

The numbering convention follows the spec's category ranges:

## `lib/common.sh` — shared helpers

`lib/common.sh` provides 19 helpers that every install script can
source:

- Phase detection: `devcontainer_phase`, `devcontainer_is_build`,
  `devcontainer_is_runtime`
- Architecture: `devcontainer_arch` (`amd64` / `arm64`)
- Idempotency guards: `devcontainer_has_cmd`, `devcontainer_has_path`,
  `devcontainer_skip_if_cmd`, `devcontainer_skip_if_path`
- Download + integrity: `devcontainer_fetch`, `devcontainer_verify_sha256`
- Privilege escalation: `devcontainer_run_as_root`
- Binary install: `devcontainer_install_bin`
- Logging: `devcontainer_log_info`, `devcontainer_log_warn`,
  `devcontainer_log_error`
- **Version checking**: `devcontainer_check_tool`,
  `devcontainer_check_tool_with_version`, `devcontainer_with_tool`,
  `_devcontainer_get_version`, `_devcontainer_version_compare`,
  `_devcontainer_version_satisfies`

It also has a re-source guard, so it's safe to source from any
script multiple times. `devcontainer_load_tool_versions` safely parses the
assignment-only `.devcontainer/tool-versions.conf` file without `source` or
`eval`; it resolves both the Docker build copy and repository runtime tree
independently of the current directory. See
[ADR 0003](adr/0003-unified-tool-policy-ownership.md) for provider strategies,
generated integrity, and sole mutation ownership. Representative installers expose an explicit
`--print-version-policy` diagnostic argument so tests and maintainers can inspect
the resolved values without performing installation; normal build and runtime
invocations never pass this argument.

## `templates/install-script.sh` — the template

`templates/install-script.sh` is the canonical starting point for
new scripts. It has:

- shebang + `set -euo pipefail` (with a documented carve-out for
  SDKMAN subshells)
- generated policy resolution with no installer-local version/checksum default
- a version-based idempotency guard
- an install section (TODO) and a verify section

Copy it, register its provider strategy and complete update unit in
`deps-update.sh`, fill in the gaps, validate (`shellcheck` + `bash -n`), and
place it in `available/`. Builds and installers must not mutate policy.

## Adding a new install script

Three cases, in order of likelihood:

When adding a new default-active optional symlink in `03-enabled/`, pick the next
free number in the sequence and keep the tool name only in the symlink
filename (`NN-tool.sh`). Do **not** copy the category/type prefix from
`available/` into `03-enabled/`; that extra information belongs to the
catalog script name, not the enabled ordering layer.

### Case 1: a new script for an existing tool (most common)

You're adding a second Pi agent config script, or you want to split a
large install into two smaller ones. No Dockerfile change, no
`03-enabled/` change — just create a new file in `available/` with
the right prefix:

```text
# Example: add a second settings file for pi-coding
.devcontainer/install/available/30-ai-pi-extras.sh
```

`30-ai-` keeps the in-group order (`30-ai-pi-coding.sh` → `30-ai-pi-extras.sh`).
If you want it active by default, link it from `03-enabled/`:

```bash
cd .devcontainer/install/03-enabled
ln -sfn ../available/30-ai-pi-extras.sh 75-pi-extras.sh
```

If only an opt-in, leave it in `available/` and let users enable
with `task install:enable -- 30-ai-pi-extras`.

### Case 2: a new tool that has its own runtime

You're adding Redis, or kubectl, or any tool with a real install
step (binary download, apt install, etc.). The script goes in
`available/` with the right prefix and is linked from `03-enabled/`
for default activation.

```text
# Example: add kubectl
.devcontainer/install/available/20-runtime-kubectl.sh
```

```bash
# from the template
cp .devcontainer/install/templates/install-script.sh \
   .devcontainer/install/available/20-runtime-kubectl.sh
# fill in: download kubectl binary, verify, exit 0 if already present
cd .devcontainer/install/03-enabled
ln -sfn ../available/20-runtime-kubectl.sh 35-kubectl.sh
```

The "State and volumes" section in the template's header tells you
how to wire the bind mount and the volume-repair mapping if your
tool owns a stateful directory.

### Case 3: a personal / site-specific extension

You want a script that runs at every build but only for *your*
clone. Don't add it to the mandatory groups and don't add it
to `available/` (catalog). Use `04-hooks/` instead, which ships
empty and is documented in its own README.

## How to verify the install tree

Three tasks tell you the live state:

```bash
task install:list              # shows core, enabled, hooks, and tools available to enable
task install:doctor            # verifies lib/, templates/, enabled/ symlinks
task install:volumes           # shows the volume contract (separate concern)
```

The `available (not enabled)` section lists filenames without repeating their status.
Dependency suffixes describe declarations, not verified runtime availability:
`requires: installer.sh`, `requires image: 01-foundation/10-system.sh`, or
`optional companion: installer.sh`. Multiple dependencies are separated by semicolons.

The build log itself shows the execution order. After
`task container:up`, `grep "Running: " /tmp/<your-build-log>.log`
prints the actual order of scripts that ran.
