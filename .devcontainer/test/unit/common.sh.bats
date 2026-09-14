#!/usr/bin/env bats
#
# common.sh.bats — unit tests for .devcontainer/install/lib/common.sh
#
# Run from the repo root:
#   bats .devcontainer/test/unit/common.sh.bats
#

SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
COMMON_SH="${SCRIPT_DIR}/install/lib/common.sh"

# ---------------------------------------------------------------------------
# Setup and teardown
# ---------------------------------------------------------------------------

setup() {
    # Reset DEVCONTAINER_TOOL_VERSION before each test.
    export DEVCONTAINER_TOOL_VERSION=""
}

# ---------------------------------------------------------------------------
# Re-source guard
# ---------------------------------------------------------------------------

@test "re-source guard: sourcing twice returns 0" {
    run bash -c "source '${COMMON_SH}' && source '${COMMON_SH}' && echo 'ok'"
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

# ---------------------------------------------------------------------------
# Phase detection
# ---------------------------------------------------------------------------

@test "devcontainer_phase returns build when DEVCONTAINER_PHASE is unset" {
    run bash -c "source '${COMMON_SH}' && devcontainer_phase"
    [ "$status" -eq 0 ]
    [ "$output" = "build" ]
}

@test "devcontainer_phase returns runtime when DEVCONTAINER_PHASE=runtime" {
    run bash -c "source '${COMMON_SH}' && DEVCONTAINER_PHASE=runtime devcontainer_phase"
    [ "$status" -eq 0 ]
    [ "$output" = "runtime" ]
}

@test "devcontainer_is_build returns 0 when DEVCONTAINER_PHASE=build" {
    run bash -c "source '${COMMON_SH}' && DEVCONTAINER_PHASE=build devcontainer_is_build"
    [ "$status" -eq 0 ]
}

@test "devcontainer_is_build returns 1 when DEVCONTAINER_PHASE=runtime" {
    run bash -c "source '${COMMON_SH}' && DEVCONTAINER_PHASE=runtime devcontainer_is_build"
    [ "$status" -ne 0 ]
}

@test "devcontainer_is_runtime returns 0 when DEVCONTAINER_PHASE=runtime" {
    run bash -c "source '${COMMON_SH}' && DEVCONTAINER_PHASE=runtime devcontainer_is_runtime"
    [ "$status" -eq 0 ]
}

@test "devcontainer_is_runtime returns 1 when DEVCONTAINER_PHASE=build" {
    run bash -c "source '${COMMON_SH}' && DEVCONTAINER_PHASE=build devcontainer_is_runtime"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Command and path checks
# ---------------------------------------------------------------------------

@test "devcontainer_has_cmd returns 0 for existing command" {
    run bash -c "source '${COMMON_SH}' && devcontainer_has_cmd bash"
    [ "$status" -eq 0 ]
}

@test "devcontainer_has_cmd returns 1 for nonexistent command" {
    run bash -c "source '${COMMON_SH}' && devcontainer_has_cmd totallynonexistentcmd123"
    [ "$status" -ne 0 ]
}

@test "devcontainer_has_path returns 0 for existing path" {
    run bash -c "source '${COMMON_SH}' && devcontainer_has_path /tmp"
    [ "$status" -eq 0 ]
}

@test "devcontainer_has_path returns 1 for nonexistent path" {
    run bash -c "source '${COMMON_SH}' && devcontainer_has_path /tmp/this/does/not/exist/xyz789"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

@test "devcontainer_log_info writes to stdout with install:info prefix" {
    run bash -c "source '${COMMON_SH}' && devcontainer_log_info 'hello world'"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "[install:info] hello world" ]
}

@test "devcontainer_log_warn writes to stderr with install:warn prefix" {
    run bash -c "source '${COMMON_SH}' && devcontainer_log_warn 'warn message' 2>&1"
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "[install:warn] warn message" ]]
}

@test "devcontainer_log_error writes to stderr with install:error prefix" {
    run bash -c "source '${COMMON_SH}' && devcontainer_log_error 'error message' 2>&1"
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "[install:error] error message" ]]
}

# ---------------------------------------------------------------------------
# Fetching and integrity
# ---------------------------------------------------------------------------

@test "devcontainer_fetch downloads a file successfully" {
    run bash -c "source '${COMMON_SH}' && tmp=\$(mktemp) && devcontainer_fetch 'https://example.com' \"\${tmp}\" && rm -f \"\${tmp}\""
    [ "$status" -eq 0 ]
}

@test "devcontainer_fetch fails on invalid URL" {
    run bash -c "source '${COMMON_SH}' && tmp=\$(mktemp) && devcontainer_fetch 'https://this-domain-does-not-exist-xyz123.invalid/file' \"\${tmp}\"; r=\$?; rm -f \"\${tmp}\"; exit \${r}"
    [ "$status" -ne 0 ]
}

@test "devcontainer_verify_sha256 passes with correct hash" {
    run bash -c "source '${COMMON_SH}' && tmp=\$(mktemp) && echo -n 'hello' > \"\${tmp}\" && devcontainer_verify_sha256 \"\${tmp}\" '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824' && rm -f \"\${tmp}\""
    [ "$status" -eq 0 ]
}

@test "devcontainer_verify_sha256 fails with incorrect hash" {
    run bash -c "source '${COMMON_SH}' && tmp=\$(mktemp) && echo -n 'hello' > \"\${tmp}\" && devcontainer_verify_sha256 \"\${tmp}\" '0000000000000000000000000000000000000000000000000000000000000000'; r=\$?; rm -f \"\${tmp}\"; exit \${r}"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Version extraction
# ---------------------------------------------------------------------------

@test "_devcontainer_get_version extracts go version" {
    go() { echo "go version go1.22.3 linux/amd64"; }
    export -f go
    run bash -c "source '${COMMON_SH}' && _devcontainer_get_version go && echo \"\${DEVCONTAINER_TOOL_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "1.22.3" ]
}

@test "_devcontainer_get_version extracts node version with v prefix" {
    node() { echo "v20.5.0"; }
    export -f node
    run bash -c "source '${COMMON_SH}' && _devcontainer_get_version node && echo \"\${DEVCONTAINER_TOOL_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "20.5.0" ]
}

@test "_devcontainer_get_version extracts java-version style output (X.Y pattern)" {
    fake_java() { echo 'java version "21"'; }
    export -f fake_java
    run bash -c "source '${COMMON_SH}' && _devcontainer_get_version fake_java && printf '%s' \"\${DEVCONTAINER_TOOL_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "21" ]
}

@test "_devcontainer_get_version extracts generic X.Y.Z version" {
    fake() { echo "fake version 1.2.3-beta"; }
    export -f fake
    run bash -c "source '${COMMON_SH}' && _devcontainer_get_version fake && echo \"\${DEVCONTAINER_TOOL_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3" ]
}

@test "_devcontainer_get_version extracts generic X.Y version as fallback" {
    fake() { echo "tool v3.14"; }
    export -f fake
    run bash -c "source '${COMMON_SH}' && _devcontainer_get_version fake && echo \"\${DEVCONTAINER_TOOL_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "3.14" ]
}

@test "_devcontainer_get_version returns 1 for nonexistent command" {
    run bash -c "source '${COMMON_SH}' && _devcontainer_get_version totallynonexistentcmd456"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Version comparison
# ---------------------------------------------------------------------------

@test "_devcontainer_version_compare: 1.22.0 >= 1.20.0" {
    run bash -c "source '${COMMON_SH}' && _devcontainer_version_compare '1.22.0' '1.20.0'"
    [ "$status" -eq 0 ]
}

@test "_devcontainer_version_compare: 1.20.0 >= 1.22.0 is false" {
    run bash -c "source '${COMMON_SH}' && _devcontainer_version_compare '1.20.0' '1.22.0'"
    [ "$status" -ne 0 ]
}

@test "_devcontainer_version_compare: equal versions satisfy" {
    run bash -c "source '${COMMON_SH}' && _devcontainer_version_compare '1.20.0' '1.20.0'"
    [ "$status" -eq 0 ]
}

@test "_devcontainer_version_compare: 1.26.4 >= 99.0 is false (numeric 1.26 < 99)" {
    run bash -c "source '${COMMON_SH}' && _devcontainer_version_compare '1.26.4' '99.0'"
    [ "$status" -ne 0 ]
}

@test "_devcontainer_version_compare: 99.0 >= 1.26.4" {
    run bash -c "source '${COMMON_SH}' && _devcontainer_version_compare '99.0' '1.26.4'"
    [ "$status" -eq 0 ]
}

@test "_devcontainer_version_compare: 20.5.0 >= 20.0.0" {
    run bash -c "source '${COMMON_SH}' && _devcontainer_version_compare '20.5.0' '20.0.0'"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Idempotence helpers
# ---------------------------------------------------------------------------

@test "devcontainer_check_tool returns 0 for existing command without version" {
    run bash -c "source '${COMMON_SH}' && devcontainer_check_tool bash"
    [ "$status" -eq 0 ]
}

@test "devcontainer_check_tool returns 1 for nonexistent command" {
    run bash -c "source '${COMMON_SH}' && devcontainer_check_tool totallynonexistentcmd789"
    [ "$status" -ne 0 ]
}

@test "devcontainer_check_tool_with_version sets DEVCONTAINER_TOOL_VERSION" {
    fake_tool() { echo "fake-tool v3.14"; }
    export -f fake_tool
    run bash -c "source '${COMMON_SH}' && devcontainer_check_tool_with_version fake_tool 3.0 && printf '%s' \"\${DEVCONTAINER_TOOL_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "3.14" ]
}

@test "devcontainer_with_tool skips install when tool is sufficient" {
    fake_tool() { echo "fake-tool v9.0"; }
    export -f fake_tool
    run bash -c "source '${COMMON_SH}' && devcontainer_with_tool fake_tool 8.0 'echo INSTALLED'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipping fake_tool"* ]]
    [[ "$output" != *"INSTALLED"* ]]
}

@test "devcontainer_with_tool calls install_fn when tool is missing" {
    run bash -c "source '${COMMON_SH}' && devcontainer_with_tool totallynonexistentcmd999 1.0 'echo INSTALLED'"
    [ "$status" -eq 0 ]
    [[ "$output" == "INSTALLED" ]]
}

    @test "devcontainer_with_tool calls install_fn when version is insufficient" {
        fake_tool() { echo "fake-tool v0.1.0"; }
        export -f fake_tool
        run bash -c "source '${COMMON_SH}' && devcontainer_with_tool fake_tool 9.0 'echo INSTALLED'"
        [ "$status" -eq 0 ]
        [[ "$output" == "INSTALLED" ]]
    }
# ---------------------------------------------------------------------------
# Declarative tool-version policy
# ---------------------------------------------------------------------------

@test "tool versions loader accepts quoted assignments comments and blank lines" {
    file="${BATS_TEST_TMPDIR}/valid.conf"
    cat >"${file}" <<'EOF'
# comment

TOOL_ALPHA_VERSION="1.2.3"
LOCK_BETA_MAJOR='26'
EOF
	run bash -c "source '${COMMON_SH}' && devcontainer_load_tool_versions '${file}' && printf '%s|%s' \"\${TOOL_ALPHA_VERSION}\" \"\${LOCK_BETA_MAJOR}\""
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3|26" ]
}

@test "tool versions loader rejects command substitution" {
    file="${BATS_TEST_TMPDIR}/substitution.conf"
    printf '%s\n' 'TOOL_BAD_VERSION="$(id)"' >"${file}"
    run bash -c "source '${COMMON_SH}' && devcontainer_load_tool_versions '${file}'"
    [ "$status" -ne 0 ]
}

@test "tool versions loader rejects backticks" {
    file="${BATS_TEST_TMPDIR}/backticks.conf"
    printf '%s\n' 'TOOL_BAD_VERSION="`id`"' >"${file}"
    run bash -c "source '${COMMON_SH}' && devcontainer_load_tool_versions '${file}'"
    [ "$status" -ne 0 ]
}

@test "tool versions loader rejects commands and functions" {
    for content in 'echo bad' 'bad() { echo bad; }'; do
        file="${BATS_TEST_TMPDIR}/command.conf"
        printf '%s\n' "${content}" >"${file}"
        run bash -c "source '${COMMON_SH}' && devcontainer_load_tool_versions '${file}'"
        [ "$status" -ne 0 ]
    done
}

@test "tool versions loader rejects export and non TOOL keys" {
    for content in 'export TOOL_BAD_VERSION="1"' 'BAD_VERSION="1"'; do
        file="${BATS_TEST_TMPDIR}/foreign.conf"
        printf '%s\n' "${content}" >"${file}"
        run bash -c "source '${COMMON_SH}' && devcontainer_load_tool_versions '${file}'"
        [ "$status" -ne 0 ]
    done
}

@test "tool versions loader rejects duplicate keys" {
    file="${BATS_TEST_TMPDIR}/duplicate.conf"
    printf '%s\n' 'TOOL_BAD_VERSION="1"' 'TOOL_BAD_VERSION="2"' >"${file}"
    run bash -c "source '${COMMON_SH}' && devcontainer_load_tool_versions '${file}'"
    [ "$status" -ne 0 ]
}

@test "tool versions loader rejects a missing explicit file" {
    run bash -c "source '${COMMON_SH}' && DEVCONTAINER_TOOL_VERSIONS_FILE='${BATS_TEST_TMPDIR}/missing.conf' devcontainer_load_tool_versions"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "tool versions path selects build copy" {
    root="${BATS_TEST_TMPDIR}/build"
    mkdir -p "${root}/lib"
    cp "${COMMON_SH}" "${root}/lib/common.sh"
    printf '%s\n' 'TOOL_BUILD_VERSION="1"' >"${root}/tool-versions.conf"
    run bash -c "source '${root}/lib/common.sh' && devcontainer_load_tool_versions && printf '%s' \"\${TOOL_BUILD_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "tool versions path selects runtime repository copy" {
    root="${BATS_TEST_TMPDIR}/repo/.devcontainer"
    mkdir -p "${root}/install/lib"
    cp "${COMMON_SH}" "${root}/install/lib/common.sh"
    printf '%s\n' 'TOOL_RUNTIME_VERSION="2"' >"${root}/tool-versions.conf"
    run bash -c "cd / && source '${root}/install/lib/common.sh' && devcontainer_load_tool_versions && printf '%s' \"\${TOOL_RUNTIME_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "approved environment override wins over generated lock" {
    file="${BATS_TEST_TMPDIR}/precedence.conf"
	printf '%s\n' 'LOCK_ENGRAM_VERSION="1.17.0"' >"${file}"
	run bash -c "source '${COMMON_SH}' && devcontainer_load_tool_versions '${file}' && ENGRAM_VERSION='9.9.9' && : \"\${ENGRAM_VERSION:=\${LOCK_ENGRAM_VERSION:?missing LOCK_ENGRAM_VERSION}}\" && printf '%s' \"\${ENGRAM_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "9.9.9" ]
}

@test "generated lock supplies the installer value" {
    file="${BATS_TEST_TMPDIR}/central.conf"
	printf '%s\n' 'LOCK_ENGRAM_VERSION="1.17.0"' >"${file}"
	run bash -c "source '${COMMON_SH}' && devcontainer_load_tool_versions '${file}' && : \"\${ENGRAM_VERSION:=\${LOCK_ENGRAM_VERSION:?missing LOCK_ENGRAM_VERSION}}\" && printf '%s' \"\${ENGRAM_VERSION}\""
    [ "$status" -eq 0 ]
    [ "$output" = "1.17.0" ]
}

@test "Dockerfile preserves existing Engram, Node, and Playwright ARG and ENV overrides" {
    run grep -F 'ARG ENGRAM_VERSION=' "${SCRIPT_DIR}/Dockerfile"
    [ "$status" -eq 0 ]
    run grep -F 'ENV ENGRAM_VERSION=${ENGRAM_VERSION}' "${SCRIPT_DIR}/Dockerfile"
    [ "$status" -eq 0 ]
    run grep -F 'ARG NODE_MAJOR=' "${SCRIPT_DIR}/Dockerfile"
    [ "$status" -eq 0 ]
    run grep -F 'ENV NODE_MAJOR=${NODE_MAJOR}' "${SCRIPT_DIR}/Dockerfile"
    [ "$status" -eq 0 ]
    run grep -F 'ARG PLAYWRIGHT_VERSION=' "${SCRIPT_DIR}/Dockerfile"
    [ "$status" -eq 0 ]
    run grep -F 'ENV PLAYWRIGHT_VERSION=${PLAYWRIGHT_VERSION}' "${SCRIPT_DIR}/Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Java installer resolves central install and observable requirement locks" {
    file="${BATS_TEST_TMPDIR}/java-central.conf"
    printf '%s\n' \
		'LOCK_JAVA_INSTALL_VERSION="25-tem"' \
		'LOCK_JAVA_REQUIRED_VERSION="25"' >"${file}"

    run env -u JAVA_VERSION -u JAVA_REQUIRED_VERSION \
        DEVCONTAINER_TOOL_VERSIONS_FILE="${file}" \
        bash "${SCRIPT_DIR}/install/available/2200-runtime-java.sh" --print-version-policy

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "JAVA_VERSION=25-tem" ]
    [ "${lines[1]}" = "JAVA_REQUIRED_VERSION=25" ]
}

@test "Java installer environment overrides central values" {
    file="${BATS_TEST_TMPDIR}/java-override.conf"
    printf '%s\n' \
		'LOCK_JAVA_INSTALL_VERSION="25-tem"' \
		'LOCK_JAVA_REQUIRED_VERSION="25"' >"${file}"

    run env \
        DEVCONTAINER_TOOL_VERSIONS_FILE="${file}" \
        JAVA_VERSION="26-tem" \
        JAVA_REQUIRED_VERSION="26" \
        bash "${SCRIPT_DIR}/install/available/2200-runtime-java.sh" --print-version-policy

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "JAVA_VERSION=26-tem" ]
    [ "${lines[1]}" = "JAVA_REQUIRED_VERSION=26" ]
}

@test "Engram installer resolves the central value" {
    file="${BATS_TEST_TMPDIR}/engram-central.conf"
	printf '%s\n' 'LOCK_ENGRAM_VERSION="1.17.0"' >"${file}"

    run env -u ENGRAM_VERSION \
        DEVCONTAINER_TOOL_VERSIONS_FILE="${file}" \
        bash "${SCRIPT_DIR}/install/available/3010-ai-engram.sh" --print-version-policy

    [ "$status" -eq 0 ]
    [ "$output" = "ENGRAM_VERSION=1.17.0" ]
}

@test "Docker-style Engram environment override wins in the installer" {
    file="${BATS_TEST_TMPDIR}/engram-override.conf"
    printf '%s\n' 'TOOL_ENGRAM_VERSION="1.17.0"' >"${file}"

    run env \
        DEVCONTAINER_TOOL_VERSIONS_FILE="${file}" \
        ENGRAM_VERSION="9.9.9" \
        bash "${SCRIPT_DIR}/install/available/3010-ai-engram.sh" --print-version-policy

    [ "$status" -eq 0 ]
    [ "$output" = "ENGRAM_VERSION=9.9.9" ]
}

@test "Phase 3A installers resolve central exact values" {
    local policy_file="${BATS_TEST_TMPDIR}/phase-3a-tool-versions.conf"
    local case_entry script_name environment_name expected_version
    local -a cases=(
        '3030-ai-pi-coding.sh|PI_CODING_AGENT_VERSION|9.9.1'
        '3050-ai-skills.sh|SKILLS_VERSION|9.9.2'
        '2020-node-markdownlint.sh|MARKDOWNLINT_CLI2_VERSION|9.9.3'
        '2050-node-mermaid.sh|MERMAID_CLI_VERSION|9.9.4'
        '2400-python-graphify.sh|GRAPHIFY_VERSION|9.9.5'
        '2080-browser-playwright.sh|PLAYWRIGHT_VERSION|9.9.6'
    )

    cat >"${policy_file}" <<'EOF'
LOCK_PI_CODING_AGENT_VERSION="9.9.1"
LOCK_SKILLS_VERSION="9.9.2"
LOCK_MARKDOWNLINT_CLI2_VERSION="9.9.3"
LOCK_MERMAID_CLI_VERSION="9.9.4"
LOCK_GRAPHIFY_VERSION="9.9.5"
LOCK_PLAYWRIGHT_VERSION="9.9.6"
LOCK_PLAYWRIGHT_CLI_VERSION="9.9.7"
EOF

    for case_entry in "${cases[@]}"; do
        IFS='|' read -r script_name environment_name expected_version <<<"${case_entry}"
        run env -u "${environment_name}" -u PLAYWRIGHT_CLI_VERSION \
            DEVCONTAINER_TOOL_VERSIONS_FILE="${policy_file}" \
            bash "${SCRIPT_DIR}/install/available/${script_name}" --print-version-policy

        [ "$status" -eq 0 ]
        if [ "${script_name}" = "2080-browser-playwright.sh" ]; then
			[ "$output" = "${environment_name}=${expected_version}"$'\n''PLAYWRIGHT_CLI_VERSION=9.9.7' ]
        else
            [ "$output" = "${environment_name}=${expected_version}" ]
        fi
    done
}

@test "Phase 3A installer environment overrides win over central values" {
    local policy_file="${SCRIPT_DIR}/tool-versions.conf"
    local case_entry script_name environment_name
    local -a cases=(
        '3030-ai-pi-coding.sh|PI_CODING_AGENT_VERSION'
        '3050-ai-skills.sh|SKILLS_VERSION'
        '2020-node-markdownlint.sh|MARKDOWNLINT_CLI2_VERSION'
        '2050-node-mermaid.sh|MERMAID_CLI_VERSION'
        '2400-python-graphify.sh|GRAPHIFY_VERSION'
        '2080-browser-playwright.sh|PLAYWRIGHT_VERSION'
    )

    for case_entry in "${cases[@]}"; do
        IFS='|' read -r script_name environment_name <<<"${case_entry}"
        run env -u PLAYWRIGHT_CLI_VERSION \
            DEVCONTAINER_TOOL_VERSIONS_FILE="${policy_file}" \
            "${environment_name}=9.9.9" \
            bash "${SCRIPT_DIR}/install/available/${script_name}" --print-version-policy

        [ "$status" -eq 0 ]
        if [ "${script_name}" = "2080-browser-playwright.sh" ]; then
			expected_cli="$(sed -n 's/^LOCK_PLAYWRIGHT_CLI_VERSION="\([^"]*\)"$/\1/p' "${policy_file}")"
			[ "$output" = "${environment_name}=9.9.9"$'\n'"PLAYWRIGHT_CLI_VERSION=${expected_cli}" ]
        else
            [ "$output" = "${environment_name}=9.9.9" ]
        fi
    done
}

@test "Phase 3B installers resolve central direct-download values" {
    local policy_file="${BATS_TEST_TMPDIR}/phase-3b-tool-versions.conf"
    local case_entry script_name environment_name expected_version
    local -a cases=(
        '6040-cli-terraform.sh|TERRAFORM_VERSION|9.9.1'
        '5010-cli-gitleaks.sh|GITLEAKS_VERSION|9.9.2'
        '6030-cli-pulumi.sh|PULUMI_VERSION|9.9.3'
        '6020-cli-opentofu.sh|OPENTOFU_VERSION|9.9.4'
        '6050-cli-terragrunt.sh|TERRAGRUNT_VERSION|9.9.5'
        '6010-cli-kubectl.sh|KUBECTL_VERSION|9.9.6'
        '2210-cli-plantuml.sh|PLANTUML_VERSION|9.9.7'
        '2110-go-debug.sh|DELVE_VERSION|v9.9.8'
        '3020-ai-gentle-ai.sh|GENTLE_AI_VERSION|9.9.9'
    )

    cat >"${policy_file}" <<'EOF'
LOCK_TERRAFORM_VERSION="9.9.1"
LOCK_GITLEAKS_VERSION="9.9.2"
LOCK_PULUMI_VERSION="9.9.3"
LOCK_OPENTOFU_VERSION="9.9.4"
LOCK_TERRAGRUNT_VERSION="9.9.5"
LOCK_KUBECTL_VERSION="9.9.6"
LOCK_PLANTUML_VERSION="9.9.7"
LOCK_PLANTUML_SHA256="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
LOCK_DELVE_VERSION="v9.9.8"
LOCK_GENTLE_AI_VERSION="9.9.9"
LOCK_GENTLE_AI_SHA256_AMD64="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
LOCK_GENTLE_AI_SHA256_ARM64="cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
EOF

    for case_entry in "${cases[@]}"; do
        IFS='|' read -r script_name environment_name expected_version <<<"${case_entry}"
        run env -u "${environment_name}" \
            DEVCONTAINER_TOOL_VERSIONS_FILE="${policy_file}" \
            bash "${SCRIPT_DIR}/install/available/${script_name}" --print-version-policy

        [ "$status" -eq 0 ]
		if [ "${script_name}" = "2210-cli-plantuml.sh" ]; then
			[ "$output" = "${environment_name}=${expected_version}"$'\n''PLANTUML_SHA256=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' ]
		else
        [ "$output" = "${environment_name}=${expected_version}" ]
		fi
    done
}

@test "Phase 3B installer environment overrides win over central values" {
    local policy_file="${SCRIPT_DIR}/tool-versions.conf"
    local case_entry script_name environment_name override_version
    local -a cases=(
        '6040-cli-terraform.sh|TERRAFORM_VERSION|8.8.1'
        '5010-cli-gitleaks.sh|GITLEAKS_VERSION|8.8.2'
        '6030-cli-pulumi.sh|PULUMI_VERSION|8.8.3'
        '6020-cli-opentofu.sh|OPENTOFU_VERSION|8.8.4'
        '6050-cli-terragrunt.sh|TERRAGRUNT_VERSION|8.8.5'
        '6010-cli-kubectl.sh|KUBECTL_VERSION|8.8.6'
        '2210-cli-plantuml.sh|PLANTUML_VERSION|8.8.7'
        '2110-go-debug.sh|DELVE_VERSION|v8.8.8'
        '3020-ai-gentle-ai.sh|GENTLE_AI_VERSION|8.8.9'
    )

    for case_entry in "${cases[@]}"; do
        IFS='|' read -r script_name environment_name override_version <<<"${case_entry}"
        run env \
            DEVCONTAINER_TOOL_VERSIONS_FILE="${policy_file}" \
            "${environment_name}=${override_version}" \
            bash "${SCRIPT_DIR}/install/available/${script_name}" --print-version-policy

        [ "$status" -eq 0 ]
		if [ "${script_name}" = "2210-cli-plantuml.sh" ]; then
			[ "$output" = "${environment_name}=${override_version}"$'\n''PLANTUML_SHA256=0f77e5f769836b3dee340e207fe497c3e4c43e973d559e3c306915da9c32e34c' ]
		else
        [ "$output" = "${environment_name}=${override_version}" ]
		fi
    done
}

@test "Phase 3C-A installers resolve central semantic and floating policies" {
    local policy_file="${BATS_TEST_TMPDIR}/phase-3c-a-tool-versions.conf"
    local case_entry script_name environment_name expected_value
    local -a cases=(
        '2000-runtime-node.sh|NODE_MAJOR|99'
        '2100-runtime-go.sh|GO_VERSION|go9.9.1'
        '2010-runtime-pnpm.sh|PNPM_VERSION|9.9.2'
        '2060-node-test.sh|VITEST_VERSION|9.9.3'
        '2300-php-lang.sh|PHP_VERSION|9.9'
        '2320-php-test.sh|PHPUNIT_VERSION|99'
        '2080-browser-playwright.sh|PLAYWRIGHT_CLI_VERSION|9.9.4'
        '2030-tool-devcontainer-cli.sh|DEVCONTAINER_CLI_VERSION|9.9.5'
    )

    cat >"${policy_file}" <<'EOF'
LOCK_NODE_MAJOR="99"
LOCK_GO_VERSION="go9.9.1"
LOCK_PNPM_VERSION="9.9.2"
LOCK_VITEST_VERSION="9.9.3"
LOCK_PHP_SERIES="9.9"
LOCK_PHPUNIT_VERSION="99"
LOCK_PLAYWRIGHT_VERSION="9.9.6"
LOCK_PLAYWRIGHT_CLI_VERSION="9.9.4"
LOCK_DEVCONTAINER_CLI_VERSION="9.9.5"
EOF

    for case_entry in "${cases[@]}"; do
        IFS='|' read -r script_name environment_name expected_value <<<"${case_entry}"
        run env -u "${environment_name}" -u PLAYWRIGHT_VERSION \
            DEVCONTAINER_TOOL_VERSIONS_FILE="${policy_file}" \
            bash "${SCRIPT_DIR}/install/available/${script_name}" --print-version-policy

        [ "$status" -eq 0 ]
        if [ "${script_name}" = "2080-browser-playwright.sh" ]; then
			[ "$output" = "PLAYWRIGHT_VERSION=9.9.6"$'\n'"${environment_name}=${expected_value}" ]
        else
            [ "$output" = "${environment_name}=${expected_value}" ]
        fi
    done
}

@test "Phase 3C-A installer environment overrides win over central policies" {
    local policy_file="${SCRIPT_DIR}/tool-versions.conf"
    local case_entry script_name environment_name override_value playwright_version
	playwright_version="$(awk -F '="' '$1 == "LOCK_PLAYWRIGHT_VERSION" { sub(/"$/, "", $2); print $2 }' "${policy_file}")"
    local -a cases=(
        '2000-runtime-node.sh|NODE_MAJOR|88'
        '2100-runtime-go.sh|GO_VERSION|go8.8.1'
        '2010-runtime-pnpm.sh|PNPM_VERSION|8.8.2'
        '2060-node-test.sh|VITEST_VERSION|8.8.3'
        '2300-php-lang.sh|PHP_VERSION|8.8'
        '2320-php-test.sh|PHPUNIT_VERSION|88'
        '2080-browser-playwright.sh|PLAYWRIGHT_CLI_VERSION|8.8.4'
        '2030-tool-devcontainer-cli.sh|DEVCONTAINER_CLI_VERSION|8.8.5'
    )

    for case_entry in "${cases[@]}"; do
        IFS='|' read -r script_name environment_name override_value <<<"${case_entry}"
        run env -u PLAYWRIGHT_VERSION \
            DEVCONTAINER_TOOL_VERSIONS_FILE="${policy_file}" \
            "${environment_name}=${override_value}" \
            bash "${SCRIPT_DIR}/install/available/${script_name}" --print-version-policy

        [ "$status" -eq 0 ]
        if [ "${script_name}" = "2080-browser-playwright.sh" ]; then
            [ "$output" = "PLAYWRIGHT_VERSION=${playwright_version}"$'\n'"${environment_name}=${override_value}" ]
        else
            [ "$output" = "${environment_name}=${override_value}" ]
        fi
    done
}

@test "Phase 3C-B Gentle Pi package versions resolve central exact values" {
    local policy_file="${BATS_TEST_TMPDIR}/phase-3c-b-tool-versions.conf"
    local expected_output

    cat >"${policy_file}" <<'EOF'
LOCK_GENTLE_PI_VERSION="9.9.1"
LOCK_PI_SUBAGENTS_VERSION="9.9.2"
LOCK_PI_INTERCOM_VERSION="9.9.3"
LOCK_PI_WEB_ACCESS_VERSION="9.9.4"
LOCK_PI_LENS_VERSION="9.9.5"
LOCK_RPIV_TODO_VERSION="9.9.6"
LOCK_RPIV_ASK_USER_QUESTION_VERSION="9.9.7"
LOCK_RPIV_BTW_VERSION="9.9.8"
LOCK_GENTLE_ENGRAM_VERSION="9.9.9"
LOCK_PI_MCP_ADAPTER_VERSION="9.9.10"
LOCK_PI_TERMINAL_THEME_VERSION="9.9.12"
EOF

	expected_output="$(
		cat <<'EOF'
GENTLE_PI_VERSION=9.9.1
PI_SUBAGENTS_VERSION=9.9.2
PI_INTERCOM_VERSION=9.9.3
PI_WEB_ACCESS_VERSION=9.9.4
PI_LENS_VERSION=9.9.5
RPIV_TODO_VERSION=9.9.6
RPIV_ASK_USER_QUESTION_VERSION=9.9.7
RPIV_BTW_VERSION=9.9.8
GENTLE_ENGRAM_VERSION=9.9.9
PI_MCP_ADAPTER_VERSION=9.9.10
PI_TERMINAL_THEME_VERSION=9.9.12
EOF
)"

    run env \
        -u GENTLE_PI_VERSION \
        -u PI_SUBAGENTS_VERSION \
        -u PI_INTERCOM_VERSION \
        -u PI_WEB_ACCESS_VERSION \
        -u PI_LENS_VERSION \
        -u RPIV_TODO_VERSION \
        -u RPIV_ASK_USER_QUESTION_VERSION \
        -u RPIV_BTW_VERSION \
        -u GENTLE_ENGRAM_VERSION \
        -u PI_MCP_ADAPTER_VERSION \
        -u PI_TERMINAL_THEME_VERSION \
        DEVCONTAINER_TOOL_VERSIONS_FILE="${policy_file}" \
        bash "${SCRIPT_DIR}/install/available/3040-ai-pi-gentle.sh" --print-version-policy

    [ "$status" -eq 0 ]
    [ "$output" = "${expected_output}" ]
}

@test "Phase 3C-B Gentle Pi package environment overrides win over central values" {
    local policy_file="${SCRIPT_DIR}/tool-versions.conf"
    local expected_output

	expected_output="$(
		cat <<'EOF'
GENTLE_PI_VERSION=8.8.1
PI_SUBAGENTS_VERSION=8.8.2
PI_INTERCOM_VERSION=8.8.3
PI_WEB_ACCESS_VERSION=8.8.4
PI_LENS_VERSION=8.8.5
RPIV_TODO_VERSION=8.8.6
RPIV_ASK_USER_QUESTION_VERSION=8.8.7
RPIV_BTW_VERSION=8.8.8
GENTLE_ENGRAM_VERSION=8.8.9
PI_MCP_ADAPTER_VERSION=8.8.10
PI_TERMINAL_THEME_VERSION=8.8.12
EOF
)"

    run env \
        DEVCONTAINER_TOOL_VERSIONS_FILE="${policy_file}" \
        GENTLE_PI_VERSION="8.8.1" \
        PI_SUBAGENTS_VERSION="8.8.2" \
        PI_INTERCOM_VERSION="8.8.3" \
        PI_WEB_ACCESS_VERSION="8.8.4" \
        PI_LENS_VERSION="8.8.5" \
        RPIV_TODO_VERSION="8.8.6" \
        RPIV_ASK_USER_QUESTION_VERSION="8.8.7" \
        RPIV_BTW_VERSION="8.8.8" \
        GENTLE_ENGRAM_VERSION="8.8.9" \
        PI_MCP_ADAPTER_VERSION="8.8.10" \
        PI_TERMINAL_THEME_VERSION="8.8.12" \
        bash "${SCRIPT_DIR}/install/available/3040-ai-pi-gentle.sh" --print-version-policy

    [ "$status" -eq 0 ]
    [ "$output" = "${expected_output}" ]
}

@test "Gentle Pi runtime migration removes legacy powerline state once" {
    local home_dir="${BATS_TEST_TMPDIR}/pi-powerline-home"
    local stub_bin="${BATS_TEST_TMPDIR}/pi-powerline-bin"
    local pi_log="${BATS_TEST_TMPDIR}/pi-powerline.log"
    local settings_file="${home_dir}/.pi/agent/settings.json"
    local powerline_dir="${home_dir}/.pi/agent/npm/node_modules/pi-powerline"

    mkdir -p "${stub_bin}" "${powerline_dir}"
    cat >"${settings_file}" <<'EOF'
{
  "packages": [
    "npm:gentle-pi@2.2.0",
    "npm:pi-powerline@0.9.1"
  ],
  "theme": "terminal-tinted"
}
EOF
    printf '%s\n' '{"name":"pi-powerline","version":"0.9.1"}' >"${powerline_dir}/package.json"

    cat >"${stub_bin}/pi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${PI_STUB_LOG}"
if [ "${1:-}" = "remove" ] && [ "${2:-}" = "npm:pi-powerline" ]; then
    node - "${HOME}/.pi/agent/settings.json" <<'NODE'
const fs = require("fs");
const path = process.argv[2];
const settings = JSON.parse(fs.readFileSync(path, "utf8"));
settings.packages = settings.packages.filter((entry) => {
    const source = typeof entry === "string" ? entry : entry.source;
    return !source.startsWith("npm:pi-powerline@");
});
fs.writeFileSync(path, `${JSON.stringify(settings, null, 2)}\n`);
NODE
    find "${HOME}/.pi/agent/npm/node_modules/pi-powerline" -depth -delete
fi
EOF
    chmod +x "${stub_bin}/pi"

    run env \
        HOME="${home_dir}" \
        PATH="${stub_bin}:${PATH}" \
        PI_STUB_LOG="${pi_log}" \
        DEVCONTAINER_PHASE=runtime \
        bash -c 'bash "$1" && bash "$1"' _ "${SCRIPT_DIR}/install/available/3040-ai-pi-gentle.sh"

    [ "$status" -eq 0 ]
    [ "$(grep -c '^remove npm:pi-powerline$' "${pi_log}")" -eq 1 ]
    [ ! -e "${powerline_dir}" ]
    run node -e '
        const settings = require(process.argv[1]);
        if (settings.theme !== "terminal-tinted") process.exit(1);
        if (settings.packages.length !== 1) process.exit(1);
        if (settings.packages[0] !== "npm:gentle-pi@2.2.0") process.exit(1);
    ' "${settings_file}"
    [ "$status" -eq 0 ]
}

@test "Gentle Pi package metadata resolves an installed unscoped package" {
    local work_dir="${BATS_TEST_TMPDIR}/pi-unscoped-work"
    local home_dir="${BATS_TEST_TMPDIR}/pi-unscoped-home"
    mkdir -p "${work_dir}/.pi/npm/node_modules/gentle-pi"
    mkdir -p "${home_dir}"
    printf '%s\n' '{"version":"2.2.0"}' >"${work_dir}/.pi/npm/node_modules/gentle-pi/package.json"

    run env HOME="${home_dir}" bash -c '
        cd "$1"
        exec bash "$2" --print-package-metadata "npm:gentle-pi@2.2.0"
    ' _ "${work_dir}" "${SCRIPT_DIR}/install/available/3040-ai-pi-gentle.sh"

    [ "$status" -eq 0 ]
    [ "$output" = $'PACKAGE_NAME=gentle-pi\nPACKAGE_VERSION=2.2.0\nINSTALLED_VERSION=2.2.0' ]
}

@test "Gentle Pi package metadata resolves an installed scoped package" {
    local work_dir="${BATS_TEST_TMPDIR}/pi-scoped-work"
    local home_dir="${BATS_TEST_TMPDIR}/pi-scoped-home"
    mkdir -p "${work_dir}"
    mkdir -p "${home_dir}/.pi/agent/npm/node_modules/@juicesharp/rpiv-todo"
    printf '%s\n' '{"version":"1.20.0"}' >"${home_dir}/.pi/agent/npm/node_modules/@juicesharp/rpiv-todo/package.json"

    run env HOME="${home_dir}" bash -c '
        cd "$1"
        exec bash "$2" --print-package-metadata "npm:@juicesharp/rpiv-todo@1.20.0"
    ' _ "${work_dir}" "${SCRIPT_DIR}/install/available/3040-ai-pi-gentle.sh"

    [ "$status" -eq 0 ]
    [ "$output" = $'PACKAGE_NAME=@juicesharp/rpiv-todo\nPACKAGE_VERSION=1.20.0\nINSTALLED_VERSION=1.20.0' ]
}

@test "Gentle Pi package metadata splits a scoped name at the final at-sign" {
    local work_dir="${BATS_TEST_TMPDIR}/pi-scoped-edge-work"
    local home_dir="${BATS_TEST_TMPDIR}/pi-scoped-edge-home"
    mkdir -p "${work_dir}/.pi/npm/node_modules/@juicesharp/rpiv-ask-user-question"
    mkdir -p "${home_dir}"
    printf '%s\n' '{"version":"1.20.0"}' >"${work_dir}/.pi/npm/node_modules/@juicesharp/rpiv-ask-user-question/package.json"

    run env HOME="${home_dir}" bash -c '
        cd "$1"
        exec bash "$2" --print-package-metadata "npm:@juicesharp/rpiv-ask-user-question@1.20.0"
    ' _ "${work_dir}" "${SCRIPT_DIR}/install/available/3040-ai-pi-gentle.sh"

    [ "$status" -eq 0 ]
    [ "$output" = $'PACKAGE_NAME=@juicesharp/rpiv-ask-user-question\nPACKAGE_VERSION=1.20.0\nINSTALLED_VERSION=1.20.0' ]
}

@test "BATS installer resolves the central exact tag version" {
    local policy_file="${BATS_TEST_TMPDIR}/bats-central.conf"
	printf '%s\n' 'LOCK_BATS_VERSION="9.9.2"' \
		'LOCK_BATS_SHA256="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' >"${policy_file}"

    run env -u BATS_VERSION \
        DEVCONTAINER_TOOL_VERSIONS_FILE="${policy_file}" \
        bash "${SCRIPT_DIR}/install/available/1000-test-bats.sh" --print-version-policy

    [ "$status" -eq 0 ]
    [ "$output" = "BATS_VERSION=9.9.2" ]
}

@test "BATS installer environment override wins over the central version" {
    local policy_file="${BATS_TEST_TMPDIR}/bats-override.conf"
	printf '%s\n' 'LOCK_BATS_VERSION="9.9.2"' \
		'LOCK_BATS_SHA256="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' >"${policy_file}"

    run env \
        DEVCONTAINER_TOOL_VERSIONS_FILE="${policy_file}" \
        BATS_VERSION="8.8.2" \
        bash "${SCRIPT_DIR}/install/available/1000-test-bats.sh" --print-version-policy

    [ "$status" -eq 0 ]
    [ "$output" = "BATS_VERSION=8.8.2" ]
}

@test "BATS installer consumes the resolved archive and generated checksum" {
	installer="${SCRIPT_DIR}/install/available/1000-test-bats.sh"
	grep -q 'bats-core/archive/refs/tags/v${BATS_VERSION}.tar.gz' "${installer}"
	grep -q 'BATS_SHA256="${LOCK_BATS_SHA256:?missing LOCK_BATS_SHA256}"' "${installer}"
	! grep -q 'git clone' "${installer}"
}

@test "Docker build ARG persists as runtime Engram ENV" {
    command -v docker >/dev/null 2>&1 || skip "docker is unavailable"
    env -u DOCKER_CONTEXT DOCKER_HOST=unix:///var/run/docker.sock docker info >/dev/null 2>&1 || skip "local Docker daemon is unavailable"

    # Use a separate run root, not BATS_TEST_TMPDIR: BATS must not remove recovery evidence.
    run env PYTHONDONTWRITEBYTECODE=1 python3 "${SCRIPT_DIR}/test/lifecycle/image-contract.py" \
        "${SCRIPT_DIR}/.." "${BATS_TMPDIR:-/tmp}"
    printf '%s\n' "${output}"
    [ "$status" -eq 0 ]
}
