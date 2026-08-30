#!/usr/bin/env bash
# Transport-neutral source and release-payload contracts.

STARTER_CONTRACT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.taskfiles/scripts/starter-lib/contracts/path-safety.sh
source "${STARTER_CONTRACT_DIR}/path-safety.sh"
# shellcheck source=.taskfiles/scripts/starter-lib/contracts/evidence-limits.sh
source "${STARTER_CONTRACT_DIR}/evidence-limits.sh"

starter_contract_error() {
	printf 'starter contract: %s\n' "$*" >&2
}

starter_require_command() {
	local command_name="$1"
	command -v "${command_name}" >/dev/null 2>&1 || {
		starter_contract_error "required command unavailable: ${command_name}"
		return 1
	}
}

starter_source_result_validate() {
	local result="$1"
	local envelope_file payload_root

	jq -e '
		type == "object" and
		(keys | sort) == ["envelope_file", "payload_root"] and
		(.envelope_file | type == "string" and length > 0) and
		(.payload_root | type == "string" and length > 0)
	' <<<"${result}" >/dev/null || {
		starter_contract_error "invalid source port result"
		return 1
	}
	envelope_file="$(jq -r '.envelope_file' <<<"${result}")"
	payload_root="$(jq -r '.payload_root' <<<"${result}")"
	release_payload_validate "${envelope_file}" "${payload_root}" || return 1
	printf '%s\n' "$(jq -cS . <<<"${result}")"
}

starter_source_port_invoke() {
	local implementation="$1"
	local argument="$2"
	local result

	if ! [[ "${implementation}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || ! declare -F "${implementation}" >/dev/null; then
		starter_contract_error "source port implementation is unavailable"
		return 1
	fi
	result="$("${implementation}" "${argument}")" || return 1
	starter_source_result_validate "${result}"
}

source_acquire() {
	local request_file="$1"
	[ -f "${request_file}" ] || {
		starter_contract_error "source acquisition request is not a file"
		return 1
	}
	starter_source_port_invoke "${STARTER_SOURCE_ACQUIRE_IMPL:-}" "${request_file}"
}

evidence_revalidate() {
	local opaque_ref="$1"
	[ -n "${opaque_ref}" ] || {
		starter_contract_error "evidence reference is empty"
		return 1
	}
	starter_source_port_invoke "${STARTER_EVIDENCE_REVALIDATE_IMPL:-}" "${opaque_ref}"
}

release_payload_validate() {
	local envelope_file="$1"
	local payload_root="$2"
	local expected_integrity actual_integrity manifest_path manifest_sha ownership_path ownership_sha
	local payload_dir entry_count index entry_path entry_sha entry_bytes

	[ -f "${envelope_file}" ] || {
		starter_contract_error "release payload envelope is not a file"
		return 1
	}
	[ -d "${payload_root}" ] || {
		starter_contract_error "release payload root is not a directory"
		return 1
	}
	jq -e '.schema == "gentle-starter.release-payload/v2"' "${envelope_file}" >/dev/null || {
		starter_contract_error "unsupported release payload schema"
		return 1
	}
	jq -e '
		def exact_keys($expected): (keys | sort) == ($expected | sort);
		def sha256: type == "string" and test("^[0-9a-f]{64}$");
		def sha256_id: type == "string" and test("^sha256:[0-9a-f]{64}$");
		def adapter_id: type == "string" and test("^[A-Za-z][A-Za-z0-9-]*/v[1-9][0-9]*$");
		def relative_path:
			type == "string" and length > 0 and
			(startswith("/") | not) and
			(split("/") | all(. != "" and . != "." and . != ".."));
		type == "object" and
		exact_keys(["schema", "source", "release", "immutable_identities", "manifest", "ownership", "payload", "evidence", "integrity"]) and
		(.source | type == "object" and exact_keys(["adapter_id", "source_id"]) and (.adapter_id | adapter_id) and (.source_id | sha256_id)) and
		(.release | type == "object" and exact_keys(["id", "version", "predecessor_id"]) and (.id | sha256_id) and
			(.version | type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")) and
			(.predecessor_id == null or (.predecessor_id | sha256_id))) and
		(.immutable_identities | type == "array" and length == 2 and
			all(type == "object" and exact_keys(["role", "id"]) and (.role == "release" or .role == "content") and (.id | sha256_id)) and
			(map(.role) | sort) == ["content", "release"]) and
		(.manifest | type == "object" and exact_keys(["schema", "path", "sha256"]) and
			.schema == "starter-manifest/v2" and (.path | relative_path) and (.sha256 | sha256)) and
		(.ownership | type == "object" and exact_keys(["schema", "path", "sha256"]) and
			.schema == "gentle-starter.ownership-inventory/v2" and (.path | relative_path) and (.sha256 | sha256)) and
		(.payload | type == "object" and exact_keys(["root", "entries"]) and (.root | relative_path) and
			(.entries | type == "array" and length > 0 and
				all(type == "object" and (keys | sort) == ["bytes","mode","path","presence","sha256"] and
					(.path | relative_path) and (.sha256 | sha256) and (.bytes | type == "number" and . >= 0 and floor == .)) and
				(map(.path) as $paths | ($paths | length) == ($paths | unique | length)))) and
		(.evidence | type == "object" and exact_keys(["adapter_id", "ref", "sha256"]) and
			(.adapter_id | adapter_id) and (.ref | type == "string" and length > 0) and (.sha256 | sha256)) and
		(.integrity | type == "object" and exact_keys(["canonicalization", "envelope_sha256"]) and
			.canonicalization == "jq-sorted-utf8-v1" and (.envelope_sha256 | sha256))
	' "${envelope_file}" >/dev/null || {
		starter_contract_error "invalid release payload envelope"
		return 1
	}

	expected_integrity="$(jq -r '.integrity.envelope_sha256' "${envelope_file}")"
	actual_integrity="$(jq -cS 'del(.integrity)' "${envelope_file}" | sha256sum | cut -d' ' -f1)"
	[ "${actual_integrity}" = "${expected_integrity}" ] || {
		starter_contract_error "release payload envelope digest mismatch"
		return 1
	}

	manifest_path="$(starter_path_existing_file_beneath "${payload_root}" "$(jq -r '.manifest.path' "${envelope_file}")")" || {
		starter_contract_error "release manifest is missing"
		return 1
	}
	manifest_sha="$(jq -r '.manifest.sha256' "${envelope_file}")"
	[ "$(sha256sum "${manifest_path}" | cut -d' ' -f1)" = "${manifest_sha}" ] || {
		starter_contract_error "release manifest digest mismatch"
		return 1
	}
	ownership_path="$(starter_path_existing_file_beneath "${payload_root}" "$(jq -r '.ownership.path' "${envelope_file}")")" || {
		starter_contract_error "release ownership inventory is missing"
		return 1
	}
	ownership_sha="$(jq -r '.ownership.sha256' "${envelope_file}")"
	[ "$(sha256sum "${ownership_path}" | cut -d' ' -f1)" = "${ownership_sha}" ] || {
		starter_contract_error "release ownership inventory digest mismatch"
		return 1
	}

	payload_dir="$(starter_path_existing_directory_beneath "${payload_root}" "$(jq -r '.payload.root' "${envelope_file}")")" || {
		starter_contract_error "release payload directory is unsafe"
		return 1
	}
	entry_count="$(jq '.payload.entries | length' "${envelope_file}")"
	for ((index = 0; index < entry_count; index++)); do
		entry_path="$(starter_path_existing_file_beneath "${payload_dir}" "$(jq -r ".payload.entries[${index}].path" "${envelope_file}")")" || {
			starter_contract_error "release payload entry is missing or unsafe"
			return 1
		}
		entry_sha="$(jq -r ".payload.entries[${index}].sha256" "${envelope_file}")"
		entry_bytes="$(jq -r ".payload.entries[${index}].bytes" "${envelope_file}")"
		[ "$(sha256sum "${entry_path}" | cut -d' ' -f1)" = "${entry_sha}" ] || {
			starter_contract_error "release payload entry digest mismatch"
			return 1
		}
		[ "$(wc -c <"${entry_path}")" -eq "${entry_bytes}" ] || {
			starter_contract_error "release payload entry size mismatch"
			return 1
		}
		[ "$(stat -c '%a' "${entry_path}")" = "$(jq -r ".payload.entries[${index}].mode" "${envelope_file}")" ] || {
			starter_contract_error "release payload entry mode mismatch"
			return 1
		}
	done
}
