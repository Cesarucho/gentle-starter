# Verification workflow

## Strict TDD evidence

1. **RED:** add the smallest installer/helper/doctor/integration contract test and run it before implementation. Record the expected failure, not a syntax accident.
2. **GREEN:** implement the minimum behavior and rerun the focused test.
3. **TRIANGULATE:** add architecture, idempotency, retry exhaustion, partial-failure, and rollback cases appropriate to the mechanism.
4. **REFACTOR:** remove duplication while all focused tests stay green.

Do not claim RED retroactively. If the derivative has no test harness, first add or identify a minimal executable contract and report the limitation.

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

Run directly applicable BATS files first. Validate every new shell file with `bash -n` and ShellCheck; preserve executable mode and a trailing newline. Validate Markdown and frontmatter with the repository's existing tooling. Ensure `SKILL.md` has valid YAML, matching kebab-case name/directory, one-line description, and the required section order.

## Contract checklist

- Catalog lists the tool dynamically; no expected-count assertion became stale.
- Enabled symlink is relative, unbroken, uniquely ordered, and recreated at the intended `preferred_enabled_name` when disabled/enabled.
- Policy parser accepts the new keys; environment precedence and architecture selection have isolated tests.
- Doctor checks actual availability without performing installation.
- Integration test skips when the canonical enabled link is absent and performs a meaningful version/function check when present.
- Config seeding preserves existing files; volume repair is added only for mutable state and has all three owners wired.
- Documentation describes only surfaces actually changed.
- `deps:update` either updates all coupled values atomically and validates before replacement, or explicitly leaves the tool manual.

## Host and clean-flow verification

Never start nested host-only container tasks from an ordinary devcontainer session. Read `AGENTS.md` and task guards. If the repository documents simulated host verification, use a temporary repository copy under a host-visible mounted workspace, set its test-only host override, build/up there, execute full validation through `devcontainer exec`, remove the simulated container, then delete the copy. Do not mutate the main workspace.

A running pre-change container cannot prove image installation. Rebuild from a real host or documented simulation when lifecycle behavior changed. Keep destructive clean/bootstrap checks in a separate temporary copy.

## Reviewer-load report

Report `git diff --stat`, `git diff --numstat`, total changed lines, and logical review units. Recommend splitting when unrelated mechanisms, broad policy migration, config/volume work, or generated content obscures the installer. Never commit, push, publish, or open a PR unless explicitly authorized.
