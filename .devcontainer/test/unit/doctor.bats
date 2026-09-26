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
    for command_name in docker task devcontainer jq node npm gh playwright; do
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
}

@test "container doctor checks applied identity and does not accept a host-only snapshot" {
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

teardown() {
    rm -rf "${TEST_ROOT}"
}

run_host_doctor() {
    run env PATH="${BIN_DIR}:/usr/bin:/bin" FORCE_HOST_CONTEXT=1 \
        bash "${REPO_ROOT}/.taskfiles/scripts/doctor.sh" host
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
    export GENTLE_VOLUME_MANIFEST_ID=inherited-container-id
    run_host_doctor
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"last host-prepared"* ]]
    [[ "${output}" == *"not proof of applied mounts"* ]]
    [[ "${output}" != *"is current"* ]]
}
