#!/usr/bin/env bash
# Transport-neutral lifecycle manifest loading and binding validation.

STARTER_MANIFEST_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.taskfiles/scripts/starter-lib/contracts/source-port.sh
source "${STARTER_MANIFEST_CORE_DIR}/../contracts/source-port.sh"

starter_manifest_error() {
	printf 'starter manifest: %s\n' "$*" >&2
}

starter_manifest_load() {
	local source_result="$1"
	local normalized envelope_file payload_root manifest_file migration_root
	local migration_count index migration_path expected_sha

	normalized="$(starter_source_result_validate "${source_result}")" || return 1
	envelope_file="$(jq -r '.envelope_file' <<<"${normalized}")"
	payload_root="$(jq -r '.payload_root' <<<"${normalized}")"
	manifest_file="$(starter_path_existing_file_beneath "${payload_root}" "$(jq -r '.manifest.path' "${envelope_file}")")" || {
		starter_manifest_error "unsafe manifest path"
		return 1
	}
	if ! jq -e '
		def relative: type == "string" and length > 0 and (startswith("/") | not) and
			(split("/") | all(. != "" and . != "." and . != ".."));
		.migrations.root | relative
	' "${manifest_file}" >/dev/null || ! jq -e '
		def relative: type == "string" and length > 0 and (startswith("/") | not) and
			(split("/") | all(. != "" and . != "." and . != ".."));
		.migrations.entries | type == "array" and all(.path | relative)
	' "${manifest_file}" >/dev/null; then
		starter_manifest_error "unsafe migration path"
		return 1
	fi

	jq -e --slurpfile envelope "${envelope_file}" '
		def exact_keys($expected): (keys | sort) == ($expected | sort);
		def semver: type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$");
		def sha256: type == "string" and test("^[0-9a-f]{64}$");
		def relative: type == "string" and length > 0 and (startswith("/") | not) and
			(split("/") | all(. != "" and . != "." and . != ".."));
		type == "object" and exact_keys(["schema","source","release","payload","migrations"]) and
		.schema == "starter-manifest/v1" and
		(.source | type == "object" and exact_keys(["id","release"]) and
			(.id | type == "string" and length > 0) and (.release == ("starter/v" + $envelope[0].release.version))) and
		(.release | type == "object" and exact_keys(["version","predecessor_id"]) and
			(.version | semver) and .version == $envelope[0].release.version and
			.predecessor_id == $envelope[0].release.predecessor_id) and
		(.payload == $envelope[0].payload) and
		(.migrations | type == "object" and exact_keys(["root","entries"]) and
			(.root | relative) and
			(.entries | type == "array" and length > 0 and
				all(type == "object" and exact_keys(["id","path","sha256"]) and
					(.id | type == "string" and length > 0) and
					(.path | relative) and (.sha256 | sha256)) and
				(map(.id) | length == (unique | length)) and
				(map(.path) | length == (unique | length))))
	' "${manifest_file}" >/dev/null || {
		starter_manifest_error "invalid lifecycle manifest"
		return 1
	}

	migration_root="$(starter_path_existing_directory_beneath "${payload_root}" "$(jq -r '.migrations.root' "${manifest_file}")")" || {
		starter_manifest_error "unsafe migration path"
		return 1
	}
	migration_count="$(jq '.migrations.entries | length' "${manifest_file}")"
	for ((index = 0; index < migration_count; index++)); do
		migration_path="$(starter_path_existing_file_beneath "${migration_root}" "$(jq -r ".migrations.entries[${index}].path" "${manifest_file}")")" || {
			starter_manifest_error "unsafe migration path"
			return 1
		}
		expected_sha="$(jq -r ".migrations.entries[${index}].sha256" "${manifest_file}")"
		if [ ! -f "${migration_path}" ] || [ "$(sha256sum "${migration_path}" | cut -d' ' -f1)" != "${expected_sha}" ]; then
			starter_manifest_error "migration descriptor binding mismatch"
			return 1
		fi
	done

	jq -cn \
		--arg envelope_file "${envelope_file}" \
		--arg payload_root "${payload_root}" \
		--arg manifest_file "${manifest_file}" \
		--arg migration_root "${migration_root}" \
		--arg release_id "$(jq -r '.release.id' "${envelope_file}")" \
		--arg version "$(jq -r '.release.version' "${envelope_file}")" \
		--slurpfile manifest "${manifest_file}" \
		'{envelope_file:$envelope_file,payload_root:$payload_root,manifest_file:$manifest_file,
			migration_root:$migration_root,target_release:{id:$release_id,version:$version},manifest:$manifest[0]}'
}

starter_manifest_payload_digest() {
	local context="$1" source_path="$2"
	local digest
	starter_path_existing_file_beneath \
		"$(jq -r '.payload_root + "/" + .manifest.payload.root' <<<"${context}")" "${source_path}" >/dev/null || {
		starter_manifest_error "operation source escapes release payload root"
		return 1
	}
	digest="$(jq -r --arg path "${source_path}" '.manifest.payload.entries[] | select(.path == $path) | .sha256' <<<"${context}")"
	[ -n "${digest}" ] || {
		starter_manifest_error "operation source is not bound by the payload manifest"
		return 1
	}
	printf '%s\n' "${digest}"
}
