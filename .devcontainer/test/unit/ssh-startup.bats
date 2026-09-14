#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	WRAPPER="${REPO_ROOT}/.devcontainer/ssh-config/usr/local/bin/start-sshd"
	TEST_ROOT="$(mktemp -d)"
	BIN_DIR="${TEST_ROOT}/bin"
	KEY_DIR="${TEST_ROOT}/keys/ssh"
	CONFIG="${TEST_ROOT}/sshd_config"
	RUN_DIR="${TEST_ROOT}/run/sshd"
	CALLS="${TEST_ROOT}/calls"
	RUNNING="${TEST_ROOT}/running"
	PROC_ROOT="${TEST_ROOT}/proc"
	PID_FILE="${RUN_DIR}/gentle-starter-sshd.pid"
	mkdir -p "${BIN_DIR}" "${KEY_DIR}" "${PROC_ROOT}"
	printf 'HostKey %s/ssh_host_ed25519_key\n' "${KEY_DIR}" >"${CONFIG}"
	printf 'rsa-private\n' >"${KEY_DIR}/ssh_host_rsa_key"
	printf 'ed25519-private\n' >"${KEY_DIR}/ssh_host_ed25519_key"
	chmod 0600 "${KEY_DIR}"/ssh_host_*_key
	write_command_stubs
}

teardown() {
	if [ -s "${RUNNING}" ]; then kill "$(cat "${RUNNING}")" 2>/dev/null || true; fi
	rm -rf "${TEST_ROOT}"
}

write_command_stubs() {
	cat >"${BIN_DIR}/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo' >>"${CALLS}"
printf ' %q' "$@" >>"${CALLS}"
printf '\n' >>"${CALLS}"
[ "${1:-}" = -n ] && shift
if [ "${1:-}" = install ]; then
	target="${!#}"
	exec /usr/bin/install -d -m 0755 "${target}"
fi
exec "$@"
EOF
	cat >"${BIN_DIR}/stat" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = -c ] && [ "${2:-}" = %u ] && [ "${3:-}" = "${SSHD_PID_FILE}" ] && { printf '0\n'; exit; }
exec /usr/bin/stat "$@"
EOF
	cat >"${BIN_DIR}/sshd" <<'EOF'
#!/usr/bin/env bash
printf 'sshd' >>"${CALLS}"
printf ' %q' "$@" >>"${CALLS}"
printf '\n' >>"${CALLS}"
if [ "${1:-}" = -T ]; then
	printf 'hostkey %s/ssh_host_rsa_key\n' "${KEY_DIR}"
	printf 'hostkey %s/ssh_host_ed25519_key\n' "${KEY_DIR}"
	printf '%s\n' 'authorizedkeysfile .ssh/authorized_keys' 'strictmodes yes' \
		'pubkeyauthentication yes' 'passwordauthentication no' 'kbdinteractiveauthentication no' \
		'permitrootlogin no' 'usepam yes'
elif [ "${1:-}" = -t ]; then
	[ "${INVALID_CONFIG:-0}" = 0 ] || exit 1
else
	sleep 300 >/dev/null 2>&1 &
	pid=$!
	printf '%s\n' "${pid}" >"${RUNNING}"
	(
		sleep "${SSHD_STUB_DELAY:-0}"
		mkdir -p "${PROC_ROOT}/${pid}" "$(dirname "${SSHD_PID_FILE}")"
		printf 'Uid:\t0\t0\t0\t0\n' >"${PROC_ROOT}/${pid}/status"
		ln -sf "${SSHD_BIN}" "${PROC_ROOT}/${pid}/exe"
		printf 'sshd: %s -f %s -o PidFile=%s -e [listener] 0 of 10-100 startups\0' \
			"${SSHD_BIN}" "${SSHD_CONFIG}" "${SSHD_PID_FILE}" >"${PROC_ROOT}/${pid}/cmdline"
		printf '%s\n' "${pid}" >"${SSHD_PID_FILE}"
	) &
fi
EOF
	cat >"${BIN_DIR}/ssh-keygen" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = -y ]; then
	printf 'public-key\n'
	exit 0
fi
while [ "$#" -gt 0 ]; do
	if [ "$1" = -f ]; then
		shift
		printf 'regenerated-%s\n' "$(date +%s%N)" >"$1"
		printf 'public-key\n' >"$1.pub"
		exit 0
	fi
	shift
done
exit 2
EOF
	chmod +x "${BIN_DIR}/sudo" "${BIN_DIR}/stat" "${BIN_DIR}/sshd" "${BIN_DIR}/ssh-keygen"
}

run_wrapper() {
	run env HOME="${TEST_ROOT}/home" PATH="${BIN_DIR}:/usr/bin:/bin" \
		CALLS="${CALLS}" RUNNING="${RUNNING}" SSH_CONFIG_DIR="${TEST_ROOT}/keys" KEY_DIR="${KEY_DIR}" \
		SSHD_CONFIG="${CONFIG}" SSHD_BIN="${BIN_DIR}/sshd" SSHD_RUN_DIR="${RUN_DIR}" SSHD_PID_FILE="${PID_FILE}" \
		PROC_ROOT="${PROC_ROOT}" STARTUP_ATTEMPTS=30 STARTUP_DELAY=0.02 \
		bash "${WRAPPER}"
}

@test "startup limits privilege to running checks, runtime directory, validation, and daemon" {
	run_wrapper
	[ "${status}" -eq 0 ]
	[ "$(stat -c '%a' "${RUN_DIR}")" = 755 ]
	grep -Fqx "sudo -n install -d -o root -g root -m 0755 ${RUN_DIR}" "${CALLS}"
	grep -Fqx "sudo -n ${BIN_DIR}/sshd -T -f ${CONFIG} -C user=$(id -un)\\,host=localhost\\,addr=127.0.0.1 -o PidFile=${PID_FILE}" "${CALLS}"
	grep -Fqx "sudo -n ${BIN_DIR}/sshd -t -f ${CONFIG} -o PidFile=${PID_FILE}" "${CALLS}"
	grep -Fqx "sudo -n ${BIN_DIR}/sshd -f ${CONFIG} -o PidFile=${PID_FILE} -e" "${CALLS}"
	[ "$(stat -c '%a' "${KEY_DIR}/ssh_host_ed25519_key")" = 600 ]
}

@test "unrelated sshd does not satisfy or get stopped by the managed identity check" {
	sleep 300 &
	unrelated_pid=$!
	run_wrapper
	[ "${status}" -eq 0 ]
	kill -0 "${unrelated_pid}"
	kill "${unrelated_pid}"
}

@test "stale managed PID is removed and replaced without signaling that process" {
	mkdir -p "${RUN_DIR}"
	sleep 300 &
	stale_pid=$!
	printf '%s\n' "${stale_pid}" >"${PID_FILE}"
	run_wrapper
	[ "${status}" -eq 0 ]
	kill -0 "${stale_pid}"
	[ "$(cat "${PID_FILE}")" != "${stale_pid}" ]
	kill "${stale_pid}"
}

@test "missing and malformed managed PID files are replaced safely" {
	run_wrapper
	[ "${status}" -eq 0 ]
	first_pid="$(cat "${PID_FILE}")"
	kill "${first_pid}"
	rm -rf "${PROC_ROOT:?}/${first_pid}"
	printf 'not-a-pid\nextra\n' >"${PID_FILE}"

	run_wrapper
	[ "${status}" -eq 0 ]
	[[ "$(cat "${PID_FILE}")" =~ ^[0-9]+$ ]]
	[ "$(cat "${PID_FILE}")" != "${first_pid}" ]
}

@test "reused PID with the wrong executable is never trusted or signaled" {
	mkdir -p "${RUN_DIR}" "${PROC_ROOT}/4242"
	printf '4242\n' >"${PID_FILE}"
	printf 'Uid:\t0\t0\t0\t0\n' >"${PROC_ROOT}/4242/status"
	ln -s /usr/bin/sleep "${PROC_ROOT}/4242/exe"
	printf 'sshd: %s -f %s -o PidFile=%s -e [listener]\0' \
		"${SSHD_BIN}" "${SSHD_CONFIG}" "${SSHD_PID_FILE}" >"${PROC_ROOT}/4242/cmdline"
	sleep 300 &
	unrelated_pid=$!
	printf '%s\n' "${unrelated_pid}" >"${PID_FILE}"
	mv "${PROC_ROOT}/4242" "${PROC_ROOT}/${unrelated_pid}"

	run_wrapper
	[ "${status}" -eq 0 ]
	kill -0 "${unrelated_pid}"
	kill "${unrelated_pid}"
}

@test "startup polls through daemonization before accepting the real listener" {
	run env SSHD_STUB_DELAY=0.15 HOME="${TEST_ROOT}/home" PATH="${BIN_DIR}:/usr/bin:/bin" \
		CALLS="${CALLS}" RUNNING="${RUNNING}" SSH_CONFIG_DIR="${TEST_ROOT}/keys" KEY_DIR="${KEY_DIR}" \
		SSHD_CONFIG="${CONFIG}" SSHD_BIN="${BIN_DIR}/sshd" SSHD_RUN_DIR="${RUN_DIR}" SSHD_PID_FILE="${PID_FILE}" \
		PROC_ROOT="${PROC_ROOT}" STARTUP_ATTEMPTS=30 STARTUP_DELAY=0.02 bash "${WRAPPER}"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"sshd running on port 22"* ]]
}

@test "invalid sshd configuration fails before daemon startup" {
	run env INVALID_CONFIG=1 HOME="${TEST_ROOT}/home" PATH="${BIN_DIR}:/usr/bin:/bin" \
		CALLS="${CALLS}" RUNNING="${RUNNING}" SSH_CONFIG_DIR="${TEST_ROOT}/keys" \
		SSHD_CONFIG="${CONFIG}" SSHD_BIN="${BIN_DIR}/sshd" SSHD_RUN_DIR="${RUN_DIR}" SSHD_PID_FILE="${PID_FILE}" \
		PROC_ROOT="${PROC_ROOT}" STARTUP_ATTEMPTS=2 STARTUP_DELAY=0.01 bash "${WRAPPER}"
	[ "${status}" -ne 0 ]
	[ ! -s "${RUNNING}" ]
}

@test "missing configuration or host key fails before privileged startup" {
	rm "${CONFIG}"
	run_wrapper
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"sshd_config not found"* ]]
	[ ! -e "${CALLS}" ]

	printf 'HostKey missing\n' >"${CONFIG}"
	rm "${KEY_DIR}/ssh_host_rsa_key"
	run_wrapper
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"required host key is missing, unreadable, or not a regular file"* ]]
	[ ! -e "${CALLS}" ]
}

@test "effective configuration must bind exactly the persistent RSA and ED25519 keys" {
	cat >"${BIN_DIR}/sshd" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = -T ]; then
	printf 'hostkey /etc/ssh/ssh_host_rsa_key\n'
	printf 'hostkey /etc/ssh/ssh_host_ed25519_key\n'
	exit 0
fi
exit 97
EOF
	chmod +x "${BIN_DIR}/sshd"

	run_wrapper
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"effective HostKey paths do not match persistent managed keys"* ]]
	[ ! -s "${RUNNING}" ]
}

@test "startup rejects effective authentication settings weakened by config resolution" {
	cat >"${BIN_DIR}/sshd" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = -T ]; then
	printf 'hostkey %s/ssh_host_rsa_key\n' "${KEY_DIR}"
	printf 'hostkey %s/ssh_host_ed25519_key\n' "${KEY_DIR}"
	printf '%s\n' 'authorizedkeysfile .ssh/authorized_keys .ssh/authorized_keys2' 'strictmodes yes' \
		'pubkeyauthentication yes' 'passwordauthentication no' 'kbdinteractiveauthentication no' \
		'permitrootlogin no' 'usepam yes'
	exit 0
fi
exit 97
EOF
	chmod +x "${BIN_DIR}/sshd"

	run_wrapper
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"unsafe or incompatible effective SSH setting: authorizedkeysfile .ssh/authorized_keys"* ]]
	[ ! -s "${RUNNING}" ]
}

@test "host keys change only for explicit regeneration" {
	local before after
	before="$(sha256sum "${KEY_DIR}"/*_key)"
	run_wrapper
	[ "${status}" -eq 0 ]
	after="$(sha256sum "${KEY_DIR}"/*_key)"
	[ "${after}" = "${before}" ]
	pid="$(cat "${RUNNING}")"
	kill "${pid}"
	rm -rf "${PROC_ROOT:?}/${pid}" "${PID_FILE}"
	: >"${RUNNING}"

	run env HOME="${TEST_ROOT}/home" PATH="${BIN_DIR}:/usr/bin:/bin" \
		CALLS="${CALLS}" RUNNING="${RUNNING}" SSH_CONFIG_DIR="${TEST_ROOT}/keys" KEY_DIR="${KEY_DIR}" \
		SSHD_CONFIG="${CONFIG}" SSHD_BIN="${BIN_DIR}/sshd" SSHD_RUN_DIR="${RUN_DIR}" SSHD_PID_FILE="${PID_FILE}" \
		PROC_ROOT="${PROC_ROOT}" STARTUP_ATTEMPTS=30 STARTUP_DELAY=0.02 bash "${WRAPPER}" --regenerate
	[ "${status}" -eq 0 ]
	[ "$(sha256sum "${KEY_DIR}"/*_key)" != "${before}" ]
}

@test "second invocation is a no-op and preserves persistent fingerprints" {
	local before
	before="$(sha256sum "${KEY_DIR}"/*_key)"
	run_wrapper
	[ "${status}" -eq 0 ]
	: >"${CALLS}"
	run_wrapper
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"already running"* ]]
	! grep -Fq "${BIN_DIR}/sshd -f" "${CALLS}"
	[ "$(sha256sum "${KEY_DIR}"/*_key)" = "${before}" ]
}
