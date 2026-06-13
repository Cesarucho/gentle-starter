#!/usr/bin/env bats
#
# tools.bats — integration tests verifying that all tools are installed
# after devcontainer setup. Run inside the devcontainer.
#
# Run from the repo root:
#   bats .devcontainer/test/integration/tools.bats
#

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

@test "core: task (Taskfile) is installed" {
    command -v task >/dev/null
}

@test "core: devcontainer CLI is installed" {
    command -v devcontainer >/dev/null
}

@test "core: node is installed" {
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
    command -v go >/dev/null
}

@test "go: gofmt is installed" {
    command -v gofmt >/dev/null
}

@test "go: go version >= 1.20" {
    go_version=$(go version | grep -oE 'go[0-9]+\.[0-9]+\.[0-9]+' | sed 's/go//')
    printf '%s\n%s\n' "1.20.0" "${go_version}" | sort -V -C
}

@test "go: GOROOT is set" {
    # GOROOT is set by the Go install script during devcontainer setup.
    # Outside the devcontainer it may be unset; in that case skip.
    skip "DEVCONTAINER_PHASE not set (run inside devcontainer)" if [ -z "${DEVCONTAINER_PHASE:-}" ]
    [ -n "${GOROOT:-}" ]
}

# ---------------------------------------------------------------------------
# Java toolchain
# ---------------------------------------------------------------------------

@test "java: java is installed" {
    skip "java is opt-in (task install:enable -- 20-runtime-java to activate)" if ! command -v java >/dev/null
    command -v java >/dev/null
}

@test "java: javac is installed" {
    skip "java is opt-in (task install:enable -- 20-runtime-java to activate)" if ! command -v java >/dev/null
    command -v javac >/dev/null
}

@test "java: java version >= 21" {
    skip "java is opt-in (task install:enable -- 20-runtime-java to activate)" if ! command -v java >/dev/null
    java_version=$(java -version 2>&1 | head -1 | grep -oE '[0-9]+' | head -1)
    printf '%s\n%s\n' "21" "${java_version}" | sort -V -C
}

# ---------------------------------------------------------------------------
# Node.js toolchain
# ---------------------------------------------------------------------------

@test "node: pnpm version >= 8" {
    pnpm_version=$(pnpm --version)
    printf '%s\n%s\n' "8.0.0" "${pnpm_version}" | sort -V -C
}

@test "node: npm is functional" {
    run npm --version
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Opt-in tools (require explicit task install:enable)
# ---------------------------------------------------------------------------

@test "opt-in dlv: dlv is installed" {
    skip "opt-in (task install:enable -- 40-go-debug to activate)" if ! command -v dlv >/dev/null
    command -v dlv >/dev/null
}

@test "opt-in vitest: vitest is installed" {
    skip "opt-in (task install:enable -- 40-node-test to activate)" if ! command -v vitest >/dev/null
    command -v vitest >/dev/null
}

@test "opt-in php: php is installed" {
    skip "opt-in (task install:enable -- 40-php-lang to activate)" if ! command -v php >/dev/null
    command -v php >/dev/null
}

@test "opt-in phpunit: phpunit is installed" {
    skip "opt-in (task install:enable -- 40-php-test to activate)" if ! command -v phpunit >/dev/null
    command -v phpunit >/dev/null
}

# ---------------------------------------------------------------------------
# AI tools
# ---------------------------------------------------------------------------

@test "ai: pi is installed" {
    command -v pi >/dev/null
}

@test "ai: pi is executable" {
    [ -x "$(command -v pi)" ]
}

@test "ai: engram is installed" {
    command -v engram >/dev/null
}

@test "ai: skills directory exists" {
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
    skip "DEVCONTAINER_PHASE not set (run inside devcontainer)" if [ -z "${DEVCONTAINER_PHASE:-}" ]
    [[ "${DEVCONTAINER_PHASE:-}" =~ ^(build|runtime)$ ]]
}

@test "env: LANG is set to a UTF-8 locale" {
    [[ "${LANG:-}" =~ \.UTF-8$ ]] || [[ "${LANG:-}" =~ \.utf-8$ ]]
}