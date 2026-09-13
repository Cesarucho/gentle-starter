#!/usr/bin/env bats

setup() {
	FIXTURE="${BATS_TEST_TMPDIR}/selection"
	INSTALL="${FIXTURE}/install"
	mkdir -p "${INSTALL}/available" "${INSTALL}/02-core-tools" "${INSTALL}/03-enabled" "${FIXTURE}/test/integration" "${FIXTURE}/bin"
	cp "${BATS_TEST_DIRNAME}/../integration/"{tools.bats,install-selection.sh} "${FIXTURE}/test/integration/"
	printf '# Fixture source; never executed.\n' >"${INSTALL}/available/30-ai-gentle-ai.sh"
	BATS_BIN="$(command -v bats)"
	# Keep the actual BATS runner utilities, but no installed optional package.
	local utility
	for utility in bash env dirname basename readlink realpath mktemp rm ln cp ps cat sed grep sort uniq nl tr head tail cut wc uname sleep touch mkdir rmdir date tput stty timeout; do
		ln -s "$(command -v "${utility}")" "${FIXTURE}/bin/${utility}"
	done
}

run_gentle_check() {
	run env PATH="${FIXTURE}/bin" "${BATS_BIN}" --filter '^ai: Gentle AI is installed$' \
		"${FIXTURE}/test/integration/tools.bats"
	printf '%s\n' "${output}"
}

@test "disabled optional installer skips even when its package is absent" {
	run_gentle_check
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'# skip disabled install'* ]]
}

@test "custom alias selects the canonical installer and missing package fails" {
	ln -s ../available/30-ai-gentle-ai.sh "${INSTALL}/02-core-tools/47-custom.sh"
	run_gentle_check
	[ "${status}" -ne 0 ]
	[[ "${output}" == *'not ok 1 ai: Gentle AI is installed'* ]]
	[[ "${output}" != *'# skip'* ]]
}

@test "custom alias accepts an installed working package without a fixed slot" {
	ln -s ../available/30-ai-gentle-ai.sh "${INSTALL}/03-enabled/47-custom.sh"
	# shellcheck disable=SC2016 # The fixture executable evaluates its own argument.
	printf '#!/bin/bash\n[ "$1" = version ]\n' >"${FIXTURE}/bin/gentle-ai"
	chmod +x "${FIXTURE}/bin/gentle-ai"
	run_gentle_check
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'ok 1 ai: Gentle AI is installed'* ]]
	[[ "${output}" != *'# skip'* ]]
}

@test "broken activation is an error rather than a disabled skip" {
	ln -s ../available/missing.sh "${INSTALL}/02-core-tools/47-custom.sh"
	run_gentle_check
	[ "${status}" -ne 0 ]
	[[ "${output}" == *'not ok 1 ai: Gentle AI is installed'* ]]
	[[ "${output}" != *'# skip'* ]]
}
