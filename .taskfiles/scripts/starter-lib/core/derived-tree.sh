#!/usr/bin/env bash
# Deterministic official-to-derived tree transformation.

YQ_COMPATIBILITY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../contracts" && pwd)/yq-compatibility.sh"
# shellcheck source=.taskfiles/scripts/starter-lib/contracts/yq-compatibility.sh
source "${YQ_COMPATIBILITY_PATH}"

STARTER_DERIVED_REMOVALS=(
	.taskfiles/project.yml .taskfiles/clean.yml
	.taskfiles/scripts/project-init.sh .taskfiles/scripts/clean.sh .taskfiles/scripts/clean-lib.sh
	AGENTS.md AGENTS.md.TEMPLATE.EXAMPLE
	.devcontainer/test/unit/project-init.bats
	.starter/contracts .starter/distribution/migrations .starter/distribution/payloads .starter/distribution/prepared
	.taskfiles/scripts/starter-release.sh .taskfiles/scripts/starter-prepare-release.sh
	.devcontainer/test/unit/starter-release.bats
)

starter_derived_transform() {
	local source_root="$1" destination="$2"
	[ -d "${source_root}" ] && [ ! -e "${destination}" ] || return 1
	mkdir -p "${destination}"
	rsync -a --exclude=.git --exclude=.env.d --exclude=.starter/evidence \
		--exclude=.starter/journals --exclude=.starter/caches --exclude=context.md \
		"${source_root}/" "${destination}/"
	starter_derived_apply_removals "${destination}"
	starter_derived_write_docs "${source_root}" "${destination}"
	yq_compatibility_yaml 'del(.tasks.release, .tasks["prepare-release"])' "${source_root}/.taskfiles/starter.yml" >"${destination}/.taskfiles/starter.yml"
	jq empty "${destination}/.starter/distribution/ownership.json"
	starter_derived_transform_taskfile "${destination}"
	starter_derived_reject_generated "${destination}"
	starter_tree_canonicalize_modes "${source_root}" "${destination}"
}

starter_derived_transform_taskfile() {
	local root="$1"
	if [ -f "${root}/Taskfile.yml" ]; then
		yq_compatibility_yaml_in_place 'del(.includes.clean, .includes.project, .tasks.clean)' "${root}/Taskfile.yml"
	fi
}

starter_derived_write_docs() {
	local source_root="$1" destination="$2" doc
	rm -rf -- "${destination:?}/README.md" "${destination}/CHANGELOG.md" "${destination}/docs"
	mkdir -p "${destination}/.devcontainer/docs"
	for doc in README.md configs.md extending.md install-tree.md install-volumes.md starter-updates.md; do
		[ -f "${source_root}/docs/en/${doc}" ] || continue
		cp -- "${source_root}/docs/en/${doc}" "${destination}/.devcontainer/docs/${doc}"
	done
	sed -i -e 's|\.\./docs/en/|./docs/|g' -e 's|docs/en/|docs/|g' "${destination}/.devcontainer/README.md"
}

starter_derived_apply_removals() {
	local root="$1" item
	[ -n "${root}" ] && [ "${root}" != / ] || return 1
	for item in "${STARTER_DERIVED_REMOVALS[@]}"; do
		rm -rf -- "${root:?}/${item}"
	done
}

starter_derived_reject_generated() {
	local root="$1" path
	for path in .starter/state.json .starter/evidence .starter/journals .starter/caches .starter/proposals .starter/pending; do
		[ ! -e "${root}/${path}" ] || {
			printf 'starter derived tree: generated path is forbidden: %s\n' "${path}" >&2
			return 1
		}
	done
}

starter_tree_canonicalize_modes() {
	local source_root="$1" tree_root="$2" entry metadata path mode
	while IFS= read -r -d '' path; do
		chmod 0644 "${tree_root}/${path}"
	done < <(find "${tree_root}" -type f -printf '%P\0' | LC_ALL=C sort -z)
	while IFS= read -r -d '' entry; do
		metadata="${entry%%$'\t'*}"
		path="${entry#*$'\t'}"
		mode="${metadata%% *}"
		[ "${mode}" = 100755 ] || continue
		[ -f "${tree_root}/${path}" ] && [ ! -L "${tree_root}/${path}" ] || continue
		chmod 0755 "${tree_root}/${path}"
	done < <(git -C "${source_root}" ls-files --stage -z)
}

starter_derived_identity() {
	local root="$1"
	(
		cd "${root}" || exit 1
		find . -mindepth 1 \( -type f -o -type l \) -printf '%P\0' | LC_ALL=C sort -z |
			while IFS= read -r -d '' path; do
				if [ -L "${path}" ]; then
					printf '120000 %s %s\n' "${path}" "$(readlink "${path}")"
				else
					printf '%s %s %s\n' "$(stat -c '%a' "${path}")" "${path}" "$(sha256sum "${path}" | cut -d' ' -f1)"
				fi
			done | sha256sum | cut -d' ' -f1
	)
}
