#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	INSTALL_ROOT="${TEST_ROOT}/install"
	HOME_DIR="${TEST_ROOT}/home/ubuntu"
	mkdir -p "${INSTALL_ROOT}/01-core" "${INSTALL_ROOT}/lib" "${HOME_DIR}"
	cp "${REPO_ROOT}/.devcontainer/install/01-core/90-post-setup-users.sh" "${INSTALL_ROOT}/01-core/"
	cat >"${INSTALL_ROOT}/lib/common.sh" <<'SH'
devcontainer_log_info() { :; }
devcontainer_run_as_root() {
	if [ "$1" = tee ]; then cat >/dev/null; return; fi
	if [ "$1" = chmod ] && [ "$3" = /etc/sudoers.d/95-ubuntu ]; then return; fi
	"$@"
}
SH
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

@test "build-time user finalization creates exact ubuntu-owned local parents without recursion" {
	run env HOME="${HOME_DIR}" DEVCONTAINER_USER_HOME="${HOME_DIR}" UID_NAME=ubuntu \
		bash "${INSTALL_ROOT}/01-core/90-post-setup-users.sh"

	[ "${status}" -eq 0 ]
	[ "$(stat -c '%U:%G:%a' -- "${HOME_DIR}/.local")" = "ubuntu:ubuntu:755" ]
	[ "$(stat -c '%U:%G:%a' -- "${HOME_DIR}/.local/bin")" = "ubuntu:ubuntu:755" ]
	implementation="$(cat "${REPO_ROOT}/.devcontainer/install/01-core/90-post-setup-users.sh")"
	[[ "${implementation}" != *'chown -R'* ]]
	[[ "${implementation}" != *'DEVCONTAINER_PHASE=runtime'* ]]
}
