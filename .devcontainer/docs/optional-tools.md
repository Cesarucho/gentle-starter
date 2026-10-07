# Optional tools

Choose tools explicitly; suggestions do not activate automatically at startup.
Run from the project root **inside the container**:

```bash
task suggest:tools
```

Enter numbers separated by spaces or commas, `all`, or `none`. Repeated numbers
select an entry only once. Review the selected tools and required dependency plan,
then confirm once. Invalid selections, `none`, cancellation and input EOF create
no aliases. Task arguments after `--` are rejected without shell evaluation.

## What activation changes

The consumer catalog `.devcontainer/install/recommended-tools.json` is a version-1
object with a `tools` array of unique canonical installer filenames. Its order
controls menu numbers. It is independent of the published starter's default
activation set. An empty array offers no tools; missing or unsafe entries fail
before the menu appears.

Selected tools and their required transitive dependencies are enabled additively
in `03-enabled/`. Mandatory core tools are reused, not copied into optional
activation. Dependencies come only from `dependencies.conf`; companion tools are
not selected implicitly. Existing valid custom aliases and unselected tools are
retained, and repeat activation is idempotent.

All selected roots and the complete projected selection are checked before any
link is created. Application revalidates under the shared enable/disable lock;
failure rolls back only operation-created links whose ownership still matches.

Activation affects **future builds only**. It does not execute installers, rebuild
the container, uninstall runtime tools, or select Compose integrations. For actual
build/start operations, follow the **HOST** workflow in the
[extension guide](extending.md). Compose selection remains independent; see
[optional integrations](optional-integrations.md).

## Select skills and tools together

```bash
# CONTAINER: project root
task suggest:all
```

The command validates both catalogs first, collects skills and tools selections,
and shows one final confirmation. Recommendations are a confirmation snapshot;
changing menu order or skill sources during confirmation does not redirect the
selected entries. Actual installer roots and dependencies are revalidated before
activation.

| Stage | Failure behavior |
|---|---|
| Catalogs, choices or tool preflight | No tool links or Skills CLI calls. |
| Tool activation | Reports the failed stage; Skills CLI is not started. |
| Skills installation | Continues remaining selected installs, reports failed names and exits nonzero. Activated tools and successful installs remain applied. |

The stages are sequential, **not a cross-system atomic transaction**. Inspect tool
activation, `skills-lock.json` and installed skills after partial success. The
combined command needs the published skills catalog; development checkouts do not
fall back to their development lock. Use `task suggest:tools` independently when
that skills catalog is unavailable. See [optional skills](optional-skills.md).
