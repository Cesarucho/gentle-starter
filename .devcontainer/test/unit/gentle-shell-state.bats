#!/usr/bin/env bats

@test "Shell passive bind host ownership and manifest proof uses no Docker" {
	run env PYTHONDONTWRITEBYTECODE=1 python3 "${BATS_TEST_DIRNAME}/gentle-shell-state-test.py" -v
	printf '%s\n' "${output}"
	[ "$status" -eq 0 ]
}
