#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "${SCRIPT_DIR}/../.." && pwd)"
POLICY_FILE="${DEPS_UPDATE_POLICY_FILE:-${WORKSPACE}/.devcontainer/tool-versions.conf}"
COMMON_SH="${DEPS_UPDATE_COMMON_SH:-${WORKSPACE}/.devcontainer/install/lib/common.sh}"
PNPM_BIN="${DEPS_UPDATE_PNPM:-pnpm}"
CURL_BIN="${DEPS_UPDATE_CURL:-curl}"
JQ_BIN="${DEPS_UPDATE_JQ:-jq}"

PACKAGE_SPECS=(
	"TOOL_PI_CODING_AGENT_VERSION|@earendil-works/pi-coding-agent"
	"TOOL_SKILLS_VERSION|skills"
	"TOOL_GENTLE_PI_VERSION|gentle-pi"
	"TOOL_PI_SUBAGENTS_VERSION|pi-subagents"
	"TOOL_PI_INTERCOM_VERSION|pi-intercom"
	"TOOL_PI_WEB_ACCESS_VERSION|pi-web-access"
	"TOOL_PI_LENS_VERSION|pi-lens"
	"TOOL_RPIV_TODO_VERSION|@juicesharp/rpiv-todo"
	"TOOL_RPIV_ASK_USER_QUESTION_VERSION|@juicesharp/rpiv-ask-user-question"
	"TOOL_RPIV_BTW_VERSION|@juicesharp/rpiv-btw"
	"TOOL_GENTLE_ENGRAM_VERSION|gentle-engram"
	"TOOL_PI_MCP_ADAPTER_VERSION|pi-mcp-adapter"
	"TOOL_PI_TERMINAL_THEME_VERSION|pi-terminal-theme"
	"TOOL_MARKDOWNLINT_CLI2_VERSION|markdownlint-cli2"
	"TOOL_MERMAID_CLI_VERSION|@mermaid-js/mermaid-cli"
	"TOOL_PLAYWRIGHT_VERSION|playwright"
	"TOOL_SPECTRAL_VERSION|@stoplight/spectral-cli"
	"TOOL_REDOCLY_VERSION|@redocly/cli"
	"TOOL_ASYNCAPI_VERSION|@asyncapi/cli"
)

MANAGED_KEYS=(
	TOOL_PI_CODING_AGENT_VERSION TOOL_SKILLS_VERSION
	TOOL_GENTLE_PI_VERSION TOOL_PI_SUBAGENTS_VERSION TOOL_PI_INTERCOM_VERSION
	TOOL_PI_WEB_ACCESS_VERSION TOOL_PI_LENS_VERSION TOOL_RPIV_TODO_VERSION
	TOOL_RPIV_ASK_USER_QUESTION_VERSION TOOL_RPIV_BTW_VERSION
	TOOL_GENTLE_ENGRAM_VERSION TOOL_PI_MCP_ADAPTER_VERSION
	TOOL_PI_TERMINAL_THEME_VERSION
	TOOL_C4_PLANTUML_VERSION TOOL_C4_PLANTUML_SHA256
	TOOL_MARKDOWNLINT_CLI2_VERSION TOOL_MERMAID_CLI_VERSION
	TOOL_PLAYWRIGHT_VERSION TOOL_TERRAFORM_VERSION TOOL_GITLEAKS_VERSION
	TOOL_PULUMI_VERSION TOOL_OPENTOFU_VERSION TOOL_TERRAGRUNT_VERSION
	TOOL_KUBECTL_VERSION TOOL_PLANTUML_VERSION TOOL_DELVE_VERSION
	TOOL_SPECTRAL_VERSION TOOL_REDOCLY_VERSION TOOL_ASYNCAPI_VERSION
)

# Every policy key not managed above must be classified here deliberately.
# Format: comma-separated keys|category|reason
EXCLUDED_SPECS=(
	"TOOL_GENTLE_AI_VERSION,TOOL_GENTLE_AI_SHA256_AMD64,TOOL_GENTLE_AI_SHA256_ARM64|manual trust review|manual review of the version and both architecture digests/trust inputs"
	"TOOL_JAVA_INSTALL_VERSION,TOOL_JAVA_REQUIRED_VERSION|provider-managed installer|SDKMAN selects the distribution while the required version is only an observable check"
	"TOOL_NODE_MAJOR|major channel|policy intentionally follows Node major 26"
	"TOOL_GO_VERSION|explicit latest|policy explicitly delegates selection to the latest Go release"
	"TOOL_PNPM_VERSION|explicit latest|policy explicitly delegates selection to Corepack"
	"TOOL_BATS_VERSION|unsupported exact pin|deterministic BATS discovery is not implemented by this updater"
	"TOOL_ENGRAM_VERSION|no trustworthy deterministic discovery|release discovery is not yet coupled to candidate artifact validation"
	"TOOL_GRAPHIFY_VERSION|unsupported exact pin|PyPI discovery is not implemented by this updater"
	"TOOL_PLAYWRIGHT_CLI_VERSION|explicit latest|policy intentionally installs the current Playwright CLI"
	"TOOL_DEVCONTAINER_CLI_VERSION|explicit latest|policy intentionally installs the current Dev Container CLI"
	"TOOL_VITEST_VERSION|explicit latest|policy intentionally installs the current Vitest release"
	"TOOL_PHP_VERSION|major channel|policy intentionally follows PHP 8.4"
	"TOOL_PHPUNIT_VERSION|major channel|policy intentionally follows PHPUnit 10"
)

declare -A CANDIDATES=()
TEMP_DIR=""
CANDIDATE_FILE=""

cleanup() {
	[ -z "${CANDIDATE_FILE}" ] || rm -f "${CANDIDATE_FILE}"
	[ -z "${TEMP_DIR}" ] || rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

fail() {
	printf 'deps:update: %s\n' "$*" >&2
	exit 1
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

stable_semver() {
	[[ "$1" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([+][0-9A-Za-z.-]+)?$ ]]
}

require_stable_semver() {
	local source="$1"
	local version="$2"
	stable_semver "${version}" || fail "${source} returned '${version}', which is not a stable semantic version"
}

fetch_url() {
	"${CURL_BIN}" -fsSL "$1"
}

fetch_url_to_file() {
	"${CURL_BIN}" -fsSL -o "$2" "$1"
}

latest_package_version() {
	local package_name="$1"
	local version
	version="$("${PNPM_BIN}" view "${package_name}" version --json | "${JQ_BIN}" -er 'if type == "string" then . else error("expected string") end')"
	require_stable_semver "pnpm package ${package_name}" "${version}"
	printf '%s\n' "${version}"
}

latest_github_release() {
	local repository="$1"
	local version_pattern="$2"
	local keep_v="$3"
	local releases version
	releases="$(fetch_url "https://api.github.com/repos/${repository}/releases?per_page=100")"
	version="$(printf '%s' "${releases}" | "${JQ_BIN}" -r '.[] | select(.draft == false and .prerelease == false) | .tag_name' | grep -E "${version_pattern}" | sort -V | tail -n 1)"
	[ -n "${version}" ] || fail "no stable ${version_pattern} release found for ${repository}"
	require_stable_semver "GitHub repository ${repository}" "${version}"
	if [ "${keep_v}" = no ]; then
		version="${version#v}"
	fi
	printf '%s\n' "${version}"
}

latest_terraform_version() {
	local version
	version="$(fetch_url 'https://releases.hashicorp.com/terraform/index.json' | "${JQ_BIN}" -r '.versions | keys[]' | grep -E '^1\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)"
	[ -n "${version}" ] || fail "no stable Terraform 1.x release found"
	require_stable_semver Terraform "${version}"
	printf '%s\n' "${version}"
}

latest_kubectl_version() {
	local version
	version="$(fetch_url 'https://dl.k8s.io/release/stable-1.36.txt')"
	version="${version//$'\r'/}"
	version="${version//$'\n'/}"
	[[ "${version}" =~ ^v1\.36\.[0-9]+$ ]] || fail "kubectl channel returned invalid version '${version}'"
	printf '%s\n' "${version#v}"
}

policy_value() {
	local key="$1"
	sed -nE "s/^${key}=\"([^\"]+)\"$/\1/p" "${POLICY_FILE}"
}

validate_inventory() {
	local key spec keys category reason
	local -a excluded_keys=()
	declare -A inventory=()

	for key in "${MANAGED_KEYS[@]}"; do
		inventory["${key}"]=$((${inventory["${key}"]:-0} + 1))
	done
	for spec in "${EXCLUDED_SPECS[@]}"; do
		IFS='|' read -r keys category reason <<<"${spec}"
		IFS=',' read -ra excluded_keys <<<"${keys}"
		for key in "${excluded_keys[@]}"; do
			inventory["${key}"]=$((${inventory["${key}"]:-0} + 1))
		done
	done

	while IFS= read -r key; do
		[ "${inventory[${key}]:-0}" -eq 1 ] || fail "policy key ${key} must appear exactly once in the managed or excluded inventory"
		unset 'inventory['"${key}"']'
	done < <(sed -nE 's/^(TOOL_[A-Z0-9_]+)=.*/\1/p' "${POLICY_FILE}")

	for key in "${!inventory[@]}"; do
		[ "${inventory[${key}]}" -eq 1 ] || fail "inventory key ${key} is classified more than once"
		grep -q "^${key}=" "${POLICY_FILE}" || fail "inventory key ${key} is absent from the policy"
	done
}

report_exclusions() {
	local spec keys category reason
	printf '\nDeliberately excluded policy:\n'
	for spec in "${EXCLUDED_SPECS[@]}"; do
		IFS='|' read -r keys category reason <<<"${spec}"
		[ "${keys}" = "TOOL_GENTLE_AI_VERSION,TOOL_GENTLE_AI_SHA256_AMD64,TOOL_GENTLE_AI_SHA256_ARM64" ] && continue
		printf '  %s — %s: %s\n' "${keys}" "${category}" "${reason}"
	done
}

report_gentle_ai_advisory() {
	local current latest lookup_output reason keys
	current="$(policy_value TOOL_GENTLE_AI_VERSION)"
	keys="TOOL_GENTLE_AI_VERSION,TOOL_GENTLE_AI_SHA256_AMD64,TOOL_GENTLE_AI_SHA256_ARM64"
	reason="manual review of the version and both architecture digests/trust inputs"

	if lookup_output="$(latest_github_release 'Gentleman-Programming/gentle-ai' '^v[0-9]+\.[0-9]+\.[0-9]+$' no 2>&1)"; then
		latest="${lookup_output}"
		if [ "$(printf '%s\n%s\n' "${current}" "${latest}" | sort -V | tail -n 1)" = "${latest}" ] && [ "${latest}" != "${current}" ]; then
			printf '  Gentle AI: %s available (pinned: %s); omitted — %s — %s\n' "${latest}" "${current}" "${keys}" "${reason}"
			printf '    Release: https://github.com/Gentleman-Programming/gentle-ai/releases/tag/v%s\n' "${latest}"
			printf '    Checksums: https://github.com/Gentleman-Programming/gentle-ai/releases/download/v%s/checksums.txt\n' "${latest}"
			printf "    Inspect Linux checksums: curl -fsSL 'https://github.com/Gentleman-Programming/gentle-ai/releases/download/v%s/checksums.txt' | grep -E '  gentle-ai_%s_linux_(amd64|arm64)\\.tar\\.gz$'\n" "${latest}" "${latest//./\\.}"
			printf '    Update TOOL_GENTLE_AI_VERSION, TOOL_GENTLE_AI_SHA256_AMD64, and TOOL_GENTLE_AI_SHA256_ARM64 together.\n'
		else
			printf '  Gentle AI: current at %s; omitted — %s — %s\n' "${current}" "${keys}" "${reason}"
		fi
	else
		printf '  WARNING: Gentle AI advisory lookup failed; omitted — %s — %s. Managed updates continue because advisory discovery cannot affect their validated candidate.\n' "${keys}" "${reason}" >&2
	fi
}

discover_candidates() {
	local spec key package_name

	printf 'Discovering exact pnpm package versions...\n'
	for spec in "${PACKAGE_SPECS[@]}"; do
		IFS='|' read -r key package_name <<<"${spec}"
		CANDIDATES["${key}"]="$(latest_package_version "${package_name}")"
	done

	printf 'Discovering constrained direct releases...\n'
	CANDIDATES[TOOL_C4_PLANTUML_VERSION]="$(latest_github_release 'plantuml-stdlib/C4-PlantUML' '^v2\.[0-9]+\.[0-9]+$' no)"
	CANDIDATES[TOOL_TERRAFORM_VERSION]="$(latest_terraform_version)"
	CANDIDATES[TOOL_GITLEAKS_VERSION]="$(latest_github_release 'gitleaks/gitleaks' '^v8\.[0-9]+\.[0-9]+$' no)"
	CANDIDATES[TOOL_PULUMI_VERSION]="$(latest_github_release 'pulumi/pulumi' '^v3\.[0-9]+\.[0-9]+$' no)"
	CANDIDATES[TOOL_OPENTOFU_VERSION]="$(latest_github_release 'opentofu/opentofu' '^v1\.[0-9]+\.[0-9]+$' no)"
	CANDIDATES[TOOL_TERRAGRUNT_VERSION]="$(latest_github_release 'gruntwork-io/terragrunt' '^v1\.[0-9]+\.[0-9]+$' no)"
	CANDIDATES[TOOL_KUBECTL_VERSION]="$(latest_kubectl_version)"
	CANDIDATES[TOOL_PLANTUML_VERSION]="$(latest_github_release 'plantuml/plantuml' '^v1\.2026\.[0-9]+$' no)"
	CANDIDATES[TOOL_DELVE_VERSION]="$(latest_github_release 'go-delve/delve' '^v1\.[0-9]+\.[0-9]+$' yes)"

	local c4_archive="${TEMP_DIR}/c4-plantuml.tar.gz"
	fetch_url_to_file \
		"https://codeload.github.com/plantuml-stdlib/C4-PlantUML/tar.gz/refs/tags/v${CANDIDATES[TOOL_C4_PLANTUML_VERSION]}" \
		"${c4_archive}"
	[ -s "${c4_archive}" ] || fail "C4-PlantUML archive is empty"
	CANDIDATES[TOOL_C4_PLANTUML_SHA256]="$(sha256sum "${c4_archive}" | awk '{print $1}')"
	[[ "${CANDIDATES[TOOL_C4_PLANTUML_SHA256]}" =~ ^[0-9a-f]{64}$ ]] || fail "invalid C4-PlantUML SHA-256"
}

replace_assignment() {
	local file="$1"
	local key="$2"
	local value="$3"
	local replacement="${TEMP_DIR}/replacement"

	[ "$(grep -c "^${key}=" "${file}")" -eq 1 ] || fail "policy must contain exactly one ${key} assignment"
	awk -v key="${key}" -v value="${value}" '
    $0 ~ ("^" key "=") { print key "=\"" value "\""; next }
    { print }
  ' "${file}" >"${replacement}"
	mv "${replacement}" "${file}"
}

validate_scope() {
	local original="$1"
	local candidate="$2"
	local pattern masked_original masked_candidate
	pattern="$(
		IFS='|'
		printf '%s' "${MANAGED_KEYS[*]}"
	)"
	masked_original="${TEMP_DIR}/original.unmanaged"
	masked_candidate="${TEMP_DIR}/candidate.unmanaged"
	grep -Ev "^(${pattern})=" "${original}" >"${masked_original}"
	grep -Ev "^(${pattern})=" "${candidate}" >"${masked_candidate}"
	cmp -s "${masked_original}" "${masked_candidate}" || fail "candidate changed policy outside the approved key scope"
}

validate_policy() {
	local candidate="$1"
	bash -c 'source "$1"; devcontainer_load_tool_versions "$2"' _ "${COMMON_SH}" "${candidate}" || fail "candidate policy validation failed"
}

publish_policy() {
	local key
	CANDIDATE_FILE="$(mktemp "$(dirname "${POLICY_FILE}")/.tool-versions.conf.XXXXXX")"
	cp "${POLICY_FILE}" "${CANDIDATE_FILE}"

	for key in "${MANAGED_KEYS[@]}"; do
		replace_assignment "${CANDIDATE_FILE}" "${key}" "${CANDIDATES[${key}]}"
	done

	validate_scope "${POLICY_FILE}" "${CANDIDATE_FILE}"
	validate_policy "${CANDIDATE_FILE}"

	printf '\nVersion policy updates:\n'
	for key in "${MANAGED_KEYS[@]}"; do
		local old_value
		old_value="$(sed -nE "s/^${key}=\"([^\"]+)\"$/\1/p" "${POLICY_FILE}")"
		if [ "${old_value}" != "${CANDIDATES[${key}]}" ]; then
			printf '  %s: %s -> %s\n' "${key}" "${old_value}" "${CANDIDATES[${key}]}"
		fi
	done

	if cmp -s "${POLICY_FILE}" "${CANDIDATE_FILE}"; then
		rm -f "${CANDIDATE_FILE}"
		CANDIDATE_FILE=""
		printf '  No changes.\n'
	else
		chmod --reference="${POLICY_FILE}" "${CANDIDATE_FILE}"
		mv "${CANDIDATE_FILE}" "${POLICY_FILE}"
		CANDIDATE_FILE=""
	fi
}

main() {
	[ -f "${POLICY_FILE}" ] || fail "policy file not found: ${POLICY_FILE}"
	[ -f "${COMMON_SH}" ] || fail "common installer library not found: ${COMMON_SH}"
	require_command "${PNPM_BIN}"
	require_command "${CURL_BIN}"
	require_command "${JQ_BIN}"
	require_command sha256sum
	validate_inventory

	TEMP_DIR="$(mktemp -d)"
	discover_candidates
	publish_policy
	report_exclusions
	report_gentle_ai_advisory
	printf "\nRun 'task container:rebuild' to apply these versions.\n"
}

main "$@"
