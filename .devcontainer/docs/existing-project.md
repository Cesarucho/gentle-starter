# 🧭 Bring starter into an existing Git project

If your project has unrelated Git history, use a **reviewed, two-parent merge**
to connect it to the published `starter` branch. Copying files alone does not
establish ancestry for future updates. Run the read-only preflight first from a
**separate checkout** of `starter` on the host; do not import files beforehand.

> **Already using an older starter release?** If your clone follows an older
> starter history that was overwritten, do not treat this as an ordinary
> `git merge upstream/starter` update. Inspect its ancestry and plan a deliberate
> migration before merging. The procedure below is for an existing project with
> unrelated history, not a shortcut for replacing an earlier starter lineage.

## 🔎 Check the existing project

Keep a backup or checkpoint. Your project can stay in place; it does not need
to be cloned. Start with a committed, clean worktree and index, no Git operation
in progress, and the absolute path to its Git root. On the host, you need Git,
Task, and Python 3; no container or project Taskfile is required.

Clone the published branch into a **separate**, unused directory to get its
checker, then run preflight from that checkout:

```bash
git clone --branch starter https://github.com/Cesarucho/gentle-starter.git gentle-starter-preflight
cd gentle-starter-preflight
PROJECT=/absolute/path/to/existing-project task project:check-existing
```

Choose another directory name if `gentle-starter-preflight` already exists.
Cloning obtains the checker; preflight only inspects the project. It does not
fetch, merge, or commit.

| Exit | Meaning | Next step |
| --- | --- | --- |
| 0 (`COMPATIBLE`) | No reserved paths detected; a conflict-free merge is **not** guaranteed. | Review the starter tree before the direct merge. |
| 1 (`MANUAL INTEGRATION`) | Reserved paths exist. | Use the manual path below; do not use the direct route. |
| 2 (`ERROR`) | State could not be verified or the project is dirty. | Resolve the condition and rerun preflight before merging. |

## 🌿 Make the first merge reviewable

In the **existing project's host checkout**, after exit 0 and a review of the
starter tree, create a dedicated branch. Use a different URL only if you have
verified a different trusted starter source:

```bash
cd /absolute/path/to/existing-project
git switch -c integrate-starter
git remote add upstream https://github.com/Cesarucho/gentle-starter.git
git fetch upstream starter
git merge --allow-unrelated-histories --no-commit --no-ff upstream/starter
```

If `upstream` already exists, verify its URL instead of replacing it. Fetch is
an **optional action you run**, not part of preflight. The first merge requires
`--allow-unrelated-histories`; `--no-commit --no-ff` leaves the result for review
and retains a merge commit even if Git could fast-forward. Do not squash merge.
Do not start the merge with a dirty index or worktree. If Git reports conflicts,
resolve each one individually and stage only the intended result.

### 💾 Preserve the current sessions of OpenCode & Engram

A simple way to maintain the OpenCode and Engram session history is to copy
all state files, including SQLite databases. While not ideal, stopping
OpenCode/Engram services in both directions while copying and pasting should
work correctly.

| type   | typical location                          | starter-repo location   |
|--------|-------------------------------------------|-------------------------|
| state  | ~/.local/share/opencode/*                 | .env.d/.opencode/share/ |
| state  | ~/.engram/*                               | .env.d/.engram/         |
| id     | <repo>/.git/opencode                      | .git/                   |
| id     | <repo>/.git/engram-project-identity.json  | .git/                   |

> ⚠️: Keep in mind that **you are copying highly sensitive information**, especially
> `auth.json` from opencode. So do it manually, don't use AI.

### 🛡️ Review before you commit

- Protect the project's `README.md`, `LICENSE`, `AGENTS.md`,
  `skills-lock.json`, `.env.example`, and its own skills. Combine `.gitignore`
  rules rather than replacing them. Review other overlaps and new starter
  dependencies; never choose ours/theirs across the whole tree.
- Inspect `git status`, `git diff --cached`, and `git diff --cached --check`.
  Ensure local secrets and state, such as `.env` and `.env.d/`, are not staged.
- Only you decide when to run `git commit`. Afterwards, confirm the merge has
  two parents with `git show --no-patch --format=%P HEAD` (two hashes).

If you cannot resolve the merge safely, run `git merge --abort` from the
previously clean branch and reassess. Never commit a partial import.

## 🧩 If reserved paths already exist

If preflight reports `.agents/skills/add-tool/`, `.devcontainer/`,
`.taskfiles/`, `.markdownlint-cli2.yaml`, or `Taskfile.yml` (including a
symlink or untracked path), **do not follow the direct recipe blindly**.
Inventory every path and compare it with the published starter tree. Plan a
manual, file-by-file integration of starter-owned surfaces and dependencies
without replacing project-owned files or skills. Explicitly protect untracked
and ignored files before any merge.

Once the worktree and index are clean, you can still make a real
unrelated-history merge using the flags above. Resolve each reserved-path
conflict deliberately and review the staged tree before your own commit. If
you cannot protect existing paths, abort rather than forcing an overwrite.
Preflight cannot certify this route.

## 🔄 Update after the reviewed merge

Later releases from the **same published starter lineage** use ordinary
`git fetch upstream` and `git merge upstream/starter` on your project branch;
resolve conflicts manually. Published `starter` commits form their own linear
history and do not descend from the producer `dev` branch. A clone of an older
overwritten starter history needs deliberate migration, not this ordinary
update. Inspect imported Task commands before running them.
