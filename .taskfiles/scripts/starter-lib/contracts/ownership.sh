#!/usr/bin/env bash
# Strict ownership inventory validation and target classification.

starter_ownership_error() {
	printf 'starter ownership: %s\n' "$*" >&2
}

starter_ownership_is_generated_path() {
	case "$1" in
	.starter/state.json | .starter/evidence/* | .starter/journals/* | .starter/caches/* | \
		.starter/proposals/* | .starter/pending/*) return 0 ;;
	esac
	return 1
}

starter_ownership_validate_file() {
	local inventory="$1"
	jq -e '
		def exact_keys($expected): (keys | sort) == ($expected | sort);
		def relative: type == "string" and length > 0 and (startswith("/") | not) and
			(split("/") | all(. != "" and . != "." and . != ".."));
		def entry: type == "object" and
			(if has("contract") then exact_keys(["match","path","contract"]) else exact_keys(["match","path"]) end) and
			.match == "exact" and (.path | relative) and
			(if has("contract") then .contract == "F-manual/v1" else true end);
		type == "object" and exact_keys(["schema","default_ownership","managed","fusion"]) and
		.schema == "gentle-starter.ownership-inventory/v2" and
		.default_ownership == "project-owned" and
		(.managed | type == "array" and all(entry)) and
		(.fusion | type == "array" and all(entry))
	' "${inventory}" >/dev/null || {
		starter_ownership_error "invalid ownership inventory"
		return 1
	}
	jq -e '.fusion == [
			{match:"exact",path:".devcontainer/devcontainer.json",contract:"F-manual/v1"},
			{match:"exact",path:".devcontainer/docker-compose.yml",contract:"F-manual/v1"}
		]' "${inventory}" >/dev/null || {
		starter_ownership_error "fusion declarations do not match supported F-manual/v1 paths"
		return 1
	}
	local entries count left_index right_index left_path right_path
	entries="$(jq -c '[.managed[],(.fusion[] | del(.contract))]' "${inventory}")"
	count="$(jq 'length' <<<"${entries}")"
	for ((left_index = 0; left_index < count; left_index++)); do
		left_path="$(jq -r ".[$left_index].path" <<<"${entries}")"
		if starter_ownership_is_generated_path "${left_path}"; then
			starter_ownership_error "generated operational path cannot be distributed or owned"
			return 1
		fi
		for ((right_index = left_index + 1; right_index < count; right_index++)); do
			right_path="$(jq -r ".[$right_index].path" <<<"${entries}")"
			if [ "${left_path}" = "${right_path}" ] ||
				[[ "${right_path}" == "${left_path}/"* ]] || [[ "${left_path}" == "${right_path}/"* ]]; then
				starter_ownership_error "duplicate, overlapping, or ancestor ownership entries"
				return 1
			fi
		done
	done
}

starter_ownership_classify() {
	local inventory="$1" target="$2" matches
	matches="$(jq -r --arg target "${target}" '[
		(.managed[] | select(.path == $target) | "managed"),
		(.fusion[] | select(.path == $target) | "fusion")
	] | unique | if length == 0 then "project-owned" elif length == 1 then .[0] else "ambiguous" end' "${inventory}")"
	[ "${matches}" != ambiguous ] || {
		starter_ownership_error "target resolves to multiple ownership classes"
		return 1
	}
	printf '%s\n' "${matches}"
}
