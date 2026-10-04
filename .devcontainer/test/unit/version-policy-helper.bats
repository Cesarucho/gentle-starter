#!/usr/bin/env bats

load ../helpers/version-policy.bash

setup() {
    INSTALLER="${BATS_TEST_TMPDIR}/installer with spaces.sh"
    POLICY="${BATS_TEST_TMPDIR}/policy with spaces.conf"
    printf '%s\n' 'fixture policy' >"${POLICY}"
    cat >"${INSTALLER}" <<'EOF'
#!/usr/bin/env bash
[ "$#" -eq 1 ] && [ "$1" = --print-version-policy ] || exit 64
[ -f "${DEVCONTAINER_TOOL_VERSIONS_FILE}" ] || exit 65
printf 'POLICY=%s\n' "${DEVCONTAINER_TOOL_VERSIONS_FILE}"
printf 'VALUE=%s\n' "${POLICY_PROBE_VALUE-unset}"
exit "${POLICY_PROBE_EXIT:-0}"
EOF
}

@test "policy probe invokes only print mode with explicit paths containing spaces" {
    run_version_policy "${INSTALLER}" "${POLICY}" -u POLICY_PROBE_VALUE -u POLICY_PROBE_EXIT

    [ "$status" -eq 0 ]
    [ "$output" = "POLICY=${POLICY}"$'\n''VALUE=unset' ]
}

@test "policy probe preserves multiline output and Bats lines" {
    run_version_policy "${INSTALLER}" "${POLICY}" -u POLICY_PROBE_EXIT POLICY_PROBE_VALUE=central

    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[0]}" = "POLICY=${POLICY}" ]
    [ "${lines[1]}" = VALUE=central ]
}

@test "policy probe preserves nonzero installer status and output" {
    run_version_policy "${INSTALLER}" "${POLICY}" -u POLICY_PROBE_VALUE POLICY_PROBE_EXIT=42

    [ "$status" -eq 42 ]
    [ "$output" = "POLICY=${POLICY}"$'\n''VALUE=unset' ]
}

@test "policy probe unsets caller-selected ambient values without changing the caller" {
    export POLICY_PROBE_VALUE=ambient
    run_version_policy "${INSTALLER}" "${POLICY}" -u POLICY_PROBE_VALUE -u POLICY_PROBE_EXIT

    [ "$status" -eq 0 ]
    [ "${lines[1]}" = VALUE=unset ]
    [ "$POLICY_PROBE_VALUE" = ambient ]
}

@test "policy probe forwards explicit overrides and keeps its explicit policy authoritative" {
    export POLICY_PROBE_VALUE=ambient
    export DEVCONTAINER_TOOL_VERSIONS_FILE="${BATS_TEST_TMPDIR}/missing.conf"
    run_version_policy "${INSTALLER}" "${POLICY}" -u POLICY_PROBE_EXIT \
        POLICY_PROBE_VALUE='override with spaces' DEVCONTAINER_TOOL_VERSIONS_FILE=ignored

    [ "$status" -eq 0 ]
    [ "$output" = "POLICY=${POLICY}"$'\n''VALUE=override with spaces' ]
    [ "$POLICY_PROBE_VALUE" = ambient ]
    [ "$DEVCONTAINER_TOOL_VERSIONS_FILE" = "${BATS_TEST_TMPDIR}/missing.conf" ]
}
