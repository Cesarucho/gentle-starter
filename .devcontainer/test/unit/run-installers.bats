#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	INSTALLERS="${TEST_ROOT}/installers"
	LOG="${TEST_ROOT}/execution.log"
	mkdir -p "${INSTALLERS}"
}

teardown() { rm -rf "${TEST_ROOT}"; }

write_installer() {
	local name="$1" status="$2"
	cat >"${INSTALLERS}/${name}" <<EOF
#!/usr/bin/env bash
printf '%s:%s\n' '${name}' "\${DEVCONTAINER_PHASE}" >>'${LOG}'
exit ${status}
EOF
	chmod +x "${INSTALLERS}/${name}"
}

@test "installer runner preserves deterministic success order" {
	write_installer 30-third.sh 0
	write_installer 10-first.sh 0
	write_installer 20-second.sh 0

	run "${REPO_ROOT}/.devcontainer/install/lib/run-installers.sh" "${INSTALLERS}"

	[ "${status}" -eq 0 ]
	[ "$(<"${LOG}")" = $'10-first.sh:build\n20-second.sh:build\n30-third.sh:build' ]
}

@test "installer runner returns the exact failure and skips later installers" {
	write_installer 10-first.sh 0
	write_installer 20-fails.sh 73
	write_installer 30-skipped.sh 0

	run "${REPO_ROOT}/.devcontainer/install/lib/run-installers.sh" "${INSTALLERS}"

	[ "${status}" -eq 73 ]
	[ "$(<"${LOG}")" = $'10-first.sh:build\n20-fails.sh:build' ]
}

@test "installer runner rejects a missing group" {
	run "${REPO_ROOT}/.devcontainer/install/lib/run-installers.sh" "${TEST_ROOT}/missing"

	[ "${status}" -eq 1 ]
	[[ "${output}" == *"Installer directory does not exist"* ]]
}
