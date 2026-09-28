# Integrate starter into an unrelated Git project

Use a reviewed merge to connect histories once. Copying starter files alone does
not create ancestry for future updates. Run the preflight from a **separate**
checkout of the published `starter` branch, on the host, before importing files.
This requires host Git, Task, and Python 3; no container or project Taskfile is
needed. The preflight is read-only and does not fetch, merge, or commit.

## Check before merging

Keep a backup or checkpoint of your existing project. It can stay where it is;
you do not need to clone it. Start with a committed, clean worktree and index,
no Git operation in progress, and the absolute path to its Git root. On the
host, clone the published starter branch into a **separate** directory so its
Taskfile provides `project:check-existing`, then run the preflight from there:

```bash
git clone --branch starter https://github.com/Cesarucho/gentle-starter.git gentle-starter-preflight
cd gentle-starter-preflight
PROJECT=/absolute/path/to/existing-project task project:check-existing
```

Choose an unused directory name for the starter checkout if
`gentle-starter-preflight` already exists. Cloning obtains the checker; the
preflight itself only inspects the existing project and does not change it.

Exit 0 (`COMPATIBLE`) means no reserved paths were detected, NOT that Git will
merge without conflicts. Exit 1 (`MANUAL INTEGRATION`) reports reserved paths;
do not use the direct route. Exit 2 (`ERROR`) means state could not be verified
or the project is dirty; resolve that condition and recheck before merging.

## Review the first merge

On the **existing project's host checkout**, after compatible preflight and
reviewing the starter tree, create a dedicated branch and bring in the published
starter branch. Replace the URL if your trusted starter source differs:

```bash
cd /absolute/path/to/existing-project
git switch -c integrate-starter
git remote add upstream https://github.com/Cesarucho/gentle-starter.git
git fetch upstream starter
git merge --allow-unrelated-histories --no-commit --no-ff upstream/starter
```

If `upstream` already exists, verify its URL instead of replacing it. The first
merge needs `--allow-unrelated-histories`; `--no-commit --no-ff` stops for review
and keeps a merge commit even when Git could otherwise fast-forward. Fetch is
an **optional action you run**, not part of preflight. Do not use a squash merge.
Do not run the merge if the index or worktree is dirty. Git may stop with
conflicts; resolve them individually and stage the intended result.

Protect the project's `README.md`, `LICENSE`, `AGENTS.md`, `skills-lock.json`,
`.env.example`, and its own skills. Combine `.gitignore` rules instead of
replacing them. Review any other overlapping paths, including new starter
dependencies. Do not choose ours/theirs across the entire tree. Inspect
`git status`, `git diff --cached`, and `git diff --cached --check` before committing.
Check that local secrets and state (such as `.env` and `.env.d/`) are not staged.
Only you decide when to run `git commit` to complete the two-parent merge;
confirm afterwards with `git show --no-patch --format=%P HEAD` (two hashes).
If you cannot safely resolve the merge, run `git merge --abort` from the
previously clean branch and reassess. Do not commit a partial import.

## When reserved paths already exist

If the checker reports `.agents/skills/add-tool/`, `.devcontainer/`,
`.taskfiles/`, `.markdownlint-cli2.yaml`, or `Taskfile.yml` (including a
symlink or untracked path), do not follow the direct merge recipe blindly.
Inventory every path and compare it with the published starter tree. Plan a
manual, file-by-file integration of the starter-owned surfaces and their
dependencies without replacing project-owned files or skills. Untracked and
ignored files need explicit protection before any merge. Once the worktree and
index are clean, you can still make a real unrelated-history merge with the
flags above, resolve each reserved-path conflict deliberately, and review the
staged tree before your own commit. If you cannot protect existing paths,
abort rather than forcing an overwrite. Preflight cannot certify this path.

After the reviewed merge, later updates use ordinary `git fetch upstream` and
`git merge upstream/starter` on your project branch, with conflicts resolved
manually. Inspect the imported Task commands before running them.
