#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/clean-lib.sh"
if [ -f "${SCRIPT_DIR}/starter-lib/core/derived-tree.sh" ]; then
	# shellcheck source=.taskfiles/scripts/starter-lib/core/derived-tree.sh
	source "${SCRIPT_DIR}/starter-lib/core/derived-tree.sh"
else
	STARTER_DERIVED_REMOVALS=()
	starter_derived_apply_removals() { :; }
fi

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

project_init_usage() {
	cat >&2 <<'EOF'
Usage: project-init.sh [--release starter/vX.Y.Z] [--no-starter-adopt]

By default, initialization adopts the exact annotated release at HEAD. Use
--release when release identity cannot be selected unambiguously. The explicit
--no-starter-adopt escape hatch is for intentionally unmarked projects only.
EOF
}

parse_project_init_args() {
	REQUESTED_RELEASE=""
	STARTER_ADOPT_ENABLED=true
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--release)
			if [ "$#" -lt 2 ] || [ -z "$2" ]; then
				fail "--release requires starter/vX.Y.Z"
			fi
			REQUESTED_RELEASE="$2"
			shift 2
			;;
		--no-starter-adopt)
			STARTER_ADOPT_ENABLED=false
			shift
			;;
		-h | --help)
			project_init_usage
			exit 0
			;;
		*)
			project_init_usage
			fail "unknown argument"
			;;
		esac
	done
	[ -z "${REQUESTED_RELEASE}" ] || [[ "${REQUESTED_RELEASE}" =~ ^starter/v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
		fail "--release must name an exact starter semantic tag"
}

release_source_url() {
	local url
	if git show-ref --verify --quiet "refs/tags/${SELECTED_RELEASE}"; then
		printf 'file://%s\n' "$(pwd -P)"
		return
	fi
	url="$(git remote get-url origin 2>/dev/null || true)"
	case "${url}" in
	https://* | ssh://* | git://* | file:///*) printf '%s\n' "${url}" ;;
	/*) printf 'file://%s\n' "${url}" ;;
	*) printf 'file://%s\n' "$(pwd -P)" ;;
	esac
}

select_originating_release() {
	local head tag peeled matches=()
	if [ -n "${REQUESTED_RELEASE}" ]; then
		SELECTED_RELEASE="${REQUESTED_RELEASE}"
		return
	fi
	head="$(git rev-parse HEAD)"
	while IFS= read -r tag; do
		[ -n "${tag}" ] || continue
		peeled="$(git rev-parse -q --verify "refs/tags/${tag}^{}" 2>/dev/null || true)"
		[ "${peeled}" != "${head}" ] || matches+=("${tag}")
	done < <(git tag --list 'starter/v*' | LC_ALL=C sort)
	case "${#matches[@]}" in
	1) SELECTED_RELEASE="${matches[0]}" ;;
	0) fail "no exact starter release identifies HEAD; fetch the required starter/vX.Y.Z tag or rerun with --release starter/vX.Y.Z" ;;
	*) fail "multiple starter releases identify HEAD; rerun with --release starter/vX.Y.Z" ;;
	esac
}

prepare_adopted_project() {
	local source_url source_result retained_result plan state operation_count index target source official_project
	PREPARED_PROJECT="$(mktemp -d "${TMPDIR:-/tmp}/project-init-preflight.XXXXXX")"
	trap 'rm -rf -- "${PREPARED_PROJECT:-}" "${official_project:-}"' EXIT
	git archive HEAD | tar -x -C "${PREPARED_PROJECT}"
	official_project="${PREPARED_PROJECT}"
	PREPARED_PROJECT="${official_project}.derived"
	starter_derived_transform "${official_project}" "${PREPARED_PROJECT}" || fail "derived project tree could not be materialized"
	STARTER_PROJECT_ROOT="${PREPARED_PROJECT}"
	STARTER_RELEASE="${SELECTED_RELEASE}"
	STARTER_CACHE_DIR="${PREPARED_PROJECT}/.starter-cache"
	export STARTER_PROJECT_ROOT STARTER_RELEASE STARTER_CACHE_DIR
	STARTER_SOURCE_URL="$(release_source_url)"
	source_url="${STARTER_SOURCE_URL}"
	if ! source_result="$(starter_acquire_candidate 2>&1)"; then
		fail "release admission failed before initialization: ${source_result##*$'\n'} (source: ${source_url})"
	fi
	plan="$(starter_build_plan "${source_result}" 0.0.0)" || fail "release baseline plan is invalid"
	PREPARED_PLAN="${plan}"
	operation_count="$(jq '.operations | length' <<<"${plan}")"
	for ((index = 0; index < operation_count; index++)); do
		target="$(jq -r ".operations[${index}].target" <<<"${plan}")"
		if [ "${target}" = ".starter/baseline.json" ] &&
			[ "$(jq -r ".operations[${index}].type" <<<"${plan}")" = copy ]; then
			source="$(jq -r ".operations[${index}].source" <<<"${plan}")"
			cp -- "$(jq -r '.payload_root' <<<"${source_result}")/payloads/${source}" "${PREPARED_PROJECT}/${target}"
		fi
	done
	retained_result="$(starter_retain_candidate "${source_result}")" || fail "release evidence could not be retained"
	state="$(starter_state_build "${PREPARED_PROJECT}" "${retained_result}" "${plan}")" || fail "post-cleanup project does not match release baseline"
	starter_state_persist "${PREPARED_PROJECT}" "${state}" || fail "adoption state could not be prepared"
}

preflight_starter_adoption() {
	[ "${STARTER_ADOPT_ENABLED}" = true ] || return 0
	# shellcheck source=/dev/null
	source "${SCRIPT_DIR}/starter.sh"
	select_originating_release
	prepare_adopted_project
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
	echo "  - never push; exact-tag admission may contact the existing origin"
	echo "Starter update plan:"
	echo "  - retain updater commands and distribution metadata"
	if [ "${STARTER_ADOPT_ENABLED}" = true ]; then
		echo "  - admit and retain exact release: ${SELECTED_RELEASE}"
		echo "  - include the proven baseline, state, and evidence in the root commit"
	else
		echo "  - intentionally leave the project unmarked (--no-starter-adopt)"
	fi
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
	git for-each-ref --format='%(refname) %(symref)' | awk '$2 != ""' >"${TRANSACTION_DIR}/symbolic-refs"

	clean_identity_items
	ROLLBACK_MUTATED_PATHS=(
		"${CLEAN_IDENTITY_ITEMS[@]}"
		"${CLEAN_PROJECT_INIT_MARKERS[@]}"
		"${STARTER_DERIVED_REMOVALS[@]}"
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
	local tree operation_count operation_index operation_target
	local root_commit

	clean_remove_starter_identity
	clean_remove_project_init_markers
	starter_derived_apply_removals "$(pwd -P)"
	if [ "${STARTER_ADOPT_ENABLED}" = true ]; then
		operation_count="$(jq '.operations | length' <<<"${PREPARED_PLAN}")"
		for ((operation_index = 0; operation_index < operation_count; operation_index++)); do
			[ "$(jq -r ".operations[${operation_index}].ownership" <<<"${PREPARED_PLAN}")" = managed ] || continue
			operation_target="$(jq -r ".operations[${operation_index}].target" <<<"${PREPARED_PLAN}")"
			mkdir -p -- "$(dirname "${operation_target}")"
			cp -p -- "${PREPARED_PROJECT}/${operation_target}" "${operation_target}"
		done
		cp -a -- "${PREPARED_PROJECT}/.starter/baseline.json" .starter/baseline.json
		cp -a -- "${PREPARED_PROJECT}/.starter/state.json" .starter/state.json
		cp -a -- "${PREPARED_PROJECT}/.starter/evidence" .starter/evidence
		rebind_adopted_evidence_paths
	fi
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

rebind_adopted_evidence_paths() {
	local version envelope evidence_ref envelope_sha state_sha
	version="$(jq -r '.release.version' .starter/state.json)"
	envelope=".starter/evidence/releases/${version}/envelope.json"
	evidence_ref="$(pwd -P)/.starter/evidence/releases/${version}/evidence"
	envelope_sha="$(jq -cS --arg ref "${evidence_ref}" '.evidence.ref=$ref | del(.integrity)' "${envelope}" | sha256sum | cut -d' ' -f1)"
	jq --arg ref "${evidence_ref}" --arg sha "${envelope_sha}" \
		'.evidence.ref=$ref | .integrity.envelope_sha256=$sha' "${envelope}" >"${envelope}.tmp"
	mv -f -- "${envelope}.tmp" "${envelope}"
	jq --slurpfile envelope "${envelope}" '
		.evidence=$envelope[0].evidence | .envelope.sha256=$envelope[0].integrity.envelope_sha256 | del(.integrity)' \
		.starter/state.json >.starter/state.json.tmp
	state_sha="$(jq -cS . .starter/state.json.tmp | sha256sum | cut -d' ' -f1)"
	jq --arg sha "${state_sha}" '.integrity={canonicalization:"jq-sorted-utf8-v1",state_sha256:$sha}' \
		.starter/state.json.tmp >.starter/state.json
	rm .starter/state.json.tmp
}

remove_previous_history_refs() {
	local object ref original_object symbolic_target original_symbolic_target

	while read -r object ref; do
		[ -n "${ref}" ] || continue
		[ "${ref}" = "refs/heads/${TARGET_BRANCH}" ] && continue
		original_object="$(awk -v wanted="${ref}" '$2 == wanted { print $1; exit }' "${TRANSACTION_DIR}/refs")"
		if [ -z "${original_object}" ]; then
			echo "[error] repository refs changed concurrently; recovery required" >&2
			return 1
		fi
		symbolic_target="$(git symbolic-ref -q "${ref}" 2>/dev/null || true)"
		if [ -n "${symbolic_target}" ]; then
			original_symbolic_target="$(awk -v wanted="${ref}" '$1 == wanted { print $2; exit }' "${TRANSACTION_DIR}/symbolic-refs")"
			if [ -z "${original_symbolic_target}" ] || [ "${symbolic_target}" != "${original_symbolic_target}" ]; then
				echo "[error] symbolic ref changed concurrently; recovery required: ${ref}" >&2
				return 1
			fi
			git symbolic-ref -d "${ref}"
		else
			git update-ref -d "${ref}" "${original_object}"
		fi
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

configure_canonical_starter_remote() {
	local metadata=.starter/source.json name url refspec existing
	[ -f "${metadata}" ] || return 0
	name="$(jq -r '.remote' "${metadata}")"
	url="$(jq -r '.url' "${metadata}")"
	refspec="$(jq -r '.branch_refspec' "${metadata}")"
	existing="$(git config --file "${TEMP_CONFIG_PATH}" --get "remote.${name}.url" 2>/dev/null || true)"
	[ -z "${existing}" ] || [ "${existing%/}" = "${url%/}" ] || fail "canonical starter remote URL mismatch"
	if [ -z "${existing}" ]; then
		git config --file "${TEMP_CONFIG_PATH}" --add "remote.${name}.url" "${url}"
		git config --file "${TEMP_CONFIG_PATH}" --add "remote.${name}.fetch" "${refspec}"
	fi
}

print_result() {
	echo
	echo "Project initialized."
	echo "  Branch: ${TARGET_BRANCH}"
	echo "  Root commit: ${ROOT_COMMIT}"
	echo "  Origin: ${ORIGIN_ACTION}"
	echo "  Previous local refs removed; unreachable objects remain until Git garbage collection."
	echo "  No remote was pushed or reconfigured by release admission."
	if [ "${STARTER_ADOPT_ENABLED}" = true ]; then
		echo "  Starter release ${SELECTED_RELEASE} was admitted into the root commit."
	else
		echo "  Starter adoption was explicitly disabled; the project is intentionally unmarked."
	fi
	echo
	if origin_exists; then
		echo "Next step: review the root commit, then push when you are ready."
	else
		echo "Next step: add an origin when ready, then review the root commit."
	fi
}

main() {
	parse_project_init_args "$@"
	enter_clean_repository_root
	preflight_starter_adoption
	prompt_for_inputs
	print_project_plan
	confirm_project_initialization
	begin_project_transaction
	create_parentless_root
	configure_origin
	configure_canonical_starter_remote
	remove_previous_history_refs
	commit_project_transaction
	print_result
}

main "$@"
