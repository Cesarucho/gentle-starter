#!/usr/bin/env bash

readonly CLEAN_MIGRATED_DOCS=(
	"extending.md"
	"install-tree.md"
	"install-volumes.md"
	"configs.md"
)

clean_identity_items() {
	CLEAN_IDENTITY_ITEMS=(
		"README.md"
		"AGENTS.md"
		"docs/"
		"CHANGELOG.md"
	)

	if [ -d ".github" ]; then
		CLEAN_IDENTITY_ITEMS+=(".github/")
	fi
}

clean_print_identity_plan() {
	clean_identity_items

	echo "The following items will be deleted:"
	echo
	printf '  - %s\n' "${CLEAN_IDENTITY_ITEMS[@]}"
	echo
	echo "The following are kept as base structure:"
	echo
	cat <<'EOF'
  - LICENSE (inherited Gentle Starter MIT attribution)
  - AGENTS.md.TEMPLATE
  - .devcontainer/README.md
  - .devcontainer/docs/
  - openspec/ (if present)
  - .agents/
  - skills-lock.json
  - .env.example
  - .gitignore
  - .taskfiles/
  - .devcontainer/
EOF
	echo
}

clean_reject_symlink_or_unexpected_type() {
	local path="$1"
	local expected_type="$2"

	[ -e "${path}" ] || [ -L "${path}" ] || return 0
	if [ -L "${path}" ]; then
		echo "[error] identity cleanup refuses symlink path: ${path}" >&2
		return 1
	fi
	case "${expected_type}" in
	directory)
		[ -d "${path}" ] || {
			echo "[error] identity cleanup expected a directory: ${path}" >&2
			return 1
		}
		;;
	file)
		[ -f "${path}" ] || {
			echo "[error] identity cleanup expected a regular file: ${path}" >&2
			return 1
		}
		;;
	esac
}

clean_validate_identity_cleanup() {
	local doc

	clean_reject_symlink_or_unexpected_type ".devcontainer" directory
	clean_reject_symlink_or_unexpected_type ".devcontainer/README.md" file
	clean_reject_symlink_or_unexpected_type ".devcontainer/docs" directory
	clean_reject_symlink_or_unexpected_type "docs" directory
	clean_reject_symlink_or_unexpected_type "docs/en" directory
	clean_reject_symlink_or_unexpected_type "AGENTS.md.TEMPLATE" file

	for doc in "${CLEAN_MIGRATED_DOCS[@]}"; do
		clean_reject_symlink_or_unexpected_type "docs/en/${doc}" file
		clean_reject_symlink_or_unexpected_type ".devcontainer/docs/${doc}" file
	done
	clean_reject_symlink_or_unexpected_type ".devcontainer/docs/README.md" file
}

clean_migrate_devcontainer_docs() {
	local source_dir="docs/en"
	local target_dir=".devcontainer/docs"
	local migrated=false
	local doc

	clean_validate_identity_cleanup

	if [ ! -f ".devcontainer/README.md" ]; then
		return 0
	fi

	if [ ! -d "${source_dir}" ]; then
		echo "[warn] ${source_dir}/ not found; skipping .devcontainer docs migration"
		return 0
	fi

	mkdir -p "${target_dir}"

	for doc in "${CLEAN_MIGRATED_DOCS[@]}"; do
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

These files are copied from `docs/en/` during starter identity cleanup.
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

clean_remove_starter_identity() {
	local item
	clean_identity_items
	clean_validate_identity_cleanup
	clean_migrate_devcontainer_docs

	for item in "${CLEAN_IDENTITY_ITEMS[@]}"; do
		if [ -e "${item}" ]; then
			rm -rf -- "${item}"
			echo "Deleted: ${item}"
		else
			echo "Not found (skipped): ${item}"
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
}

clean_print_next_steps() {
	cat <<'EOF'

Identity removed. Next steps:
  1. Review and update AGENTS.md from the copied template
  2. Delete optional AGENTS.md sections that do not apply
  3. Review .devcontainer/README.md and .devcontainer/docs/
  4. Review and update .env.example (APP_NAME, APP_PORT, APP_IMAGE)
  5. Review or create OpenSpec config if your project uses OpenSpec
  6. Rename the repo to your project name
  7. task validate   # verify the base structure works
  8. Optionally delete AGENTS.md.TEMPLATE once AGENTS.md is final
EOF
}
