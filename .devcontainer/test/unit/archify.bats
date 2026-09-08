#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	BIN_DIR="${TEST_ROOT}/bin"
	INSTALL_ROOT="${TEST_ROOT}/opt/archify"
	ARCHIFY_BIN="${TEST_ROOT}/usr-local-bin/archify"
	ARCHIVE_FIXTURE="${TEST_ROOT}/archify.zip"
	CALLS="${TEST_ROOT}/calls"
	CHOWN_CALLS="${TEST_ROOT}/chown-calls"
	VERSION=2.16.0
	mkdir -p "${BIN_DIR}" "$(dirname "${INSTALL_ROOT}")" "$(dirname "${ARCHIFY_BIN}")"
	: >"${CALLS}"
	: >"${CHOWN_CALLS}"
	export REPO_ROOT TEST_ROOT BIN_DIR INSTALL_ROOT ARCHIFY_BIN ARCHIVE_FIXTURE CALLS CHOWN_CALLS VERSION
	write_archive "${VERSION}" normal
	SHA256="$(sha256sum "${ARCHIVE_FIXTURE}" | awk '{print $1}')"
	export SHA256 PATH="${BIN_DIR}:${PATH}"
	write_stubs
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

write_archive() {
	local version="$1"
	local mode="$2"
	python3 - "${ARCHIVE_FIXTURE}" "${version}" "${mode}" <<'PY'
import json, stat, sys, zipfile
archive, version, mode = sys.argv[1:]
files = {
    "archify/SKILL.md": "---\nname: archify\ndescription: Test fixture.\n---\n",
    "archify/package.json": json.dumps({"name": "archify", "version": version, "bin": {"archify": "./bin/archify.mjs"}, "engines": {"node": ">=18"}}),
    "archify/skill-release.json": json.dumps({"schemaVersion": 1, "skillId": "archify", "channel": "stable", "version": version}),
    "archify/bin/archify.mjs": "#!/usr/bin/env node\nif (process.env.ARCHIFY_TEST_FAIL_FINAL === '1' && process.argv[1].startsWith(process.env.ARCHIFY_INSTALL_ROOT)) process.exit(1);\nif (process.argv[2] === 'doctor') process.exit(process.env.ARCHIFY_UPDATE_CHECK_DISABLED === '1' ? 0 : 1); console.log('help');\n",
    "archify/complete.txt": "complete package\n",
}
if mode == "missing": files.pop("archify/SKILL.md")
if mode == "multiple": files["other/file"] = "bad"
if mode == "traversal": files["archify/../escape"] = "bad"
if mode == "absolute": files["/absolute"] = "bad"
if mode == "drive": files["C:/escape"] = "bad"
if mode == "backslash": files["archify\\escape"] = "bad"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
    for name, body in files.items():
        info = zipfile.ZipInfo(name)
        info.external_attr = (stat.S_IFREG | (0o755 if name.endswith(".mjs") else 0o644)) << 16
        if mode == "symlink" and name == "archify/complete.txt":
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            body = "target"
        if mode == "fifo" and name == "archify/complete.txt":
            info.external_attr = (stat.S_IFIFO | 0o644) << 16
        z.writestr(info, body)
PY
}

write_stubs() {
	cat >"${BIN_DIR}/curl" <<'EOF'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >>"${CALLS}"
output=""
while [ "$#" -gt 0 ]; do
  case "$1" in -o) output="$2"; shift 2 ;; *) shift ;; esac
done
cp "${ARCHIVE_FIXTURE}" "${output}"
EOF
	cat >"${BIN_DIR}/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
	cat >"${BIN_DIR}/chown" <<'EOF'
#!/usr/bin/env bash
printf 'chown %s\n' "$*" >>"${CHOWN_CALLS}"
exit 0
EOF
	cat >"${BIN_DIR}/mv" <<'EOF'
#!/usr/bin/env bash
if [ ! -e "${TEST_ROOT}/mv-failed" ]; then
  case "${ARCHIFY_TEST_MV_FAILURE:-}" in
    root-backup) [[ "$1" = "${INSTALL_ROOT}" && "$2" == "$(dirname "${INSTALL_ROOT}")/.archify.backup."* ]] ;;
    cli-backup) [[ "$1" = "${ARCHIFY_BIN}" && "$2" == "$(dirname "${ARCHIFY_BIN}")/.archify.backup."* ]] ;;
    root-activation) [[ "$1" == "$(dirname "${INSTALL_ROOT}")/.archify.new."* && "$2" = "${INSTALL_ROOT}" ]] ;;
    cli-activation) [[ "$1" == "$(dirname "${ARCHIFY_BIN}")/.archify.new."* && "$2" = "${ARCHIFY_BIN}" ]] ;;
    *) false ;;
  esac && { : >"${TEST_ROOT}/mv-failed"; exit 73; }
fi
exec /bin/mv "$@"
EOF
	chmod +x "${BIN_DIR}/curl" "${BIN_DIR}/sudo" "${BIN_DIR}/chown" "${BIN_DIR}/mv"
}

run_installer() {
	run env ARCHIFY_VERSION="${ARCHIFY_VERSION_OVERRIDE:-${VERSION}}" \
		ARCHIFY_SHA256="${ARCHIFY_SHA256_OVERRIDE-${SHA256}}" \
		ARCHIFY_INSTALL_ROOT="${INSTALL_ROOT}" ARCHIFY_BIN="${ARCHIFY_BIN}" \
		bash "${REPO_ROOT}/.devcontainer/install/available/40-node-archify.sh"
}

write_stale_installation() {
	mkdir -p "${INSTALL_ROOT}"
	printf 'stale\n' >"${INSTALL_ROOT}/old"
	printf '#!/usr/bin/env bash\nprintf old\n' >"${ARCHIFY_BIN}"
	chmod +x "${ARCHIFY_BIN}"
}

assert_stale_installation_survives() {
	[ -f "${INSTALL_ROOT}/old" ]
	run "${ARCHIFY_BIN}"
	[ "${status}" -eq 0 ]
	[ "${output}" = old ]
}

@test "Archify policy resolves centrally with environment precedence" {
	policy="${TEST_ROOT}/policy"
	printf '%s\n' 'TOOL_ARCHIFY_VERSION="1.2.3"' "TOOL_ARCHIFY_SHA256=\"$(printf 'a%.0s' {1..64})\"" >"${policy}"
	run env DEVCONTAINER_TOOL_VERSIONS_FILE="${policy}" ARCHIFY_VERSION=9.8.7 \
		ARCHIFY_SHA256="$(printf 'b%.0s' {1..64})" \
		bash "${REPO_ROOT}/.devcontainer/install/available/40-node-archify.sh" --print-version-policy
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "ARCHIFY_VERSION=9.8.7" ]
	[ "${lines[1]}" = "ARCHIFY_SHA256=$(printf 'b%.0s' {1..64})" ]
}

@test "Archify rejects malformed policy before network" {
	for value in v2.16.0 latest 2.16.0-rc.1; do
		ARCHIFY_VERSION_OVERRIDE="${value}" run_installer
		[ "$status" -ne 0 ]
	done
	ARCHIFY_SHA256_OVERRIDE=bad run_installer
	[ "$status" -ne 0 ]
	[ ! -s "${CALLS}" ]
}

@test "Archify checks Node and unzip before network" {
	cat >"${BIN_DIR}/node" <<'EOF'
#!/usr/bin/env bash
printf '17\n'
EOF
	chmod +x "${BIN_DIR}/node"
	run_installer
	[ "$status" -ne 0 ]
	[[ "$output" == *"Node.js >=18"* ]]
	[ ! -s "${CALLS}" ]
}

@test "Archify rejects digest mismatch without replacing stale state" {
	mkdir -p "${INSTALL_ROOT}"
	printf 'stale\n' >"${INSTALL_ROOT}/old"
	ARCHIFY_SHA256_OVERRIDE="$(printf '0%.0s' {1..64})" run_installer
	[ "$status" -ne 0 ]
	[ -f "${INSTALL_ROOT}/old" ]
}

@test "Archify rejects unsafe and malformed layouts" {
	for mode in missing multiple traversal absolute drive backslash symlink fifo; do
		write_archive "${VERSION}" "${mode}"
		SHA256="$(sha256sum "${ARCHIVE_FIXTURE}" | awk '{print $1}')"
		run_installer
		[ "$status" -ne 0 ]
	done
}

@test "Archify rejects mismatched embedded versions" {
	write_archive 9.9.9 normal
	SHA256="$(sha256sum "${ARCHIVE_FIXTURE}" | awk '{print $1}')"
	run_installer
	[ "$status" -ne 0 ]
	[[ "$output" == *"embedded version"* ]]
}

@test "Archify installs the complete package and replaces stale state" {
	mkdir -p "${INSTALL_ROOT}"
	printf 'stale\n' >"${INSTALL_ROOT}/old"
	run_installer
	[ "$status" -eq 0 ]
	[ ! -e "${INSTALL_ROOT}/old" ]
	[ -f "${INSTALL_ROOT}/complete.txt" ]
	[ "$(<"${INSTALL_ROOT}/.archify-version")" = "${VERSION}" ]
	[ "$(<"${INSTALL_ROOT}/.archify-sha256")" = "${SHA256}" ]
	[ -x "${ARCHIFY_BIN}" ]
	[ -z "$(find "${INSTALL_ROOT}" -type d ! -perm 0755 -print)" ]
	[ -z "$(find "${INSTALL_ROOT}" -type f ! -path "${INSTALL_ROOT}/bin/archify.mjs" ! -perm 0644 -print)" ]
	[ "$(stat -c '%a' "${INSTALL_ROOT}/complete.txt")" = 644 ]
	[ "$(stat -c '%a' "${INSTALL_ROOT}/bin/archify.mjs")" = 755 ]
	[ "$(stat -c '%a' "${ARCHIFY_BIN}")" = 755 ]
	grep -Eq "^chown -R root:root $(dirname "${INSTALL_ROOT}")/\.archify\.new\.[0-9]+$" "${CHOWN_CALLS}"
	cat >"${TEST_ROOT}/expected-wrapper" <<EOF
#!/usr/bin/env bash
export ARCHIFY_UPDATE_CHECK_DISABLED=1
exec node "${INSTALL_ROOT}/bin/archify.mjs" "\$@"
EOF
	cmp -s "${TEST_ROOT}/expected-wrapper" "${ARCHIFY_BIN}"
}

@test "Archify preserves both previous targets across activation failures" {
	local failure
	for failure in root-backup cli-backup root-activation cli-activation final-verification; do
		write_stale_installation
		rm -f "${TEST_ROOT}/mv-failed"
		unset ARCHIFY_TEST_MV_FAILURE ARCHIFY_TEST_FAIL_FINAL
		if [ "${failure}" = final-verification ]; then
			export ARCHIFY_TEST_FAIL_FINAL=1
		else
			export ARCHIFY_TEST_MV_FAILURE="${failure}"
		fi

		run_installer

		[ "$status" -ne 0 ]
		assert_stale_installation_survives
	done
}

@test "healthy exact Archify installation performs no download" {
	run_installer
	[ "$status" -eq 0 ]
	: >"${CALLS}"
	run_installer
	[ "$status" -eq 0 ]
	[[ "$output" == *"already installed and healthy"* ]]
	[ ! -s "${CALLS}" ]
}
