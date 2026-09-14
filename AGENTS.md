# AGENTS.md

This file is the AI-facing context for Gentle Starter. Read it before changing
the repository. Human-facing details live in `README.md` and `docs/en/`.

## Project identity

Gentle Starter is a ready-to-prompt devcontainer for the Gentle AI ecosystem.
It builds an Ubuntu 24.04 environment with mandatory OpenCode, Gentle AI,
Engram, Bats, Node/npm, pnpm, markdownlint, Dev Container CLI, and Skills.
Pi, Go, Java, and other catalog tools remain optional.

At session start, inspect the current branch, `HEAD`, worktree, and remotes.
Never rely on branch or commit metadata copied into documentation.

## Project initialization and updates

- Users should clone or fork this repository so their projects retain shared
  Git ancestry.
- `task project:init` is an optional one-time project setup. It prompts for a
  branch (default `main`) and optional project `origin`, configures canonical
  Gentle Starter `upstream`, removes identity, and creates the normal child
  commit `chore: initialize project`.
- Initialization preserves history, unrelated branches/tags/refs and Git
  configuration, `LICENSE` bytes and mode, and `AGENTS.md.TEMPLATE`. Intentional
  local branch and remote changes are transactional and roll back on failure.
- Initialization and standalone identity cleanup remove `AGENTS.md` and
  `AGENTS.md.TEMPLATE.EXAMPLE`; they never create `AGENTS.md` from the template.
- `task project:init -- --dry-run` prints branch, remote, cleanup, and commit
  actions without mutation. Initialization never fetches, pushes, rewrites
  history, or creates a parentless root.
- Future starter updates use conventional Git:

  ```bash
  git remote add upstream https://github.com/Cesarucho/gentle-starter.git
  git fetch upstream
  git merge upstream/main
  ```

  Resolve conflicts manually. GitHub template-generated repositories do not
  share ancestry; shallow clones may require `git fetch --unshallow upstream`.

## Extension architecture

Gentle Starter has four coordinated extension surfaces:

1. **Install tree** (`.devcontainer/install/`) — build-time scripts grouped as
   `01-foundation/`, mandatory aliases in `02-core-tools/`, optional aliases in
   `03-enabled/`, and user hooks in `04-hooks/`. Canonical tool installers live
   in `available/`. Docker stages are `foundation` → `core-tools` → `devcontainer`.
   Core aliases and selective Dockerfile source/helper COPY inputs must agree.
   Keep project identity, optional sources/selectors, and hooks downstream of core.
2. **Persistent state** — `task container:up` prepares managed `.env.d` bind
   sources as the host user before Docker starts; `.devcontainer/lifecycle/setup-volumes.sh`
   maps container targets to enabled owner scripts for runtime population.
3. **Config seeding** (`seed_config_tree` in `.devcontainer/setup.sh`) — copies
   versioned baseline configuration on first run. Do not replace this with
   runtime config symlinks; tools that atomically rewrite files break them.
4. **Tool-version policy** (`.devcontainer/tool-versions.conf`) — keeps editable
   `TOOL_*_VERSION` intent above a final generated `LOCK_*` section.
   `task tools:update` is the only mutation authority; builds and installers are
   read-only and carry no local version/checksum defaults.

Start with `docs/en/extending.md`; use the linked deep dives for each surface.

## Project skill lifecycle

- External skills restored by the Skills CLI remain in `skills-lock.json`.
- Repository-authored skills live in `.agents/skills/` and are listed one per
  line in `.agents/local-skills.txt`.
- `task skill:prune` preserves the union of both sources.
- `task skill:validate` rejects unsafe or duplicate local names.
- Never fabricate external lock metadata for local skills.

## Settled conventions

- The project uses `ubuntu` as the sole devcontainer identity. Do not restore
  `devuser` or `HOST_GID`. `HOST_UID` is generated only after the host guard,
  exclusively to locate the optional host Pulse socket; it is not container identity.
- Source scripts under `.devcontainer/install/` use mode `0755` intentionally.
- Dockerfile group iteration is the load-bearing install order; directory
  prefixes are visual hints, while filename prefixes control in-group order.
- Catalog names use unique `BBPP-category-tool.sh` prefixes: related-tool block
  `BB`, position `PP` from `00` to `99`, with gaps allowed. Generated aliases use
  the identical canonical basename. Preserve valid custom aliases and actual
  layer-first, filename-second execution order.
- Enable/disable modifies only `03-enabled/` and refuses mandatory core tools.
  `dependencies.conf` alone defines dependencies. Enable plans the required
  transitive closure, reuses core, and repairs missing dependencies of active tools;
  companions are never autoactivated. Validate the whole projected selection
  before mutation under the shared lock; roll back only operation-created links.
  Core aliases must match selective Dockerfile COPY inputs. Disable protects
  active dependents and does not remove orphan prerequisites.
- `04-hooks/` is intentionally visible to Git.
- `task env:backup`, `task env:restore`, and `task pi:diff-config` are deferred.
  Do not implement them without explicit approval.

## Verification

For normal changes inside the devcontainer:

```bash
task install:list
task install:doctor
task install:volumes
task validate
task validate:full
task test:starter
```

`task test` is application-owned and fails as not configured until the project
owner replaces `tasks.test.cmds`. Starter editorial/distribution tests remain
maintainer-only; derived applications need not satisfy them after initialization.
The maintainer unit suite includes lifecycle/build fixtures: inspect and select
safe tests when execution permissions are restricted. `validate` and
`install:doctor` are not application test proof.

`task test:starter:lifecycle -- --daemon-visible-scratch ABSOLUTE_PARENT` is a
separate, explicitly authorized expensive base build/start/connect/recreate and
managed-state/preservation proof. It is not a seventh test layer or included in
`test:starter`/`validate:full`; it automates only those operational full-validation
items. Initialization and optional Pi/SSH/audio/GUI integrations remain separate.
Forecast downloads, build time, disk use, and deliberately retained shared cache before running.
See `docs/en/extending.md` for its deliberately reduced sandbox scenario.

Explicitly set the external execution tool or supervisor timeout for network/build
checks; do not rely on short defaults. Starting guidelines are 10 minutes per real
`task tools:update` call and 30 minutes for a combined updater/build/verification
flow, adjusted for cache, network, and download scope in the pre-launch forecast.
These are not Task flags or enforced limits. Keep the outer hard deadline beyond
the planned work/soft budget to allow graceful shutdown and cleanup; hard kills
cannot guarantee cleanup. A timeout is incomplete proof, not automatically a
provider, build, or functional bug: report stage, elapsed time, known outcomes,
and cleanup status, preserving successful-step evidence. Inspect processes and
registered resources before bounded continuation; never endlessly rerun or mark
an interrupted run PASS. See
[timeout guidance](docs/en/extending.md#execution-timeouts-for-operational-checks).

### Command decision guide

| Need | Command | Effects, authorization, and evidence |
| --- | --- | --- |
| Application proof | `task test` | Application-owned; inspect the configured command and its effects first. |
| Starter regression proof | `task test:starter` | Unit + integration only; inspect fixtures before authorizing builds or lifecycle operations. |
| Repository checks | `task validate`, `task validate:full` | Not application or full runtime proof; inspect task effects before execution. |
| Isolated operational proof | `task test:starter:lifecycle` | Separate explicit authorization, cost forecast, and daemon-visible scratch required; reduced base coverage only. |
| Recover registered test resources | `task test:starter:clean` | Read-only preview by default; deletion requires explicit apply and one selected run. |
| Work on the real environment | `task container:*` | Normal host workflow, not test cleanup; startup/restart can build. |

After authorized sandbox work, use its automatic cleanup and review retained or
failed outcomes. Recovery uses the same scoped engine for participating lifecycle
and image-contract fixtures; it does not own arbitrary scripts or hook resources.
Never use global Docker pruning as normal test recovery. Stop and report uncertain
ownership, daemon mismatches, or permission failures rather than escalating cleanup.
The helper is not a delivery gate or commit authorization. Human recovery examples
and retention details live in `docs/en/extending.md#recovering-test-owned-resources`.

Host-only `task container:*` commands should skip when run inside the active
devcontainer. To verify a real host flow from inside a container, use a temporary
repository copy under the mounted workspace and `FORCE_HOST_CONTEXT=1`; never
mutate the primary worktree for destructive bootstrap tests.

Test `task clean` and `task project:init` only in temporary repository copies.
For `project:init`, verify that:

- the new commit has the pre-init `HEAD` as its parent;
- unrelated branches, tags, refs, remotes, and upstream settings are unchanged;
- branch and remote changes follow the documented matrix and roll back exactly;
- dry-run leaves files, refs, configuration, index, and worktree unchanged;
- identity files are removed and docs are migrated;
- `LICENSE` and `AGENTS.md.TEMPLATE` retain their bytes and mode;
- only `AGENTS.md.TEMPLATE` remains among the AGENTS identity files;
- the final worktree is clean; and
- a second run refuses without creating another commit.

## Known issues

1. Legacy symlinks may remain under `~/.pi/` from older builds. Remove the old
   runtime links before rerunning `.devcontainer/setup.sh`.
2. The build pipeline normalizes one line in `seed_config_tree`, which can
   produce a semantic-equivalent whitespace diff after rebuild. Do not fight
   that normalization.

## Documentation map

- `docs/en/README.md` — documentation index
- `docs/en/extending.md` — comprehensive extension guide
- `docs/en/install-tree.md` — install layout
- `docs/en/install-volumes.md` — volume repair contract
- `docs/en/configs.md` — config seeding
- `docs/en/adr/0001-install-layout-refactor.md` — install layout ADR
- `docs/en/adr/0002-centralized-tool-version-policy.md` — version policy ADR
- `docs/en/adr/0003-unified-tool-policy-ownership.md` — unified policy ownership
