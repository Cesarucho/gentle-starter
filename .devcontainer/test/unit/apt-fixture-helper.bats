#!/usr/bin/env bats

load ../helpers/apt-fixture.bash

setup() {
    setup_apt_fixture "${BATS_TEST_TMPDIR}/apt sandbox"
    INSTALLER="${APT_FIXTURE_ROOT}/installer"
    CONSUMER_ENV="${APT_FIXTURE_ROOT}/consumer-env"
    printf 'source "$APT_FIXTURE_RUNTIME"\n' >"$CONSUMER_ENV"
    printf 'apt-get update\n' >"$INSTALLER"
}

@test "APT fixture records serial raw arguments including empty and multiline values" {
    printf 'apt_fixture_dispatch() { printf "first\\nsecond\\n"; }\n' >>"$CONSUMER_ENV"
    printf 'apt-get install "package with spaces" "" $\x27line\\nbreak\x27\napt-get update\n' >"$INSTALLER"
    run_apt_fixture "$INSTALLER" "$CONSUMER_ENV"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = first ]
    [ "${lines[1]}" = second ]
    local argv
    mapfile -d '' -t argv <"${APT_FIXTURE_CALLS}/1"
    [ "${#argv[@]}" -eq 4 ]
    [ "${argv[0]}" = install ]
    [ "${argv[1]}" = 'package with spaces' ]
    [ "${argv[2]}" = '' ]
    [ "${argv[3]}" = $'line\nbreak' ]
    mapfile -d '' -t argv <"${APT_FIXTURE_CALLS}/2"
    [ "${#argv[@]}" -eq 1 ]
    [ "${argv[0]}" = update ]
    [ ! -e "${APT_FIXTURE_CALLS}/3" ]
}

@test "APT fixture distinguishes zero arguments from one empty argument" {
    printf 'apt_fixture_dispatch() { printf "%%s\\n" "$#"; }\n' >>"$CONSUMER_ENV"
    printf 'apt-get\napt-get ""\n' >"$INSTALLER"
    run_apt_fixture "$INSTALLER" "$CONSUMER_ENV"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[0]}" = 0 ]
    [ "${lines[1]}" = 1 ]
    [ -f "${APT_FIXTURE_CALLS}/1" ]
    [ ! -s "${APT_FIXTURE_CALLS}/1" ]
    local argv
    mapfile -d '' -t argv <"${APT_FIXTURE_CALLS}/1"
    [ "${#argv[@]}" -eq 0 ]
    printf '\0' >"${APT_FIXTURE_ROOT}/expected-empty-argument"
    cmp "${APT_FIXTURE_ROOT}/expected-empty-argument" "${APT_FIXTURE_CALLS}/2"
    mapfile -d '' -t argv <"${APT_FIXTURE_CALLS}/2"
    [ "${#argv[@]}" -eq 1 ]
    [ "${argv[0]}" = '' ]
    [ ! -e "${APT_FIXTURE_CALLS}/3" ]
}

@test "APT fixture fails closed without dispatch and propagates rejection with errexit" {
    run_apt_fixture "$INSTALLER" "$CONSUMER_ENV"
    [ "$status" -eq 93 ]
    printf 'apt_fixture_dispatch() { return 42; }\n' >>"$CONSUMER_ENV"
    printf 'set -e\napt-get unexpected\nprintf forbidden\n' >"$INSTALLER"
    run_apt_fixture "$INSTALLER" "$CONSUMER_ENV"
    [ "$status" -eq 42 ]
    [ -z "$output" ]
    [ -e "${APT_FIXTURE_CALLS}/2" ]
}

@test "APT fixture sanitizes ambient state while preserving explicit values" {
    export APT_AMBIENT=leaked
    printf 'printf "%%s\\n" "$HOME" "$TMPDIR" "${APT_AMBIENT-unset}" "$EXPLICIT" "$PATH"\n' >"$INSTALLER"
    run_apt_fixture "$INSTALLER" "$CONSUMER_ENV" EXPLICIT='value with spaces'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "${APT_FIXTURE_ROOT}/home" ]
    [ "${lines[1]}" = "${APT_FIXTURE_ROOT}/tmp" ]
    [ "${lines[2]}" = unset ]
    [ "${lines[3]}" = 'value with spaces' ]
    [ "${lines[4]}" = "${APT_FIXTURE_ROOT}/bin" ]
    [ "$APT_AMBIENT" = leaked ]
}

@test "APT fixture rejects reserved malformed environment and unsafe roots" {
    local assignment
    for assignment in HOME=/tmp TMPDIR=/tmp PATH=/bin BASH_ENV=/tmp ENV=/tmp \
        SHELLOPTS=x BASHOPTS=x APT_FIXTURE_CALLS=/tmp 'invalid-key=value' 'no-equals'; do
        run run_apt_fixture "$INSTALLER" "$CONSUMER_ENV" "$assignment"
        [ "$status" -ne 0 ]
        [ ! -e "${APT_FIXTURE_CALLS}/1" ]
    done
    run setup_apt_fixture /tmp/outside-apt-fixture
    [ "$status" -ne 0 ]
    run setup_apt_fixture "${BATS_TEST_TMPDIR}/../escape"
    [ "$status" -ne 0 ]
}

@test "APT fixture blocks executable fallback and ambient package and tool commands" {
    run_apt_fixture "$INSTALLER" /dev/null
    [ "$status" -eq 93 ]
    printf 'sudo apt-get update\n' >"$INSTALLER"
    run_apt_fixture "$INSTALLER" /dev/null
    [ "$status" -eq 93 ]
    local command_name
    for command_name in apt dot ansible curl; do
        printf '%s --version\n' "$command_name" >"$INSTALLER"
        run_apt_fixture "$INSTALLER" /dev/null
        [ "$status" -eq 127 ]
    done
    [ ! -e "${APT_FIXTURE_CALLS}/1" ]
}

@test "APT fixture keeps captures isolated across separate roots" {
    printf 'apt_fixture_dispatch() { return 0; }\n' >>"$CONSUMER_ENV"
    run_apt_fixture "$INSTALLER" "$CONSUMER_ENV"
    [ "$status" -eq 0 ]
    local first_calls="$APT_FIXTURE_CALLS"
    setup_apt_fixture "${BATS_TEST_TMPDIR}/second"
    [ "$APT_FIXTURE_CALLS" != "$first_calls" ]
    [ ! -e "${APT_FIXTURE_CALLS}/1" ]
    [ -e "${first_calls}/1" ]
}
