#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	BIN_DIR="${TEST_ROOT}/bin"
	INSTALL_ROOT="${TEST_ROOT}/opt/gga"
	GGA_BIN="${TEST_ROOT}/usr/local/bin/gga"
	POLICY="${TEST_ROOT}/policy"
	ARCHIVE="${TEST_ROOT}/gga.tar.gz"
	COMMIT="1124c3672f082c56b033c4e23a30e95d0e8cd593"
	VERSION="2.10.1"
	mkdir -p "${BIN_DIR}" "${TEST_ROOT}/tmp" "${TEST_ROOT}/home"
	cat >"${BIN_DIR}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
while [ "$#" -gt 0 ]; do
  case "$1" in -o) output="$2"; shift 2 ;; *) shift ;; esac
done
cp "${ARCHIVE_FIXTURE}" "${output}"
EOF
	cat >"${BIN_DIR}/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
	chmod 0755 "${BIN_DIR}/curl" "${BIN_DIR}/sudo"
	write_archive normal
	write_policy "$(sha256sum "${ARCHIVE}" | awk '{print $1}')"
}

teardown() { rm -rf "${TEST_ROOT}"; }

write_policy() {
	printf 'LOCK_GGA_VERSION="%s"\nLOCK_GGA_COMMIT="%s"\nLOCK_GGA_SHA256="%s"\n' \
		"${VERSION}" "${COMMIT}" "$1" >"${POLICY}"
}

write_archive() {
	local mode="$1" root="${TEST_ROOT}/gentleman-guardian-angel-${COMMIT}"
	rm -rf "${root}"
	mkdir -p "${root}/bin" "${root}/lib"
	cat >"${root}/bin/gga" <<'EOF'
#!/usr/bin/env bash
printf 'upstream gga %s\n' "${GGA_VERSION:-dev}"
EOF
	for source in cache providers pr_mode; do printf '#!/usr/bin/env bash\n' >"${root}/lib/${source}.sh"; done
	chmod 0755 "${root}/bin/gga"
	case "${mode}" in
	missing) rm "${root}/lib/providers.sh" ;;
	symlink) rm "${root}/lib/cache.sh"; ln -s providers.sh "${root}/lib/cache.sh" ;;
	esac
	tar -czf "${ARCHIVE}" -C "${TEST_ROOT}" "${root##*/}"
}

run_installer() {
	run env PATH="${BIN_DIR}:/usr/bin:/bin" TMPDIR="${TEST_ROOT}/tmp" ARCHIVE_FIXTURE="${ARCHIVE}" \
		HOME="${TEST_ROOT}/home" XDG_CACHE_HOME="${TEST_ROOT}/cache" XDG_CONFIG_HOME="${TEST_ROOT}/config" \
		DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY}" GGA_INSTALL_ROOT="${INSTALL_ROOT}" GGA_BIN="${GGA_BIN}" \
		bash "${REPO_ROOT}/.devcontainer/install/available/3070-ai-gga.sh"
}

@test "GGA installer verifies the source archive, installs image-owned sources, and launcher version is state-free" {
	run_installer
	[ "${status}" -eq 0 ]
	local destination="${INSTALL_ROOT}/${VERSION}-${COMMIT}"
	[ -x "${destination}/bin/gga" ]
	[ -f "${destination}/lib/cache.sh" ]
	[ -f "${destination}/lib/providers.sh" ]
	[ -f "${destination}/lib/pr_mode.sh" ]
	[ "$(cat "${destination}/.policy")" = "${VERSION}|${COMMIT}|$(sha256sum "${ARCHIVE}" | awk '{print $1}')" ]
	run "${GGA_BIN}" version
	[ "${status}" -eq 0 ]
	[ "${output}" = "gga v${VERSION}" ]
	[ ! -e "${TEST_ROOT}/home/.config/gga" ]
	[ ! -e "${TEST_ROOT}/home/.cache/gga" ]
	[ ! -e "${TEST_ROOT}/home/.gga" ]
}

@test "GGA installer is idempotent after a verified installation" {
	run_installer
	[ "${status}" -eq 0 ]
	local before="$(sha256sum "${GGA_BIN}")"
	run_installer
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"already installed"* ]]
	[ "$(sha256sum "${GGA_BIN}")" = "${before}" ]
}

@test "GGA installer rejects digest and unsafe source layouts before publication" {
	local mode digest
	for mode in mismatch missing symlink; do
		write_archive "${mode/mismatch/normal}"
		digest="$(sha256sum "${ARCHIVE}" | awk '{print $1}')"
		[ "${mode}" != mismatch ] || digest="$(printf '0%.0s' {1..64})"
		write_policy "${digest}"
		run_installer
		[ "${status}" -ne 0 ]
		[ ! -e "${INSTALL_ROOT}/${VERSION}-${COMMIT}" ]
		[ ! -e "${GGA_BIN}" ]
	done
}

@test "GGA policy diagnostic is resolved centrally without installation" {
	run env DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY}" \
		bash "${REPO_ROOT}/.devcontainer/install/available/3070-ai-gga.sh" --print-version-policy
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"GGA_VERSION=${VERSION}"* ]]
	[[ "${output}" == *"GGA_COMMIT=${COMMIT}"* ]]
	[ ! -e "${INSTALL_ROOT}" ]
}
