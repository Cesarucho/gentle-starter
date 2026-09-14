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
- **Within each group, scripts are sorted by filename** (`LC_ALL=C sort`
  order). The numeric prefix you put on each script controls the
  in-group order. Generated aliases use the canonical `BBPP-category-tool.sh` basename.
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
1000-test-bats.sh
2000-runtime-node.sh
2010-runtime-pnpm.sh
2020-node-markdownlint.sh
2030-tool-devcontainer-cli.sh
3000-ai-opencode.sh
3010-ai-engram.sh
3020-ai-gentle-ai.sh
3050-ai-skills.sh
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

`dependencies.conf` is the sole dependency graph authority. Numbers never imply
dependencies. Enabling a tool activates its transitive `enabled` prerequisites
in `03-enabled/`, reusing dependencies already in core. An already-active tool
still repairs missing prerequisites. `companion` entries are never autoactivated;
`image` entries are structurally checked, not installed or probed on the host.

For example, `task install:enable -- 2320-php-test` also enables PHP if missing.
Disabling PHPUnit leaves PHP enabled; dependencies are not garbage-collected.
Disabling a dependency with an active consumer is refused, including when named
through a custom alias. Missing core aliases fail against the existing selective
Dockerfile COPY inputs; the helper never recreates mandatory tools as optional.

Enable and disable share a bounded directory lock covering inspection, planning,
application, and rollback. The complete projected selection is validated before
any symlink is changed. Unsafe or broken aliases, duplicate identities/prefixes,
unknown graph nodes, cycles, collisions, and invalid execution order fail closed.
Failed enable operations roll back only links they created, never preexisting
paths. Abrupt uncatchable termination cannot guarantee rollback; inspect the tree
with doctor before retrying. Manual edits must not race a helper operation.

Both alias groups satisfy activation; a core consumer cannot depend on a later
optional installer. Valid custom aliases retain their names and actual order:
layer first, filename second. There is no legacy alias-name translation map.
The runner and planner now use bytewise (`C`) collation; review custom aliases
whose previous relative order depended on locale-specific punctuation handling.
`task install:list` displays relationships and `task install:doctor` validates
the catalog, graph, core COPY consistency, and active set. Neither runs installers.

#### Playwright user-owned provisioning

Playwright's global npm packages, system dependencies, and `/opt/ms-playwright`
preparation remain image-owned. Its CLI configuration and skills are initialized
as `ubuntu`, with both `HOME` and the working directory set to the account's home.
The upstream CLI creates `.playwright/cli.config.json` and installs its default
skill under `.claude/skills/playwright-cli` relative to that working directory.

Existing regular configuration and existing skill trees are preserved, including
custom modes. Provisioning rejects symlinked destination components and a home
that is itself a Git workspace, rather than following links or letting upstream
modify unrelated Git configuration. Missing users or invalid homes fail closed.
This is a fresh-image ownership fix: rebuild to apply it. It does not repair
root-owned files retained from an older container or change runtime state mounts.

### `04-hooks/` — user extensions (visible to Git)

Reserved for personal, project-agnostic extensions (a personal VPN
cert installer, a site-specific CLI, etc.). The directory is empty
by default and ships with a README. See `install/04-hooks/README.md`
for the contract.

## `available/` — the catalog

Every canonical installer uses `BBPP-category-tool.sh`: `BB` is a related-tool
block and `PP` is a position from `00` through `99`. The full four-digit prefix
must be unique across the catalog. Gaps are intentional; leave room for additions.
Generated aliases have exactly the same basename as their canonical target.
Foundation scripts and personal hooks are outside this catalog naming contract.

| Block | Related tools |
| --- | --- |
| `10` | Shell testing |
| `20` | Node/npm and its CLI consumers |
| `21` | Go and debugging |
| `22` | Java and PlantUML tooling |
| `23` | PHP, debugging, and testing |
| `24` | Python tooling |
| `30` | AI tools and integrations |
| `40` | SSH client/server |
| `41` | Audio clients |
| `50` | General CLI utilities |
| `60` | Infrastructure tooling |

These blocks aid browsing, not dependency discovery. Category labels remain
descriptive and may differ within a block. Only active aliases execute, and an
optional alias always runs after core regardless of its numeric prefix.
Custom aliases must have a numeric prefix, a safe lowercase hyphenated name,
and a `.sh` suffix; prefixes must be unique within each execution layer.

The BBPP migration preserves `tool-versions.conf` byte-for-byte. Its historical
filename comments are not current catalog lookup keys; policy values and the
updater remain authoritative and unchanged.

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
`tools-update.sh`, fill in the gaps, validate (`shellcheck` + `bash -n`), and
place it in `available/`. Builds and installers must not mutate policy.

## Adding a new install script

1. Inspect the catalog and select a related block with a free position. Use the
   closest existing provider implementation and preserve installer mode `0755`.
2. Declare real prerequisites in `dependencies.conf`, not in an alias-name map.
   Keep prerequisites earlier in actual execution order. For a new tool without
   related entries, choose an unused block; do not renumber unrelated tools.
3. Leave opt-in tools unlinked. To activate an optional tool, use
   `task install:enable -- BBPP-category-tool`; the helper creates canonical-named
   aliases for its missing required closure. Never use forceful symlink replacement.
4. For intentional core additions, coordinate aliases and selective Dockerfile
   source/helper COPY inputs. Never broaden core COPY to the full catalog.
5. Update runtime owner basenames, tests, and docs where applicable. See the
   [extension guide](extending.md) for policy, state, and configuration integration.

Personal or site-specific extensions belong in `04-hooks/`, not mandatory groups
or the catalog. Its README documents that separate contract.

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
