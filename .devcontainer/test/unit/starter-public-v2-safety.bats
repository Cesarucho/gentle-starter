#!/usr/bin/env bats

setup_file() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	SHARED="${BATS_FILE_TMPDIR}/public-v2"
	SOURCE="${SHARED}/source"
	BASE="${SHARED}/base"
	export REPO_ROOT SHARED SOURCE BASE
	mkdir -p "${SHARED}"
	rsync -a --exclude=.git --exclude=.env.d --exclude=.starter/distribution/prepared "${REPO_ROOT}/" "${SOURCE}/"
	git -C "${SOURCE}" init -q -b release
	git -C "${SOURCE}" config user.name Safety
	git -C "${SOURCE}" config user.email safety@example.test
	git -C "${SOURCE}" add -A
	git -C "${SOURCE}" commit -qm fixture
	publish_shared_release 2.0.0 0.0.0
	git clone -q --branch starter/v2.0.0 "${SOURCE}" "${BASE}"
	git -C "${BASE}" switch -qc project
	git -C "${BASE}" config user.name Safety
	git -C "${BASE}" config user.email safety@example.test
	(cd "${BASE}" && printf '\n\nCREATE ROOT\n' | ./.taskfiles/scripts/project-init.sh >/dev/null)
	publish_shared_release 2.1.0 2.0.0
}

publish_shared_release() {
	local version="$1" predecessor="$2"
	printf '\n# managed-%s\n' "${version}" >>"${SOURCE}/.devcontainer/tool-versions.conf"
	git -C "${SOURCE}" add -A
	git -C "${SOURCE}" commit -qm "source ${version}"
	task --dir "${SOURCE}" starter:prepare-release -- "${version}" --predecessor "${predecessor}" >/dev/null
	git -C "${SOURCE}" add -A
	git -C "${SOURCE}" commit -qm "prepared ${version}"
	(cd "${SOURCE}" && ./.taskfiles/scripts/starter-release.sh "${version}" >/dev/null)
}

setup() {
	PROJECT="${BATS_TEST_TMPDIR}/project"
	CACHE="${BATS_TEST_TMPDIR}/cache"
	rsync -a "${BASE}/" "${PROJECT}/"
}

run_starter() {
	local command="$1"
	shift
	run env STARTER_CACHE_DIR="${CACHE}" "${PROJECT}/.taskfiles/scripts/starter.sh" "${command}" \
		--project-root "${PROJECT}" --source "file://${SOURCE}" "$@"
}

snapshot_project() {
	(cd "${PROJECT}" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 sha256sum)
}

@test "v2 adopt creates state last and rejects dirty worktrees without mutation" {
	rm -rf "${PROJECT}/.starter/state.json" "${PROJECT}/.starter/evidence"
	git -C "${PROJECT}" add -A && git -C "${PROJECT}" commit -qm "remove adoption"
	run_starter adopt --release starter/v2.0.0
	[ "${status}" -eq 0 ]
	[ "$(jq -r '.schema' "${PROJECT}/.starter/state.json")" = gentle-starter.state/v2 ]
	git -C "${PROJECT}" add -A && git -C "${PROJECT}" commit -qm adopted
	printf 'dirty\n' >"${PROJECT}/dirty.txt"
	local before="$(snapshot_project)"
	run_starter check --release starter/v2.1.0
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"BLOCKER repository.dirty"* ]]
	[ "$(snapshot_project)" = "${before}" ]
}

@test "v2 check discovers latest release and remains read-only" {
	local before status_before refs_before
	before="$(snapshot_project)"
	status_before="$(git -C "${PROJECT}" status --porcelain=v1)"
	refs_before="$(git -C "${PROJECT}" for-each-ref --format='%(refname) %(objectname)')"
	run_starter check
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"selected latest release 2.1.0"* ]]
	[ "$(snapshot_project)" = "${before}" ]
	[ "$(git -C "${PROJECT}" status --porcelain=v1)" = "${status_before}" ]
	[ "$(git -C "${PROJECT}" for-each-ref --format='%(refname) %(objectname)')" = "${refs_before}" ]
}

@test "v2 update decline and planning failure are read-only" {
	local before
	before="$(snapshot_project)"
	run bash -c 'printf "n\n" | env STARTER_CACHE_DIR="$1" "$2" update --project-root "$3" --source "file://$4" --release starter/v2.1.0' \
		_ "${CACHE}" "${PROJECT}/.taskfiles/scripts/starter.sh" "${PROJECT}" "${SOURCE}"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"update aborted"* ]]
	[ "$(snapshot_project)" = "${before}" ]
	local planner=".taskfiles/scripts/starter-lib/core/planner-v2.sh" planner_sha state_sha
	printf '\nstarter_plan_v2_build() { return 91; }\n' >>"${PROJECT}/${planner}"
	planner_sha="$(sha256sum "${PROJECT}/${planner}" | cut -d' ' -f1)"
	jq --arg path "${planner}" --arg sha "${planner_sha}" \
		'(.managed_fingerprints[]|select(.path==$path)|.sha256)=$sha | del(.integrity)' \
		"${PROJECT}/.starter/state.json" >"${PROJECT}/.starter/state.tmp"
	state_sha="$(jq -cS . "${PROJECT}/.starter/state.tmp" | sha256sum | cut -d' ' -f1)"
	jq --arg sha "${state_sha}" '.integrity={canonicalization:"jq-sorted-utf8-v1",state_sha256:$sha}' \
		"${PROJECT}/.starter/state.tmp" >"${PROJECT}/.starter/state.json"
	rm "${PROJECT}/.starter/state.tmp"
	git -C "${PROJECT}" add "${planner}" .starter/state.json && git -C "${PROJECT}" commit -qm "induce planner failure"
	before="$(snapshot_project)"
	run_starter update --release starter/v2.1.0 --yes
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"BLOCKER plan.invalid"* ]]
	[ "$(snapshot_project)" = "${before}" ]
}

@test "v2 update uses the frozen candidate and persists state only after content" {
	local old_state
	old_state="$(sha256sum "${PROJECT}/.starter/state.json" | cut -d' ' -f1)"
	run env STARTER_CACHE_DIR="${CACHE}" STARTER_TRANSACTION_FAILPOINT=before-state \
		"${PROJECT}/.taskfiles/scripts/starter.sh" update --project-root "${PROJECT}" --source "file://${SOURCE}" \
		--release starter/v2.1.0 --yes
	[ "${status}" -ne 0 ]
	[ "$(sha256sum "${PROJECT}/.starter/state.json" | cut -d' ' -f1)" = "${old_state}" ]
	[ ! -d "${PROJECT}/.starter/journals" ]
	! grep -Fq '# managed-2.1.0' "${PROJECT}/.devcontainer/tool-versions.conf"
	[[ "${output}" == *"CAS-safe recovery was attempted"* ]]
}

@test "v2 frozen candidate survives tag deletion after confirmation" {
	cat >"${BATS_TEST_TMPDIR}/delete-tag.sh" <<'EOF'
#!/usr/bin/env bash
git -C "${SAFETY_SOURCE}" tag -d starter/v2.1.0 >/dev/null
EOF
	chmod +x "${BATS_TEST_TMPDIR}/delete-tag.sh"
	run bash -c 'printf "y\n" | env STARTER_CACHE_DIR="$1" SAFETY_SOURCE="$2" STARTER_UPDATE_BEFORE_CONFIRM_HOOK="$3" \
		"$4" update --project-root "$5" --source "file://$2" --release starter/v2.1.0' _ \
		"${CACHE}" "${SOURCE}" "${BATS_TEST_TMPDIR}/delete-tag.sh" "${PROJECT}/.taskfiles/scripts/starter.sh" "${PROJECT}"
	[ "${status}" -eq 0 ]
	[ "$(jq -r '.release.version' "${PROJECT}/.starter/state.json")" = 2.1.0 ]
}
