#!/usr/bin/env bats

@test "base lifecycle control flow and isolation use only unprivileged mocks" {
	run env PYTHONDONTWRITEBYTECODE=1 python3 "${BATS_TEST_DIRNAME}/starter-lifecycle-test.py"
	printf '%s\n' "${output}"
	[ "${status}" -eq 0 ]
}

@test "test resource ownership and recovery use synthetic files and Docker mocks" {
	run env PYTHONDONTWRITEBYTECODE=1 python3 "${BATS_TEST_DIRNAME}/test-resources-test.py"
	printf '%s\n' "${output}"
	[ "${status}" -eq 0 ]
}
