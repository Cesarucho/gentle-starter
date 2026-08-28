#!/usr/bin/env bash
# Shared lexical and filesystem path safety for verified payload consumers.

starter_path_error() {
	printf 'starter path: %s\n' "$*" >&2
}

starter_path_is_normalized_relative() {
	local path="$1" component
	local -a components
	[ -n "${path}" ] && [[ "${path}" != /* ]] || return 1
	IFS='/' read -r -a components <<<"${path}"
	for component in "${components[@]}"; do
		[ -n "${component}" ] && [ "${component}" != . ] && [ "${component}" != .. ] || return 1
	done
}

starter_path_root() {
	local root="$1" physical
	if [[ "${root}" != /* ]] || [ ! -d "${root}" ]; then
		starter_path_error "root is not an absolute directory"
		return 1
	fi
	physical="$(cd -P -- "${root}" && pwd)" || return 1
	printf '%s\n' "${physical}"
}

starter_path_resolve_beneath() {
	local root="$1" path="$2" physical resolved
	starter_path_is_normalized_relative "${path}" || {
		starter_path_error "path is not normalized and relative"
		return 1
	}
	physical="$(starter_path_root "${root}")" || return 1
	resolved="$(realpath -m -- "${physical}/${path}")" || return 1
	case "${resolved}" in
	"${physical}"/*) printf '%s\n' "${resolved}" ;;
	*)
		starter_path_error "path resolves outside root"
		return 1
		;;
	esac
}

starter_path_existing_file_beneath() {
	local resolved
	resolved="$(starter_path_resolve_beneath "$1" "$2")" || return 1
	[ -f "${resolved}" ] || {
		starter_path_error "path is not an existing file"
		return 1
	}
	printf '%s\n' "${resolved}"
}

starter_path_existing_directory_beneath() {
	local resolved
	resolved="$(starter_path_resolve_beneath "$1" "$2")" || return 1
	[ -d "${resolved}" ] || {
		starter_path_error "path is not an existing directory"
		return 1
	}
	printf '%s\n' "${resolved}"
}

starter_paths_collide() {
	local first="$1" second="$2"
	[ "${first}" = "${second}" ] || [[ "${first}" == "${second}"/* ]] || [[ "${second}" == "${first}"/* ]]
}
