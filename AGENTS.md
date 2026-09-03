# AGENTS.md

This file is the AI-facing context for Gentle Starter. Read it before changing
the repository. Human-facing details live in `README.md` and `docs/en/`.

## Project identity

Gentle Starter is a ready-to-prompt devcontainer for the Gentle AI ecosystem.
It builds an Ubuntu 24.04 environment with Pi, Gentle AI, Engram, Go, Java 25,
pnpm, and a curated CLI catalog.

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
   `01-core/`, ordered symlinks in `02-enabled/`, and user hooks in `03-hooks/`.
   Source installers live in `available/`.
2. **Persistent state** — `task container:up` prepares managed `.env.d` bind
   sources as the host user before Docker starts; `.devcontainer/setup-volumes.sh`
   maps container targets to enabled owner scripts for runtime population.
3. **Config seeding** (`seed_config_tree` in `.devcontainer/setup.sh`) — copies
   versioned baseline configuration on first run. Do not replace this with
   runtime config symlinks; tools that atomically rewrite files break them.
4. **Tool-version policy** (`.devcontainer/tool-versions.conf`) — declares exact
   versions, providers, channels, and explicit latest policies. Installers keep
   installation URLs, checksums, permissions, idempotency, and verification.

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
  `devuser`, `HOST_UID`, or `HOST_GID`.
- Source scripts under `.devcontainer/install/` use mode `0755` intentionally.
- Dockerfile group iteration is the load-bearing install order; directory
  prefixes are visual hints, while filename prefixes control in-group order.
- `02-enabled/` is an execution-order layer, not a taxonomy. Keep unique
  `NN-tool.sh` aliases; category names belong in `available/`.
- `03-hooks/` is intentionally visible to Git.
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
task test
```

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
