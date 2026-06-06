# Changelog

All notable changes to Gentleman Starter will be documented in this file.

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

### Changed

- Renamed the starter identity to Gentleman Starter.
- Simplified the Docker Compose service name to `dev`.
- Cleaned `.devcontainer/devcontainer.json` and removed the empty VS Code
  extension entry.

### Security

- Documented local state, secret handling, Git/GitHub credentials, Engram local
  memory, and privileged devcontainer considerations.
