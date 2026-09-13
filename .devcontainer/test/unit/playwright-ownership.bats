#!/usr/bin/env bats

@test "Playwright provisioning respects user ownership and existing state (offline fixtures)" {
	run python3 "${BATS_TEST_DIRNAME}/playwright-ownership.py" -v
	[ "${status}" -eq 0 ]
}
