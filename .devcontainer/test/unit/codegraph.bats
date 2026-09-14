#!/usr/bin/env bats

@test "CodeGraph installer, launcher, configuration and selection contracts" {
	run python3 -B "${BATS_TEST_DIRNAME}/codegraph-test.py"
	[ "$status" -eq 0 ]
}
