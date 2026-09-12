#!/usr/bin/env bats
# Retained helper coverage, independent of the removed Pi lifecycle scenario.

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	CAPTURE="${REPO_ROOT}/.devcontainer/test/lifecycle/capture-ssh-hostkey-fingerprints.sh"
	SNAPSHOT="${REPO_ROOT}/.devcontainer/test/lifecycle/tracked-path-snapshot.py"
	CREATE_CANDIDATE="${REPO_ROOT}/.devcontainer/test/lifecycle/create-candidate.sh"
	RESTORE_MODES="${REPO_ROOT}/.devcontainer/lifecycle/restore-tracked-modes.sh"
	TEST_ROOT="$(mktemp -d)"
	BIN_DIR="${TEST_ROOT}/bin"
	mkdir "${BIN_DIR}"
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

setup_snapshot_fixture() {
	SNAPSHOT_ROOT="${TEST_ROOT}/snapshot-repo"
	mkdir "${SNAPSHOT_ROOT}"
	git -C "${SNAPSHOT_ROOT}" init -q
	printf '.env\n.devcontainer/.env\n' >"${SNAPSHOT_ROOT}/.gitignore"
	printf 'tracked\n' >"${SNAPSHOT_ROOT}/tracked.txt"
	printf 'target-one\n' >"${SNAPSHOT_ROOT}/target-one"
	printf 'target-two\n' >"${SNAPSHOT_ROOT}/target-two"
	ln -s target-one "${SNAPSHOT_ROOT}/tracked-link"
	git -C "${SNAPSHOT_ROOT}" add .gitignore tracked.txt target-one target-two tracked-link
	git -C "${SNAPSHOT_ROOT}" ls-files --stage -z >"${TEST_ROOT}/manifest"
	python3 "${SNAPSHOT}" capture "${TEST_ROOT}/manifest" "${SNAPSHOT_ROOT}" "${TEST_ROOT}/before"
}

compare_snapshot_fixture() {
	python3 "${SNAPSHOT}" capture "${TEST_ROOT}/manifest" "${SNAPSHOT_ROOT}" "${TEST_ROOT}/after"
	run python3 "${SNAPSHOT}" compare "${TEST_ROOT}/before" "${TEST_ROOT}/after"
}

@test "candidate overlay excludes source worktree Git files without real Git operations" {
	local source_repo="${TEST_ROOT}/source" candidate="${TEST_ROOT}/candidate"
	mkdir "${source_repo}"
	printf 'gitdir: synthetic-private-metadata\n' >"${source_repo}/.git"
	printf 'public source\n' >"${source_repo}/public"
	cat >"${BIN_DIR}/git" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = clone ]; then
	mkdir -p "${!#}/.git"
fi
EOF
	chmod +x "${BIN_DIR}/git"
	run env PATH="${BIN_DIR}:/usr/bin:/bin" bash "${CREATE_CANDIDATE}" "${source_repo}" "${candidate}"
	[ "${status}" -eq 0 ]
	[ -d "${candidate}/.git" ]
	cmp "${source_repo}/public" "${candidate}/public"
	[ "$(<"${source_repo}/.git")" = 'gitdir: synthetic-private-metadata' ]
}

@test "candidate has independent Git metadata, no remotes, and an exact safe dirty overlay" {
	local source_repo="${TEST_ROOT}/source" candidate="${TEST_ROOT}/candidate"
	mkdir "${source_repo}"
	git -C "${source_repo}" init -q
	git -C "${source_repo}" config user.name Test
	git -C "${source_repo}" config user.email test@example.test
	printf 'base\n' >"${source_repo}/tracked"
	printf 'remove\n' >"${source_repo}/deleted"
	git -C "${source_repo}" add .
	git -C "${source_repo}" commit -qm baseline
	git -C "${source_repo}" remote add unsafe https://example.invalid/private.git
	printf 'dirty bytes\n' >"${source_repo}/tracked"
	chmod 0755 "${source_repo}/tracked"
	rm "${source_repo}/deleted"
	printf 'untracked bytes\n' >"${source_repo}/untracked"
	chmod 0751 "${source_repo}/untracked"
	ln -s tracked "${source_repo}/untracked-link"
	printf 'secret\n' >"${source_repo}/.env.local"
	local object_path primary_before
	object_path="$(git -C "${source_repo}" rev-parse HEAD)"
	object_path="${object_path:0:2}/${object_path:2}"
	primary_before="$(
		git -C "${source_repo}" show-ref
		git -C "${source_repo}" status --porcelain=v1 --untracked-files=all
		git -C "${source_repo}" config --local --list
		sha256sum "${source_repo}/.git/index"
	)"
	run bash "${CREATE_CANDIDATE}" "${source_repo}" "${candidate}"
	[ "${status}" -eq 0 ]
	[ -d "${candidate}/.git" ]
	[ "$(stat -c '%d:%i' "${source_repo}/.git/objects/${object_path}")" != "$(stat -c '%d:%i' "${candidate}/.git/objects/${object_path}")" ]
	[ ! -f "${candidate}/.git/objects/info/alternates" ]
	[ -z "$(git -C "${candidate}" remote)" ]
	cmp "${source_repo}/tracked" "${candidate}/tracked"
	[ "$(stat -c '%a' "${candidate}/tracked")" = 755 ]
	[ ! -e "${candidate}/deleted" ]
	cmp "${source_repo}/untracked" "${candidate}/untracked"
	[ "$(stat -c '%a' "${candidate}/untracked")" = 751 ]
	[ "$(readlink "${candidate}/untracked-link")" = tracked ]
	[ ! -e "${candidate}/.env.local" ]
	[ "$(
		git -C "${source_repo}" show-ref
		git -C "${source_repo}" status --porcelain=v1 --untracked-files=all
		git -C "${source_repo}" config --local --list
		sha256sum "${source_repo}/.git/index"
	)" = "${primary_before}" ]
}

@test "Git-backed candidate restores canonical executable and sourced shell modes" {
	local source_repo="${TEST_ROOT}/source" candidate="${TEST_ROOT}/candidate"
	mkdir "${source_repo}"
	git -C "${source_repo}" init -q
	git -C "${source_repo}" config user.name Test
	git -C "${source_repo}" config user.email test@example.test
	printf '#!/bin/sh\n' >"${source_repo}/executable-tool"
	printf 'helper=true\n' >"${source_repo}/yq-compatibility.sh"
	chmod 0755 "${source_repo}/executable-tool"
	chmod 0644 "${source_repo}/yq-compatibility.sh"
	git -C "${source_repo}" add .
	git -C "${source_repo}" commit -qm baseline
	bash "${CREATE_CANDIDATE}" "${source_repo}" "${candidate}"
	chmod 0644 "${candidate}/executable-tool"
	chmod 0755 "${candidate}/yq-compatibility.sh"
	# shellcheck disable=SC2016 # The fixture shell must expand its own positional parameters.
	run env PATH="${BIN_DIR}:/usr/bin:/bin" bash -c 'printf "#!/bin/sh\nshift\nexec chmod \"\$@\"\n" >"$1/sudo"; chmod +x "$1/sudo"; bash "$2" "$3"' _ "${BIN_DIR}" "${RESTORE_MODES}" "${candidate}"
	[ "${status}" -eq 0 ]
	[ "$(stat -c '%a' "${candidate}/executable-tool")" = 755 ]
	[ "$(stat -c '%a' "${candidate}/yq-compatibility.sh")" = 644 ]
}

@test "tracked snapshot ignores runtime env rewrites" {
	setup_snapshot_fixture
	mkdir "${SNAPSHOT_ROOT}/.devcontainer"
	printf 'APP_NAME=changed\n' >"${SNAPSHOT_ROOT}/.env"
	printf 'APP_PORT=changed\n' >"${SNAPSHOT_ROOT}/.devcontainer/.env"
	compare_snapshot_fixture
	[ "${status}" -eq 0 ]
}

@test "tracked snapshot reports tracked content mutation by path" {
	setup_snapshot_fixture
	printf 'mutated\n' >"${SNAPSHOT_ROOT}/tracked.txt"
	compare_snapshot_fixture
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"changed tracked path: tracked.txt"* ]]
}

@test "tracked snapshot detects tracked executable mode mutation" {
	setup_snapshot_fixture
	chmod +x "${SNAPSHOT_ROOT}/tracked.txt"
	compare_snapshot_fixture
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"changed tracked path: tracked.txt"* ]]
}

@test "tracked snapshot detects tracked symlink target mutation" {
	setup_snapshot_fixture
	ln -sfn target-two "${SNAPSHOT_ROOT}/tracked-link"
	compare_snapshot_fixture
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"changed tracked path: tracked-link"* ]]
}

write_keyscan_stub() {
	cat >"${BIN_DIR}/ssh-keyscan" <<'EOF'
#!/usr/bin/env bash
count_file="${TEST_ROOT}/scan-count"
count=0
[ ! -f "${count_file}" ] || count="$(<"${count_file}")"
count=$((count + 1))
printf '%s\n' "${count}" >"${count_file}"
case "${SCAN_SCENARIO}:${count}" in
reordered:*) printf '%s\n' 'host ssh-ed25519 ed-key' 'host ssh-rsa rsa-key' ;;
transient:1) printf '%s\n' 'host ssh-rsa rsa-key' ;;
transient:*) printf '%s\n' 'host ssh-ed25519 ed-key' 'host ssh-rsa rsa-key' ;;
incomplete:*) printf '%s\n' 'host ssh-ed25519 ed-key' ;;
esac
EOF
	cat >"${BIN_DIR}/ssh-keygen" <<'EOF'
#!/usr/bin/env bash
case "$(awk 'NR == 1 { print $2 }' "${!#}")" in
ssh-rsa) printf '%s\n' '3072 SHA256:rsa fingerprint (RSA)' ;;
ssh-ed25519) printf '%s\n' '256 SHA256:ed25519 fingerprint (ED25519)' ;;
*) exit 1 ;;
esac
EOF
	chmod +x "${BIN_DIR}/ssh-keyscan" "${BIN_DIR}/ssh-keygen"
}

capture_fingerprints() {
	run env PATH="${BIN_DIR}:/usr/bin:/bin" TEST_ROOT="${TEST_ROOT}" SCAN_SCENARIO="$1" \
		SSH_HOSTKEY_SCAN_RETRY_DELAY=0 bash "${CAPTURE}" 127.0.0.1 2222 "${TEST_ROOT}/fingerprints"
}

@test "SSH fingerprint capture normalizes reordered RSA and ED25519 records" {
	write_keyscan_stub
	capture_fingerprints reordered
	[ "${status}" -eq 0 ]
	[ "$(<"${TEST_ROOT}/fingerprints")" = $'ssh-ed25519 SHA256:ed25519\nssh-rsa SHA256:rsa' ]
}

@test "SSH fingerprint capture retries a transient partial scan" {
	write_keyscan_stub
	capture_fingerprints transient
	[ "${status}" -eq 0 ]
	[ "$(<"${TEST_ROOT}/scan-count")" -eq 2 ]
	[ "$(wc -l <"${TEST_ROOT}/fingerprints")" -eq 2 ]
}

@test "SSH fingerprint capture rejects permanently incomplete scans without key blobs" {
	write_keyscan_stub
	capture_fingerprints incomplete
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"rsa and ed25519 are both required"* ]]
	[[ "${output}" != *"ed-key"* ]]
	[ ! -e "${TEST_ROOT}/fingerprints" ]
}
