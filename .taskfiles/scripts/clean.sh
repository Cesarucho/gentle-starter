#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/clean-lib.sh"

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
    - CHANGELOG.md
    - .github/               (if present)

  KEPT (structure):
    - LICENSE                inherited Gentle Starter MIT attribution
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

run_identity_cleanup() {
	local confirm

	clean_validate_identity_cleanup
	clean_print_identity_plan
	read -rp "Proceed? (y/N) " confirm || confirm=""
	if [ "${confirm}" != "y" ] && [ "${confirm}" != "Y" ]; then
		echo "Aborted."
		return 0
	fi

	clean_remove_starter_identity
	clean_print_next_steps
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
