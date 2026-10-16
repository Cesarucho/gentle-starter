#!/usr/bin/env bash
#
# 1000-test-bats.sh — install BATS (Bash Automated Testing System).
#
# Lifecycle:
#   * DEVCONTAINER_PHASE=build   during image build (Dockerfile RUN loop)
#   * DEVCONTAINER_PHASE=runtime during container start (setup.sh)
#
# This script is idempotent: it skips if BATS is already on PATH.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/tar-archive.sh"

devcontainer_load_tool_versions

: "${BATS_VERSION:=${LOCK_BATS_VERSION:?missing LOCK_BATS_VERSION}}"
: "${BATS_INSTALL_DIR:=/usr/local}"
BATS_TMPDIR=""
BATS_TRANSACTION_ACTIVE=0
BATS_PUBLISHED_COUNT=0
declare -a BATS_DESTINATIONS=()
declare -a BATS_BACKUPS=()

cleanup_bats_install() {
	local index
	if [ "${BATS_TRANSACTION_ACTIVE}" -eq 1 ]; then
		set +e
		for ((index = BATS_PUBLISHED_COUNT - 1; index >= 0; index--)); do
			devcontainer_run_as_root rm -rf "${BATS_DESTINATIONS[index]}"
		done
		for ((index = ${#BATS_DESTINATIONS[@]} - 1; index >= 0; index--)); do
			[ -e "${BATS_BACKUPS[index]}" ] || [ -L "${BATS_BACKUPS[index]}" ] || continue
			devcontainer_run_as_root mv "${BATS_BACKUPS[index]}" "${BATS_DESTINATIONS[index]}"
		done
		set -e
	fi
	[ -z "${BATS_TMPDIR}" ] || devcontainer_run_as_root rm -rf "${BATS_TMPDIR}"
}

abort_bats_install() {
	cleanup_bats_install
	exit 1
}

validate_staged_bats() {
	local prefix="$1"
	python3 - "${prefix}" <<'PY'
import pathlib, stat, sys

prefix = pathlib.Path(sys.argv[1])
allowed_trees = ("lib/bats-core", "libexec/bats-core")
allowed_files = {"bin/bats", "share/man/man1/bats.1", "share/man/man7/bats.7"}
allowed_directories = {
    "bin", "lib", "lib/bats-core", "libexec", "libexec/bats-core",
    "share", "share/man", "share/man/man1", "share/man/man7",
}
required = ("bin/bats", "libexec/bats-core/bats", "share/man/man1/bats.1", "share/man/man7/bats.7")
for path in prefix.rglob("*"):
    relative = path.relative_to(prefix).as_posix()
    mode = path.lstat().st_mode
    if stat.S_ISLNK(mode) or not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)):
        raise SystemExit(f"unexpected staged BATS entry type: {relative}")
    if relative not in allowed_directories and relative not in allowed_files and not any(relative.startswith(tree + "/") for tree in allowed_trees):
        raise SystemExit(f"unexpected staged BATS output: {relative}")
for relative in required:
    if not (prefix / relative).is_file():
        raise SystemExit(f"missing staged BATS path: {relative}")
if stat.S_IMODE((prefix / "share/man/man7").stat().st_mode) != 0o755:
    raise SystemExit("unexpected staged BATS man7 directory mode")
if stat.S_IMODE((prefix / "share/man/man7/bats.7").stat().st_mode) != 0o644:
    raise SystemExit("unexpected staged BATS bats.7 mode")
PY
	[ "$("${prefix}/bin/bats" --version)" = "Bats ${BATS_VERSION}" ] || {
		devcontainer_log_error "Staged BATS version does not match ${BATS_VERSION}"
		return 1
	}
}

publish_staged_bats() {
	local prefix="$1" relative destination backup index
	local -a paths=(bin/bats lib/bats-core libexec/bats-core share/man/man1/bats.1 share/man/man7/bats.7)
	for relative in "${paths[@]}"; do
		destination="${BATS_INSTALL_DIR}/${relative}"
		backup="${BATS_TMPDIR}/backup/${relative}"
		BATS_DESTINATIONS+=("${destination}")
		BATS_BACKUPS+=("${backup}")
		devcontainer_run_as_root mkdir -p "$(dirname "${destination}")" "$(dirname "${backup}")"
		if devcontainer_run_as_root test -e "${destination}" || devcontainer_run_as_root test -L "${destination}"; then
			devcontainer_run_as_root mv "${destination}" "${backup}"
		fi
	done
	BATS_TRANSACTION_ACTIVE=1
	for ((index = 0; index < ${#paths[@]}; index++)); do
		devcontainer_run_as_root mv "${prefix}/${paths[index]}" "${BATS_DESTINATIONS[index]}"
		BATS_PUBLISHED_COUNT=$((BATS_PUBLISHED_COUNT + 1))
	done
	[ "$("${BATS_INSTALL_DIR}/bin/bats" --version)" = "Bats ${BATS_VERSION}" ] || return 1
	BATS_TRANSACTION_ACTIVE=0
	devcontainer_run_as_root rm -rf "${BATS_TMPDIR}/backup"
}

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'BATS_VERSION=%s\n' "${BATS_VERSION}"
	exit 0
fi

installed_bats_version() {
	local output
	devcontainer_has_cmd bats || return 1
	output="$(bats --version 2>/dev/null)" || return 1
	if [[ "${output}" =~ ^Bats[[:space:]]+v?([0-9]+[.][0-9]+[.][0-9]+)([[:space:]].*)?$ ]]; then
		printf '%s\n' "${BASH_REMATCH[1]}"
		return 0
	fi
	return 1
}

# Only run during build (BATS is a dev tool, not needed at runtime).
if ! devcontainer_is_build; then
	devcontainer_log_info "Skipping BATS: not in build phase"
	exit 0
fi

# Idempotency: skip only when the installed version matches policy.
installed_version="$(installed_bats_version || true)"
if [ "${installed_version}" = "${BATS_VERSION}" ]; then
	devcontainer_log_info "BATS ${BATS_VERSION} already installed at $(command -v bats)"
	exit 0
fi
if devcontainer_has_cmd bats; then
	devcontainer_log_warn "Replacing BATS at $(command -v bats): installed version is ${installed_version:-unrecognized}; required version is ${BATS_VERSION}"
fi

devcontainer_log_info "Installing BATS ${BATS_VERSION}"

# Download and verify the exact BATS source archive.
BATS_TMPDIR="$(mktemp -d)"
trap cleanup_bats_install EXIT
trap abort_bats_install HUP INT TERM
BATS_ARCHIVE="${BATS_TMPDIR}/bats.tar.gz"
BATS_SHA256="${LOCK_BATS_SHA256:?missing LOCK_BATS_SHA256}"
[[ "${BATS_SHA256}" =~ ^[0-9a-f]{64}$ ]] || {
	devcontainer_log_error "Invalid BATS SHA-256"
	exit 1
}
devcontainer_fetch "https://github.com/bats-core/bats-core/archive/refs/tags/v${BATS_VERSION}.tar.gz" "${BATS_ARCHIVE}"
devcontainer_verify_sha256 "${BATS_ARCHIVE}" "${BATS_SHA256}"
devcontainer_validate_bats_tar "${BATS_ARCHIVE}" "bats-core-${BATS_VERSION}" "${BATS_TMPDIR}"
BATS_SOURCE="${BATS_TMPDIR}/bats-core-${BATS_VERSION}"
[ -x "${BATS_SOURCE}/install.sh" ] || {
	devcontainer_log_error "BATS archive layout is invalid"
	exit 1
}

# Run upstream installation only against a private staging prefix.
BATS_STAGE="${BATS_TMPDIR}/stage"
mkdir -p "${BATS_STAGE}"
"${BATS_SOURCE}/install.sh" "${BATS_STAGE}"
validate_staged_bats "${BATS_STAGE}"
publish_staged_bats "${BATS_STAGE}"

# Clean up.
devcontainer_run_as_root rm -rf "${BATS_TMPDIR}"
BATS_TMPDIR=""
trap - EXIT HUP INT TERM

# Verify.
if ! devcontainer_has_cmd bats; then
	devcontainer_log_error "BATS install failed: bats not on PATH after install"
	exit 1
fi

devcontainer_log_info "BATS installed at $(command -v bats)"
