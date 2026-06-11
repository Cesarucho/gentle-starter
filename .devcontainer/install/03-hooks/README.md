# `03-hooks/` — Personal install extensions

This directory is the **last** group the Docker build loop iterates
(after `01-core/` and `02-enabled/`). Every executable `*.sh` you drop
here is sourced and run during image build, in lexicographic order by
filename. Use the same numeric-prefix convention as the other groups
when the order matters (`00-`, `10-`, `20-`, …).

## When to use this directory

- The tool is **yours**, not the project's. A VPN cert, a personal
  alias installer, a company-internal CLI, a one-off experiment.
- You want it to land in **every** rebuild of *your* devcontainer,
  but it should not be in the shared repo.
- It does not belong in `available/` (opt-in for everyone) and
  definitely not in `01-core/` (mandatory for everyone).

If the tool is useful to the project, graduate it: copy it from
`03-hooks/` into `available/`, refactor it to use `lib/common.sh`,
and link it from `02-enabled/` so the next person benefits too.

## Conventions

- **Filename**: `NN-purpose.sh` (the `NN-` controls order; `00-` runs
  first, `99-` runs last). The extension is `.sh`.
- **Mode**: `0755`. The Dockerfile runs `chmod 0755` on every `*.sh`
  under `install/`, so the source mode is not load-bearing — but if
  you `chmod 0644` it on the host, the build will still set `0755`
  in the image.
- **Shebang + strict mode**: start with `#!/usr/bin/env bash` and
  `set -euo pipefail`. Drop `-u` only if you source SDKMAN (see
  `02-enabled/20-runtime-java.sh` for the carve-out).
- **Helpers**: `source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"`
  gives you logging, arch detection, `devcontainer_run_as_root`,
  `devcontainer_has_cmd` (for idempotency), and so on.
- **Idempotency**: guard the body with `devcontainer_has_cmd` /
  `devcontainer_skip_if_cmd` so re-runs are no-ops.

## Minimal example

```bash
#!/usr/bin/env bash
#
# 00-my-company-vpn.sh — drop a site-specific client cert into the
# container. Replace with whatever you actually need.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_log_info "Installing company VPN cert"
devcontainer_run_as_root install -m 0644 \
    "${SCRIPT_DIR}/certs/internal-ca.crt" \
    /usr/local/share/ca-certificates/internal-ca.crt
devcontainer_run_as_root update-ca-certificates
```

## Visibility

This directory is **not** in `.gitignore` on purpose: a script you
drop here will show up in `git status` so you can see what is in
scope for *your* checkout and decide what to do with it (commit it
as a project-level opt-in by moving it to `available/`, or leave it
untracked as a personal one-off). Use `git status --ignored` if you
also want to see the contents of other ignored paths.

## The "order" question

If you find yourself wanting a script in `03-hooks/` to run **before**
something in `01-core/` or `02-enabled/`, that is a sign the script
should move to one of those groups (probably `02-enabled/` if it is
opt-in for the team, or `01-core/` if it is mandatory). The numeric
prefix within a group controls in-group order; the *group order*
itself is fixed by the Dockerfile's `for group in 01-core 02-enabled
03-hooks` loop.
