#!/usr/bin/env bats

load ../helpers/apt-fixture.bash

prepare_installer() {
    local tool="$1" source_installer
    case "$tool" in
        graphviz)
            source_installer=5020-cli-graphviz.sh
            CLI=dot PACKAGE=graphviz PACKAGE_ENV=GRAPHVIZ_PACKAGE
            ;;
        ansible)
            source_installer=6000-cli-ansible.sh
            CLI=ansible PACKAGE=ansible-core PACKAGE_ENV=ANSIBLE_PACKAGE
            ;;
        *) return 1 ;;
    esac
    FIXTURE_NUMBER=$((${FIXTURE_NUMBER:-0} + 1))
    setup_apt_fixture "${BATS_TEST_TMPDIR}/${tool}-${FIXTURE_NUMBER}"
    mkdir -p "${APT_FIXTURE_ROOT}/install/available" "${APT_FIXTURE_ROOT}/install/lib"
    INSTALLER="${APT_FIXTURE_ROOT}/install/available/${source_installer}"
    cp "${BATS_TEST_DIRNAME}/../../install/available/${source_installer}" "$INSTALLER"
    cmp "${BATS_TEST_DIRNAME}/../../install/available/${source_installer}" "$INSTALLER"
    CONSUMER_ENV="${APT_FIXTURE_ROOT}/install/lib/common.sh"
    cat >"$CONSUMER_ENV" <<'STUBS'
source "$APT_FIXTURE_RUNTIME"
devcontainer_has_cmd() {
    [ "$#" -eq 1 ] && [ "$1" = "$CLI" ] || return 95
    [ -x "${APT_FIXTURE_ROOT}/bin/${CLI}" ]
}
devcontainer_log_info() { printf '%s\n' "$*"; }
devcontainer_log_error() { printf '%s\n' "$*" >&2; }
devcontainer_run_as_root() {
    [ "$#" -ge 1 ] && [ "$1" = apt-get ] || return 95
    shift
    apt-get "$@"
}
create_fixture_cli() {
    # Only this fixture-local mode change bypasses the closed command PATH.
    printf '%s\n' '#!/bin/bash' 'source "$CLI_SCRIPT"' >"${APT_FIXTURE_ROOT}/bin/${CLI}"
    /usr/bin/chmod +x "${APT_FIXTURE_ROOT}/bin/${CLI}"
}
apt_fixture_dispatch() {
    if [ "$#" -eq 1 ] && [ "$1" = update ]; then
        [ ! -e "${APT_FIXTURE_ROOT}/updated" ] || return 98
        [ "$UPDATE_FAILURE" -eq 0 ] || return "$UPDATE_FAILURE"
        : >"${APT_FIXTURE_ROOT}/updated"
        return 0
    fi
    [ "$#" -eq 4 ] && [ "$1" = install ] && [ "$2" = -y ] &&
        [ "$3" = --no-install-recommends ] && [ "$4" = "$PACKAGE" ] || return 98
    [ -e "${APT_FIXTURE_ROOT}/updated" ] || return 98
    [ "$INSTALL_FAILURE" -eq 0 ] || return "$INSTALL_FAILURE"
    [ "$OMIT_CLI" = 0 ] || return 0
    create_fixture_cli
}
STUBS
    CLI_SCRIPT="${APT_FIXTURE_ROOT}/cli-script"
    cat >"$CLI_SCRIPT" <<'CLI'
printf '%s\0' "$@" >"${APT_FIXTURE_ROOT}/cli-probe"
[ "$#" -eq 1 ] || exit 97
case "$CLI" in
    dot)
        [ "$1" = -V ] || exit 97
        printf 'fixture Graphviz version\n' >&2
        ;;
    ansible)
        [ "$1" = --version ] || exit 97
        printf 'fixture Ansible version\nsecond version detail\n'
        ;;
    *) exit 97 ;;
esac
exit "$PROBE_FAILURE"
CLI
}

create_existing_cli() {
    printf '%s\n' '#!/bin/bash' 'source "$CLI_SCRIPT"' >"${APT_FIXTURE_ROOT}/bin/${CLI}"
    chmod +x "${APT_FIXTURE_ROOT}/bin/${CLI}"
}

run_installer() {
    local -a overrides=()
    if [ "${CUSTOM_PACKAGE:-0}" = 1 ]; then
        overrides+=("${PACKAGE_ENV}=${PACKAGE}")
    fi
    run_apt_fixture "$INSTALLER" "$CONSUMER_ENV" \
        CLI="$CLI" CLI_SCRIPT="$CLI_SCRIPT" PACKAGE="$PACKAGE" \
        UPDATE_FAILURE="${UPDATE_FAILURE:-0}" INSTALL_FAILURE="${INSTALL_FAILURE:-0}" \
        OMIT_CLI="${OMIT_CLI:-0}" PROBE_FAILURE="${PROBE_FAILURE:-0}" "${overrides[@]}"
}

assert_request() {
    local file="$1" index
    shift
    local -a actual expected=("$@")
    mapfile -d '' -t actual <"$file"
    [ "${#actual[@]}" -eq "${#expected[@]}" ]
    for ((index=0; index<${#expected[@]}; index++)); do
        [ "${actual[index]}" = "${expected[index]}" ]
    done
}

assert_install_requests() {
    assert_request "${APT_FIXTURE_CALLS}/1" update
    assert_request "${APT_FIXTURE_CALLS}/2" install -y --no-install-recommends "$PACKAGE"
    [ ! -e "${APT_FIXTURE_CALLS}/3" ]
}

assert_probe_and_log() {
    if [ "$CLI" = dot ]; then
        assert_request "${APT_FIXTURE_ROOT}/cli-probe" -V
        [[ "$output" == *'Graphviz '*'installed: fixture Graphviz version'* ]]
    else
        assert_request "${APT_FIXTURE_ROOT}/cli-probe" --version
        [[ "$output" == *'ansible '*'installed: fixture Ansible version'* ]]
        [[ "$output" != *'second version detail'* ]]
    fi
}

@test "APT installers reuse fixture CLIs with exact distinct probes and zero APT calls" {
    local tool before
    for tool in graphviz ansible; do
        prepare_installer "$tool"
        create_existing_cli
        before="$(sha256sum "${APT_FIXTURE_ROOT}/bin/${CLI}")"
        run_installer
        [ "$status" -eq 0 ]
        assert_probe_and_log
        [[ "$output" == *'already installed:'* ]]
        [ ! -e "${APT_FIXTURE_CALLS}/1" ]
        [ "$before" = "$(sha256sum "${APT_FIXTURE_ROOT}/bin/${CLI}")" ]
    done
}

@test "APT installers install default packages after exact ordered update requests" {
    local tool
    for tool in graphviz ansible; do
        prepare_installer "$tool"
        run_installer
        [ "$status" -eq 0 ]
        assert_install_requests
        assert_probe_and_log
    done
}

@test "APT installers preserve a custom package as one exact argument" {
    local tool
    for tool in graphviz ansible; do
        prepare_installer "$tool"
        PACKAGE=$'custom package\nwith detail'
        CUSTOM_PACKAGE=1 run_installer
        [ "$status" -eq 0 ]
        assert_install_requests
        assert_probe_and_log
    done
}

@test "APT update failures propagate and prevent installation probes and success" {
    local tool
    for tool in graphviz ansible; do
        prepare_installer "$tool"
        UPDATE_FAILURE=41 run_installer
        [ "$status" -eq 41 ]
        assert_request "${APT_FIXTURE_CALLS}/1" update
        [ ! -e "${APT_FIXTURE_CALLS}/2" ]
        [ ! -e "${APT_FIXTURE_ROOT}/bin/${CLI}" ]
        [ ! -e "${APT_FIXTURE_ROOT}/cli-probe" ]
        [[ "$output" != *'installed:'* ]]
    done
}

@test "APT install failures propagate without CLI probes or success" {
    local tool
    for tool in graphviz ansible; do
        prepare_installer "$tool"
        INSTALL_FAILURE=42 run_installer
        [ "$status" -eq 42 ]
        assert_install_requests
        [ ! -e "${APT_FIXTURE_ROOT}/bin/${CLI}" ]
        [ ! -e "${APT_FIXTURE_ROOT}/cli-probe" ]
        [[ "$output" != *'installed:'* ]]
    done
}

@test "APT success without a CLI exits one and never claims installation success" {
    local tool
    for tool in graphviz ansible; do
        prepare_installer "$tool"
        OMIT_CLI=1 run_installer
        [ "$status" -eq 1 ]
        assert_install_requests
        [[ "$output" == *'not on PATH'* ]]
        [[ "$output" != *'installed:'* ]]
        [ ! -e "${APT_FIXTURE_ROOT}/cli-probe" ]
    done
}

@test "APT installer logging swallows failed version probes on reuse and installation" {
    local tool mode
    for mode in reuse install; do
        for tool in graphviz ansible; do
            prepare_installer "$tool"
            if [ "$mode" = reuse ]; then create_existing_cli; fi
            PROBE_FAILURE=43 run_installer
            [ "$status" -eq 0 ]
            assert_probe_and_log
            if [ "$mode" = reuse ]; then
                [ ! -e "${APT_FIXTURE_CALLS}/1" ]
            else
                assert_install_requests
            fi
            # An independent direct probe proves that exit zero is logging, not health.
            local probe="${APT_FIXTURE_ROOT}/direct-probe"
            if [ "$CLI" = dot ]; then
                printf 'dot -V\n' >"$probe"
            else
                printf 'ansible --version\n' >"$probe"
            fi
            run_apt_fixture "$probe" /dev/null \
                CLI="$CLI" CLI_SCRIPT="$CLI_SCRIPT" PROBE_FAILURE=43
            [ "$status" -eq 43 ]
        done
    done
}

@test "APT consumer rejects unknown commands and unexpected argument vectors" {
    prepare_installer graphviz
    local request probe="${APT_FIXTURE_ROOT}/rejected-request"
    for request in 'devcontainer_run_as_root sudo apt-get update' \
        'devcontainer_run_as_root apt-get update extra' \
        'devcontainer_run_as_root apt-get install -y --no-install-recommends wrong' \
        'devcontainer_run_as_root apt-get install -y graphviz'; do
        printf '%s\n' "$request" >"$probe"
        run_apt_fixture "$probe" "$CONSUMER_ENV" PACKAGE=graphviz UPDATE_FAILURE=0
        if [[ "$request" == *'root sudo'* ]]; then
            [ "$status" -eq 95 ]
        else
            [ "$status" -eq 98 ]
        fi
        [ ! -e "${APT_FIXTURE_ROOT}/bin/dot" ]
    done
}

@test "APT consumer lookup and direct invocation cannot discover ambient CLIs" {
    local tool probe="${BATS_TEST_TMPDIR}/absent-cli"
    for tool in graphviz ansible; do
        prepare_installer "$tool"
        printf 'devcontainer_has_cmd "$CLI" && exit 96\n"$CLI" --version\n' >"$probe"
        run_apt_fixture "$probe" "$CONSUMER_ENV" CLI="$CLI"
        [ "$status" -eq 127 ]
        [ ! -e "${APT_FIXTURE_CALLS}/1" ]
    done
}
