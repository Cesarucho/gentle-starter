# AGENTS.md

This file is the AI-facing context for the Gentle Starter project.
Any coding agent that opens this repository in a fresh session
should be able to read this file and continue from where the last
session left off, without reconstructing the reasoning from scratch.

For humans, the same information is in
[`docs/en/extending.md`](docs/en/extending.md),
[`docs/en/starter-updates.md`](docs/en/starter-updates.md),
[`docs/en/starter-releases.md`](docs/en/starter-releases.md), and the deep-dives
linked from the documentation index. This file is a shortcut.

## Project identity

- **Gentle Starter**: a "ready-to-prompt" devcontainer for the Gentle
  AI ecosystem. The devcontainer builds an Ubuntu 24.04 image with
  Pi, Gentle-AI, Engram, Go, Java 25, pnpm, and a curated set of
  CLI tools.
- **Active branch**: `refactor` (post-refactor of the install-layout
  work; ready to push when the user gives the go-ahead).
- **Last commit at session start**: `5f2b083 refactor(core): move devcontainer CLI from core to available/02-enabled`.

## AI session contract

- **Language**: neutral Spanish. No rioplatense voseo, no
  regionalismos. English is fine for commit messages, file paths,
  identifiers, and code comments.
- **Tone**: senior architect. Give an opinion when there are
  trade-offs. Recommend before implementing if the change is
  significant. Don't re-ask obvious things.
- **Subagents**: `pi-subagents` is available but this session did
  not use it. For small changes, inline is faster. For large
  explorations, delegate.
- **Memory**: Engram tools (`mem_save`, `mem_search`, etc.) are
  available. This session did not use them; if you make
  discoveries worth persisting, save with stable `topic_key`s
  (e.g., `sdd/install-layout/decision`).
- **This file is mutable.** If a future session changes a
  convention, update this file in the same commit. Do not treat
  it as sacred; the docs/ entry is the long-form reference.

## Architecture summary (five extension surfaces)

The devcontainer has five coordinated extension surfaces. The deep-dives are
in `docs/en/extending.md` and `docs/en/starter-updates.md`; this is the
one-paragraph version of each.

1. **Install tree** (`.devcontainer/install/`) — build-time
   scripts that the Dockerfile iterates in three groups
   (`01-core/`, `02-enabled/`, `03-hooks/`), each sorted by filename.
   `02-enabled/` is intentionally a pure ordering layer: symlink names
   use a unique `NN-tool.sh` sequence (`10-bats.sh` ... `90-skills.sh`,
   including intermediate slots such as `45-markdownlint.sh` and
   `46-glow.sh`) while `available/` keeps the richer category-based
   script names.
   Adding a new install script = drop a file in `available/` and
   optionally link it from `02-enabled/`. Doc: `docs/en/install-tree.md`.

2. **Volume repair** (`.devcontainer/setup-volumes.sh`,
   sourced by `setup.sh`) — parses the bind mounts in
   `docker-compose.yml`, maps potential owner scripts, and re-runs only
   owners enabled by a valid `02-enabled/` symlink with
   `DEVCONTAINER_PHASE=runtime`. Adding a new stateful volume = bind mount in
   compose + case in
   `compose_target_to_install_scripts` + install script in
   `available/`. Doc: `docs/en/install-volumes.md`.

3. **Config seeding** (`seed_config_tree` in `setup.sh`) —
   copy-on-first-run from `.devcontainer/<name>-config/` to the
   runtime path. Targets outside `$HOME` auto-escalate to `sudo`.
   Adding a new tool's baseline config = source tree in
   `<name>-config/` + one `seed_config_tree` call in
   `setup_versioned_configs`. Doc: `docs/en/configs.md`.

4. **Tool-version policy** (`.devcontainer/tool-versions.conf`) — declarative
   exact versions, provider selectors, observable requirements, major channels,
   and explicit `latest` policies. Installers load it through the restricted
   `devcontainer_load_tool_versions` parser while retaining installation logic,
   URLs, checksums, and idempotency. Doc:
   `docs/en/adr/0002-centralized-tool-version-policy.md`.

5. **Starter update lifecycle** (`.starter/`, `.taskfiles/starter.yml`) — exact
   exact annotated-tag admission, transport-neutral release payloads, declarative
   ownership operations, retained evidence, and transactional recovery for
   `starter:adopt`, `starter:check`, and `starter:update`. Doc:
   `docs/en/starter-updates.md`.

The comprehensive guide (how these systems interact, a worked example
adding Redis end-to-end, and the FAQ) is in
[`docs/en/extending.md`](docs/en/extending.md).

## Project skill lifecycle

- External skills restored by the Skills CLI remain declared in
  `skills-lock.json`.
- Repository-authored skills live in `.agents/skills/` and must be listed one
  per line in `.agents/local-skills.txt`.
- `task skill:prune` preserves the union of both sources;
  `task skill:validate` checks both and rejects unsafe or duplicate local names.
- Do not fabricate `skills-lock.json` source metadata for a local skill.

## Starter update guardrails

- Admit only exact annotated semantic tags named `starter/vX.Y.Z` from the
  initial Git-only source. Immutable tag, commit, tree, manifest, payload, and
  evidence bindings provide structural and integrity validation, not publisher
  authentication.
- Keep source adapters outside lifecycle core. Future transports must emit the
  same versioned release payload and preserve state, ownership, journal,
  rollback, and evidence semantics.

- Release maintainers create a local release with
  `task starter:release -- X.Y.Z`. The command binds the committed
  `.starter/distribution/manifest.json` into the canonical annotated-tag
  metadata, re-admits the tag through `GitTagSource/v1`, and leaves remote
  publication pending; it never pushes automatically.
- `task starter:check` discovers the highest exact stable annotated release by
  bounded Git ref discovery, then uses normal `GitTagSource/v1` admission and
  lifecycle planning. Explicit `--release` bypasses discovery.
- `task starter:update` normally discovers, admits, freezes, and displays the
  exact candidate and plan before an interactive `y`/`Y` confirmation. An
  explicit `--release` keeps the same prompt; deterministic automation requires
  both exact `--release` and `--yes`. Never rediscover or reacquire after the
  prompt, and never accept `--yes` with mutable latest discovery. Adoption
  continues to require an exact release.
- `managed` and explicitly declared `fusion` paths require exact fingerprints.
  `project-owned` paths are immutable to starter migrations. Never silently
  overwrite drift or auto-resolve conflicts.
- Starter commands require clean-worktree eligibility and never merge history,
  execute fetched content, mutate `origin`, or create commits. The project owner
  reviews and commits successful adoption or update results.
- Retain admitted evidence and ambiguous journals. Recovery restores only
  compare-and-swap-provable operation-owned paths; state is written last.
- `task project:init` detects and admits the originating exact annotated release
  before history rewrite, proves the post-cleanup baseline, and includes state
  plus retained evidence in the parentless root. Missing or ambiguous identity
  fails closed; `--no-starter-adopt` is only for deliberately unmarked projects.

## The "what NOT to touch" list

These are decisions that are settled. If a future change
contradicts any of them, that's fine — but the change should
update the docs (or this file) in the same commit, and probably
get its own ADR.

- **`seed_config_tree` is the seed mechanism**, not symlinks. The
  legacy `ln -sfn` approach was removed because tools that use
  "atomic replace" to write their config files (notably Pi and
  some MCP servers) silently break symlinks. The new approach is
  copy-on-first-run. Do not reintroduce symlinks for runtime
  config files.
- **`devuser` is removed.** The project uses `ubuntu` as the
  single devcontainer identity. Do not re-add the `HOST_UID` /
  `HOST_GID` ARGs or the `devuser` account.
- **Source files in `install/` are mode 0755.** The Dockerfile's
  `chmod 0755` over the bind-mounted source will set this on
  every rebuild. The convention is intentional, not a bug.
- **The group prefixes `01-`, `02-`, `03-` are visual hints.**
  The Dockerfile's `for group in 01-core 02-enabled 03-hooks` is
  the load-bearing order. The numeric prefix inside a filename
  (`00-`, `10-`, `20-`) controls in-group sort order. Do not "fix"
  the directory names to match the in-filename prefixes.
- **`02-enabled/` is ordered for execution, not taxonomy.** Keep a
  unique `NN-tool.sh` sequence there and preserve the intended build
  order (`10-bats` first, `90-skills` last). Category/type prefixes
  such as `runtime-` or `ai-` belong in `available/`, not in the
  enabled symlink names.
- **The `03-hooks/` directory is intentionally NOT in
  `.gitignore`.** A file dropped in there shows up in
  `git status` so the user can decide what to do with it.

## What's deferred (do NOT pick up without checking)

- `task env:backup` and `task env:restore` — were designed,
  tested, and reverted at the user's request. The conversation
  history has the full design; do not re-implement them without
  asking.
- `task pi:diff-config` — the user explicitly opted out of this
  when `seed_config_tree` was added.
- Translation to Spanish of `docs/en/install-volumes.md` and
  `.devcontainer/README.md` — decided against; only the
  docs/en/ structure has a Spanish mirror.

## How to verify

### Fast verification in the current devcontainer

Use this path for normal repository validation when the current Pi
session is already running inside the devcontainer:

```bash
task install:list                # full install catalog from available/ + enabled status
task install:doctor              # lib/, templates/, symlinks integrity
task install:volumes             # bind-mount → owning-script contract
task validate                    # doctor + host-safe quality
task validate:full               # strict shell + Markdown quality
task test                        # BATS unit + integration suite
```

Expected result in the current repo: `validate`, `validate:full`, and
`test` should pass.

### Host-only tasks from inside a devcontainer

This repo now protects `task container:*` host-only commands from running
accidentally inside a devcontainer. From the current devcontainer, these
commands should **skip**:

```bash
task container:build
task container:up
task container:restart
task container:rebuild
task container:rm
```

If any of them starts a nested devcontainer from a normal in-container
session, treat it as a regression.

### Simulated host verification from inside a devcontainer

When the session itself runs inside the devcontainer, a realistic full
host-flow test must use a temporary repo copy plus
`FORCE_HOST_CONTEXT=1`. This is the supported way to simulate the host
without mutating the main workspace.

Recommended flow:

```bash
ROOT="$PWD"
SIM_BASE="$ROOT/.tmp-host-sim-$(date +%s)"
rsync -a --exclude '.env.d' --exclude '.tmp-host-sim-*' ./ "$SIM_BASE/"
cd "$SIM_BASE"

FORCE_HOST_CONTEXT=1 task doctor:host
FORCE_HOST_CONTEXT=1 task container:build
FORCE_HOST_CONTEXT=1 task container:up

devcontainer exec --workspace-folder . bash -lc '
  task validate:full &&
  task test &&
  ./.taskfiles/scripts/doctor.sh auto
'

FORCE_HOST_CONTEXT=1 task container:rm
rm -rf "$SIM_BASE"
```

Notes:

- `FORCE_HOST_CONTEXT=1` is **test-only**. Do not bake it into normal
  workflows.
- Use `devcontainer exec`, not raw `docker exec`, because the simulated
  container workspace path differs from the source path of the current
  session.
- The temporary copy should live under the mounted workspace root so the
  host Docker daemon can see it.

### Bootstrap / clean-flow verification

Test `task clean` in a separate temporary copy so the real repo is not
wiped:

```bash
ROOT="$PWD"
LICENSE_SHA256="$(sha256sum LICENSE | awk '{print $1}')"
LICENSE_MODE="$(stat -c '%a' LICENSE)"
CLEAN_BASE="$ROOT/.tmp-clean-sim-$(date +%s)"
rsync -a --exclude '.env.d' --exclude '.tmp-clean-sim-*' ./ "$CLEAN_BASE/"
cd "$CLEAN_BASE"
printf 'y\n' | task clean
```

Verify that:

- `README.md`, `AGENTS.md`, `docs/`, and `CHANGELOG.md` are removed;
- `LICENSE` is kept unchanged as inherited Gentle Starter MIT attribution;
- `sha256sum LICENSE` still matches `LICENSE_SHA256`, and
  `stat -c '%a' LICENSE` still matches `LICENSE_MODE`;
- `AGENTS.md.TEMPLATE` is kept;
- `AGENTS.md` is recreated from `AGENTS.md.TEMPLATE`;
- `.devcontainer/docs/` is created with the migrated deep-dive docs;
- `.devcontainer/README.md` now points at `./docs/*.md` instead of the
  deleted `../docs/en/*.md` paths;
- the placeholder warning is printed;
- `.env.example`, `.taskfiles/`, and `.devcontainer/` remain present.

Test `task project:init` only in a separate temporary repository. It is more
destructive than `task clean` because it also creates a new parentless Git
history:

```bash
ROOT="$PWD"
LICENSE_SHA256="$(sha256sum LICENSE | awk '{print $1}')"
LICENSE_MODE="$(stat -c '%a' LICENSE)"
INIT_BASE="$ROOT/.tmp-project-init-$(date +%s)"
rsync -a --exclude '.env.d' --exclude '.tmp-project-init-*' ./ "$INIT_BASE/"
cd "$INIT_BASE"
ORIGINAL_ORIGIN="$(git remote get-url origin 2>/dev/null || true)"
printf 'project-main\n\nCREATE ROOT\n' | task project:init
```

Verify that:

- the current branch is `project-main`;
- `git rev-list --count HEAD` prints `1`;
- `git rev-list --parents -n 1 HEAD` contains only the root commit SHA;
- the root message is `chore: initialize project`;
- `git for-each-ref --format='%(refname)'` lists only
  `refs/heads/project-main` (unreachable objects may remain until Git garbage
  collection);
- identity cleanup, LICENSE checksum/mode preservation, and migrated-doc
  assertions above still hold;
- a blank origin preserved `ORIGINAL_ORIGIN`;
- no upstream exists and no remote received a ref;
- the working tree is clean.

### Full clean rebuild from a real host

Use this only from a real host shell, not from inside a devcontainer
unless you are intentionally using the host-sim flow above.

```bash
task container:rm
docker buildx prune -af
docker rmi code-img:0.1 2>/dev/null
docker rmi $(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "vsc-code-.*-uid" | head -1) 2>/dev/null
task container:up > /tmp/rebuild.log 2>&1
grep "Running: " /tmp/rebuild.log | grep -vE "\\\$script"  # 17 lines expected
grep "Volume repair" /tmp/rebuild.log                         # 3 lines expected
```

The known-good state after the current validation fixes: core + enabled
validation passes with Go currently disabled by default in
`02-enabled/`. The expected always-on tools are `curl`, `jq`, `git`,
`task`, `devcontainer`, `node`, `npm`, `pnpm`, `glow`, `opencode`, `pi`,
`engram`, `gentle-ai`, and `skills`; Java, Go, and other catalog tools may be enabled or
disabled per project needs. postCreate should exit 0, the host-sim flow
should pass, and both `validate:full` and `test` should pass inside the
active or simulated devcontainer.

## How to extend (cheat sheet)

| You want to... | Do this |
|---|---|
| Add a new install script | `cp templates/install-script.sh available/NN-categoria-tool.sh`, fill in, then if it is default-active link it from `02-enabled/` as `NN-tool.sh` using the next free execution slot. |
| Add a new stateful volume | bind mount in `docker-compose.yml` + case in `compose_target_to_install_scripts` + install script in `available/`. |
| Add a new tool's baseline config (HOME) | create `<name>-config/`, add `seed_config_tree ... "${HOME}/.<name>"` in `setup_versioned_configs`. |
| Add a new tool's baseline config (/etc) | same, target is `/etc/<ruta>` — the helper auto-escalates to `sudo`. |
| Add a personal, non-versioned config | use `<name>-config.local/`, gitignored, add `seed_config_tree ... || true`. |

## Known issues

1. **Legacy symlinks may still exist in `~/.pi/` from older
   builds.** The new `seed_config_tree` correctly leaves them
   alone (`if [ -e ]`). To migrate: `docker exec ${APP_NAME}-run rm -f
   ~/.pi/agent/{settings,mcp}.json ~/.pi/gentle-ai/{banner,models,persona}.json`
   then `bash /home/ubuntu/${APP_NAME}/.devcontainer/setup.sh`.
2. **A whitespace-only change in `setup.sh` re-applies on every
   rebuild:** the `if [ ... ] \` line in `seed_config_tree` becomes
   `if [ ... ] &&`. Semantic-equivalent, but it shows up in
   `git diff` after each rebuild. Don't try to "fix" it; the build
   pipeline normalizes it.

## Pointers to the deep-dive docs

- [`docs/en/README.md`](docs/en/README.md) — the docs index
- [`docs/en/extending.md`](docs/en/extending.md) — the comprehensive guide (start here for extension work)
- [`docs/en/install-tree.md`](docs/en/install-tree.md) — install/ convention deep dive
- [`docs/en/install-volumes.md`](docs/en/install-volumes.md) — volume repair contract deep dive
- [`docs/en/configs.md`](docs/en/configs.md) — `seed_config_tree` deep dive
- [`docs/en/starter-updates.md`](docs/en/starter-updates.md) — release admission, ownership, and recovery contract
- [`docs/en/starter-releases.md`](docs/en/starter-releases.md) — maintainer release creation and publication guide
- [`docs/en/adr/0001-install-layout-refactor.md`](docs/en/adr/0001-install-layout-refactor.md) — the ADR for the refactor
- [`docs/en/adr/0002-centralized-tool-version-policy.md`](docs/en/adr/0002-centralized-tool-version-policy.md) — centralized version-policy ADR
- [`docs/en/`](docs/en/) — English documentation
