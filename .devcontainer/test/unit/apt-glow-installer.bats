#!/usr/bin/env bats

load ../helpers/apt-fixture.bash
load ../helpers/argv-assertions.bash

setup() {
    setup_apt_fixture "${BATS_TEST_TMPDIR}/glow"
    mkdir -p "${APT_FIXTURE_ROOT}/install/available" "${APT_FIXTURE_ROOT}/install/lib"
    INSTALLER="${APT_FIXTURE_ROOT}/install/available/5000-cli-glow.sh"
    cp "${BATS_TEST_DIRNAME}/../../install/available/5000-cli-glow.sh" "$INSTALLER"
    cmp "${BATS_TEST_DIRNAME}/../../install/available/5000-cli-glow.sh" "$INSTALLER"
    CONSUMER="${APT_FIXTURE_ROOT}/install/lib/common.sh"
    cp "${BATS_TEST_DIRNAME}/../helpers/apt-glow-consumer.bash" "$CONSUMER"
}

run_glow_fixture() {
    run_apt_fixture "$1" "$CONSUMER" EXISTING="${EXISTING:-0}" \
        OMIT_CLI="${OMIT_CLI:-0}" PROBE_FAILURE="${PROBE_FAILURE:-0}" \
        FAIL_STAGE="${FAIL_STAGE:-0}" \
        EXPECT_KEY="${EXPECT_KEY:-/etc/apt/keyrings/charm.gpg}" \
        EXPECT_REPO="${EXPECT_REPO:-deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *}" \
        EXPECT_LIST="${EXPECT_LIST:-/etc/apt/sources.list.d/charm.list}" "${@:2}"
}

@test "Glow rejects hostile shell text without execution or recording" {
    printf 'devcontainer_run_as_root bash -lc '\''touch "%s/hostile"'\'' -- /etc/apt/keyrings/charm.gpg repo /etc/apt/sources.list.d/charm.list\n' "$APT_FIXTURE_ROOT" >"${APT_FIXTURE_ROOT}/probe"
    run_glow_fixture "${APT_FIXTURE_ROOT}/probe"
    [ "$status" -eq 98 ]
    [ ! -e "${APT_FIXTURE_ROOT}/hostile" ]
    [ ! -e "${APT_FIXTURE_ROOT}/root-1" ]
}

@test "Glow default install captures four exact APT calls and six ordered inert root requests" {
    run_glow_fixture "$INSTALLER"
    [ "$status" -eq 0 ]
    assert_recorded_argv "${APT_FIXTURE_CALLS}/1" update
    assert_recorded_argv "${APT_FIXTURE_CALLS}/2" install -y --no-install-recommends gnupg
    assert_recorded_argv "${APT_FIXTURE_CALLS}/3" update
    assert_recorded_argv "${APT_FIXTURE_CALLS}/4" install -y --no-install-recommends glow
    [ ! -e "${APT_FIXTURE_CALLS}/5" ]
    assert_recorded_argv "${APT_FIXTURE_ROOT}/root-3" mkdir -p /etc/apt/keyrings
    local -a repo
    mapfile -d '' -t repo <"${APT_FIXTURE_ROOT}/root-4"
    [ "${#repo[@]}" -eq 7 ]
    [ "${repo[0]}" = bash ]
    [ "${repo[1]}" = -lc ]
    [ "${repo[3]}" = -- ]
    [ "${repo[4]}" = /etc/apt/keyrings/charm.gpg ]
    [ "${repo[5]}" = 'deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *' ]
    [ "${repo[6]}" = /etc/apt/sources.list.d/charm.list ]
    [ ! -e "${APT_FIXTURE_ROOT}/root-7" ]
    [ "$output" = $'Installing prerequisites for Charm apt repository\nConfiguring Charm apt repository\nInstalling glow\nglow installed: glow 2.0.0' ]
    [ "$(<"${APT_FIXTURE_ROOT}/probes")" = probe ]
}

@test "Glow explicit overrides are inert operands and keyring alone preserves default signed-by" {
    local key="${APT_FIXTURE_ROOT}/key" list="${APT_FIXTURE_ROOT}/list"
    EXPECT_KEY="$key" EXPECT_LIST="$list" run_glow_fixture "$INSTALLER" GLOW_APT_KEYRING="$key" GLOW_APT_LIST="$list"
    [ "$status" -eq 0 ]
    [ ! -e "$key" ]
    [ ! -e "$list" ]
    local -a args
    mapfile -d '' -t args <"${APT_FIXTURE_ROOT}/root-4"
    [ "${args[4]}" = "$key" ]
    [ "${args[5]}" = 'deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *' ]
    [ "${args[6]}" = "$list" ]
}

@test "Glow explicit repository override preserves exact bytes" {
    local repo='deb [signed-by=/fixture/key] https://fixture.invalid/apt/ stable main'
    EXPECT_REPO="$repo" run_glow_fixture "$INSTALLER" GLOW_APT_REPO="$repo"
    [ "$status" -eq 0 ]
    local -a args
    mapfile -d '' -t args <"${APT_FIXTURE_ROOT}/root-4"
    [ "${args[5]}" = "$repo" ]
}

@test "Glow reuse performs one first-line probe and zero root or APT calls" {
    EXISTING=1 run_glow_fixture "$INSTALLER"
    [ "$status" -eq 0 ]
    [ "$output" = 'glow already installed: glow 2.0.0' ]
    [ "$(<"${APT_FIXTURE_ROOT}/probes")" = probe ]
    [ ! -e "${APT_FIXTURE_ROOT}/root-1" ]
    [ ! -e "${APT_FIXTURE_CALLS}/1" ]
}

@test "Glow all six synthetic stage failures stop subsequent requests and success" {
    local stage index
    for stage in 1 2 3 4 5 6; do
        FAIL_STAGE="$stage" run_glow_fixture "$INSTALLER"
        [ "$status" -eq "$((40 + stage))" ]
        [ -e "${APT_FIXTURE_ROOT}/root-${stage}" ]
        [ ! -e "${APT_FIXTURE_ROOT}/root-$((stage + 1))" ]
        [ ! -e "${APT_FIXTURE_ROOT}/stage-${stage}" ]
        [ ! -e "${APT_FIXTURE_ROOT}/probes" ]
        [[ "$output" != *'glow installed:'* ]]
        # Reset only this test's private fixture between independent failures.
        for ((index=1; index<=6; index++)); do
            rm -f "${APT_FIXTURE_ROOT}/root-${index}" "${APT_FIXTURE_ROOT}/stage-${index}" "${APT_FIXTURE_CALLS}/${index}"
        done
    done
}

@test "Glow missing installed CLI exits one without probing" {
    OMIT_CLI=1 run_glow_fixture "$INSTALLER"
    [ "$status" -eq 1 ]
    [[ "$output" = *'glow install failed: binary not on PATH'* ]]
    [ ! -e "${APT_FIXTURE_ROOT}/probes" ]
}

@test "Glow swallows failed and missing version probes on install and reuse with direct proof" {
    local failure existing
    for failure in 43 127; do
        for existing in 0 1; do
            EXISTING="$existing" PROBE_FAILURE="$failure" run_glow_fixture "$INSTALLER"
            [ "$status" -eq 0 ]
            [[ "$output" = *'installed: '* ]]
            [[ "$output" != *'glow 2.0.0'* ]]
            printf 'glow --version\n' >"${APT_FIXTURE_ROOT}/probe"
            PROBE_FAILURE="$failure" run_glow_fixture "${APT_FIXTURE_ROOT}/probe"
            [ "$status" -eq "$failure" ]
            rm -f "${APT_FIXTURE_ROOT}"/root-* "${APT_FIXTURE_ROOT}"/stage-* "${APT_FIXTURE_CALLS}"/*
        done
    done
}

@test "Glow rejects malformed root APT commands packages order and paths without fallback" {
    local request
    for request in 'devcontainer_run_as_root' 'devcontainer_run_as_root /bin/bash -lc true' \
        'devcontainer_run_as_root sudo apt-get update' 'devcontainer_run_as_root apt-get update extra' \
        'devcontainer_run_as_root apt-get install -y --no-install-recommends glow' \
        'devcontainer_run_as_root mkdir -p /tmp/keyrings' 'apt-get update' \
        'head -n 2' 'glow --help' 'devcontainer_has_cmd other'; do
        printf '%s\n' "$request" >"${APT_FIXTURE_ROOT}/probe"
        run_glow_fixture "${APT_FIXTURE_ROOT}/probe"
        [ "$status" -eq 98 ]
        [ ! -e "${APT_FIXTURE_ROOT}/root-1" ]
    done
}

@test "Glow rejects altered repository script argc delimiter operands and shell spelling" {
    local mutation
    for mutation in script hostile argc missing delimiter key repo list shell option; do
        cat >"${APT_FIXTURE_ROOT}/probe" <<'SH'
devcontainer_run_as_root apt-get update
devcontainer_run_as_root apt-get install -y --no-install-recommends gnupg
devcontainer_run_as_root mkdir -p /etc/apt/keyrings
args=(bash -lc "$GLOW_REPOSITORY_SCRIPT" -- "$EXPECT_KEY" "$EXPECT_REPO" "$EXPECT_LIST")
case "$MUTATION" in
script) args[2]+=' ' ;;
hostile) args[2]=': >"${APT_FIXTURE_ROOT}/hostile"' ;;
argc) args+=(extra) ;;
missing) unset 'args[6]' ;;
delimiter) args[3]=other ;;
key) args[4]=/wrong/key ;;
repo) args[5]=wrong ;;
list) args[6]=/wrong/list ;;
shell) args[0]=/bin/bash ;;
option) args[1]=-c ;;
esac
devcontainer_run_as_root "${args[@]}"
SH
        run_glow_fixture "${APT_FIXTURE_ROOT}/probe" MUTATION="$mutation"
        [ "$status" -eq 98 ]
        [ ! -e "${APT_FIXTURE_ROOT}/root-4" ]
        [ ! -e "${APT_FIXTURE_ROOT}/hostile" ]
        rm -f "${APT_FIXTURE_ROOT}"/root-* "${APT_FIXTURE_ROOT}"/stage-* "${APT_FIXTURE_CALLS}"/*
    done
}

@test "Glow closed PATH has no executable shell curl gpg mkdir head or CLI fallback" {
    local command
    for command in bash curl gpg mkdir head glow docker python3; do
        printf 'type -P %s\n' "$command" >"${APT_FIXTURE_ROOT}/probe"
        run_glow_fixture "${APT_FIXTURE_ROOT}/probe"
        [ "$status" -eq 1 ]
    done
}
