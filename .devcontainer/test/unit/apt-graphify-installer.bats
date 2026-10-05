#!/usr/bin/env bats

load ../helpers/apt-fixture.bash
load ../helpers/argv-assertions.bash

setup() {
    setup_apt_fixture "${BATS_TEST_TMPDIR}/graphify"
    mkdir -p "${APT_FIXTURE_ROOT}/install/available" "${APT_FIXTURE_ROOT}/install/lib"
    INSTALLER="${APT_FIXTURE_ROOT}/install/available/2400-python-graphify.sh"
    cp "${BATS_TEST_DIRNAME}/../../install/available/2400-python-graphify.sh" "$INSTALLER"
    cmp "${BATS_TEST_DIRNAME}/../../install/available/2400-python-graphify.sh" "$INSTALLER"
    CONSUMER="${APT_FIXTURE_ROOT}/install/lib/common.sh"
    cp "${BATS_TEST_DIRNAME}/../helpers/apt-graphify-consumer.bash" "$CONSUMER"
    mkdir "${APT_FIXTURE_ROOT}/synthetic"
}

run_graphify_fixture() {
    run_apt_fixture "$1" "$CONSUMER" GRAPHIFY_INSTALL_DIR="${APT_FIXTURE_ROOT}/venv" \
        GRAPHIFY_BIN_DIR="${APT_FIXTURE_ROOT}/prefix" FAIL_STAGE="${FAIL_STAGE:-0}" \
        POLICY_STATUS="${POLICY_STATUS:-0}" MISSING_LOCK="${MISSING_LOCK:-0}" \
        PYTHON_PRESENT="${PYTHON_PRESENT:-1}" PYTHON_STATUS="${PYTHON_STATUS:-0}" \
        PYTHON_VERSION_STATUS="${PYTHON_VERSION_STATUS:-0}" CLI_STATUS="${CLI_STATUS:-0}" \
        EXISTING_GRAPHIFY="${EXISTING_GRAPHIFY:-0}" EXISTING_MCP="${EXISTING_MCP:-0}" \
        POST_MISSING="${POST_MISSING:-none}" "${@:2}"
}

reset_graphify_calls() {
    rm -f "${APT_FIXTURE_ROOT}"/root-* "${APT_FIXTURE_ROOT}"/stage-* \
        "${APT_FIXTURE_ROOT}"/{python-probes,cli-probes} "${APT_FIXTURE_CALLS}"/*
    rm -f "${APT_FIXTURE_ROOT}/synthetic/graphify" "${APT_FIXTURE_ROOT}/synthetic/graphify-mcp"
}

assert_graphify_install() {
    local directory=$1 prefix=$2 version=$3
    [ "$status" -eq 0 ]
    assert_recorded_argv "${APT_FIXTURE_CALLS}/1" update
    assert_recorded_argv "${APT_FIXTURE_CALLS}/2" install -y --no-install-recommends python3-venv
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-1" apt-get update
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-2" apt-get install -y --no-install-recommends python3-venv
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-3" rm -rf "$directory"
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-4" python3 -m venv "$directory"
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-5" "$directory/bin/pip" install --no-cache-dir "graphifyy==$version"
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-6" ln -sfn "$directory/bin/graphify" "$prefix/graphify"
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-7" ln -sfn "$directory/bin/graphify-mcp" "$prefix/graphify-mcp"
    [ ! -e "${APT_FIXTURE_ROOT}/root-8" ]
    [ ! -e "${APT_FIXTURE_CALLS}/3" ]
    [ -x "$APT_FIXTURE_ROOT/synthetic/graphify" ]
    [ -x "$APT_FIXTURE_ROOT/synthetic/graphify-mcp" ]
    [[ "$output" = *'Graphify installed: Graphify fixture'* ]]
}

@test "Graphify exact ordered install has one pip request and two inert link requests" {
    run_graphify_fixture "$INSTALLER"
    assert_graphify_install "$APT_FIXTURE_ROOT/venv" "$APT_FIXTURE_ROOT/prefix" 0.9.5
    assert_recorded_argv "${APT_FIXTURE_ROOT}/python-probes" -c 'import sys; raise SystemExit(sys.version_info < (3, 10))'
    assert_recorded_argv "${APT_FIXTURE_ROOT}/cli-probes" --version
}

@test "Graphify controls version environment and prefix but not distribution or APT package" {
    run_graphify_fixture "$INSTALLER" GRAPHIFY_VERSION=2.3.4 \
        GRAPHIFY_INSTALL_DIR="$APT_FIXTURE_ROOT/custom-venv" GRAPHIFY_BIN_DIR="$APT_FIXTURE_ROOT/custom-prefix" \
        GRAPHIFY_PACKAGE=ignored
    assert_graphify_install "$APT_FIXTURE_ROOT/custom-venv" "$APT_FIXTURE_ROOT/custom-prefix" 2.3.4
}

@test "Graphify both CLI reuse precedes Python and ignores version mismatch" {
    EXISTING_GRAPHIFY=1 EXISTING_MCP=1 PYTHON_PRESENT=0 run_graphify_fixture "$INSTALLER" GRAPHIFY_VERSION=99.0
    [ "$status" -eq 0 ]
    [ "$output" = 'Graphify and Graphify MCP already installed: Graphify fixture' ]
    [ ! -e "$APT_FIXTURE_ROOT/python-probes" ]
    [ ! -e "$APT_FIXTURE_ROOT/root-1" ]
}

@test "Graphify either CLI alone does not skip installation" {
    EXISTING_GRAPHIFY=1 run_graphify_fixture "$INSTALLER"
    assert_graphify_install "$APT_FIXTURE_ROOT/venv" "$APT_FIXTURE_ROOT/prefix" 0.9.5
    reset_graphify_calls
    EXISTING_MCP=1 run_graphify_fixture "$INSTALLER"
    assert_graphify_install "$APT_FIXTURE_ROOT/venv" "$APT_FIXTURE_ROOT/prefix" 0.9.5
}

@test "Graphify Python absence and minimum version errors fail before root requests" {
    PYTHON_PRESENT=0 run_graphify_fixture "$INSTALLER"
    [ "$status" -eq 1 ]
    [ ! -e "$APT_FIXTURE_ROOT/python-probes" ]
    local failure
    for failure in 1 53 127; do
        PYTHON_STATUS="$failure" PYTHON_VERSION_STATUS=54 run_graphify_fixture "$INSTALLER"
        [ "$status" -eq 1 ]
        [[ "$output" = *'requires Python 3.10 or newer'* ]]
        [ ! -e "$APT_FIXTURE_ROOT/root-1" ]
        [ ! -e "$APT_FIXTURE_CALLS/1" ]
        reset_graphify_calls
    done
}

@test "Graphify policy errors precede reuse while explicit version permits absent lock" {
    POLICY_STATUS=51 EXISTING_GRAPHIFY=1 EXISTING_MCP=1 run_graphify_fixture "$INSTALLER"
    [ "$status" -eq 51 ]
    MISSING_LOCK=1 EXISTING_GRAPHIFY=1 EXISTING_MCP=1 run_graphify_fixture "$INSTALLER"
    [ "$status" -eq 1 ]
    [[ "$output" = *'missing LOCK_GRAPHIFY_VERSION'* ]]
    [ ! -e "$APT_FIXTURE_ROOT/cli-probes" ]
    printf 'exec /bin/bash "%s" --print-version-policy\n' "$INSTALLER" >"$APT_FIXTURE_ROOT/probe"
    MISSING_LOCK=1 run_graphify_fixture "$APT_FIXTURE_ROOT/probe" GRAPHIFY_VERSION=2.0
    [ "$status" -eq 0 ]
    [ "$output" = 'GRAPHIFY_VERSION=2.0' ]
    [ ! -e "$APT_FIXTURE_ROOT/root-1" ]
}

@test "Graphify every root failure preserves status and stops later mutations without rollback" {
    local stage
    for stage in 1 2 3 4 5 6 7; do
        FAIL_STAGE="$stage" run_graphify_fixture "$INSTALLER"
        [ "$status" -eq "$((40+stage))" ]
        [ -e "$APT_FIXTURE_ROOT/root-$stage" ]
        [ ! -e "$APT_FIXTURE_ROOT/root-$((stage+1))" ]
        [ ! -e "$APT_FIXTURE_ROOT/stage-$stage" ]
        if [ "$stage" -gt 1 ]; then
            [ -e "$APT_FIXTURE_ROOT/stage-$((stage-1))" ]
        fi
        [ ! -e "$APT_FIXTURE_ROOT/cli-probes" ]
        [[ "$output" != *'Graphify installed:'* ]]
        reset_graphify_calls
    done
}

@test "Graphify missing either synthetic postinstall CLI fails after both link requests" {
    local command
    for command in graphify graphify-mcp; do
        POST_MISSING="$command" run_graphify_fixture "$INSTALLER"
        [ "$status" -eq 1 ]
        [[ "$output" = *'expected commands not on PATH'* ]]
        [ ! -x "$APT_FIXTURE_ROOT/synthetic/$command" ]
        [ -e "$APT_FIXTURE_ROOT/stage-7" ]
        [ ! -e "$APT_FIXTURE_ROOT/root-8" ]
        [ ! -e "$APT_FIXTURE_ROOT/cli-probes" ]
        reset_graphify_calls
    done
}

@test "Graphify logging swallows CLI probe errors on reuse and install with direct proof" {
    local failure existing
    for failure in 53 127; do
        for existing in 0 1; do
            CLI_STATUS="$failure" EXISTING_GRAPHIFY="$existing" EXISTING_MCP="$existing" run_graphify_fixture "$INSTALLER"
            [ "$status" -eq 0 ]
            printf 'graphify --version\n' >"$APT_FIXTURE_ROOT/probe"
            CLI_STATUS="$failure" run_graphify_fixture "$APT_FIXTURE_ROOT/probe"
            [ "$status" -eq "$failure" ]
            reset_graphify_calls
        done
    done
}

@test "Graphify rejects altered vectors paths commands ordering and ambient executables" {
    local request
    for request in 'devcontainer_run_as_root /usr/bin/python3 -m venv /opt/graphify' \
        'devcontainer_run_as_root apt-get update -qq' \
        'devcontainer_run_as_root apt-get install -y --no-install-recommends python3-venv' \
        'GRAPHIFY_STAGE=2; devcontainer_run_as_root rm -rf /opt/graphify' \
        'GRAPHIFY_STAGE=3; devcontainer_run_as_root python3 -m venv /tmp/other' \
        'GRAPHIFY_STAGE=4; devcontainer_run_as_root "$GRAPHIFY_INSTALL_DIR/bin/pip" install --upgrade pip' \
        'GRAPHIFY_STAGE=5; devcontainer_run_as_root ln -sfn /tmp/other /usr/local/bin/graphify' \
        'GRAPHIFY_STAGE=6; devcontainer_run_as_root ln -sfn "$GRAPHIFY_INSTALL_DIR/bin/graphify-mcp" "$GRAPHIFY_BIN_DIR/graphify-mcp" extra' \
        'python3 -m venv /tmp/other' 'graphify install' 'devcontainer_has_cmd pip'; do
        printf '%s\n' "$request" >"$APT_FIXTURE_ROOT/probe"
        run_graphify_fixture "$APT_FIXTURE_ROOT/probe" GRAPHIFY_VERSION=0.9.5
        [ "$status" -eq 98 ]
        [ ! -e "$APT_FIXTURE_ROOT/root-1" ]
        [ ! -e "$APT_FIXTURE_ROOT/root-3" ]
        [ ! -e "$APT_FIXTURE_ROOT/root-5" ]
        [ ! -e "$APT_FIXTURE_ROOT/root-6" ]
        [ ! -e "$APT_FIXTURE_ROOT/root-7" ]
    done
    for request in python3 pip graphify graphify-mcp rm ln curl docker bash; do
        printf 'type -P %s\n' "$request" >"$APT_FIXTURE_ROOT/probe"
        run_graphify_fixture "$APT_FIXTURE_ROOT/probe"
        [ "$status" -eq 1 ]
    done
}

@test "Graphify rejects destructive traversal before capture or mutation" {
    printf 'devcontainer_run_as_root rm -rf "%s/venv/../../outside"\n' "$APT_FIXTURE_ROOT" >"${APT_FIXTURE_ROOT}/probe"
    run_graphify_fixture "${APT_FIXTURE_ROOT}/probe"
    [ "$status" -eq 98 ]
    [ ! -e "${APT_FIXTURE_ROOT}/root-1" ]
}

@test "Graphify unsafe configured directories reject before APT requests" {
    local directory
    for directory in /opt/graphify "$APT_FIXTURE_ROOT/venv/../../outside" "$APT_FIXTURE_ROOT/venv/../venv"; do
        run_graphify_fixture "$INSTALLER" GRAPHIFY_INSTALL_DIR="$directory"
        [ "$status" -eq 98 ]
        [ ! -e "$APT_FIXTURE_ROOT/root-1" ]
        [ ! -e "$APT_FIXTURE_CALLS/1" ]
    done
    run_graphify_fixture "$INSTALLER" GRAPHIFY_BIN_DIR=/usr/local/bin
    [ "$status" -eq 98 ]
    [ ! -e "$APT_FIXTURE_ROOT/root-1" ]
}

@test "Graphify rejects synthetic executable symlinks without changing their fixture target" {
    printf 'preserve\n' >"$APT_FIXTURE_ROOT/sentinel"
    ln -s "$APT_FIXTURE_ROOT/sentinel" "$APT_FIXTURE_ROOT/synthetic/graphify"
    run_graphify_fixture "$INSTALLER"
    [ "$status" -eq 98 ]
    [ "$(<"$APT_FIXTURE_ROOT/sentinel")" = preserve ]
    [ ! -e "$APT_FIXTURE_ROOT/root-1" ]
}
