# Route runtime directory contracts to the policy

Use the [exact-directory contract](../../../../.devcontainer/docs/install-volumes.md#exact-directory-runtime-permissions)
and [extension guide](../../../../.devcontainer/docs/extending.md) when a managed
runtime directory needs an exact mode or explicit creation. Read the current
[policy](../../../../.devcontainer/config/runtime-directory-permissions.json),
[schema/helper](../../../../.devcontainer/lifecycle/runtime-directory-permissions.py),
and [setup](../../../../.devcontainer/setup.sh) before changing that contract.

## Choose the owner

| Need | Route |
| --- | --- |
| Exact mode on an existing controlled runtime directory | Policy with `missing: "skip"` |
| Explicit runtime child provisioning | Policy with `missing: "create"`; declare every missing intermediate separately |
| Build installation or installed file modes | Installer; not this directory policy |
| Host bind-source preparation or ownership | Existing host/state lifecycle; never helper sudo/chown or bind-root repair |
| Config seeding, local-parent recovery, tool-specific security | Preserve the separate owner and its validated ordering |

Do not register every directory a tool owns. Add only a required managed contract;
leave ordinary tool-created state alone. Never introduce universal root changes.
The existing workspace authority rule uses `missing: "skip"`: absence grants no
authority-state creation permission and contents are never read by the helper.

## Declare only bounded exact directories

- Keep schema version `1`. Each rule requires `root`, `path`, `mode`, `missing`;
  only `when` is optional. Duplicate keys/rules and invalid fields fail closed.
- Select `workspace` or an exact `.env.d/...` managed source identifier from the
  validated applied Compose manifest. Managed rules address the **container
  target**, not the host source. Require snapshot integrity and applied identity.
  Read-only, external, file, absent, or ambiguous mounts are not usable roots.
- Use a nonempty relative `path`, never the root itself, absolute paths, empty
  components, `.` or `..`. Do not cross mounts or use workspace paths to bypass
  managed-source boundaries. Reject overlapping cross-root destinations/sources.
- Specify four-character ordinary octal text (`0000`–`0777`), with no special bits.
  Existing directories receive only their exact selected mode, not recursive
  descendant repair. `skip` leaves absence alone; `create` is not implicit
  `mkdir -p`. Every absent intermediate must have an applicable create rule.
- For optional managed roots, use exact `when.enabled_installer` with a real
  canonical catalog basename. Valid canonical aliases, including custom names,
  determine activation; Compose selection does not. Disabled rules are not
  applicable. Invalid conditions or unknown installers fail even when disabled;
  an applicable missing/invalid writable root fails, never silently skips.
  Conditions are not supported on `workspace` rules.

## Preserve safety and execution order

Require existing roots and target directories to belong to the runtime user.
Reject symlink components, wrong types, unexpected owners, unsafe writable
ancestors and permission errors; only `ENOENT` means absence. Absolute system
ancestors may be root-owned, with the helper's sticky-system-directory exception.
Do not open inaccessible parents by changing permissions or escalate privileges.

The helper pins no-follow directory descriptors and preflights **all applicable
rules**, even when `--root` or `--exclude-root` narrows mutation. Use
`--expected-root SOURCE=TARGET` when a consumer has a runtime target override:
the source must be applicable and uniquely match a writable applied bind target
before consumer mutations. Selection must not bypass unrelated unsafe paths.
Unselected exact modes remain unchanged; full safety validation is metadata-only.

Creation starts privately at `0700` under a restrictive umask; all children are
constructed before exact modes are finalized deepest-first, including `0000`.
Pinned identities, ownership and ancestor safety are rechecked before mutation.
Concurrent collisions/replacements fail rather than being adopted. Do not promise
transactions, rollback or complete race immunity: failures can leave private new
directories or already-applied modes behind.

Automatic application is **CONTAINER postCreate**, on creation/recreation only,
before tool use; later starts and **HOST restart** do not apply it. A skipped
directory created later waits until the next setup invocation. This is not
continuous enforcement. Setup obtains validated exclusions before generic
normalization and tracked-mode restoration, protecting complete policy subtrees,
first absent components, managed sources and workspace-contained mount targets.

Keep specialized root privacy recovery exceptional and installer-owned. Current
SSH sequencing is dry preflight before normalization, then SSH preparation
(root privacy recovery → scoped child apply → tool-specific preparation), general
apply excluding that root, then service startup. Its installer repeats dry
validation with the expected mapping before any mutation.
`--defer-root` is validation-only (`validate`/`exclusions`), never `apply` or
workspace: it defers only that owned managed root's privacy check, not owner,
type, child or other ancestor checks. Do not generalize it into root repair.

## Return contract evidence

Report rule choices, create intermediates or skip non-creation, canonical
applicability, applied source/target mapping, full preflight and lifecycle order.
For behavior changes, require focused fixture evidence for absent skip, explicit
create, idempotence, unsafe owners/symlinks, disabled applicability, enabled
missing/invalid roots, and preflight-before-mutation/tool-use ordering. Verify
unchanged root/ownership, descendants/files, unselected modes and restart behavior.
Use the existing [helper fixtures](../../../../.devcontainer/test/unit/runtime-directory-permissions-test.py)
and [installer/setup fixtures](../../../../.devcontainer/test/unit/tool-ownership.bats)
as the closest patterns; do not inspect actual authority contents to obtain proof.
For instruction-only edits, report structural/contract checks, not runtime proof.

## Existing cross-surface constraints

These are not runtime-directory rules. Apply the existing
[architecture](architecture.md), [provider matrix](decision-matrix.md),
[trust](supply-chain.md), and [verification](verification.md) contracts to their
respective surfaces; runtime policy does not replace them.

- Explicitly select foundation, core, optional or hook execution groups;
  coordinate core aliases with selective Dockerfile COPY inputs. Preserve
  `BBPP-category-tool.sh` naming, unique four-digit prefixes, identical generated
  basenames, valid custom aliases and layer-first, filename-second execution.
- Use only `dependencies.conf` for real dependencies. Under the shared lock,
  validate the full projected closure before mutation, reuse core, repair active
  consumers, never autoactivate companions, and roll back only created links.
  Enable/disable remains optional-only.
- Separate installation, copy-on-first-run configuration and mutable state;
  classify state as none/passive/installer-owned. Preserve host-prepared
  long-syntax binds with `create_host_path: false`, applied manifest identity,
  independent Compose selection and attach-only IDEs.
- Register each intent and generated lock output exactly once in the
  transactional updater; reject unsupported provider semantics. Keep version
  and integrity resolution/policy mutation exclusively in `tools:update`, with
  no installer-local version/checksum defaults or build-time discovery.
- Apply proportional trust, rollback, state, architecture, updater and
  verification controls. Require all supported architectures for direct
  artifacts before publication. Obtain explicit approval before weakening
  trust or lifecycle controls.
- Before removal, trace activation, policy, state, updater, tests and docs.
  Keep implementation, tests and user-facing docs in one reviewable work unit;
  refresh the registry officially only when metadata changes.
