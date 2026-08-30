#!/usr/bin/env bash
# Query-only canonical source validation. Mutation belongs to project:init.

starter_canonical_remote_query() {
	local project_root="$1" metadata name expected actual
	metadata="${project_root}/.starter/source.json"
	[ -f "${metadata}" ] || {
		printf 'starter remote: source metadata is missing\n' >&2
		return 1
	}
	jq -e 'type == "object" and keys == ["branch_refspec","release_ref_namespace","remote","schema","url"] and
		.schema == "gentle-starter.source/v1" and .remote == "gentle-starter" and
		(.url | type == "string" and length > 0) and
		.branch_refspec == "+refs/heads/*:refs/remotes/gentle-starter/*" and
		.release_ref_namespace == "refs/gentle-starter/releases"' "${metadata}" >/dev/null || return 1
	name="$(jq -r '.remote' "${metadata}")"
	expected="$(jq -r '.url' "${metadata}")"
	actual="$(git -C "${project_root}" remote get-url "${name}" 2>/dev/null || true)"
	if [ -n "${actual}" ] && [ "${actual%/}" != "${expected%/}" ]; then
		printf 'starter remote: canonical remote URL mismatch\n' >&2
		return 1
	fi
	printf '%s\n' "${expected}"
}
