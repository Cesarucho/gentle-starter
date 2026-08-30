#!/usr/bin/env bash
# Planner for prepared lifecycle v2 artifacts.

STARTER_PLANNER_V2_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.taskfiles/scripts/starter-lib/core/manifest.sh
source "${STARTER_PLANNER_V2_CORE_DIR}/manifest.sh"

starter_plan_v2_error() { printf 'starter planner v2: %s\n' "$*" >&2; }

starter_plan_v2_chain() {
	local context="$1" current="$2" target documents='[]' count index path expected_id document
	local matches next selected='[]' steps=0
	target="$(jq -r '.target_release.version' <<<"${context}")"
	[[ "${current}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || return 1
	if [ "${current}" != "${target}" ] && [ "$(printf '%s\n%s\n' "${current}" "${target}" | sort -V | sed -n '$p')" != "${target}" ]; then
		starter_plan_v2_error "downgrade is not supported: ${current} -> ${target}"
		return 1
	fi
	count="$(jq '.manifest.migrations.entries | length' <<<"${context}")"
	for ((index = 0; index < count; index++)); do
		path="$(jq -r --argjson index "${index}" '.migration_root + "/" + .manifest.migrations.entries[$index].path' <<<"${context}")"
		expected_id="$(jq -r --argjson index "${index}" '.manifest.migrations.entries[$index].id' <<<"${context}")"
		jq -e --arg id "${expected_id}" '
			.schema == "starter-migration/v2" and .id == $id and
			(.from_version | test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")) and
			(.to_version | test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")) and
			.from_version != .to_version and (.operations | type == "array") and
			all(.operations[]; (.ownership == "managed" or .ownership == "fusion") and
			(.expected_before.presence | IN("any","present","absent")) and
			(.after.presence | IN("present","absent")))' "${path}" >/dev/null || return 1
		document="$(jq -c . "${path}")"
		documents="$(jq -cn --argjson documents "${documents}" --argjson document "${document}" '$documents + [$document]')"
	done
	[ "$(jq '[group_by([.from_version,.to_version])[] | select(length > 1)] | length' <<<"${documents}")" -eq 0 ] || {
		starter_plan_v2_error 'duplicate migration edge'
		return 1
	}
	[ "$(jq '[group_by(.from_version)[] | select(length > 1)] | length' <<<"${documents}")" -eq 0 ] || {
		starter_plan_v2_error 'ambiguous migration chain'
		return 1
	}
	while [ "${current}" != "${target}" ]; do
		matches="$(jq -c --arg current "${current}" '[.[] | select(.from_version == $current)]' <<<"${documents}")"
		[ "$(jq 'length' <<<"${matches}")" -eq 1 ] || {
			starter_plan_v2_error "incomplete migration chain from ${current}"
			return 1
		}
		next="$(jq -r '.[0].to_version' <<<"${matches}")"
		if [ "$(printf '%s\n%s\n' "${current}" "${next}" | sort -V | sed -n '$p')" != "${next}" ]; then
			starter_plan_v2_error 'migration cycle or downgrade'
			return 1
		fi
		if [ "$(printf '%s\n%s\n' "${next}" "${target}" | sort -V | sed -n '$p')" != "${target}" ]; then
			starter_plan_v2_error 'migration target does not match release'
			return 1
		fi
		selected="$(jq -cn --argjson selected "${selected}" --argjson migration "$(jq '.[0]' <<<"${matches}")" '$selected + [$migration]')"
		current="${next}"
		steps=$((steps + 1))
		[ "${steps}" -le "${count}" ] || {
			starter_plan_v2_error 'migration cycle'
			return 1
		}
	done
	printf '%s\n' "${selected}"
}

starter_plan_v2_build() {
	local source_result="$1" current_version="$2" context manifest chain migration inventory
	context="$(starter_manifest_load "${source_result}")" || return 1
	manifest="$(jq -r '.manifest_file' <<<"${context}")"
	inventory="$(jq -r '.ownership_file' <<<"${context}")"
	jq -e '.schema == "starter-manifest/v2" and .payload.closure == "exact" and
		.identities.official_tree != .identities.derived_tree and
		.transformation.schema == "gentle-starter.derived-tree-transformation/v1"' "${manifest}" >/dev/null || return 1
	chain="$(starter_plan_v2_chain "${context}" "${current_version}")" || return 1
	[ "$(jq 'length' <<<"${chain}")" -gt 0 ] || return 1
	migration="$(jq -c '.[-1]' <<<"${chain}")"
	local operations='[]' pending='[]' count index operation path ownership classified source content expected migration_id
	local project_root state_file ours base decision
	project_root="$(pwd -P)"
	state_file="${project_root}/.starter/state.json"
	migration_id="$(jq -r '.id' <<<"${migration}")"
	count="$(jq '.operations | length' <<<"${migration}")"
	for ((index = 0; index < count; index++)); do
		operation="$(jq -c ".operations[${index}]" <<<"${migration}")"
		path="$(jq -r '.target' <<<"${operation}")"
		case "${path}" in .starter/state.json | .starter/evidence/* | .starter/journals/* | .starter/caches/*) return 1 ;; esac
		ownership="$(jq -r '.ownership' <<<"${operation}")"
		classified="$(starter_ownership_classify "${inventory}" "${path}")" || return 1
		[ "${classified}" = "${ownership}" ] || return 1
		source="$(jq -r '.source // empty' <<<"${operation}")"
		content="$(jq -r '.after.sha256 // empty' <<<"${operation}")"
		if [ -f "${project_root}/${path}" ] && [ ! -L "${project_root}/${path}" ]; then
			expected="$(sha256sum "${project_root}/${path}" | cut -d' ' -f1)"
		else
			expected=null
		fi
		if [ "${ownership}" = fusion ]; then
			ours="${expected}"
			base="$(jq -r --arg path "${path}" '.fusion.accepted[]? | select(.path == $path) | .sha256' "${state_file}" 2>/dev/null || true)"
			[ -n "${base}" ] || base="${ours}"
			if [ "${ours}" = "${base}" ]; then
				decision=take-starter
			elif [ "${content}" = "${base}" ]; then
				decision=keep-project
			else
				decision=manual
				pending="$(jq -cn --argjson pending "${pending}" --arg path "${path}" --arg base "${base}" \
					--arg ours "${ours}" --arg theirs "${content}" '$pending + [{path:$path,base_sha256:$base,ours_sha256:$ours,theirs_sha256:$theirs}]')"
			fi
			[ "${decision}" != keep-project ] || continue
		elif [ -f "${state_file}" ] && [ "${expected}" = "${content}" ]; then
			continue
		fi
		operations="$(jq -cn --argjson operations "${operations}" --arg migration "${migration_id}" \
			--arg type "$(jq -r '.type' <<<"${operation}")" --arg ownership "${ownership}" --arg source "${source}" \
			--arg target "${path}" --arg content "${content}" --arg expected "${expected}" '
			$operations + [{migration_id:$migration,type:$type,ownership:$ownership,
			source:(if $source == "" then null else $source end),target:$target,
			content_sha256:(if $content == "" then null else $content end),
			expected_before_sha256:(if $expected == "null" then null else $expected end)}]')"
	done
	jq -n --argjson release "$(jq '.target_release' <<<"${context}")" --argjson migrations "$(jq '[.[].id]' <<<"${chain}")" \
		--argjson operations "${operations}" --argjson pending "${pending}" '{
		schema:"gentle-starter.plan/v2",target_release:$release,migration_ids:$migrations,operations:$operations,
		ownership_summary:{managed:([$operations[]|select(.ownership=="managed")]|length),fusion:([$operations[]|select(.ownership=="fusion")]|length),project_owned:0},
		fusion:{contract:"F-manual/v1",paths:[".devcontainer/devcontainer.json",".devcontainer/docker-compose.yml"],pending:$pending}
	}'
}
