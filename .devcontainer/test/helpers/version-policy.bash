#!/usr/bin/env bash

# Call from a Bats test; callers own assertions and env unset/override arguments.
run_version_policy() {
    local installer="$1" policy="$2"
    shift 2
    run env "$@" DEVCONTAINER_TOOL_VERSIONS_FILE="${policy}" \
        bash "${installer}" --print-version-policy
}
