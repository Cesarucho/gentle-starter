# Closed npm plumbing for trusted, tool-specific test callbacks.
setup_npm_fixture() {
    case "$1" in
        "${BATS_TEST_TMPDIR:?}/"*) ;;
        *) printf 'npm fixture must be inside BATS_TEST_TMPDIR\n' >&2; return 1 ;;
    esac
    [[ "$1" != *'/../'* && "$1" != */.. ]] || return 1
    NPM_FIXTURE_ROOT="$1"
    NPM_FIXTURE_CALLS="$1/npm-calls"
    NPM_FIXTURE_RUNTIME="$1/npm-runtime.bash"
    mkdir -p "$1/home" "$1/tmp" "$1/bin" "${NPM_FIXTURE_CALLS}"
    cat >"$1/bin/npm" <<'SH'
#!/bin/bash
printf 'npm fixture dispatcher not loaded\n' >&2
exit 93
SH
    chmod +x "$1/bin/npm"
    cat >"${NPM_FIXTURE_RUNTIME}" <<'SH'
npm() {
    local number=1
    while [ -e "${NPM_FIXTURE_CALLS}/${number}" ]; do
        number=$((number + 1))
    done
    printf '%s\0' "$@" >"${NPM_FIXTURE_CALLS}/${number}"
    declare -F npm_fixture_dispatch >/dev/null || return 93
    npm_fixture_dispatch "$@"
}
SH
}

run_npm_fixture() {
    local installer="$1" consumer_env="$2" assignment
    shift 2
    for assignment in "$@"; do
        [[ "$assignment" =~ ^[a-zA-Z_][a-zA-Z_0-9]*= ]] || return 1
        case "${assignment%%=*}" in
            HOME|TMPDIR|PATH|BASH_ENV|ENV|SHELLOPTS|BASHOPTS|NPM_FIXTURE_*)
                printf 'Reserved npm fixture environment key\n' >&2; return 1 ;;
        esac
    done
    run env -i PATH="${NPM_FIXTURE_ROOT}/bin:/usr/bin:/bin" \
        HOME="${NPM_FIXTURE_ROOT}/home" TMPDIR="${NPM_FIXTURE_ROOT}/tmp" \
        NPM_FIXTURE_ROOT="${NPM_FIXTURE_ROOT}" \
        NPM_FIXTURE_CALLS="${NPM_FIXTURE_CALLS}" \
        NPM_FIXTURE_RUNTIME="${NPM_FIXTURE_RUNTIME}" \
        BASH_ENV="${consumer_env}" "$@" bash "${installer}"
}
