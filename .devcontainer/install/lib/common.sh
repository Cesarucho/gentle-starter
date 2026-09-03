#!/usr/bin/env bash
# common.sh — shared helpers for .devcontainer/install/* scripts.
#
# Source this file from any install script:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   # shellcheck source=../lib/common.sh
#   source "${SCRIPT_DIR}/../lib/common.sh"
#
# All helpers are prefixed with `devcontainer_` to avoid namespace
# collisions with caller-defined symbols. A re-source guard at the
# top makes the file safe to source multiple times in the same shell.

# Re-source guard: bail out early if this file was already loaded.
if [ -n "${DEVC_INSTALL_LIB_COMMON_LOADED:-}" ]; then
	return 0
fi
readonly DEVC_INSTALL_LIB_COMMON_LOADED=1

# ---------------------------------------------------------------------------
# Declarative tool-version policy
# ---------------------------------------------------------------------------

# Resolve the version-policy file without depending on the current directory.
# An explicit path is authoritative. Otherwise support both the Docker build
# copy (`.devcontainer-install/tool-versions.conf`) and the repository runtime
# tree (`.devcontainer/tool-versions.conf`).
devcontainer_tool_versions_file() {
	local install_root
	install_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

	if [ -n "${DEVCONTAINER_TOOL_VERSIONS_FILE:-}" ]; then
		printf '%s\n' "${DEVCONTAINER_TOOL_VERSIONS_FILE}"
	elif [ -f "${install_root}/tool-versions.conf" ]; then
		printf '%s\n' "${install_root}/tool-versions.conf"
	else
		printf '%s\n' "${install_root}/../tool-versions.conf"
	fi
}

# Load a restricted assignment-only file. The file is data, never shell code:
# no source, eval, command substitutions, exports, functions, or extra syntax.
devcontainer_load_tool_versions() {
	local versions_file="${1:-}"
	local line line_number=0 key quoted value
	local assignment_pattern="^[[:space:]]*(TOOL_[A-Z0-9_]+)[[:space:]]*=[[:space:]]*('[^']*'|\"[^\"]*\")[[:space:]]*$"
	local command_substitution="\$("
	local backtick="\`"
	local -A seen=()

	if [ -z "${versions_file}" ]; then
		versions_file="$(devcontainer_tool_versions_file)"
	fi
	if [ ! -f "${versions_file}" ]; then
		devcontainer_log_error "Tool versions file not found: ${versions_file}"
		return 1
	fi

	while IFS= read -r line || [ -n "${line}" ]; do
		line_number=$((line_number + 1))
		line="${line%$'\r'}"
		if [[ "${line}" =~ ^[[:space:]]*$ || "${line}" =~ ^[[:space:]]*# ]]; then
			continue
		fi
		if [[ "${line}" == *"${command_substitution}"* || "${line}" == *"${backtick}"* ]]; then
			devcontainer_log_error "Invalid tool versions syntax at ${versions_file}:${line_number}"
			return 1
		fi
		if [[ ! "${line}" =~ ${assignment_pattern} ]]; then
			devcontainer_log_error "Invalid tool versions assignment at ${versions_file}:${line_number}"
			return 1
		fi

		key="${BASH_REMATCH[1]}"
		quoted="${BASH_REMATCH[2]}"
		value="${quoted:1:${#quoted}-2}"
		if [ -z "${value}" ]; then
			devcontainer_log_error "Empty tool version is not allowed for ${key} at ${versions_file}:${line_number}"
			return 1
		fi
		if [ -n "${seen[${key}]:-}" ]; then
			devcontainer_log_error "Duplicate tool version key ${key} at ${versions_file}:${line_number}"
			return 1
		fi
		seen["${key}"]=1
		printf -v "${key}" '%s' "${value}"
	done <"${versions_file}"
}

# ---------------------------------------------------------------------------
# Phase detection
# ---------------------------------------------------------------------------

# Echoes the current devcontainer phase: "build" or "runtime".
devcontainer_phase() {
	printf '%s\n' "${DEVCONTAINER_PHASE:-build}"
}

# Returns 0 when the script is running during image build.
devcontainer_is_build() {
	[ "$(devcontainer_phase)" = "build" ]
}

# Returns 0 when the script is running during container start.
devcontainer_is_runtime() {
	[ "$(devcontainer_phase)" = "runtime" ]
}

# ---------------------------------------------------------------------------
# Architecture
# ---------------------------------------------------------------------------

# Echoes the normalized target architecture (amd64 or arm64).
# Mirrors the resolution used by existing scripts in the project.
devcontainer_arch() {
	case "$(uname -m)" in
	x86_64)
		printf 'amd64'
		;;
	aarch64 | arm64)
		printf 'arm64'
		;;
	*)
		echo "Unsupported architecture: $(uname -m)" >&2
		return 1
		;;
	esac
}

# ---------------------------------------------------------------------------
# Command and path checks
# ---------------------------------------------------------------------------

# Returns 0 when a command is on PATH.
devcontainer_has_cmd() {
	command -v "$1" >/dev/null 2>&1
}

# Returns 0 when a filesystem path exists.
devcontainer_has_path() {
	[ -e "$1" ]
}

# Skip the rest of the current script (exit 0) when a command is present.
devcontainer_skip_if_cmd() {
	if devcontainer_has_cmd "$1"; then
		devcontainer_log_info "Skipping: $1 already on PATH"
		exit 0
	fi
}

# Skip the rest of the current script (exit 0) when a path exists.
devcontainer_skip_if_path() {
	if devcontainer_has_path "$1"; then
		devcontainer_log_info "Skipping: $1 already exists at $1"
		exit 0
	fi
}

# ---------------------------------------------------------------------------
# Fetching and integrity
# ---------------------------------------------------------------------------

# Fetch a URL to a local path with curl, failing on HTTP errors.
# Usage: devcontainer_fetch <url> <output-path>
devcontainer_fetch() {
	local url="$1"
	local output="$2"
	curl -fsSL -o "${output}" "${url}"
}

# Verify a file's SHA-256 against an expected hex digest.
# Usage: devcontainer_verify_sha256 <path> <expected-sha256>
devcontainer_verify_sha256() {
	local file="$1"
	local expected="$2"
	local actual
	actual="$(sha256sum "${file}" | awk '{print $1}')"
	if [ "${actual}" != "${expected}" ]; then
		devcontainer_log_error "SHA-256 mismatch for ${file}: expected ${expected}, got ${actual}"
		return 1
	fi
}

# ---------------------------------------------------------------------------
# Privilege escalation and binary install
# ---------------------------------------------------------------------------

# Run a command as root, escalating with sudo when not already root.
devcontainer_run_as_root() {
	if [ "$(id -u)" -eq 0 ]; then
		"$@"
	else
		sudo "$@"
	fi
}

# Install a binary into /usr/local/bin with mode 0755.
# Usage: devcontainer_install_bin <source-path> [name]
devcontainer_install_bin() {
	local source="$1"
	local name="${2:-$(basename "${source}")}"
	devcontainer_run_as_root install -m 0755 "${source}" "/usr/local/bin/${name}"
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

devcontainer_log_info() {
	printf '[install:info] %s\n' "$*"
}

devcontainer_log_warn() {
	printf '[install:warn] %s\n' "$*" >&2
}

devcontainer_log_error() {
	printf '[install:error] %s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# Version extraction and comparison
# ---------------------------------------------------------------------------

# Export DEVCONTAINER_TOOL_VERSION so callers can read the extracted version.
DEVCONTAINER_TOOL_VERSION=""

# Extract version string from a command's --version output.
# Handles: go version go1.x.y, node v20.5.0, java version "21", and generic
# patterns. Returns 0 on success, 1 if the command is not found.
_devcontainer_get_version() {
	local cmd="$1"
	local version_output

	# Try "cmd --version" first (works for most tools, including Go 1.24+).
	# Fall back to "cmd version" for Go if --version exits non-zero.
	if ! version_output="$(eval "${cmd}" --version 2>&1)"; then
		if ! version_output="$(eval "${cmd}" version 2>&1)"; then
			return 1
		fi
	fi

	local _go_pat='go([0-9]+\.[0-9]+\.[0-9]+)'
	local _node_pat='v([0-9]+\.[0-9]+\.[0-9]+)'
	local _java_pat='version[[:space:]]+"([0-9]+)"'
	local _java2_pat='java[[:space:]]+([0-9]+)'
	local _xyz_pat='([0-9]+\.[0-9]+\.[0-9]+)'
	local _xy_pat='([0-9]+\.[0-9]+)'

	# go version go1.22.3 linux/amd64 → 1.22.3
	if [[ "$version_output" =~ $_go_pat ]]; then
		DEVCONTAINER_TOOL_VERSION="${BASH_REMATCH[1]}"
		return 0
	fi

	# node v20.5.0 → 20.5.0
	if [[ "$version_output" =~ $_node_pat ]]; then
		DEVCONTAINER_TOOL_VERSION="${BASH_REMATCH[1]}"
		return 0
	fi

	# java version "21" or java version "25" → 21 or 25
	if [[ "$version_output" =~ $_java_pat ]]; then
		DEVCONTAINER_TOOL_VERSION="${BASH_REMATCH[1]}"
		return 0
	fi

	# java 25 → 25 (alternative java --version format)
	if [[ "$version_output" =~ $_java2_pat ]]; then
		DEVCONTAINER_TOOL_VERSION="${BASH_REMATCH[1]}"
		return 0
	fi

	# Generic: first occurrence of X.Y.Z pattern anywhere in output
	if [[ "$version_output" =~ $_xyz_pat ]]; then
		DEVCONTAINER_TOOL_VERSION="${BASH_REMATCH[1]}"
		return 0
	fi

	# Generic: X.Y pattern as fallback
	if [[ "$version_output" =~ $_xy_pat ]]; then
		DEVCONTAINER_TOOL_VERSION="${BASH_REMATCH[1]}"
		return 0
	fi

	return 1
}

# Compare two version strings using sort -V.
# Returns 0 if $installed >= $required, 1 otherwise.
_devcontainer_version_compare() {
	local installed="$1"
	local required="$2"
	printf '%s\n%s\n' "${required}" "${installed}" | sort -V -C >/dev/null 2>&1
}

# Check if a command satisfies a minimum version requirement.
# Returns 0 if the version is sufficient, 1 otherwise.
# If version cannot be extracted, falls back to presence check (returns 0).
_devcontainer_version_satisfies() {
	local cmd="$1"
	local required="$2"

	if ! devcontainer_has_cmd "${cmd}"; then
		return 1
	fi

	DEVCONTAINER_TOOL_VERSION=""
	# Use `|| true` to prevent `set -e` from exiting the caller when
	# _devcontainer_get_version returns 1 (no match found).
	_devcontainer_get_version "${cmd}" || true

	# If no version was extracted, be lenient and return 0 (presence is
	# sufficient; caller can still fall back to a binary check).
	if [ -z "${DEVCONTAINER_TOOL_VERSION}" ]; then
		return 0
	fi

	_devcontainer_version_compare "${DEVCONTAINER_TOOL_VERSION}" "${required}"
}

# Check if a command exists and optionally meets a minimum version.
# Usage: devcontainer_check_tool <cmd> [required_version]
# Returns 0 on success, 1 if the tool is missing or version is insufficient.
devcontainer_check_tool() {
	local cmd="$1"
	local required="${2:-}"

	if [ -z "${required}" ]; then
		devcontainer_has_cmd "${cmd}"
		return $?
	fi

	_devcontainer_version_satisfies "${cmd}" "${required}"
}

# Same as devcontainer_check_tool, but also exports DEVCONTAINER_TOOL_VERSION
# with the extracted version string on success.
devcontainer_check_tool_with_version() {
	local cmd="$1"
	local required="${2:-}"

	DEVCONTAINER_TOOL_VERSION=""
	if devcontainer_check_tool "${cmd}" "${required}"; then
		return 0
	fi
	return 1
}

# Run an install function only if the tool is missing or version is insufficient.
# Usage: devcontainer_with_tool <cmd> <required_version> <install_fn>
# Logs info when skipping (tool OK) or running (tool missing/insufficient).
devcontainer_with_tool() {
	local cmd="$1"
	local required="$2"
	local install_fn="$3"

	# Disable `set -e` locally: the following conditional calls can return 1
	# (command not found or version insufficient), and we need to capture
	# those exit codes without exiting the shell.
	set +e
	local tool_ok=false
	if devcontainer_has_cmd "${cmd}"; then
		if _devcontainer_version_satisfies "${cmd}" "${required}"; then
			tool_ok=true
		fi
	fi
	set -e

	if $tool_ok; then
		devcontainer_log_info "Skipping ${cmd}: already present and version is sufficient"
		return 0
	fi

	# Use eval so the caller can pass any command string, including
	# quoted arguments: e.g. devcontainer_with_tool foo 1.0 "make install"
	eval "${install_fn}"
}
