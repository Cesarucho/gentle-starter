#!/usr/bin/env bash
# Install the policy-pinned Gentleman Guardian Angel source distribution.
# Project configuration, hooks, and cache remain user-owned explicit actions.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions
: "${GGA_VERSION:=${LOCK_GGA_VERSION:?missing LOCK_GGA_VERSION}}"
: "${GGA_COMMIT:=${LOCK_GGA_COMMIT:?missing LOCK_GGA_COMMIT}}"
: "${GGA_SHA256:=${LOCK_GGA_SHA256:?missing LOCK_GGA_SHA256}}"
: "${GGA_INSTALL_ROOT:=/opt/gga}"
: "${GGA_BIN:=/usr/local/bin/gga}"

if [ "${1:-}" = --print-version-policy ]; then
	printf '%s\n' "GGA_VERSION=${GGA_VERSION}" "GGA_COMMIT=${GGA_COMMIT}" "GGA_SHA256=${GGA_SHA256}"
	exit 0
fi

[[ "${GGA_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
	devcontainer_log_error "GGA_VERSION must be an exact stable SemVer"
	exit 1
}
[[ "${GGA_COMMIT}" =~ ^[0-9a-f]{40}$ ]] || {
	devcontainer_log_error "GGA_COMMIT must be a 40-character lowercase Git commit"
	exit 1
}
[[ "${GGA_SHA256}" =~ ^[0-9a-f]{64}$ ]] || {
	devcontainer_log_error "GGA_SHA256 must be a 64-character lowercase digest"
	exit 1
}
if devcontainer_is_runtime; then
	devcontainer_log_info "GGA is image-owned; rebuild to install or update it."
	exit 0
fi
if [ -d "${GGA_BIN}" ]; then
	devcontainer_log_error "GGA launcher destination is a directory: ${GGA_BIN}"
	exit 1
fi

destination="${GGA_INSTALL_ROOT}/${GGA_VERSION}-${GGA_COMMIT}"
policy_file="${destination}/.policy"
if [ -e "${destination}" ] || [ -L "${destination}" ]; then
	if [ -f "${policy_file}" ] &&
		[ "$(cat "${policy_file}")" = "${GGA_VERSION}|${GGA_COMMIT}|${GGA_SHA256}" ] &&
		[ -x "${destination}/bin/gga" ] &&
		[ -f "${destination}/lib/cache.sh" ] && [ -f "${destination}/lib/providers.sh" ] &&
		[ -f "${destination}/lib/pr_mode.sh" ]; then
		devcontainer_run_as_root mkdir -p "$(dirname "${GGA_BIN}")"
		devcontainer_run_as_root tee "${GGA_BIN}" >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == version || "\${1:-}" == --version || "\${1:-}" == -v ]]; then
  printf 'gga v%s\\n' '${GGA_VERSION}'
  exit 0
fi
export GGA_VERSION='${GGA_VERSION}'
exec '${destination}/bin/gga' "\$@"
EOF
		devcontainer_run_as_root chmod 0755 "${GGA_BIN}"
		devcontainer_log_info "GGA ${GGA_VERSION} already installed"
		exit 0
	fi
	devcontainer_log_error "Invalid existing image-owned GGA installation: ${destination}"
	exit 1
fi

tmp_dir="$(mktemp -d)"
stage=""
cleanup() {
	rm -rf "${tmp_dir}"
	[ -z "${stage}" ] || devcontainer_run_as_root rm -rf -- "${stage}"
}
trap cleanup EXIT
archive="${tmp_dir}/gga.tar.gz"
archive_root="gentleman-guardian-angel-${GGA_COMMIT}"
archive_url="https://codeload.github.com/Gentleman-Programming/gentleman-guardian-angel/tar.gz/${GGA_COMMIT}"

devcontainer_log_info "Downloading GGA ${GGA_VERSION} (${GGA_COMMIT})"
devcontainer_fetch "${archive_url}" "${archive}"
devcontainer_verify_sha256 "${archive}" "${GGA_SHA256}"

entries="${tmp_dir}/entries"
tar -tzf "${archive}" >"${entries}" || {
	devcontainer_log_error "GGA source archive is malformed"
	exit 1
}
[ -s "${entries}" ] || {
	devcontainer_log_error "GGA source archive is empty"
	exit 1
}
if ! awk -v root="${archive_root}/" '
  /^\// || /^[A-Za-z]:[\\/]/ || /\\/ || /(^|\/)\.\.?($|\/)/ || index($0, root) != 1 { exit 1 }
' "${entries}" || [ "$(sort -u "${entries}" | wc -l)" -ne "$(wc -l <"${entries}")" ]; then
	devcontainer_log_error "GGA source archive has an unsafe or unexpected layout"
	exit 1
fi
for required in "${archive_root}/bin/gga" "${archive_root}/lib/cache.sh" "${archive_root}/lib/providers.sh" "${archive_root}/lib/pr_mode.sh"; do
	[ "$(grep -Fxc "${required}" "${entries}")" -eq 1 ] || {
		devcontainer_log_error "GGA source archive is missing required file: ${required#"${archive_root}"/}"
		exit 1
	}
done

devcontainer_run_as_root mkdir -p -- "${GGA_INSTALL_ROOT}"
stage="$(devcontainer_run_as_root mktemp -d "${GGA_INSTALL_ROOT}/.stage.XXXXXX")"
devcontainer_run_as_root tar -xzf "${archive}" --no-same-owner --no-same-permissions -C "${stage}" \
	"${archive_root}/bin/gga" "${archive_root}/lib"
devcontainer_run_as_root mv "${stage}/${archive_root}/bin" "${stage}/bin"
devcontainer_run_as_root mv "${stage}/${archive_root}/lib" "${stage}/lib"
devcontainer_run_as_root rmdir "${stage}/${archive_root}"
if devcontainer_run_as_root find "${stage}" \( -type l -o -type b -o -type c -o -type p -o -type s \) -print -quit | grep -q . ||
	! devcontainer_run_as_root test -x "${stage}/bin/gga" ||
	! devcontainer_run_as_root test -f "${stage}/lib/cache.sh" ||
	! devcontainer_run_as_root test -f "${stage}/lib/providers.sh" ||
	! devcontainer_run_as_root test -f "${stage}/lib/pr_mode.sh"; then
	devcontainer_log_error "GGA source archive has unsafe entries or an invalid extracted layout"
	exit 1
fi
printf '%s\n' "${GGA_VERSION}|${GGA_COMMIT}|${GGA_SHA256}" | devcontainer_run_as_root tee "${stage}/.policy" >/dev/null
devcontainer_run_as_root chmod 0755 "${stage}/bin/gga"
devcontainer_run_as_root chmod 0644 "${stage}/lib/"*.sh "${stage}/.policy"
devcontainer_run_as_root mv -- "${stage}" "${destination}"
stage=""

devcontainer_run_as_root mkdir -p "$(dirname "${GGA_BIN}")"
devcontainer_run_as_root tee "${GGA_BIN}" >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == version || "\${1:-}" == --version || "\${1:-}" == -v ]]; then
  printf 'gga v%s\\n' '${GGA_VERSION}'
  exit 0
fi
export GGA_VERSION='${GGA_VERSION}'
exec '${destination}/bin/gga' "\$@"
EOF
devcontainer_run_as_root chmod 0755 "${GGA_BIN}"
"${GGA_BIN}" version | grep -Fx "gga v${GGA_VERSION}" >/dev/null || {
	devcontainer_log_error "GGA launcher verification failed"
	exit 1
}
devcontainer_log_info "GGA ${GGA_VERSION} installed; run gga init and gga install manually in a project."
