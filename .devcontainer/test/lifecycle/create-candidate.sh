#!/usr/bin/env bash
# Create an isolated Git-backed lifecycle candidate and overlay the current worktree.
set -euo pipefail

source_root="${1:?source repository is required}"
candidate="${2:?candidate path is required}"

[ ! -e "${candidate}" ] || {
	printf 'candidate already exists: %s\n' "${candidate}" >&2
	exit 1
}

git clone --quiet --no-checkout --no-local --no-hardlinks "${source_root}" "${candidate}"
git -C "${candidate}" read-tree HEAD

# The candidate must not retain a path or network endpoint that later Git commands
# could contact. Its object database and index remain fully independent.
while IFS= read -r remote; do
	git -C "${candidate}" remote remove "${remote}"
done < <(git -C "${candidate}" remote)

# Overlay the exact dirty worktree, including untracked files and modes. Keep clone
# metadata while excluding local credentials, caches, and runtime state.
rsync -a --delete \
	--include='/.env.example' \
	--exclude='/.git' --exclude='/.env*' --exclude='/.env.d/' \
	--exclude='/.devcontainer/.env*' --exclude='/.devcontainer/.volume-manifest.json' \
	--exclude='/.atl/' --exclude='/.pi/' --exclude='/.base-backup/' \
	--exclude='/*-config.local/' --exclude='/.vscode/' \
	--exclude='node_modules/' --exclude='.cache/' --exclude='__pycache__/' \
	--exclude='coverage/' --exclude='dist/' --exclude='*.py[cod]' \
	--exclude='.ssh/' --exclude='.aws/' --exclude='.gnupg/' --exclude='.docker/' \
	--exclude='.npmrc' --exclude='.netrc' \
	--exclude='*.key' --exclude='*.pem' --exclude='id_rsa*' --exclude='id_ed25519*' \
	"${source_root}/" "${candidate}/"
