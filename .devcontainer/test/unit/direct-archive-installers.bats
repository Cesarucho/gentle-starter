#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	BIN_DIR="${TEST_ROOT}/bin"
	INSTALL_DIR="${TEST_ROOT}/install"
	POLICY="${TEST_ROOT}/policy"
	ARCHIVE="${TEST_ROOT}/fixture.tar.gz"
	mkdir -p "${BIN_DIR}" "${INSTALL_DIR}" "${TEST_ROOT}/tmp"
	cat >"${BIN_DIR}/curl" <<'EOF'
#!/usr/bin/env bash
while [ "$#" -gt 0 ]; do
	case "$1" in -o) output="$2"; shift 2 ;; *) shift ;; esac
done
cp "${ARCHIVE_FIXTURE}" "${output}"
EOF
	cat >"${BIN_DIR}/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${FIXTURE_MACHINE}"
EOF
	cat >"${BIN_DIR}/sudo" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" != -n ] || shift
exec "$@"
EOF
	chmod +x "${BIN_DIR}/curl" "${BIN_DIR}/uname" "${BIN_DIR}/sudo"
}

teardown() { rm -rf "${TEST_ROOT}"; }

assert_installer_temp_is_empty() {
	[ -z "$(find "${TEST_ROOT}/tmp" -mindepth 1 -print -quit)" ]
}

write_bats_archive() {
	local version="$1" mode="${2:-normal}" root
	root="${TEST_ROOT}/bats-core-${version}"
	rm -rf "${root}"
	mkdir -p "${root}"
	cat >"${root}/install.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
prefix="\$1"
mkdir -p "\${prefix}/bin" "\${prefix}/lib/bats-core" "\${prefix}/libexec/bats-core" "\${prefix}/share/man/man1" "\${prefix}/share/man/man7"
cat >"\${prefix}/bin/bats" <<'INNER'
#!/usr/bin/env bash
printf 'Bats 1.2.3\n'
INNER
cp "\${prefix}/bin/bats" "\${prefix}/libexec/bats-core/bats"
printf 'formatter\n' >"\${prefix}/lib/bats-core/bats-format-cat"
printf 'manual\n' >"\${prefix}/share/man/man1/bats.1"
printf 'test file format manual\n' >"\${prefix}/share/man/man7/bats.7"
chmod +x "\${prefix}/bin/bats" "\${prefix}/libexec/bats-core/bats"
EOF
	if [ "${mode}" = unexpected-man7 ]; then
		printf '%s\n' 'printf '\''unexpected manual\n'\'' >"${prefix}/share/man/man7/unexpected.7"' >>"${root}/install.sh"
	fi
	chmod +x "${root}/install.sh"
	mkdir -p \
		"${root}/test/fixtures/parallel/setup_file" \
		"${root}/test/fixtures/parallel/suite" \
		"${root}/test/fixtures/suite/recursive" \
		"${root}/test/fixtures/suite/recursive_with_symlinks" \
		"${root}/test/fixtures/suite_setup_teardown/pick_up_toplevel/folder1" \
		"${root}/test/fixtures/suite_setup_teardown/pick_up_toplevel/folder2"
	touch \
		"${root}/test/fixtures/parallel/setup_file/setup_file.bats" \
		"${root}/test/fixtures/parallel/suite/parallel1.bats" \
		"${root}/test/fixtures/suite/recursive/test.bats" \
		"${root}/test/fixtures/suite_setup_teardown/pick_up_toplevel/setup_suite.bash"
	mkdir -p "${root}/test/fixtures/suite/recursive/subsuite"
	ln -s ./setup_file.bats "${root}/test/fixtures/parallel/setup_file/setup_file1.bats"
	ln -s ./setup_file.bats "${root}/test/fixtures/parallel/setup_file/setup_file2.bats"
	ln -s ./setup_file.bats "${root}/test/fixtures/parallel/setup_file/setup_file3.bats"
	ln -s parallel1.bats "${root}/test/fixtures/parallel/suite/parallel2.bats"
	ln -s parallel1.bats "${root}/test/fixtures/parallel/suite/parallel3.bats"
	ln -s parallel1.bats "${root}/test/fixtures/parallel/suite/parallel4.bats"
	ln -s ../recursive/subsuite/ "${root}/test/fixtures/suite/recursive_with_symlinks/subsuite"
	ln -s ../recursive/test.bats "${root}/test/fixtures/suite/recursive_with_symlinks/test.bats"
	ln -s ../setup_suite.bash "${root}/test/fixtures/suite_setup_teardown/pick_up_toplevel/folder1/setup_suite.bash"
	ln -s ../setup_suite.bash "${root}/test/fixtures/suite_setup_teardown/pick_up_toplevel/folder2/setup_suite.bash"
	[ "${mode}" != extra-root ] || printf 'unexpected\n' >"${TEST_ROOT}/unexpected"
	tar -czf "${ARCHIVE}" -C "${TEST_ROOT}" "bats-core-${version}" $([ "${mode}" = extra-root ] && printf unexpected)
}

write_binary_archive() {
	local name="$1" version="$2" mode="${3:-normal}"
	local root="${TEST_ROOT}/archive-root"
	rm -rf "${root}"
	mkdir -p "${root}"
	cat >"${root}/${name}" <<EOF
#!/usr/bin/env bash
printf '${name} version ${version}\n'
EOF
	chmod +x "${root}/${name}"
	if [ "${name}" = engram ]; then
		printf 'changelog\n' >"${root}/CHANGELOG.md"
		printf 'license\n' >"${root}/LICENSE"
		printf 'readme\n' >"${root}/README.md"
	fi
	case "${mode}" in
	duplicate) cp "${root}/${name}" "${root}/extra" ;;
	symlink) rm "${root}/${name}"; ln -s target "${root}/${name}" ;;
	traversal) tar -czf "${ARCHIVE}" --transform='s|^|../|' -C "${root}" "${name}"; return ;;
	execution-fail) printf '#!/usr/bin/env bash\nexit 42\n' >"${root}/${name}" ;;
	signal) printf '#!/usr/bin/env bash\nkill -TERM "$PPID"\nsleep 1\n' >"${root}/${name}" ;;
	esac
	if [ "${mode}" = duplicate ]; then
		tar -czf "${ARCHIVE}" -C "${root}" $([ "${name}" = engram ] && printf 'CHANGELOG.md LICENSE README.md ') "${name}" extra
	else
		tar -czf "${ARCHIVE}" -C "${root}" $([ "${name}" = engram ] && printf 'CHANGELOG.md LICENSE README.md ') "${name}"
	fi
}

write_adversarial_archive() {
	local tool="$1" mode="$2" rooted="${3:-no}"
	python3 - "${ARCHIVE}" "${tool}" "${mode}" "${rooted}" <<'PY'
import io, sys, tarfile

archive, tool, mode, rooted = sys.argv[1:]
root = "bats-core-1.2.3/" if rooted == "yes" else ""
canonical = root + ("install.sh" if rooted == "yes" else tool)
with tarfile.open(archive, "w:gz") as bundle:
    def regular(name, body=b"#!/usr/bin/env bash\nexit 0\n"):
        info = tarfile.TarInfo(name)
        info.mode = 0o755
        info.size = len(body)
        bundle.addfile(info, io.BytesIO(body))
    if mode == "traversal": regular("../" + canonical)
    elif mode == "symlink":
        info = tarfile.TarInfo(canonical); info.type = tarfile.SYMTYPE; info.linkname = "target"; bundle.addfile(info)
    elif mode == "hardlink":
        info = tarfile.TarInfo(canonical); info.type = tarfile.LNKTYPE; info.linkname = "target"; bundle.addfile(info)
    elif mode == "special":
        info = tarfile.TarInfo(canonical); info.type = tarfile.FIFOTYPE; bundle.addfile(info)
    elif mode == "duplicate": regular(canonical); regular(canonical)
    elif mode == "extra-root": regular(canonical); regular("unexpected/file")
PY
}

snapshot_tree() {
	local root="$1"
	python3 - "${root}" <<'PY'
import hashlib, pathlib, stat, sys

root = pathlib.Path(sys.argv[1])
for path in sorted(root.rglob("*")):
    mode = path.lstat().st_mode
    kind = "f" if stat.S_ISREG(mode) else "d" if stat.S_ISDIR(mode) else "l" if stat.S_ISLNK(mode) else "s"
    digest = hashlib.sha256(path.read_bytes()).hexdigest() if stat.S_ISREG(mode) else "-"
    print(f"{path.relative_to(root).as_posix()}|{kind}|{stat.S_IMODE(mode):o}|{digest}")
PY
}

seed_existing_bats() {
	local version_output="$1"
	mkdir -p \
		"${INSTALL_DIR}/bin" "${INSTALL_DIR}/lib/bats-core" "${INSTALL_DIR}/libexec/bats-core" \
		"${INSTALL_DIR}/share/man/man1" "${INSTALL_DIR}/share/man/man7" \
		"${INSTALL_DIR}/lib/unrelated" "${INSTALL_DIR}/libexec/unrelated"
	cat >"${INSTALL_DIR}/bin/bats" <<EOF
#!/usr/bin/env bash
printf '%s\n' '${version_output}'
EOF
	printf 'old lib\n' >"${INSTALL_DIR}/lib/bats-core/old"
	printf 'old exec\n' >"${INSTALL_DIR}/libexec/bats-core/bats"
	printf 'old man1\n' >"${INSTALL_DIR}/share/man/man1/bats.1"
	printf 'old man7\n' >"${INSTALL_DIR}/share/man/man7/bats.7"
	printf 'unrelated bin\n' >"${INSTALL_DIR}/bin/unrelated"
	printf 'unrelated lib\n' >"${INSTALL_DIR}/lib/unrelated/file"
	printf 'unrelated libexec\n' >"${INSTALL_DIR}/libexec/unrelated/file"
	printf 'unrelated man1\n' >"${INSTALL_DIR}/share/man/man1/unrelated.1"
	printf 'unrelated man7\n' >"${INSTALL_DIR}/share/man/man7/unrelated.7"
	chmod 0751 "${INSTALL_DIR}/bin/bats"
}

run_bats_installer() {
	local digest="$1"
	printf 'LOCK_BATS_VERSION="1.2.3"\nLOCK_BATS_SHA256="%s"\n' "${digest}" >"${POLICY}"
	run env -u BATS_VERSION PATH="${INSTALL_DIR}/bin:${BIN_DIR}:/usr/bin:/bin" TMPDIR="${TEST_ROOT}/tmp" ARCHIVE_FIXTURE="${ARCHIVE}" BATS_INSTALL_DIR="${INSTALL_DIR}" DEVCONTAINER_PHASE=build DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY}" bash "${REPO_ROOT}/.devcontainer/install/available/1000-test-bats.sh"
}

run_direct_installer() {
	local tool="$1" machine="$2" version="$3" digest_mode="${4:-valid}" digest
	digest="$(sha256sum "${ARCHIVE}" | awk '{print $1}')"
	[ "${digest_mode}" != mismatch ] || digest="$(printf '0%.0s' {1..64})"
	if [ "${tool}" = opencode ]; then
		printf 'LOCK_OPENCODE_VERSION="%s"\nLOCK_OPENCODE_SHA256_AMD64="%s"\nLOCK_OPENCODE_SHA256_ARM64="%s"\n' "${version}" "${digest}" "${digest}" >"${POLICY}"
		run env PATH="${BIN_DIR}:/usr/bin:/bin" TMPDIR="${TEST_ROOT}/tmp" FIXTURE_MACHINE="${machine}" ARCHIVE_FIXTURE="${ARCHIVE}" DEVCONTAINER_PHASE=build DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY}" OPENCODE_INSTALL_DIR="${INSTALL_DIR}" bash "${REPO_ROOT}/.devcontainer/install/available/3000-ai-opencode.sh"
	else
		printf 'LOCK_ENGRAM_VERSION="%s"\nLOCK_ENGRAM_SHA256_AMD64="%s"\nLOCK_ENGRAM_SHA256_ARM64="%s"\n' "${version}" "${digest}" "${digest}" >"${POLICY}"
		run env PATH="${BIN_DIR}:/usr/bin:/bin" TMPDIR="${TEST_ROOT}/tmp" FIXTURE_MACHINE="${machine}" ARCHIVE_FIXTURE="${ARCHIVE}" DEVCONTAINER_PHASE=build DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY}" ENGRAM_INSTALL_DIR="${INSTALL_DIR}" bash "${REPO_ROOT}/.devcontainer/install/available/3010-ai-engram.sh"
	fi
}

@test "OpenCode build installs provider-shaped amd64 and arm64 archives" {
	for machine in x86_64 aarch64; do
		rm -f "${INSTALL_DIR}/opencode"
		write_binary_archive opencode 1.2.3
		run_direct_installer opencode "${machine}" 1.2.3
		[ "${status}" -eq 0 ]
		[ "$(${INSTALL_DIR}/opencode --version)" = "opencode version 1.2.3" ]
		assert_installer_temp_is_empty
	done
}

@test "Engram build installs provider-shaped amd64 and arm64 archives" {
	for machine in x86_64 aarch64; do
		rm -f "${INSTALL_DIR}/engram"
		write_binary_archive engram 1.2.3
		run_direct_installer engram "${machine}" 1.2.3
		[ "${status}" -eq 0 ]
		[ "$(${INSTALL_DIR}/engram version)" = "engram version 1.2.3" ]
		assert_installer_temp_is_empty
	done
}

@test "direct installers reject malformed layouts and preserve installed bytes and mode" {
	for tool in opencode engram; do
		printf 'preserved\n' >"${INSTALL_DIR}/${tool}"
		chmod 0711 "${INSTALL_DIR}/${tool}"
		write_binary_archive "${tool}" 1.2.3 duplicate
		run_direct_installer "${tool}" x86_64 1.2.3
		[ "${status}" -ne 0 ]
		[ "$(cat "${INSTALL_DIR}/${tool}")" = preserved ]
		[ "$(stat -c %a "${INSTALL_DIR}/${tool}")" = 711 ]
		assert_installer_temp_is_empty
	done
}

@test "direct installers reject checksum and embedded-version mismatches atomically" {
	for tool in opencode engram; do
		printf 'preserved\n' >"${INSTALL_DIR}/${tool}"
		chmod 0701 "${INSTALL_DIR}/${tool}"
		write_binary_archive "${tool}" 9.9.9
		run_direct_installer "${tool}" aarch64 1.2.3
		[ "${status}" -ne 0 ]
		[ "$(cat "${INSTALL_DIR}/${tool}")" = preserved ]
		[ "$(stat -c %a "${INSTALL_DIR}/${tool}")" = 701 ]
		assert_installer_temp_is_empty
	done
}

@test "direct installers clean temporary files after checksum failures" {
	for tool in opencode engram; do
		printf 'preserved\n' >"${INSTALL_DIR}/${tool}"
		chmod 0741 "${INSTALL_DIR}/${tool}"
		write_binary_archive "${tool}" 1.2.3
		run_direct_installer "${tool}" x86_64 1.2.3 mismatch
		[ "${status}" -ne 0 ]
		[ "$(cat "${INSTALL_DIR}/${tool}")" = preserved ]
		[ "$(stat -c %a "${INSTALL_DIR}/${tool}")" = 741 ]
		assert_installer_temp_is_empty
	done
}

@test "staged binary execution failures clean destination-side temporary files" {
	for tool in opencode engram; do
		printf 'preserved\n' >"${INSTALL_DIR}/${tool}"
		chmod 0740 "${INSTALL_DIR}/${tool}"
		write_binary_archive "${tool}" 1.2.3 execution-fail
		run_direct_installer "${tool}" x86_64 1.2.3
		[ "${status}" -ne 0 ]
		[ "$(cat "${INSTALL_DIR}/${tool}")" = preserved ]
		[ "$(stat -c %a "${INSTALL_DIR}/${tool}")" = 740 ]
		[ ! -e "${INSTALL_DIR}/${tool}.new" ]
		assert_installer_temp_is_empty
	done
}

@test "installer signal traps clean staged binaries and preserve destinations" {
	for tool in opencode engram; do
		printf 'preserved\n' >"${INSTALL_DIR}/${tool}"
		chmod 0730 "${INSTALL_DIR}/${tool}"
		write_binary_archive "${tool}" 1.2.3 signal
		run_direct_installer "${tool}" x86_64 1.2.3
		[ "${status}" -ne 0 ]
		[ "$(cat "${INSTALL_DIR}/${tool}")" = preserved ]
		[ "$(stat -c %a "${INSTALL_DIR}/${tool}")" = 730 ]
		[ ! -e "${INSTALL_DIR}/${tool}.new" ]
		assert_installer_temp_is_empty
	done
}

@test "direct installers reject every unsafe tar entry before publication" {
	local tool mode before
	for tool in opencode engram; do
		printf 'preserved\n' >"${INSTALL_DIR}/${tool}"
		chmod 0751 "${INSTALL_DIR}/${tool}"
		for mode in traversal symlink hardlink special duplicate extra-root; do
			write_adversarial_archive "${tool}" "${mode}"
			before="$(snapshot_tree "${INSTALL_DIR}")"
			run_direct_installer "${tool}" x86_64 1.2.3
			[ "${status}" -ne 0 ]
			[ "$(snapshot_tree "${INSTALL_DIR}")" = "${before}" ]
			[ ! -e "${INSTALL_DIR}/${tool}.new" ]
			assert_installer_temp_is_empty
		done
	done
}

@test "BATS rejects every unsafe tar entry before staging or publication" {
	local mode digest before
	mkdir -p "${INSTALL_DIR}/bin" "${INSTALL_DIR}/lib/bats-core" "${INSTALL_DIR}/libexec/bats-core" "${INSTALL_DIR}/share/man/man1"
	printf 'old bats\n' >"${INSTALL_DIR}/bin/bats"
	printf 'old lib\n' >"${INSTALL_DIR}/lib/bats-core/old"
	printf 'old exec\n' >"${INSTALL_DIR}/libexec/bats-core/bats"
	printf 'old man\n' >"${INSTALL_DIR}/share/man/man1/bats.1"
	chmod 0751 "${INSTALL_DIR}/bin/bats"
	for mode in traversal symlink hardlink special duplicate extra-root; do
		write_adversarial_archive bats "${mode}" yes
		digest="$(sha256sum "${ARCHIVE}" | awk '{print $1}')"
		printf 'LOCK_BATS_VERSION="1.2.3"\nLOCK_BATS_SHA256="%s"\n' "${digest}" >"${POLICY}"
		before="$(snapshot_tree "${INSTALL_DIR}")"
		run env -u BATS_VERSION PATH="${BIN_DIR}:/usr/bin:/bin" TMPDIR="${TEST_ROOT}/tmp" ARCHIVE_FIXTURE="${ARCHIVE}" BATS_INSTALL_DIR="${INSTALL_DIR}" DEVCONTAINER_PHASE=build DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY}" bash "${REPO_ROOT}/.devcontainer/install/available/1000-test-bats.sh"
		[ "${status}" -ne 0 ]
		[ "$(snapshot_tree "${INSTALL_DIR}")" = "${before}" ]
		assert_installer_temp_is_empty
	done
}

@test "BATS matching normalized version is a complete no-op" {
	local before
	seed_existing_bats 'Bats v1.2.3 release'
	before="$(snapshot_tree "${INSTALL_DIR}")"
	printf 'LOCK_BATS_VERSION="1.2.3"\nLOCK_BATS_SHA256="%064d"\n' 0 >"${POLICY}"

	run env -u BATS_VERSION PATH="${INSTALL_DIR}/bin:${BIN_DIR}:/usr/bin:/bin" TMPDIR="${TEST_ROOT}/tmp" ARCHIVE_FIXTURE="${ARCHIVE}" BATS_INSTALL_DIR="${INSTALL_DIR}" DEVCONTAINER_PHASE=build DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY}" bash "${REPO_ROOT}/.devcontainer/install/available/1000-test-bats.sh"

	[ "${status}" -eq 0 ]
	[ "$(snapshot_tree "${INSTALL_DIR}")" = "${before}" ]
	[ ! -e "${ARCHIVE}" ]
	assert_installer_temp_is_empty
}

@test "BATS stale installation is transactionally replaced" {
	seed_existing_bats 'Bats 1.1.0'
	write_bats_archive 1.2.3
	run_bats_installer "$(sha256sum "${ARCHIVE}" | awk '{print $1}')"

	[ "${status}" -eq 0 ]
	[ "$(${INSTALL_DIR}/bin/bats --version)" = 'Bats 1.2.3' ]
	[ "$(<"${INSTALL_DIR}/lib/bats-core/bats-format-cat")" = formatter ]
	[ "$(<"${INSTALL_DIR}/share/man/man7/bats.7")" = 'test file format manual' ]
	[ "$(<"${INSTALL_DIR}/bin/unrelated")" = 'unrelated bin' ]
	[ "$(<"${INSTALL_DIR}/lib/unrelated/file")" = 'unrelated lib' ]
	[ "$(<"${INSTALL_DIR}/libexec/unrelated/file")" = 'unrelated libexec' ]
	[ "$(<"${INSTALL_DIR}/share/man/man1/unrelated.1")" = 'unrelated man1' ]
	[ "$(<"${INSTALL_DIR}/share/man/man7/unrelated.7")" = 'unrelated man7' ]
	assert_installer_temp_is_empty
}

@test "BATS malformed installed version triggers replacement" {
	seed_existing_bats 'not a BATS version'
	write_bats_archive 1.2.3
	run_bats_installer "$(sha256sum "${ARCHIVE}" | awk '{print $1}')"

	[ "${status}" -eq 0 ]
	[ "$(${INSTALL_DIR}/bin/bats --version)" = 'Bats 1.2.3' ]
	assert_installer_temp_is_empty
}

@test "BATS build executes a verified provider-shaped archive and rejects extra roots" {
	mkdir -p "${INSTALL_DIR}/share/man/man7"
	printf 'unrelated manual\n' >"${INSTALL_DIR}/share/man/man7/unrelated.7"
	write_bats_archive 1.2.3
	digest="$(sha256sum "${ARCHIVE}" | awk '{print $1}')"
	printf 'LOCK_BATS_VERSION="1.2.3"\nLOCK_BATS_SHA256="%s"\n' "${digest}" >"${POLICY}"
	run env -u BATS_VERSION PATH="${INSTALL_DIR}/bin:${BIN_DIR}:/usr/bin:/bin" TMPDIR="${TEST_ROOT}/tmp" ARCHIVE_FIXTURE="${ARCHIVE}" BATS_INSTALL_DIR="${INSTALL_DIR}" DEVCONTAINER_PHASE=build DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY}" bash "${REPO_ROOT}/.devcontainer/install/available/1000-test-bats.sh"
	[ "${status}" -eq 0 ]
	[ "$(${INSTALL_DIR}/bin/bats --version)" = 'Bats 1.2.3' ]
	[ "$(<"${INSTALL_DIR}/share/man/man7/bats.7")" = 'test file format manual' ]
	[ "$(stat -c %a "${INSTALL_DIR}/share/man/man7/bats.7")" = 644 ]
	[ "$(<"${INSTALL_DIR}/share/man/man7/unrelated.7")" = 'unrelated manual' ]
	assert_installer_temp_is_empty

	rm -rf "${INSTALL_DIR:?}"/*
	write_bats_archive 1.2.3 extra-root
	digest="$(sha256sum "${ARCHIVE}" | awk '{print $1}')"
	sed -i "s/^LOCK_BATS_SHA256=.*/LOCK_BATS_SHA256=\"${digest}\"/" "${POLICY}"
	run env -u BATS_VERSION PATH="${INSTALL_DIR}/bin:${BIN_DIR}:/usr/bin:/bin" TMPDIR="${TEST_ROOT}/tmp" ARCHIVE_FIXTURE="${ARCHIVE}" BATS_INSTALL_DIR="${INSTALL_DIR}" DEVCONTAINER_PHASE=build DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY}" bash "${REPO_ROOT}/.devcontainer/install/available/1000-test-bats.sh"
	[ "${status}" -ne 0 ]
	[ ! -e "${INSTALL_DIR}/bin/bats" ]
	assert_installer_temp_is_empty

	digest="$(printf '0%.0s' {1..64})"
	sed -i "s/^LOCK_BATS_SHA256=.*/LOCK_BATS_SHA256=\"${digest}\"/" "${POLICY}"
	run env -u BATS_VERSION PATH="${INSTALL_DIR}/bin:${BIN_DIR}:/usr/bin:/bin" TMPDIR="${TEST_ROOT}/tmp" ARCHIVE_FIXTURE="${ARCHIVE}" BATS_INSTALL_DIR="${INSTALL_DIR}" DEVCONTAINER_PHASE=build DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY}" bash "${REPO_ROOT}/.devcontainer/install/available/1000-test-bats.sh"
	[ "${status}" -ne 0 ]
	assert_installer_temp_is_empty
}

@test "BATS rejects unexpected man7 output before publication" {
	local digest before
	mkdir -p "${INSTALL_DIR}/share/man/man7"
	printf 'old bats manual\n' >"${INSTALL_DIR}/share/man/man7/bats.7"
	printf 'unrelated manual\n' >"${INSTALL_DIR}/share/man/man7/unrelated.7"
	before="$(snapshot_tree "${INSTALL_DIR}")"
	write_bats_archive 1.2.3 unexpected-man7
	digest="$(sha256sum "${ARCHIVE}" | awk '{print $1}')"
	printf 'LOCK_BATS_VERSION="1.2.3"\nLOCK_BATS_SHA256="%s"\n' "${digest}" >"${POLICY}"

	run env -u BATS_VERSION PATH="${BIN_DIR}:/usr/bin:/bin" TMPDIR="${TEST_ROOT}/tmp" ARCHIVE_FIXTURE="${ARCHIVE}" BATS_INSTALL_DIR="${INSTALL_DIR}" DEVCONTAINER_PHASE=build DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY}" bash "${REPO_ROOT}/.devcontainer/install/available/1000-test-bats.sh"

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"unexpected staged BATS output: share/man/man7/unexpected.7"* ]]
	[ "$(snapshot_tree "${INSTALL_DIR}")" = "${before}" ]
	assert_installer_temp_is_empty
}

@test "BATS man7 publication failure restores every previous destination" {
	local digest before after
	seed_existing_bats 'Bats 1.1.0'
	before="$(snapshot_tree "${INSTALL_DIR}")"
	write_bats_archive 1.2.3
	digest="$(sha256sum "${ARCHIVE}" | awk '{print $1}')"
	printf 'LOCK_BATS_VERSION="1.2.3"\nLOCK_BATS_SHA256="%s"\n' "${digest}" >"${POLICY}"
	cat >"${BIN_DIR}/mv" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == */stage/share/man/man7/bats.7 ]]; then exit 73; fi
exec /bin/mv "$@"
EOF
	chmod +x "${BIN_DIR}/mv"
	run env -u BATS_VERSION PATH="${INSTALL_DIR}/bin:${BIN_DIR}:/usr/bin:/bin" TMPDIR="${TEST_ROOT}/tmp" ARCHIVE_FIXTURE="${ARCHIVE}" BATS_INSTALL_DIR="${INSTALL_DIR}" DEVCONTAINER_PHASE=build DEVCONTAINER_TOOL_VERSIONS_FILE="${POLICY}" bash "${REPO_ROOT}/.devcontainer/install/available/1000-test-bats.sh"
	[ "${status}" -ne 0 ]
	after="$(snapshot_tree "${INSTALL_DIR}")"
	if [ "${after}" != "${before}" ]; then
		diff <(printf '%s\n' "${before}") <(printf '%s\n' "${after}") >&3
		false
	fi
	assert_installer_temp_is_empty
}
