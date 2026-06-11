# AGENTS.md

This file is the AI-facing context for the Gentle Starter project.
Any coding agent that opens this repository in a fresh session
should be able to read this file and continue from where the last
session left off, without reconstructing the reasoning from scratch.

For humans, the same information is in
[`docs/en/extending.md`](docs/en/extending.md) and the deep-dives
linked from there. This file is a shortcut.

## Project identity

- **Gentle Starter**: a "ready-to-prompt" devcontainer for the Gentle
  AI ecosystem. The devcontainer builds an Ubuntu 24.04 image with
  Pi, Gentle-AI, Engram, Go, Java 25, pnpm, and a curated set of
  CLI tools.
- **Active branch**: `refactor` (post-refactor of the install-layout
  work; ready to push when the user gives the go-ahead).
- **Last commit at session start**: `3b3609e docs(es): translate
  the new docs/en/ structure to neutral Spanish`.

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

## Architecture summary (the three systems)

The devcontainer has three coordinated extension surfaces. The
deep-dive is in `docs/en/extending.md`; this is the one-paragraph
version of each.

1. **Install tree** (`.devcontainer/install/`) — build-time
   scripts that the Dockerfile iterates in three groups
   (`01-core/`, `02-enabled/`, `03-hooks/`), each sorted by filename.
   Adding a new install script = drop a file in `available/` and
   optionally link it from `02-enabled/`. Doc: `docs/en/install-tree.md`.

2. **Volume repair** (`.devcontainer/setup-volumes.sh`,
   sourced by `setup.sh`) — parses the bind mounts in
   `docker-compose.yml` and re-runs the install scripts that own
   each target with `DEVCONTAINER_PHASE=runtime`. Adding a new
   stateful volume = bind mount in compose + case in
   `compose_target_to_install_scripts` + install script in
   `available/`. Doc: `docs/en/install-volumes.md`.

3. **Config seeding** (`seed_config_tree` in `setup.sh`) —
   copy-on-first-run from `.devcontainer/<name>-config/` to the
   runtime path. Targets outside `$HOME` auto-escalate to `sudo`.
   Adding a new tool's baseline config = source tree in
   `<name>-config/` + one `seed_config_tree` call in
   `setup_versioned_pi_config`. Doc: `docs/en/configs.md`.

The comprehensive guide (how the three interact, a worked example
adding Redis end-to-end, and the FAQ) is in
[`docs/en/extending.md`](docs/en/extending.md).

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

After any change, run:

```bash
task install:list              # core, enabled, available
task install:list --presets    # also shows .disabled
task install:doctor            # lib/, templates/, symlinks integrity
task install:volumes           # bind-mount → owning-script contract
task validate                  # doctor + host-safe quality
task validate:full             # strict (requires shellcheck)
```

For a full clean rebuild:

```bash
task container:rm
docker buildx prune -af
docker rmi code-img:0.1 2>/dev/null
docker rmi $(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "vsc-code-.*-uid" | head -1) 2>/dev/null
task container:up > /tmp/rebuild.log 2>&1
grep "Running: " /tmp/rebuild.log | grep -vE "\\\$script"  # 13 lines expected
grep "Volume repair" /tmp/rebuild.log                     # 3 lines expected
```

The known-good state at the end of the refactor: 14/14 tools
present (`curl`, `jq`, `git`, `task`, `node`, `npm`, `pnpm`, `go`,
`gofmt`, `java`, `javac`, `pi`, `engram`, `skills`), postCreate
exit 0, both `validate` and `validate:full` pass.

## How to extend (cheat sheet)

| You want to... | Do this |
|---|---|
| Add a new install script | `cp templates/install-script.sh available/NN-categoria-tool.sh`, fill in, link from `02-enabled/` if default-active. |
| Add a new stateful volume | bind mount in `docker-compose.yml` + case in `compose_target_to_install_scripts` + install script in `available/`. |
| Add a new tool's baseline config (HOME) | create `<name>-config/`, add `seed_config_tree ... "${HOME}/.<name>"` in `setup_versioned_pi_config`. |
| Add a new tool's baseline config (/etc) | same, target is `/etc/<ruta>` — the helper auto-escalates to `sudo`. |
| Add a personal, non-versioned config | use `<name>-config.local/`, gitignored, add `seed_config_tree ... || true`. |

## Known issues

1. **The `devcontainer` CLI does not persist on the Pi host.**
   Each new session needs `sudo npm install -g @devcontainers/cli`.
   If `task container:*` fails with "executable file not found in
   $PATH", reinstall.
2. **Legacy symlinks may still exist in `~/.pi/` from older
   builds.** The new `seed_config_tree` correctly leaves them
   alone (`if [ -e ]`). To migrate: `docker exec code-run rm -f
   ~/.pi/agent/{settings,mcp}.json ~/.pi/gentle-ai/{banner,models,persona}.json`
   then `bash /home/ubuntu/code/.devcontainer/setup.sh`.
3. **A whitespace-only change in `setup.sh` re-applies on every
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
- [`docs/en/adr/0001-install-layout-refactor.md`](docs/en/adr/0001-install-layout-refactor.md) — the ADR for the refactor
- [`docs/es/`](docs/es/) — Spanish translations of the above (where they exist)
