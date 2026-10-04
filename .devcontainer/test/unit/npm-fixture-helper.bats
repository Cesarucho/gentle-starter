#!/usr/bin/env bats

load ../helpers/npm-fixture.bash

setup() {
    setup_npm_fixture "${BATS_TEST_TMPDIR}/npm sandbox"
    INSTALLER="${NPM_FIXTURE_ROOT}/installer"
    CONSUMER_ENV="${NPM_FIXTURE_ROOT}/consumer-env"
    printf 'source "$NPM_FIXTURE_RUNTIME"\n' >"${CONSUMER_ENV}"
    printf 'npm "$@"\n' >"${INSTALLER}"
}

@test "npm fixture preserves multiline results and exact raw argv" {
    printf 'npm_fixture_dispatch() { printf "first\\nsecond\\n"; }\n' >>"${CONSUMER_ENV}"
    printf 'npm npm install "package with spaces" ""\n' >"${INSTALLER}"
    run_npm_fixture "${INSTALLER}" "${CONSUMER_ENV}"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = first ]
    [ "${lines[1]}" = second ]
    local argv
    mapfile -d '' -t argv <"${NPM_FIXTURE_CALLS}/1"
    [ "${#argv[@]}" -eq 4 ]
    [ "${argv[0]}" = npm ]
    [ "${argv[1]}" = install ]
    [ "${argv[2]}" = 'package with spaces' ]
    [ "${argv[3]}" = '' ]
}

@test "npm fixture propagates rejection and fails closed without a dispatcher" {
    run_npm_fixture "${INSTALLER}" "${CONSUMER_ENV}"
    [ "$status" -eq 93 ]
    printf 'npm_fixture_dispatch() { printf "rejected\\n"; return 42; }\n' >>"${CONSUMER_ENV}"
    run_npm_fixture "${INSTALLER}" "${CONSUMER_ENV}"
    [ "$status" -eq 42 ]
    [ "$output" = rejected ]
    [ -f "${NPM_FIXTURE_CALLS}/2" ]
}

@test "npm fixture isolates ambient variables and keeps explicit overrides" {
    export NPM_AMBIENT=leaked
    printf 'printf "%%s\\n" "$HOME" "$TMPDIR" "${NPM_AMBIENT-unset}" "$EXPLICIT"\n' >"${INSTALLER}"
    run_npm_fixture "${INSTALLER}" "${CONSUMER_ENV}" EXPLICIT='value with spaces'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "${NPM_FIXTURE_ROOT}/home" ]
    [ "${lines[1]}" = "${NPM_FIXTURE_ROOT}/tmp" ]
    [ "${lines[2]}" = unset ]
    [ "${lines[3]}" = 'value with spaces' ]
    [ "$NPM_AMBIENT" = leaked ]
}

@test "npm fixture rejects isolation overrides and roots outside Bats temporary scope" {
    local assignment
    for assignment in HOME=/tmp PATH=/usr/bin BASH_ENV=/tmp/env NPM_FIXTURE_ROOT=/tmp TMPDIR=/tmp; do
        run run_npm_fixture "${INSTALLER}" "${CONSUMER_ENV}" "$assignment"
        [ "$status" -ne 0 ]
    done
    run setup_npm_fixture /tmp/outside-npm-fixture
    [ "$status" -ne 0 ]
}

@test "npm fixture separates roots and blocks executable npm fallback" {
    run_npm_fixture "${INSTALLER}" /dev/null
    [ "$status" -eq 93 ]
    local first_calls="${NPM_FIXTURE_CALLS}"
    setup_npm_fixture "${BATS_TEST_TMPDIR}/second"
    [ "$NPM_FIXTURE_CALLS" != "$first_calls" ]
    [ ! -e "${NPM_FIXTURE_CALLS}/1" ]
}
