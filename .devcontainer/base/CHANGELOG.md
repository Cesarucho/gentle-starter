# Changelog

All notable changes to Gentle Starter will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and
this project will follow [Semantic Versioning](https://semver.org/) when tagged
releases start.

## [Unreleased]

### Added

- Initial Spanish README with quick usage and project structure.
- `.env.example` for local environment setup.
- Host/container doctor tasks: `task doctor`, `task doctor:host`, and
  `task doctor:container`, backed by `.taskfiles/scripts/doctor.sh`.
- MIT license.
- Security documentation in `docs/security.md`.
- Devcontainer language tooling: latest stable Go, Java 25 through SDKMAN, and
  latest stable pnpm.
- Context7 MCP integration through versioned Pi config and the official
  `context7-mcp` skill.
- Optional MCP presets for GitHub and Playwright, with GitHub token
  documentation in `.env.example`.
- `task container:restart` to remove and start the devcontainer without
  rebuilding the image.
- Auto-start guard for `task container:connect`, `task container:pi`, and
  `task container:engram` when the devcontainer is not running.
- `.devcontainer/install/` layout with `01-core/`, `02-enabled/`,
  `03-hooks/`, `available/`, `lib/`, and `templates/` directories. The
  `01-` / `02-` / `03-` prefix is a visual hint of execution order
  (group order is hardcoded in the Dockerfile, the numeric prefix
  within each group controls the in-group sort). The `available/`
  catalog uses a 00-99 prefix for the spec's category ranges
  (runtimes, AI tooling, CLI tools, presets, post-setup, cleanup).
- `.devcontainer/install/lib/common.sh` with 13 shared helpers
  (`devcontainer_phase`, `devcontainer_arch`, `devcontainer_has_cmd`,
  `devcontainer_run_as_root`, `devcontainer_install_bin`,
  `devcontainer_fetch`, `devcontainer_verify_sha256`,
  `devcontainer_log_info` / `_warn` / `_error`, and idempotency guards),
  backed by a re-source guard so it can be sourced from any script safely.
- `.devcontainer/install/templates/install-script.sh` as the template for
  new install scripts.
- `task install:list`, `task install:enable`, `task install:disable`,
  `task install:doctor`, and `task install:help` to manage the install
  layout, backed by `.taskfiles/scripts/install.sh`.

### Changed

- Renamed the starter identity to Gentle Starter.
- Simplified the Docker Compose service name to `container-svc`.
- Cleaned `.devcontainer/devcontainer.json` and removed the empty VS Code
  extension entry.
- Added deterministic devcontainer identity generation for `APP_NAME` and
  `APP_PORT` based on the project directory.
- Added devcontainer entrypoints for Pi and Engram TUI.
- Pinned core AI tooling versions and moved Pi package updates behind the
  manual `task ai:update` workflow.
- Added host-safe repository validation through `task validate` and strict
  validation through `task validate:full`, without requiring a fixed project
  skill set.
- Renamed the user-facing devcontainer task namespace from `devcontainer:*` to
  `container:*`.
- Simplified Engram installation to an idempotent user-local binary install that
  detects architecture and registers the local bin directory on `PATH`.
- Added idempotent Pi workspace trust setup for `/home/ubuntu/${APP_NAME}`.
- `task ai:update` now re-pins selected Pi packages with explicit latest npm
  versions after updating.
- `task container:pi` now opens Pi with `pi --continue`.
- Dockerfile now `COPY install/` instead of `scripts/`, and the build RUN
  iterates only over the `01-core/`, `02-enabled/`, and `03-hooks/`
  groups. The legacy `.devcontainer/scripts/` directory was removed;
  `lib/common.sh` and `templates/install-script.sh` are never executed
  by the build loop.
- `setup.sh` is now volume-aware: bind mounts from `docker-compose.yml`
  are parsed with `yq` and the install scripts that own each target
  (`~/.pi` → `30-ai-pi-coding` and `30-ai-pi-gentle`, `~/.engram` and
  `~/.local` → `30-ai-engram`) are re-run with `DEVCONTAINER_PHASE=runtime`
  on every container start.
- The devuser creation path in `01-core/90-post-setup-users.sh` and the
  matching `HOST_UID` / `HOST_GID` ARGs in the Dockerfile were removed.
  The project settles on `ubuntu` as the single devcontainer user.
- Library-version ARGs in the Dockerfile (`ENGRAM_VERSION`,
  `NODE_MAJOR`, `PLAYWRIGHT_VERSION`) now have no default; the canonical
  default lives in the install script that consumes the value. The
  ARGs remain so users can still override via
  `docker build --build-arg VAR=...`, and the runtime ENVs are still
  propagated for re-installs at container start.
- The Pi config seeding in `setup.sh` switched from symlinks to a
  copy-on-first-run model. `seed_config_tree(source_root, target_root)`
  walks the source tree and copies each file to the equivalent path
  under the target, but only when the target does NOT already
  exist (the user's customisations are preserved across rebuilds).
  Targets outside `$HOME` escalate to `sudo` automatically. The
  pipeline no longer calls the seed function twice (no symlinks
  to re-link). The tree-walking shape means adding a new tool's
  baseline config is one `seed_config_tree` call in
  `setup_versioned_pi_config()` plus the source tree under
  `.devcontainer/<name>-config/`.
- `go-task` is now in `install/core/15-task.sh` and is unconditionally
  present in the image; the previous `available/40-cli-task.sh` opt-in
  path was dropped.
- Source files under `.devcontainer/install/` are mode 0755 to match the
  Dockerfile's `chmod 0755` and the workspace bind-mount contract. The
  runtime groups carry a `01-` / `02-` / `03-` prefix as a visual hint
  of execution order; the prefix is not load-bearing for ordering.

### Security

- Documented local state, secret handling, Git/GitHub credentials, Engram local
  memory, and privileged devcontainer considerations.
