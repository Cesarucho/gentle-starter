#!/usr/bin/env bash
# Declarative migration validation and deterministic chain selection.

STARTER_MIGRATION_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.taskfiles/scripts/starter-lib/core/manifest.sh
source "${STARTER_MIGRATION_CORE_DIR}/manifest.sh"

starter_migration_error() {
	printf 'starter migration: %s\n' "$*" >&2
}

starter_migration_validate_file() {
	local migration_file="$1"
	jq -e '
		def exact_keys($expected): (keys | sort) == ($expected | sort);
		def semver: type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$");
		def sha256: type == "string" and test("^[0-9a-f]{64}$");
		def relative: type == "string" and length > 0 and (startswith("/") | not) and
			(split("/") | all(. != "" and . != "." and . != ".."));
		type == "object" and exact_keys(["schema","id","from_version","to_version","operations"]) and
		.schema == "starter-migration/v1" and (.id | type == "string" and length > 0) and
		(.from_version | semver) and (.to_version | semver) and .from_version != .to_version and
		(.operations | type == "array" and
			all(type == "object" and exact_keys(["type","ownership","source","target","expected_before_sha256"]) and
				(.type == "copy" or .type == "delete" or .type == "fusion") and
				(.ownership == "managed" or .ownership == "fusion" or .ownership == "project-owned") and
				(.target | relative) and
				(.expected_before_sha256 == null or (.expected_before_sha256 | sha256)) and
				(if .type == "delete" then .source == null
					 else (.source | relative) end)))
	' "${migration_file}" >/dev/null || {
		starter_migration_error "invalid migration descriptor"
		return 1
	}
}

starter_migration_documents() {
	local context="$1"
	local count index path expected_id document documents='[]'
	count="$(jq '.manifest.migrations.entries | length' <<<"${context}")"
	for ((index = 0; index < count; index++)); do
		path="$(jq -r --argjson index "${index}" '.migration_root + "/" + .manifest.migrations.entries[$index].path' <<<"${context}")"
		expected_id="$(jq -r --argjson index "${index}" '.manifest.migrations.entries[$index].id' <<<"${context}")"
		starter_migration_validate_file "${path}" || return 1
		document="$(jq -c . "${path}")"
		[ "$(jq -r '.id' <<<"${document}")" = "${expected_id}" ] || {
			starter_migration_error "migration identifier binding mismatch"
			return 1
		}
		documents="$(jq -cn --argjson documents "${documents}" --argjson document "${document}" '$documents + [$document]')"
	done
	printf '%s\n' "${documents}"
}

starter_migration_select_chain() {
	local context="$1" current_version="$2"
	local target_version documents selected='[]' matches match_count next_version step=0 maximum
	target_version="$(jq -r '.target_release.version' <<<"${context}")"
	documents="$(starter_migration_documents "${context}")" || return 1
	maximum="$(jq 'length' <<<"${documents}")"
	while [ "${current_version}" != "${target_version}" ]; do
		matches="$(jq -c --arg current "${current_version}" '[.[] | select(.from_version == $current)]' <<<"${documents}")"
		match_count="$(jq 'length' <<<"${matches}")"
		[ "${match_count}" -eq 1 ] || {
			starter_migration_error "incomplete migration chain from ${current_version}"
			return 1
		}
		selected="$(jq -cn --argjson selected "${selected}" --argjson next "$(jq '.[0]' <<<"${matches}")" '$selected + [$next]')"
		next_version="$(jq -r '.[0].to_version' <<<"${matches}")"
		current_version="${next_version}"
		step=$((step + 1))
		[ "${step}" -le "${maximum}" ] || {
			starter_migration_error "migration chain does not reach target release"
			return 1
		}
	done
	printf '%s\n' "${selected}"
}
