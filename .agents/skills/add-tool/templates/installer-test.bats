#!/usr/bin/env bats
# Copy beside repository unit tests, replace EXAMPLE paths/names, and make this RED first.

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	BIN_DIR="${TEST_ROOT}/bin"
	INSTALL_DIR="${TEST_ROOT}/install"
	mkdir -p "${BIN_DIR}" "${INSTALL_DIR}"
	export REPO_ROOT TEST_ROOT BIN_DIR INSTALL_DIR
	export PATH="${BIN_DIR}:${INSTALL_DIR}:${PATH}"
	# TODO: create deterministic amd64 and arm64 release fixtures and command stubs.
}

teardown() { rm -rf "${TEST_ROOT}"; }

run_installer() {
	run env \
		EXAMPLE_VERSION="1.2.3" \
		EXAMPLE_SHA256_AMD64="${TEST_SHA256_AMD64}" \
		EXAMPLE_SHA256_ARM64="${TEST_SHA256_ARM64}" \
		EXAMPLE_INSTALL_DIR="${INSTALL_DIR}" \
		EXAMPLE_FETCH_ATTEMPTS=3 \
		bash "${REPO_ROOT}/.devcontainer/install/available/NN-category-example.sh"
}

@test "installer replaces stale binary, then exact version skips network" {
	# TODO: install a stale fixture, run twice, assert replacement and unchanged fetch count.
	false
}

@test "installer selects and verifies each supported architecture" {
	# TODO: run with stubbed x86_64 and aarch64; mismatch each digest independently.
	false
}

@test "installer bounds retries and preserves previous binary" {
	# TODO: make fetch fail repeatedly; assert exact attempt count and old binary output.
	false
}

@test "installer rolls back when final verification fails" {
	# TODO: make only the installed target report a wrong version; assert old target restored.
	false
}

@test "installer rejects malformed policy and unsupported architecture before download" {
	# TODO: table-test empty digest, latest/prerelease when forbidden, and unknown uname.
	false
}
