#!/usr/bin/env bats

load install-fixture

@test "doctor rejects active consumers with missing prerequisites" {
	ln -s ../available/1020-tool-leaf.sh "${INSTALL}/03-enabled/99-custom.sh"
	activate doctor
	[ "$status" -ne 0 ]
	[[ "$output" == *"requires enabled installer 1010-tool-middle.sh"* ]]
}

@test "list excludes canonical targets selected through custom aliases" {
	touch "${INSTALL}/01-foundation/10-base.sh" "${INSTALL}/04-hooks/10-hook.sh"
	ln -s ../available/1000-runtime-base.sh "${INSTALL}/03-enabled/25-custom.sh"
	activate list
	[ "$status" -eq 0 ]
	[[ "$output" == *"25-custom.sh -> ../available/1000-runtime-base.sh"* ]]
	[[ "$output" == *"10-base.sh"* && "$output" == *"10-hook.sh"* ]]
	local available="${output#*available (}"
	[[ "$available" != *$'\n  1000-runtime-base.sh'* ]]
}

@test "list labels enabled image and companion dependencies without host checks" {
	printf '%s\n' '1020-tool-leaf.sh|image|01-foundation/10-image.sh|absent-command' >>"${INSTALL}/dependencies.conf"
	activate list
	[ "$status" -eq 0 ]
	[[ "$output" == *'1020-tool-leaf.sh — requires: 1010-tool-middle.sh; optional companion: 1030-tool-companion.sh; requires image: 01-foundation/10-image.sh'* ]]
	[[ "$output" != *'.sh (not enabled)'* ]]
}

@test "list keeps broken aliases visible without hiding catalog targets" {
	ln -s ../available/missing.sh "${INSTALL}/03-enabled/99-broken.sh"
	activate list
	[ "$status" -eq 0 ]
	[[ "$output" == *'99-broken.sh -> ../available/missing.sh'* ]]
	[[ "$output" == *$'\n  1000-runtime-base.sh\n'* ]]
}

@test "list works without dependency metadata and reports an exhausted catalog" {
	rm "${INSTALL}/dependencies.conf"
	activate list
	[ "$status" -eq 0 ]
	[[ "$output" != *' — '* ]]
	for path in "${INSTALL}/available/"*.sh; do
		ln -s "../available/${path##*/}" "${INSTALL}/03-enabled/${path##*/}"
	done
	activate list
	[ "$status" -eq 0 ]
	[[ "$output" == *'(no tools available to enable)'* ]]
}

@test "Task list rejects arguments including removed preset flags" {
	for option in --presets --json; do
		run task --exit-code --dir "${FIXTURE}" install:list -- "$option"
		[ "$status" -eq 2 ]
		[[ "$output" == *'ERROR: list accepts no arguments'* ]]
	done
}

@test "Task activation rejects traversal and unknown tools without mutation" {
	for operation in enable disable; do
		for name in ../outside ../02-core-tools/99-base /tmp/unknown; do
			run task --dir "${FIXTURE}" "install:${operation}" -- "$name"
			[ "$status" -ne 0 ]
			[[ "$output" == *'NAME must be a filename, not a path'* ]]
		done
	done
	activate enable unknown
	[ "$status" -ne 0 ]
	[ -z "$(ls -A "${INSTALL}/03-enabled")" ]
}

@test "Task activation is idempotent reuses core and disables by generated name" {
	core_base
	for _ in 1 2; do
		run task --dir "${FIXTURE}" install:enable -- 1020-tool-leaf
		[ "$status" -eq 0 ]
		[ "$(readlink "${INSTALL}/03-enabled/1020-tool-leaf.sh")" = ../available/1020-tool-leaf.sh ]
	done
	run task --dir "${FIXTURE}" install:disable -- 1020-tool-leaf
	[ "$status" -eq 0 ]
	[ ! -L "${INSTALL}/03-enabled/1020-tool-leaf.sh" ]
	run task --dir "${FIXTURE}" install:doctor
	[ "$status" -eq 0 ]
}

@test "Task help exposes desired rather than applied manifest semantics" {
	run task --dir "${FIXTURE}" install:help
	[ "$status" -eq 0 ]
	[[ "$output" == *'validated selected Compose manifest, not applied mounts'* ]]
}

@test "Task versions validation leaves policy unchanged with network commands disabled" {
	cp "${REPO_ROOT}/.devcontainer/tool-versions.conf" "${FIXTURE}/.devcontainer/"
	cp "${REPO_ROOT}/.taskfiles/scripts/deps-update.sh" "${FIXTURE}/.taskfiles/scripts/"
	local before
	before="$(sha256sum "${FIXTURE}/.devcontainer/tool-versions.conf")"
	run env DEPS_UPDATE_CURL=false DEPS_UPDATE_PNPM=false DEPS_UPDATE_JQ=false task --dir "${FIXTURE}" install:versions:validate
	[ "$status" -eq 0 ]
	[ "$(sha256sum "${FIXTURE}/.devcontainer/tool-versions.conf")" = "$before" ]
}
