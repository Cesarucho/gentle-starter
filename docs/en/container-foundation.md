# Automatic foundation cache

The Dockerfile separates stable core setup from project tool installation:

1. `foundation` copies and runs `01-core` with its required `common.sh` library.
2. `devcontainer` derives from `foundation`, applies the tool-version
   build-argument-to-environment contract, then copies version policy, available
   installers, enabled aliases, and hooks.

An independent `devcontainer-version-contract` test target derives directly
from the configured base image. It applies the same tool-version ARG/ENV block
without building `foundation` or installing tools, keeping focused contract
tests inexpensive. Static tests prevent that duplicated contract from drifting.

Because tool-specific inputs appear only after `foundation`, changing them does
not invalidate the core layer. `task container:build` and
`task container:up` rely on BuildKit's ordinary cache lookup; there is no
separate foundation image, tag, lifecycle command, or metadata.

Go Task is itself required to expose those workflows, so `01-core/15-task.sh`
installs it as an external APT-managed core bootstrap. It is deliberately
outside `.devcontainer/tool-versions.conf`: the signed Cloudsmith APT repository
owns package version selection and package integrity, while the initial
`setup.deb.sh` repository bootstrap is trusted through HTTPS/provider delivery
rather than authenticated by APT signatures. Failures stop the build, and a
transient provider or network failure requires a manual retry.

Cache reuse is automatic only when builds can access the same BuildKit cache,
typically on the same Docker builder. It is not a cross-machine guarantee, and
cache eviction, builder replacement, base-image changes, core argument changes,
or changes to `01-core` and `common.sh` rebuild the foundation. Locale and
timezone generation are core setup, so changing `LOCALE`, `TZ`, or their core
installers invalidates `foundation`; tool-version policy remains downstream and
does not.
