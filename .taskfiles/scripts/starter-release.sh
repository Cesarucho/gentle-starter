#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.taskfiles/scripts/starter-lib/adapters/git-tag-source.sh
source "${SCRIPT_DIR}/starter-lib/adapters/git-tag-source.sh"
# shellcheck source=.taskfiles/scripts/starter-lib/contracts/ownership.sh
source "${SCRIPT_DIR}/starter-lib/contracts/ownership.sh"
# shellcheck source=.taskfiles/scripts/starter-prepare-release.sh
source "${SCRIPT_DIR}/starter-prepare-release.sh"

release_error() {
	printf 'starter release: %s\n' "$*" >&2
}

require_clean_repository() {
	git rev-parse --show-toplevel >/dev/null 2>&1 || {
		release_error "run from the Gentle Starter repository"
		return 1
	}
	[ "$(git rev-parse --show-toplevel)" = "${PWD}" ] || {
		release_error "run from the Gentle Starter repository root"
		return 1
	}
	if [ ! -f AGENTS.md ] || [ ! -d .starter/distribution ]; then
		release_error "run from the Gentle Starter repository"
		return 1
	fi
	git rev-parse --verify 'HEAD^{commit}' >/dev/null 2>&1 || {
		release_error "HEAD must be a valid commit"
		return 1
	}
	if git log --format=%s --max-parents=0 HEAD | grep -Fxq 'chore: initialize project'; then
		release_error "publisher repository history is required; derived project roots cannot create releases"
		return 1
	fi
	[ -z "$(git status --porcelain=v1 --untracked-files=all)" ] || {
		release_error "worktree and index must be clean"
		return 1
	}
}

validate_distribution() {
	local version="$1" manifest="$2" root predecessor
	root="$(dirname "${manifest}")"
	predecessor="$(jq -r '.release.predecessor_version // empty' "${manifest}" 2>/dev/null)"
	if [ -z "${predecessor}" ] || ! starter_prepare_validate "${root}" "${version}" "${predecessor}"; then
		release_error "prepared v2 release is invalid"
		return 1
	fi
}

remote_has_tag() {
	local remote="${STARTER_RELEASE_REMOTE:-origin}" output status
	git remote get-url --push "${remote}" >/dev/null 2>&1 || return 1
	set +e
	output="$(git ls-remote --tags "${remote}" "refs/tags/${TAG}" "refs/tags/${TAG}^{}" 2>/dev/null)"
	status=$?
	set -e
	[ "${status}" -eq 0 ] && [ -n "${output}" ]
}

rollback_created_tag() {
	local current
	current="$(git rev-parse --verify "refs/tags/${TAG}^{tag}" 2>/dev/null || true)"
	[ "${current}" = "${CREATED_TAG_OID:-}" ] || return 0
	git update-ref -d "refs/tags/${TAG}" "${CREATED_TAG_OID}"
}

main() {
	local version="${1:-}" manifest commit tree blob manifest_sha metadata
	local temporary request result
	if [ "$#" -ne 1 ] || [[ ! "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
		release_error "usage: task starter:release -- <X.Y.Z>"
		return 1
	fi
	TAG="starter/v${version}"
	manifest=".starter/distribution/prepared/${version}/manifest.json"
	require_clean_repository
	git show-ref --verify --quiet "refs/tags/${TAG}" && {
		release_error "local tag already exists: ${TAG}"
		return 1
	}
	remote_has_tag && {
		release_error "publication remote already has exact tag: ${TAG}"
		return 1
	}
	if [ ! -f "${manifest}" ] || [ -L "${manifest}" ]; then
		release_error "distribution manifest is missing or invalid"
		return 1
	fi
	validate_distribution "${version}" "${manifest}"
	if ! git diff --quiet HEAD -- "$(dirname "${manifest}")" || ! git diff --cached --quiet HEAD -- "$(dirname "${manifest}")"; then
		release_error "distribution assets must match committed HEAD"
		return 1
	fi
	commit="$(git rev-parse 'HEAD^{commit}')"
	tree="$(git rev-parse 'HEAD^{tree}')"
	blob="$(git rev-parse "${commit}:${manifest}" 2>/dev/null)" || {
		release_error "distribution manifest is not committed"
		return 1
	}
	manifest_sha="$(git show "${commit}:${manifest}" | sha256sum | cut -d' ' -f1)"
	metadata="$(jq -cn --arg version "${version}" --arg commit "${commit}" --arg tree "${tree}" --arg path "${manifest}" \
		--arg blob "${blob}" --arg sha "${manifest_sha}" '{schema:"gentle-starter.git-tag/v1",source_id:"gentle-starter",version:$version,
		commit_oid:$commit,tree_oid:$tree,manifest:{path:$path,blob_oid:$blob,sha256:$sha}}')"
	git tag -a -m "${metadata}" "${TAG}" "${commit}"
	CREATED_TAG_OID="$(git rev-parse "refs/tags/${TAG}^{tag}")"
	trap rollback_created_tag ERR INT TERM
	if [ "${STARTER_RELEASE_FAILPOINT:-}" = after-tag ]; then
		release_error "induced post-create validation failure"
		rollback_created_tag
		return 1
	fi
	temporary="$(mktemp -d "${TMPDIR:-/tmp}/starter-release.XXXXXX")"
	trap 'rm -rf "${temporary}"; rollback_created_tag' ERR INT TERM
	request="${temporary}/request.json"
	jq -n --arg remote "file://${PWD}" --arg selector "${TAG}" --arg output "${temporary}/admitted" '{
		schema:"gentle-starter.git-tag-source-request/v1",source_id:"gentle-starter",remote:$remote,selector:$selector,output_dir:$output
	}' >"${request}"
	if ! result="$(git_tag_source_acquire "${request}")"; then
		rollback_created_tag
		return 1
	fi
	[ -f "$(jq -r '.envelope_file' <<<"${result}")" ]
	trap - ERR INT TERM
	rm -rf "${temporary}"
	printf 'starter release created\nselector/tag: %s\ncommit: %s\ntree: %s\nmanifest sha256: %s\nstructural/integrity status: validated\nremote publication: pending\n' \
		"${TAG}" "${commit}" "${tree}" "${manifest_sha}"
}

main "$@"
