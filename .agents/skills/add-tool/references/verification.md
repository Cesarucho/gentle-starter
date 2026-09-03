# Verification workflow

## Proportional evidence

| Change | Required evidence |
| --- | --- |
| Behavior, lifecycle, trust, provider | Focused characterization or genuine RED before implementation, then GREEN and relevant edge cases |
| Mechanical version/digest | Existing updater, policy, and installer checks |
| Enable/disable only | Helper behavior, relative alias target, uniqueness, and execution order |
| Documentation only | Documentation/Markdown validation |
| Removal | Focused absence checks plus remaining layout/policy validation |

Never claim RED after implementation. If no harness exists, add the smallest executable contract or report the limitation.

## Adaptive command discovery

Use the inspection script, then read the repository's Taskfile before running commands. Common compatible tasks—only when present—are:

```bash
task install:list
task install:doctor
task install:versions:validate
task install:volumes
task validate
task validate:full
task test
```

Run directly applicable BATS files first. Validate changed shell with `bash -n`, ShellCheck, executable mode, and trailing newline. Validate Markdown/frontmatter with repository tooling. Run broader checks only when their expected duration and scope are proportionate.

## Contract checklist

- Catalog lists the tool dynamically; no expected-count assertion became stale.
- Enabled symlink is relative, unbroken, uniquely ordered, and recreated at the intended `preferred_enabled_name` when disabled/enabled.
- Policy parser accepts the new keys; environment precedence and architecture selection have isolated tests.
- Doctor checks actual availability without performing installation.
- Integration test skips when the canonical enabled link is absent and performs a meaningful version/function check when present.
- Config seeding preserves existing files; every managed bind uses long syntax and `create_host_path: false`.
- Host preparation passes isolated empty and pre-populated state tests: exact created UID/GID/`0755`, preservation, and symlink/file/wrong-owner failures.
- Passive mounts have no installer mapping; installer-owned mounts have an enabled runtime-safe owner and idempotent repair coverage.
- Structured Compose parsing uses complete JSON/Python and NUL-safe records without delimiter splitting, executable base64, or PATH-dependent `realpath`.
- Documentation describes only surfaces actually changed.
- `deps:update` either updates all coupled values atomically and validates before replacement, or explicitly leaves the tool manual.

## Host and clean-flow verification

Never start nested host-only container tasks from an ordinary devcontainer session. Read `AGENTS.md` and task guards. If the repository documents simulated host verification, use a temporary repository copy under a host-visible mounted workspace, set its test-only host override, build/up there, execute full validation through `devcontainer exec`, remove the simulated container, then delete the copy. Do not mutate the main workspace.

A running pre-change container cannot prove image installation. Rebuild from a real host or documented simulation when lifecycle behavior changed. Keep destructive clean/bootstrap checks in a separate temporary copy.

## Reviewer-load report

Report `git diff --stat`, `git diff --numstat`, total changed lines, and logical review units. Recommend splitting when unrelated mechanisms, broad policy migration, config/volume work, or generated content obscures the installer. Never commit, push, publish, or open a PR unless explicitly authorized.
