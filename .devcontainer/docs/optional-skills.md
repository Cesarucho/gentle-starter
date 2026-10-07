# Optional skills

The published starter includes the repository-authored `add-tool` skill. Other
skills are opt-in; nothing installs automatically when the container starts.

## Choose suggestions

Inside the container, from the project root:

```bash
task suggest:skills
```

Enter several listed numbers separated by spaces or commas, `all`, or `none`.
There is no default selection. Review the selected names and confirm once before
installation. To skip the selection menu, pass exact catalog names directly to
the Bash script; confirmation is still required:

```bash
bash .taskfiles/scripts/skills-suggest.sh clean-code frontend-design
```

Task arguments after `--` are rejected, not evaluated as shell commands. Use
the script for batch names; quote any names containing shell metacharacters.

The selector reads `.devcontainer/skills/recommended.json` from the published
`starter` branch. On the development branch that file is absent; the command
reports that suggestions are unavailable instead of reading its development
lock. You can install any other skill directly with the Skills CLI:

```bash
skills add owner/repo --skill skill-name --agent universal --copy -y
```

The universal target installs the skill in `.agents/skills/`.

Installed external skills are Git-ignored; only the repository-authored `add-tool`
is tracked under `.agents/skills/`. Keep `skills-lock.json` versioned to restore
external packages. Local-only skills absent from the lock stay ignored and must
be preserved separately; lock restoration does not recreate them.

The task validates the whole selection before calling Skills CLI. Each selected
skill is added separately; if one fails, the remaining selected skills are still
attempted and the failed names are reported. Check `skills-lock.json` and the
installed skills after a partial failure. Your lock and custom skills remain
your responsibility; this command does not remove or overwrite them directly.

To select tools and skills together, use `task suggest:all`. Both catalogs and
selections are validated before one final confirmation. Tools are activated first;
Skills CLI runs only after the tool stage succeeds. Successful skill installs and
tool activation remain applied if a later skill install fails. See
[optional tools](optional-tools.md) for the future-build activation contract.
