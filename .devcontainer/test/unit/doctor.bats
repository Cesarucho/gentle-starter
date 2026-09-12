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
    for command_name in docker task devcontainer jq; do
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
    '.taskfiles/scripts/compose-manifest.py service .') printf 'container-svc\n' ;;
    '.taskfiles/scripts/compose-manifest.py check .') exit 0 ;;
    *) exit 1 ;;
esac
EOF
    chmod +x "${BIN_DIR}/"*
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
