#!/usr/bin/env bash
# Read-only planning over neutral source results and declarative migrations.

STARTER_PLANNER_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.taskfiles/scripts/starter-lib/core/migration.sh
source "${STARTER_PLANNER_CORE_DIR}/migration.sh"

starter_planner_error() {
	printf 'starter planner: %s\n' "$*" >&2
}

starter_planner_classify_ownership() {
	local operation="$1" ownership
	ownership="$(jq -r '.ownership' <<<"${operation}")"
	case "${ownership}" in
	managed | fusion | project-owned) printf '%s\n' "${ownership}" ;;
	*)
		starter_planner_error "unknown ownership class"
		return 1
		;;
	esac
}

starter_plan_build() {
	local source_result="$1" current_version="$2"
	local context chain planned='[]' migration_count migration_index operation_count operation_index
	local migration operation migration_id operation_type ownership source_path content_sha expected_before target_path
	local project_root resolved_target prior_target prior_count prior_index resolved_targets='[]'

	project_root="$(pwd -P)" || return 1
	context="$(starter_manifest_load "${source_result}")" || return 1
	chain="$(starter_migration_select_chain "${context}" "${current_version}")" || return 1
	migration_count="$(jq 'length' <<<"${chain}")"
	for ((migration_index = 0; migration_index < migration_count; migration_index++)); do
		migration="$(jq -c --argjson index "${migration_index}" '.[$index]' <<<"${chain}")"
		migration_id="$(jq -r '.id' <<<"${migration}")"
		operation_count="$(jq '.operations | length' <<<"${migration}")"
		for ((operation_index = 0; operation_index < operation_count; operation_index++)); do
			operation="$(jq -c --argjson index "${operation_index}" '.operations[$index]' <<<"${migration}")"
			operation_type="$(jq -r '.type' <<<"${operation}")"
			ownership="$(starter_planner_classify_ownership "${operation}")" || return 1
			[ "${ownership}" != project-owned ] || {
				starter_planner_error "project-owned target is immutable"
				return 1
			}
			source_path="$(jq -r '.source // empty' <<<"${operation}")"
			content_sha=""
			[ -z "${source_path}" ] || content_sha="$(starter_manifest_payload_digest "${context}" "${source_path}")" || return 1
			expected_before="$(jq -c '.expected_before_sha256' <<<"${operation}")"
			target_path="$(jq -r '.target' <<<"${operation}")"
			resolved_target="$(starter_path_resolve_beneath "${project_root}" "${target_path}")" || {
				starter_planner_error "target escapes project root"
				return 1
			}
			prior_count="$(jq 'length' <<<"${resolved_targets}")"
			for ((prior_index = 0; prior_index < prior_count; prior_index++)); do
				prior_target="$(jq -r --argjson index "${prior_index}" '.[$index]' <<<"${resolved_targets}")"
				if starter_paths_collide "${resolved_target}" "${prior_target}"; then
					starter_planner_error "target path collision"
					return 1
				fi
			done
			resolved_targets="$(jq -cn --argjson targets "${resolved_targets}" --arg target "${resolved_target}" '$targets + [$target]')"
			planned="$(jq -cn \
				--argjson planned "${planned}" --arg migration_id "${migration_id}" \
				--arg type "${operation_type}" --arg ownership "${ownership}" \
				--arg source "${source_path}" --arg target "${target_path}" \
				--arg content_sha256 "${content_sha}" --argjson expected_before_sha256 "${expected_before}" \
				'$planned + [{migration_id:$migration_id,type:$type,ownership:$ownership,
					source:(if $source == "" then null else $source end),target:$target,
					content_sha256:(if $content_sha256 == "" then null else $content_sha256 end),
					expected_before_sha256:$expected_before_sha256}]')"
		done
	done

	jq -cn \
		--argjson target_release "$(jq '.target_release' <<<"${context}")" \
		--argjson migration_ids "$(jq '[.[].id]' <<<"${chain}")" \
		--argjson operations "${planned}" \
		'{schema:"gentle-starter.plan/v1",target_release:$target_release,migration_ids:$migration_ids,
			operations:$operations,ownership_summary:{
				managed:([$operations[] | select(.ownership == "managed")] | length),
				fusion:([$operations[] | select(.ownership == "fusion")] | length),
				project_owned:([$operations[] | select(.ownership == "project-owned")] | length)
			}}'
}
