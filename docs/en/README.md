# `docs/`

Maintainer documentation lives here. Reusable environment guides are canonical
in [`.devcontainer/docs/`](../../.devcontainer/docs/README.md).

## What's here

| File | What it's for |
|---|---|
| [Environment guides](../../.devcontainer/docs/README.md) | Extension, install, volume, integration, and configuration workflows. |
| [`container-foundation.md`](./container-foundation.md) | Automatic same-builder caching for the internal core Docker stage. |
| [`adr/0001-install-layout-refactor.md`](./adr/0001-install-layout-refactor.md) | Install-tree, ownership, ordering, and config-seeding decision. |
| [`adr/0002-centralized-tool-version-policy.md`](./adr/0002-centralized-tool-version-policy.md) | Canonical declarative tool-version policy and secure loader decision. |
| [`adr/0003-unified-tool-policy-ownership.md`](./adr/0003-unified-tool-policy-ownership.md) | User version intent, generated locks, and sole mutation authority. |
| `assets/` | Brand assets (logo, etc.). |

## Where to start

If you want to **add a new tool** (Redis, kubectl, your own CLI),
read the [extension guide](../../.devcontainer/docs/extending.md) end to end. It's a
10-minute read that covers everything you need.

If you want to **understand a specific system**, jump to the
relevant deep-dive:

- Adding an install script? → [Install tree](../../.devcontainer/docs/install-tree.md)
- Adding a stateful volume? → [Volumes](../../.devcontainer/docs/install-volumes.md)
- Adding a baseline config? → [Configuration](../../.devcontainer/docs/configs.md)

If you have a **specific question** that isn't covered by the above,
check the FAQ at the bottom of the [extension guide](../../.devcontainer/docs/extending.md)
before opening an issue.

## Conventions

- English is canonical.
- Each guide is a self-contained document. Cross-references
  between docs are explicit links.
- The docs are versioned with the project. Updates to a system
  (e.g. changing `seed_config_tree`'s privilege detection logic)
  must be reflected in the corresponding doc in the same commit.
