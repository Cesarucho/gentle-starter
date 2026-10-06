# Default-enabled Gentle Shell v4

Gentle Shell uses the native `gentle-pi@4.0.0` npm package and its upstream
`gentle-shell` executable. The repository verifies the package tarball before
installation; upstream owns postinstall and first-launch setup. There is no
custom launcher, vendored Engram adapter or managed-Pi override.

## Quick path

1. Shell and standard standalone Pi are enabled by default as optional catalog
   tools, not mandatory core tools. If disabled, re-enable with
   `task install:enable -- 3040-ai-gentle-shell`. The planner selects standard
   Pi and reuses core Node/npm. Pi has no repository-managed Gentle plugins.
   Engram is not a declared Shell prerequisite;
   mandatory core Engram 3 remains independently available.
2. The new consumer persistence preset selects base Docker, core tools, Pi and
   Shell, in that order. Pi/Shell binds are passive and selected by default;
   consumers may customize their own `.devcontainer/devcontainer.json` later.
   Compose selection remains independent of installer activation.
3. On the host, rebuild and start with the normal container workflow. Image
   installation needs network access for npm dependencies and the upstream private
   Gentle AI binary. Node must be at least 22.19.0.
4. From the host, run `task container:gentle-shell` to launch the native interactive
   `gentle-shell --continue` as ubuntu, starting the container if needed. Inside
   the container, this Task skips the entire entrypoint; run `gentle-shell --continue`
   directly instead. Native Pi continues the latest session or creates one if none
   exists. Native first launch automatically sets up its
   own Shell agent; no `--link` or separate user setup command is needed. Pi,
   `gentle-engram` and other native companions remain upstream-owned, not a guarantee
   of reuse of the separately managed global Pi or core Engram.

The bounded Pi 1 operational proof verified native installation, automatic setup
and persistence through recreation. It did not test an interactive LLM/provider
session or the interactive Engram API. Matching managed and native Pi 1.0.0 versions
are observations, not global lock enforcement or a shared-binary guarantee.

## Configuration and persistence

The owner-selected versioned Shell tree contains agent settings, subagents, trust,
a home marker and launcher configuration; the Pi tree includes Gentle AI model
and feature preferences. The activation-gated postCreate seed hook copies only
missing files and preserves existing preferences and user data. Native setup owns
subsequent provisioning and companions. See [Configuration](configs.md) for the
runtime-to-repository export contract. Standard Pi preferences remain owner-controlled.
No adapter, configuration symlink or personal profile/database migration is provided.

Optional Shell-owned runtime inputs are documented as commented examples in
the repository-root `.env.example`, separately from inherited Pi inputs. Native
setup is automatic by default; `GENTLE_SHELL_NO_AUTO_SETUP=1` is an intentional
opt-out, not an offline mode. Runtime environment changes require host recreation,
not rebuilding the image. Custom preference roots are not automatically followed
by the fixed configuration export manifest.

The optional unchanged long-syntax bind maps host `.env.d/.gentle-shell` to
`/home/ubuntu/.gentle-shell` with `create_host_path: false`. Normal host Task
preparation owns the source directory. There is no Shell-specific runtime bind
ownership repair or new volume. Other upstream state paths are not covered merely
because this one directory is mounted; no complete companion persistence or
database safety guarantee follows from it. Native shared `.gentle` state, backups
and telemetry also mean this is not a global-home isolation guarantee. Standard Pi
retained its existing configuration without Gentle plugins in the bounded proof;
two empty upstream cache directories were not plugins.

## Integrity and trust boundary

`TOOL_GENTLE_SHELL_VERSION="=4.0.0"` is editable intent. Only `tools:update` owns
the generated `LOCK_GENTLE_SHELL_VERSION` and `LOCK_GENTLE_SHELL_INTEGRITY`.
The installer downloads that exact registry tarball, computes SHA-512 using
Node crypto and compares its base64 SRI with policy before npm runs scripts.
It installs the **same verified local tarball** using global npm with normal
lifecycle scripts; npm publishes the unchanged native executable link.

SRI detects changed package bytes relative to the recorded registry checksum. It
does not independently authenticate the publisher, verify npm attestations or pin
all transitive dependencies and first-launch companions. The acknowledged native
flow intentionally permits upstream peer resolution, private binary provisioning,
automatic setup and native development overrides. Private asset integrity checks
are those shipped in the pinned upstream package, not separate repository locks.

The image installer runs npm through the existing root helper. Upstream creates
owner-only package-private directories/files; afterward only the installed
`gentle-pi` subtree receives `a+rX` so ubuntu can read and execute it. Global npm
ownership, parent permissions and user state are not changed. This assumes the
standard traversable global npm prefix supplied by core Node. Mock mode checks
alone are not live root-to-ubuntu runtime proof. The bounded operational run also
verified ubuntu execution after native installation. Runtime calls do not reinstall
the package or modify a passive mounted Shell home; rebuild to repair installation.

## Updating the policy

Ordinary `task tools:update` resolves the two Shell outputs with the inventory.
Missing registered Shell locks use the ordinary updater's initial-lock bootstrap.
Discovery failure does not publish a partial policy. Selective Shell reconciliation
and legacy private-bundle migration are retired; no compatibility path remains.

Core Engram 3 remains an independent mandatory tool with its own existing policy
and scoped updater. It is not a Shell prerequisite or a claim that native Shell
uses the same Engram binary/database.

Managed Pi intent and lock are currently 1.0.0. The scoped
`task tools:update -- --update-pi 1.0.0` argument updates managed Pi only, not Shell's
internal tree. It is Pi-specific; a generic tool-selector interface is deferred.
