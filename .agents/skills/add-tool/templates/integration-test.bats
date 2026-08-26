#!/usr/bin/env bats
# Copy into the derivative's integration suite and adapt its existing skip helper.

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
}

install_is_enabled() {
	local enabled_name="$1"
	[ -L "${REPO_ROOT}/.devcontainer/install/02-enabled/${enabled_name}" ]
}

@test "example tool is available at the canonical enabled slot" {
	install_is_enabled "NN-example.sh" || skip "example installer is disabled"
	command -v example
	run example --version
	[ "$status" -eq 0 ]
	[[ "$output" == *"1.2.3"* ]]
}

@test "enable helper recreates the canonical example slot" {
	# Prefer the repository's existing sandbox/helper pattern; never mutate the real tree.
	# TODO: copy install helper and installer into a temporary tree, disable then enable,
	# and assert NN-example.sh points relatively to ../available/NN-category-example.sh.
	false
}
