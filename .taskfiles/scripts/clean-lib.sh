#!/usr/bin/env bash

clean_identity_items() {
	CLEAN_IDENTITY_ITEMS=(
		"README.md"
		"AGENTS.md"
		"AGENTS.md.TEMPLATE.EXAMPLE"
		"docs/"
		"CHANGELOG.md"
		"odd/"
		"openspec/"
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
	echo "All root openspec/ content will be deleted, including user-authored, committed, and ignored content."
	echo
	echo "The following are kept as base structure:"
	echo
	cat <<'EOF'
  - LICENSE (inherited Gentle Starter MIT attribution)
  - AGENTS.md.TEMPLATE
  - .devcontainer/README.md
  - .devcontainer/docs/
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
	clean_reject_symlink_or_unexpected_type ".devcontainer" directory
	clean_reject_symlink_or_unexpected_type ".devcontainer/README.md" file
	clean_reject_symlink_or_unexpected_type ".devcontainer/docs" directory
	clean_reject_symlink_or_unexpected_type "docs" directory
	clean_reject_symlink_or_unexpected_type "docs/en" directory
	clean_reject_symlink_or_unexpected_type "AGENTS.md.TEMPLATE" file
	clean_reject_symlink_or_unexpected_type "odd" directory
	# Initialization also calls this function in a conditional, where errexit is disabled.
	clean_reject_symlink_or_unexpected_type "openspec" directory || return 1

	clean_reject_symlink_or_unexpected_type ".devcontainer/docs/README.md" file
}

clean_remove_starter_identity() {
	local item
	clean_identity_items
	clean_validate_identity_cleanup

	for item in "${CLEAN_IDENTITY_ITEMS[@]}"; do
		if [ -e "${item}" ]; then
			rm -rf -- "${item}"
			echo "Deleted: ${item}"
		else
			echo "Not found (skipped): ${item}"
		fi
	done
}

clean_print_next_steps() {
	cat <<'EOF'

Identity removed. Next steps:
  1. Adapt, rename, or copy AGENTS.md.TEMPLATE if you want an AGENTS.md
  2. Delete template sections that do not apply
  3. Review .devcontainer/README.md and .devcontainer/docs/
  4. Review and update .env.example (APP_NAME, APP_PORT, APP_IMAGE)
  5. Review or create OpenSpec config if your project uses OpenSpec
  6. Rename the repo to your project name
  7. task validate   # verify the base structure works
  8. Keep or delete AGENTS.md.TEMPLATE according to your project policy
EOF
}
