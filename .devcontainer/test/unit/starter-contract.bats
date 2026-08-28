#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	CONTRACT="${REPO_ROOT}/.taskfiles/scripts/starter-lib/contracts/source-port.sh"
	TRUST_POLICY="${REPO_ROOT}/.starter/trust/policy.json"
	TRUST_KEY="${REPO_ROOT}/.starter/trust/release-key.asc"
	TRUST_FIXTURE="${BATS_TEST_DIRNAME}/../fixtures/starter-trust/policy.json"
	TEST_ROOT="$(mktemp -d)"
	PAYLOAD_ROOT="${TEST_ROOT}/candidate"
	mkdir -p "${PAYLOAD_ROOT}"
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

snapshot_tree() {
	find "$1" -mindepth 1 -printf '%P %y %s\n' | sort
}

seal_envelope() {
	local envelope="$1"
	local canonical digest
	canonical="$(jq -cS 'del(.integrity)' "${envelope}")"
	digest="$(printf '%s\n' "${canonical}" | sha256sum | cut -d' ' -f1)"
	jq --arg digest "${digest}" \
		'.integrity = {canonicalization: "jq-sorted-utf8-v1", envelope_sha256: $digest}' \
		"${envelope}" >"${envelope}.sealed"
	mv "${envelope}.sealed" "${envelope}"
}

write_valid_payload() {
	local envelope="$1"
	local manifest_sha payload_sha payload_bytes
	mkdir -p "${PAYLOAD_ROOT}/payloads/config"
	printf '%s\n' '{"schema":"starter-manifest/v1","operations":[]}' >"${PAYLOAD_ROOT}/manifest.json"
	printf '%s\n' 'managed=true' >"${PAYLOAD_ROOT}/payloads/config/starter.conf"
	manifest_sha="$(sha256sum "${PAYLOAD_ROOT}/manifest.json" | cut -d' ' -f1)"
	payload_sha="$(sha256sum "${PAYLOAD_ROOT}/payloads/config/starter.conf" | cut -d' ' -f1)"
	payload_bytes="$(wc -c <"${PAYLOAD_ROOT}/payloads/config/starter.conf")"

	jq -n \
		--arg manifest_sha "${manifest_sha}" \
		--arg payload_sha "${payload_sha}" \
		--argjson payload_bytes "${payload_bytes}" \
		'{
			schema: "gentle-starter.verified-payload/v1",
			source: {adapter_id: "FixtureSource/v1", source_id: ("sha256:" + ("1" * 64))},
			release: {id: ("sha256:" + ("2" * 64)), version: "1.2.3", predecessor_id: null},
			immutable_identities: [
				{role: "release", id: ("sha256:" + ("2" * 64))},
				{role: "content", id: ("sha256:" + ("3" * 64))}
			],
			manifest: {schema: "starter-manifest/v1", path: "manifest.json", sha256: $manifest_sha},
			payload: {
				root: "payloads",
				entries: [{path: "config/starter.conf", sha256: $payload_sha, bytes: $payload_bytes}]
			},
			verification: {
				result: "accepted",
				policy_id: "starter-release-signers/v1",
				policy_sha256: ("4" * 64),
				signer_subject_id: ("openpgp:" + ("A" * 40))
			},
			evidence: {
				adapter_id: "FixtureSource/v1",
				ref: "fixture-evidence:release-1.2.3",
				sha256: ("5" * 64)
			}
		}' >"${envelope}"
	seal_envelope "${envelope}"
}

@test "verified payload rejects an unknown schema without writes" {
	local envelope="${TEST_ROOT}/unknown-schema.json"
	local before after
	printf '%s\n' '{"schema":"gentle-starter.verified-payload/v2"}' >"${envelope}"
	before="$(snapshot_tree "${PAYLOAD_ROOT}")"

	run bash -c "source '${CONTRACT}'; verified_payload_validate '${envelope}' '${PAYLOAD_ROOT}'"

	[ "$status" -ne 0 ]
	[[ "$output" == *"unsupported verified payload schema"* ]]
	after="$(snapshot_tree "${PAYLOAD_ROOT}")"
	[ "${after}" = "${before}" ]
}

@test "verified payload rejects Git-shaped core fields without writes" {
	local envelope="${TEST_ROOT}/git-shaped.json"
	local before after
	write_valid_payload "${envelope}"
	jq '.git = {tag_oid: "0123456789abcdef"}' "${envelope}" >"${envelope}.tmp"
	mv "${envelope}.tmp" "${envelope}"
	seal_envelope "${envelope}"
	before="$(snapshot_tree "${PAYLOAD_ROOT}")"

	run bash -c "source '${CONTRACT}'; verified_payload_validate '${envelope}' '${PAYLOAD_ROOT}'"

	[ "$status" -ne 0 ]
	[[ "$output" == *"invalid verified payload envelope"* ]]
	after="$(snapshot_tree "${PAYLOAD_ROOT}")"
	[ "${after}" = "${before}" ]
}

@test "verified payload accepts neutral identities and validates materialized bytes" {
	local envelope="${TEST_ROOT}/valid.json"
	write_valid_payload "${envelope}"

	run bash -c "source '${CONTRACT}'; verified_payload_validate '${envelope}' '${PAYLOAD_ROOT}'"
	[ "$status" -eq 0 ]

	printf '%s\n' 'tampered=true' >"${PAYLOAD_ROOT}/payloads/config/starter.conf"
	run bash -c "source '${CONTRACT}'; verified_payload_validate '${envelope}' '${PAYLOAD_ROOT}'"
	[ "$status" -ne 0 ]
	[[ "$output" == *"verified payload entry digest mismatch"* ]]
}

@test "missing GPG fails preflight without writes" {
	local empty_path="${TEST_ROOT}/empty-path"
	local before after
	mkdir -p "${empty_path}"
	printf '%s\n' 'preserve' >"${PAYLOAD_ROOT}/SENTINEL"
	before="$(snapshot_tree "${PAYLOAD_ROOT}")"

	run bash -c "source '${CONTRACT}'; PATH='${empty_path}'; starter_require_command gpg"

	[ "$status" -ne 0 ]
	[[ "$output" == *"required command unavailable: gpg"* ]]
	after="$(snapshot_tree "${PAYLOAD_ROOT}")"
	[ "${after}" = "${before}" ]
}

@test "source acquisition port returns only a validated neutral result" {
	local envelope="${TEST_ROOT}/source-result.json"
	local request="${TEST_ROOT}/request.json"
	write_valid_payload "${envelope}"
	printf '%s\n' '{"release_version":"1.2.3"}' >"${request}"

	run bash -c "
		source '${CONTRACT}'
		fixture_source_acquire() {
			jq -n --arg envelope_file '${envelope}' --arg payload_root '${PAYLOAD_ROOT}' \
				'{envelope_file: \$envelope_file, payload_root: \$payload_root}'
		}
		STARTER_SOURCE_ACQUIRE_IMPL=fixture_source_acquire source_acquire '${request}'
	"

	[ "$status" -eq 0 ]
	[ "$(jq -r '.envelope_file' <<<"${output}")" = "${envelope}" ]
	[ "$(jq -r '.payload_root' <<<"${output}")" = "${PAYLOAD_ROOT}" ]
	[ "$(jq 'keys | length' <<<"${output}")" -eq 2 ]
}

@test "signer policy accepts the pinned release key" {
	local fingerprint
	fingerprint="$(gpg --batch --show-keys --with-colons "${TRUST_KEY}" 2>/dev/null | awk -F: '$1 == "fpr" { print $10; exit }')"

	run bash -c "source '${CONTRACT}'; signer_policy_evaluate '${TRUST_POLICY}' 'openpgp:${fingerprint}' 1.0.0"

	[ "$status" -eq 0 ]
	[ "$(jq -r '.result' <<<"${output}")" = "accepted" ]
	[ "$(jq -r '.policy_id' <<<"${output}")" = "starter-release-signers/v1" ]
	[ "$(jq -r '.signer_subject_id' <<<"${output}")" != "openpgp:" ]
}

@test "signer policy rejects an unpinned signer" {
	run bash -c "source '${CONTRACT}'; signer_policy_evaluate '${TRUST_FIXTURE}' 'openpgp:9999999999999999999999999999999999999999' 1.4.0"

	[ "$status" -ne 0 ]
	[[ "$output" == *"signer is not pinned by policy"* ]]
	[[ "$output" != *"Could not open file"* ]]
}

@test "signer policy rejects a revoked signer at and after revocation" {
	local revoked="openpgp:3333333333333333333333333333333333333333"

	run bash -c "source '${CONTRACT}'; signer_policy_evaluate '${TRUST_FIXTURE}' '${revoked}' 1.4.9"
	[ "$status" -eq 0 ]

	run bash -c "source '${CONTRACT}'; signer_policy_evaluate '${TRUST_FIXTURE}' '${revoked}' 1.5.0"
	[ "$status" -ne 0 ]
	[[ "$output" == *"signer is revoked for release version 1.5.0"* ]]
}

@test "signer rotation enforces the version boundary deterministically" {
	local previous="openpgp:1111111111111111111111111111111111111111"
	local rotated="openpgp:2222222222222222222222222222222222222222"

	run bash -c "source '${CONTRACT}'; signer_policy_evaluate '${TRUST_FIXTURE}' '${previous}' 1.9.9"
	[ "$status" -eq 0 ]
	run bash -c "source '${CONTRACT}'; signer_policy_evaluate '${TRUST_FIXTURE}' '${previous}' 2.0.0"
	[ "$status" -ne 0 ]
	[[ "$output" == *"signer is outside its allowed release window"* ]]

	run bash -c "source '${CONTRACT}'; signer_policy_evaluate '${TRUST_FIXTURE}' '${rotated}' 1.9.9"
	[ "$status" -ne 0 ]
	[[ "$output" == *"signer is outside its allowed release window"* ]]
	run bash -c "source '${CONTRACT}'; signer_policy_evaluate '${TRUST_FIXTURE}' '${rotated}' 2.0.0"
	[ "$status" -eq 0 ]
}
