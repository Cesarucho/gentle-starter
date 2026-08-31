#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	COMPATIBILITY="${REPO_ROOT}/.taskfiles/scripts/starter-lib/contracts/yq-compatibility.sh"
	TEST_ROOT="$(mktemp -d)"
	REAL_YQ="$(command -v yq)"
	MIKE_YQ="${MIKE_YQ:-}"
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
	[[ "${output}" == *'"keep": "value"'* ]]
	[[ "${output}" != *"release:"* ]]
}

@test "uses Mike Farah v4 JSON output and strenv syntax" {
	write_fake_yq 'printf "%s\n" "$*" >>"$YQ_CALLS"; case "${1:-}" in --version) echo "yq (https://github.com/mikefarah/yq/) version v4.44.3";; -e) exit 0;; -r) echo ./Dockerfile;; -o=json) echo "{\"tasks\":{}}";; esac'

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
	grep -Fq -- '-o=json -I=0 del(.tasks.release)' "${TEST_ROOT}/calls"
	grep -Fq -- 'strenv(SERVICE)' "${TEST_ROOT}/calls"
	[ "$(stat -c '%a' "${TEST_ROOT}/input.yml")" = 644 ]
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
	write_fake_yq 'case "${1:-}" in --version) echo "yq (https://github.com/mikefarah/yq/) version v4.44.3";; -o=json) echo "{\"tasks\":{}}";; esac'
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
	write_fake_yq 'if [ "${1:-}" = --version ]; then echo "yq (https://github.com/mikefarah/yq/) version v4.44.3"; exit; fi; if [ "${1:-}" = -o=json ]; then shift 2; fi; exec "$REAL_YQ" -c "$@"'
	local destination="${TEST_ROOT}/derived"

	run env PATH="${TEST_ROOT}/bin:${PATH}" REAL_YQ="${REAL_YQ}" bash -c 'source "$1"; starter_derived_transform "$2" "$3"' \
		_ "${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/derived-tree.sh" "${REPO_ROOT}" "${destination}"

	[ "${status}" -eq 0 ]
	run "${REAL_YQ}" -e '.tasks.release or .tasks.prepare-release' "${destination}/.taskfiles/starter.yml"
	[ "${status}" -ne 0 ]
}

@test "real supported dialects produce byte-identical canonical derived files and identity" {
	[ -x "${MIKE_YQ}" ] || skip "MIKE_YQ does not name a real Mike Farah v4 binary"
	local kislyuk_bin="${TEST_ROOT}/kislyuk-bin" mike_bin="${TEST_ROOT}/mike-bin"
	local kislyuk_tree="${TEST_ROOT}/derived-kislyuk" mike_tree="${TEST_ROOT}/derived-mike"
	mkdir -p "${kislyuk_bin}" "${mike_bin}"
	ln -s "${REAL_YQ}" "${kislyuk_bin}/yq"
	ln -s "${MIKE_YQ}" "${mike_bin}/yq"

	run env PATH="${kislyuk_bin}:${PATH}" bash -c 'source "$1"; starter_derived_transform "$2" "$3"' \
		_ "${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/derived-tree.sh" "${REPO_ROOT}" "${kislyuk_tree}"
	[ "${status}" -eq 0 ]
	run env PATH="${mike_bin}:${PATH}" bash -c 'source "$1"; starter_derived_transform "$2" "$3"' \
		_ "${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/derived-tree.sh" "${REPO_ROOT}" "${mike_tree}"
	[ "${status}" -eq 0 ]

	cmp "${kislyuk_tree}/.taskfiles/starter.yml" "${mike_tree}/.taskfiles/starter.yml"
	cmp "${kislyuk_tree}/Taskfile.yml" "${mike_tree}/Taskfile.yml"
	source "${REPO_ROOT}/.taskfiles/scripts/starter-lib/core/derived-tree.sh"
	[ "$(starter_derived_identity "${kislyuk_tree}")" = "$(starter_derived_identity "${mike_tree}")" ]
	task --dir "${kislyuk_tree}" --list >/dev/null
	task --dir "${mike_tree}" --list >/dev/null
}
