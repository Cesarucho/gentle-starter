#!/usr/bin/env bats

load ../helpers/apt-fixture.bash
load ../helpers/argv-assertions.bash

setup() {
    setup_apt_fixture "${BATS_TEST_TMPDIR}/node"
    mkdir -p "${APT_FIXTURE_ROOT}/install/available" "${APT_FIXTURE_ROOT}/install/lib"
    INSTALLER="${APT_FIXTURE_ROOT}/install/available/2000-runtime-node.sh"
    cp "${BATS_TEST_DIRNAME}/../../install/available/2000-runtime-node.sh" "$INSTALLER"
    cmp "${BATS_TEST_DIRNAME}/../../install/available/2000-runtime-node.sh" "$INSTALLER"
    CONSUMER="${APT_FIXTURE_ROOT}/install/lib/common.sh"
    cp "${BATS_TEST_DIRNAME}/../helpers/apt-node-consumer.bash" "$CONSUMER"
}

@test "Node consumer rejects URL arguments and unordered or malformed APT requests" {
    local request
    for request in 'curl -fsSL https://deb.nodesource.com/setup_22.x' \
        'curl -fsSL https://deb.nodesource.com/setup_24.x extra' \
        'apt-get update' 'apt-get install -y --no-install-recommends nodejs' \
        'apt-get install -y --no-install-recommends other'; do
        printf '%s\n' "$request" >"${APT_FIXTURE_ROOT}/probe"
        run_node_fixture "${APT_FIXTURE_ROOT}/probe"
        [ "$status" -eq 98 ]
        [ ! -e "${APT_FIXTURE_ROOT}/installed" ]
    done
}

@test "Node fixture has no external command or root shell PATH fallback" {
    local command
    for command in bash curl node npm apt-get sudo docker python3; do
        # Functions are intentional adapters; executable lookup bypasses them.
        printf 'type -P %s\n' "$command" >"${APT_FIXTURE_ROOT}/probe"
        run_node_fixture "${APT_FIXTURE_ROOT}/probe"
        if [[ "$command" = apt-get || "$command" = sudo ]]; then
            [ "$status" -eq 0 ]
            [[ "$output" = "${APT_FIXTURE_ROOT}/bin/"* ]]
        else
            [ "$status" -eq 1 ]
        fi
    done
}

@test "Node installs using locked major exact bootstrap and APT argv without running payload" {
    run_node_fixture "$INSTALLER"
    [ "$status" -eq 0 ]
    assert_recorded_argv "${APT_FIXTURE_ROOT}/curl-args" -fsSL https://deb.nodesource.com/setup_24.x
    assert_recorded_argv "${APT_FIXTURE_ROOT}/bootstrap-args" bash -
    assert_recorded_argv "${APT_FIXTURE_ROOT}/npm-args" --version
    assert_recorded_argv "${APT_FIXTURE_CALLS}/1" install -y --no-install-recommends nodejs
    [ ! -e "${APT_FIXTURE_CALLS}/2" ]
    [ -e "${APT_FIXTURE_ROOT}/bootstrapped" ]
    [ -e "${APT_FIXTURE_ROOT}/installed" ]
    [ ! -e "${APT_FIXTURE_ROOT}/download-executed" ]
    [[ "$output" = *'node v24.1.0, npm 10.1.0' ]]
}

@test "Node reuses matching and mismatched existing majors without bootstrap or npm" {
    local version
    for version in v24.1.0 v18.0.0; do
        EXISTING=1 NODE_VERSION="$version" run_node_fixture "$INSTALLER"
        [ "$status" -eq 0 ]
        [ "$output" = "node already installed: $version" ]
        [ ! -e "${APT_FIXTURE_ROOT}/curl-args" ]
        [ ! -e "${APT_FIXTURE_ROOT}/npm-args" ]
        [ ! -e "${APT_FIXTURE_CALLS}/1" ]
    done
}

@test "Node npm adapter appends raw arguments before availability and failure checks" {
    printf 'npm --version\n' >"${APT_FIXTURE_ROOT}/probe"
    run_node_fixture "${APT_FIXTURE_ROOT}/probe"
    [ "$status" -eq 127 ]
    assert_recorded_argv "${APT_FIXTURE_ROOT}/npm-args" --version
    : >"${APT_FIXTURE_ROOT}/installed"
    NPM_FAILURE=43 run_node_fixture "${APT_FIXTURE_ROOT}/probe"
    [ "$status" -eq 43 ]
    assert_recorded_argv "${APT_FIXTURE_ROOT}/npm-args" --version --version
}

@test "Node policy loading failure precedes reuse and bootstrap" {
    EXISTING=1 POLICY_FAILURE=44 run_node_fixture "$INSTALLER"
    [ "$status" -eq 44 ]
    [ ! -e "${APT_FIXTURE_ROOT}/curl-args" ]
    [ ! -e "${APT_FIXTURE_CALLS}/1" ]
}

@test "Node bootstrap failure prevents APT and downloaded code execution" {
    BOOTSTRAP_FAILURE=41 run_node_fixture "$INSTALLER"
    [ "$status" -eq 41 ]
    [ ! -e "${APT_FIXTURE_CALLS}/1" ]
    [ ! -e "${APT_FIXTURE_ROOT}/download-executed" ]
}

@test "Node curl failure stops APT even when pipeline consumer rejects empty input" {
    CURL_FAILURE=45 run_node_fixture "$INSTALLER"
    [ "$status" -eq 98 ]
    [ ! -e "${APT_FIXTURE_CALLS}/1" ]
    [ ! -e "${APT_FIXTURE_ROOT}/installed" ]
}

@test "Node APT failure propagates without final success logging" {
    INSTALL_FAILURE=42 run_node_fixture "$INSTALLER"
    [ "$status" -eq 42 ]
    assert_recorded_argv "${APT_FIXTURE_CALLS}/1" install -y --no-install-recommends nodejs
    [ ! -e "${APT_FIXTURE_ROOT}/installed" ]
    [[ "$output" != *'npm 10.1.0'* ]]
}

@test "Node swallows failed and missing final Node and npm version probes" {
    NODE_FAILURE=43 NPM_FAILURE=127 run_node_fixture "$INSTALLER"
    [ "$status" -eq 0 ]
    [[ "$output" = *'node , npm ' ]]
    printf 'node --version\n' >"${APT_FIXTURE_ROOT}/probe"
    NODE_FAILURE=43 run_node_fixture "${APT_FIXTURE_ROOT}/probe"
    [ "$status" -eq 43 ]
    printf 'npm --version\n' >"${APT_FIXTURE_ROOT}/probe"
    NPM_FAILURE=127 run_node_fixture "${APT_FIXTURE_ROOT}/probe"
    [ "$status" -eq 127 ]
}

@test "Node reuse also swallows a failed version probe" {
    EXISTING=1 NODE_FAILURE=43 run_node_fixture "$INSTALLER"
    [ "$status" -eq 0 ]
    [ "$output" = 'node already installed: ' ]
    [ ! -e "${APT_FIXTURE_CALLS}/1" ]
}

@test "Node final probes independently swallow missing Node and failing npm" {
    NODE_FAILURE=127 NPM_FAILURE=43 run_node_fixture "$INSTALLER"
    [ "$status" -eq 0 ]
    [[ "$output" = *'node , npm ' ]]
    printf 'node --version\n' >"${APT_FIXTURE_ROOT}/probe"
    NODE_FAILURE=127 run_node_fixture "${APT_FIXTURE_ROOT}/probe"
    [ "$status" -eq 127 ]
    printf 'npm --version\n' >"${APT_FIXTURE_ROOT}/probe"
    NPM_FAILURE=43 run_node_fixture "${APT_FIXTURE_ROOT}/probe"
    [ "$status" -eq 43 ]
}

run_node_fixture() {
    run_apt_fixture "$1" "$CONSUMER" LOCK_VALUE="${LOCK_VALUE-24}" \
        POLICY_FAILURE="${POLICY_FAILURE:-0}" EXISTING="${EXISTING:-0}" \
        NODE_VERSION="${NODE_VERSION:-v24.1.0}" CURL_FAILURE="${CURL_FAILURE:-0}" \
        BOOTSTRAP_FAILURE="${BOOTSTRAP_FAILURE:-0}" INSTALL_FAILURE="${INSTALL_FAILURE:-0}" \
        NODE_FAILURE="${NODE_FAILURE:-0}" NPM_FAILURE="${NPM_FAILURE:-0}"
}

@test "Node consumer rejects root command vectors before any execution" {
    local request
    for request in 'devcontainer_run_as_root bash -c true' \
        'devcontainer_run_as_root sudo apt-get install nodejs' \
        'devcontainer_run_as_root /bin/bash -' 'devcontainer_run_as_root'; do
        printf '%s\n' "$request" >"${APT_FIXTURE_ROOT}/probe"
        run_node_fixture "${APT_FIXTURE_ROOT}/probe"
        [ "$status" -eq 98 ]
        [ ! -e "${APT_FIXTURE_ROOT}/installed" ]
    done
}
