# Optional skills

The published starter includes the repository-authored `add-tool` skill. Other
skills are opt-in; nothing installs automatically when the container starts.

## Choose suggestions

Inside the container, from the project root:

```bash
task skills:suggest
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
skills add owner/repo --skill skill-name --agent pi --copy -y
```

The task validates the whole selection before calling Skills CLI. Each selected
skill is added separately; if one fails, the remaining selected skills are still
attempted and the failed names are reported. Check `skills-lock.json` and the
installed skills after a partial failure. Your lock and custom skills remain
your responsibility; this command does not remove or overwrite them directly.
