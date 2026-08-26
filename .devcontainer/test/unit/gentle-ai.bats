#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
    TEST_ROOT="$(mktemp -d)"
    BIN_DIR="${TEST_ROOT}/bin"
    INSTALL_DIR="${TEST_ROOT}/install"
    FIXTURE_DIR="${TEST_ROOT}/fixture"
    CALLS_FILE="${TEST_ROOT}/calls"
    ATTEMPTS_FILE="${TEST_ROOT}/attempts"
    AMD64_ARCHIVE_FILE="${TEST_ROOT}/gentle-ai-amd64.tar.gz"
    ARM64_ARCHIVE_FILE="${TEST_ROOT}/gentle-ai-arm64.tar.gz"
    TEST_VERSION="2.3.0"
    STALE_VERSION="2.2.0"
    INVALID_INSTALLED_VERSION="9.9.9"
    DEFAULT_FETCH_ATTEMPTS=3
    TEST_ARCH="x86_64"
    mkdir -p "${BIN_DIR}" "${INSTALL_DIR}" "${FIXTURE_DIR}"
    : >"${CALLS_FILE}"
    : >"${ATTEMPTS_FILE}"
    export REPO_ROOT TEST_ROOT BIN_DIR INSTALL_DIR FIXTURE_DIR CALLS_FILE ATTEMPTS_FILE
    export AMD64_ARCHIVE_FILE ARM64_ARCHIVE_FILE TEST_VERSION STALE_VERSION
    export INVALID_INSTALLED_VERSION DEFAULT_FETCH_ATTEMPTS TEST_ARCH
    export PATH="${BIN_DIR}:${INSTALL_DIR}:${PATH}"
    write_release_fixture "${AMD64_ARCHIVE_FILE}" amd64
    write_release_fixture "${ARM64_ARCHIVE_FILE}" arm64
    TEST_SHA256_AMD64="$(sha256sum "${AMD64_ARCHIVE_FILE}" | awk '{print $1}')"
    TEST_SHA256_ARM64="$(sha256sum "${ARM64_ARCHIVE_FILE}" | awk '{print $1}')"
    export TEST_SHA256_AMD64 TEST_SHA256_ARM64
    write_command_stubs
}

teardown() {
    rm -rf "${TEST_ROOT}"
}

write_release_fixture() {
    local archive_file="$1"
    local architecture="$2"
    cat >"${FIXTURE_DIR}/gentle-ai" <<'EOF'
#!/usr/bin/env bash
if [ "${GENTLE_AI_TEST_FAIL_INSTALLED_VERIFY:-0}" = 1 ] && [[ "$0" == "${GENTLE_AI_INSTALL_DIR}"/* ]]; then
    printf 'gentle-ai version %s\n' "${INVALID_INSTALLED_VERSION}"
else
    printf 'gentle-ai version %s\n' "${TEST_VERSION}"
fi
EOF
    printf '# fixture architecture: %s\n' "${architecture}" >>"${FIXTURE_DIR}/gentle-ai"
    chmod +x "${FIXTURE_DIR}/gentle-ai"
    tar -czf "${archive_file}" -C "${FIXTURE_DIR}" gentle-ai
}

write_command_stubs() {
    cat >"${BIN_DIR}/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${TEST_ARCH}"
EOF
    cat >"${BIN_DIR}/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
    cat >"${BIN_DIR}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl %s\n' "$*" >>"${CALLS_FILE}"
output=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o) output="$2"; shift 2 ;;
        -*) shift ;;
        *) url="$1"; shift ;;
    esac
done
case "${url}" in
    *.tar.gz)
        attempt_count="$(wc -l <"${ATTEMPTS_FILE}")"
        printf 'attempt\n' >>"${ATTEMPTS_FILE}"
        if [ "${attempt_count}" -lt "${GENTLE_AI_TEST_TRANSIENT_FAILURES:-0}" ]; then
            exit 22
        fi
        case "${url}" in
            *linux_arm64.tar.gz) cp "${ARM64_ARCHIVE_FILE}" "${output}" ;;
            *linux_amd64.tar.gz) cp "${AMD64_ARCHIVE_FILE}" "${output}" ;;
            *) printf 'unexpected archive URL: %s\n' "${url}" >&2; exit 64 ;;
        esac
        ;;
    *) printf 'unexpected URL: %s\n' "${url}" >&2; exit 64 ;;
esac
EOF
    chmod +x "${BIN_DIR}/uname" "${BIN_DIR}/sudo" "${BIN_DIR}/curl"
}

write_doctor_stubs() {
    local doctor_bin="$1"
    local command_name
    mkdir -p "${doctor_bin}"

    for command_name in task node npm pi engram gentle-ai; do
        cat >"${doctor_bin}/${command_name}" <<EOF
#!/usr/bin/env bash
printf '%s 1.0.0\n' '${command_name}'
EOF
        chmod +x "${doctor_bin}/${command_name}"
    done

    cat >"${doctor_bin}/git" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "rev-parse" ]; then
    printf '%s\n' "${REPO_ROOT}"
else
    printf 'git version 2.43.0\n'
fi
EOF
    chmod +x "${doctor_bin}/git"
}

write_installed_version() {
    local version="$1"
    cat >"${INSTALL_DIR}/gentle-ai" <<EOF
#!/usr/bin/env bash
printf 'gentle-ai version ${version}\n'
EOF
    chmod +x "${INSTALL_DIR}/gentle-ai"
}

run_installer() {
    run env \
        GENTLE_AI_VERSION="${GENTLE_AI_VERSION_OVERRIDE:-${TEST_VERSION}}" \
        GENTLE_AI_SHA256_AMD64="${GENTLE_AI_SHA256_AMD64_OVERRIDE-${TEST_SHA256_AMD64}}" \
        GENTLE_AI_SHA256_ARM64="${GENTLE_AI_SHA256_ARM64_OVERRIDE-${TEST_SHA256_ARM64}}" \
        GENTLE_AI_INSTALL_DIR="${INSTALL_DIR}" \
        GENTLE_AI_FETCH_RETRY_DELAY=0 \
        TEST_VERSION="${TEST_VERSION}" \
        INVALID_INSTALLED_VERSION="${INVALID_INSTALLED_VERSION}" \
        GENTLE_AI_TEST_TRANSIENT_FAILURES="${GENTLE_AI_TEST_TRANSIENT_FAILURES:-0}" \
        GENTLE_AI_TEST_FAIL_INSTALLED_VERIFY="${GENTLE_AI_TEST_FAIL_INSTALLED_VERIFY:-0}" \
        bash "${REPO_ROOT}/.devcontainer/install/available/30-ai-gentle-ai.sh"
}

@test "Gentle AI installer uses the pinned amd64 digest, replaces stale, and skips exact" {
    write_installed_version "${STALE_VERSION}"

    run_installer

    [ "$status" -eq 0 ]
    grep -q "gentle-ai_${TEST_VERSION}_linux_amd64.tar.gz" "${CALLS_FILE}"
    ! grep -q 'checksums.txt' "${CALLS_FILE}"
    run "${INSTALL_DIR}/gentle-ai" version
    [ "$status" -eq 0 ]
    [ "$output" = "gentle-ai version ${TEST_VERSION}" ]
    first_call_count="$(wc -l <"${CALLS_FILE}")"

    run_installer

    [ "$status" -eq 0 ]
    [ "$(wc -l <"${CALLS_FILE}")" -eq "${first_call_count}" ]
    [[ "$output" == *"already installed: ${TEST_VERSION}"* ]]
}

@test "Gentle AI installer selects the arm64 archive and digest" {
    export TEST_ARCH="aarch64"
    write_installed_version "${STALE_VERSION}"

    run_installer

    [ "$status" -eq 0 ]
    grep -q "gentle-ai_${TEST_VERSION}_linux_arm64.tar.gz" "${CALLS_FILE}"
    [ "${TEST_SHA256_AMD64}" != "${TEST_SHA256_ARM64}" ]

    write_installed_version "${STALE_VERSION}"
    GENTLE_AI_SHA256_ARM64_OVERRIDE="${TEST_SHA256_AMD64}"
    export GENTLE_AI_SHA256_ARM64_OVERRIDE
    run_installer

    [ "$status" -ne 0 ]
    [[ "$output" == *'SHA-256 mismatch'* ]]
}

@test "Gentle AI installer retries transient archive failures then succeeds" {
    export GENTLE_AI_TEST_TRANSIENT_FAILURES=2
    write_installed_version "${STALE_VERSION}"

    run_installer

    [ "$status" -eq 0 ]
    [ "$(wc -l <"${ATTEMPTS_FILE}")" -eq "${DEFAULT_FETCH_ATTEMPTS}" ]
    [[ "$output" == *"Download attempt 1 of ${DEFAULT_FETCH_ATTEMPTS} failed"* ]]
    [[ "$output" == *"Download attempt 2 of ${DEFAULT_FETCH_ATTEMPTS} failed"* ]]
}

@test "Gentle AI installer stops after three persistent archive failures" {
    export GENTLE_AI_TEST_TRANSIENT_FAILURES=99
    write_installed_version "${STALE_VERSION}"

    run_installer

    [ "$status" -ne 0 ]
    [ "$(wc -l <"${ATTEMPTS_FILE}")" -eq "${DEFAULT_FETCH_ATTEMPTS}" ]
    run "${INSTALL_DIR}/gentle-ai" version
    [ "$output" = "gentle-ai version ${STALE_VERSION}" ]
}

@test "Gentle AI installer fails closed on a pinned digest mismatch" {
    GENTLE_AI_SHA256_AMD64_OVERRIDE="$(printf '%064d' 0)"
    export GENTLE_AI_SHA256_AMD64_OVERRIDE
    write_installed_version "${STALE_VERSION}"

    run_installer

    [ "$status" -ne 0 ]
    [[ "$output" == *'SHA-256 mismatch'* ]]
    run "${INSTALL_DIR}/gentle-ai" version
    [ "$output" = "gentle-ai version ${STALE_VERSION}" ]
}

@test "Gentle AI installer validates the architecture digest before an exact-version skip" {
    GENTLE_AI_SHA256_AMD64_OVERRIDE=""
    export GENTLE_AI_SHA256_AMD64_OVERRIDE
    write_installed_version "${TEST_VERSION}"

    run_installer

    [ "$status" -ne 0 ]
    [[ "$output" == *'SHA-256 must be a 64-character lowercase digest'* ]]
    [ ! -s "${CALLS_FILE}" ]
}

@test "Gentle AI installer rejects non-exact stable versions before downloading" {
    local invalid_version
    for invalid_version in v2.3.0 2.4.0-rc.1 latest; do
        GENTLE_AI_VERSION_OVERRIDE="${invalid_version}"
        export GENTLE_AI_VERSION_OVERRIDE

        run_installer

        [ "$status" -ne 0 ]
    done
    [ ! -s "${CALLS_FILE}" ]
}

@test "Gentle AI installer restores the prior binary when final verification fails" {
    export GENTLE_AI_TEST_FAIL_INSTALLED_VERIFY=1
    write_installed_version "${STALE_VERSION}"

    run_installer

    [ "$status" -ne 0 ]
    [[ "$output" == *'restored previous binary'* ]]
    run env GENTLE_AI_TEST_FAIL_INSTALLED_VERIFY=0 "${INSTALL_DIR}/gentle-ai" version
    [ "$status" -eq 0 ]
    [ "$output" = "gentle-ai version ${STALE_VERSION}" ]
}

@test "doctor requires Gentle AI in container mode" {
    local doctor_bin="${TEST_ROOT}/doctor-bin"
    write_doctor_stubs "${doctor_bin}"

    run env PATH="${doctor_bin}:/usr/bin:/bin" \
        bash "${REPO_ROOT}/.taskfiles/scripts/doctor.sh" container

    [ "$status" -eq 0 ]
    [[ "$output" == *'[ok] gentle-ai available:'* ]]

    rm -f "${doctor_bin}/gentle-ai"
    run env PATH="${doctor_bin}:/usr/bin:/bin" \
        bash "${REPO_ROOT}/.taskfiles/scripts/doctor.sh" container

    [ "$status" -eq 1 ]
    [[ "$output" == *'[fail] gentle-ai not found'* ]]
}

@test "install helper re-enables Gentle AI at canonical slot 81" {
    local sandbox="${TEST_ROOT}/install-helper"
    mkdir -p "${sandbox}/.taskfiles/scripts" \
        "${sandbox}/.devcontainer/install/available" \
        "${sandbox}/.devcontainer/install/02-enabled"
    cp "${REPO_ROOT}/.taskfiles/scripts/install.sh" "${sandbox}/.taskfiles/scripts/install.sh"
    cp "${REPO_ROOT}/.devcontainer/install/available/30-ai-gentle-ai.sh" \
        "${sandbox}/.devcontainer/install/available/30-ai-gentle-ai.sh"
    ln -s ../available/30-ai-gentle-ai.sh \
        "${sandbox}/.devcontainer/install/02-enabled/81-gentle-ai.sh"

    run bash "${sandbox}/.taskfiles/scripts/install.sh" disable 30-ai-gentle-ai
    [ "$status" -eq 0 ]
    run bash "${sandbox}/.taskfiles/scripts/install.sh" enable 30-ai-gentle-ai

    [ "$status" -eq 0 ]
    [ -L "${sandbox}/.devcontainer/install/02-enabled/81-gentle-ai.sh" ]
    [ "$(readlink "${sandbox}/.devcontainer/install/02-enabled/81-gentle-ai.sh")" = '../available/30-ai-gentle-ai.sh' ]
    [ ! -e "${sandbox}/.devcontainer/install/02-enabled/30-ai-gentle-ai.sh" ]
}
