#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	PROJECT_ROOT="${TEST_ROOT}/project"
	mkdir -p "${PROJECT_ROOT}"
	seed_project
	LICENSE_SHA256_BEFORE="$(sha256sum "${PROJECT_ROOT}/LICENSE" | awk '{print $1}')"
	LICENSE_MODE_BEFORE="$(stat -c '%a' "${PROJECT_ROOT}/LICENSE")"
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

seed_project() {
	mkdir -p \
		"${PROJECT_ROOT}/.devcontainer/docs" \
		"${PROJECT_ROOT}/.devcontainer/install" \
		"${PROJECT_ROOT}/.taskfiles/scripts" \
		"${PROJECT_ROOT}/docs/en" \
		"${PROJECT_ROOT}/.agents"
	cp "${REPO_ROOT}/.taskfiles/scripts/project-init.sh" \
		"${PROJECT_ROOT}/.taskfiles/scripts/project-init.sh"
	cp "${REPO_ROOT}/.taskfiles/scripts/clean.sh" \
		"${PROJECT_ROOT}/.taskfiles/scripts/clean.sh"
	cp "${REPO_ROOT}/.taskfiles/scripts/clean-lib.sh" \
		"${PROJECT_ROOT}/.taskfiles/scripts/clean-lib.sh"
	chmod +x "${PROJECT_ROOT}/.taskfiles/scripts/"*.sh
	printf '# Starter\n' >"${PROJECT_ROOT}/README.md"
	printf '# Agents\n' >"${PROJECT_ROOT}/AGENTS.md"
	printf '# Template\n<PROJECT_NAME>\n' >"${PROJECT_ROOT}/AGENTS.md.TEMPLATE"
	printf '# Changelog\n' >"${PROJECT_ROOT}/CHANGELOG.md"
	printf 'MIT\n' >"${PROJECT_ROOT}/LICENSE"
	chmod 0640 "${PROJECT_ROOT}/LICENSE"
	printf '# Devcontainer\n../docs/en/extending.md\n' \
		>"${PROJECT_ROOT}/.devcontainer/README.md"
	for doc in extending.md install-tree.md install-volumes.md configs.md; do
		printf '# %s\n' "${doc}" >"${PROJECT_ROOT}/docs/en/${doc}"
	done
	printf 'APP_NAME=starter\n' >"${PROJECT_ROOT}/.env.example"
	printf '.env.d/\n' >"${PROJECT_ROOT}/.gitignore"
	printf 'version: "3"\n' >"${PROJECT_ROOT}/Taskfile.yml"
	printf 'skill\n' >"${PROJECT_ROOT}/skills-lock.json"
	git -C "${PROJECT_ROOT}" init -q -b starter
	git -C "${PROJECT_ROOT}" config user.name "Project Init Test"
	git -C "${PROJECT_ROOT}" config user.email "project-init@example.test"
	git -C "${PROJECT_ROOT}" add -A
	git -C "${PROJECT_ROOT}" commit -qm "starter history"
}

seed_starter_update_machinery() {
	mkdir -p "${PROJECT_ROOT}/.starter"
	cp "${REPO_ROOT}/.starter/source.json" "${PROJECT_ROOT}/.starter/source.json"
	cp -R "${REPO_ROOT}/.starter/distribution" "${PROJECT_ROOT}/.starter/distribution"
	jq -n '{schema:"gentle-starter.ownership-inventory/v2",default_ownership:"project-owned",managed:[
		{match:"exact",path:".starter/baseline.json"},{match:"exact",path:".starter/distribution/ownership.json"},
		{match:"exact",path:".starter/source.json"},{match:"exact",path:".taskfiles/starter.yml"},
		{match:"exact",path:".taskfiles/scripts/starter.sh"}],fusion:[
		{match:"exact",path:".devcontainer/devcontainer.json",contract:"F-manual/v1"},
		{match:"exact",path:".devcontainer/docker-compose.yml",contract:"F-manual/v1"}]}' \
		>"${PROJECT_ROOT}/.starter/distribution/ownership.json"
	cp "${REPO_ROOT}/.starter/baseline.json" "${PROJECT_ROOT}/.starter/baseline.json"
	cp -R "${REPO_ROOT}/.taskfiles/scripts/starter-lib" \
		"${PROJECT_ROOT}/.taskfiles/scripts/starter-lib"
	cp "${REPO_ROOT}/.taskfiles/scripts/starter.sh" \
		"${PROJECT_ROOT}/.taskfiles/scripts/starter.sh"
	cp "${REPO_ROOT}/.taskfiles/scripts/starter-prepare-release.sh" \
		"${PROJECT_ROOT}/.taskfiles/scripts/starter-prepare-release.sh"
	cp "${REPO_ROOT}/.taskfiles/starter.yml" "${PROJECT_ROOT}/.taskfiles/starter.yml"
	chmod +x "${PROJECT_ROOT}/.taskfiles/scripts/starter.sh"
	chmod +x "${PROJECT_ROOT}/.taskfiles/scripts/starter-prepare-release.sh"
	printf '{"name":"fixture"}\n' >"${PROJECT_ROOT}/.devcontainer/devcontainer.json"
	printf 'services: {}\n' >"${PROJECT_ROOT}/.devcontainer/docker-compose.yml"
	(cd "${PROJECT_ROOT}" && ./.taskfiles/scripts/starter-prepare-release.sh 1.0.0 >/dev/null)
	cat >"${PROJECT_ROOT}/Taskfile.yml" <<'EOF'
version: "3"

includes:
  starter:
    taskfile: ./.taskfiles/starter.yml
EOF
}

tag_current_release() {
	local version="${1:-1.0.0}" commit tree blob sha message
	commit="$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"
	tree="$(git -C "${PROJECT_ROOT}" rev-parse 'HEAD^{tree}')"
	blob="$(git -C "${PROJECT_ROOT}" rev-parse "HEAD:.starter/distribution/prepared/${version}/manifest.json")"
	sha="$(git -C "${PROJECT_ROOT}" show "HEAD:.starter/distribution/prepared/${version}/manifest.json" | sha256sum | cut -d' ' -f1)"
	message="$(jq -cn --arg version "${version}" --arg commit "${commit}" --arg tree "${tree}" --arg blob "${blob}" --arg sha "${sha}" '{schema:"gentle-starter.git-tag/v1",source_id:"gentle-starter",version:$version,commit_oid:$commit,tree_oid:$tree,manifest:{path:(".starter/distribution/prepared/"+$version+"/manifest.json"),blob_oid:$blob,sha256:$sha}}')"
	git -C "${PROJECT_ROOT}" tag -a -m "${message}" "starter/v${version}"
}

run_project_init() {
	local input="$1"
	shift
	if [ "${1:-}" = __auto__ ]; then
		shift
		set --
	elif [ "$#" -eq 0 ]; then
		set -- --no-starter-adopt
	fi
	run bash -c 'cd "$1" && shift && input="$1" && shift && printf "%b" "${input}" | ./.taskfiles/scripts/project-init.sh "$@"' \
		_ "${PROJECT_ROOT}" "${input}" "$@"
}

assert_parentless_root() {
	local description
	description="$(git -C "${PROJECT_ROOT}" rev-list --parents -n 1 HEAD)"
	[ "$(wc -w <<<"${description}")" -eq 1 ]
	[ "$(git -C "${PROJECT_ROOT}" rev-list --count HEAD)" -eq 1 ]
	[ "$(git -C "${PROJECT_ROOT}" log -1 --format=%s)" = "chore: initialize project" ]
}

assert_starter_identity_cleaned() {
	[ ! -e "${PROJECT_ROOT}/README.md" ]
	[ ! -e "${PROJECT_ROOT}/docs" ]
	[ -f "${PROJECT_ROOT}/LICENSE" ]
	[ "$(sha256sum "${PROJECT_ROOT}/LICENSE" | awk '{print $1}')" = "${LICENSE_SHA256_BEFORE}" ]
	[ "$(stat -c '%a' "${PROJECT_ROOT}/LICENSE")" = "${LICENSE_MODE_BEFORE}" ]
	[ ! -e "${PROJECT_ROOT}/CHANGELOG.md" ]
	[ -f "${PROJECT_ROOT}/AGENTS.md" ]
	grep -Fq '<PROJECT_NAME>' "${PROJECT_ROOT}/AGENTS.md"
	[ -f "${PROJECT_ROOT}/.devcontainer/docs/extending.md" ]
	grep -Fq './docs/extending.md' "${PROJECT_ROOT}/.devcontainer/README.md"
}

assert_only_root_ref_remains() {
	local expected_ref="refs/heads/$1"
	[ "$(git -C "${PROJECT_ROOT}" for-each-ref --format='%(refname)')" = "${expected_ref}" ]
}

@test "automatic adoption detects an exact release at HEAD and includes state and evidence in the root" {
	seed_starter_update_machinery
	git -C "${PROJECT_ROOT}" add -A
	git -C "${PROJECT_ROOT}" commit -qm "release fixture"
	tag_current_release

	run_project_init 'project-main\n\nCREATE ROOT\n' __auto__

	[ "${status}" -eq 0 ] || {
		printf '%s\n' "${output}" >&3
		false
	}
	assert_parentless_root
	assert_only_root_ref_remains project-main
	[ "$(jq -r '.release.version' "${PROJECT_ROOT}/.starter/state.json")" = 1.0.0 ]
	[ -f "${PROJECT_ROOT}/.starter/baseline.json" ]
	[ -f "${PROJECT_ROOT}/.starter/evidence/releases/1.0.0/evidence/index.json" ]
	[ "$(git -C "${PROJECT_ROOT}" remote get-url gentle-starter)" = "$(jq -r '.url' "${PROJECT_ROOT}/.starter/source.json")" ]
	git -C "${PROJECT_ROOT}" show --stat --oneline HEAD >/dev/null
	[ -z "$(git -C "${PROJECT_ROOT}" status --porcelain)" ]
	[[ "${output}" == *"Starter release starter/v1.0.0 was admitted"* ]]
}

@test "explicit release succeeds and ambiguous automatic detection fails before mutation" {
	seed_starter_update_machinery
	git -C "${PROJECT_ROOT}" add -A
	git -C "${PROJECT_ROOT}" commit -qm "release fixture"
	tag_current_release
	git -C "${PROJECT_ROOT}" tag starter/v9.9.9
	local before
	before="$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"

	run_project_init 'project-main\n\nCREATE ROOT\n' __auto__
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"multiple starter releases identify HEAD"* ]]
	[ "$(git -C "${PROJECT_ROOT}" rev-parse HEAD)" = "${before}" ]
	[ -f "${PROJECT_ROOT}/README.md" ]

	git -C "${PROJECT_ROOT}" tag -d starter/v9.9.9 >/dev/null
	run_project_init 'project-main\n\nCREATE ROOT\n' --release starter/v1.0.0
	[ "${status}" -eq 0 ]
	[ "$(jq -r '.release.version' "${PROJECT_ROOT}/.starter/state.json")" = 1.0.0 ]
}

@test "missing release identity fails before destructive mutation with explicit guidance" {
	seed_starter_update_machinery
	git -C "${PROJECT_ROOT}" add -A
	git -C "${PROJECT_ROOT}" commit -qm "untagged fixture"
	local before
	before="$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"

	run_project_init 'project-main\n\nCREATE ROOT\n' __auto__

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"--release starter/vX.Y.Z"* ]]
	[ "$(git -C "${PROJECT_ROOT}" rev-parse HEAD)" = "${before}" ]
	[ -f "${PROJECT_ROOT}/README.md" ]
}

@test "happy path creates one parentless root commit and preserves blank origin" {
	git -C "${PROJECT_ROOT}" remote add origin https://example.test/starter.git

	run_project_init 'fresh-main\n\nCREATE ROOT\n'

	[ "${status}" -eq 0 ]
	[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = "fresh-main" ]
	[ "$(git -C "${PROJECT_ROOT}" remote get-url origin)" = \
		"https://example.test/starter.git" ]
	[ -z "$(git -C "${PROJECT_ROOT}" status --porcelain)" ]
	[ -z "$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)" ]
	assert_parentless_root
	assert_starter_identity_cleaned
	[[ "${output}" == *"No remote was pushed or reconfigured"* ]]
	[[ "${output}" != *"https://example.test/starter.git"* ]]
}

@test "initialization removes unadmitted inherited markers while retaining updater machinery" {
	seed_starter_update_machinery
	mkdir -p \
		"${PROJECT_ROOT}/.starter/evidence/releases/1.0.0" \
		"${PROJECT_ROOT}/.starter/journals/interrupted"
	printf '%s\n' '{"schema":"unadmitted-template-state"}' >"${PROJECT_ROOT}/.starter/state.json"
	printf '%s\n' '{"schema":"unadmitted-template-baseline"}' >"${PROJECT_ROOT}/.starter/baseline.json"
	printf 'unadmitted evidence\n' >"${PROJECT_ROOT}/.starter/evidence/releases/1.0.0/proof"
	printf '%s\n' '{"schema":"unadmitted-template-journal"}' \
		>"${PROJECT_ROOT}/.starter/journals/interrupted/journal.json"
	git -C "${PROJECT_ROOT}" add -A
	git -C "${PROJECT_ROOT}" commit -qm "seed updater with unverified markers"
	git -C "${PROJECT_ROOT}" remote add origin https://example.test/starter.git

	run_project_init 'fresh-main\n\nCREATE ROOT\n'

	[ "${status}" -eq 0 ]
	assert_parentless_root
	assert_starter_identity_cleaned
	[ ! -e "${PROJECT_ROOT}/.starter/distribution/manifest.json" ]
	[ ! -e "${PROJECT_ROOT}/.starter/distribution/migrations" ]
	[ ! -e "${PROJECT_ROOT}/.starter/distribution/payloads" ]
	[ ! -e "${PROJECT_ROOT}/.taskfiles/scripts/starter-release.sh" ]
	[ -f "${PROJECT_ROOT}/.taskfiles/scripts/starter.sh" ]
	[ -f "${PROJECT_ROOT}/.taskfiles/starter.yml" ]
	! task --dir "${PROJECT_ROOT}" --list | grep -Fq 'starter:release'
	[ ! -e "${PROJECT_ROOT}/.starter/state.json" ]
	[ ! -e "${PROJECT_ROOT}/.starter/baseline.json" ]
	[ ! -e "${PROJECT_ROOT}/.starter/evidence" ]
	[ ! -e "${PROJECT_ROOT}/.starter/journals" ]
	[ "$(git -C "${PROJECT_ROOT}" remote get-url origin)" = \
		"https://example.test/starter.git" ]
	[ -z "$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)" ]
	[[ "${output}" == *"intentionally unmarked"* ]]
	[[ "${output}" == *"No remote was pushed or reconfigured"* ]]
	run task --dir "${PROJECT_ROOT}" --list
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"starter:adopt"* ]]
}

@test "marker-free initialization remains unmarked and directs explicit adoption" {
	seed_starter_update_machinery
	git -C "${PROJECT_ROOT}" add -A
	git -C "${PROJECT_ROOT}" commit -qm "seed updater machinery"
	local new_origin="https://new.example.test/org/project.git"

	run_project_init "project-main\n${new_origin}\nCREATE ROOT\n"

	[ "${status}" -eq 0 ]
	assert_parentless_root
	assert_starter_identity_cleaned
	[ ! -e "${PROJECT_ROOT}/.starter/state.json" ]
	[ ! -e "${PROJECT_ROOT}/.starter/baseline.json" ]
	[ ! -e "${PROJECT_ROOT}/.starter/evidence" ]
	[ ! -e "${PROJECT_ROOT}/.starter/journals" ]
	[ "$(git -C "${PROJECT_ROOT}" remote get-url origin)" = "${new_origin}" ]
	[ -z "$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)" ]
	[ -z "$(git -C "${PROJECT_ROOT}" status --porcelain)" ]
	[[ "${output}" == *"intentionally unmarked"* ]]
	[[ "${output}" == *"No remote was pushed or reconfigured"* ]]
}

@test "successful initialization removes every ref that keeps starter history reachable" {
	git -C "${PROJECT_ROOT}" branch legacy-two
	git -C "${PROJECT_ROOT}" tag starter-v1
	git -C "${PROJECT_ROOT}" update-ref refs/remotes/origin/starter HEAD
	git -C "${PROJECT_ROOT}" update-ref refs/notes/review HEAD
	git -C "${PROJECT_ROOT}" update-ref refs/stash HEAD

	run_project_init 'fresh-main\n\nCREATE ROOT\n'

	[ "${status}" -eq 0 ]
	assert_parentless_root
	assert_only_root_ref_remains fresh-main
	[[ "${output}" == *"Previous local refs removed"* ]]
}

@test "linked worktrees are rejected before prompting or deleting shared refs" {
	local linked_root="${TEST_ROOT}/linked-worktree"
	git -C "${PROJECT_ROOT}" worktree add -q -b linked-old "${linked_root}"
	local before_refs before_main_head before_linked_head
	before_refs="$(git -C "${PROJECT_ROOT}" for-each-ref --format='%(objectname) %(refname)')"
	before_main_head="$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"
	before_linked_head="$(git -C "${linked_root}" rev-parse HEAD)"

	run_project_init 'fresh-main\n\nCREATE ROOT\n'

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"linked worktree"* ]]
	[ "$(git -C "${PROJECT_ROOT}" for-each-ref --format='%(objectname) %(refname)')" = "${before_refs}" ]
	[ "$(git -C "${PROJECT_ROOT}" rev-parse HEAD)" = "${before_main_head}" ]
	[ "$(git -C "${linked_root}" rev-parse HEAD)" = "${before_linked_head}" ]
	[ -f "${PROJECT_ROOT}/README.md" ]
}

@test "stale target branch config cannot attach an upstream to the new root" {
	git -C "${PROJECT_ROOT}" remote add origin https://example.test/starter.git
	git -C "${PROJECT_ROOT}" update-ref refs/remotes/origin/stale-main HEAD
	git -C "${PROJECT_ROOT}" config branch.stale-main.remote origin
	git -C "${PROJECT_ROOT}" config branch.stale-main.merge refs/heads/stale-main

	run_project_init 'stale-main\n\nCREATE ROOT\n'

	[ "${status}" -eq 0 ]
	[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = "stale-main" ]
	[ -z "$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)" ]
	[ -z "$(git -C "${PROJECT_ROOT}" config --get branch.stale-main.remote || true)" ]
	[ -z "$(git -C "${PROJECT_ROOT}" config --get branch.stale-main.merge || true)" ]
	assert_parentless_root
}

@test "blank branch input defaults to main when main does not exist" {
	run_project_init '\n\nCREATE ROOT\n'

	[ "${status}" -eq 0 ]
	[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = "main" ]
	assert_parentless_root
}

@test "supplied origin fully replaces existing fetch and push endpoints without contact" {
	git -C "${PROJECT_ROOT}" remote add origin https://example.test/old.git
	git -C "${PROJECT_ROOT}" config --add remote.origin.url https://example.test/old-secondary.git
	git -C "${PROJECT_ROOT}" config --add remote.origin.pushurl ssh://git@example.test/old-push.git
	git -C "${PROJECT_ROOT}" config --add remote.origin.pushurl git@example.test:old-push-two.git
	local new_origin="https://new.example.test/org/project.git"

	run_project_init "fresh-main\n${new_origin}\nCREATE ROOT\n"

	[ "${status}" -eq 0 ]
	[ "$(git -C "${PROJECT_ROOT}" config --get-all remote.origin.url)" = "${new_origin}" ]
	[ "$(git -C "${PROJECT_ROOT}" config --get-all remote.origin.pushurl)" = "${new_origin}" ]
	[ "$(git -C "${PROJECT_ROOT}" remote get-url --push origin)" = "${new_origin}" ]
	[[ "${output}" == *"origin updated"* ]]
	[[ "${output}" != *"${new_origin}"* ]]
}

@test "supplied origin is added when origin is absent" {
	local new_origin="ssh://git@new.example.test/org/project.git"

	run_project_init "fresh-main\n${new_origin}\nCREATE ROOT\n"

	[ "${status}" -eq 0 ]
	[ "$(git -C "${PROJECT_ROOT}" remote get-url origin)" = "${new_origin}" ]
	[ "$(git -C "${PROJECT_ROOT}" remote get-url --push origin)" = "${new_origin}" ]
	[[ "${output}" == *"origin added"* ]]
}

@test "supplied origin rejects inherited push URLs before confirmation" {
	local isolated_global="${TEST_ROOT}/global.gitconfig"
	local inherited_push="ssh://git@old.example.test/inherited.git"
	git -C "${PROJECT_ROOT}" remote add origin https://example.test/old.git
	git config --file "${isolated_global}" remote.origin.pushurl "${inherited_push}"

	run bash -c 'cd "$1" && printf "%b" "$2" | env GIT_CONFIG_GLOBAL="$3" GIT_CONFIG_NOSYSTEM=1 ./.taskfiles/scripts/project-init.sh --no-starter-adopt' \
		_ "${PROJECT_ROOT}" 'fresh-main\nhttps://new.example.test/repo.git\nCREATE ROOT\n' "${isolated_global}" --no-starter-adopt

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"inherited origin push URL"* ]]
	[[ "${output}" != *"${inherited_push}"* ]]
	[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = starter ]
	[ -f "${PROJECT_ROOT}/README.md" ]
}

@test "cancellation wrong phrase and EOF do not mutate the repository" {
	local initial_head
	initial_head="$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"
	local input
	for input in 'fresh-main\n\nNO\n' 'fresh-main\n\n' ''; do
		run_project_init "${input}"
		[ "${status}" -eq 0 ]
		[ "$(git -C "${PROJECT_ROOT}" rev-parse HEAD)" = "${initial_head}" ]
		[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = "starter" ]
		[ -f "${PROJECT_ROOT}/README.md" ]
		[ -z "$(git -C "${PROJECT_ROOT}" status --porcelain)" ]
	done
}

@test "invalid and existing branch names fail before cleanup" {
	git -C "${PROJECT_ROOT}" branch existing
	local branch
	for branch in '@' '-option' 'has space' 'foo..bar' 'existing'; do
		run_project_init "${branch}\n\nCREATE ROOT\n"
		[ "${status}" -ne 0 ]
		[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = "starter" ]
		[ -f "${PROJECT_ROOT}/README.md" ]
		[ -z "$(git -C "${PROJECT_ROOT}" status --porcelain)" ]
	done
}

@test "dirty staged unstaged and untracked repositories fail before prompting" {
	local mode
	for mode in staged unstaged untracked; do
		git -C "${PROJECT_ROOT}" reset --hard -q HEAD
		git -C "${PROJECT_ROOT}" clean -fdq
		case "${mode}" in
		staged)
			printf 'change\n' >>"${PROJECT_ROOT}/README.md"
			git -C "${PROJECT_ROOT}" add README.md
			;;
		unstaged)
			printf 'change\n' >>"${PROJECT_ROOT}/README.md"
			;;
		untracked)
			printf 'change\n' >"${PROJECT_ROOT}/untracked.txt"
			;;
		esac
		run_project_init 'fresh-main\n\nCREATE ROOT\n'
		[ "${status}" -ne 0 ]
		[[ "${output}" == *"working tree must be clean"* ]]
		[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = "starter" ]
	done
}

@test "missing Git identity fails before cleanup" {
	git -C "${PROJECT_ROOT}" config --unset user.name
	git -C "${PROJECT_ROOT}" config --unset user.email

	local isolated_home="${TEST_ROOT}/empty-home"
	mkdir -p "${isolated_home}"
	run bash -c 'cd "$1" && printf "%b" "$2" | env HOME="$3" GIT_CONFIG_NOSYSTEM=1 ./.taskfiles/scripts/project-init.sh' \
		_ "${PROJECT_ROOT}" 'fresh-main\n\nCREATE ROOT\n' "${isolated_home}"

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"Git author and committer identity"* ]]
	[ -f "${PROJECT_ROOT}/README.md" ]
	[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = "starter" ]
}

@test "unsafe origin inputs fail without leaking credentials" {
	local secret='super-secret-token'
	local unsafe
	for unsafe in \
		"https://${secret}@example.test/repo.git" \
		"https://user:${secret}@example.test/repo.git" \
		"user:${secret}@example.test:repo.git" \
		"https://example.test/repo.git?access_token=${secret}" \
		"https://example.test/${secret}/repo.git" \
		'https://example.test/repo.git#credential' \
		'ext::id>/tmp/project-init-pwned' \
		'file:///tmp/repo.git' \
		'origin with spaces' \
		$'origin\twith-tab' \
		'-upload-pack=evil'; do
		run_project_init "fresh-main\n${unsafe}\nCREATE ROOT\n"
		[ "${status}" -ne 0 ]
		[[ "${output}" != *"${secret}"* ]]
		[ -f "${PROJECT_ROOT}/README.md" ]
		[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = "starter" ]
	done
}

@test "normal HTTPS SSH and SCP-like origins pass validation without mutation" {
	local safe_origin
	for safe_origin in \
		'https://example.test/org/repo.git' \
		'ssh://example.test/org/repo.git' \
		'git@example.test:org/repo.git'; do
		run_project_init "fresh-main\n${safe_origin}\nCANCEL\n"
		[ "${status}" -eq 0 ]
		[[ "${output}" == *"Aborted. No changes were made."* ]]
		[ -f "${PROJECT_ROOT}/README.md" ]
		[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = "starter" ]
	done
}

@test "migration rejects source and destination symlinks before project mutation" {
	local external_source="${TEST_ROOT}/external-source.md"
	printf 'EXTERNAL SECRET\n' >"${external_source}"
	rm "${PROJECT_ROOT}/docs/en/extending.md"
	ln -s "${external_source}" "${PROJECT_ROOT}/docs/en/extending.md"
	git -C "${PROJECT_ROOT}" add -A
	git -C "${PROJECT_ROOT}" commit -qm "tracked source symlink"

	run_project_init 'fresh-main\n\nCREATE ROOT\n'

	[ "${status}" -ne 0 ]
	[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = "starter" ]
	[ -f "${PROJECT_ROOT}/README.md" ]
	[ ! -e "${PROJECT_ROOT}/.devcontainer/docs/extending.md" ] ||
		! grep -Fq 'EXTERNAL SECRET' "${PROJECT_ROOT}/.devcontainer/docs/extending.md"

	git -C "${PROJECT_ROOT}" reset --hard -q HEAD~1
	git -C "${PROJECT_ROOT}" clean -fdq
	rm -rf "${PROJECT_ROOT}/.devcontainer/docs"
	ln -s "${TEST_ROOT}/outside-target" "${PROJECT_ROOT}/.devcontainer/docs"
	git -C "${PROJECT_ROOT}" add -A
	git -C "${PROJECT_ROOT}" commit -qm "tracked destination symlink"

	run_project_init 'fresh-main\n\nCREATE ROOT\n'

	[ "${status}" -ne 0 ]
	[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = "starter" ]
	[ -f "${PROJECT_ROOT}/README.md" ]
	[ ! -e "${TEST_ROOT}/outside-target" ]
}

@test "post-confirmation failures and TERM restore worktree index HEAD refs and config" {
	local real_git
	real_git="$(command -v git)"
	local wrapper_dir="${TEST_ROOT}/failure-bin"
	mkdir -p "${wrapper_dir}"
	cat >"${wrapper_dir}/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
args="$*"
if [ ! -e "${PROJECT_INIT_FAILURE_MARKER}" ] && [[ "${args}" == *"${PROJECT_INIT_FAIL_MATCH}"* ]]; then
	touch "${PROJECT_INIT_FAILURE_MARKER}"
	if [ "${PROJECT_INIT_FAIL_MODE}" = signal ]; then
		kill -TERM "${PPID}"
		sleep 1
	fi
	exit 86
fi
exec "${PROJECT_INIT_REAL_GIT}" "$@"
EOF
	chmod +x "${wrapper_dir}/git"
	printf 'docs/ignored-rollback-state.bin\n' >>"${PROJECT_ROOT}/.git/info/exclude"
	printf 'IGNORED STATE MUST SURVIVE\n' >"${PROJECT_ROOT}/docs/ignored-rollback-state.bin"

	local fail_spec
	for fail_spec in \
		'add -A|exit' \
		'write-tree|exit' \
		'commit-tree|exit' \
		'update-ref refs/heads/fresh-main|exit' \
		'--unset-all branch.fresh-main.remote|exit' \
		'symbolic-ref HEAD|exit' \
		'--remove-section remote.origin|exit' \
		'--add remote.origin.url|exit' \
		'write-tree|signal'; do
		git -C "${PROJECT_ROOT}" reset --hard -q HEAD
		git -C "${PROJECT_ROOT}" clean -fdq
		git -C "${PROJECT_ROOT}" remote remove origin 2>/dev/null || true
		git -C "${PROJECT_ROOT}" remote add origin https://example.test/old.git
		git -C "${PROJECT_ROOT}" update-ref -d refs/heads/fresh-main
		git -C "${PROJECT_ROOT}" config branch.fresh-main.remote origin
		git -C "${PROJECT_ROOT}" config branch.fresh-main.merge refs/heads/fresh-main
		local before_head before_status before_config before_index
		before_head="$(cat "${PROJECT_ROOT}/.git/HEAD")"
		before_status="$(git -C "${PROJECT_ROOT}" status --porcelain=v1 --untracked-files=all)"
		before_config="$(sha256sum "${PROJECT_ROOT}/.git/config" | cut -d' ' -f1)"
		before_index="$(sha256sum "${PROJECT_ROOT}/.git/index" | cut -d' ' -f1)"
		local match="${fail_spec%%|*}"
		local mode="${fail_spec##*|}"
		local marker="${TEST_ROOT}/failure-${match//[^A-Za-z0-9]/-}-${mode}"

		run bash -c 'cd "$1" && printf "%b" "$2" | env PATH="$3:$PATH" PROJECT_INIT_REAL_GIT="$4" PROJECT_INIT_FAIL_MATCH="$5" PROJECT_INIT_FAIL_MODE="$6" PROJECT_INIT_FAILURE_MARKER="$7" ./.taskfiles/scripts/project-init.sh --no-starter-adopt' \
			_ "${PROJECT_ROOT}" "fresh-main\nhttps://new.example.test/repo.git\nCREATE ROOT\n" \
			"${wrapper_dir}" "${real_git}" "${match}" "${mode}" "${marker}" --no-starter-adopt

		[ "${status}" -ne 0 ]
		[ "$(cat "${PROJECT_ROOT}/.git/HEAD")" = "${before_head}" ]
		[ "$(sha256sum "${PROJECT_ROOT}/.git/config" | cut -d' ' -f1)" = "${before_config}" ]
		local after_index
		after_index="$(sha256sum "${PROJECT_ROOT}/.git/index" | cut -d' ' -f1)"
		[ "${after_index}" = "${before_index}" ]
		[ "$(GIT_OPTIONAL_LOCKS=0 git -C "${PROJECT_ROOT}" status --porcelain=v1 --untracked-files=all)" = "${before_status}" ]
		[ -z "$(git -C "${PROJECT_ROOT}" show-ref --verify --hash refs/heads/fresh-main 2>/dev/null || true)" ]
		[ -f "${PROJECT_ROOT}/README.md" ]
		[ "$(cat "${PROJECT_ROOT}/docs/ignored-rollback-state.bin")" = "IGNORED STATE MUST SURVIVE" ]
	done
}

@test "signals before and after config and index replacement restore exact originals" {
	local real_mv wrapper_dir
	real_mv="$(command -v mv)"
	wrapper_dir="${TEST_ROOT}/mv-signal-bin"
	mkdir -p "${wrapper_dir}"
	cat >"${wrapper_dir}/mv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == *"${PROJECT_INIT_MV_MATCH}"* ]] && [ ! -e "${PROJECT_INIT_MV_MARKER}" ]; then
	touch "${PROJECT_INIT_MV_MARKER}"
	if [ "${PROJECT_INIT_MV_MODE}" = before ]; then
		kill -TERM "${PPID}"
		sleep 1
		exit 86
	fi
	"${PROJECT_INIT_REAL_MV}" "$@"
	kill -TERM "${PPID}"
	sleep 1
	exit 86
fi
exec "${PROJECT_INIT_REAL_MV}" "$@"
EOF
	chmod +x "${wrapper_dir}/mv"

	local replacement mode
	for replacement in config.next index.next; do
		for mode in before after; do
			git -C "${PROJECT_ROOT}" reset --hard -q HEAD
			git -C "${PROJECT_ROOT}" clean -fdq
			git -C "${PROJECT_ROOT}" update-ref -d refs/heads/fresh-main
			local before_head before_config before_index marker
			before_head="$(cat "${PROJECT_ROOT}/.git/HEAD")"
			before_config="$(sha256sum "${PROJECT_ROOT}/.git/config" | cut -d' ' -f1)"
			before_index="$(sha256sum "${PROJECT_ROOT}/.git/index" | cut -d' ' -f1)"
			marker="${TEST_ROOT}/${replacement}-${mode}.marker"

			run bash -c 'cd "$1" && printf "%b" "$2" | env PATH="$3:$PATH" PROJECT_INIT_REAL_MV="$4" PROJECT_INIT_MV_MATCH="$5" PROJECT_INIT_MV_MODE="$6" PROJECT_INIT_MV_MARKER="$7" ./.taskfiles/scripts/project-init.sh --no-starter-adopt' \
				_ "${PROJECT_ROOT}" 'fresh-main\nhttps://new.example.test/repo.git\nCREATE ROOT\n' \
				"${wrapper_dir}" "${real_mv}" "${replacement}" "${mode}" "${marker}" --no-starter-adopt

			[ "${status}" -ne 0 ]
			[ "$(cat "${PROJECT_ROOT}/.git/HEAD")" = "${before_head}" ]
			[ "$(sha256sum "${PROJECT_ROOT}/.git/config" | cut -d' ' -f1)" = "${before_config}" ]
			[ "$(sha256sum "${PROJECT_ROOT}/.git/index" | cut -d' ' -f1)" = "${before_index}" ]
			[ -f "${PROJECT_ROOT}/README.md" ]
		done
	done
}

@test "rollback preserves unrelated concurrent tracked and untracked work" {
	local real_git wrapper_dir marker before_index
	real_git="$(command -v git)"
	wrapper_dir="${TEST_ROOT}/concurrent-bin"
	marker="${TEST_ROOT}/concurrent-marker"
	before_index="$(sha256sum "${PROJECT_ROOT}/.git/index" | cut -d' ' -f1)"
	mkdir -p "${wrapper_dir}"
	cat >"${wrapper_dir}/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ ! -e "${PROJECT_INIT_FAILURE_MARKER}" ] && [[ "$*" == *"write-tree"* ]]; then
	touch "${PROJECT_INIT_FAILURE_MARKER}"
	printf 'CONCURRENT TRACKED EDIT\n' >>.env.example
	printf 'CONCURRENT UNTRACKED FILE\n' >concurrent.txt
	exit 86
fi
exec "${PROJECT_INIT_REAL_GIT}" "$@"
EOF
	chmod +x "${wrapper_dir}/git"

	run bash -c 'cd "$1" && printf "%b" "$2" | env PATH="$3:$PATH" PROJECT_INIT_REAL_GIT="$4" PROJECT_INIT_FAILURE_MARKER="$5" ./.taskfiles/scripts/project-init.sh --no-starter-adopt' \
		_ "${PROJECT_ROOT}" 'fresh-main\n\nCREATE ROOT\n' "${wrapper_dir}" "${real_git}" "${marker}" --no-starter-adopt

	[ "${status}" -ne 0 ]
	grep -Fq 'CONCURRENT TRACKED EDIT' "${PROJECT_ROOT}/.env.example"
	[ "$(cat "${PROJECT_ROOT}/concurrent.txt")" = "CONCURRENT UNTRACKED FILE" ]
	[ "$(sha256sum "${PROJECT_ROOT}/.git/index" | cut -d' ' -f1)" = "${before_index}" ]
	[ -f "${PROJECT_ROOT}/README.md" ]
	[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = starter ]
}

@test "rollback reports incomplete recovery and retains artifacts when restoration fails" {
	local real_git wrapper_dir marker
	real_git="$(command -v git)"
	wrapper_dir="${TEST_ROOT}/rollback-failure-bin"
	marker="${TEST_ROOT}/rollback-failure-marker"
	mkdir -p "${wrapper_dir}"
	cat >"${wrapper_dir}/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ ! -e "${PROJECT_INIT_FAILURE_MARKER}" ] && [[ "$*" == *"write-tree"* ]]; then
	touch "${PROJECT_INIT_FAILURE_MARKER}"
	exit 86
fi
exec "${PROJECT_INIT_REAL_GIT}" "$@"
EOF
	cat >"${wrapper_dir}/tar" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == *"-xpf"* ]]; then
	exit 87
fi
exec /usr/bin/tar "$@"
EOF
	chmod +x "${wrapper_dir}/git" "${wrapper_dir}/tar"

	run bash -c 'cd "$1" && printf "%b" "$2" | env TMPDIR="$3" PATH="$4:$PATH" PROJECT_INIT_REAL_GIT="$5" PROJECT_INIT_FAILURE_MARKER="$6" ./.taskfiles/scripts/project-init.sh --no-starter-adopt' \
		_ "${PROJECT_ROOT}" 'fresh-main\n\nCREATE ROOT\n' "${TEST_ROOT}" "${wrapper_dir}" "${real_git}" "${marker}" --no-starter-adopt

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"recovery incomplete"* ]]
	[[ "${output}" != *"original worktree, index, HEAD, refs, and Git config restored"* ]]
	compgen -G "${TEST_ROOT}/project-init-rollback.*" >/dev/null
}

@test "standalone clean keeps its existing confirmation and migration behavior" {
	run bash -c 'cd "$1" && printf "y\n" | ./.taskfiles/scripts/clean.sh identity' \
		_ "${PROJECT_ROOT}"

	[ "${status}" -eq 0 ]
	[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = "starter" ]
	[ "$(git -C "${PROJECT_ROOT}" rev-list --count HEAD)" -eq 1 ]
	assert_starter_identity_cleaned
}

@test "task project:init entrypoint executes the isolated lifecycle" {
	cp "${REPO_ROOT}/.taskfiles/project.yml" "${PROJECT_ROOT}/.taskfiles/project.yml"
	cp "${REPO_ROOT}/.taskfiles/deps.yml" "${PROJECT_ROOT}/.taskfiles/deps.yml"
	cp "${REPO_ROOT}/.taskfiles/scripts/deps-update.sh" \
		"${PROJECT_ROOT}/.taskfiles/scripts/deps-update.sh"
	cp "${REPO_ROOT}/.devcontainer/tool-versions.conf" \
		"${PROJECT_ROOT}/.devcontainer/tool-versions.conf"
	mkdir -p "${PROJECT_ROOT}/.devcontainer/install/lib"
	cp "${REPO_ROOT}/.devcontainer/install/lib/common.sh" \
		"${PROJECT_ROOT}/.devcontainer/install/lib/common.sh"
	cat >"${PROJECT_ROOT}/Taskfile.yml" <<'EOF'
version: "3"

includes:
  deps:
    taskfile: ./.taskfiles/deps.yml
  project:
    taskfile: ./.taskfiles/project.yml
EOF
	git -C "${PROJECT_ROOT}" add Taskfile.yml .taskfiles .devcontainer
	git -C "${PROJECT_ROOT}" commit -qm "add task entrypoint"

	run bash -c 'printf "task-root\n\nCREATE ROOT\n" | task --dir "$1" project:init -- --no-starter-adopt' \
		_ "${PROJECT_ROOT}"

	[ "${status}" -eq 0 ]
	[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = "task-root" ]
	assert_parentless_root
	[ -z "$(git -C "${PROJECT_ROOT}" status --porcelain)" ]
	[ -f "${PROJECT_ROOT}/.taskfiles/scripts/deps-update.sh" ]
	[ -f "${PROJECT_ROOT}/.devcontainer/tool-versions.conf" ]
	[ -f "${PROJECT_ROOT}/.devcontainer/install/lib/common.sh" ]
	run task --dir "${PROJECT_ROOT}" --list
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"deps:update"* ]]
	run task --dir "${PROJECT_ROOT}" --dry deps:update
	[ "${status}" -eq 0 ]
	[[ "${output}" == *".taskfiles/scripts/deps-update.sh"* ]]
}

@test "task surface and unit runner register project init without remote commands" {
	grep -Fq 'project:' "${REPO_ROOT}/Taskfile.yml"
	grep -Fq 'task project:init' "${REPO_ROOT}/Taskfile.yml"
	grep -Fq 'project-init.bats' "${REPO_ROOT}/.taskfiles/test.yml"
	[ -f "${REPO_ROOT}/.taskfiles/project.yml" ]
	run grep -Eq 'git[[:space:]]+(push|fetch|ls-remote)' \
		"${REPO_ROOT}/.taskfiles/scripts/project-init.sh"
	[ "${status}" -ne 0 ]
}
