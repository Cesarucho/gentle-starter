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
- Added idempotent Pi workspace trust setup for `/home/ubuntu/code`.
- `task ai:update` now re-pins selected Pi packages with explicit latest npm
  versions after updating.
- `task container:pi` now opens Pi with `pi --continue`.

### Security

- Documented local state, secret handling, Git/GitHub credentials, Engram local
  memory, and privileged devcontainer considerations.
