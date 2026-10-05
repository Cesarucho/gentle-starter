#!/usr/bin/env bats

load ../helpers/apt-fixture.bash
load ../helpers/argv-assertions.bash

setup() {
    setup_apt_fixture "${BATS_TEST_TMPDIR}/php-debug"
    mkdir -p "${APT_FIXTURE_ROOT}/install/available" "${APT_FIXTURE_ROOT}/install/lib"
    ORIGINAL="${BATS_TEST_DIRNAME}/../../install/available/2310-php-debug.sh"
    INSTALLER="${APT_FIXTURE_ROOT}/install/available/2310-php-debug.sh"
    CONSUMER="${APT_FIXTURE_ROOT}/install/lib/common.sh"
    cp "$ORIGINAL" "${APT_FIXTURE_ROOT}/original"
    cmp "$ORIGINAL" "${APT_FIXTURE_ROOT}/original"
    # Only the independently specified, complete assignment line may change.
    local line count=0
    while IFS= read -r line; do
        if [ "$line" = 'XDEBUG_INI="/etc/php/${PHP_VERSION}/mods-available/xdebug.ini"' ]; then
            printf '%s\n' 'XDEBUG_INI="${APT_FIXTURE_ROOT}/etc/php/${PHP_VERSION}/mods-available/xdebug.ini"'
            count=$((count+1))
        else
            printf '%s\n' "$line"
        fi
    done <"$ORIGINAL" >"$INSTALLER"
    [ "$count" -eq 1 ]
    count=0
    while IFS= read -r line; do
        if [ "$line" = 'XDEBUG_INI="${APT_FIXTURE_ROOT}/etc/php/${PHP_VERSION}/mods-available/xdebug.ini"' ]; then
            printf '%s\n' 'XDEBUG_INI="/etc/php/${PHP_VERSION}/mods-available/xdebug.ini"'
            count=$((count+1))
        else
            printf '%s\n' "$line"
        fi
    done <"$INSTALLER" >"${APT_FIXTURE_ROOT}/reconstructed"
    [ "$count" -eq 1 ]
    cmp "$ORIGINAL" "${APT_FIXTURE_ROOT}/reconstructed"
    cp "${BATS_TEST_DIRNAME}/../helpers/apt-php-debug-consumer.bash" "$CONSUMER"
}

teardown() {
    cmp "$ORIGINAL" "${APT_FIXTURE_ROOT}/original"
}

run_debug_fixture() {
    run_apt_fixture "$1" "$CONSUMER" PHP_PRESENT="${PHP_PRESENT:-1}" \
        MAJOR="${MAJOR:-8}" MINOR="${MINOR:-3}" FAIL_STAGE="${FAIL_STAGE:-0}" \
        LOADED="${LOADED:-0}" POST_LOADED="${POST_LOADED:-1}" \
        MAJOR_STATUS="${MAJOR_STATUS:-0}" MINOR_STATUS="${MINOR_STATUS:-0}" \
        MODULE_STATUS="${MODULE_STATUS:-0}" LOG_STATUS="${LOG_STATUS:-0}" "${@:2}"
}

@test "PHP debug rejects arbitrary root scripts before capture or execution" {
    printf 'devcontainer_run_as_root /bin/bash -c '\''touch "%s/hostile"'\''\n' "$APT_FIXTURE_ROOT" >"${APT_FIXTURE_ROOT}/probe"
    run_debug_fixture "${APT_FIXTURE_ROOT}/probe"
    [ "$status" -eq 98 ]
    [ ! -e "${APT_FIXTURE_ROOT}/hostile" ]
    [ ! -e "${APT_FIXTURE_ROOT}/root-1" ]
}

prepare_ini() {
    INI="${APT_FIXTURE_ROOT}/etc/php/${MAJOR:-8}.${MINOR:-3}/mods-available/xdebug.ini"
    mkdir -p "${INI%/*}"
    printf 'original INI\n' >"$INI"
}

assert_install_requests() {
    assert_recorded_argv "${APT_FIXTURE_CALLS}/1" update -qq
    assert_recorded_argv "${APT_FIXTURE_CALLS}/2" install -y --no-install-recommends "php${MAJOR:-8}.${MINOR:-3}-xdebug"
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-1" apt-get update -qq
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-2" apt-get install -y --no-install-recommends "php${MAJOR:-8}.${MINOR:-3}-xdebug"
    [ ! -e "${APT_FIXTURE_CALLS}/3" ]
}

@test "PHP debug requires PHP before version probes APT or INI writes" {
    prepare_ini
    PHP_PRESENT=0 run_debug_fixture "$INSTALLER"
    [ "$status" -eq 1 ]
    [[ "$output" = *'Required command not found: php.'* ]]
    [ ! -e "${APT_FIXTURE_ROOT}/php-probes" ]
    [ ! -e "${APT_FIXTURE_CALLS}/1" ]
    [ "$(<"$INI")" = 'original INI' ]
}

@test "PHP debug loaded module reuse preserves INI and makes zero APT requests" {
    prepare_ini
    LOADED=1 run_debug_fixture "$INSTALLER" PHP_VERSION=9.9 XDEBUG_INI=/etc/unsafe
    [ "$status" -eq 0 ]
    [ "$output" = 'Xdebug already loaded in PHP 8.3' ]
    [ "$(<"$INI")" = 'original INI' ]
    [ ! -e "${APT_FIXTURE_CALLS}/1" ]
    [ ! -e "${APT_FIXTURE_ROOT}/root-1" ]
    assert_recorded_argv "${APT_FIXTURE_ROOT}/php-probes" -r 'echo PHP_MAJOR_VERSION;' -r 'echo PHP_MINOR_VERSION;' -m
}

@test "PHP debug derives package from PHP and writes exact shared module INI bytes" {
    MAJOR=7 MINOR=4
    prepare_ini
    mkdir -p "${APT_FIXTURE_ROOT}/etc/php/7.4/cli/conf.d" "${APT_FIXTURE_ROOT}/etc/php/7.4/fpm/conf.d"
    printf 'CLI sentinel\n' >"${APT_FIXTURE_ROOT}/etc/php/7.4/cli/conf.d/xdebug.ini"
    printf 'FPM sentinel\n' >"${APT_FIXTURE_ROOT}/etc/php/7.4/fpm/conf.d/xdebug.ini"
    run_debug_fixture "$INSTALLER" PHP_VERSION=9.9 XDEBUG_INI=/etc/unsafe
    [ "$status" -eq 0 ]
    assert_install_requests
    printf '%s\n' 'zend_extension=xdebug' 'xdebug.mode=debug' \
        'xdebug.start_with_request=yes' 'xdebug.client_host=host.docker.internal' \
        'xdebug.discover_client_host=true' >"${APT_FIXTURE_ROOT}/expected.ini"
    cmp "${APT_FIXTURE_ROOT}/expected.ini" "$INI"
    [ "$(<"${APT_FIXTURE_ROOT}/etc/php/7.4/cli/conf.d/xdebug.ini")" = 'CLI sentinel' ]
    [ "$(<"${APT_FIXTURE_ROOT}/etc/php/7.4/fpm/conf.d/xdebug.ini")" = 'FPM sentinel' ]
    assert_recorded_argv "${APT_FIXTURE_ROOT}/php-probes" -r 'echo PHP_MAJOR_VERSION;' -r 'echo PHP_MINOR_VERSION;' -m -m -m
    [[ "$output" = *'Xdebug loaded: XdEbUg'* ]]
}

@test "PHP debug missing INI warns without creating directories and still checks module" {
    run_debug_fixture "$INSTALLER"
    [ "$status" -eq 0 ]
    assert_install_requests
    [[ "$output" = *"Xdebug INI not found at ${APT_FIXTURE_ROOT}/etc/php/8.3/mods-available/xdebug.ini; please configure manually"* ]]
    [ ! -e "${APT_FIXTURE_ROOT}/etc" ]
}

@test "PHP debug APT failures propagate and never modify INI" {
    prepare_ini
    FAIL_STAGE=1 run_debug_fixture "$INSTALLER"
    [ "$status" -eq 41 ]
    [ ! -e "${APT_FIXTURE_CALLS}/2" ]
    [ "$(<"$INI")" = 'original INI' ]
    rm -f "${APT_FIXTURE_CALLS}/1" "${APT_FIXTURE_ROOT}/root-1"
    FAIL_STAGE=2 run_debug_fixture "$INSTALLER"
    [ "$status" -eq 42 ]
    assert_install_requests
    [ ! -e "${APT_FIXTURE_ROOT}/stage-2" ]
    [ "$(<"$INI")" = 'original INI' ]
    [[ "$output" != *'Configuring Xdebug'* ]]
}

@test "PHP debug missing postinstall module exits one after configuration without rollback" {
    prepare_ini
    POST_LOADED=0 run_debug_fixture "$INSTALLER"
    [ "$status" -eq 1 ]
    assert_install_requests
    [[ "$output" = *'module not loaded after apt install'* ]]
    [ "$(<"$INI")" != 'original INI' ]
    [ "$(<"${APT_FIXTURE_ROOT}/module-count")" -eq 2 ]
}

@test "PHP debug version errors propagate before APT or configuration" {
    prepare_ini
    MAJOR_STATUS=53 run_debug_fixture "$INSTALLER"
    [ "$status" -eq 53 ]
    [ ! -e "${APT_FIXTURE_CALLS}/1" ]
    MINOR_STATUS=54 run_debug_fixture "$INSTALLER"
    [ "$status" -eq 54 ]
    [ ! -e "${APT_FIXTURE_CALLS}/1" ]
    [ "$(<"$INI")" = 'original INI' ]
}

@test "PHP debug failed module probes are treated as absent and final log failure is swallowed" {
    MODULE_STATUS=55 run_debug_fixture "$INSTALLER"
    [ "$status" -eq 1 ]
    assert_install_requests
    printf 'php -m\n' >"${APT_FIXTURE_ROOT}/probe"
    rm -f "${APT_FIXTURE_ROOT}/module-count"
    MODULE_STATUS=55 run_debug_fixture "${APT_FIXTURE_ROOT}/probe"
    [ "$status" -eq 55 ]
    rm -f "${APT_FIXTURE_CALLS}"/* "${APT_FIXTURE_ROOT}"/root-* "${APT_FIXTURE_ROOT}"/stage-* "${APT_FIXTURE_ROOT}/module-count"
    LOG_STATUS=56 run_debug_fixture "$INSTALLER"
    [ "$status" -eq 0 ]
    [[ "$output" = *'Xdebug loaded: '* ]]
    printf 'php -m\n' >"${APT_FIXTURE_ROOT}/probe"
    LOG_STATUS=56 run_debug_fixture "${APT_FIXTURE_ROOT}/probe"
    [ "$status" -eq 56 ]
}

@test "PHP debug rejects unexpected vectors paths packages order and pipeline commands" {
    local request
    for request in 'devcontainer_run_as_root' 'devcontainer_run_as_root sudo apt-get update -qq' \
        'devcontainer_run_as_root apt-get update' 'devcontainer_run_as_root apt-get update -qq extra' \
        'devcontainer_run_as_root apt-get install -y --no-install-recommends php8.3-xdebug' \
        'DEBUG_STAGE=1; devcontainer_run_as_root apt-get install -y --no-install-recommends php9.9-xdebug' \
        'DEBUG_STAGE=2; apt-get update -qq' 'php --version' 'php -r evil' \
        'grep -qi other' 'grep -qi xdebug /etc/php/8.3/mods-available/xdebug.ini' \
        'cat /etc/passwd' 'mkdir -p /etc/php' 'devcontainer_has_cmd composer' \
        'devcontainer_require_cmd php wrong'; do
        printf '%s\n' "$request" >"${APT_FIXTURE_ROOT}/probe"
        run_debug_fixture "${APT_FIXTURE_ROOT}/probe"
        [ "$status" -eq 98 ]
    done
    MAJOR=../../etc run_debug_fixture "$INSTALLER"
    [ "$status" -eq 98 ]
    [ ! -e "${APT_FIXTURE_ROOT}/etc" ]
}

@test "PHP debug closed PATH has no executable ambient fallback" {
    local command
    for command in php grep cat mkdir curl bash docker python3; do
        printf 'type -P %s\n' "$command" >"${APT_FIXTURE_ROOT}/probe"
        run_debug_fixture "${APT_FIXTURE_ROOT}/probe"
        [ "$status" -eq 1 ]
    done
}
