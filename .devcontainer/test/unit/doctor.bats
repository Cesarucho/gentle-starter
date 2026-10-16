#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
    TEST_ROOT="$(mktemp -d)"
    FIXTURE_ROOT="${TEST_ROOT}/repo"
    BIN_DIR="${TEST_ROOT}/bin"
    export FIXTURE_ROOT
    mkdir -p "${FIXTURE_ROOT}/.devcontainer" "${BIN_DIR}"
    touch "${FIXTURE_ROOT}/.devcontainer/"{devcontainer.json,docker-compose.yml,Dockerfile,setup.sh}
    touch "${FIXTURE_ROOT}/"{Taskfile.yml,.env.example,.env,skills-lock.json}

    local command_name
    for command_name in docker task devcontainer jq yq node npm gh playwright; do
        printf '#!/usr/bin/env bash\n[[ "$*" == "--version" ]] || exit 0\nprintf "fixture version\\n"\n' >"${BIN_DIR}/${command_name}"
    done
    cat >"${BIN_DIR}/git" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    'rev-parse --show-toplevel') printf '%s\n' "${FIXTURE_ROOT}" ;;
    '--version') printf 'git fixture version\n' ;;
    *) exit 1 ;;
esac
EOF
    cat >"${BIN_DIR}/python3" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    '.taskfiles/scripts/compose-manifest.py check .') [[ "${EXPECT_MANIFEST_CONTEXT:-host}" == host ]] ;;
    '.taskfiles/scripts/compose-manifest.py runtime .')
        [[ "${EXPECT_MANIFEST_CONTEXT:-host}" == container ]] && [[ "${REJECT_APPLIED_ID:-0}" == 0 ]] ;;
    *) exit 1 ;;
esac
EOF
    chmod +x "${BIN_DIR}/"*
    cat >"${TEST_ROOT}/missing-command-env" <<'EOF'
command() {
    if [ "$1" = -v ] && [ "$2" = "${MISSING_COMMAND}" ]; then
        return 1
    fi
    builtin command "$@"
}
EOF
}

prepare_container_checks() {
    mkdir -p "${FIXTURE_ROOT}/.devcontainer/install/lib" "${TEST_ROOT}/gitconfig-volume"
    printf 'devcontainer_install_is_active() { return 1; }\n' >"${FIXTURE_ROOT}/.devcontainer/install/lib/activation.sh"
    cat >"${TEST_ROOT}/doctor-env" <<'EOF'
function [() {
    if builtin [ "$#" -eq 3 ] && builtin [ "$1" = -d ] && builtin [ "$2" = /home/ubuntu/.gitconfig-volume ]; then
        builtin [ -d "${DOCTOR_MOUNT}" ]
    else
        builtin [ "$@"
    fi
}
EOF
}

@test "container doctor checks applied identity and does not accept a host-only snapshot" {
    prepare_container_checks
    for rejected in 0 1; do
        run env -u FORCE_HOST_CONTEXT PATH="${BIN_DIR}:/usr/bin:/bin" DEVCONTAINER=true \
            EXPECT_MANIFEST_CONTEXT=container REJECT_APPLIED_ID="${rejected}" \
            BASH_ENV="${TEST_ROOT}/doctor-env" DOCTOR_MOUNT="${TEST_ROOT}/gitconfig-volume" \
            bash "${REPO_ROOT}/.taskfiles/scripts/doctor.sh" container
        [ "${status}" -eq "${rejected}" ]
        if [ "${rejected}" -eq 0 ]; then
            [[ "${output}" == *"applied container identity verified"* ]]
        else
            [[ "${output}" == *"volume snapshot unavailable or invalid"* ]]
        fi
        [[ "${output}" != *"last host-prepared"* ]]
    done
}

@test "explicit host mode checks the stored snapshot inside a detected container" {
    run env -u FORCE_HOST_CONTEXT PATH="${BIN_DIR}:/usr/bin:/bin" DEVCONTAINER=true \
        EXPECT_MANIFEST_CONTEXT=host REJECT_APPLIED_ID=1 \
        bash "${REPO_ROOT}/.taskfiles/scripts/doctor.sh" host
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"host checks are running from inside a container"* ]]
    [[ "${output}" == *"last host-prepared"* ]]
    [[ "${output}" == *"not proof of applied mounts or current desired configuration"* ]]
    [[ "${output}" != *"applied container identity verified"* ]]
}

@test "explicit container mode checks applied identity in forced host context" {
    prepare_container_checks
    for rejected in 0 1; do
        run env PATH="${BIN_DIR}:/usr/bin:/bin" FORCE_HOST_CONTEXT=1 \
            EXPECT_MANIFEST_CONTEXT=container REJECT_APPLIED_ID="${rejected}" \
            BASH_ENV="${TEST_ROOT}/doctor-env" DOCTOR_MOUNT="${TEST_ROOT}/gitconfig-volume" \
            bash "${REPO_ROOT}/.taskfiles/scripts/doctor.sh" container
        [ "${status}" -eq "${rejected}" ]
        if [ "${rejected}" -eq 0 ]; then
            [[ "${output}" == *"applied container identity verified"* ]]
        else
            [[ "${output}" == *"volume snapshot unavailable or invalid"* ]]
        fi
        [[ "${output}" != *"last host-prepared"* ]]
    done
}

@test "auto mode retains detected container and forced host snapshot selection" {
    prepare_container_checks
    for context in container host; do
        force=1
        [ "${context}" = host ] || force=0
        run env PATH="${BIN_DIR}:/usr/bin:/bin" DEVCONTAINER=true FORCE_HOST_CONTEXT="${force}" \
            EXPECT_MANIFEST_CONTEXT="${context}" \
            BASH_ENV="${TEST_ROOT}/doctor-env" DOCTOR_MOUNT="${TEST_ROOT}/gitconfig-volume" \
            bash "${REPO_ROOT}/.taskfiles/scripts/doctor.sh" auto
        [ "${status}" -eq 0 ]
        if [ "${context}" = host ]; then
            [[ "${output}" == *"last host-prepared"* ]]
        else
            [[ "${output}" == *"applied container identity verified"* ]]
        fi
    done
}

@test "validate host reports partial proof and never invokes strict quality" {
    run env PATH="${BIN_DIR}:/usr/bin:/bin" DEVCONTAINER=true FORCE_HOST_CONTEXT=1 \
        EXPECT_MANIFEST_CONTEXT=host bash "${REPO_ROOT}/.taskfiles/scripts/doctor.sh" validate
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"last host-prepared"* ]]
    [[ "${output}" == *"partial"* ]]
    [[ "${output}" == *"task validate inside the container"* ]]
    [[ "${output}" != *"applied container identity verified"* ]]
}

@test "validate container runs strict quality after container diagnosis" {
    prepare_container_checks
    run env PATH="${BIN_DIR}:/usr/bin:/bin" DEVCONTAINER=true \
        EXPECT_MANIFEST_CONTEXT=container BASH_ENV="${TEST_ROOT}/doctor-env" \
        DOCTOR_MOUNT="${TEST_ROOT}/gitconfig-volume" \
        bash "${REPO_ROOT}/.taskfiles/scripts/doctor.sh" validate
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"applied container identity verified"* ]]
    [[ "${output}" != *"Host validation is partial"* ]]
}

@test "context mode uses the same detection as auto including the host override" {
    for context in container host; do
        force=0
        [ "${context}" = container ] || force=1
        run env PATH="${BIN_DIR}:/usr/bin:/bin" DEVCONTAINER=true FORCE_HOST_CONTEXT="${force}" \
            bash "${REPO_ROOT}/.taskfiles/scripts/doctor.sh" context
        [ "${status}" -eq 0 ]
        [ "${output}" = "${context}" ]
    done
}

teardown() {
    rm -rf "${TEST_ROOT}"
}

run_host_doctor() {
    run env PATH="${BIN_DIR}:/usr/bin:/bin" FORCE_HOST_CONTEXT=1 \
        bash "${REPO_ROOT}/.taskfiles/scripts/doctor.sh" host
}

@test "host doctor reports every required command when unavailable" {
    local missing
    for missing in git task docker devcontainer jq yq python3; do
        run env PATH="${BIN_DIR}:/usr/bin:/bin" FORCE_HOST_CONTEXT=1 \
            MISSING_COMMAND="${missing}" BASH_ENV="${TEST_ROOT}/missing-command-env" \
            bash "${REPO_ROOT}/.taskfiles/scripts/doctor.sh" host

        [ "${status}" -eq 1 ]
        [[ "${output}" == *"[fail] ${missing} not found; install "*" on the host and rerun task validate"* ]]
        [[ "${output}" == *"Summary: 1 error(s)"* ]]
    done
}

@test "host doctor reports all seven prerequisites when available" {
    mkdir "${FIXTURE_ROOT}/.env.d"

    run_host_doctor

    [ "${status}" -eq 0 ]
    local required
    for required in git task docker devcontainer jq yq python3; do
        [[ "${output}" == *"[ok] ${required} available:"* ]]
    done
    [[ "${output}" == *"Summary: 0 error(s), 0 warning(s)"* ]]
}

@test "host doctor accepts .env.d without the legacy env directory" {
    mkdir "${FIXTURE_ROOT}/.env.d"

    run_host_doctor

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[ok] directory exists: .env.d"* ]]
    [[ "${output}" != *"[warn] directory missing: env"* ]]
    [[ "${output}" == *"Summary: 0 error(s), 0 warning(s)"* ]]
    [ ! -e "${FIXTURE_ROOT}/env" ]
}

@test "host doctor warns without failing or creating missing .env.d" {
    run_host_doctor

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[warn] directory missing: .env.d"* ]]
    [[ "${output}" != *"[warn] directory missing: env"* ]]
    [[ "${output}" == *"Summary: 0 error(s), 1 warning(s)"* ]]
    [ ! -e "${FIXTURE_ROOT}/.env.d" ]
    [ ! -e "${FIXTURE_ROOT}/env" ]
}

@test "host snapshot report does not infer runtime from inherited applied identity" {
    export DEVCONTAINER_BIND_MANIFEST_ID=inherited-container-id
    run_host_doctor
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"last host-prepared"* ]]
    [[ "${output}" == *"not proof of applied mounts"* ]]
    [[ "${output}" != *"is current"* ]]
}
