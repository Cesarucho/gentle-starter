#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	export HOME="${BATS_TEST_TMPDIR}/home"
	CONFIG="${BATS_TEST_TMPDIR}/config"
	mkdir -p "${HOME}" "${CONFIG}"
}

seed() {
	run bash -c 'set -euo pipefail; eval "$(sed -n "/^seed_config_tree() {/,/^}/p" "$1")"; seed_config_tree "$2" "$3"' _ \
		"${REPO_ROOT}/.devcontainer/setup.sh" "$1" "$2"
}

seed_asyncapi_defaults() {
	run env ASYNCAPI_ENABLED="$1" bash -c '
		set -euo pipefail
		SCRIPT_DIR="$1/.devcontainer"
		WORKSPACE_DIR="$1"
		eval "$(sed -n "/^seed_config_tree() {/,/^}/p" "$SCRIPT_DIR/setup.sh")"
		eval "$(sed -n "/^setup_versioned_configs() {/,/^}/p" "$SCRIPT_DIR/setup.sh")"
		install_script_is_enabled() {
			[ "$ASYNCAPI_ENABLED" = true ] && [[ "$1" == */2040-node-contracts.sh ]]
		}
		setup_versioned_configs
	' _ "${REPO_ROOT}"
}

@test "AsyncAPI default disables analytics without a shared user identifier" {
	seed_asyncapi_defaults true
	[ "$status" -eq 0 ]
	run python3 - "${HOME}/.asyncapi-analytics" <<'PY'
import json, sys
from pathlib import Path
settings = json.loads(Path(sys.argv[1]).read_text())
assert settings == {"analyticsEnabled": "false", "infoMessageShown": "true"}
PY
	[ "$status" -eq 0 ]
	[ ! -L "${HOME}/.asyncapi-analytics" ]
	before="$(sha256sum "${HOME}/.asyncapi-analytics")"
	seed_asyncapi_defaults true
	[ "$status" -eq 0 ]
	[ "$(sha256sum "${HOME}/.asyncapi-analytics")" = "$before" ]
}

@test "AsyncAPI default preserves existing enabled and disabled preferences byte for byte" {
	for enabled in true false; do
		printf '{"analyticsEnabled":"%s","userID":"local-fixture-id","custom":42}\n' "$enabled" >"${HOME}/.asyncapi-analytics"
		before="$(sha256sum "${HOME}/.asyncapi-analytics")"
		seed_asyncapi_defaults true
		[ "$status" -eq 0 ]
		[ "$(sha256sum "${HOME}/.asyncapi-analytics")" = "$before" ]
	done
}

@test "AsyncAPI default is absent when the contract installer is disabled" {
	seed_asyncapi_defaults false
	[ "$status" -eq 0 ]
	[ ! -e "${HOME}/.asyncapi-analytics" ]
}

@test "AsyncAPI default does not follow an existing dangling configuration link" {
	ln -s "${HOME}/external-settings" "${HOME}/.asyncapi-analytics"
	seed_asyncapi_defaults true
	[ "$status" -eq 0 ]
	[ -L "${HOME}/.asyncapi-analytics" ]
	[ ! -e "${HOME}/external-settings" ]
}

@test "config seeding supports arbitrary directory and linked roots without overwriting runtime files" {
	local tool mode source target profile
	for tool in example-tool future-tool; do
		for mode in directory symlink; do
			source="${CONFIG}/${tool}-${mode}"
			target="${HOME}/${tool}-${mode}"
			profile="${CONFIG}/${tool}-${mode}-profile"
			mkdir -p "${profile}/nested" "${target}"
			printf 'selected\n' >"${profile}/nested/settings.json"
			printf 'baseline\n' >"${profile}/existing.json"
			printf 'custom\n' >"${target}/existing.json"
			if [ "${mode}" = symlink ]; then
				ln -s "$(basename "${profile}")" "${source}"
			else
				mv "${profile}" "${source}"
			fi
			seed "${source}" "${target}"
			[ "${status}" -eq 0 ]
			[ -z "${output}" ]
			[ "$(cat "${target}/nested/settings.json")" = selected ]
			[ "$(cat "${target}/existing.json")" = custom ]
			[ ! -L "${target}/nested/settings.json" ]
		done
	done
}

@test "config seeding rejects broken and non-directory root links before mutation" {
	local kind source target before
	printf 'not a directory\n' >"${CONFIG}/file"
	for kind in missing file; do
		source="${CONFIG}/selector-${kind}"
		target="${HOME}/${kind}"
		ln -s "${kind}" "${source}"
		seed "${source}" "${target}"
		[ "${status}" -eq 1 ]
		[[ "${output}" == *"[setup:error] Invalid config seed directory: ${source}"* ]]
		[ ! -e "${target}" ]
		[ -L "${source}" ]
		mkdir -p "${target}"
		printf 'custom\n' >"${target}/existing.json"
		before="$(sha256sum "${target}/existing.json")"
		seed "${source}" "${target}"
		[ "${status}" -eq 1 ]
		[ "$(sha256sum "${target}/existing.json")" = "${before}" ]
		[ "$(find "${target}" -mindepth 1 | wc -l)" -eq 1 ]
	done
}

@test "config seeding accepts a relative selector and a linked ancestor" {
	mkdir -p "${CONFIG}/profile/nested"
	printf 'selected\n' >"${CONFIG}/profile/nested/settings.json"
	ln -s profile "${CONFIG}/selector"
	ln -s "${CONFIG}" "${BATS_TEST_TMPDIR}/config-alias"
	cd "${CONFIG}"
	seed selector "${HOME}/relative"
	[ "${status}" -eq 0 ]
	[ -z "${output}" ]
	[ "$(cat "${HOME}/relative/nested/settings.json")" = selected ]
	seed "${BATS_TEST_TMPDIR}/config-alias/profile" "${HOME}/ancestor"
	[ "${status}" -eq 0 ]
	[ -z "${output}" ]
	[ "$(cat "${HOME}/ancestor/nested/settings.json")" = selected ]
}

@test "config seeding does not follow internal links through a linked root" {
	mkdir -p "${CONFIG}/profile" "${CONFIG}/outside"
	printf 'external\n' >"${CONFIG}/outside/secret"
	printf 'selected\n' >"${CONFIG}/profile/settings.json"
	ln -s ../outside "${CONFIG}/profile/linked-directory"
	ln -s ../outside/secret "${CONFIG}/profile/linked-file"
	ln -s profile "${CONFIG}/selector"
	seed "${CONFIG}/selector" "${HOME}/runtime"
	[ "${status}" -eq 0 ]
	[ "$(cat "${HOME}/runtime/settings.json")" = selected ]
	[ ! -e "${HOME}/runtime/linked-directory" ]
	[ ! -e "${HOME}/runtime/linked-file" ]
}

@test "config seeding still skips an absent optional source" {
	seed "${CONFIG}/absent" "${HOME}/runtime"
	[ "${status}" -eq 0 ]
	[ -z "${output}" ]
	[ ! -e "${HOME}/runtime" ]
}

@test "config seeding normalizes trailing slashes for directory and linked roots" {
	local mode suffix source target
	mkdir -p "${CONFIG}/profile/nested"
	printf 'selected\n' >"${CONFIG}/profile/nested/settings.json"
	ln -s profile "${CONFIG}/selector"
	for mode in profile selector; do
		for suffix in / ///; do
			source="${CONFIG}/${mode}${suffix}"
			target="${HOME}/${mode}-${#suffix}"
			seed "${source}" "${target}"
			[ "${status}" -eq 0 ]
			[ -z "${output}" ]
			[ "$(cat "${target}/nested/settings.json")" = selected ]
			[ "$(find "${target}" -type f | wc -l)" -eq 1 ]
		done
	done
}

@test "config seeding rejects invalid selectors with trailing slashes without changing runtime" {
	local kind suffix source before
	printf 'not a directory\n' >"${CONFIG}/file"
	mkdir -p "${HOME}/runtime"
	printf 'custom\n' >"${HOME}/runtime/existing.json"
	before="$(sha256sum "${HOME}/runtime/existing.json")"
	for kind in missing file; do
		ln -s "${kind}" "${CONFIG}/selector-${kind}"
		for suffix in / ///; do
			source="${CONFIG}/selector-${kind}"
			seed "${source}${suffix}" "${HOME}/runtime"
			[ "${status}" -eq 1 ]
			[ "${output}" = "[setup:error] Invalid config seed directory: ${source}" ]
			[ "$(sha256sum "${HOME}/runtime/existing.json")" = "${before}" ]
			[ "$(find "${HOME}/runtime" -mindepth 1 | wc -l)" -eq 1 ]
		done
	done
}

@test "config seeding preserves filesystem root while normalizing slash-only sources" {
	local source
	for source in / ///; do
		run bash -c '
			set -euo pipefail
			eval "$(sed -n "/^seed_config_tree() {/,/^}/p" "$1")"
			find() { [ "$#" -eq 4 ] && [ "$1" = -H ] && [ "$2" = / ] && [ "$3" = -type ] && [ "$4" = f ] || printf "unexpected find arguments\n"; }
			seed_config_tree "$2" "$3"
		' _ "${REPO_ROOT}/.devcontainer/setup.sh" "${source}" "${HOME}/runtime"
		[ "${status}" -eq 0 ]
		[ -z "${output}" ]
		[ ! -e "${HOME}/runtime" ]
	done
}
