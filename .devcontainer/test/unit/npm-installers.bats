#!/usr/bin/env bats

load ../helpers/npm-fixture.bash

prepare_installer() {
    local tool="$1" source_installer
    case "$tool" in
        markdownlint)
            source_installer=2020-node-markdownlint.sh
            VERSION_ENV=MARKDOWNLINT_CLI2_VERSION
            PACKAGE=markdownlint-cli2
            CLI=markdownlint-cli2
            EXPECTED_VERSION=9.9.31
            ;;
        devcontainer)
            source_installer=2030-tool-devcontainer-cli.sh
            VERSION_ENV=DEVCONTAINER_CLI_VERSION
            PACKAGE=@devcontainers/cli
            CLI=devcontainer
            EXPECTED_VERSION=9.9.32
            ;;
    esac
    setup_npm_fixture "${BATS_TEST_TMPDIR}/${tool}"
    export HOME="${NPM_FIXTURE_ROOT}/home"
    mkdir -p "${NPM_FIXTURE_ROOT}/install/available" "${NPM_FIXTURE_ROOT}/install/lib"
    INSTALLER="${NPM_FIXTURE_ROOT}/install/available/${source_installer}"
    cp "${BATS_TEST_DIRNAME}/../../install/available/${source_installer}" "$INSTALLER"
    cmp "$INSTALLER" "${BATS_TEST_DIRNAME}/../../install/available/${source_installer}"
    CONSUMER_ENV="${NPM_FIXTURE_ROOT}/install/lib/common.sh"
    cat >"$CONSUMER_ENV" <<'STUBS'
source "$NPM_FIXTURE_RUNTIME"
command() {
    if [ "$#" -eq 2 ] && [ "$1" = -v ]; then
        case "$2" in
            npm)
                [ "$NPM_AVAILABLE" = 1 ] || return 1
                printf '%s/bin/npm\n' "$NPM_FIXTURE_ROOT"
                return 0
                ;;
            markdownlint-cli2|devcontainer)
                [ -x "${NPM_FIXTURE_ROOT}/bin/$2" ] || return 1
                printf '%s/bin/%s\n' "$NPM_FIXTURE_ROOT" "$2"
                return 0
                ;;
        esac
    fi
    builtin command "$@"
}
markdownlint-cli2() {
    [ -x "${NPM_FIXTURE_ROOT}/bin/markdownlint-cli2" ] || return 127
    "${NPM_FIXTURE_ROOT}/bin/markdownlint-cli2" "$@"
}
devcontainer() {
    [ -x "${NPM_FIXTURE_ROOT}/bin/devcontainer" ] || return 127
    "${NPM_FIXTURE_ROOT}/bin/devcontainer" "$@"
}
devcontainer_load_tool_versions() {
    [ "$HOME" = "${NPM_FIXTURE_ROOT}/home" ] || return 94
    [[ ! -v "$VERSION_ENV" ]] || return 94
    LOCK_MARKDOWNLINT_CLI2_VERSION=9.9.31
    LOCK_DEVCONTAINER_CLI_VERSION=9.9.32
}
devcontainer_has_cmd() { command -v "$1" >/dev/null; }
devcontainer_require_cmd() {
    devcontainer_has_cmd "$1" && return 0
    printf '%s is required: %s\n' "$1" "$2" >&2
    return 1
}
devcontainer_log_info() { printf '%s\n' "$*"; }
devcontainer_log_error() { printf '%s\n' "$*" >&2; }
devcontainer_run_as_root() {
    [ "$#" -eq 4 ] && [ "$1" = npm ] && [ "$2" = install ] &&
        [ "$3" = -g ] && [ "$4" = "${PACKAGE}@${EXPECTED_VERSION}" ] || return 95
    shift
    npm "$@"
}
npm_fixture_dispatch() {
    [ "$#" -eq 3 ] && [ "$1" = install ] && [ "$2" = -g ] &&
        [ "$3" = "${PACKAGE}@${EXPECTED_VERSION}" ] || return 98
    [ "$NPM_FAILURE" -eq 0 ] || return "$NPM_FAILURE"
    cat >"${NPM_FIXTURE_ROOT}/bin/${CLI}" <<CLI_SCRIPT
#!/bin/bash
[ "\$#" -eq 1 ] || exit 97
case "\$1" in
    --help|--version) printf '%s\\n' '$EXPECTED_VERSION' ;;
    *) exit 97 ;;
esac
CLI_SCRIPT
    chmod +x "${NPM_FIXTURE_ROOT}/bin/${CLI}"
}
STUBS
}

create_existing_cli() {
    printf '#!/bin/bash\nprintf "existing unrelated version\\n"\n' >"${NPM_FIXTURE_ROOT}/bin/${CLI}"
    chmod +x "${NPM_FIXTURE_ROOT}/bin/${CLI}"
}

run_installer() {
    [ "$HOME" = "${NPM_FIXTURE_ROOT}/home" ] || return 94
    run_npm_fixture "$INSTALLER" "$CONSUMER_ENV" \
        PACKAGE="$PACKAGE" CLI="$CLI" EXPECTED_VERSION="$EXPECTED_VERSION" \
        VERSION_ENV="$VERSION_ENV" \
        NPM_AVAILABLE="${NPM_AVAILABLE:-1}" NPM_FAILURE="${NPM_FAILURE:-0}"
}

assert_exact_install_call() {
    local argv
    mapfile -d '' -t argv <"${NPM_FIXTURE_CALLS}/1"
    [ "${#argv[@]}" -eq 3 ]
    [ "${argv[0]}" = install ]
    [ "${argv[1]}" = -g ]
    [ "${argv[2]}" = "${PACKAGE}@${EXPECTED_VERSION}" ]
    [ ! -e "${NPM_FIXTURE_CALLS}/2" ]
}

@test "npm installers reuse present CLIs without exact-version matching or npm calls" {
    local tool before
    for tool in markdownlint devcontainer; do
        prepare_installer "$tool"
        create_existing_cli
        before="$(sha256sum "${NPM_FIXTURE_ROOT}/bin/${CLI}")"
        run_installer
        [ "$status" -eq 0 ]
        [ "$before" = "$(sha256sum "${NPM_FIXTURE_ROOT}/bin/${CLI}")" ]
        [ ! -e "${NPM_FIXTURE_CALLS}/1" ]
    done
}

@test "npm installers install the exact locked package and expose the fixture CLI" {
    local tool
    for tool in markdownlint devcontainer; do
        prepare_installer "$tool"
        run_installer
        [ "$status" -eq 0 ]
        assert_exact_install_call
        [ -x "${NPM_FIXTURE_ROOT}/bin/${CLI}" ]
        run env -i HOME="$HOME" PATH="${NPM_FIXTURE_ROOT}/bin:/usr/bin:/bin" \
            "${NPM_FIXTURE_ROOT}/bin/${CLI}" --version
        [ "$status" -eq 0 ]
        [ "$output" = "$EXPECTED_VERSION" ]
    done
}

@test "npm installers propagate npm failure without a CLI or success claim" {
    local tool
    for tool in markdownlint devcontainer; do
        prepare_installer "$tool"
        NPM_FAILURE=42 run_installer
        [ "$status" -eq 42 ]
        assert_exact_install_call
        [ ! -e "${NPM_FIXTURE_ROOT}/bin/${CLI}" ]
        [[ "$output" != *"installed:"* ]]
    done
}

@test "npm installers reject missing npm before installation without npm calls" {
    local tool
    for tool in markdownlint devcontainer; do
        prepare_installer "$tool"
        NPM_AVAILABLE=0 run_installer
        [ "$status" -ne 0 ]
        [[ "$output" == *"npm is required"* ]]
        [ ! -e "${NPM_FIXTURE_CALLS}/1" ]
        [ ! -e "${NPM_FIXTURE_ROOT}/bin/${CLI}" ]
    done
}

@test "npm installers preserve different prerequisite ordering when reusing a CLI" {
    prepare_installer markdownlint
    create_existing_cli
    NPM_AVAILABLE=0 run_installer
    [ "$status" -eq 0 ]
    [ ! -e "${NPM_FIXTURE_CALLS}/1" ]

    prepare_installer devcontainer
    create_existing_cli
    NPM_AVAILABLE=0 run_installer
    [ "$status" -eq 1 ]
    [[ "$output" == *"npm is required"* ]]
    [ ! -e "${NPM_FIXTURE_CALLS}/1" ]
}

@test "devcontainer rejects npm success without a binary on the fixture PATH" {
    prepare_installer devcontainer
    cat >>"$CONSUMER_ENV" <<'STUBS'
npm_fixture_dispatch() {
    [ "$#" -eq 3 ] && [ "$1" = install ] && [ "$2" = -g ] &&
        [ "$3" = "${PACKAGE}@${EXPECTED_VERSION}" ] || return 98
}
STUBS
    run_installer
    [ "$status" -eq 1 ]
    [[ "$output" == *"binary not on PATH"* ]]
    [[ "$output" != *"CLI installed:"* ]]
    assert_exact_install_call
}

@test "npm installer fixture rejects unexpected argv without creating a CLI" {
    prepare_installer markdownlint
    local probe="${NPM_FIXTURE_ROOT}/rejected-request.sh"
    printf 'npm install -g "wrong-package@0"\n' >"$probe"
    run_npm_fixture "$probe" "$CONSUMER_ENV" \
        PACKAGE="$PACKAGE" CLI="$CLI" EXPECTED_VERSION="$EXPECTED_VERSION"
    [ "$status" -eq 98 ]
    [ ! -e "${NPM_FIXTURE_ROOT}/bin/${CLI}" ]
    local argv
    mapfile -d '' -t argv <"${NPM_FIXTURE_CALLS}/1"
    [ "${#argv[@]}" -eq 3 ]
    [ "${argv[2]}" = wrong-package@0 ]
}

@test "npm installer fixture lookup and direct probes never use ambient CLIs" {
    local tool probe
    for tool in markdownlint devcontainer; do
        prepare_installer "$tool"
        probe="${NPM_FIXTURE_ROOT}/absent-cli.sh"
        cat >"$probe" <<'PROBE'
command -v bash >/dev/null || exit 96
command -v npm && exit 96
command -v "$CLI" && exit 96
if "$CLI" --version; then exit 96; else [ "$?" -eq 127 ]; fi
PROBE
        run_npm_fixture "$probe" "$CONSUMER_ENV" CLI="$CLI" NPM_AVAILABLE=0
        [ "$status" -eq 0 ]
        [ -z "$output" ]
        [ ! -e "${NPM_FIXTURE_CALLS}/1" ]
    done
}
