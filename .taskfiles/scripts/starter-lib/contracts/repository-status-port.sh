#!/usr/bin/env bash
# Transport-neutral repository cleanliness contract.

starter_repository_status_error() {
	printf 'starter repository status: %s\n' "$*" >&2
}

repository_status_inspect() {
	local project_root="$1" implementation="${STARTER_REPOSITORY_STATUS_IMPL:-}" result
	if ! [[ "${implementation}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || ! declare -F "${implementation}" >/dev/null; then
		starter_repository_status_error "repository status implementation is unavailable"
		return 1
	fi
	result="$("${implementation}" "${project_root}")" || return 1
	jq -e '
		type == "object" and
		(keys | sort) == ["clean", "is_repository", "root_matches", "schema"] and
		.schema == "gentle-starter.repository-status/v1" and
		all(.is_repository, .root_matches, .clean; type == "boolean") and
		(if .is_repository then true else (.root_matches == false and .clean == false) end) and
		(if .root_matches then .is_repository else true end)
	' <<<"${result}" >/dev/null || {
		starter_repository_status_error "repository status result is invalid"
		return 1
	}
	printf '%s\n' "$(jq -cS . <<<"${result}")"
}
