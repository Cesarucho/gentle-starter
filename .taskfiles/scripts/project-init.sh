#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/clean-lib.sh"

readonly ROOT_COMMIT_MESSAGE="chore: initialize project"
readonly CONFIRMATION_PHRASE="CREATE ROOT"
readonly SIGNAL_EXIT_HUP=129
readonly SIGNAL_EXIT_INT=130
readonly SIGNAL_EXIT_TERM=143

fail() {
	echo "[error] $*" >&2
	exit 1
}

abort_without_changes() {
	echo "Aborted. No changes were made."
	exit 0
}

enter_clean_repository_root() {
	local repository_root

	git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
		fail "project:init must run inside a Git worktree"
	repository_root="$(git rev-parse --show-toplevel)" ||
		fail "could not resolve the Git worktree root"
	cd "${repository_root}"

	if [ -n "$(GIT_OPTIONAL_LOCKS=0 git status --porcelain=v1 --untracked-files=all)" ]; then
		fail "working tree must be clean, including staged and untracked files"
	fi

	if ! git var GIT_AUTHOR_IDENT >/dev/null 2>&1 ||
		! git var GIT_COMMITTER_IDENT >/dev/null 2>&1; then
		fail "Git author and committer identity must be configured"
	fi

	local worktree_count
	worktree_count="$(git worktree list --porcelain | grep -c '^worktree ' || true)"
	[ "${worktree_count}" -eq 1 ] ||
		fail "project:init refuses repositories with linked worktrees"

	clean_validate_identity_cleanup || fail "identity cleanup contains unsafe paths"
	clean_validate_project_init_markers || fail "starter marker cleanup contains unsafe paths"
}

prompt_for_inputs() {
	local entered_branch

	if ! read -rp "New root branch [main]: " entered_branch; then
		abort_without_changes
	fi
	TARGET_BRANCH="${entered_branch:-main}"
	validate_branch "${TARGET_BRANCH}"

	if ! read -rp "New origin URL (blank preserves current origin): " NEW_ORIGIN; then
		abort_without_changes
	fi
	validate_origin "${NEW_ORIGIN}"
	validate_no_inherited_origin_pushurl
}

validate_branch() {
	local branch="$1"
	local checked_branch

	[ -n "${branch}" ] || fail "branch name cannot be empty"
	[[ "${branch}" != -* ]] || fail "branch name cannot begin with an option prefix"
	[ "${branch}" != "@" ] || fail "branch name '@' is not allowed"
	checked_branch="$(git check-ref-format --branch "${branch}" 2>/dev/null)" ||
		fail "invalid branch name"
	[ "${checked_branch}" = "${branch}" ] || fail "invalid branch name"
	if git show-ref --verify --quiet "refs/heads/${branch}"; then
		fail "target branch already exists"
	fi
}

validate_origin() {
	local origin="$1"
	local normalized

	[ -z "${origin}" ] && return 0
	[[ "${origin}" != -* ]] || fail "origin URL is unsafe"
	if [[ "${origin}" =~ [[:space:][:cntrl:]] ]]; then
		fail "origin URL is unsafe"
	fi

	normalized="${origin,,}"
	case "${normalized}" in
	*\?* | *\#* | *token* | *password* | *secret* | *credential*)
		fail "origin URL must not contain embedded credentials"
		;;
	esac

	if [[ "${origin}" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?/[A-Za-z0-9._~/-]+$ ]]; then
		return 0
	fi
	if [[ "${origin}" =~ ^ssh://(git@)?[A-Za-z0-9.-]+(:[0-9]+)?/[A-Za-z0-9._~/-]+$ ]]; then
		return 0
	fi
	if [[ "${origin}" =~ ^git@[A-Za-z0-9.-]+:[A-Za-z0-9._~/-]+$ ]]; then
		return 0
	fi
	fail "origin URL must use HTTPS, SSH, or git@host:path syntax"
}

validate_no_inherited_origin_pushurl() {
	local scope

	[ -n "${NEW_ORIGIN}" ] || return 0
	while IFS=$'\t' read -r scope _; do
		[ -n "${scope}" ] || continue
		[ "${scope}" = local ] ||
			fail "supplied origin cannot override an inherited origin push URL"
	done < <(git config --show-scope --show-origin --get-all remote.origin.pushurl 2>/dev/null || true)
}

origin_exists() {
	git remote get-url origin >/dev/null 2>&1
}

print_project_plan() {
	clean_print_identity_plan
	echo "Git history plan:"
	echo "  - create parentless branch: ${TARGET_BRANCH}"
	echo "  - create root commit: ${ROOT_COMMIT_MESSAGE}"
	echo "  - remove previous local branches, tags, and other refs"
	if [ -n "${NEW_ORIGIN}" ]; then
		if origin_exists; then
			echo "  - replace origin with the supplied credential-free URL"
		else
			echo "  - add origin with the supplied credential-free URL"
		fi
	else
		echo "  - preserve the current origin configuration"
	fi
	echo "  - no push, fetch, ls-remote, or remote contact"
	echo "Starter update plan:"
	echo "  - retain updater commands, trust policy, and distribution metadata"
	echo "  - remove inherited state, baseline, evidence, and journals"
	echo "  - leave the project unmarked until an exact baseline is admitted"
	echo
}

confirm_project_initialization() {
	local confirmation

	if ! read -rp "Type ${CONFIRMATION_PHRASE} to continue: " confirmation; then
		abort_without_changes
	fi
	[ "${confirmation}" = "${CONFIRMATION_PHRASE}" ] || abort_without_changes
}

clear_config_key_if_present() {
	local key="$1"

	if git config --file "${TEMP_CONFIG_PATH}" --get-all "${key}" >/dev/null 2>&1; then
		git config --file "${TEMP_CONFIG_PATH}" --unset-all "${key}"
	fi
}

clear_target_upstream_config() {
	clear_config_key_if_present "branch.${TARGET_BRANCH}.remote"
	clear_config_key_if_present "branch.${TARGET_BRANCH}.merge"
}

begin_project_transaction() {
	TRANSACTION_DIR="$(mktemp -d "${TMPDIR:-/tmp}/project-init-rollback.XXXXXX")"
	GIT_HEAD_PATH="$(git rev-parse --git-path HEAD)"
	GIT_INDEX_PATH="$(git rev-parse --git-path index)"
	GIT_CONFIG_PATH="$(git rev-parse --git-path config)"
	TEMP_INDEX_PATH="${TRANSACTION_DIR}/index.next"
	TEMP_CONFIG_PATH="${TRANSACTION_DIR}/config.next"

	cp -p -- "${GIT_HEAD_PATH}" "${TRANSACTION_DIR}/HEAD"
	cp -p -- "${GIT_INDEX_PATH}" "${TRANSACTION_DIR}/index.original"
	cp -p -- "${GIT_INDEX_PATH}" "${TEMP_INDEX_PATH}"
	cp -p -- "${GIT_CONFIG_PATH}" "${TRANSACTION_DIR}/config.original"
	cp -p -- "${GIT_CONFIG_PATH}" "${TEMP_CONFIG_PATH}"
	ORIGINAL_CONFIG_HASH="$(sha256sum "${GIT_CONFIG_PATH}" | cut -d' ' -f1)"
	ORIGINAL_INDEX_HASH="$(sha256sum "${GIT_INDEX_PATH}" | cut -d' ' -f1)"
	CONFIG_REPLACED=false
	INDEX_REPLACED=false
	git for-each-ref --format='%(objectname) %(refname)' >"${TRANSACTION_DIR}/refs"

	clean_identity_items
	ROLLBACK_MUTATED_PATHS=(
		"${CLEAN_IDENTITY_ITEMS[@]}"
		"${CLEAN_PROJECT_INIT_MARKERS[@]}"
		".devcontainer/README.md"
		".devcontainer/docs"
	)
	ROLLBACK_EXISTING_PATHS=()
	local path
	for path in "${ROLLBACK_MUTATED_PATHS[@]}"; do
		if [ -e "${path}" ] || [ -L "${path}" ]; then
			ROLLBACK_EXISTING_PATHS+=("${path}")
		fi
	done
	if [ "${#ROLLBACK_EXISTING_PATHS[@]}" -gt 0 ]; then
		tar -cpf "${TRANSACTION_DIR}/worktree.tar" -- "${ROLLBACK_EXISTING_PATHS[@]}"
	fi

	TRANSACTION_ACTIVE=true
	trap 'rollback_project_transaction "$?" "command failure"' ERR
	trap 'rollback_project_transaction "${SIGNAL_EXIT_HUP}" "hangup"' HUP
	trap 'rollback_project_transaction "${SIGNAL_EXIT_INT}" "interrupt"' INT
	trap 'rollback_project_transaction "${SIGNAL_EXIT_TERM}" "termination"' TERM
}

record_recovery_failure() {
	RECOVERY_FAILURES=$((RECOVERY_FAILURES + 1))
}

restore_owned_worktree_paths() {
	local path
	for path in "${ROLLBACK_MUTATED_PATHS[@]}"; do
		rm -rf -- "${path}" || record_recovery_failure
	done
	if [ -f "${TRANSACTION_DIR}/worktree.tar" ]; then
		tar -xpf "${TRANSACTION_DIR}/worktree.tar" -C . || record_recovery_failure
	fi
}

restore_original_refs() {
	local object ref current

	git update-ref -d "refs/heads/${TARGET_BRANCH}" 2>/dev/null || true
	while read -r object ref; do
		[ -n "${ref}" ] || continue
		current="$(git show-ref --verify --hash "${ref}" 2>/dev/null || true)"
		if [ -z "${current}" ]; then
			git update-ref "${ref}" "${object}" || record_recovery_failure
		elif [ "${current}" != "${object}" ]; then
			echo "[warn] preserving concurrently changed ref during recovery: ${ref}" >&2
			record_recovery_failure
		fi
	done <"${TRANSACTION_DIR}/refs"
}

rollback_project_transaction() {
	local status="$1"
	local reason="$2"

	trap - ERR HUP INT TERM
	set +e
	if [ "${TRANSACTION_ACTIVE:-false}" = true ]; then
		echo "[error] project initialization failed (${reason}); attempting scoped recovery" >&2
		RECOVERY_FAILURES=0
		cp -p -- "${TRANSACTION_DIR}/HEAD" "${GIT_HEAD_PATH}" || record_recovery_failure
		restore_original_refs
		if [ "${CONFIG_REPLACED:-false}" = true ]; then
			cp -p -- "${TRANSACTION_DIR}/config.original" "${GIT_CONFIG_PATH}" || record_recovery_failure
		fi
		if [ "${INDEX_REPLACED:-false}" = true ]; then
			cp -p -- "${TRANSACTION_DIR}/index.original" "${GIT_INDEX_PATH}" || record_recovery_failure
		fi
		restore_owned_worktree_paths
		if [ "${RECOVERY_FAILURES}" -eq 0 ]; then
			rm -rf -- "${TRANSACTION_DIR}" || record_recovery_failure
		fi
		TRANSACTION_ACTIVE=false
		if [ "${RECOVERY_FAILURES}" -eq 0 ]; then
			echo "[error] operation-owned worktree paths, HEAD, refs, and Git config restored" >&2
		else
			echo "[error] recovery incomplete; rollback artifacts retained at: ${TRANSACTION_DIR}" >&2
			echo "[error] inspect the retained HEAD, refs, config, index, and worktree archive before retrying" >&2
		fi
	fi
	exit "${status}"
}

commit_project_transaction() {
	local current_config_hash
	local current_index_hash

	current_config_hash="$(sha256sum "${GIT_CONFIG_PATH}" | cut -d' ' -f1)"
	current_index_hash="$(sha256sum "${GIT_INDEX_PATH}" | cut -d' ' -f1)"
	if [ "${current_config_hash}" != "${ORIGINAL_CONFIG_HASH}" ] ||
		[ "${current_index_hash}" != "${ORIGINAL_INDEX_HASH}" ]; then
		echo "[error] local Git config or index changed concurrently; recovery required" >&2
		return 1
	fi
	CONFIG_REPLACED=true
	mv -f -- "${TEMP_CONFIG_PATH}" "${GIT_CONFIG_PATH}"
	INDEX_REPLACED=true
	mv -f -- "${TEMP_INDEX_PATH}" "${GIT_INDEX_PATH}"
	trap - ERR HUP INT TERM
	TRANSACTION_ACTIVE=false
	rm -rf -- "${TRANSACTION_DIR}" ||
		echo "[warn] project initialized but temporary rollback artifacts could not be removed" >&2
}

create_parentless_root() {
	local tree
	local root_commit

	clean_remove_starter_identity
	clean_remove_project_init_markers
	GIT_INDEX_FILE="${TEMP_INDEX_PATH}" git add -A
	GIT_INDEX_FILE="${TEMP_INDEX_PATH}" git write-tree >"${TRANSACTION_DIR}/tree"
	read -r tree <"${TRANSACTION_DIR}/tree"
	printf '%s\n' "${ROOT_COMMIT_MESSAGE}" |
		git commit-tree "${tree}" >"${TRANSACTION_DIR}/commit"
	read -r root_commit <"${TRANSACTION_DIR}/commit"
	git update-ref "refs/heads/${TARGET_BRANCH}" "${root_commit}" ""
	clear_target_upstream_config
	git symbolic-ref HEAD "refs/heads/${TARGET_BRANCH}"

	ROOT_COMMIT="${root_commit}"
}

remove_previous_history_refs() {
	local object ref original_object

	while read -r object ref; do
		[ -n "${ref}" ] || continue
		[ "${ref}" = "refs/heads/${TARGET_BRANCH}" ] && continue
		original_object="$(awk -v wanted="${ref}" '$2 == wanted { print $1; exit }' "${TRANSACTION_DIR}/refs")"
		if [ -z "${original_object}" ]; then
			echo "[error] repository refs changed concurrently; recovery required" >&2
			return 1
		fi
		git update-ref -d "${ref}" "${original_object}"
	done < <(git for-each-ref --format='%(objectname) %(refname)')

	if [ "$(git for-each-ref --format='%(refname)')" != "refs/heads/${TARGET_BRANCH}" ]; then
		echo "[error] could not remove all previous history refs" >&2
		return 1
	fi
}

configure_origin() {
	ORIGIN_ACTION="origin preserved"
	[ -z "${NEW_ORIGIN}" ] && return 0

	if git config --file "${TEMP_CONFIG_PATH}" --get-regexp '^remote\.origin\.' >/dev/null 2>&1; then
		git config --file "${TEMP_CONFIG_PATH}" --remove-section remote.origin
		ORIGIN_ACTION="origin updated"
	else
		ORIGIN_ACTION="origin added"
	fi
	git config --file "${TEMP_CONFIG_PATH}" --add remote.origin.url "${NEW_ORIGIN}"
	git config --file "${TEMP_CONFIG_PATH}" --add remote.origin.fetch \
		'+refs/heads/*:refs/remotes/origin/*'
	git config --file "${TEMP_CONFIG_PATH}" --add remote.origin.pushurl "${NEW_ORIGIN}"
}

print_result() {
	echo
	echo "Project initialized."
	echo "  Branch: ${TARGET_BRANCH}"
	echo "  Root commit: ${ROOT_COMMIT}"
	echo "  Origin: ${ORIGIN_ACTION}"
	echo "  Previous local refs removed; unreachable objects remain until Git garbage collection."
	echo "  No remote was contacted or pushed."
	echo "  No verified starter baseline was admitted during initialization."
	echo "  Run task starter:adopt with an exact verified release before using starter updates."
	echo
	if origin_exists; then
		echo "Next step: review the root commit, then push when you are ready."
	else
		echo "Next step: add an origin when ready, then review the root commit."
	fi
}

main() {
	enter_clean_repository_root
	prompt_for_inputs
	print_project_plan
	confirm_project_initialization
	begin_project_transaction
	create_parentless_root
	configure_origin
	remove_previous_history_refs
	commit_project_transaction
	print_result
}

main "$@"
