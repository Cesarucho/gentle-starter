#!/usr/bin/env bats

@test "Docker build ARG persists as runtime Engram ENV" {
    local root
    root="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
    command -v docker >/dev/null 2>&1 || skip "docker is unavailable"
    env -u DOCKER_CONTEXT DOCKER_HOST=unix:///var/run/docker.sock docker info >/dev/null 2>&1 || skip "local Docker daemon is unavailable"

    # Keep recovery evidence outside BATS_TEST_TMPDIR.
    run env PYTHONDONTWRITEBYTECODE=1 python3 "${root}/.maintainer/test/lifecycle/image-contract.py" \
        "${root}" "${BATS_TMPDIR:-/tmp}"
    printf '%s\n' "${output}"
    [ "$status" -eq 0 ]
}
