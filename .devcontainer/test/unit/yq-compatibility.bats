#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	COMPATIBILITY="${REPO_ROOT}/.taskfiles/scripts/starter-lib/contracts/yq-compatibility.sh"
	TEST_ROOT="$(mktemp -d)"
	REAL_YQ="$(command -v yq)"
	cat >"${TEST_ROOT}/input.yml" <<'EOF'
tasks:
  keep: value
  release: remove
EOF
}

teardown() { rm -rf "${TEST_ROOT}"; }

write_fake_yq() {
	local body="$1"
	mkdir -p "${TEST_ROOT}/bin"
	cat >"${TEST_ROOT}/bin/yq" <<EOF
#!/usr/bin/env bash
${body}
EOF
	chmod +x "${TEST_ROOT}/bin/yq"
}

@test "detects and executes the installed Kislyuk dialect" {
	run bash -c 'source "$1"; yq_compatibility_detect; printf "%s\n" "$YQ_COMPATIBILITY_DIALECT"; yq_compatibility_yaml "del(.tasks.release)" "$2"' \
		_ "${COMPATIBILITY}" "${TEST_ROOT}/input.yml"

	[ "${status}" -eq 0 ]
	[[ "${output}" == kislyuk$'\n'* ]]
	[[ "${output}" == *"keep: value"* ]]
	[[ "${output}" != *"release:"* ]]
}

@test "uses Mike Farah v4 output, in-place, and strenv syntax" {
	write_fake_yq 'printf "%s\n" "$*" >>"$YQ_CALLS"; case "${1:-}" in --version) echo "yq (https://github.com/mikefarah/yq/) version v4.44.3";; -e) exit 0;; -r) echo ./Dockerfile;; -o=yaml) if [ "${2:-}" = -i ]; then exit 0; else echo "tasks: {}"; fi;; esac'

	run env PATH="${TEST_ROOT}/bin:${PATH}" YQ_CALLS="${TEST_ROOT}/calls" bash -c '
		source "$1"
		yq_compatibility_detect
		yq_compatibility_yaml "del(.tasks.release)" "$2" >/dev/null
		yq_compatibility_yaml_in_place "del(.tasks.release)" "$2"
		yq_compatibility_service_is_object app "$2"
		yq_compatibility_service_dockerfile app "$2" >/dev/null
		printf "%s\n" "$YQ_COMPATIBILITY_DIALECT"
	' _ "${COMPATIBILITY}" "${TEST_ROOT}/input.yml"

	[ "${status}" -eq 0 ]
	[ "${output}" = mike-farah-v4 ]
	grep -Fq -- '-o=yaml del(.tasks.release)' "${TEST_ROOT}/calls"
	grep -Fq -- '-o=yaml -i del(.tasks.release)' "${TEST_ROOT}/calls"
	grep -Fq -- 'strenv(SERVICE)' "${TEST_ROOT}/calls"
}

@test "rejects unsupported and missing yq with actionable errors" {
	write_fake_yq 'case "${1:-}" in --version) echo "unknown yq 1.0";; --help) echo "unknown implementation";; esac'
	run env PATH="${TEST_ROOT}/bin:${PATH}" bash -c 'source "$1"; yq_compatibility_detect' _ "${COMPATIBILITY}"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"unsupported yq implementation"* ]]
	[[ "${output}" == *"Mike Farah yq v4"* ]]

	rm "${TEST_ROOT}/bin/yq"
	run env PATH="${TEST_ROOT}/bin" /bin/bash -c 'source "$1"; yq_compatibility_detect' _ "${COMPATIBILITY}"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"yq is required"* ]]
}

@test "ignores inherited dialect values and derives the actual selected binary" {
	write_fake_yq 'case "${1:-}" in --version) echo "yq (https://github.com/mikefarah/yq/) version v4.44.3";; -o=yaml) echo "tasks: {}";; esac'
	run env PATH="${TEST_ROOT}/bin:${PATH}" YQ_COMPATIBILITY_DIALECT=invalid bash -c '
		source "$1"
		yq_compatibility_yaml "del(.tasks.release)" "$2" >/dev/null
		printf "%s\n" "$YQ_COMPATIBILITY_DIALECT"
	' _ "${COMPATIBILITY}" "${TEST_ROOT}/input.yml"
	[ "${status}" -eq 0 ]
	[ "${output}" = mike-farah-v4 ]

	write_fake_yq 'case "${1:-}" in --version) echo "unknown yq 1.0";; --help) echo "unknown implementation";; esac'
	run env PATH="${TEST_ROOT}/bin:${PATH}" YQ_COMPATIBILITY_DIALECT=kislyuk bash -c \
		'source "$1"; yq_compatibility_yaml "del(.tasks.release)" "$2"' \
		_ "${COMPATIBILITY}" "${TEST_ROOT}/input.yml"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"unsupported yq implementation"* ]]
}

@test "derived transformation runs through Mike Farah v4 syntax" {
	write_fake_yq 'if [ "${1:-}" = --version ]; then echo "yq (https://github.com/mikefarah/yq/) version v4.44.3"; exit; fi; if [ "${1:-}" = -o=yaml ]; then shift; fi; if [ "${1:-}" = -i ]; then exec "$REAL_YQ" -y -i "$@"; fi; exec "$REAL_YQ" -y "$@"'
	local destination="${TEST_ROOT}/derived"

	run env PATH="${TEST_ROOT}/bin:${PATH}" REAL_YQ="${REAL_YQ}" bash -c 'source "$1"; starter_derived_transform "$2" "$3"' \
		_ "${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/derived-tree.sh" "${REPO_ROOT}" "${destination}"

	[ "${status}" -eq 0 ]
	run "${REAL_YQ}" -e '.tasks.release or .tasks.prepare-release' "${destination}/.taskfiles/starter.yml"
	[ "${status}" -ne 0 ]
}
