# Automatic foundation and core-tool cache

The Dockerfile separates shared setup from project-specific installation:

1. `foundation` copies and runs `01-foundation` with `common.sh` and the runner.
2. `core-tools` derives from `foundation`, copies the central version policy,
   required archive helper, selective core installer sources, and `02-core-tools`
   aliases, then installs the mandatory tools. ENGRAM_VERSION and NODE_MAJOR
   overrides enter here.
3. `devcontainer` derives from `core-tools`. Only here do APP_NAME,
   PLAYWRIGHT_VERSION, optional sources/selectors, and `04-hooks` enter the build.

An independent `devcontainer-version-contract` test target derives directly
from the configured base image. It applies the same three tool-version overrides
without building `foundation` or installing tools, keeping focused contract
tests inexpensive. Static tests prevent that duplicated contract from drifting.

Because tool-specific inputs appear only after `foundation`, changing them does
not invalidate the foundation layer. Optional installer sources, aliases, hooks,
and project names do not enter the shared core installation stage. The whole
policy file does: even an optional version edit can invalidate core. No separate
policy projection or generated manifest is introduced. `task container:build` and
`task container:up` rely on BuildKit's ordinary cache lookup; there is no
separate foundation image, tag, lifecycle command, or metadata.

Go Task is itself required to expose those workflows, so `01-foundation/15-task.sh`
installs it as an external APT-managed core bootstrap. It is deliberately
outside `.devcontainer/tool-versions.conf`: the signed Cloudsmith APT repository
owns package version selection and package integrity, while the initial
`setup.deb.sh` repository bootstrap is trusted through HTTPS/provider delivery
rather than authenticated by APT signatures. Failures stop the build, and a
transient provider or network failure requires a manual retry.

Cache reuse is automatic only when builds can access the same BuildKit cache,
typically on the same Docker builder. It is not a cross-machine guarantee, and
cache eviction, builder replacement, base-image changes, core argument changes,
or changes to `01-foundation` and `common.sh` rebuild the foundation. Locale and
timezone generation are core setup, so changing `LOCALE`, `TZ`, or their core
installers invalidates `foundation`; tool-version policy remains downstream and
does not.

The group migration intentionally causes an initial cache miss. Reuse requires
compatible builder inputs, architecture, arguments, versions, and accessible
cache; it is not universal across Docker daemons. Static tests verify stage
boundaries and that selective core COPY sources match the actual core aliases.
They do not measure cache hits or prove a successful image build.
