#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"; PROJECT_ROOT="${TEST_ROOT}/project"
	mkdir -p "${PROJECT_ROOT}/.taskfiles/scripts" "${PROJECT_ROOT}/.devcontainer/docs" "${PROJECT_ROOT}/docs/en" "${PROJECT_ROOT}/.agents"
	cp "${REPO_ROOT}/.taskfiles/scripts/"{project-init.sh,clean-lib.sh} "${PROJECT_ROOT}/.taskfiles/scripts/"
	chmod +x "${PROJECT_ROOT}/.taskfiles/scripts/project-init.sh"
	printf '# Starter\n' >"${PROJECT_ROOT}/README.md"; printf '# Agents\n' >"${PROJECT_ROOT}/AGENTS.md"
	printf '# Project\n<PROJECT_NAME>\n' >"${PROJECT_ROOT}/AGENTS.md.TEMPLATE"; printf '# Example\n' >"${PROJECT_ROOT}/AGENTS.md.TEMPLATE.EXAMPLE"
	printf '# Changes\n' >"${PROJECT_ROOT}/CHANGELOG.md"; printf 'MIT\n' >"${PROJECT_ROOT}/LICENSE"
	chmod 0640 "${PROJECT_ROOT}/LICENSE" "${PROJECT_ROOT}/AGENTS.md.TEMPLATE"
	printf '# Devcontainer\n../docs/en/extending.md\n' >"${PROJECT_ROOT}/.devcontainer/README.md"
	for doc in extending.md install-tree.md install-volumes.md configs.md; do printf '# %s\n' "${doc}" >"${PROJECT_ROOT}/docs/en/${doc}"; done
	printf 'APP_NAME=starter\n' >"${PROJECT_ROOT}/.env.example"; printf 'skill\n' >"${PROJECT_ROOT}/skills-lock.json"
	git -C "${PROJECT_ROOT}" init -q -b dev
	git -C "${PROJECT_ROOT}" config user.name "Project Init Test"; git -C "${PROJECT_ROOT}" config user.email "project-init@example.test"
	git -C "${PROJECT_ROOT}" add -A; git -C "${PROJECT_ROOT}" commit -qm "starter baseline"
	ORIGINAL_HEAD="$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"
	LICENSE_STATE="$(stat -c '%a' "${PROJECT_ROOT}/LICENSE"):$(sha256sum "${PROJECT_ROOT}/LICENSE" | cut -d' ' -f1)"
	TEMPLATE_STATE="$(stat -c '%a' "${PROJECT_ROOT}/AGENTS.md.TEMPLATE"):$(sha256sum "${PROJECT_ROOT}/AGENTS.md.TEMPLATE" | cut -d' ' -f1)"
}

teardown() { rm -rf "${TEST_ROOT}"; }

run_init() {
	local branch="${1:-main}" url="${2:-}"
	run bash -c 'cd "$1" && printf "INIT\n" | ./.taskfiles/scripts/project-init.sh --branch "$2" --origin-url "$3"' _ "${PROJECT_ROOT}" "${branch}" "${url}"
}

snapshot_repository() {
	git -C "${PROJECT_ROOT}" status --porcelain=v1 --branch
	git -C "${PROJECT_ROOT}" for-each-ref --format='%(refname) %(objectname) %(symref)'
	git -C "${PROJECT_ROOT}" config --local --list --show-origin
}

@test "default interactive inputs create main and configure canonical upstream" {
	git -C "${PROJECT_ROOT}" remote add origin git@GitHub.com:Cesarucho/Gentle-Starter/
	run bash -c 'cd "$1" && printf "\n\nINIT\n" | ./.taskfiles/scripts/project-init.sh' _ "${PROJECT_ROOT}"
	[ "${status}" -eq 0 ]; [ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = main ]
	[ "$(git -C "${PROJECT_ROOT}" remote get-url upstream)" = https://github.com/Cesarucho/gentle-starter.git ]
	[ "$(git -C "${PROJECT_ROOT}" remote)" = upstream ]
}

@test "custom branch and project URL produce exact next steps" {
	git -C "${PROJECT_ROOT}" remote add origin https://github.com/Cesarucho/gentle-starter.git
	run_init release https://github.com/example/project.git
	[ "${status}" -eq 0 ]; [[ "${output}" == *"Branch: release"* ]]
	[[ "${output}" == *"origin: https://github.com/example/project.git"* ]]
	[[ "${output}" == *"upstream: https://github.com/Cesarucho/gentle-starter.git"* ]]
	[[ "${output}" == *"Push: git push -u origin release"* ]]
}

@test "current target branch continues safely" {
	run_init dev
	[ "${status}" -eq 0 ]; [ "$(git -C "${PROJECT_ROOT}" rev-parse HEAD^)" = "${ORIGINAL_HEAD}" ]
}

@test "an existing non-current target branch fails before mutation" {
	git -C "${PROJECT_ROOT}" branch main; before="$(snapshot_repository)"
	run_init main
	[ "${status}" -ne 0 ]; [[ "${output}" == *"already exists"* ]]; [ "$(snapshot_repository)" = "${before}" ]
}

@test "invalid branch and repository URL fail before mutation" {
	before="$(snapshot_repository)"; run_init 'bad..branch'; [ "${status}" -ne 0 ]; [[ "${output}" == *"invalid project branch"* ]]
	run_init main 'not-a-url'; [ "${status}" -ne 0 ]; [[ "${output}" == *"invalid project repository URL"* ]]
	[ "$(snapshot_repository)" = "${before}" ]
}

@test "remote matrix preserves a user origin and adds upstream" {
	git -C "${PROJECT_ROOT}" remote add origin git@github.com:example/project.git
	run_init main
	[ "${status}" -eq 0 ]; [ "$(git -C "${PROJECT_ROOT}" remote get-url origin)" = git@github.com:example/project.git ]
	[ "$(git -C "${PROJECT_ROOT}" remote get-url upstream)" = https://github.com/Cesarucho/gentle-starter.git ]
}

@test "remote matrix accepts an equivalent supplied origin URL" {
	git -C "${PROJECT_ROOT}" remote add origin git@GitHub.com:Example/Project.git
	run_init main https://github.com/example/project/
	[ "${status}" -eq 0 ]; [ "$(git -C "${PROJECT_ROOT}" remote get-url origin)" = git@GitHub.com:Example/Project.git ]
}

@test "remote matrix rejects origin overwrite and conflicting upstream" {
	git -C "${PROJECT_ROOT}" remote add origin https://github.com/example/one.git; before="$(snapshot_repository)"
	run_init main https://github.com/example/two.git
	[ "${status}" -ne 0 ]; [[ "${output}" == *"refusing to overwrite"* ]]; [ "$(snapshot_repository)" = "${before}" ]
	git -C "${PROJECT_ROOT}" remote add upstream https://github.com/other/starter.git; before="$(snapshot_repository)"
	run_init main; [ "${status}" -ne 0 ]; [[ "${output}" == *"does not identify Gentle Starter"* ]]; [ "$(snapshot_repository)" = "${before}" ]
}

@test "duplicate starter remotes converge to canonical upstream only" {
	git -C "${PROJECT_ROOT}" remote add origin ssh://git@github.com/CESARUCHO/gentle-starter.git/
	git -C "${PROJECT_ROOT}" remote add upstream https://GITHUB.com/cesarucho/GENTLE-STARTER
	run_init main
	[ "${status}" -eq 0 ]; [ "$(git -C "${PROJECT_ROOT}" remote)" = upstream ]
	[ "$(git -C "${PROJECT_ROOT}" remote get-url upstream)" = https://github.com/Cesarucho/gentle-starter.git ]
}

@test "starter URL equivalence accepts common GitHub spellings" {
	local url
	for url in \
		'https://github.com/Cesarucho/gentle-starter.git' \
		'https://GITHUB.COM/cesarucho/GENTLE-STARTER/' \
		'git@github.com:Cesarucho/gentle-starter.git' \
		'ssh://git@GitHub.com/Cesarucho/gentle-starter.git/'; do
		git -C "${PROJECT_ROOT}" remote add origin "${url}"
		run bash -c 'cd "$1" && ./.taskfiles/scripts/project-init.sh --dry-run --branch main --origin-url ""' _ "${PROJECT_ROOT}"
		[ "${status}" -eq 0 ]
		[[ "${output}" == *"rename starter origin to upstream"* ]]
		git -C "${PROJECT_ROOT}" remote remove origin
	done
}

@test "dry-run reports all actions and changes no repository state" {
	git -C "${PROJECT_ROOT}" remote add origin git@github.com:Cesarucho/gentle-starter.git; before="$(snapshot_repository)"
	run bash -c 'cd "$1" && ./.taskfiles/scripts/project-init.sh --dry-run --branch main --origin-url https://github.com/example/project.git' _ "${PROJECT_ROOT}"
	[ "${status}" -eq 0 ]; [[ "${output}" == *"Branch: main (create and switch to main)"* ]]
	[[ "${output}" == *"rename starter origin to upstream"* ]]; [[ "${output}" == *"Dry run complete. No changes were made."* ]]
	[ "$(snapshot_repository)" = "${before}" ]; [ -f "${PROJECT_ROOT}/README.md" ]
}

@test "failure after branch and remote changes restores exact repository state" {
	git -C "${PROJECT_ROOT}" remote add origin git@github.com:Cesarucho/gentle-starter.git
	git -C "${PROJECT_ROOT}" config branch.dev.remote origin; git -C "${PROJECT_ROOT}" config branch.dev.merge refs/heads/dev
	git -C "${PROJECT_ROOT}" branch retained; git -C "${PROJECT_ROOT}" tag retained-v1
	before="$(snapshot_repository)"; mkdir -p "${TEST_ROOT}/bin"; real_git="$(command -v git)"
	cat >"${TEST_ROOT}/bin/git" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = commit ]; then exit 86; fi
exec "${REAL_GIT}" "$@"
EOF
	chmod +x "${TEST_ROOT}/bin/git"
	run env PATH="${TEST_ROOT}/bin:${PATH}" REAL_GIT="${real_git}" bash -c 'cd "$1" && printf "INIT\n" | ./.taskfiles/scripts/project-init.sh --branch main --origin-url https://github.com/example/project.git' _ "${PROJECT_ROOT}"
	[ "${status}" -ne 0 ]; [ "$(snapshot_repository)" = "${before}" ]; [ -f "${PROJECT_ROOT}/README.md" ]
}

@test "failure rollback restores symbolic remote HEAD without ref collisions" {
	git -C "${PROJECT_ROOT}" remote add origin git@github.com:Cesarucho/gentle-starter.git
	git -C "${PROJECT_ROOT}" update-ref refs/remotes/origin/dev "${ORIGINAL_HEAD}"
	git -C "${PROJECT_ROOT}" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/dev
	git -C "${PROJECT_ROOT}" branch retained
	git -C "${PROJECT_ROOT}" tag retained-v1
	local before branch_before head_before index_before worktree_before real_git
	before="$(snapshot_repository)"
	branch_before="$(git -C "${PROJECT_ROOT}" branch --show-current)"
	head_before="$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"
	index_before="$(sha256sum "${PROJECT_ROOT}/.git/index")"
	worktree_before="$(git -C "${PROJECT_ROOT}" status --porcelain=v1 --untracked-files=all)"
	mkdir -p "${TEST_ROOT}/bin"
	real_git="$(command -v git)"
	cat >"${TEST_ROOT}/bin/git" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = commit ]; then exit 86; fi
exec "${REAL_GIT}" "$@"
EOF
	chmod +x "${TEST_ROOT}/bin/git"

	run env PATH="${TEST_ROOT}/bin:${PATH}" REAL_GIT="${real_git}" bash -c 'cd "$1" && printf "INIT\n" | ./.taskfiles/scripts/project-init.sh --branch main --origin-url https://github.com/example/project.git' _ "${PROJECT_ROOT}"

	[ "${status}" -ne 0 ]
	[[ "${output}" != *"multiple updates"* ]]
	[ "$(sha256sum "${PROJECT_ROOT}/.git/index")" = "${index_before}" ]
	[ "$(snapshot_repository)" = "${before}" ]
	[ "$(git -C "${PROJECT_ROOT}" branch --show-current)" = "${branch_before}" ]
	[ "$(git -C "${PROJECT_ROOT}" rev-parse HEAD)" = "${head_before}" ]
	[ "$(git -C "${PROJECT_ROOT}" symbolic-ref refs/remotes/origin/HEAD)" = refs/remotes/origin/dev ]
	[ "$(git -C "${PROJECT_ROOT}" status --porcelain=v1 --untracked-files=all)" = "${worktree_before}" ]
	[ ! -e "${PROJECT_ROOT}/.git/refs/heads/main" ]
}

@test "initialization preserves ancestry refs license template and template-only policy" {
	git -C "${PROJECT_ROOT}" branch retained; git -C "${PROJECT_ROOT}" tag retained-v1; refs_before="$(git -C "${PROJECT_ROOT}" show-ref | grep -v 'refs/heads/dev')"
	run_init main
	[ "${status}" -eq 0 ]; [ "$(git -C "${PROJECT_ROOT}" rev-parse HEAD^)" = "${ORIGINAL_HEAD}" ]
	[ "$(git -C "${PROJECT_ROOT}" show-ref | grep -E 'retained|retained-v1')" = "${refs_before}" ]
	[ "$(stat -c '%a' "${PROJECT_ROOT}/LICENSE"):$(sha256sum "${PROJECT_ROOT}/LICENSE" | cut -d' ' -f1)" = "${LICENSE_STATE}" ]
	[ "$(stat -c '%a' "${PROJECT_ROOT}/AGENTS.md.TEMPLATE"):$(sha256sum "${PROJECT_ROOT}/AGENTS.md.TEMPLATE" | cut -d' ' -f1)" = "${TEMPLATE_STATE}" ]
	[ ! -e "${PROJECT_ROOT}/AGENTS.md" ]; [ ! -e "${PROJECT_ROOT}/AGENTS.md.TEMPLATE.EXAMPLE" ]; [ -z "$(git -C "${PROJECT_ROOT}" status --porcelain)" ]
	[ -f "${PROJECT_ROOT}/.devcontainer/docs/extending.md" ]
	grep -Fq './docs/extending.md' "${PROJECT_ROOT}/.devcontainer/README.md"
}

@test "missing origin output gives precise add and push commands" {
	run_init main
	[ "${status}" -eq 0 ]; [[ "${output}" == *"Next: git remote add origin <project-url>"* ]]; [[ "${output}" == *"git push -u origin main"* ]]
	[[ "${output}" == *"run 'git fetch upstream' to establish upstream/main locally"* ]]
}

@test "locally available upstream baseline is verified without network access" {
	git -C "${PROJECT_ROOT}" update-ref refs/remotes/upstream/main HEAD
	run_init main
	[ "${status}" -eq 0 ]; [[ "${output}" == *"Ancestry: verified against local upstream/main."* ]]
}

@test "a second run refuses without another commit" {
	run_init main; [ "${status}" -eq 0 ]; initialized_head="$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"
	run_init main; [ "${status}" -ne 0 ]; [[ "${output}" == *"already been committed"* ]]; [ "$(git -C "${PROJECT_ROOT}" rev-parse HEAD)" = "${initialized_head}" ]
}

@test "cancellation and dirty worktrees do not mutate the repository" {
	run bash -c 'cd "$1" && printf "NO\n" | ./.taskfiles/scripts/project-init.sh --branch main --origin-url ""' _ "${PROJECT_ROOT}"
	[ "${status}" -eq 0 ]; [ "$(git -C "${PROJECT_ROOT}" rev-parse HEAD)" = "${ORIGINAL_HEAD}" ]
	printf 'dirty\n' >>"${PROJECT_ROOT}/README.md"; run_init main; [ "${status}" -ne 0 ]; [[ "${output}" == *"working tree must be clean"* ]]
}
