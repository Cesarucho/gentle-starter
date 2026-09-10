#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
}

run_ssh_runtime_installer() {
	local root="$1"
	mkdir -p "${root}/home" "${root}/bin" "${root}/target"
	cat >"${root}/bin/ssh-keygen" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = -l ]; then
	[ -s "${3:-}" ]
	exit
fi
while [ "$#" -gt 0 ]; do
	if [ "$1" = -f ]; then
		shift
		: >"$1"
		: >"$1.pub"
		exit 0
	fi
	shift
done
exit 2
EOF
	chmod +x "${root}/bin/ssh-keygen"
	run env HOME="${root}/home" PATH="${root}/bin:/usr/bin:/bin" \
		WORKSPACE_DIR="${REPO_ROOT}" DEVCONTAINER_PHASE=runtime \
		SSH_CONFIG_DIR="${root}/keys" SSH_START_WRAPPER_TARGET="${root}/target/start-sshd" \
		SSHD_CONFIG_TARGET="${root}/target/sshd_config.gentle-starter" \
		bash -c 'seed_config_tree() { :; }; export -f seed_config_tree; exec bash "$1"' _ \
		"${REPO_ROOT}/.devcontainer/install/available/20-tool-ssh.sh"
}

@test "image-owned direct binaries have exact architecture digests" {
	local policy="${REPO_ROOT}/.devcontainer/tool-versions.conf"
	for key in \
		LOCK_OPENCODE_VERSION LOCK_OPENCODE_SHA256_AMD64 LOCK_OPENCODE_SHA256_ARM64 \
		LOCK_ENGRAM_VERSION LOCK_ENGRAM_SHA256_AMD64 LOCK_ENGRAM_SHA256_ARM64; do
		[ "$(grep -Ec "^${key}=\"[^\"]+\"$" "${policy}")" -eq 1 ]
	done
	for key in LOCK_OPENCODE_SHA256_AMD64 LOCK_OPENCODE_SHA256_ARM64 \
		LOCK_ENGRAM_SHA256_AMD64 LOCK_ENGRAM_SHA256_ARM64; do
		grep -Eq "^${key}=\"[0-9a-f]{64}\"$" "${policy}"
	done
}

@test "OpenCode runtime performs no binary or network mutation" {
	local calls="${BATS_TEST_TMPDIR}/calls"
	mkdir -p "${BATS_TEST_TMPDIR}/bin"
	cat >"${BATS_TEST_TMPDIR}/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf 'network\n' >>"${CALLS}"
exit 97
EOF
	chmod +x "${BATS_TEST_TMPDIR}/bin/curl"
	run env DEVCONTAINER_PHASE=runtime CALLS="${calls}" \
		PATH="${BATS_TEST_TMPDIR}/bin:/usr/bin:/bin" \
		bash "${REPO_ROOT}/.devcontainer/install/available/30-ai-opencode.sh"
	[ "${status}" -eq 0 ]
	[ ! -e "${calls}" ]
	[[ "${output}" == *"image-owned"* ]]
}

@test "Engram version parsing tolerates realistic trailing metadata" {
	local root="${BATS_TEST_TMPDIR}/engram"
	mkdir -p "${root}/bin" "${root}/home"
	cat >"${root}/bin/engram" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = version ]; then printf 'engram version v1.20.0 (commit abc123, built 2026-07-20)\n'; exit 0; fi
EOF
	chmod +x "${root}/bin/engram"
	run env HOME="${root}/home" DEVCONTAINER_PHASE=runtime ENGRAM_SETUP_PI=0 \
		ENGRAM_INSTALL_DIR="${root}/bin" ENGRAM_DATA_DIR="${root}/data" \
		bash "${REPO_ROOT}/.devcontainer/install/available/30-ai-engram.sh"
	[ "${status}" -eq 0 ]
	[ -d "${root}/data" ]
}

@test "setup prepares enabled SSH before starting and accepts arbitrary aliases" {
	local setup="${REPO_ROOT}/.devcontainer/setup.sh"
	grep -Fq 'install_script_is_enabled "${_ssh_installer}"' "${setup}"
	local prepare_line start_line
	prepare_line="$(grep -nF 'DEVCONTAINER_PHASE=runtime bash "${_ssh_installer}"' "${setup}" | cut -d: -f1)"
	start_line="$(grep -nF $'\t\tstart-sshd' "${setup}" | cut -d: -f1)"
	[ -n "${prepare_line}" ]
	[ -n "${start_line}" ]
	[ "${prepare_line}" -lt "${start_line}" ]
}

@test "SSH runtime installs the startup wrapper as executable" {
	local root="${BATS_TEST_TMPDIR}/new-wrapper"
	run_ssh_runtime_installer "${root}"
	[ "${status}" -eq 0 ]
	[ "$(stat -c '%a' "${root}/target/start-sshd")" = 755 ]
	cmp -s "${REPO_ROOT}/.devcontainer/ssh-config/usr/local/bin/start-sshd" \
		"${root}/target/start-sshd"
	cmp -s "${REPO_ROOT}/.devcontainer/ssh-config/etc/ssh/sshd_config" \
		"${root}/target/sshd_config.gentle-starter"
}

@test "managed SSH config preserves key-only access for the password-locked ubuntu account" {
	local config="${REPO_ROOT}/.devcontainer/ssh-config/etc/ssh/sshd_config"
	grep -Fqx 'UsePAM yes' "${config}"
	grep -Fqx 'StrictModes yes' "${config}"
	grep -Fqx 'PubkeyAuthentication yes' "${config}"
	grep -Fqx 'PasswordAuthentication no' "${config}"
	grep -Fqx 'ChallengeResponseAuthentication no' "${config}"
	grep -Fqx 'PermitRootLogin no' "${config}"
	grep -Fqx 'AuthorizedKeysFile  .ssh/authorized_keys' "${config}"
}

@test "SSH authorization is authoritative, validated, and StrictModes-safe" {
	local root="${BATS_TEST_TMPDIR}/authorized-keys"
	mkdir -p "${root}/home/.ssh"
	printf 'ssh-rsa AAAAlegacy legacy\n' >"${root}/home/.ssh/authorized_keys"
	chmod 0777 "${root}/home/.ssh"

	SSH_AUTHORIZED_KEYS='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestOnly lifecycle' run_ssh_runtime_installer "${root}"
	[ "${status}" -eq 0 ]
	[ "$(<"${root}/home/.ssh/authorized_keys")" = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestOnly lifecycle' ]
	[ "$(stat -c '%a' "${root}/home/.ssh")" = 700 ]
	[ "$(stat -c '%a' "${root}/home/.ssh/authorized_keys")" = 600 ]

	SSH_AUTHORIZED_KEYS='command="anything" ssh-ed25519 AAAAunsafe' run_ssh_runtime_installer "${root}"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"unsupported or malformed public key"* ]]
}

@test "SSH runtime fails closed when the home path violates StrictModes" {
	local root="${BATS_TEST_TMPDIR}/unsafe-home"
	mkdir -p "${root}/home"
	chmod 0777 "${root}/home"

	run_ssh_runtime_installer "${root}"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"StrictModes requires"* ]]
}

@test "SSH runtime preserves an existing regular wrapper and repairs its mode" {
	local root="${BATS_TEST_TMPDIR}/existing-wrapper"
	mkdir -p "${root}/target"
	printf '#!/usr/bin/env bash\nprintf custom\\n\n' >"${root}/target/start-sshd"
	chmod 0644 "${root}/target/start-sshd"
	local before
	before="$(sha256sum "${root}/target/start-sshd" | cut -d' ' -f1)"

	run_ssh_runtime_installer "${root}"
	[ "${status}" -eq 0 ]
	[ "$(stat -c '%a' "${root}/target/start-sshd")" = 755 ]
	[ "$(sha256sum "${root}/target/start-sshd" | cut -d' ' -f1)" = "${before}" ]
}

@test "persistent SSH host keys use a host-prepared passive bind" {
	local compose="${REPO_ROOT}/.devcontainer/docker-compose.yml"
	yq -e '.services."container-svc".volumes[] | select(.source == "../.env.d/.ssh-server" and .target == "/home/ubuntu/.ssh-server" and .bind.create_host_path == false)' "${compose}" >/dev/null
	local scripts=(sentinel)
	WORKSPACE_DIR="${REPO_ROOT}"
	source "${REPO_ROOT}/.devcontainer/setup-volumes.sh"
	compose_target_to_install_scripts "/home/ubuntu/.ssh-server" scripts
	[ "${#scripts[@]}" -eq 0 ]
}
