#!/usr/bin/env bats
#
# tools.bats — maintainer integration checks for core and selected tools
# after devcontainer setup. Run inside the devcontainer.
#
# Run from the repo root:
#   bats .devcontainer/test/integration/tools.bats
#

load install-selection.sh

# ---------------------------------------------------------------------------
# Core tools
# ---------------------------------------------------------------------------

@test "core: curl is installed" {
    command -v curl >/dev/null
}

@test "core: jq is installed" {
    command -v jq >/dev/null
}

@test "core: git is installed" {
    command -v git >/dev/null
}

@test "core: GnuPG is installed by the always-on system layer" {
    local system_installer="${BATS_TEST_DIRNAME}/../../install/01-foundation/10-system.sh"

    command -v gpg >/dev/null
    run gpg --version
    [ "$status" -eq 0 ]
    [[ "$output" == gpg* ]]
    grep -Eq '^[[:space:]]*gnupg[[:space:]]*\\$' "${system_installer}"
}

@test "core: task (Taskfile) is installed" {
    command -v task >/dev/null
}

@test "selected: devcontainer CLI is installed" {
    skip_if_install_disabled "2030-tool-devcontainer-cli.sh" "Restore the mandatory core alias and matching Dockerfile COPY input"
    command -v devcontainer >/dev/null
}

@test "selected: node is installed" {
    skip_if_install_disabled "2000-runtime-node.sh" "Restore the mandatory core alias and matching Dockerfile COPY input"
    command -v node >/dev/null
}

@test "core: bash version >= 5.0" {
    bash_version=$(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    # Use sort -V to compare versions
    printf '%s\n%s\n' "5.0" "${bash_version}" | sort -V -C
}

# ---------------------------------------------------------------------------
# Go toolchain
# ---------------------------------------------------------------------------

@test "go: go is installed" {
    skip_if_install_disabled "2100-runtime-go.sh" "task install:enable -- 2100-runtime-go"
    command -v go >/dev/null
}

@test "go: gofmt is installed" {
    skip_if_install_disabled "2100-runtime-go.sh" "task install:enable -- 2100-runtime-go"
    command -v gofmt >/dev/null
}

@test "go: go version >= 1.20" {
    skip_if_install_disabled "2100-runtime-go.sh" "task install:enable -- 2100-runtime-go"
    go_version=$(go version | grep -oE 'go[0-9]+\.[0-9]+\.[0-9]+' | sed 's/go//')
    printf '%s\n%s\n' "1.20.0" "${go_version}" | sort -V -C
}

@test "go: GOROOT is set" {
    skip_if_install_disabled "2100-runtime-go.sh" "task install:enable -- 2100-runtime-go"
    # GOROOT is set by the Go install script during devcontainer setup.
    # Outside the devcontainer it may be unset; in that case skip.
    [ -n "${DEVCONTAINER_PHASE:-}" ] || skip "DEVCONTAINER_PHASE not set (run inside devcontainer)"
    [ -n "${GOROOT:-}" ]
}

# ---------------------------------------------------------------------------
# Java toolchain
# ---------------------------------------------------------------------------

@test "java: java is installed" {
    skip_if_install_disabled "2200-runtime-java.sh" "task install:enable -- 2200-runtime-java"
    command -v java >/dev/null
}

@test "java: javac is installed" {
    skip_if_install_disabled "2200-runtime-java.sh" "task install:enable -- 2200-runtime-java"
    command -v javac >/dev/null
}

@test "java: java version >= 21" {
    skip_if_install_disabled "2200-runtime-java.sh" "task install:enable -- 2200-runtime-java"
    java_version=$(java -version 2>&1 | head -1 | grep -oE '[0-9]+' | head -1)
    printf '%s\n%s\n' "21" "${java_version}" | sort -V -C
}

# ---------------------------------------------------------------------------
# Node.js toolchain
# ---------------------------------------------------------------------------

@test "node: pnpm version >= 8" {
    skip_if_install_disabled "2010-runtime-pnpm.sh" "Restore the mandatory core alias and matching Dockerfile COPY input"
    pnpm_version=$(pnpm --version)
    printf '%s\n%s\n' "8.0.0" "${pnpm_version}" | sort -V -C
}

@test "node: npm is functional" {
    skip_if_install_disabled "2000-runtime-node.sh" "Restore the mandatory core alias and matching Dockerfile COPY input"
    run npm --version
    [ "$status" -eq 0 ]
}

@test "node: pnpm image exports a writable user-global environment" {
    skip_if_install_disabled "2010-runtime-pnpm.sh" "Restore the mandatory core alias and matching Dockerfile COPY input"
    run bash --noprofile --norc -c '
        [ "${PNPM_HOME:-}" = /home/ubuntu/.local/share/pnpm ] &&
        [ "${SHELL:-}" = /bin/bash ] &&
        [[ ":${PATH}:" == *":${PNPM_HOME}/bin:"* ]] &&
        [[ ":${PATH}:" == *":${PNPM_HOME}:"* ]] &&
        [ -w "${PNPM_HOME}" ] && [ -w "${PNPM_HOME}/bin" ] &&
        [ "$(stat -c %U:%G "${PNPM_HOME}")" = ubuntu:ubuntu ] &&
        [ "$(stat -c %U:%G "${PNPM_HOME}/bin")" = ubuntu:ubuntu ]
    '
    [ "$status" -eq 0 ]
}

@test "node: pnpm installs and runs an offline isolated user-global command" {
    skip_if_install_disabled "2010-runtime-pnpm.sh" "Restore the mandatory core alias and matching Dockerfile COPY input"
    local sandbox="${BATS_TEST_TMPDIR}/pnpm-global"
    local cli
    cli="$(command -v pnpm)"
    mkdir -p "${sandbox}/home" "${sandbox}/package" "${sandbox}/pnpm/bin"
    printf '%s\n' '{"name":"starter-global-fixture","version":"1.0.0","bin":{"starter-global-fixture":"cli.cjs"}}' >"${sandbox}/package/package.json"
    printf '%s\n' '#!/usr/bin/env node' 'console.log("starter-global-ok")' >"${sandbox}/package/cli.cjs"
    chmod +x "${sandbox}/package/cli.cjs"
    run env -i HOME="${sandbox}/home" SHELL=/bin/bash \
        PNPM_HOME="${sandbox}/pnpm" PATH="${PATH}:${sandbox}/pnpm/bin:${sandbox}/pnpm" \
        XDG_CONFIG_HOME="${sandbox}/config" XDG_DATA_HOME="${sandbox}/data" \
        XDG_CACHE_HOME="${sandbox}/cache" XDG_STATE_HOME="${sandbox}/state" \
        bash --noprofile --norc -c '
            set -eu
            cd "$1"
            "$2" add --global --offline --ignore-scripts --store-dir "$1/store" "$1/package"
            [ "$(command -v pnpm)" = "$2" ]
            [ "$(starter-global-fixture)" = starter-global-ok ]
        ' bash "${sandbox}" "${cli}"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Opt-in tools (require explicit task install:enable)
# ---------------------------------------------------------------------------

@test "opt-in dlv: dlv is installed" {
    skip_if_install_disabled "2110-go-debug.sh" "task install:enable -- 2110-go-debug"
    command -v dlv >/dev/null
}

@test "opt-in vitest: vitest is installed" {
    skip_if_install_disabled "2060-node-test.sh" "task install:enable -- 2060-node-test"
    command -v vitest >/dev/null
}

@test "opt-in archify: Archify is healthy" {
    skip_if_install_disabled "2070-node-archify.sh" "task install:enable -- 2070-node-archify"
    command -v archify >/dev/null
    run env ARCHIFY_UPDATE_CHECK_DISABLED=1 archify doctor
    [ "$status" -eq 0 ]
}

@test "opt-in php: php is installed" {
    skip_if_install_disabled "2300-php-lang.sh" "task install:enable -- 2300-php-lang"
    command -v php >/dev/null
}

@test "opt-in phpunit: phpunit is installed" {
    skip_if_install_disabled "2320-php-test.sh" "task install:enable -- 2320-php-test"
    command -v phpunit >/dev/null
}

# ---------------------------------------------------------------------------
# AI tools
# ---------------------------------------------------------------------------

@test "ai: pi is installed" {
    skip_if_install_disabled "3030-ai-pi-coding.sh" "task install:enable -- 3030-ai-pi-coding"
    command -v pi >/dev/null
}

@test "ai: pi is executable" {
    skip_if_install_disabled "3030-ai-pi-coding.sh" "task install:enable -- 3030-ai-pi-coding"
    [ -x "$(command -v pi)" ]
}

@test "ai: engram is installed" {
    skip_if_install_disabled "3010-ai-engram.sh" "Restore the mandatory core alias and matching Dockerfile COPY input"
    command -v engram >/dev/null
}

@test "ai: Gentle AI is installed" {
    skip_if_install_disabled "3020-ai-gentle-ai.sh" "Restore the mandatory core alias and matching Dockerfile COPY input"
    command -v gentle-ai >/dev/null
    run gentle-ai version
    [ "$status" -eq 0 ]
}

@test "ai: skills directory exists" {
    skip_if_install_disabled "3040-ai-pi-gentle.sh" "task install:enable -- 3040-ai-pi-gentle"
    [ -d "${HOME}/.pi/agent/skills" ] || [ -d "${HOME}/.pi/agent/npm/node_modules/gentle-pi/skills" ]
}

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

@test "env: PATH includes /usr/local/bin" {
    [[ ":${PATH}:" == *":/usr/local/bin:"* ]]
}

@test "env: HOME is writable" {
    [ -w "${HOME}" ]
}

@test "env: DEVCONTAINER_PHASE is set" {
    # DEVCONTAINER_PHASE is set by the devcontainer lifecycle scripts.
    # Outside the devcontainer it is typically unset.
    [ -n "${DEVCONTAINER_PHASE:-}" ] || skip "DEVCONTAINER_PHASE not set (run inside devcontainer)"
    [[ "${DEVCONTAINER_PHASE:-}" =~ ^(build|runtime)$ ]]
}

@test "env: LANG is set to a UTF-8 locale" {
    [[ "${LANG:-}" =~ \.UTF-8$ ]] || [[ "${LANG:-}" =~ \.utf-8$ ]]
}
