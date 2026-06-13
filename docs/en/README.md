# `docs/`

Project documentation. The English originals live under `en/`.
When in doubt, the English version is canonical.

## What's here

| File | What it's for |
|---|---|
| [`en/extending.md`](./en/extending.md) | **Start here.** The comprehensive guide for adding new functionality. Covers the three systems (install, volumes, configs), a worked example, and the FAQ. |
| [`en/install-tree.md`](./en/install-tree.md) | Deep dive on the `install/` convention: groups, numbering, how to add a new install script. |
| [`en/install-volumes.md`](./en/install-volumes.md) | Deep dive on the volume repair contract: how the bind-mount → owning-script mapping works, how to add a new stateful volume. |
| [`en/configs.md`](./en/configs.md) | Deep dive on `seed_config_tree`: privilege detection, the three cases, idempotency rules, the `*.local` pattern. |
| `assets/` | Brand assets (logo, etc.). |

## Where to start

If you want to **add a new tool** (Redis, kubectl, your own CLI),
read [`en/extending.md`](./en/extending.md) end to end. It's a
10-minute read that covers everything you need.

If you want to **understand a specific system**, jump to the
relevant deep-dive:

- Adding an install script? → [`en/install-tree.md`](./en/install-tree.md)
- Adding a stateful volume? → [`en/install-volumes.md`](./en/install-volumes.md)
- Adding a baseline config? → [`en/configs.md`](./en/configs.md)

If you have a **specific question** that isn't covered by the above,
check the FAQ at the bottom of [`en/extending.md`](./en/extending.md)
before opening an issue.

## Conventions

- English is canonical.
- Each file in `en/` is a self-contained document. Cross-references
  between docs are explicit links.
- The docs are versioned with the project. Updates to a system
  (e.g. changing `seed_config_tree`'s privilege detection logic)
  must be reflected in the corresponding doc in the same commit.
