# The install/ tree

The `install/` directory under `.devcontainer/` is the catalog of
scripts that the Docker build runs. The build iterates three runtime
groups in order, each sorted by filename. This doc explains the
convention and how to add a new install script.

For the comprehensive view (how install/, volumes, and configs
interact, plus a worked example), see
[`docs/en/extending.md`](./extending.md).

## Layout

```text
.devcontainer/install/
├── 01-core/                # mandatory, runs in every build
├── 02-enabled/             # symlinks to active available/ scripts
├── 03-hooks/               # user extensions (read its README first)
├── available/              # opt-in catalog (numbered 00-99, .disabled suffix)
├── lib/                    # shared helpers (common.sh)
└── templates/              # install-script.sh template for new scripts
```

## The three runtime groups

The Dockerfile's build loop is:

```dockerfile
for group in 01-core 02-enabled 03-hooks; do
    find -L "./.devcontainer-install/${group}" -maxdepth 1 -type f -name "*.sh" \
        -not -name "*.disabled" \
        | sort | while read -r script; do
        DEVCONTAINER_PHASE=build bash "${script}"
    done
done
```

Three things to notice:

- **Group order is fixed by the Dockerfile**: `01-core/` runs first, then
  `02-enabled/`, then `03-hooks/`. The numeric prefix is a *visual* hint
  for the execution order; the load-bearing order is the Dockerfile's
  `for` loop.
- **Within each group, scripts are sorted by filename** (default `sort`
  order). The numeric prefix you put on each script controls the
  in-group order. So `30-ai-engram.sh` runs after `20-runtime-go.sh`
  in the same group.
- **`-L` follows symlinks**, which is how `02-enabled/` (all symlinks
  into `available/`) actually gets the script bodies to run.

### `01-core/` — always runs

The five core scripts today (00, 10, 15, 90, 99) cover timezone
and locale, base apt packages, go-task, ubuntu sudoers, and final
cleanup. They are mandatory. Adding a new core script means adding
a new file with the right `NN-` prefix and committing it.

### `02-enabled/` — opt-in, default active

Each entry in `02-enabled/` is a symlink to a script in `available/`.
Default-active scripts (the 8 today: go, java, node, pnpm, engram,
pi-coding, pi-gentle, skills) are linked here at install time. To
disable one, delete the symlink. To enable one, run
`task install:enable -- NAME`.

### `03-hooks/` — user extensions (gitignored)

Reserved for personal, project-agnostic extensions (a personal VPN
cert installer, a site-specific CLI, etc.). The directory is empty
by default and ships with a README. See `install/03-hooks/README.md`
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
50-79  presets opt-in     (e.g. 50-browser-playwright.sh.disabled)
80-89  misc
90-98  post-setup         (e.g. 90-post-setup-users.sh)
99     cleanup            (e.g. 99-cleanup.sh)
```

The `.disabled` suffix marks scripts that are in the catalog but
**not** enabled by default. The Dockerfile's `find` filter
(`-not -name "*.disabled"`) excludes them from the build loop. To
opt-in, rename to remove the suffix and link from `02-enabled/`.

## `lib/common.sh` — shared helpers

`lib/common.sh` provides 13 helpers that every install script can
source:

- `devcontainer_phase`, `devcontainer_is_build`, `devcontainer_is_runtime`
  — phase detection
- `devcontainer_arch` — normalized architecture (`amd64` / `arm64`)
- `devcontainer_has_cmd`, `devcontainer_has_path`,
  `devcontainer_skip_if_cmd`, `devcontainer_skip_if_path` — idempotency guards
- `devcontainer_fetch`, `devcontainer_verify_sha256` — download + integrity
- `devcontainer_run_as_root` — privilege escalation that no-ops when already root
- `devcontainer_install_bin` — copy a binary into `/usr/local/bin`
- `devcontainer_log_info`, `devcontainer_log_warn`, `devcontainer_log_error` — logging

It also has a re-source guard, so it's safe to source from any
script multiple times. See the header comment in `lib/common.sh`
for the full contract.

## `templates/install-script.sh` — the template

`templates/install-script.sh` is the canonical starting point for
new scripts. It has:

- shebang + `set -euo pipefail` (with a documented carve-out for
  SDKMAN subshells)
- a `: "${VAR:=default}"` block for variable defaults
- an idempotency guard using `devcontainer_has_cmd`
- an install section (TODO) and a verify section

Copy it, fill in the gaps, validate (`shellcheck` + `bash -n`), and
place the result in `available/`.

## Adding a new install script

Three cases, in order of likelihood:

### Case 1: a new script for an existing tool (most common)

You're adding a second Pi agent config script, or you want to split a
large install into two smaller ones. No Dockerfile change, no
`02-enabled/` change — just create a new file in `available/` with
the right prefix:

```text
# Example: add a second settings file for pi-coding
.devcontainer/install/available/30-ai-pi-extras.sh
```

`30-ai-` keeps the in-group order (`30-ai-pi-coding.sh` → `30-ai-pi-extras.sh`).
If you want it active by default, link it from `02-enabled/`:

```bash
cd .devcontainer/install/02-enabled
ln -sfn ../available/30-ai-pi-extras.sh 30-ai-pi-extras.sh
```

If only an opt-in, leave it in `available/` and let users enable
with `task install:enable -- 30-ai-pi-extras`.

### Case 2: a new tool that has its own runtime

You're adding Redis, or kubectl, or any tool with a real install
step (binary download, apt install, etc.). The script goes in
`available/` with the right prefix and is linked from `02-enabled/`
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
cd .devcontainer/install/02-enabled
ln -sfn ../available/20-runtime-kubectl.sh 20-runtime-kubectl.sh
```

The "State and volumes" section in the template's header tells you
how to wire the bind mount and the volume-repair mapping if your
tool owns a stateful directory.

### Case 3: a personal / site-specific extension

You want a script that runs at every build but only for *your*
clone. Don't add it to `01-core/` (project-level) and don't add it
to `available/` (catalog). Use `03-hooks/` instead, which ships
empty and is documented in its own README.

## How to verify the install tree

Three tasks tell you the live state:

```bash
task install:list              # shows 01-core, 02-enabled, hooks
task install:list --presets    # also shows .disabled entries in available/
task install:doctor            # verifies lib/, templates/, enabled/ symlinks
task install:volumes           # shows the volume contract (separate concern)
```

The build log itself shows the execution order. After
`task container:up`, `grep "Running: " /tmp/<your-build-log>.log`
prints the actual order of scripts that ran.
