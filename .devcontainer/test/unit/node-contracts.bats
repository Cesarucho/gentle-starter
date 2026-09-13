#!/usr/bin/env bats

setup() {
    INSTALLER="${BATS_TEST_DIRNAME}/../../install/available/40-node-contracts.sh"
    export TEST_ROOT="${BATS_TEST_TMPDIR}/contracts"
    mkdir -p "${TEST_ROOT}/global/@asyncapi/cli/lib/utils"
    export BASH_ENV="${TEST_ROOT}/closed-stubs.sh"
    cat >"${BASH_ENV}" <<'STUBS'
export DEVC_INSTALL_LIB_COMMON_LOADED=1
devcontainer_load_tool_versions() {
    LOCK_SPECTRAL_VERSION=6.16.3
    LOCK_REDOCLY_VERSION=2.51.2
    LOCK_ASYNCAPI_VERSION=6.0.2
}
devcontainer_has_cmd() {
    case "$1" in
        npm) return 0 ;;
        spectral|redocly|asyncapi) test -f "${TEST_ROOT}/installed" ;;
        *) return 1 ;;
    esac
}
devcontainer_log_info() { printf '%s\n' "$*"; }
devcontainer_log_error() { printf '%s\n' "$*" >&2; }
devcontainer_run_as_root() {
    case "$*" in
        'npm root -g') npm root -g ;;
        'npm install -g '*) npm "$@" ;;
        "mkdir -m 0755 ${TEST_ROOT}/global/@asyncapi/cli/lib/utils/logs") "$@" ;;
        *) printf 'Unexpected privileged command: %s\n' "$*" >&2; return 90 ;;
    esac
}
npm() {
    case "$*" in
        'root -g') test "${ROOT_FAILURE:-0}" = 0 || return 91; printf '%s\n' "${TEST_ROOT}/global" ;;
        'npm install -g @stoplight/spectral-cli@6.16.3 @redocly/cli@2.51.2 @asyncapi/cli@6.0.2') touch "${TEST_ROOT}/installed" ;;
        *) printf 'Unexpected npm command: %s\n' "$*" >&2; return 92 ;;
    esac
}
spectral() { test "$*" = --version && printf '6.16.3\n'; }
redocly() { test "$*" = --version && printf '2.51.2\n'; }
asyncapi() { test "$*" = --version && printf '6.0.2\n'; }
STUBS
}

@test "contracts install prepares the immutable AsyncAPI logger directory" {
    run bash "${INSTALLER}"
    [ "$status" -eq 0 ]
    [ -d "${TEST_ROOT}/global/@asyncapi/cli/lib/utils/logs" ]
    [ "$(stat -c '%a' "${TEST_ROOT}/global/@asyncapi/cli/lib/utils/logs")" = 755 ]
}

@test "contracts existing installation prepares the logger directory without reinstalling" {
    touch "${TEST_ROOT}/installed"
    run bash "${INSTALLER}"
    [ "$status" -eq 0 ]
    [ -d "${TEST_ROOT}/global/@asyncapi/cli/lib/utils/logs" ]
    touch "${TEST_ROOT}/global/@asyncapi/cli/lib/utils/logs/preserved"
    run bash "${INSTALLER}"
    [ "$status" -eq 0 ]
    [ -f "${TEST_ROOT}/global/@asyncapi/cli/lib/utils/logs/preserved" ]
}

@test "contracts refuses an unverifiable npm root" {
    export ROOT_FAILURE=1
    run bash "${INSTALLER}"
    [ "$status" -ne 0 ]
    [ ! -e "${TEST_ROOT}/global/@asyncapi/cli/lib/utils/logs" ]
}

@test "contracts refuses a symlink at the logger directory" {
    mkdir "${TEST_ROOT}/outside"
    ln -s "${TEST_ROOT}/outside" "${TEST_ROOT}/global/@asyncapi/cli/lib/utils/logs"
    run bash "${INSTALLER}"
    [ "$status" -ne 0 ]
    [ -L "${TEST_ROOT}/global/@asyncapi/cli/lib/utils/logs" ]
}
