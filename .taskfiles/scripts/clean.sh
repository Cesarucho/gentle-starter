#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Clean tasks help

Usage:
  task clean              Review, confirm, and execute identity cleanup
  task clean:identity     Explicit alias for the same cleanup

Preferred command:
  task clean

About clean:identity:
  Removes files that reference "Gentle Starter" so the repo can be
  renamed and used as a new project base or as a migration target.

  DELETED (identity):
    - README.md
    - AGENTS.md
    - docs/
    - LICENSE
    - CHANGELOG.md
    - .github/               (if present)

  KEPT (structure):
    - AGENTS.md.TEMPLATE     reusable AI-facing template
    - .devcontainer/README.md
    - .devcontainer/docs/    local deep-dive docs copied from docs/en/ during clean
    - openspec/              project source of truth (if present)
    - .agents/               versioned project skills
    - skills-lock.json       skill lock file
    - .env.example           environment template
    - .gitignore             git ignores
    - .taskfiles/            build and dev tasks
    - .devcontainer/         dev environment

  After running:
    - if AGENTS.md.TEMPLATE exists, it is copied to AGENTS.md
    - .devcontainer/README.md is rewritten to use .devcontainer/docs/
    - selected docs/en/*.md guides are copied to .devcontainer/docs/
    - adapt AGENTS.md placeholders and delete optional sections
    - review .env.example  (APP_NAME, APP_PORT, APP_IMAGE)
    - review or create OpenSpec config if your project uses OpenSpec
    - optionally delete AGENTS.md.TEMPLATE once AGENTS.md is final
EOF
}

migrate_devcontainer_docs() {
	local source_dir="docs/en"
	local target_dir=".devcontainer/docs"
	local migrated=false

	if [ ! -f ".devcontainer/README.md" ]; then
		return 0
	fi

	if [ ! -d "${source_dir}" ]; then
		echo "[warn] ${source_dir}/ not found; skipping .devcontainer docs migration"
		return 0
	fi

	mkdir -p "${target_dir}"

	for doc in extending.md install-tree.md install-volumes.md configs.md; do
		if [ -f "${source_dir}/${doc}" ]; then
			cp "${source_dir}/${doc}" "${target_dir}/${doc}"
			migrated=true
		else
			echo "[warn] missing source doc: ${source_dir}/${doc}"
		fi
	done

	cat >"${target_dir}/README.md" <<'EOF'
# `.devcontainer/docs/`

Local deep-dive guides kept after `task clean` so `.devcontainer/README.md`
remains self-contained in derived projects.

## What's here

| File | What it's for |
|---|---|
| [`extending.md`](./extending.md) | **Start here.** Comprehensive guide for extending the devcontainer. |
| [`install-tree.md`](./install-tree.md) | Deep dive on the `install/` convention. |
| [`install-volumes.md`](./install-volumes.md) | Deep dive on the volume repair contract. |
| [`configs.md`](./configs.md) | Deep dive on `seed_config_tree` and baseline config seeding. |

These files are copied from `docs/en/` during `task clean`.
EOF

	sed -i \
		-e 's|\.\./docs/en/extending\.md|./docs/extending.md|g' \
		-e 's|\.\./docs/en/install-tree\.md|./docs/install-tree.md|g' \
		-e 's|\.\./docs/en/install-volumes\.md|./docs/install-volumes.md|g' \
		-e 's|\.\./docs/en/configs\.md|./docs/configs.md|g' \
		-e 's|docs/en/extending\.md|docs/extending.md|g' \
		-e 's|docs/en/install-tree\.md|docs/install-tree.md|g' \
		-e 's|docs/en/install-volumes\.md|docs/install-volumes.md|g' \
		-e 's|docs/en/configs\.md|docs/configs.md|g' \
		".devcontainer/README.md"

	if [ -f "${target_dir}/extending.md" ]; then
		sed -i 's|../../\.devcontainer/README\.md|../README.md|g' \
			"${target_dir}/extending.md"
	fi

	if [ "${migrated}" = true ]; then
		echo "Migrated: docs/en -> ${target_dir}/"
		echo "Updated: .devcontainer/README.md -> local docs references"
	fi
}

run_identity_cleanup() {
	local items=(
		"README.md"
		"AGENTS.md"
		"docs/"
		"LICENSE"
		"CHANGELOG.md"
	)

	if [ -d ".github" ]; then
		items+=(".github/")
	fi

	echo "The following items will be deleted:"
	echo
	for item in "${items[@]}"; do
		echo "  - $item"
	done
	echo
	echo "The following are kept as base structure:"
	echo
	echo "  - AGENTS.md.TEMPLATE"
	echo "  - .devcontainer/README.md"
	echo "  - .devcontainer/docs/"
	echo "  - openspec/ (if present)"
	echo "  - .agents/"
	echo "  - skills-lock.json"
	echo "  - .env.example"
	echo "  - .gitignore"
	echo "  - .taskfiles/"
	echo "  - .devcontainer/"
	echo
	read -rp "Proceed? (y/N) " confirm
	if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
		echo "Aborted."
		exit 0
	fi

	migrate_devcontainer_docs

	for item in "${items[@]}"; do
		if [ -e "$item" ]; then
			rm -rf "$item"
			echo "Deleted: $item"
		else
			echo "Not found (skipped): $item"
		fi
	done

	if [ -f "AGENTS.md.TEMPLATE" ] && [ ! -e "AGENTS.md" ]; then
		cp "AGENTS.md.TEMPLATE" "AGENTS.md"
		echo "Copied: AGENTS.md.TEMPLATE -> AGENTS.md"

		if grep -Eq '<[A-Z0-9_]+>' "AGENTS.md" || grep -Fq 'Template note:' "AGENTS.md"; then
			echo
			echo "[warn] AGENTS.md still contains template placeholders or notes."
			echo "[warn] Update AGENTS.md before committing the new project identity."
		fi
	fi

	echo
	echo "Identity removed. Next steps:"
	echo "  1. Review and update AGENTS.md from the copied template"
	echo "  2. Delete optional AGENTS.md sections that do not apply"
	echo "  3. Review .devcontainer/README.md and .devcontainer/docs/"
	echo "  4. Review and update .env.example (APP_NAME, APP_PORT, APP_IMAGE)"
	echo "  5. Review or create OpenSpec config if your project uses OpenSpec"
	echo "  6. Rename the repo to your project name"
	echo "  7. task validate   # verify the base structure works"
	echo "  8. Optionally delete AGENTS.md.TEMPLATE once AGENTS.md is final"
}

main() {
	case "${1:-help}" in
	help)
		usage
		;;
	identity)
		run_identity_cleanup
		;;
	*)
		echo "Unknown command: ${1}" >&2
		usage >&2
		exit 1
		;;
	esac
}

main "$@"
