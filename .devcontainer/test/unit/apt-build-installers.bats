#!/usr/bin/env bats

load ../helpers/apt-fixture.bash
load ../helpers/argv-assertions.bash

prepare_build_installer() {
    local tool="$1" filename
    case "$tool" in
        ssh) filename=4000-tool-ssh.sh; PACKAGE=openssh-client ;;
        pulse) filename=4100-tool-pulseaudio-utils.sh; PACKAGE=pulseaudio-utils ;;
        server) filename=4010-tool-ssh-server.sh; PACKAGE=openssh-server ;;
        *) return 1 ;;
    esac
    FIXTURE_NUMBER=$((${FIXTURE_NUMBER:-0} + 1))
    setup_apt_fixture "${BATS_TEST_TMPDIR}/${tool}-${FIXTURE_NUMBER}"
    mkdir -p "${APT_FIXTURE_ROOT}/install/available" "${APT_FIXTURE_ROOT}/install/lib"
    INSTALLER="${APT_FIXTURE_ROOT}/install/available/${filename}"
    cp "${BATS_TEST_DIRNAME}/../../install/available/${filename}" "$INSTALLER"
    cmp "${BATS_TEST_DIRNAME}/../../install/available/${filename}" "$INSTALLER"
    CONSUMER_ENV="${APT_FIXTURE_ROOT}/install/lib/common.sh"
    cp "${BATS_TEST_DIRNAME}/../helpers/apt-build-consumer.bash" "$CONSUMER_ENV"
}

run_build_probe() {
    local probe="${APT_FIXTURE_ROOT}/probe"
    printf '%s\n' "$1" >"$probe"
    run_apt_fixture "$probe" "$CONSUMER_ENV" PACKAGE="$PACKAGE" \
        DEVCONTAINER_PHASE=build UPDATE_FAILURE=0 INSTALL_FAILURE=0
}

@test "build consumer rejects unknown root commands and malformed requests" {
    local request
    for request in 'devcontainer_run_as_root sudo apt-get update -qq' \
        'devcontainer_run_as_root' 'apt-get update extra' \
        'apt-get update -qq extra' 'apt-get install -y -qq wrong' \
        'apt-get install -y --no-install-recommends openssh-client'; do
        prepare_build_installer ssh
        run_build_probe "$request"
        [ "$status" -eq 98 ]
        [ ! -e "${APT_FIXTURE_ROOT}/updated" ]
        [ ! -e "${APT_FIXTURE_ROOT}/installed" ]
    done
}

@test "build consumer rejects install before update and repeated update or install" {
    local request
    for request in 'apt-get install -y -qq openssh-client' \
        $'apt-get update -qq\napt-get update -qq' \
        $'apt-get update -qq\napt-get install -y -qq openssh-client\napt-get install -y -qq openssh-client'; do
        prepare_build_installer ssh
        run_build_probe "$request"
        [ "$status" -eq 98 ]
    done
}

@test "build consumer rejects phase arguments and runtime helper invocation" {
    local request
    for request in 'devcontainer_is_build extra' 'devcontainer_is_runtime' \
        'devcontainer_is_runtime extra'; do
        prepare_build_installer server
        run_build_probe "$request"
        [ "$status" -eq 98 ]
        [ ! -e "${APT_FIXTURE_CALLS}/1" ]
    done
}

run_build_installer() {
    run_apt_fixture "$INSTALLER" "$CONSUMER_ENV" PACKAGE="$PACKAGE" \
        DEVCONTAINER_PHASE="${PHASE:-build}" \
        UPDATE_FAILURE="${UPDATE_FAILURE:-0}" INSTALL_FAILURE="${INSTALL_FAILURE:-0}" \
        WORKSPACE_DIR="${APT_FIXTURE_ROOT}/workspace" \
        SSH_CONFIG_DIR="${APT_FIXTURE_ROOT}/keys" \
        SSH_START_WRAPPER_TARGET="${APT_FIXTURE_ROOT}/start-sshd" \
        SSHD_CONFIG_TARGET="${APT_FIXTURE_ROOT}/sshd_config"
}

assert_build_requests() {
    assert_recorded_argv "${APT_FIXTURE_CALLS}/1" update -qq
    assert_recorded_argv "${APT_FIXTURE_CALLS}/2" install -y -qq "$PACKAGE"
    [ ! -e "${APT_FIXTURE_CALLS}/3" ]
}

assert_no_server_runtime() {
    [ ! -e "${APT_FIXTURE_ROOT}/runtime-request" ]
    [ ! -e "${APT_FIXTURE_ROOT}/keys" ]
    [ ! -e "${APT_FIXTURE_ROOT}/start-sshd" ]
    [ ! -e "${APT_FIXTURE_ROOT}/sshd_config" ]
    [ ! -e "${APT_FIXTURE_ROOT}/home/.ssh" ]
    [[ "$output" != *'seeded'* ]]
}

@test "build installers issue exact ordered package requests without runtime work" {
    local tool
    for tool in ssh pulse server; do
        prepare_build_installer "$tool"
        run_build_installer
        [ "$status" -eq 0 ]
        assert_build_requests
        [ -e "${APT_FIXTURE_ROOT}/installed" ]
        assert_no_server_runtime
        if [ "$tool" = server ]; then
            [ "$output" = $'Installing openssh-server\nopenssh-server installed' ]
        else
            [ -z "$output" ]
        fi
    done
}

@test "build update failure propagates and stops install without false success" {
    local tool
    for tool in ssh pulse server; do
        prepare_build_installer "$tool"
        UPDATE_FAILURE=41 run_build_installer
        [ "$status" -eq 41 ]
        assert_recorded_argv "${APT_FIXTURE_CALLS}/1" update -qq
        [ ! -e "${APT_FIXTURE_CALLS}/2" ]
        [ ! -e "${APT_FIXTURE_ROOT}/updated" ]
        [ ! -e "${APT_FIXTURE_ROOT}/installed" ]
        [[ "$output" != *'openssh-server installed'* ]]
        assert_no_server_runtime
    done
}

@test "build install failure propagates without false success or runtime work" {
    local tool
    for tool in ssh pulse server; do
        prepare_build_installer "$tool"
        INSTALL_FAILURE=42 run_build_installer
        [ "$status" -eq 42 ]
        assert_build_requests
        [ ! -e "${APT_FIXTURE_ROOT}/installed" ]
        [[ "$output" != *'openssh-server installed'* ]]
        assert_no_server_runtime
    done
}

@test "SSH client and PulseAudio runtime are silent zero-call noops" {
    local tool
    for tool in ssh pulse; do
        prepare_build_installer "$tool"
        PHASE=runtime run_build_installer
        [ "$status" -eq 0 ]
        [ -z "$output" ]
        [ ! -e "${APT_FIXTURE_CALLS}/1" ]
        [ ! -e "${APT_FIXTURE_ROOT}/updated" ]
        [ ! -e "${APT_FIXTURE_ROOT}/installed" ]
        assert_no_server_runtime
    done
}

@test "build fixture cannot discover ambient runtime or tool CLIs" {
    local command
    for command in ssh sshd ssh-keygen paplay pactl python3 mkdir chmod install id stat curl docker; do
        prepare_build_installer server
        run_build_probe "command -v $command"
        [ "$status" -eq 1 ]
        run_build_probe "$command --version"
        [ "$status" -eq 127 ]
        [ ! -e "${APT_FIXTURE_CALLS}/1" ]
    done
}
