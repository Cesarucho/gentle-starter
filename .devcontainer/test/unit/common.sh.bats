#!/usr/bin/env bats
#
# common.sh.bats — unit tests for .devcontainer/install/lib/common.sh
#
# Run from the repo root:
#   bats .devcontainer/test/unit/common.sh.bats
#

SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
COMMON_SH="${SCRIPT_DIR}/install/lib/common.sh"

# ---------------------------------------------------------------------------
# Setup and teardown
# ---------------------------------------------------------------------------

setup() {
    # Reset DEVCONTAINER_TOOL_VERSION before each test.
    export DEVCONTAINER_TOOL_VERSION=""
}

# ---------------------------------------------------------------------------
# Re-source guard
# ---------------------------------------------------------------------------

@test "re-source guard: sourcing twice returns 0" {
    run bash -c "source '${COMMON_SH}' && source '${COMMON_SH}' && echo 'ok'"
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

# ---------------------------------------------------------------------------
# Phase detection
# ---------------------------------------------------------------------------

@test "devcontainer_phase returns build when DEVCONTAINER_PHASE is unset" {
    run bash -c "source '${COMMON_SH}' && devcontainer_phase"
    [ "$status" -eq 0 ]
    [ "$output" = "build" ]
}

@test "devcontainer_phase returns runtime when DEVCONTAINER_PHASE=runtime" {
    run bash -c "source '${COMMON_SH}' && DEVCONTAINER_PHASE=runtime devcontainer_phase"
    [ "$status" -eq 0 ]
    [ "$output" = "runtime" ]
}

@test "devcontainer_is_build returns 0 when DEVCONTAINER_PHASE=build" {
    run bash -c "source '${COMMON_SH}' && DEVCONTAINER_PHASE=build devcontainer_is_build"
    [ "$status" -eq 0 ]
}

@test "devcontainer_is_build returns 1 when DEVCONTAINER_PHASE=runtime" {
    run bash -c "source '${COMMON_SH}' && DEVCONTAINER_PHASE=runtime devcontainer_is_build"
    [ "$status" -ne 0 ]
}

@test "devcontainer_is_runtime returns 0 when DEVCONTAINER_PHASE=runtime" {
    run bash -c "source '${COMMON_SH}' && DEVCONTAINER_PHASE=runtime devcontainer_is_runtime"
    [ "$status" -eq 0 ]
}

@test "devcontainer_is_runtime returns 1 when DEVCONTAINER_PHASE=build" {
    run bash -c "source '${COMMON_SH}' && DEVCONTAINER_PHASE=build devcontainer_is_runtime"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Command and path checks
# ---------------------------------------------------------------------------

@test "devcontainer_has_cmd returns 0 for existing command" {
    run bash -c "source '${COMMON_SH}' && devcontainer_has_cmd bash"
    [ "$status" -eq 0 ]
}

@test "devcontainer_has_cmd returns 1 for nonexistent command" {
    run bash -c "source '${COMMON_SH}' && devcontainer_has_cmd totallynonexistentcmd123"
    [ "$status" -ne 0 ]
}

@test "devcontainer_has_path returns 0 for existing path" {
    run bash -c "source '${COMMON_SH}' && devcontainer_has_path /tmp"
    [ "$status" -eq 0 ]
}

@test "devcontainer_has_path returns 1 for nonexistent path" {
    run bash -c "source '${COMMON_SH}' && devcontainer_has_path /tmp/this/does/not/exist/xyz789"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

@test "devcontainer_log_info writes to stdout with install:info prefix" {
    run bash -c "source '${COMMON_SH}' && devcontainer_log_info 'hello world'"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "[install:info] hello world" ]
}

@test "devcontainer_log_warn writes to stderr with install:warn prefix" {
    run bash -c "source '${COMMON_SH}' && devcontainer_log_warn 'warn message' 2>&1"
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "[install:warn] warn message" ]]
}

@test "devcontainer_log_error writes to stderr with install:error prefix" {
    run bash -c "source '${COMMON_SH}' && devcontainer_log_error 'error message' 2>&1"
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "[install:error] error message" ]]
}

# ---------------------------------------------------------------------------
# Fetching and integrity
# ---------------------------------------------------------------------------

@test "devcontainer_fetch downloads a file successfully" {
    run bash -c "source '${COMMON_SH}' && tmp=\$(mktemp) && devcontainer_fetch 'https://example.com' \"\${tmp}\" && rm -f \"\${tmp}\""
    [ "$status" -eq 0 ]
}

@test "devcontainer_fetch fails on invalid URL" {
    run bash -c "source '${COMMON_SH}' && tmp=\$(mktemp) && devcontainer_fetch 'https://this-domain-does-not-exist-xyz123.invalid/file' \"\${tmp}\"; r=\$?; rm -f \"\${tmp}\"; exit \${r}"
    [ "$status" -ne 0 ]
}

@test "devcontainer_verify_sha256 passes with correct hash" {
    run bash -c "source '${COMMON_SH}' && tmp=\$(mktemp) && echo -n 'hello' > \"\${tmp}\" && devcontainer_verify_sha256 \"\${tmp}\" '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824' && rm -f \"\${tmp}\""
    [ "$status" -eq 0 ]
}

@test "devcontainer_verify_sha256 fails with incorrect hash" {
    run bash -c "source '${COMMON_SH}' && tmp=\$(mktemp) && echo -n 'hello' > \"\${tmp}\" && devcontainer_verify_sha256 \"\${tmp}\" '0000000000000000000000000000000000000000000000000000000000000000'; r=\$?; rm -f \"\${tmp}\"; exit \${r}"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Version extraction
# ---------------------------------------------------------------------------

@test "_devcontainer_get_version extracts go version" {
    go() { echo "go version go1.22.3 linux/amd64"; }
    export -f go
    run bash -c "source '${COMMON_SH}' && _devcontainer_get_version go && echo \"\${DEVCONTAINER_TOOL_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "1.22.3" ]
}

@test "_devcontainer_get_version extracts node version with v prefix" {
    node() { echo "v20.5.0"; }
    export -f node
    run bash -c "source '${COMMON_SH}' && _devcontainer_get_version node && echo \"\${DEVCONTAINER_TOOL_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "20.5.0" ]
}

@test "_devcontainer_get_version extracts java-version style output (X.Y pattern)" {
    fake_java() { echo 'java version "21"'; }
    export -f fake_java
    run bash -c "source '${COMMON_SH}' && _devcontainer_get_version fake_java && printf '%s' \"\${DEVCONTAINER_TOOL_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "21" ]
}

@test "_devcontainer_get_version extracts generic X.Y.Z version" {
    fake() { echo "fake version 1.2.3-beta"; }
    export -f fake
    run bash -c "source '${COMMON_SH}' && _devcontainer_get_version fake && echo \"\${DEVCONTAINER_TOOL_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3" ]
}

@test "_devcontainer_get_version extracts generic X.Y version as fallback" {
    fake() { echo "tool v3.14"; }
    export -f fake
    run bash -c "source '${COMMON_SH}' && _devcontainer_get_version fake && echo \"\${DEVCONTAINER_TOOL_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "3.14" ]
}

@test "_devcontainer_get_version returns 1 for nonexistent command" {
    run bash -c "source '${COMMON_SH}' && _devcontainer_get_version totallynonexistentcmd456"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Version comparison
# ---------------------------------------------------------------------------

@test "_devcontainer_version_compare: 1.22.0 >= 1.20.0" {
    run bash -c "source '${COMMON_SH}' && _devcontainer_version_compare '1.22.0' '1.20.0'"
    [ "$status" -eq 0 ]
}

@test "_devcontainer_version_compare: 1.20.0 >= 1.22.0 is false" {
    run bash -c "source '${COMMON_SH}' && _devcontainer_version_compare '1.20.0' '1.22.0'"
    [ "$status" -ne 0 ]
}

@test "_devcontainer_version_compare: equal versions satisfy" {
    run bash -c "source '${COMMON_SH}' && _devcontainer_version_compare '1.20.0' '1.20.0'"
    [ "$status" -eq 0 ]
}

@test "_devcontainer_version_compare: 1.26.4 >= 99.0 is false (numeric 1.26 < 99)" {
    run bash -c "source '${COMMON_SH}' && _devcontainer_version_compare '1.26.4' '99.0'"
    [ "$status" -ne 0 ]
}

@test "_devcontainer_version_compare: 99.0 >= 1.26.4" {
    run bash -c "source '${COMMON_SH}' && _devcontainer_version_compare '99.0' '1.26.4'"
    [ "$status" -eq 0 ]
}

@test "_devcontainer_version_compare: 20.5.0 >= 20.0.0" {
    run bash -c "source '${COMMON_SH}' && _devcontainer_version_compare '20.5.0' '20.0.0'"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Idempotence helpers
# ---------------------------------------------------------------------------

@test "devcontainer_check_tool returns 0 for existing command without version" {
    run bash -c "source '${COMMON_SH}' && devcontainer_check_tool bash"
    [ "$status" -eq 0 ]
}

@test "devcontainer_check_tool returns 1 for nonexistent command" {
    run bash -c "source '${COMMON_SH}' && devcontainer_check_tool totallynonexistentcmd789"
    [ "$status" -ne 0 ]
}

@test "devcontainer_check_tool_with_version sets DEVCONTAINER_TOOL_VERSION" {
    fake_tool() { echo "fake-tool v3.14"; }
    export -f fake_tool
    run bash -c "source '${COMMON_SH}' && devcontainer_check_tool_with_version fake_tool 3.0 && printf '%s' \"\${DEVCONTAINER_TOOL_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "3.14" ]
}

@test "devcontainer_with_tool skips install when tool is sufficient" {
    fake_tool() { echo "fake-tool v9.0"; }
    export -f fake_tool
    run bash -c "source '${COMMON_SH}' && devcontainer_with_tool fake_tool 8.0 'echo INSTALLED'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipping fake_tool"* ]]
    [[ "$output" != *"INSTALLED"* ]]
}

@test "devcontainer_with_tool calls install_fn when tool is missing" {
    run bash -c "source '${COMMON_SH}' && devcontainer_with_tool totallynonexistentcmd999 1.0 'echo INSTALLED'"
    [ "$status" -eq 0 ]
    [[ "$output" == "INSTALLED" ]]
}

    @test "devcontainer_with_tool calls install_fn when version is insufficient" {
        fake_tool() { echo "fake-tool v0.1.0"; }
        export -f fake_tool
        run bash -c "source '${COMMON_SH}' && devcontainer_with_tool fake_tool 9.0 'echo INSTALLED'"
        [ "$status" -eq 0 ]
        [[ "$output" == "INSTALLED" ]]
    }