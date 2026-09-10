#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "${SCRIPT_DIR}/../.." && pwd)"
POLICY_FILE="${DEPS_UPDATE_POLICY_FILE:-${WORKSPACE}/.devcontainer/tool-versions.conf}"
COMMON_SH="${DEPS_UPDATE_COMMON_SH:-${WORKSPACE}/.devcontainer/install/lib/common.sh}"
ARCHIFY_ARCHIVE_SH="${DEPS_UPDATE_ARCHIFY_ARCHIVE_SH:-${WORKSPACE}/.devcontainer/install/lib/archify-archive.sh}"
PNPM_BIN="${DEPS_UPDATE_PNPM:-pnpm}"
CURL_BIN="${DEPS_UPDATE_CURL:-curl}"
JQ_BIN="${DEPS_UPDATE_JQ:-jq}"

PACKAGE_SPECS=(
	"LOCK_PNPM_VERSION|pnpm" "LOCK_PI_CODING_AGENT_VERSION|@earendil-works/pi-coding-agent"
	"LOCK_SKILLS_VERSION|skills" "LOCK_GENTLE_PI_VERSION|gentle-pi"
	"LOCK_PI_SUBAGENTS_VERSION|pi-subagents" "LOCK_PI_INTERCOM_VERSION|pi-intercom"
	"LOCK_PI_WEB_ACCESS_VERSION|pi-web-access" "LOCK_PI_LENS_VERSION|pi-lens"
	"LOCK_RPIV_TODO_VERSION|@juicesharp/rpiv-todo" "LOCK_RPIV_ASK_USER_QUESTION_VERSION|@juicesharp/rpiv-ask-user-question"
	"LOCK_RPIV_BTW_VERSION|@juicesharp/rpiv-btw" "LOCK_GENTLE_ENGRAM_VERSION|gentle-engram"
	"LOCK_PI_MCP_ADAPTER_VERSION|pi-mcp-adapter" "LOCK_PI_TERMINAL_THEME_VERSION|pi-terminal-theme"
	"LOCK_MARKDOWNLINT_CLI2_VERSION|markdownlint-cli2" "LOCK_MERMAID_CLI_VERSION|@mermaid-js/mermaid-cli"
	"LOCK_PLAYWRIGHT_VERSION|playwright" "LOCK_PLAYWRIGHT_CLI_VERSION|@playwright/cli"
	"LOCK_DEVCONTAINER_CLI_VERSION|@devcontainers/cli" "LOCK_VITEST_VERSION|vitest"
	"LOCK_SPECTRAL_VERSION|@stoplight/spectral-cli" "LOCK_REDOCLY_VERSION|@redocly/cli"
	"LOCK_ASYNCAPI_VERSION|@asyncapi/cli"
)

MANAGED_KEYS=(
	LOCK_JAVA_INSTALL_VERSION LOCK_JAVA_REQUIRED_VERSION LOCK_NODE_MAJOR
	LOCK_PI_CODING_AGENT_VERSION LOCK_SKILLS_VERSION LOCK_PNPM_VERSION LOCK_PLAYWRIGHT_CLI_VERSION LOCK_DEVCONTAINER_CLI_VERSION LOCK_VITEST_VERSION
	LOCK_GENTLE_PI_VERSION LOCK_PI_SUBAGENTS_VERSION LOCK_PI_INTERCOM_VERSION LOCK_PI_WEB_ACCESS_VERSION LOCK_PI_LENS_VERSION
	LOCK_RPIV_TODO_VERSION LOCK_RPIV_ASK_USER_QUESTION_VERSION LOCK_RPIV_BTW_VERSION LOCK_GENTLE_ENGRAM_VERSION LOCK_PI_MCP_ADAPTER_VERSION LOCK_PI_TERMINAL_THEME_VERSION
	LOCK_GO_VERSION LOCK_GO_SHA256_AMD64 LOCK_GO_SHA256_ARM64 LOCK_BATS_VERSION LOCK_BATS_SHA256
	LOCK_ENGRAM_VERSION LOCK_ENGRAM_SHA256_AMD64 LOCK_ENGRAM_SHA256_ARM64 LOCK_OPENCODE_VERSION LOCK_OPENCODE_SHA256_AMD64 LOCK_OPENCODE_SHA256_ARM64
	LOCK_GENTLE_AI_VERSION LOCK_GENTLE_AI_SHA256_AMD64 LOCK_GENTLE_AI_SHA256_ARM64 LOCK_C4_PLANTUML_VERSION LOCK_C4_PLANTUML_SHA256
	LOCK_MARKDOWNLINT_CLI2_VERSION LOCK_MERMAID_CLI_VERSION LOCK_PLAYWRIGHT_VERSION LOCK_GRAPHIFY_VERSION LOCK_PHP_SERIES LOCK_PHPUNIT_VERSION
	LOCK_TERRAFORM_VERSION LOCK_GITLEAKS_VERSION LOCK_PULUMI_VERSION LOCK_OPENTOFU_VERSION LOCK_TERRAGRUNT_VERSION LOCK_KUBECTL_VERSION
	LOCK_PLANTUML_VERSION LOCK_PLANTUML_SHA256 LOCK_DELVE_VERSION LOCK_DELVE_SHA256_AMD64 LOCK_DELVE_SHA256_ARM64
	LOCK_SPECTRAL_VERSION LOCK_REDOCLY_VERSION LOCK_ASYNCAPI_VERSION LOCK_ARCHIFY_VERSION LOCK_ARCHIFY_SHA256
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

intent_key_for_lock() {
	case "$1" in
	LOCK_JAVA_*) printf TOOL_JAVA_VERSION ;;
	LOCK_NODE_MAJOR) printf TOOL_NODE_VERSION ;;
	LOCK_PHP_SERIES) printf TOOL_PHP_VERSION ;;
	LOCK_*_SHA256*) printf '%s_VERSION' "${1#LOCK_}" | sed -E 's/_SHA256.*_VERSION$/_VERSION/' ;;
	*) printf 'TOOL_%s' "${1#LOCK_}" ;;
	esac
}

validate_intent() {
	local key="$1" intent="$2" strategy="$3"
	case "${strategy}" in
	semver | npm | github-v | composer)
		[[ "${intent}" =~ ^(latest|=?[0-9]+([.][0-9]+){0,2})$ ]] || fail "${key} has unsafe ${strategy} intent '${intent}'"
		;;
	plantuml)
		[[ "${intent}" =~ ^(latest|=?1[.][0-9]{4}([.][0-9]+)?)$ ]] || fail "${key} has unsafe PlantUML intent '${intent}'"
		;;
	node | php | kubectl | sdkman)
		[[ "${intent}" =~ ^(latest|=?[0-9]+([.][0-9]+){0,2}(-[A-Za-z0-9._-]+)?)$ ]] || fail "${key} has unsafe ${strategy} intent '${intent}'"
		;;
	*) fail "unknown tool strategy '${strategy}' for ${key}" ;;
	esac
}

intent_accepts_version() {
	local intent="$1" version="${2#v}" strategy="$3"
	version="${version#go}"
	intent="${intent#v}"
	validate_intent candidate "${intent}" "${strategy}"
	case "${intent}" in
	latest) return 0 ;;
	=*)
		[ "${version}" = "${intent#=}" ]
		return
		;;
	esac
	case "${strategy}:${intent}" in
	sdkman:*) [[ "${version}" == "${intent}" ]] ;;
	plantuml:1.[0-9][0-9][0-9][0-9]) [[ "${version}" == "${intent}."* ]] ;;
	plantuml:1.[0-9][0-9][0-9][0-9].*)
		[[ "${version}" == "${intent%.*}."* ]] && version_at_least "${version}" "${intent}"
		;;
	*)
		case "${intent}" in
		*.*.*) [[ "${version}" == "${intent%%.*}."* ]] && version_at_least "${version}" "${intent}" ;;
		*.*) [[ "${version}" == "${intent}."* ]] ;;
		*) [[ "${version}" == "${intent}."* ]] ;;
		esac
		;;
	esac
}

version_at_least() {
	[ "$(printf '%s\n%s\n' "${2#v}" "${1#v}" | sort -V | head -n 1)" = "${2#v}" ]
}

select_newest_stable_candidate() {
	local intent="$1" strategy="$2" source="$3" candidate selected=""
	while IFS= read -r candidate; do
		[ -n "${candidate}" ] || continue
		stable_semver "${candidate#go}" || continue
		if intent_accepts_version "${intent}" "${candidate}" "${strategy}"; then
			selected="$(printf '%s\n%s\n' "${selected}" "${candidate}" | sed '/^$/d' | sort -V | tail -n 1)"
		fi
	done
	[ -n "${selected}" ] || fail "no stable candidate matching ${intent} found for ${source}"
	printf '%s\n' "${selected}"
}

strategy_for_key() {
	case "$1" in
	TOOL_PLANTUML_VERSION) printf plantuml ;; TOOL_KUBECTL_VERSION) printf kubectl ;; TOOL_DELVE_VERSION) printf github-v ;;
	TOOL_PHP_VERSION) printf php ;; TOOL_JAVA_VERSION) printf sdkman ;; TOOL_NODE_VERSION) printf node ;; TOOL_PHPUNIT_VERSION) printf composer ;;
	TOOL_GO_VERSION | TOOL_C4_PLANTUML_VERSION | TOOL_GENTLE_AI_VERSION | TOOL_ENGRAM_VERSION | TOOL_OPENCODE_VERSION | TOOL_ARCHIFY_VERSION | TOOL_TERRAFORM_VERSION | TOOL_GITLEAKS_VERSION | TOOL_PULUMI_VERSION | TOOL_OPENTOFU_VERSION | TOOL_TERRAGRUNT_VERSION | TOOL_BATS_VERSION) printf github-v ;;
	TOOL_GRAPHIFY_VERSION) printf semver ;;
	TOOL_PNPM_VERSION | TOOL_PI_CODING_AGENT_VERSION | TOOL_SKILLS_VERSION | TOOL_GENTLE_PI_VERSION | TOOL_PI_SUBAGENTS_VERSION | TOOL_PI_INTERCOM_VERSION | TOOL_PI_WEB_ACCESS_VERSION | TOOL_PI_LENS_VERSION | TOOL_RPIV_TODO_VERSION | TOOL_RPIV_ASK_USER_QUESTION_VERSION | TOOL_RPIV_BTW_VERSION | TOOL_GENTLE_ENGRAM_VERSION | TOOL_PI_MCP_ADAPTER_VERSION | TOOL_PI_TERMINAL_THEME_VERSION | TOOL_MARKDOWNLINT_CLI2_VERSION | TOOL_MERMAID_CLI_VERSION | TOOL_PLAYWRIGHT_VERSION | TOOL_PLAYWRIGHT_CLI_VERSION | TOOL_DEVCONTAINER_CLI_VERSION | TOOL_VITEST_VERSION | TOOL_SPECTRAL_VERSION | TOOL_REDOCLY_VERSION | TOOL_ASYNCAPI_VERSION) printf npm ;;
	*) fail "unknown tool strategy for $1" ;;
	esac
}

apply_intent_contract() {
	local key intent_key intent strategy candidate
	for key in "${MANAGED_KEYS[@]}"; do
		[[ "${key}" == *_VERSION ]] || continue
		[ "${key}" != LOCK_JAVA_REQUIRED_VERSION ] || continue
		intent_key="$(intent_key_for_lock "${key}")"
		intent="$(policy_value "${intent_key}")"
		[ -n "${intent}" ] || fail "missing editable intent ${intent_key}"
		strategy="$(strategy_for_key "${intent_key}")"
		validate_intent "${intent_key}" "${intent}" "${strategy}"
		candidate="${CANDIDATES[${key}]}"
		if ! intent_accepts_version "${intent}" "${candidate}" "${strategy}"; then
			fail "${key} candidate ${candidate} escapes intent ${intent}"
		fi
	done
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
	local package_name="$1" intent="$2"
	local version
	version="$("${PNPM_BIN}" view "${package_name}" versions --json | "${JQ_BIN}" -er '.[]' | select_newest_stable_candidate "${intent}" npm "pnpm package ${package_name}")"
	require_stable_semver "pnpm package ${package_name}" "${version}"
	printf '%s\n' "${version}"
}

latest_pypi_version() {
	local package_name="$1" intent="$2" version
	version="$(fetch_url "https://pypi.org/pypi/${package_name}/json" | "${JQ_BIN}" -er '.releases | keys[]' | select_newest_stable_candidate "${intent}" semver "PyPI package ${package_name}")"
	require_stable_semver "PyPI package ${package_name}" "${version}"
	printf '%s\n' "${version}"
}

latest_composer_version() {
	local package_name="$1" intent="$2" version candidate
	version=""
	# jq variables are intentionally evaluated by jq, not the shell.
	# shellcheck disable=SC2016
	while IFS= read -r candidate; do
		if intent_accepts_version "${intent}" "${candidate}" composer; then version="${candidate}"; fi
	done < <(fetch_url "https://repo.packagist.org/p2/${package_name}.json" | "${JQ_BIN}" -r --arg package "${package_name}" '.packages[$package][] | select(.version_normalized | test("^[0-9]+[.][0-9]+[.][0-9]+[.]0$") ) | .version' | sed 's/^v//' | sort -V)
	require_stable_semver "Composer package ${package_name}" "${version}"
	printf '%s\n' "${version}"
}

latest_github_release() {
	local repository="$1"
	local version_pattern="$2"
	local keep_v="$3" intent="$4" strategy="${5:-github-v}"
	local releases version exact_tag
	if [[ "${intent}" == =* ]]; then
		exact_tag="v${intent#=}"
		# jq evaluates $tag; the shell must not expand it.
		# shellcheck disable=SC2016
		releases="$(fetch_url "https://api.github.com/repos/${repository}/releases/tags/${exact_tag}" | "${JQ_BIN}" -ec --arg tag "${exact_tag}" 'if type == "object" and .tag_name == $tag and .draft == false and .prerelease == false then [.] else error("invalid exact stable release") end')" || fail "exact GitHub release ${repository}@${exact_tag} is missing or unstable"
	else
		releases="$(fetch_github_release_pages "${repository}" | "${JQ_BIN}" -sc '.')"
	fi
	validate_unique_github_release_tags "${repository}" "${releases}"
	version="$(printf '%s' "${releases}" | "${JQ_BIN}" -r '.[] | select(.draft == false and .prerelease == false) | .tag_name' | grep -E "${version_pattern}" | select_newest_stable_candidate "${intent}" "${strategy}" "GitHub repository ${repository}")"
	[ -n "${version}" ] || fail "no stable ${version_pattern} release found for ${repository}"
	require_stable_semver "GitHub repository ${repository}" "${version}"
	if [ "${keep_v}" = no ]; then
		version="${version#v}"
	fi
	printf '%s\n' "${version}"
}

validate_unique_github_release_tags() {
	local repository="$1" releases="$2"
	printf '%s' "${releases}" | "${JQ_BIN}" -e '
		if type != "array" then error("expected release array")
		elif any(group_by(.tag_name)[]; length > 1) then error("duplicate release tag")
		else true end
	' >/dev/null || fail "GitHub returned duplicate or malformed release metadata for ${repository}"
}

fetch_github_release_pages() {
	local repository="$1" page=1 page_json count
	while [ "${page}" -le 100 ]; do
		page_json="$(fetch_url "https://api.github.com/repos/${repository}/releases?per_page=100&page=${page}")" || fail "GitHub release page ${page} failed for ${repository}"
		count="$(printf '%s' "${page_json}" | "${JQ_BIN}" -er 'if type == "array" then length else error("expected release array") end')" || fail "GitHub returned invalid release page ${page} for ${repository}"
		printf '%s' "${page_json}" | "${JQ_BIN}" -c '.[]'
		[ "${count}" -eq 100 ] || return 0
		page=$((page + 1))
	done
	fail "GitHub pagination exceeded 100 pages for ${repository}"
}

latest_terraform_version() {
	local intent="$1" version
	version="$(fetch_url 'https://releases.hashicorp.com/terraform/index.json' | "${JQ_BIN}" -r '.versions | keys[]' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | select_newest_stable_candidate "${intent}" github-v Terraform)"
	[ -n "${version}" ] || fail "no stable Terraform 1.x release found"
	require_stable_semver Terraform "${version}"
	printf '%s\n' "${version}"
}

latest_kubectl_version() {
	local lane="$1" version
	lane="${lane#=}"
	[[ "${lane}" == *.* ]] || fail "kubectl intent must specify a minor lane"
	lane="$(cut -d. -f1,2 <<<"${lane}")"
	version="$(fetch_url "https://dl.k8s.io/release/stable-${lane}.txt")"
	version="${version//$'\r'/}"
	version="${version//$'\n'/}"
	[[ "${version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "kubectl channel returned invalid version '${version}'"
	printf '%s\n' "${version#v}"
}

policy_value() {
	local key="$1"
	sed -nE "s/^${key}=\"([^\"]+)\"$/\1/p" "${POLICY_FILE}"
}

validate_inventory() {
	local key intent_key
	declare -A inventory=()

	for key in "${MANAGED_KEYS[@]}"; do
		inventory["${key}"]=$((${inventory["${key}"]:-0} + 1))
	done
	while IFS= read -r key; do
		[ "${inventory[${key}]:-0}" -eq 1 ] || fail "policy key ${key} must appear exactly once in the managed or excluded inventory"
		unset 'inventory['"${key}"']'
	done < <(sed -nE 's/^(LOCK_[A-Z0-9_]+)=.*/\1/p' "${POLICY_FILE}")

	for key in "${!inventory[@]}"; do
		[ "${inventory[${key}]}" -eq 1 ] || fail "inventory key ${key} is classified more than once"
		grep -q "^${key}=" "${POLICY_FILE}" || fail "inventory key ${key} is absent from the policy"
	done

	while IFS= read -r intent_key; do
		validate_intent "${intent_key}" "$(policy_value "${intent_key}")" "$(strategy_for_key "${intent_key}")"
	done < <(sed -nE 's/^(TOOL_[A-Z0-9_]+_VERSION)=.*/\1/p' "${POLICY_FILE}")
}

discover_gentle_ai_digests() {
	local version release_url release_json architecture asset_name digest
	version="${CANDIDATES[LOCK_GENTLE_AI_VERSION]}"
	require_stable_semver LOCK_GENTLE_AI_VERSION "${version}"
	release_url="https://api.github.com/repos/Gentleman-Programming/gentle-ai/releases/tags/v${version}"
	release_json="$(fetch_url "${release_url}")"

	# jq variables are intentionally evaluated by jq, not the shell.
	# shellcheck disable=SC2016
	printf '%s' "${release_json}" | "${JQ_BIN}" -e \
		--arg html_url "https://github.com/Gentleman-Programming/gentle-ai/releases/tag/v${version}" \
		--arg tag "v${version}" \
		'.html_url == $html_url and .tag_name == $tag and .draft == false and .prerelease == false and ((has("immutable") | not) or .immutable == true)' \
		>/dev/null || fail "Gentle AI release metadata failed repository, tag, stability, or immutability validation"

	for architecture in amd64 arm64; do
		asset_name="gentle-ai_${version}_linux_${architecture}.tar.gz"
		# shellcheck disable=SC2016
		digest="$(printf '%s' "${release_json}" | "${JQ_BIN}" -er --arg name "${asset_name}" --arg download_url "https://github.com/Gentleman-Programming/gentle-ai/releases/download/v${version}/${asset_name}" '
			[.assets[] | select(.name == $name)]
			| if length == 1 and .[0].browser_download_url == $download_url then .[0].digest else error("expected exactly one matching asset") end
		')" || fail "Gentle AI release must contain exactly one matching ${architecture} asset"
		[[ "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "Gentle AI ${architecture} asset has an invalid SHA-256 digest"
		CANDIDATES["LOCK_GENTLE_AI_SHA256_${architecture^^}"]="${digest#sha256:}"
	done
}

discover_archify_release() {
	local releases release_json version asset_url digest archive extraction
	local intent
	intent="$(policy_value TOOL_ARCHIFY_VERSION)"
	if [[ "${intent}" == =* ]]; then
		# jq evaluates $tag; the shell must not expand it.
		# shellcheck disable=SC2016
		releases="$(fetch_url "https://api.github.com/repos/tt-a1i/archify/releases/tags/v${intent#=}" | "${JQ_BIN}" -ec --arg tag "v${intent#=}" 'if type == "object" and .tag_name == $tag and .draft == false and .prerelease == false then [.] else error("invalid exact stable release") end')" || fail "exact Archify release is missing or unstable"
	else
		releases="$(fetch_github_release_pages tt-a1i/archify | "${JQ_BIN}" -sc '.')"
	fi
	validate_unique_github_release_tags tt-a1i/archify "${releases}"
	version="$(printf '%s' "${releases}" | "${JQ_BIN}" -r '.[] | select(.draft == false and .prerelease == false) | .tag_name' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | select_newest_stable_candidate "${intent}" github-v 'GitHub repository tt-a1i/archify')"
	[ -n "${version}" ] || fail "no stable Archify release found"
	require_stable_semver "GitHub repository tt-a1i/archify" "${version}"
	# shellcheck disable=SC2016
	release_json="$(printf '%s' "${releases}" | "${JQ_BIN}" -c --arg tag "${version}" '[.[] | select(.tag_name == $tag)] | if length == 1 then .[0] else error("expected one release") end')" || fail "Archify release metadata is ambiguous"
	asset_url="https://github.com/tt-a1i/archify/releases/download/${version}/archify.zip"
	# shellcheck disable=SC2016
	digest="$(printf '%s' "${release_json}" | "${JQ_BIN}" -er --arg url "${asset_url}" '
		if .draft == false and .prerelease == false and .immutable == true then
			[.assets[] | select(.name == "archify.zip")]
			| if length == 1 and .[0].browser_download_url == $url then .[0].digest else error("invalid canonical asset") end
		else error("release is not immutable stable") end
	')" || fail "Archify release must have one canonical immutable archify.zip asset"
	[[ "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "Archify asset has an invalid SHA-256 digest"
	archive="${TEMP_DIR}/archify.zip"
	extraction="${TEMP_DIR}/archify-extracted"
	fetch_url_to_file "${asset_url}" "${archive}"
	bash -c '
		source "$1"
		source "$2"
		devcontainer_validate_archify_archive "$3" "$4" "$5" "$6"
	' _ "${COMMON_SH}" "${ARCHIFY_ARCHIVE_SH}" "${archive}" "${version#v}" "${digest#sha256:}" "${extraction}" ||
		fail "Archify candidate ZIP failed digest, layout, entry-type, or embedded-version validation"
	CANDIDATES[LOCK_ARCHIFY_VERSION]="${version#v}"
	CANDIDATES[LOCK_ARCHIFY_SHA256]="${digest#sha256:}"
}

discover_github_binary_release() {
	local key="$1" repository="$2" version="$3" asset_template="$4"
	local release_json architecture asset_arch asset_name digest
	release_json="$(fetch_url "https://api.github.com/repos/${repository}/releases/tags/v${version}")"
	# jq variables are evaluated by jq, not by the shell.
	# shellcheck disable=SC2016
	printf '%s' "${release_json}" | "${JQ_BIN}" -e --arg tag "v${version}" \
		'.tag_name == $tag and .draft == false and .prerelease == false' >/dev/null ||
		fail "${repository} release metadata is not one exact stable release"
	for architecture in amd64 arm64; do
		asset_arch="${architecture}"
		[ "${key}" != LOCK_OPENCODE ] || { [ "${architecture}" = amd64 ] && asset_arch=x64 || asset_arch=arm64; }
		asset_name="${asset_template//\{version\}/${version}}"
		asset_name="${asset_name//\{arch\}/${asset_arch}}"
		# shellcheck disable=SC2016
		digest="$(printf '%s' "${release_json}" | "${JQ_BIN}" -er --arg name "${asset_name}" '[.assets[] | select(.name == $name)] | if length == 1 then .[0].digest else error("expected one asset") end')" ||
			fail "${repository} must contain exactly one ${asset_name} asset"
		[[ "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "${repository} ${asset_name} has no valid SHA-256"
		CANDIDATES["${key}_SHA256_${architecture^^}"]="${digest#sha256:}"
	done
}

discover_candidates() {
	local spec key package_name
	local java_intent node_intent php_intent
	java_intent="$(policy_value TOOL_JAVA_VERSION)"
	node_intent="$(policy_value TOOL_NODE_VERSION)"
	php_intent="$(policy_value TOOL_PHP_VERSION)"
	CANDIDATES[LOCK_JAVA_INSTALL_VERSION]="${java_intent#=}"
	CANDIDATES[LOCK_JAVA_REQUIRED_VERSION]="$(cut -d- -f1 <<<"${java_intent#=}" | cut -d. -f1)"
	CANDIDATES[LOCK_NODE_MAJOR]="$(cut -d. -f1 <<<"${node_intent#=}")"
	CANDIDATES[LOCK_PHP_SERIES]="$(cut -d. -f1,2 <<<"${php_intent#=}")"
	CANDIDATES[LOCK_GRAPHIFY_VERSION]="$(latest_pypi_version graphifyy "$(policy_value TOOL_GRAPHIFY_VERSION)")"
	CANDIDATES[LOCK_PHPUNIT_VERSION]="$(latest_composer_version phpunit/phpunit "$(policy_value TOOL_PHPUNIT_VERSION)")"

	printf 'Discovering exact pnpm package versions...\n'
	for spec in "${PACKAGE_SPECS[@]}"; do
		IFS='|' read -r key package_name <<<"${spec}"
		CANDIDATES["${key}"]="$(latest_package_version "${package_name}" "$(policy_value "$(intent_key_for_lock "${key}")")")"
	done

	printf 'Discovering constrained direct releases...\n'
	CANDIDATES[LOCK_GENTLE_AI_VERSION]="$(latest_github_release 'Gentleman-Programming/gentle-ai' '^v[0-9]+\.[0-9]+\.[0-9]+$' no "$(policy_value TOOL_GENTLE_AI_VERSION)")"
	discover_gentle_ai_digests
	discover_archify_release
	CANDIDATES[LOCK_C4_PLANTUML_VERSION]="$(latest_github_release 'plantuml-stdlib/C4-PlantUML' '^v[0-9]+\.[0-9]+\.[0-9]+$' no "$(policy_value TOOL_C4_PLANTUML_VERSION)")"
	CANDIDATES[LOCK_TERRAFORM_VERSION]="$(latest_terraform_version "$(policy_value TOOL_TERRAFORM_VERSION)")"
	CANDIDATES[LOCK_GITLEAKS_VERSION]="$(latest_github_release 'gitleaks/gitleaks' '^v[0-9]+\.[0-9]+\.[0-9]+$' no "$(policy_value TOOL_GITLEAKS_VERSION)")"
	CANDIDATES[LOCK_PULUMI_VERSION]="$(latest_github_release 'pulumi/pulumi' '^v[0-9]+\.[0-9]+\.[0-9]+$' no "$(policy_value TOOL_PULUMI_VERSION)")"
	CANDIDATES[LOCK_OPENTOFU_VERSION]="$(latest_github_release 'opentofu/opentofu' '^v[0-9]+\.[0-9]+\.[0-9]+$' no "$(policy_value TOOL_OPENTOFU_VERSION)")"
	CANDIDATES[LOCK_TERRAGRUNT_VERSION]="$(latest_github_release 'gruntwork-io/terragrunt' '^v[0-9]+\.[0-9]+\.[0-9]+$' no "$(policy_value TOOL_TERRAGRUNT_VERSION)")"
	CANDIDATES[LOCK_KUBECTL_VERSION]="$(latest_kubectl_version "$(policy_value TOOL_KUBECTL_VERSION)")"
	CANDIDATES[LOCK_PLANTUML_VERSION]="$(latest_github_release 'plantuml/plantuml' '^v1\.[0-9]{4}\.[0-9]+$' no "$(policy_value TOOL_PLANTUML_VERSION)" plantuml)"
	local plantuml_digest
	plantuml_digest="$(fetch_url "https://repo.maven.apache.org/maven2/net/sourceforge/plantuml/plantuml/${CANDIDATES[LOCK_PLANTUML_VERSION]}/plantuml-${CANDIDATES[LOCK_PLANTUML_VERSION]}.jar.sha256")"
	plantuml_digest="${plantuml_digest//[[:space:]]/}"
	[[ "${plantuml_digest}" =~ ^[0-9a-f]{64}$ ]] || fail "PlantUML Maven metadata has an invalid SHA-256"
	CANDIDATES[LOCK_PLANTUML_SHA256]="${plantuml_digest}"
	CANDIDATES[LOCK_DELVE_VERSION]="$(latest_github_release 'go-delve/delve' '^v[0-9]+\.[0-9]+\.[0-9]+$' yes "$(policy_value TOOL_DELVE_VERSION)")"
	CANDIDATES[LOCK_ENGRAM_VERSION]="$(latest_github_release 'Gentleman-Programming/engram' '^v[0-9]+\.[0-9]+\.[0-9]+$' no "$(policy_value TOOL_ENGRAM_VERSION)")"
	CANDIDATES[LOCK_OPENCODE_VERSION]="$(latest_github_release 'anomalyco/opencode' '^v[0-9]+\.[0-9]+\.[0-9]+$' no "$(policy_value TOOL_OPENCODE_VERSION)")"
	discover_github_binary_release LOCK_ENGRAM Gentleman-Programming/engram "${CANDIDATES[LOCK_ENGRAM_VERSION]}" 'engram_{version}_linux_{arch}.tar.gz'
	discover_github_binary_release LOCK_OPENCODE anomalyco/opencode "${CANDIDATES[LOCK_OPENCODE_VERSION]}" 'opencode-linux-{arch}.tar.gz'

	local go_json go_version architecture go_digest
	go_json="$(fetch_url 'https://go.dev/dl/?mode=json')"
	go_version="$(printf '%s' "${go_json}" | "${JQ_BIN}" -er '.[].version' | select_newest_stable_candidate "$(policy_value TOOL_GO_VERSION)" github-v Go)"
	[[ "${go_version}" =~ ^go[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Go returned an invalid stable version"
	CANDIDATES[LOCK_GO_VERSION]="${go_version}"
	for architecture in amd64 arm64; do
		# shellcheck disable=SC2016
		go_digest="$(printf '%s' "${go_json}" | "${JQ_BIN}" -er --arg version "${go_version}" --arg arch "${architecture}" '[.[].files[] | select(.version == $version and .os == "linux" and .arch == $arch and .kind == "archive")] | if length == 1 then .[0].sha256 else error("expected one Go archive") end')" || fail "Go must publish one linux/${architecture} archive"
		[[ "${go_digest}" =~ ^[0-9a-f]{64}$ ]] || fail "Go ${architecture} archive has an invalid SHA-256"
		CANDIDATES["LOCK_GO_SHA256_${architecture^^}"]="${go_digest}"
	done

	CANDIDATES[LOCK_BATS_VERSION]="$(latest_github_release 'bats-core/bats-core' '^v[0-9]+\.[0-9]+\.[0-9]+$' no "$(policy_value TOOL_BATS_VERSION)")"
	local bats_archive="${TEMP_DIR}/bats.tar.gz"
	fetch_url_to_file "https://github.com/bats-core/bats-core/archive/refs/tags/v${CANDIDATES[LOCK_BATS_VERSION]}.tar.gz" "${bats_archive}"
	CANDIDATES[LOCK_BATS_SHA256]="$(sha256sum "${bats_archive}" | awk '{print $1}')"

	local delve_checksums delve_version
	delve_version="${CANDIDATES[LOCK_DELVE_VERSION]#v}"
	delve_checksums="$(fetch_url "https://github.com/go-delve/delve/releases/download/v${delve_version}/checksums.txt")"
	for architecture in amd64 arm64; do
		go_digest="$(printf '%s\n' "${delve_checksums}" | awk -v name="dlv_${delve_version}_linux_${architecture}.tar.gz" '$2 == name {print $1}')"
		[[ "${go_digest}" =~ ^[0-9a-f]{64}$ ]] || fail "Delve checksums omit linux/${architecture}"
		CANDIDATES["LOCK_DELVE_SHA256_${architecture^^}"]="${go_digest}"
	done

	local c4_archive="${TEMP_DIR}/c4-plantuml.tar.gz"
	fetch_url_to_file \
		"https://codeload.github.com/plantuml-stdlib/C4-PlantUML/tar.gz/refs/tags/v${CANDIDATES[LOCK_C4_PLANTUML_VERSION]}" \
		"${c4_archive}"
	[ -s "${c4_archive}" ] || fail "C4-PlantUML archive is empty"
	CANDIDATES[LOCK_C4_PLANTUML_SHA256]="$(sha256sum "${c4_archive}" | awk '{print $1}')"
	[[ "${CANDIDATES[LOCK_C4_PLANTUML_SHA256]}" =~ ^[0-9a-f]{64}$ ]] || fail "invalid C4-PlantUML SHA-256"
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
		[ -n "${CANDIDATES[${key}]:-}" ] || fail "candidate is missing ${key}"
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
	[ -f "${ARCHIFY_ARCHIVE_SH}" ] || fail "Archify archive validator not found: ${ARCHIFY_ARCHIVE_SH}"
	require_command "${PNPM_BIN}"
	require_command "${CURL_BIN}"
	require_command "${JQ_BIN}"
	require_command sha256sum
	require_command node
	require_command unzip
	validate_inventory
	if [ "${1:-}" = "--validate" ]; then
		printf 'ok: %s\n' "${POLICY_FILE}"
		exit 0
	fi

	TEMP_DIR="$(mktemp -d)"
	discover_candidates
	apply_intent_contract
	publish_policy
	printf "\nRun 'task container:rebuild' to apply these versions.\n"
}

main "$@"
