# AGENTS.md

This file is the AI-facing context for Gentle Starter. Read it before changing
the repository. Human-facing details live in `README.md` and `.devcontainer/docs/`.

## Project identity

Gentle Starter is a ready-to-prompt devcontainer for the Gentle AI ecosystem.
It builds an Ubuntu 24.04 environment with mandatory OpenCode, Gentle AI,
Engram, Bats, Node/npm, pnpm, markdownlint, Dev Container CLI, and Skills.
Pi, Go, Java, and other catalog tools remain optional.

At session start, inspect the current branch, `HEAD`, worktree, and remotes.
Never rely on branch or commit metadata copied into documentation.

For code and documentation edits, leave changes unstaged and uncommitted after
verification so the owner can review them in VS Code. Commit only after the
owner explicitly approves the reviewed diff; preserve unrelated local edits.

## Execution topology

- **Current environment:** The agent runs INSIDE the devcontainer. The host owns
  the repo bind-mounted at the current path: the same checkout, not an independent clone.
- **Continuity:** Retain this topology across handoffs and compaction;
  reconcile a changed environment before relying on it.
- **Host commands:** Run `task container:*` on the HOST, not in this container; respect skip guards.
  Never bypass them with `FORCE_HOST_CONTEXT=1` in the primary worktree; host simulation requires an explicitly authorized isolated fixture.
- **Operational instructions:** Label execution as HOST or CONTAINER and distinguish their paths
  in every lifecycle, build, connect, or release-candidate (RC) recipe. Recipes are not execution authorization.
- **RC test:** On this same host, use a separate host folder for a local clone of the host repo;
  it has independent checkout/state and needs no publishing or transfer. The mounted repo is not that clone.
- **Unknown details:** Do not invent host path, location, OS, daemon topology, or SSH authority, or assume the host is the user's physical PC.
  Ask only for a genuinely missing destination/path, not settled topology; never probe ambient credentials or sessions or infer remote permission.

## Task-response closing

After each completed task, including implementation, investigation, explanation,
and small changes, give a concise outcome or confirmation with relevant
verification and limitations. Recommend one concrete next step; if no work is
pending, say so rather than inventing tasks. Include an alternative only for a
meaningful decision or tradeoff, and briefly distinguish it from the recommendation.
Keep the response short and proportionate, without mandatory menus or list boilerplate.

Recommendations do not authorize executing the next step, expanding scope,
committing, pushing, opening a PR, or taking remote actions. When blocked, do not
imply completion; honestly state the blocking action. Preserve clarification and
blocking prompts intact and losslessly, then stop and wait. Do not append extra
choices or forced recommendations to provider-owned prompt envelopes.

## ODD record closure

Only the orchestrator/parent closes authorized ODD work; workers report evidence
and remaining work. This is procedural instruction, not runtime automation.

Before closure, reconcile the authorized scope and observed, reported results of
applicable checks, including explicitly accepted skipped or unavailable proofs.
Do not close with real pending implementation, product decisions, or unresolved
closure uncertainty; checked boxes alone are insufficient. Optional future work
is not a current blocker. Require commit, push, or PR only when the explicitly
authorized scope requires that delivery. Respect applicable pending native proof
and review authority; never claim review approval from task completion.

After reconciliation and before reporting closure, the parent MUST move completed
or explicitly superseded authorized feature records to `odd/archive/{same name}.md`.
Preserve all historical content and evidence; do not delete history, overwrite
another record, or proceed through a destination collision. Update current
navigation links and the full project-scoped Engram mirror under the same stable
topic, including the new repository-relative locator. Read back both the local
record and full mirror. If archival is unsafe or the mirror is unavailable,
preserve existing state and honestly report archive or mirror pending rather than
claiming closure.

Before creating a new `odd/tasks/` record, the parent MUST inventory and reconcile
existing records there against the closure criteria above. This gate explicitly
authorizes only precreation archival of proven completed or explicitly superseded
records, with all archival, history, collision, navigation, Engram mirror, and
readback guarantees above. Preserve active, pending, or ambiguous records; unrelated
active work does not block creation, and the directory need not be empty. If an
eligible record cannot be safely archived or its full mirror verified, report the
blocker and do not create the new record until resolved.

This rule applies only to ODD records. It authorizes no source mutations beyond
the approved scope. Outside the narrowly scoped precreation gate above, retroactive
bulk classification or archival requires explicit authorization; the gate does
not authorize general bulk cleanup.

## Project initialization and updates

- Once a linear `starter` release is published, consumers should clone that
  branch to retain ancestry with later releases. Its history does not descend
  from producer `dev`; a fork of `dev` is not equivalent to a consumer clone.
- The distributed `starter` tree excludes `AGENTS.md`, `AGENTS.md.TEMPLATE`,
  and `AGENTS.md.TEMPLATE.EXAMPLE`; the dev template remains tracked.
- After a release is published, consumer updates use conventional Git:

  ```bash
  # Add upstream only if the consumer clone does not already have it.
  git remote add upstream https://github.com/Cesarucho/gentle-starter.git
  git fetch upstream
  git merge upstream/starter
  ```

  Resolve conflicts manually. GitHub template-generated repositories do not
  share ancestry; shallow clones may require `git fetch --unshallow upstream`.
  For unrelated existing projects, use the reviewed first-merge procedure in
  `.devcontainer/docs/existing-project.md`.

## Extension architecture

Gentle Starter has four coordinated extension surfaces:

1. **Install tree** (`.devcontainer/install/`) — build-time scripts grouped as
   `01-foundation/`, mandatory aliases in `02-core-tools/`, optional aliases in
   `03-enabled/`, and user hooks in `04-hooks/`. Canonical tool installers live
   in `available/`. Docker stages are `foundation` → `core-tools` → `devcontainer`.
   Core aliases and selective Dockerfile source/helper COPY inputs must agree.
   Keep project identity, optional sources/selectors, and hooks downstream of core.
2. **Persistent state** — `task container:up` prepares managed `.env.d` bind
   sources as the host user before Docker starts; `.devcontainer/lifecycle/setup-volumes.sh`
   maps container targets to enabled owner scripts for runtime population.
3. **Config seeding** (`seed_config_tree` in `.devcontainer/setup.sh`) — copies
   versioned baseline configuration on first run. Do not replace this with
   runtime config symlinks; tools that atomically rewrite files break them.
4. **Tool-version policy** (`.devcontainer/tool-versions.conf`) — keeps editable
   `TOOL_*_VERSION` intent above a final generated `LOCK_*` section.
   `task tools:update` is the only mutation authority; builds and installers are
   read-only and carry no local version/checksum defaults.

Start with `.devcontainer/docs/extending.md`; use the linked deep dives for each surface.

## Project skill lifecycle

- External skills restored by the Skills CLI remain in `skills-lock.json`.
- Installed external content under `.agents/skills/` is Git-ignored; keep the
  lock tracked, not the installed copies. Local-only skills may be absent from
  the lock and are not restored by it.
- Repository-authored `add-tool` lives in `.agents/skills/add-tool/` and is
  tracked by Git, not by external lock metadata. Load its `SKILL.md` for managed
  tool installation, activation, provisioning or state-lifecycle changes.
- Repository-authored `operational-verification` lives in
  `.agents/skills/operational-verification/`; load its `SKILL.md` for operational
  checks, lifecycle tests or environment verification. It is producer-only;
  its local harness reference is excluded from consumer releases too.
- Use the installed `skills` CLI: `skills add <source> --skill <name> --agent universal --copy -y`,
  `skills experimental_install -y` (experimental lock restore),
  `skills update --project -y`, and `skills list --json`.
- Remove only by explicit name: `skills remove <name> -y`. NEVER run
  `skills remove --skill '*'`: it deletes tracked `add-tool` and
  `operational-verification` too.
- Review `git status` and `git diff` after CLI operations; restore a mistakenly
  deleted authored skills from Git after owner review. Generated `.claude/` is ignored;
  do not delete personal `.claude/` files.

## Settled conventions

- The project uses `ubuntu` as the sole devcontainer identity. Do not restore
  `devuser` or `HOST_GID`. `HOST_UID` is generated only after the host guard,
  exclusively to locate the optional host Pulse socket; it is not container identity.
- Source scripts under `.devcontainer/install/` use mode `0755` intentionally.
- Dockerfile group iteration is the load-bearing install order; directory
  prefixes are visual hints, while filename prefixes control in-group order.
- Catalog names use unique `BBPP-category-tool.sh` prefixes: related-tool block
  `BB`, position `PP` from `00` to `99`, with gaps allowed. Generated aliases use
  the identical canonical basename. Preserve valid custom aliases and actual
  layer-first, filename-second execution order.
- Enable/disable modifies only `03-enabled/` and refuses mandatory core tools.
  `dependencies.conf` alone defines dependencies. Enable plans the required
  transitive closure, reuses core, and repairs missing dependencies of active tools;
  companions are never autoactivated. Validate the whole projected selection
  before mutation under the shared lock; roll back only operation-created links.
  Core aliases must match selective Dockerfile COPY inputs. Disable protects
  active dependents and does not remove orphan prerequisites.
- `04-hooks/` is intentionally visible to Git.
- `task env:backup`, `task env:restore`, and `task pi:diff-config` are deferred.
  Do not implement them without explicit approval.

## Verification

Before operational commands, lifecycle/environment proof or test-resource recovery
in this **producer repository**, MUST load both
[operational-verification](.agents/skills/operational-verification/SKILL.md) and its
[Starter harness reference](.agents/skills/operational-verification/references/starter-harness.md),
then follow their linked authoritative human contracts. If either is unavailable,
stop unsafe operational actions; do not substitute a missing-guard fallback.
These producer-only instructions are not distributed consumer requirements.

Execution and cleanup require explicit consent for their destinations and effects;
recipes are not permission. Stop on uncertain ownership, daemon identity or
permissions; never escalate or globally prune Docker resources. Follow
[Execution topology](#execution-topology): respect HOST skip guards and never use
`FORCE_HOST_CONTEXT=1` in the primary checkout. Verification grants no review,
commit or delivery approval.

Ordinary unit TDD does not require operational skill activation. Inspect fixtures
before running them; operational effects or expensive checks trigger the routing
above. `task test` is application-owned; Starter regression is maintainer-only.
`task validate`/`install:doctor` are quality/diagnosis, not application or full
runtime proof; HOST preflight is partial. Select commands and proof boundaries
from the harness reference rather than treating quality as runtime evidence.

## Known issues

1. Legacy symlinks may remain under `~/.pi/` from older builds. Remove the old
   runtime links before rerunning `.devcontainer/setup.sh`.
2. The build pipeline normalizes one line in `seed_config_tree`, which can
   produce a semantic-equivalent whitespace diff after rebuild. Do not fight
   that normalization.

## Documentation map

- `docs/en/README.md` — documentation index
- `.devcontainer/docs/extending.md` — comprehensive extension guide
- `.devcontainer/docs/install-tree.md` — install layout
- `.devcontainer/docs/install-volumes.md` — volume repair contract
- `.devcontainer/docs/configs.md` — config seeding
- `docs/en/adr/0001-install-layout-refactor.md` — install layout ADR
- `docs/en/adr/0002-centralized-tool-version-policy.md` — version policy ADR
- `docs/en/adr/0003-unified-tool-policy-ownership.md` — unified policy ownership
