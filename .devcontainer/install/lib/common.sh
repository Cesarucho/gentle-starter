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
