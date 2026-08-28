#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.taskfiles/scripts/starter-lib/adapters/git-tag-source.sh
source "${SCRIPT_DIR}/starter-lib/adapters/git-tag-source.sh"

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
	local version="$1" manifest="$2" root count index path expected bytes
	root="$(dirname "${manifest}")"
	jq -e --arg version "${version}" '
		def relative: type == "string" and length > 0 and (startswith("/") | not) and
			(split("/") | all(. != "" and . != "." and . != ".."));
		def sha: type == "string" and test("^[0-9a-f]{64}$");
		type == "object" and ((keys | sort) == ["payload","release","schema","source"] or
			(keys | sort) == ["migrations","payload","release","schema","source"]) and
		.schema == "starter-manifest/v1" and .source == {id:"gentle-starter",release:("starter/v"+$version)} and
		.release.version == $version and
		(.payload.root == "payloads") and (.payload.entries | type == "array" and length > 0 and
			all((keys | sort) == ["bytes","path","sha256"] and (.path | relative) and (.sha256 | sha) and
			(.bytes | type == "number" and . >= 0 and floor == .))) and
		(if has("migrations") then .migrations.root == "migrations" and
			(.migrations.entries | type == "array" and length > 0 and all((keys | sort) == ["id","path","sha256"] and
			(.id | type == "string" and length > 0) and (.path | relative) and (.sha256 | sha))) else true end)
	' "${manifest}" >/dev/null || {
		release_error "distribution manifest is malformed or does not match version ${version}"
		return 1
	}
	count="$(jq '.payload.entries | length' "${manifest}")"
	for ((index = 0; index < count; index++)); do
		path="$(jq -r ".payload.entries[${index}].path" "${manifest}")"
		expected="$(jq -r ".payload.entries[${index}].sha256" "${manifest}")"
		bytes="$(jq -r ".payload.entries[${index}].bytes" "${manifest}")"
		if [ ! -f "${root}/payloads/${path}" ] || [ -L "${root}/payloads/${path}" ] ||
			[ "$(sha256sum "${root}/payloads/${path}" | cut -d' ' -f1)" != "${expected}" ] ||
			[ "$(wc -c <"${root}/payloads/${path}")" -ne "${bytes}" ]; then
			release_error "distribution payload binding mismatch: ${path}"
			return 1
		fi
	done
	count="$(jq 'if has("migrations") then .migrations.entries | length else 0 end' "${manifest}")"
	for ((index = 0; index < count; index++)); do
		path="$(jq -r ".migrations.entries[${index}].path" "${manifest}")"
		expected="$(jq -r ".migrations.entries[${index}].sha256" "${manifest}")"
		if [ ! -f "${root}/migrations/${path}" ] || [ -L "${root}/migrations/${path}" ] ||
			[ "$(sha256sum "${root}/migrations/${path}" | cut -d' ' -f1)" != "${expected}" ]; then
			release_error "distribution migration binding mismatch: ${path}"
			return 1
		fi
	done
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
	local version="${1:-}" manifest=.starter/distribution/manifest.json commit tree blob manifest_sha metadata
	local temporary request result
	if [ "$#" -ne 1 ] || [[ ! "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
		release_error "usage: task starter:release -- <X.Y.Z>"
		return 1
	fi
	TAG="starter/v${version}"
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
	if ! git diff --quiet HEAD -- .starter/distribution || ! git diff --cached --quiet HEAD -- .starter/distribution; then
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
