#!/usr/bin/env bash
# Transport-neutral source and verified-payload contracts.

STARTER_CONTRACT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARTER_VERIFIED_PAYLOAD_SCHEMA="${STARTER_CONTRACT_DIR}/verified-payload-v1.schema.json"
# shellcheck source=.taskfiles/scripts/starter-lib/contracts/path-safety.sh
source "${STARTER_CONTRACT_DIR}/path-safety.sh"

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
	verified_payload_validate "${envelope_file}" "${payload_root}" || return 1
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

signer_policy_evaluate() {
	local policy_file="$1"
	local signer_subject_id="$2"
	local release_version="$3"
	local policy_id policy_sha signer valid_from valid_until revoked_at

	[ -f "${policy_file}" ] || {
		starter_contract_error "signer policy is not a file"
		return 1
	}
	[[ "${release_version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
		starter_contract_error "release version is not semantic"
		return 1
	}
	jq -e '
		def exact_keys($expected): (keys | sort) == ($expected | sort);
		def semver: type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$");
		def subject: type == "string" and test("^openpgp:[0-9A-F]{40}$");
		def key_file: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*\\.asc$");
		type == "object" and exact_keys(["schema", "policy_id", "signers", "revocations", "rotations", "evidence_limits"]) and
		.schema == "gentle-starter.signer-policy/v1" and (.policy_id | type == "string" and length > 0) and
		(.evidence_limits | type == "object" and
			exact_keys(["max_reachable_objects", "max_object_bytes", "max_pack_bytes", "max_retained_bytes"]) and
			all(.max_reachable_objects, .max_object_bytes, .max_pack_bytes, .max_retained_bytes;
				type == "number" and floor == . and . > 0)) and
		(.signers | type == "array" and length > 0 and
			all(type == "object" and exact_keys(["subject_id", "key_file", "valid_from", "valid_until"]) and
				(.subject_id | subject) and (.key_file | key_file) and (.valid_from | semver) and
				(.valid_until == null or (.valid_until | semver))) and
			(map(.subject_id) as $subjects | ($subjects | length) == ($subjects | unique | length))) and
		(.revocations | type == "array" and
			all(type == "object" and exact_keys(["subject_id", "effective_version", "reason"]) and
				(.subject_id | subject) and (.effective_version | semver) and (.reason | type == "string" and length > 0)) and
			(map(.subject_id) as $revoked | ($revoked | length) == ($revoked | unique | length))) and
		(.rotations | type == "array" and
			all(type == "object" and exact_keys(["from_subject_id", "to_subject_id", "effective_version"]) and
				(.from_subject_id | subject) and (.to_subject_id | subject) and
				.from_subject_id != .to_subject_id and (.effective_version | semver))) and
		((.signers | map(.subject_id)) as $subjects |
			(.revocations | all(.subject_id as $id | $subjects | index($id) != null)) and
			(.rotations | all(.from_subject_id as $from | .to_subject_id as $to |
				($subjects | index($from) != null) and ($subjects | index($to) != null))))
	' "${policy_file}" >/dev/null || {
		starter_contract_error "invalid signer policy"
		return 1
	}
	signer="$(jq -c --arg signer "${signer_subject_id}" '.signers[] | select(.subject_id == $signer)' "${policy_file}")"
	[ -n "${signer}" ] || {
		starter_contract_error "signer is not pinned by policy"
		return 1
	}
	valid_from="$(jq -r '.valid_from' <<<"${signer}")"
	valid_until="$(jq -r '.valid_until // empty' <<<"${signer}")"
	jq -en --arg release "${release_version}" --arg boundary "${valid_from}" \
		'def version: split(".") | map(tonumber); ($release | version) >= ($boundary | version)' >/dev/null || {
		starter_contract_error "signer is outside its allowed release window"
		return 1
	}
	if [ -n "${valid_until}" ] && jq -en --arg release "${release_version}" --arg boundary "${valid_until}" \
		'def version: split(".") | map(tonumber); ($release | version) >= ($boundary | version)' >/dev/null; then
		starter_contract_error "signer is outside its allowed release window"
		return 1
	fi
	revoked_at="$(jq -r --arg signer "${signer_subject_id}" '.revocations[] | select(.subject_id == $signer) | .effective_version' "${policy_file}")"
	if [ -n "${revoked_at}" ] && jq -en --arg release "${release_version}" --arg boundary "${revoked_at}" \
		'def version: split(".") | map(tonumber); ($release | version) >= ($boundary | version)' >/dev/null; then
		starter_contract_error "signer is revoked for release version ${release_version}"
		return 1
	fi
	policy_id="$(jq -r '.policy_id' "${policy_file}")"
	policy_sha="$(sha256sum "${policy_file}" | cut -d' ' -f1)"
	jq -cn \
		--arg policy_id "${policy_id}" \
		--arg policy_sha256 "${policy_sha}" \
		--arg signer_subject_id "${signer_subject_id}" \
		'{result: "accepted", policy_id: $policy_id, policy_sha256: $policy_sha256, signer_subject_id: $signer_subject_id}'
}

verified_payload_validate() {
	local envelope_file="$1"
	local payload_root="$2"
	local expected_integrity actual_integrity manifest_path manifest_sha
	local payload_dir entry_count index entry_path entry_sha entry_bytes

	[ -f "${envelope_file}" ] || {
		starter_contract_error "verified payload envelope is not a file"
		return 1
	}
	[ -d "${payload_root}" ] || {
		starter_contract_error "verified payload root is not a directory"
		return 1
	}
	jq -e --arg schema "$(jq -r '.properties.schema.const' "${STARTER_VERIFIED_PAYLOAD_SCHEMA}")" \
		'.schema == $schema' "${envelope_file}" >/dev/null || {
		starter_contract_error "unsupported verified payload schema"
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
		exact_keys(["schema", "source", "release", "immutable_identities", "manifest", "payload", "verification", "evidence", "integrity"]) and
		(.source | type == "object" and exact_keys(["adapter_id", "source_id"]) and (.adapter_id | adapter_id) and (.source_id | sha256_id)) and
		(.release | type == "object" and exact_keys(["id", "version", "predecessor_id"]) and (.id | sha256_id) and
			(.version | type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")) and
			(.predecessor_id == null or (.predecessor_id | sha256_id))) and
		(.immutable_identities | type == "array" and length == 2 and
			all(type == "object" and exact_keys(["role", "id"]) and (.role == "release" or .role == "content") and (.id | sha256_id)) and
			(map(.role) | sort) == ["content", "release"]) and
		(.manifest | type == "object" and exact_keys(["schema", "path", "sha256"]) and
			.schema == "starter-manifest/v1" and (.path | relative_path) and (.sha256 | sha256)) and
		(.payload | type == "object" and exact_keys(["root", "entries"]) and (.root | relative_path) and
			(.entries | type == "array" and length > 0 and
				all(type == "object" and exact_keys(["path", "sha256", "bytes"]) and
					(.path | relative_path) and (.sha256 | sha256) and (.bytes | type == "number" and . >= 0 and floor == .)) and
				(map(.path) as $paths | ($paths | length) == ($paths | unique | length)))) and
		(.verification | type == "object" and exact_keys(["result", "policy_id", "policy_sha256", "signer_subject_id"]) and
			.result == "accepted" and (.policy_id | type == "string" and length > 0) and
			(.policy_sha256 | sha256) and (.signer_subject_id | type == "string" and length > 0)) and
		(.evidence | type == "object" and exact_keys(["adapter_id", "ref", "sha256"]) and
			(.adapter_id | adapter_id) and (.ref | type == "string" and length > 0) and (.sha256 | sha256)) and
		(.integrity | type == "object" and exact_keys(["canonicalization", "envelope_sha256"]) and
			.canonicalization == "jq-sorted-utf8-v1" and (.envelope_sha256 | sha256))
	' "${envelope_file}" >/dev/null || {
		starter_contract_error "invalid verified payload envelope"
		return 1
	}

	expected_integrity="$(jq -r '.integrity.envelope_sha256' "${envelope_file}")"
	actual_integrity="$(jq -cS 'del(.integrity)' "${envelope_file}" | sha256sum | cut -d' ' -f1)"
	[ "${actual_integrity}" = "${expected_integrity}" ] || {
		starter_contract_error "verified payload envelope digest mismatch"
		return 1
	}

	manifest_path="$(starter_path_existing_file_beneath "${payload_root}" "$(jq -r '.manifest.path' "${envelope_file}")")" || {
		starter_contract_error "verified manifest is missing"
		return 1
	}
	manifest_sha="$(jq -r '.manifest.sha256' "${envelope_file}")"
	[ "$(sha256sum "${manifest_path}" | cut -d' ' -f1)" = "${manifest_sha}" ] || {
		starter_contract_error "verified manifest digest mismatch"
		return 1
	}

	payload_dir="$(starter_path_existing_directory_beneath "${payload_root}" "$(jq -r '.payload.root' "${envelope_file}")")" || {
		starter_contract_error "verified payload directory is unsafe"
		return 1
	}
	entry_count="$(jq '.payload.entries | length' "${envelope_file}")"
	for ((index = 0; index < entry_count; index++)); do
		entry_path="$(starter_path_existing_file_beneath "${payload_dir}" "$(jq -r ".payload.entries[${index}].path" "${envelope_file}")")" || {
			starter_contract_error "verified payload entry is missing or unsafe"
			return 1
		}
		entry_sha="$(jq -r ".payload.entries[${index}].sha256" "${envelope_file}")"
		entry_bytes="$(jq -r ".payload.entries[${index}].bytes" "${envelope_file}")"
		[ "$(sha256sum "${entry_path}" | cut -d' ' -f1)" = "${entry_sha}" ] || {
			starter_contract_error "verified payload entry digest mismatch"
			return 1
		}
		[ "$(wc -c <"${entry_path}")" -eq "${entry_bytes}" ] || {
			starter_contract_error "verified payload entry size mismatch"
			return 1
		}
	done
}
