#!/usr/bin/env bats

@test "connect rcfile local PTY behavior and forbidden-call guards" {
	run env PYTHONDONTWRITEBYTECODE=1 python3 "${BATS_TEST_DIRNAME}/container-connect-test.py"
	printf '%s\n' "${output}"
	[ "${status}" -eq 0 ]
}
