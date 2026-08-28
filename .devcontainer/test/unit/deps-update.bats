#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	POLICY_FILE="${TEST_ROOT}/tool-versions.conf"
	BIN_DIR="${TEST_ROOT}/bin"
	CALLS_FILE="${TEST_ROOT}/calls"
	mkdir -p "${BIN_DIR}"
	cp "${REPO_ROOT}/.devcontainer/tool-versions.conf" "${POLICY_FILE}"
	: >"${CALLS_FILE}"
	export REPO_ROOT TEST_ROOT POLICY_FILE BIN_DIR CALLS_FILE
	export PATH="${BIN_DIR}:${PATH}"
	export DEPS_UPDATE_POLICY_FILE="${POLICY_FILE}"
	export DEPS_UPDATE_PNPM="${BIN_DIR}/pnpm"
	export DEPS_UPDATE_CURL="${BIN_DIR}/curl"
	export DEPS_UPDATE_COMMON_SH="${REPO_ROOT}/.devcontainer/install/lib/common.sh"
	write_pnpm_stub stable
	write_curl_stub success
	write_forbidden_stub npm
	write_forbidden_stub pi
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

write_pnpm_stub() {
	local mode="$1"
	cat >"${BIN_DIR}/pnpm" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'pnpm %s\n' "\$*" >>"${CALLS_FILE}"
if [ "${mode}" = prerelease ]; then
  printf '%s\n' '"9.9.9-beta.1"'
else
  printf '%s\n' '"9.9.9"'
fi
EOF
	chmod +x "${BIN_DIR}/pnpm"
}

write_forbidden_stub() {
	local command_name="$1"
	cat >"${BIN_DIR}/${command_name}" <<EOF
#!/usr/bin/env bash
printf '${command_name} %s\n' "\$*" >>"${CALLS_FILE}"
exit 99
EOF
	chmod +x "${BIN_DIR}/${command_name}"
}

write_c4_archive_fixture() {
	local archive_root="${TEST_ROOT}/c4-archive"
	C4_ARCHIVE_FILE="${TEST_ROOT}/c4-plantuml.tar.gz"
	C4_ARCHIVE_VERSION="$(sed -n 's/^TOOL_C4_PLANTUML_VERSION="\([^"]*\)"$/\1/p' "${POLICY_FILE}")"
	mkdir -p "${archive_root}/C4-PlantUML-${C4_ARCHIVE_VERSION}"
	printf '%s\n' 'configured C4 content' >"${archive_root}/C4-PlantUML-${C4_ARCHIVE_VERSION}/C4.puml"
	tar -czf "${C4_ARCHIVE_FILE}" -C "${archive_root}" "C4-PlantUML-${C4_ARCHIVE_VERSION}"
	expected_checksum="$(sha256sum "${C4_ARCHIVE_FILE}" | awk '{print $1}')"
	sed -i "s/^TOOL_C4_PLANTUML_SHA256=.*/TOOL_C4_PLANTUML_SHA256=\"${expected_checksum}\"/" "${POLICY_FILE}"
}

write_curl_stub() {
	local mode="$1"
	cat >"${BIN_DIR}/curl" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'curl %s\n' "\$*" >>"${CALLS_FILE}"
output=""
url=""
while [ "\$#" -gt 0 ]; do
  case "\$1" in
    -o) output="\$2"; shift 2 ;;
    -*) shift ;;
    *) url="\$1"; shift ;;
  esac
done
if [ "${mode}" = fail ] && [[ "\${url}" == *releases.hashicorp.com* ]]; then
  exit 22
fi
if [ "${mode}" = gentle_fail ] && [[ "\${url}" == *Gentleman-Programming/gentle-ai* ]]; then
  exit 22
fi
case "\${url}" in
  *releases.hashicorp.com/terraform/index.json)
    body='{"versions":{"1.98.0":{},"1.99.0":{},"2.0.0-beta.1":{}}}' ;;
  *dl.k8s.io/release/stable-1.36.txt)
    body='v1.36.99' ;;
  *codeload.github.com/plantuml-stdlib/C4-PlantUML*)
    if [ "${mode}" = c4_archive ]; then
      cp "${C4_ARCHIVE_FILE}" "\${output}"
      exit 0
    fi
    body='c4 archive bytes' ;;
  *api.github.com/repos/plantuml-stdlib/C4-PlantUML/releases*)
    body='[{"tag_name":"v3.0.0-beta.1","draft":false,"prerelease":true},{"tag_name":"v2.99.0","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/gitleaks/gitleaks/releases*)
    body='[{"tag_name":"v9.0.0-beta.1","draft":false,"prerelease":true},{"tag_name":"v8.99.0","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/pulumi/pulumi/releases*)
    body='[{"tag_name":"v3.999.0","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/opentofu/opentofu/releases*)
    body='[{"tag_name":"v1.99.0","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/gruntwork-io/terragrunt/releases*)
    body='[{"tag_name":"v1.99.0","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/plantuml/plantuml/releases*)
    body='[{"tag_name":"v1.2027.1","draft":false,"prerelease":false},{"tag_name":"v1.2026.99","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/go-delve/delve/releases*)
    body='[{"tag_name":"v2.0.0-rc.1","draft":false,"prerelease":true},{"tag_name":"v1.99.0","draft":false,"prerelease":false}]' ;;
  *api.github.com/repos/Gentleman-Programming/gentle-ai/releases*)
    if [ "${mode}" = gentle_current ]; then
      body='[{"tag_name":"v2.4.0","draft":false,"prerelease":false}]'
    else
      body='[{"tag_name":"v2.6.0-rc.1","draft":false,"prerelease":true},{"tag_name":"v2.5.0","draft":false,"prerelease":false}]'
    fi ;;
  *) echo "unexpected URL: \${url}" >&2; exit 64 ;;
esac
if [ -n "\${output}" ]; then
  printf '%s' "\${body}" >"\${output}"
else
  printf '%s\n' "\${body}"
fi
EOF
	chmod +x "${BIN_DIR}/curl"
}

@test "deps:update atomically updates the approved stable pins with pnpm metadata" {
	run "${REPO_ROOT}/.taskfiles/scripts/deps-update.sh"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"Run 'task container:rebuild' to apply these versions."* ]]
	grep -q '^TOOL_PI_CODING_AGENT_VERSION="9.9.9"$' "${POLICY_FILE}"
	grep -q '^TOOL_ASYNCAPI_VERSION="9.9.9"$' "${POLICY_FILE}"
	grep -q '^TOOL_C4_PLANTUML_VERSION="2.99.0"$' "${POLICY_FILE}"
	expected_c4_sha="$(printf 'c4 archive bytes' | sha256sum | awk '{print $1}')"
	grep -q "^TOOL_C4_PLANTUML_SHA256=\"${expected_c4_sha}\"$" "${POLICY_FILE}"
	grep -q '^TOOL_TERRAFORM_VERSION="1.99.0"$' "${POLICY_FILE}"
	grep -q '^TOOL_GITLEAKS_VERSION="8.99.0"$' "${POLICY_FILE}"
	grep -q '^TOOL_GENTLE_AI_VERSION="2.4.0"$' "${POLICY_FILE}"
	grep -q '^TOOL_GENTLE_AI_SHA256_AMD64="517eb8420cf966b74be1413a7ea1036119a5ccbb376e0778aa9f4d4d283e2e9a"$' "${POLICY_FILE}"
	grep -q '^TOOL_GENTLE_AI_SHA256_ARM64="1badec9cad1f2bbeb22b5c6804c3a88c601d844abae231264e416e8095f2a15f"$' "${POLICY_FILE}"
	grep -q 'Gentleman-Programming/gentle-ai' "${CALLS_FILE}"
	grep -q '^TOOL_PLANTUML_VERSION="1.2026.99"$' "${POLICY_FILE}"
	grep -q '^TOOL_DELVE_VERSION="v1.99.0"$' "${POLICY_FILE}"
	! grep -Eq '(^| )(npm|pi)( |$)' "${CALLS_FILE}"
	[ "$(grep -c '^pnpm view ' "${CALLS_FILE}")" -eq 19 ]
}

@test "deps:update reports a newer Gentle AI release without changing its coupled pins" {
	before_gentle="$(grep '^TOOL_GENTLE_AI_' "${POLICY_FILE}")"

	run "${REPO_ROOT}/.taskfiles/scripts/deps-update.sh"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"Gentle AI: 2.5.0 available (pinned: 2.4.0); omitted"* ]]
	[[ "${output}" == *"manual review of the version and both architecture digests/trust inputs"* ]]
	[[ "${output}" == *"Release: https://github.com/Gentleman-Programming/gentle-ai/releases/tag/v2.5.0"* ]]
	[[ "${output}" == *"Checksums: https://github.com/Gentleman-Programming/gentle-ai/releases/download/v2.5.0/checksums.txt"* ]]
	[[ "${output}" == *"curl -fsSL 'https://github.com/Gentleman-Programming/gentle-ai/releases/download/v2.5.0/checksums.txt' | grep -E '  gentle-ai_2\\.5\\.0_linux_(amd64|arm64)\\.tar\\.gz$'"* ]]
	[[ "${output}" == *"Update TOOL_GENTLE_AI_VERSION, TOOL_GENTLE_AI_SHA256_AMD64, and TOOL_GENTLE_AI_SHA256_ARM64 together."* ]]
	[ "$(grep '^TOOL_GENTLE_AI_' "${POLICY_FILE}")" = "${before_gentle}" ]
}

@test "deps:update reports Gentle AI as current without claiming an update" {
	write_curl_stub gentle_current

	run "${REPO_ROOT}/.taskfiles/scripts/deps-update.sh"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"Gentle AI: current at 2.4.0; omitted"* ]]
	[[ "${output}" != *"Gentle AI: 2.4.0 available"* ]]
}

@test "deps:update treats Gentle AI advisory discovery failure as warning-only" {
	write_curl_stub gentle_fail

	run "${REPO_ROOT}/.taskfiles/scripts/deps-update.sh"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"WARNING: Gentle AI advisory lookup failed"* ]]
	grep -q '^TOOL_PI_CODING_AGENT_VERSION="9.9.9"$' "${POLICY_FILE}"
}

@test "deps:update explicitly reports every excluded policy key" {
	run "${REPO_ROOT}/.taskfiles/scripts/deps-update.sh"

	[ "${status}" -eq 0 ]
	for key in \
		TOOL_JAVA_INSTALL_VERSION TOOL_JAVA_REQUIRED_VERSION TOOL_NODE_MAJOR \
		TOOL_GO_VERSION TOOL_PNPM_VERSION TOOL_BATS_VERSION TOOL_ENGRAM_VERSION \
		TOOL_GENTLE_AI_VERSION TOOL_GENTLE_AI_SHA256_AMD64 TOOL_GENTLE_AI_SHA256_ARM64 \
		TOOL_GRAPHIFY_VERSION TOOL_PLAYWRIGHT_CLI_VERSION TOOL_DEVCONTAINER_CLI_VERSION \
		TOOL_VITEST_VERSION TOOL_PHP_VERSION TOOL_PHPUNIT_VERSION; do
		[[ "${output}" == *"${key}"* ]]
	done
	[[ "${output}" == *"major channel"* ]]
	[[ "${output}" == *"explicit latest"* ]]
	[[ "${output}" == *"provider-managed installer"* ]]
	[[ "${output}" == *"unsupported exact pin"* ]]
	[[ "${output}" == *"no trustworthy deterministic discovery"* ]]
}

@test "deps:update preserves channels, latest policies, comments, and unsupported exact pins" {
	before_node="$(grep '^TOOL_NODE_MAJOR=' "${POLICY_FILE}")"
	before_graphify="$(grep '^TOOL_GRAPHIFY_VERSION=' "${POLICY_FILE}")"
	before_latest="$(grep '="latest"$' "${POLICY_FILE}")"

	run "${REPO_ROOT}/.taskfiles/scripts/deps-update.sh"

	[ "${status}" -eq 0 ]
	[ "$(grep '^TOOL_NODE_MAJOR=' "${POLICY_FILE}")" = "${before_node}" ]
	[ "$(grep '^TOOL_GRAPHIFY_VERSION=' "${POLICY_FILE}")" = "${before_graphify}" ]
	[ "$(grep '="latest"$' "${POLICY_FILE}")" = "${before_latest}" ]
	grep -q '^# Canonical version policy' "${POLICY_FILE}"
}

@test "deps:update rejects prerelease package metadata without writing" {
	write_pnpm_stub prerelease
	cp "${POLICY_FILE}" "${TEST_ROOT}/before"

	run "${REPO_ROOT}/.taskfiles/scripts/deps-update.sh"

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"not a stable semantic version"* ]]
	cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
}

@test "deps:update leaves policy unchanged when direct release discovery fails" {
	write_curl_stub fail
	cp "${POLICY_FILE}" "${TEST_ROOT}/before"

	run "${REPO_ROOT}/.taskfiles/scripts/deps-update.sh"

	[ "${status}" -ne 0 ]
	cmp -s "${TEST_ROOT}/before" "${POLICY_FILE}"
	[ -z "$(find "${TEST_ROOT}" -maxdepth 1 -name '.tool-versions.conf.*' -print)" ]
}

@test "C4 installer resolves the central version and checksum with environment precedence" {
	sed -i 's/^TOOL_C4_PLANTUML_SHA256=.*/TOOL_C4_PLANTUML_SHA256="0000000000000000000000000000000000000000000000000000000000000001"/' "${POLICY_FILE}"
	configured_version="$(sed -n 's/^TOOL_C4_PLANTUML_VERSION="\([^"]*\)"$/\1/p' "${POLICY_FILE}")"

	run env DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY_FILE}" \
		"${REPO_ROOT}/.devcontainer/install/available/40-cli-c4-plantuml.sh" --print-version-policy
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"C4_PLANTUML_VERSION=${configured_version}"* ]]
	[[ "${output}" == *"C4_PLANTUML_SHA256=$(printf '%064d' 1)"* ]]

	run env DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY_FILE}" \
		C4_PLANTUML_VERSION="2.88.0" C4_PLANTUML_SHA256="$(printf '%064d' 2)" \
		"${REPO_ROOT}/.devcontainer/install/available/40-cli-c4-plantuml.sh" --print-version-policy
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"C4_PLANTUML_VERSION=2.88.0"* ]]
	[[ "${output}" == *"C4_PLANTUML_SHA256=$(printf '%064d' 2)"* ]]
}

@test "C4 installer replaces a stale checksum installation with the configured archive" {
	install_dir="${TEST_ROOT}/c4-plantuml"
	write_c4_archive_fixture
	expected_version="${C4_ARCHIVE_VERSION}"
	expected_checksum="$(sed -n 's/^TOOL_C4_PLANTUML_SHA256="\([^"]*\)"$/\1/p' "${POLICY_FILE}")"
	write_curl_stub c4_archive
	mkdir -p "${install_dir}"
	printf '%s\n' 'stale C4 content' >"${install_dir}/C4.puml"
	printf '%s\n' "${expected_version}" >"${install_dir}/.version"
	printf '%064d\n' 9 >"${install_dir}/.sha256"

	run env DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY_FILE}" \
		C4_PLANTUML_INSTALL_DIR="${install_dir}" \
		"${REPO_ROOT}/.devcontainer/install/available/40-cli-c4-plantuml.sh"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"Downloading C4-PlantUML ${expected_version}"* ]]
	[ "$(cat "${install_dir}/C4.puml")" = 'configured C4 content' ]
	[ "$(cat "${install_dir}/.version")" = "${expected_version}" ]
	[ "$(cat "${install_dir}/.sha256")" = "${expected_checksum}" ]
}

@test "C4 installer treats matching version and checksum as installed" {
	install_dir="${TEST_ROOT}/c4-plantuml"
	expected_version="$(sed -n 's/^TOOL_C4_PLANTUML_VERSION="\([^"]*\)"$/\1/p' "${POLICY_FILE}")"
	expected_checksum="$(sed -n 's/^TOOL_C4_PLANTUML_SHA256="\([^"]*\)"$/\1/p' "${POLICY_FILE}")"
	mkdir -p "${install_dir}"
	printf '%s\n' "${expected_version}" >"${install_dir}/.version"
	printf '%s\n' "${expected_checksum}" >"${install_dir}/.sha256"

	run env DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY_FILE}" \
		C4_PLANTUML_INSTALL_DIR="${install_dir}" \
		"${REPO_ROOT}/.devcontainer/install/available/40-cli-c4-plantuml.sh"

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"already installed at ${install_dir}"* ]]
}

@test "public task surface exposes deps:update and removes legacy AI update tasks" {
	run task --dir "${REPO_ROOT}" --list
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"deps:update"* ]]
	[[ "${output}" != *"ai:update"* ]]
	[[ "${output}" != *"ai:configure-models"* ]]

	run task --dir "${REPO_ROOT}" help
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"task deps:update"* ]]
	[[ "${output}" != *"task ai:update"* ]]
	[[ "${output}" != *"task ai:configure-models"* ]]
}
