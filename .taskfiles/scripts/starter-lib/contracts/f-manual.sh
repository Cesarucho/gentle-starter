#!/usr/bin/env bash
# F-manual/v1 equality rules. This module never merges content.

starter_f_manual_decision() {
	local base="$1" ours="$2" theirs="$3"
	if [ "${ours}" = "${base}" ]; then
		printf 'take-starter\n'
	elif [ "${theirs}" = "${base}" ]; then
		printf 'keep-project\n'
	else
		printf 'manual\n'
	fi
}

starter_f_manual_validate_paths() {
	local path
	for path in "$@"; do
		case "${path}" in
		.devcontainer/devcontainer.json | .devcontainer/docker-compose.yml) ;;
		*)
			printf 'starter F-manual: unsupported path: %s\n' "${path}" >&2
			return 1
			;;
		esac
	done
}

starter_f_manual_resolve_all() {
	local journal="$1" choice="$2" count
	case "${choice}" in take-starter | keep-project | continue | abort) ;; *) return 1 ;; esac
	jq -e '.schema == "gentle-starter.journal/v2" and .fusion.contract == "F-manual/v1" and
		(.fusion.pending | type == "array" and length > 0)' "${journal}" >/dev/null || return 1
	count="$(jq '.fusion.pending | length' "${journal}")"
	jq --arg choice "${choice}" --argjson count "${count}" \
		'.fusion.decision={scope:"all",choice:$choice,count:$count}' "${journal}"
}
