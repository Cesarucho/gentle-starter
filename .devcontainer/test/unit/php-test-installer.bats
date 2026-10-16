#!/usr/bin/env bats

@test "PHPUnit installer uses exact Composer constraints and a shared binary prefix offline" {
	run env PYTHONDONTWRITEBYTECODE=1 python3 "${BATS_TEST_DIRNAME}/php-test-installer-test.py"
	printf '%s\n' "${output}"
	[ "${status}" -eq 0 ]
}
