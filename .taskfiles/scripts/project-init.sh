#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/clean-lib.sh"

readonly INITIALIZATION_COMMIT_MESSAGE="chore: initialize project"
readonly CONFIRMATION_PHRASE="INIT"
readonly STARTER_URL="https://github.com/Cesarucho/gentle-starter.git"
readonly STARTER_KEY="github.com/cesarucho/gentle-starter"
readonly SIGNAL_EXIT_HUP=129 SIGNAL_EXIT_INT=130 SIGNAL_EXIT_TERM=143

fail() {
	echo "[error] $*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage: project-init.sh [--dry-run] [--branch <name>] [--origin-url <url>]

Initializes a project as a normal child of the starter history. The normal task
prompts for the project branch and optional origin URL. --dry-run prints every
planned action without changing files, refs, configuration, index, or worktree.
EOF
}

parse_args() {
	DRY_RUN=false BRANCH_ARGUMENT='' ORIGIN_ARGUMENT='' BRANCH_SUPPLIED=false ORIGIN_SUPPLIED=false
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--dry-run)
			DRY_RUN=true
			shift
			;;
		--branch)
			[ "$#" -ge 2 ] || fail "--branch requires a value"
			BRANCH_ARGUMENT="$2"
			BRANCH_SUPPLIED=true
			shift 2
			;;
		--origin-url)
			[ "$#" -ge 2 ] || fail "--origin-url requires a value"
			ORIGIN_ARGUMENT="$2"
			ORIGIN_SUPPLIED=true
			shift 2
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			usage >&2
			fail "unknown argument: $1"
			;;
		esac
	done
}

enter_clean_repository_root() {
	git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "project:init must run inside a Git worktree"
	cd "$(git rev-parse --show-toplevel)" || fail "could not resolve the Git worktree root"
	CURRENT_BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
	[ -n "${CURRENT_BRANCH}" ] || fail "project:init requires a checked-out branch"
	[ -z "$(GIT_OPTIONAL_LOCKS=0 git status --porcelain=v1 --untracked-files=all)" ] || fail "working tree must be clean, including staged and untracked files"
	if ! git var GIT_AUTHOR_IDENT >/dev/null 2>&1 || ! git var GIT_COMMITTER_IDENT >/dev/null 2>&1; then
		fail "Git author and committer identity must be configured"
	fi
	git log --format=%s HEAD | grep -Fxq "${INITIALIZATION_COMMIT_MESSAGE}" && fail "project:init has already been committed in this branch's history"
	clean_validate_identity_cleanup || fail "identity cleanup contains unsafe paths"
}

collect_inputs() {
	if [ "${BRANCH_SUPPLIED}" = true ]; then
		PROJECT_BRANCH="${BRANCH_ARGUMENT}"
	else
		read -rp "Project branch [main]: " PROJECT_BRANCH || fail "project branch input is required"
		PROJECT_BRANCH="${PROJECT_BRANCH:-main}"
	fi
	git check-ref-format --branch "${PROJECT_BRANCH}" >/dev/null 2>&1 || fail "invalid project branch: ${PROJECT_BRANCH}"

	if [ "${ORIGIN_SUPPLIED}" = true ]; then
		PROJECT_URL="${ORIGIN_ARGUMENT}"
	else
		read -rp "Project repository URL for origin (optional): " PROJECT_URL || fail "project repository URL input is required"
	fi
	[ -z "${PROJECT_URL}" ] || validate_repository_url "${PROJECT_URL}"
}

validate_repository_url() {
	case "$1" in
	https://*/* | ssh://*/* | git@*:*/*) ;;
	*) fail "invalid project repository URL: $1" ;;
	esac
}

repository_key() {
	local url="$1" key
	key="${url%/}"
	key="${key%.git}"
	case "${key}" in
	https://* | http://* | ssh://*)
		key="${key#*://}"
		key="${key#*@}"
		key="${key/:/\/}"
		;;
	*@*:*)
		key="${key#*@}"
		key="${key/:/\/}"
		;;
	esac
	printf '%s\n' "${key,,}"
}

is_starter_url() { [ "$(repository_key "$1")" = "${STARTER_KEY}" ]; }
urls_equivalent() { [ "$(repository_key "$1")" = "$(repository_key "$2")" ]; }
remote_url() { git remote get-url "$1" 2>/dev/null; }
remote_exists() { git config --get-regexp "^remote\.$1\.url$" >/dev/null 2>&1; }

plan_branch() {
	BRANCH_ACTION="keep ${CURRENT_BRANCH}"
	if [ "${PROJECT_BRANCH}" != "${CURRENT_BRANCH}" ]; then
		git show-ref --verify --quiet "refs/heads/${PROJECT_BRANCH}" && fail "branch '${PROJECT_BRANCH}' already exists; switch to it explicitly before running project:init"
		BRANCH_ACTION="create and switch to ${PROJECT_BRANCH}"
	fi
}

plan_remotes() {
	ORIGIN_EXISTS=false UPSTREAM_EXISTS=false ORIGIN_IS_STARTER=false UPSTREAM_IS_STARTER=false
	remote_exists origin && {
		ORIGIN_EXISTS=true
		ORIGIN_URL="$(remote_url origin)"
		is_starter_url "${ORIGIN_URL}" && ORIGIN_IS_STARTER=true
	}
	remote_exists upstream && {
		UPSTREAM_EXISTS=true
		UPSTREAM_URL="$(remote_url upstream)"
		is_starter_url "${UPSTREAM_URL}" && UPSTREAM_IS_STARTER=true
	}

	[ "${UPSTREAM_EXISTS}" = false ] || [ "${UPSTREAM_IS_STARTER}" = true ] || fail "remote 'upstream' exists but does not identify Gentle Starter"
	if [ "${ORIGIN_EXISTS}" = true ] && [ "${ORIGIN_IS_STARTER}" = false ] && [ -n "${PROJECT_URL}" ] && ! urls_equivalent "${ORIGIN_URL}" "${PROJECT_URL}"; then
		fail "remote 'origin' already exists with a different URL; refusing to overwrite it"
	fi

	REMOTE_PLAN=()
	if [ "${ORIGIN_IS_STARTER}" = true ]; then
		if [ "${UPSTREAM_IS_STARTER}" = true ]; then REMOTE_PLAN+=("remove duplicate starter origin"); else REMOTE_PLAN+=("rename starter origin to upstream"); fi
	fi
	if [ "${UPSTREAM_IS_STARTER}" = true ] || [ "${ORIGIN_IS_STARTER}" = true ]; then REMOTE_PLAN+=("normalize upstream to ${STARTER_URL}"); else REMOTE_PLAN+=("add upstream ${STARTER_URL}"); fi
	if [ -n "${PROJECT_URL}" ] && { [ "${ORIGIN_EXISTS}" = false ] || [ "${ORIGIN_IS_STARTER}" = true ]; }; then REMOTE_PLAN+=("add origin ${PROJECT_URL}"); fi
}

print_plan() {
	cat <<EOF
Project initialization plan:
  Branch: ${PROJECT_BRANCH} (${BRANCH_ACTION})
  Remotes:
EOF
	printf '    - %s\n' "${REMOTE_PLAN[@]}"
	clean_print_identity_plan
	cat <<EOF
Git plan:
  - create a normal child commit: ${INITIALIZATION_COMMIT_MESSAGE}
  - never fetch, push, rewrite history, or contact a remote
EOF
}

confirm_initialization() {
	local confirmation
	read -rp "Type ${CONFIRMATION_PHRASE} to continue: " confirmation || {
		echo "Aborted. No changes were made."
		exit 0
	}
	[ "${confirmation}" = "${CONFIRMATION_PHRASE}" ] || {
		echo "Aborted. No changes were made."
		exit 0
	}
}

begin_transaction() {
	local path config_path index_path
	TRANSACTION_DIR="$(mktemp -d "${TMPDIR:-/tmp}/project-init-rollback.XXXXXX")"
	ORIGINAL_HEAD="$(git rev-parse HEAD)"
	ORIGINAL_BRANCH="${CURRENT_BRANCH}"
	git for-each-ref --format='%(refname) %(symref)' | while read -r ref symref; do
		if [ -n "${symref}" ]; then
			printf '%s %s\n' "${ref}" "${symref}" >>"${TRANSACTION_DIR}/symbolic-refs"
		else
			printf '%s %s\n' "$(git rev-parse "${ref}")" "${ref}" >>"${TRANSACTION_DIR}/direct-refs"
		fi
	done
	config_path="$(git rev-parse --git-path config)"
	index_path="$(git rev-parse --git-path index)"
	CONFIG_PATH="$(realpath "${config_path}")"
	INDEX_PATH="$(realpath "${index_path}")"
	cp -p "${CONFIG_PATH}" "${TRANSACTION_DIR}/config"
	cp -p "${INDEX_PATH}" "${TRANSACTION_DIR}/index"
	ROLLBACK_PATHS=("README.md" "AGENTS.md" "AGENTS.md.TEMPLATE.EXAMPLE" "docs" "CHANGELOG.md" ".github" ".devcontainer/README.md" ".devcontainer/docs")
	ROLLBACK_EXISTING_PATHS=()
	for path in "${ROLLBACK_PATHS[@]}"; do [ ! -e "${path}" ] && [ ! -L "${path}" ] || ROLLBACK_EXISTING_PATHS+=("${path}"); done
	[ "${#ROLLBACK_EXISTING_PATHS[@]}" -eq 0 ] || tar -cpf "${TRANSACTION_DIR}/worktree.tar" -- "${ROLLBACK_EXISTING_PATHS[@]}"
	TRANSACTION_ACTIVE=true
	trap 'rollback_transaction "$?" "command failure"' ERR
	trap 'rollback_transaction "${SIGNAL_EXIT_HUP}" "hangup"' HUP
	trap 'rollback_transaction "${SIGNAL_EXIT_INT}" "interrupt"' INT
	trap 'rollback_transaction "${SIGNAL_EXIT_TERM}" "termination"' TERM
}

restore_refs() {
	local oid ref target
	git for-each-ref --format='%(refname) %(symref)' | while read -r ref target; do
		[ -z "${target}" ] || git symbolic-ref --delete "${ref}"
	done
	git for-each-ref --format='delete %(refname)' | git update-ref --stdin
	while read -r oid ref; do git update-ref "${ref}" "${oid}"; done <"${TRANSACTION_DIR}/direct-refs"
	if [ -f "${TRANSACTION_DIR}/symbolic-refs" ]; then
		while read -r ref target; do git symbolic-ref "${ref}" "${target}"; done <"${TRANSACTION_DIR}/symbolic-refs"
	fi
}

rollback_transaction() {
	local status="$1" reason="$2" path
	trap - ERR HUP INT TERM
	set +e
	if [ "${TRANSACTION_ACTIVE:-false}" = true ]; then
		echo "[error] project initialization failed (${reason}); restoring the original repository" >&2
		cp -p "${TRANSACTION_DIR}/config" "${CONFIG_PATH}"
		restore_refs
		git symbolic-ref HEAD "refs/heads/${ORIGINAL_BRANCH}"
		git reset --hard "${ORIGINAL_HEAD}" >/dev/null 2>&1
		for path in "${ROLLBACK_PATHS[@]}"; do rm -rf -- "${path}"; done
		[ ! -f "${TRANSACTION_DIR}/worktree.tar" ] || tar -xpf "${TRANSACTION_DIR}/worktree.tar" -C .
		cp -p "${TRANSACTION_DIR}/index" "${INDEX_PATH}"
		rm -rf -- "${TRANSACTION_DIR}"
	fi
	exit "${status}"
}

configure_remotes() {
	if [ "${ORIGIN_IS_STARTER}" = true ]; then
		if [ "${UPSTREAM_IS_STARTER}" = true ]; then git remote remove origin; else git remote rename origin upstream; fi
	fi
	if remote_exists upstream; then git remote set-url upstream "${STARTER_URL}"; else git remote add upstream "${STARTER_URL}"; fi
	if [ -n "${PROJECT_URL}" ] && ! remote_exists origin; then git remote add origin "${PROJECT_URL}"; fi
}

initialize_project() {
	[ "${PROJECT_BRANCH}" = "${CURRENT_BRANCH}" ] || git switch -c "${PROJECT_BRANCH}"
	configure_remotes
	clean_remove_starter_identity
	git add -A
	git commit -m "${INITIALIZATION_COMMIT_MESSAGE}"
	trap - ERR HUP INT TERM
	TRANSACTION_ACTIVE=false
	rm -rf -- "${TRANSACTION_DIR}"
}

print_ancestry_guidance() {
	if git show-ref --verify --quiet refs/remotes/upstream/main; then
		if git merge-base HEAD refs/remotes/upstream/main >/dev/null; then echo "  Ancestry: verified against local upstream/main."; else echo "  Ancestry: no merge-base with local upstream/main; resolve before merging updates."; fi
	else
		echo "  Ancestry: not verified; run 'git fetch upstream' to establish upstream/main locally."
	fi
}

print_result() {
	local name
	cat <<EOF

Project initialized.
  Branch: ${PROJECT_BRANCH}
  Commit: $(git rev-parse HEAD)
  Parent: ${ORIGINAL_HEAD}
  Remotes:
EOF
	while read -r name; do printf '    %s: %s\n' "${name}" "$(remote_url "${name}")"; done < <(git remote | sort)
	print_ancestry_guidance
	if remote_exists origin; then echo "  Push: git push -u origin ${PROJECT_BRANCH}"; else
		echo "  Next: git remote add origin <project-url>"
		echo "        git push -u origin ${PROJECT_BRANCH}"
	fi
	echo "  Then customize .env.example and adapt, rename, or copy AGENTS.md.TEMPLATE if needed."
	echo "  Future updates: git fetch upstream && git merge upstream/main"
}

main() {
	parse_args "$@"
	enter_clean_repository_root
	collect_inputs
	plan_branch
	plan_remotes
	print_plan
	[ "${DRY_RUN}" = false ] || {
		echo "Dry run complete. No changes were made."
		exit 0
	}
	confirm_initialization
	begin_transaction
	initialize_project
	print_result
}

main "$@"
