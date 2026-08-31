#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	[ -d /home/ubuntu/tmp ]
	TEST_ROOT="$(mktemp -d /home/ubuntu/tmp/starter-journey.XXXXXX)"
	SOURCE="${TEST_ROOT}/source"
	BASE_PROJECT="${TEST_ROOT}/base-project"
	PROJECT="${TEST_ROOT}/project"
	export STARTER_CACHE_DIR="${TEST_ROOT}/cache"
	rsync -a --exclude=.git --exclude=.env.d --exclude=.starter/distribution/prepared "${REPO_ROOT}/" "${SOURCE}/"
	git -C "${SOURCE}" init -q -b release
	git -C "${SOURCE}" config user.name Journey
	git -C "${SOURCE}" config user.email journey@example.test
	git -C "${SOURCE}" add -A
	git -C "${SOURCE}" commit -qm fixture
}

teardown() { rm -rf "${TEST_ROOT}"; }

publish_release() {
	local version="$1" predecessor="$2"
	printf '\n# managed-%s\n' "${version}" >>"${SOURCE}/.devcontainer/tool-versions.conf"
	printf '\n# fusion-%s\n' "${version}" >>"${SOURCE}/.devcontainer/docker-compose.yml"
	git -C "${SOURCE}" add -A
	git -C "${SOURCE}" commit -qm "source ${version}"
	task --dir "${SOURCE}" starter:prepare-release -- "${version}" --predecessor "${predecessor}" >/dev/null
	git -C "${SOURCE}" add -A
	git -C "${SOURCE}" commit -qm "prepared ${version}"
	(cd "${SOURCE}" && ./.taskfiles/scripts/starter-release.sh "${version}" >/dev/null)
}

commit_project() {
	git -C "${PROJECT}" add -A
	git -C "${PROJECT}" commit -qm "$1"
}

edit_project_fusion() {
	local marker="$1"
	printf '\n# project-%s\n' "${marker}" >>"${PROJECT}/.devcontainer/docker-compose.yml"
	commit_project "project ${marker}"
}

new_scenario() {
	PROJECT="${TEST_ROOT}/project"
	rm -rf -- "${PROJECT}"
	rsync -a "${BASE_PROJECT}/" "${PROJECT}/"
}

start_conflicting_update() {
	local version="$1"
	run "${PROJECT}/.taskfiles/scripts/starter.sh" update --project-root "${PROJECT}" \
		--source "file://${SOURCE}" --release "starter/v${version}" --yes
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"BLOCKER fusion.pending"* ]]
	[ -f "$(printf '%s\n' "${PROJECT}"/.starter/journals/*/journal.json)" ]
}

resolve_conflict() {
	local flag="$1"
	run "${PROJECT}/.taskfiles/scripts/starter.sh" update --project-root "${PROJECT}" "--${flag}"
	[ "${status}" -eq 0 ]
	[ ! -d "${PROJECT}/.starter/journals" ]
}

@test "public multi-release v2 journey exercises combined managed and F-manual recovery" {
	printf 'journey: release 2.0\n' >&3
	publish_release 2.0.0 0.0.0
	git clone -q --branch starter/v2.0.0 "${SOURCE}" "${BASE_PROJECT}"
	git -C "${BASE_PROJECT}" switch -qc project
	git -C "${BASE_PROJECT}" config user.name Journey
	git -C "${BASE_PROJECT}" config user.email journey@example.test
	run bash -c 'cd "$1" && printf "\n\nCREATE ROOT\n" | ./.taskfiles/scripts/project-init.sh' _ "${BASE_PROJECT}"
	[ "${status}" -eq 0 ]
	[ "$(git -C "${BASE_PROJECT}" rev-list --count HEAD)" -eq 1 ]
	[ "$(git -C "${BASE_PROJECT}" for-each-ref --format='%(refname)' | grep -c '^refs/heads/main$')" -eq 1 ]
	[ -z "$(git -C "${BASE_PROJECT}" tag --list)" ]
	[ ! -e "${BASE_PROJECT}/AGENTS.md" ]
	[ ! -e "${BASE_PROJECT}/AGENTS.md.TEMPLATE.EXAMPLE" ]
	[ "$(sha256sum "${BASE_PROJECT}/AGENTS.md.TEMPLATE" | cut -d' ' -f1)" = \
		"$(sha256sum "${SOURCE}/AGENTS.md.TEMPLATE" | cut -d' ' -f1)" ]
	[ "$(stat -c '%a' "${BASE_PROJECT}/AGENTS.md.TEMPLATE")" = \
		"$(stat -c '%a' "${SOURCE}/AGENTS.md.TEMPLATE")" ]
	[ -n "$(git --git-dir="${BASE_PROJECT}/.starter/evidence/releases/2.0.0/evidence/repository.git" \
		for-each-ref --format='%(refname)' refs/gentle-starter/releases/2.0.0)" ]
	run "${BASE_PROJECT}/.taskfiles/scripts/starter.sh" check --project-root "${BASE_PROJECT}" \
		--source "file://${SOURCE}" --release starter/v2.0.0
	[ "${status}" -eq 0 ]

	publish_release 2.1.0 2.0.0
	new_scenario keep
	printf 'journey: keep\n' >&3
	edit_project_fusion keep
	start_conflicting_update 2.1.0
	resolve_conflict keep-project
	grep -Fq '# project-keep' "${PROJECT}/.devcontainer/docker-compose.yml"
	grep -Fq '# managed-2.1.0' "${PROJECT}/.devcontainer/tool-versions.conf"

	new_scenario manual
	printf 'journey: manual\n' >&3
	edit_project_fusion manual
	start_conflicting_update 2.1.0
	printf '\n# manually-reconciled\n' >>"${PROJECT}/.devcontainer/docker-compose.yml"
	resolve_conflict continue
	grep -Fq '# manually-reconciled' "${PROJECT}/.devcontainer/docker-compose.yml"

	new_scenario crash
	printf 'journey: crash\n' >&3
	edit_project_fusion crash
	start_conflicting_update 2.1.0
	run env STARTER_TRANSACTION_FAILPOINT=after-operation-2 \
		"${PROJECT}/.taskfiles/scripts/starter.sh" update --project-root "${PROJECT}" --take-starter
	[ "${status}" -ne 0 ]
	[ "$(jq -r '.release.version' "${PROJECT}/.starter/state.json")" = 2.0.0 ]
	[ ! -d "${PROJECT}/.starter/journals" ]
	start_conflicting_update 2.1.0
	resolve_conflict take-starter

	new_scenario concurrent
	printf 'journey: concurrent\n' >&3
	edit_project_fusion concurrent
	local managed_before
	managed_before="$(sha256sum "${PROJECT}/.devcontainer/tool-versions.conf" | cut -d' ' -f1)"
	start_conflicting_update 2.1.0
	cat >"${TEST_ROOT}/mutate-operation.sh" <<'EOF'
#!/usr/bin/env bash
[ "$1" -ne 0 ] || { cp -p -- "$2" "${JOURNEY_APPLIED}"; printf '\n# concurrent-human-edit\n' >>"$2"; exit 91; }
EOF
	chmod +x "${TEST_ROOT}/mutate-operation.sh"
	run env JOURNEY_APPLIED="${TEST_ROOT}/applied" STARTER_TRANSACTION_AFTER_OPERATION_HOOK="${TEST_ROOT}/mutate-operation.sh" \
		"${PROJECT}/.taskfiles/scripts/starter.sh" update --project-root "${PROJECT}" --take-starter
	[ "${status}" -ne 0 ]
	grep -Fq '# concurrent-human-edit' "$(jq -r '.operations[0].target' "${PROJECT}"/.starter/journals/*/journal.json | xargs -I{} printf '%s/%s' "${PROJECT}" '{}')"
	cp -p -- "${TEST_ROOT}/applied" "${PROJECT}/$(jq -r '.operations[0].target' "${PROJECT}"/.starter/journals/*/journal.json)"
	resolve_conflict abort
	[ "$(jq -r '.release.version' "${PROJECT}/.starter/state.json")" = 2.0.0 ]
	[ "$(sha256sum "${PROJECT}/.devcontainer/tool-versions.conf" | cut -d' ' -f1)" = "${managed_before}" ]

	new_scenario frozen
	printf 'journey: frozen\n' >&3
	edit_project_fusion frozen
	cat >"${TEST_ROOT}/delete-tag.sh" <<'EOF'
#!/usr/bin/env bash
git -C "${JOURNEY_SOURCE}" tag -d starter/v2.1.0 >/dev/null
EOF
	chmod +x "${TEST_ROOT}/delete-tag.sh"
	run env JOURNEY_SOURCE="${SOURCE}" STARTER_UPDATE_BEFORE_CONFIRM_HOOK="${TEST_ROOT}/delete-tag.sh" \
		"${PROJECT}/.taskfiles/scripts/starter.sh" update --project-root "${PROJECT}" \
		--source "file://${SOURCE}" --release starter/v2.1.0 <<<"y"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"BLOCKER fusion.pending"* ]]
	[ -z "$(git -C "${SOURCE}" tag --list starter/v2.1.0)" ]
	resolve_conflict take-starter
	grep -Fq '# fusion-2.1.0' "${PROJECT}/.devcontainer/docker-compose.yml"
	grep -Fq '# managed-2.1.0' "${PROJECT}/.devcontainer/tool-versions.conf"
	commit_project 'resolve frozen candidate'
	mv "${SOURCE}" "${SOURCE}.offline"
	run "${PROJECT}/.taskfiles/scripts/starter.sh" check --project-root "${PROJECT}" \
		--source "file://${SOURCE}" --release starter/v2.1.0
	[ "${status}" -eq 0 ]
}
