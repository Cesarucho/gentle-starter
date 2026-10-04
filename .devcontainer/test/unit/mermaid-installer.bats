#!/usr/bin/env bats

load ../helpers/npm-fixture.bash

setup() {
    setup_npm_fixture "${BATS_TEST_TMPDIR}/mermaid"
    mkdir -p "${NPM_FIXTURE_ROOT}/install/available" "${NPM_FIXTURE_ROOT}/install/lib"
    INSTALLER="${NPM_FIXTURE_ROOT}/install/available/2050-node-mermaid.sh"
    cp "${BATS_TEST_DIRNAME}/../../install/available/2050-node-mermaid.sh" "$INSTALLER"
    cmp "${BATS_TEST_DIRNAME}/../../install/available/2050-node-mermaid.sh" "$INSTALLER"
    mkdir -p "${NPM_FIXTURE_ROOT}/opt/mermaid-cli/bin" \
        "${NPM_FIXTURE_ROOT}/etc/mermaid-cli" "${NPM_FIXTURE_ROOT}/usr/local/bin"
    CONSUMER_ENV="${NPM_FIXTURE_ROOT}/install/lib/common.sh"
    cat >"$CONSUMER_ENV" <<'STUBS'
source "$NPM_FIXTURE_RUNTIME"
devcontainer_load_tool_versions() {
    [ "$HOME" = "${NPM_FIXTURE_ROOT}/home" ] && [[ ! -v MERMAID_CLI_VERSION ]] || exit 90
    LOCK_MERMAID_CLI_VERSION=9.9.36
}
record_request() {
    local family="$1" number=1
    shift
    case "$family" in root|user|lookup|render|version) ;; *) exit 90 ;; esac
    mkdir -p "${NPM_FIXTURE_ROOT}/${family}-calls"
    while [ -e "${NPM_FIXTURE_ROOT}/${family}-calls/${number}" ]; do
        number=$((number + 1))
    done
    printf '%s\0' "$@" >"${NPM_FIXTURE_ROOT}/${family}-calls/${number}"
}
# Compare argc and every argument, never a space-joined authorization string.
expect_request() {
    local count="$1" index
    shift
    builtin [ "$#" -eq "$((count * 2))" ] || exit 90
    local -a args=("$@")
    for ((index=0; index<count; index++)); do
        builtin [ "${args[index]}" = "${args[index + count]}" ] || exit 90
    done
}
devcontainer_log_info() { printf '%s\n' "$*"; }
devcontainer_log_error() { printf '%s\n' "$*" >&2; }
devcontainer_has_cmd() {
    case "$1" in
        npm) [ "$NPM_AVAILABLE" = 1 ] ;;
        mmdc) [ "$EXISTING_CLI" = 1 ] ;;
        *) return 90 ;;
    esac
}
getent() {
    expect_request 2 "$@" passwd ubuntu
    record_request lookup "$@"
    [ "$USER_AVAILABLE" = 1 ] || return 0
    printf 'ubuntu:x:1000:1000:fixture:%s/home:/bin/bash\n' "$NPM_FIXTURE_ROOT"
}
# The source uses the interceptable [ builtin, not an absolute executable.
[() {
    if builtin [ "$#" -eq 4 ] && builtin [ "$1" = '!' ] &&
        builtin [ "$2" = -x ] && builtin [ "$3" = /opt/mermaid-cli/bin/mmdc ] &&
        builtin [ "$4" = ']' ]; then
        builtin [ ! -x "${NPM_FIXTURE_ROOT}/opt/mermaid-cli/bin/mmdc" ]
        return
    elif builtin [ "$#" -eq 3 ] && builtin [ "$1" = -x ] &&
        builtin [ "$2" = /opt/mermaid-cli/bin/mmdc ] && builtin [ "$3" = ']' ]; then
        builtin [ -x "${NPM_FIXTURE_ROOT}/opt/mermaid-cli/bin/mmdc" ]
        return
    fi
    local argument
    for argument in "$@"; do
        case "$argument" in /opt/*|/etc/*|/usr/local/*) exit 90 ;; esac
    done
    builtin [ "$@"
}
mktemp() {
    expect_request 1 "$@" -d
    [ "$TMPDIR" = "${NPM_FIXTURE_ROOT}/tmp" ] || exit 90
    local path
    path="$(/usr/bin/mktemp -d)"
    printf '%s\n' "$path" >"${NPM_FIXTURE_ROOT}/smoke-path"
    printf '%s\n' "$path"
}
rm() {
    local directory
    directory="$(<"${NPM_FIXTURE_ROOT}/smoke-path")"
    case "$directory" in "${NPM_FIXTURE_ROOT}/tmp/"*) ;; *) exit 90 ;; esac
    [[ "$directory" != *'/../'* && "$directory" != */.. ]] || exit 90
    [ "$#" -eq 2 ] || exit 90
    case "$1" in
        -rf) [ "$2" = "$directory" ] || exit 90 ;;
        -f) [ "$2" = "${directory}/smoke.svg" ] || exit 90 ;;
        *) exit 90 ;;
    esac
    /usr/bin/rm "$@"
}
devcontainer_run_as_root() {
    record_request root "$@"
    local directory="$(<"${NPM_FIXTURE_ROOT}/smoke-path")"
    case "$directory" in "${NPM_FIXTURE_ROOT}/tmp/"*) ;; *) exit 90 ;; esac
    [[ "$directory" != *'/../'* && "$directory" != */.. ]] || exit 90
    case "$1" in
        chown) expect_request 4 "$@" chown -R ubuntu:ubuntu "$directory" ;;
        apt-get)
            if [ "${2:-}" = update ]; then
                expect_request 2 "$@" apt-get update
            else
                expect_request 13 "$@" apt-get install -y --no-install-recommends \
                    libasound2t64 libatk-bridge2.0-0t64 libgbm1 libnss3 \
                    libxcomposite1 libxdamage1 libxfixes3 libxkbcommon0 libxrandr2
            fi
            ;;
        install)
            case "${!#}" in
                /opt/mermaid-cli)
                    expect_request 7 "$@" install -d -o ubuntu -g ubuntu /opt/mermaid-cli
                    ;;
                /etc/mermaid-cli)
                    expect_request 5 "$@" install -d -m 0755 /etc/mermaid-cli
                    ;;
                /etc/mermaid-cli/puppeteer.json)
                    expect_request 5 "$@" install -m 0644 "${directory}/puppeteer.json" /etc/mermaid-cli/puppeteer.json
                    cat "${directory}/puppeteer.json" >"${NPM_FIXTURE_ROOT}/etc/mermaid-cli/puppeteer.json"
                    chmod 0644 "${NPM_FIXTURE_ROOT}/etc/mermaid-cli/puppeteer.json"
                    ;;
                /usr/local/bin/mmdc)
                    expect_request 5 "$@" install -m 0755 "${directory}/mmdc" /usr/local/bin/mmdc
                    cat "${directory}/mmdc" >"${NPM_FIXTURE_ROOT}/usr/local/bin/mmdc"
                    chmod 0755 "${NPM_FIXTURE_ROOT}/usr/local/bin/mmdc"
                    ;;
                *) exit 90 ;;
            esac
            ;;
        *) exit 90 ;;
    esac
}
sudo() {
    [ "$#" -ge 4 ] || exit 90
    expect_request 3 "$1" "$2" "$3" -H -u ubuntu
    record_request user "$@"
    shift 3
    case "$1" in
        npm) shift; npm "$@" ;;
        mmdc)
            local directory="$(<"${NPM_FIXTURE_ROOT}/smoke-path")" mode
            expect_request 5 "$@" mmdc -i "${directory}/smoke.mmd" -o "${directory}/smoke.svg"
            [ "$(<"${directory}/smoke.mmd")" = 'graph TD; A-->B' ] || exit 90
            record_request render "$@"
            if [ -e "${NPM_FIXTURE_CALLS}/1" ]; then
                mode="$FINAL_RENDER"
            else
                mode="$INITIAL_RENDER"
            fi
            case "$mode" in
                success) printf '<svg>fixture</svg>\n' >"${directory}/smoke.svg" ;;
                empty) : >"${directory}/smoke.svg" ;;
                fail) return 41 ;;
                *) exit 90 ;;
            esac
            ;;
        *) exit 90 ;;
    esac
}
mmdc() {
    expect_request 1 "$@" --version
    record_request version "$@"
    printf 'fixture unrelated version\n'
}
npm_fixture_dispatch() {
    expect_request 7 "$@" install -g --prefix /opt/mermaid-cli \
        --ignore-scripts=false --foreground-scripts '@mermaid-js/mermaid-cli@9.9.36'
    [ "$NPM_FAILURE" -eq 0 ] || return "$NPM_FAILURE"
    [ "$OMIT_PRIVATE_CLI" = 0 ] || return 0
    cat >"${NPM_FIXTURE_ROOT}/opt/mermaid-cli/bin/mmdc" <<'CLI'
#!/bin/bash
[ "$HOME" = "${NPM_FIXTURE_ROOT}/home" ] || exit 90
printf '%s\0' "$@" >"${NPM_FIXTURE_ROOT}/wrapper-argv"
CLI
    chmod 0755 "${NPM_FIXTURE_ROOT}/opt/mermaid-cli/bin/mmdc"
}
STUBS
}

run_installer() {
    run_npm_fixture "$INSTALLER" "$CONSUMER_ENV" \
        NPM_AVAILABLE="${NPM_AVAILABLE:-1}" USER_AVAILABLE="${USER_AVAILABLE:-1}" \
        EXISTING_CLI="${EXISTING_CLI:-0}" NPM_FAILURE="${NPM_FAILURE:-0}" \
        OMIT_PRIVATE_CLI="${OMIT_PRIVATE_CLI:-0}" \
        INITIAL_RENDER="${INITIAL_RENDER:-success}" FINAL_RENDER="${FINAL_RENDER:-success}"
}

@test "Mermaid rejects missing npm before user lookup or root requests" {
    NPM_AVAILABLE=0 run_installer
    [ "$status" -eq 1 ]
    [[ "$output" == *'npm is required'* ]]
    [ ! -e "${NPM_FIXTURE_CALLS}/1" ]
    [ ! -e "${NPM_FIXTURE_ROOT}/lookup-calls" ]
    [ ! -e "${NPM_FIXTURE_ROOT}/root-calls" ]
    [ ! -e "${NPM_FIXTURE_ROOT}/smoke-path" ]
}

@test "Mermaid installs the locked private-prefix package through the user adapter" {
    run_installer
    [ "$status" -eq 0 ]
    local argv
    mapfile -d '' -t argv <"${NPM_FIXTURE_CALLS}/1"
    [ "${#argv[@]}" -eq 7 ]
    [ "${argv[0]}" = install ]
    [ "${argv[1]}" = -g ]
    [ "${argv[2]}" = --prefix ]
    [ "${argv[3]}" = /opt/mermaid-cli ]
    [ "${argv[4]}" = --ignore-scripts=false ]
    [ "${argv[5]}" = --foreground-scripts ]
    [ "${argv[6]}" = '@mermaid-js/mermaid-cli@9.9.36' ]
    [ ! -e "${NPM_FIXTURE_CALLS}/2" ]
    assert_install_requests
    assert_request "${NPM_FIXTURE_ROOT}/user-calls/1" -H -u ubuntu npm install -g \
        --prefix /opt/mermaid-cli --ignore-scripts=false --foreground-scripts '@mermaid-js/mermaid-cli@9.9.36'
    local directory="$(<"${NPM_FIXTURE_ROOT}/smoke-path")"
    assert_request "${NPM_FIXTURE_ROOT}/user-calls/2" -H -u ubuntu mmdc -i "${directory}/smoke.mmd" -o "${directory}/smoke.svg"
    [ ! -e "${NPM_FIXTURE_ROOT}/user-calls/3" ]
    assert_smoke_cleaned
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

assert_smoke_cleaned() {
    local directory="$(<"${NPM_FIXTURE_ROOT}/smoke-path")"
    [[ "$directory" == "${NPM_FIXTURE_ROOT}/tmp/"* ]]
    [ ! -e "$directory" ]
}

assert_install_requests() {
    local directory="$(<"${NPM_FIXTURE_ROOT}/smoke-path")"
    assert_request "${NPM_FIXTURE_ROOT}/root-calls/1" chown -R ubuntu:ubuntu "$directory"
    assert_request "${NPM_FIXTURE_ROOT}/root-calls/2" apt-get update
    assert_request "${NPM_FIXTURE_ROOT}/root-calls/3" apt-get install -y --no-install-recommends \
        libasound2t64 libatk-bridge2.0-0t64 libgbm1 libnss3 \
        libxcomposite1 libxdamage1 libxfixes3 libxkbcommon0 libxrandr2
    assert_request "${NPM_FIXTURE_ROOT}/root-calls/4" install -d -o ubuntu -g ubuntu /opt/mermaid-cli
    assert_request "${NPM_FIXTURE_ROOT}/root-calls/5" install -d -m 0755 /etc/mermaid-cli
    assert_request "${NPM_FIXTURE_ROOT}/root-calls/6" install -m 0644 "${directory}/puppeteer.json" /etc/mermaid-cli/puppeteer.json
    assert_request "${NPM_FIXTURE_ROOT}/root-calls/7" install -m 0755 "${directory}/mmdc" /usr/local/bin/mmdc
    [ ! -e "${NPM_FIXTURE_ROOT}/root-calls/8" ]
}

@test "Mermaid rejects a missing user before temporary state or installation" {
    USER_AVAILABLE=0 run_installer
    [ "$status" -eq 1 ]
    [[ "$output" == *'User not found: ubuntu'* ]]
    assert_request "${NPM_FIXTURE_ROOT}/lookup-calls/1" passwd ubuntu
    [ ! -e "${NPM_FIXTURE_ROOT}/root-calls" ]
    [ ! -e "${NPM_FIXTURE_CALLS}/1" ]
    [ ! -e "${NPM_FIXTURE_ROOT}/smoke-path" ]
}

@test "Mermaid reuses only a render-ready CLI without npm or dependency installation" {
    EXISTING_CLI=1 run_installer
    [ "$status" -eq 0 ]
    [[ "$output" == *'already render-ready: fixture unrelated version'* ]]
    local directory="$(<"${NPM_FIXTURE_ROOT}/smoke-path")"
    assert_request "${NPM_FIXTURE_ROOT}/root-calls/1" chown -R ubuntu:ubuntu "$directory"
    [ ! -e "${NPM_FIXTURE_ROOT}/root-calls/2" ]
    assert_request "${NPM_FIXTURE_ROOT}/user-calls/1" -H -u ubuntu mmdc -i "${directory}/smoke.mmd" -o "${directory}/smoke.svg"
    assert_request "${NPM_FIXTURE_ROOT}/version-calls/1" --version
    [ ! -e "${NPM_FIXTURE_CALLS}/1" ]
    assert_smoke_cleaned
}

assert_reinstall_after_render() {
    [ "$status" -eq 0 ]
    [[ "$output" == *'installed and render-checked'* ]]
    local directory="$(<"${NPM_FIXTURE_ROOT}/smoke-path")"
    assert_install_requests
    assert_request "${NPM_FIXTURE_ROOT}/user-calls/2" -H -u ubuntu npm install -g \
        --prefix /opt/mermaid-cli --ignore-scripts=false --foreground-scripts '@mermaid-js/mermaid-cli@9.9.36'
    assert_request "${NPM_FIXTURE_ROOT}/render-calls/1" mmdc -i "${directory}/smoke.mmd" -o "${directory}/smoke.svg"
    assert_request "${NPM_FIXTURE_ROOT}/render-calls/2" mmdc -i "${directory}/smoke.mmd" -o "${directory}/smoke.svg"
    [ ! -e "${NPM_FIXTURE_ROOT}/render-calls/3" ]
    assert_smoke_cleaned
}

@test "Mermaid replaces a CLI whose initial render command fails" {
    EXISTING_CLI=1 INITIAL_RENDER=fail run_installer
    assert_reinstall_after_render
}

@test "Mermaid replaces a CLI whose initial render produces an empty SVG" {
    EXISTING_CLI=1 INITIAL_RENDER=empty run_installer
    assert_reinstall_after_render
}

@test "Mermaid propagates npm failure without wrapper configuration or success claim" {
    NPM_FAILURE=42 run_installer
    [ "$status" -eq 42 ]
    [[ "$output" != *'installed and render-checked'* ]]
    [ -e "${NPM_FIXTURE_CALLS}/1" ]
    [ ! -e "${NPM_FIXTURE_ROOT}/root-calls/5" ]
    [ ! -e "${NPM_FIXTURE_ROOT}/usr/local/bin/mmdc" ]
    [ ! -e "${NPM_FIXTURE_ROOT}/etc/mermaid-cli/puppeteer.json" ]
    assert_smoke_cleaned
}

@test "Mermaid rejects npm success without the executable private CLI" {
    OMIT_PRIVATE_CLI=1 run_installer
    [ "$status" -eq 1 ]
    [[ "$output" == *'/opt/mermaid-cli/bin/mmdc not found'* ]]
    [[ "$output" != *'installed and render-checked'* ]]
    [ ! -e "${NPM_FIXTURE_ROOT}/root-calls/5" ]
    [ ! -e "${NPM_FIXTURE_ROOT}/usr/local/bin/mmdc" ]
    assert_smoke_cleaned
}

assert_final_render_failure() {
    [ "$status" -eq 1 ]
    [[ "$output" == *'functional SVG render check failed'* ]]
    [[ "$output" != *'installed and render-checked'* ]]
    assert_install_requests
    [ ! -e "${NPM_FIXTURE_ROOT}/version-calls" ]
    assert_smoke_cleaned
}

@test "Mermaid rejects a failed final render without claiming success" {
    FINAL_RENDER=fail run_installer
    assert_final_render_failure
}

@test "Mermaid rejects an empty final SVG without claiming success" {
    FINAL_RENDER=empty run_installer
    assert_final_render_failure
}


@test "Mermaid fixture rejects unknown users commands argv and absolute test paths" {
    run_installer
    [ "$status" -eq 0 ]
    local request probe="${NPM_FIXTURE_ROOT}/rejected-request"
    for request in \
        'getent passwd root' \
        'sudo -H -u root mmdc --version' \
        'sudo -H -u ubuntu node --version' \
        'sudo -H -u ubuntu npm install -g wrong-package' \
        'devcontainer_run_as_root apt-get update extra' \
        'devcontainer_run_as_root install -d /opt/other' \
        'mktemp -d extra' \
        'rm -rf /tmp/outside-mermaid-fixture' \
        '[ ! -x /opt/other/bin/mmdc ]'; do
        printf '%s\n' "$request" >"$probe"
        run_npm_fixture "$probe" "$CONSUMER_ENV"
        [ "$status" -eq 90 ]
    done
    assert_smoke_cleaned
}
