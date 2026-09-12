#!/usr/bin/env bats

@test "isolated Compose manifest contracts" {
	run env PYTHONDONTWRITEBYTECODE=1 python3 "${BATS_TEST_DIRNAME}/compose-manifest-test.py" -v
	printf '%s\n' "${output}"
	[ "${status}" -eq 0 ]
}
