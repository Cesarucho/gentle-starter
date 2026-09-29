# Retire legacy project bootstrap

## Objective

Remove the maintainer-only `project:init`, `clean`, and `clean:identity` workflows and their live documentation/tests. Preserve the independent linear `starter` candidate/promotion workflow, committed-source filtering, and consumer exclusion guarantees.

## Scope and constraints

- Authorized: retire legacy task routes, scripts, dedicated tests, and current instructions; retain historical task records as historical evidence.
- Do not modify remote refs, publish releases, run cleanup on the primary worktree, or change the filtered release contract.
- Branch: `feat/retire-legacy-project-bootstrap`; route: delegated direct (multiple nontrivial files and preparation reads).
- TDD: not established in project/session configuration; use ordinary focused regression checks. Runner: Bats via `bats` and maintainer `test:starter:unit`.
- Delivery: `ask-on-risk`; estimated authored change exceeds ~400 lines because retired shell script and fixture suite alone exceed 800 lines. No push or PR authorized. Repository policy requires owner approval of reviewed diff before commit.

## Tasks

- [x] R1: Removed legacy maintainer task routes and scripts; task listing still contains candidate/promote and active-reference search found no surviving invocation.
- [x] R2: Removed the initializer/cleanup-specific Bats suite; retained negative distribution and consumer exclusion assertions. Focused Bats: 31/31; maintainer unit suite: 462/462.
- [x] R3: Removed current bootstrap guidance while retaining release/update guidance. `task validate`: passed, including Markdown lint (20 files, zero issues); `git diff --check`: passed.
- [x] R4: Reproduced a consumer's local workflow with a fixture-only future `starter`: generated and cloned release, built image, started the sub-devcontainer, and separately verified nested Docker. Registered resources were removed selectively; two verified DinD state volumes and shared cache were retained. Run `ab9d3d3a-a6a8-43ad-b42f-f8a492aba52d`; read-only recovery preview confirms `passed` with expected retention.
- [x] R5: The owner chose not to pursue the earlier unmarked run `29f7a762-7c76-45af-9244-5f27331697c6`. Preserve its stopped container, network, volumes, scratch, and inventory without claiming cleanup or retroactive ownership; it does not block the separately verified consumer run.
- [x] R6: Include the owner's concurrent OpenCode config and profile changes in the final reviewed diff: updated `opencode.json`, `openai-100usd-astral.json`, and `openai-20usd-pareto.json`; deleted `openai-100usd-solar.json`; corrected the README profile inventory. All modified JSON parsed; structural agent-role/model/effort checks, README Bats (7/7), full maintainer unit suite (462/462), `task validate`, and `git diff --check` passed. These owner-authored changes are a separate commit work unit from the bootstrap retirement.

## Progress and evidence

- Initial audit: release filtering works on committed Git trees in `starter-source.py`; legacy `clean-lib.sh` is called only by `clean.sh` and `project-init.sh`.
- The first broad unit-suite attempt timed out after test 341/462 under a 120-second supervisor; a subsequent bounded 10-minute run passed 462/462.
- Direct `markdownlint` command was unavailable; `task validate` ran the configured `markdownlint-cli2` successfully instead. The original reduced base lifecycle was not run; the separately authorized consumer lifecycle attempt and its incomplete cleanup are recorded below.
- Historical `odd/tasks/` records still describe past init/cleanup behavior; active consumer exclusion assertions intentionally mention the old names to prevent their return.
- Publication fixture test: `bats .maintainer/test/unit/starter-distribution.bats` passed 24/24. Existing lifecycle fixture disables DinD and cannot prove the generated release. User explicitly authorized implementing a new safe DinD proof before versioning this document.
- R4 clarification: the user wants the consumer experience (clone a locally generated release, build its image, and turn it on), not a universal proof of every external side effect. An earlier always-refusing preflight offered no DinD evidence and was removed.
- R4 partial live evidence: a fixture-only source commit, candidate, promotion, and consumer clone matched a filtered release tree in temporary Git. The subsequent isolated consumer run `29f7a762-7c76-45af-9244-5f27331697c6` built its image and `devcontainer up` reported success; the harness then refused to adopt the two unlabeled DinD feature volumes, before nested Docker verification. The labeled running container was stopped after checking its exact run/project labels and daemon. The stopped container, network, feature volumes, scratch, and private inventory remain for reviewed recovery; automatic cleanup preview reports an ownership-label conflict. No DinD pass or complete cleanup is claimed. Never delete these by project prefix alone: the v1 inventory lacks pre-creation proof for those volumes.
- User accepted a bounded exception: recognize exactly the two expected DinD Feature state volumes through the run's Compose project and actual container mounts, retain them without asserting deletion authority, and still reject any other unknown volume. Report build/up and optional inside-container results separately, and never call retained-volume cleanup complete. Apply only after focused mock proof and a read-only preview of the retained run.
- New consumer run `ab9d3d3a-a6a8-43ad-b42f-f8a492aba52d` passed fixture release/clone, build, up, and nested Docker smoke. Registered container, network, two images, and scratch were removed and verified; two DinD Feature state volumes plus shared build cache intentionally remain. The subsequent recovery preview reports `test=passed`, `cleanup=retained`, with only the expected two volumes and cache; it does not claim complete removal. The original unmarked run remains stopped and preserved independently.
- Commit: deferred until the owner approves the reviewed diff. The old run remains retained by the owner's choice and is not part of this task's proof. No remote publication authorized. Next: review the final diff and the optional native review before commit approval.
- User-owned OpenCode config and profile updates are explicitly included in the review set; preserve their exact bytes. The config diff changes agent model and reasoning-effort settings only; no changed-value credential pattern was detected. Runtime model availability was not established. OpenCode loads configuration on startup, so a running session will not adopt these settings until restart. README now lists only existing profiles.
- Review limitation: the owner declined native review for the OpenCode candidate, then authorized continuing this work without the blocked native review after all four retirement reviewer launches refused with `opencode_review_transport_binding_invalid`. The frozen retirement transaction remains incomplete; no approval or receipt is claimed and review mode remains enabled. Functional and consumer-flow evidence above remains separate. Planned delivery is three local work-unit commits; final reviewed-diff approval is still required, with no push authorized.
