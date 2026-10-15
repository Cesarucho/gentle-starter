#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	export HOME="${BATS_TEST_TMPDIR}/home"
	export CALLS="${BATS_TEST_TMPDIR}/calls"
	mkdir -p "${HOME}/config" "${BATS_TEST_TMPDIR}/source" "${BATS_TEST_TMPDIR}/bin"
	SOURCE="${BATS_TEST_TMPDIR}/source"
	TARGET="${HOME}/config"
	printf '{}\n' >"${TARGET}/package.json"
	cat >"${BATS_TEST_TMPDIR}/bin/npm" <<'SH'
#!/usr/bin/env bash
printf '%s\n%s\n' "$PWD" "$*" >>"${CALLS}"
exit "${NPM_STATUS:-0}"
SH
	chmod +x "${BATS_TEST_TMPDIR}/bin/npm"
	export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

invoke() {
	run bash -c 'set -euo pipefail; source "$1"; install_config_dependencies "$2" "$3"' _ \
		"${REPO_ROOT}/.devcontainer/lifecycle/config-dependencies.sh" "${SOURCE}" "${TARGET}"
}

@test "config dependencies skip sources without a manifest" {
	invoke
	[ "$status" -eq 0 ]
	[ ! -e "${CALLS}" ]
}

@test "config dependencies install effective runtime manifest on every invocation without changing seed" {
	printf '{"dependencies":{"seed":"1"}}\n' >"${SOURCE}/package.json"
	printf '{"dependencies":{"custom":"2"}}\n' >"${TARGET}/package.json"
	local before
	before="$(sha256sum "${SOURCE}/package.json" "${TARGET}/package.json")"
	invoke
	[ "$status" -eq 0 ]
	[ "$(cat "${CALLS}")" = "${TARGET}"$'\ninstall --global=false --prefix '"${TARGET}"' --ignore-scripts --no-audit --no-fund' ]
	invoke
	[ "$status" -eq 0 ]
	[ "$(wc -l <"${CALLS}")" -eq 4 ]
	[ "$(sha256sum "${SOURCE}/package.json" "${TARGET}/package.json")" = "${before}" ]
}

@test "config dependencies reject invalid or unsafe targets before npm" {
	printf '{}\n' >"${SOURCE}/package.json"
	printf 'invalid\n' >"${TARGET}/package.json"
	invoke
	[ "$status" -ne 0 ]
	[ ! -e "${CALLS}" ]
	rm "${TARGET}/package.json"
	ln -s "${SOURCE}/package.json" "${TARGET}/package.json"
	invoke
	[ "$status" -ne 0 ]
	[ ! -e "${CALLS}" ]
}

@test "config dependencies propagate npm failure with a setup diagnostic" {
	printf '{}\n' >"${SOURCE}/package.json"
	export NPM_STATUS=42
	invoke
	[ "$status" -eq 42 ]
	[[ "$output" == *'Config dependency installation failed'* ]]
}

@test "config dependencies override inherited npm global mode and prefix" {
	printf '{}\n' >"${SOURCE}/package.json"
	export npm_config_global=true npm_config_prefix="${BATS_TEST_TMPDIR}/outside"
	cat >"${BATS_TEST_TMPDIR}/bin/npm" <<'SH'
#!/usr/bin/env bash
# Model npm precedence: explicit CLI options override inherited configuration.
global="${npm_config_global}"
prefix="${npm_config_prefix}"
while [ "$#" -gt 0 ]; do
	case "$1" in
	--global=false) global=false; shift ;;
	--prefix) prefix="$2"; shift 2 ;;
	*) shift ;;
	esac
done
[ "$global" = false ] && [ "$prefix" = "$PWD" ] || exit 71
printf '%s\n' "$prefix" >"${CALLS}"
SH
	invoke
	[ "$status" -eq 0 ]
	[ "$(cat "${CALLS}")" = "${TARGET}" ]
	[ ! -e "${npm_config_prefix}" ]
}

@test "config dependencies reject multiple JSON documents" {
	printf '{}\n' >"${SOURCE}/package.json"
	printf '{} {}\n' >"${TARGET}/package.json"
	invoke
	[ "$status" -eq 1 ]
	[[ "$output" == *'Invalid config package.json'* ]]
	[ ! -e "${CALLS}" ]
}

@test "dependency wrapper preserves early seed failures even in conditional context" {
	printf 'first\n' >"${SOURCE}/first"
	printf 'second\n' >"${SOURCE}/second"
	run bash -c '
		set -euo pipefail
		source "$1"
		eval "$(sed -n "/^seed_config_tree() {/,/^}/p" "$2")"
		count=0
		cp() { count=$((count + 1)); if [ "$count" -eq 1 ]; then return 42; fi; command cp "$@"; }
		if seed_config_with_dependencies "$3" "$4"; then exit 99; else exit "$?"; fi
	' _ "${REPO_ROOT}/.devcontainer/lifecycle/config-dependencies.sh" \
		"${REPO_ROOT}/.devcontainer/setup.sh" "${SOURCE}" "${TARGET}"
	[ "$status" -eq 42 ]
	[ ! -e "${CALLS}" ]
}
