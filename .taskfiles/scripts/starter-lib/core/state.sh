#!/usr/bin/env bash
# Read-only repository admission and atomic transport-neutral state markers.

STARTER_STATE_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.taskfiles/scripts/starter-lib/core/manifest.sh
source "${STARTER_STATE_CORE_DIR}/manifest.sh"
# shellcheck source=.taskfiles/scripts/starter-lib/contracts/repository-status-port.sh
source "${STARTER_STATE_CORE_DIR}/../contracts/repository-status-port.sh"

starter_state_error() {
	printf 'starter state: %s\n' "$*" >&2
}

starter_state_require_clean_workspace() {
	local project_root="$1" physical_root repository_status
	physical_root="$(starter_path_root "${project_root}")" || return 1
	repository_status="$(repository_status_inspect "${physical_root}")" || {
		starter_state_error "could not inspect workspace and index"
		return 1
	}
	[ "$(jq -r '.is_repository' <<<"${repository_status}")" = true ] || {
		starter_state_error "project root is not a Git worktree"
		return 1
	}
	[ "$(jq -r '.root_matches' <<<"${repository_status}")" = true ] || {
		starter_state_error "project root must be the Git worktree root"
		return 1
	}
	[ "$(jq -r '.clean' <<<"${repository_status}")" = true ] || {
		starter_state_error "workspace or index is not clean"
		return 1
	}
}

starter_state_validate_plan() {
	local plan="$1" target_release="$2"
	jq -e --argjson target_release "${target_release}" '
		def exact_keys($expected): (keys | sort) == ($expected | sort);
		def sha256: type == "string" and test("^[0-9a-f]{64}$");
		def relative: type == "string" and length > 0 and (startswith("/") | not) and
			(split("/") | all(. != "" and . != "." and . != ".."));
		type == "object" and
		.schema == "gentle-starter.plan/v2" and
		exact_keys(["schema","target_release","migration_ids","operations","ownership_summary","fusion"]) and
		.target_release == $target_release and
		(.migration_ids | type == "array" and all(type == "string" and length > 0)) and
		.fusion.contract == "F-manual/v1" and (.fusion.pending | type == "array") and
		(.operations | type == "array" and all(
			type == "object" and
			exact_keys(["migration_id","type","ownership","source","target","content_sha256","expected_before_sha256"]) and
			(.migration_id | type == "string" and length > 0) and
			(.type == "copy" or .type == "delete" or .type == "fusion") and
			(.ownership == "managed" or .ownership == "fusion") and
			(.target | relative) and
			(.content_sha256 == null or (.content_sha256 | sha256)) and
			(.expected_before_sha256 == null or (.expected_before_sha256 | sha256))))
	' <<<"${plan}" >/dev/null || {
		starter_state_error "invalid state plan"
		return 1
	}
}

starter_state_migration_bindings() {
	local context="$1" plan="$2" bindings
	bindings="$(jq -cn \
		--argjson ids "$(jq '.migration_ids' <<<"${plan}")" \
		--argjson entries "$(jq '.manifest.migrations.entries' <<<"${context}")" '
			[$ids[] as $id | $entries[] | select(.id == $id) | {id,sha256}]
	')" || return 1
	[ "$(jq 'length' <<<"${bindings}")" -eq "$(jq '.migration_ids | length' <<<"${plan}")" ] || {
		starter_state_error "state migration binding is incomplete"
		return 1
	}
	printf '%s\n' "${bindings}"
}

starter_state_managed_fingerprints() {
	local project_root="$1" plan="$2"
	local fingerprints='[]' count index operation target ownership operation_type expected_sha resolved actual_sha
	count="$(jq '.operations | length' <<<"${plan}")"
	for ((index = 0; index < count; index++)); do
		operation="$(jq -c --argjson index "${index}" '.operations[$index]' <<<"${plan}")"
		target="$(jq -r '.target' <<<"${operation}")"
		ownership="$(jq -r '.ownership' <<<"${operation}")"
		operation_type="$(jq -r '.type' <<<"${operation}")"
		resolved="$(starter_path_resolve_beneath "${project_root}" "${target}")" || {
			starter_state_error "managed path escapes project root"
			return 1
		}
		if [ "${operation_type}" = delete ]; then
			if [ -e "${resolved}" ] || [ -L "${project_root}/${target}" ]; then
				starter_state_error "managed fingerprint mismatch: expected absent ${target}"
				return 1
			fi
			fingerprints="$(jq -cn \
				--argjson fingerprints "${fingerprints}" --arg path "${target}" \
				--arg ownership "${ownership}" \
				'$fingerprints + [{path:$path,ownership:$ownership,sha256:null}]')"
			continue
		fi
		[ -f "${resolved}" ] || {
			starter_state_error "managed fingerprint mismatch: missing ${target}"
			return 1
		}
		actual_sha="$(sha256sum "${resolved}" | cut -d' ' -f1)"
		if [ "${operation_type}" = copy ]; then
			expected_sha="$(jq -r '.content_sha256 // empty' <<<"${operation}")"
			if [ -z "${expected_sha}" ] || [ "${actual_sha}" != "${expected_sha}" ]; then
				starter_state_error "managed fingerprint mismatch: ${target}"
				return 1
			fi
		fi
		fingerprints="$(jq -cn \
			--argjson fingerprints "${fingerprints}" --arg path "${target}" \
			--arg ownership "${ownership}" --arg sha256 "${actual_sha}" \
			'$fingerprints + [{path:$path,ownership:$ownership,sha256:$sha256}]')"
	done
	printf '%s\n' "${fingerprints}"
}

starter_state_v2_managed_fingerprints() {
	local project_root="$1" context="$2" inventory manifest fingerprints='[]' path expected actual
	inventory="$(jq -r '.ownership_file' <<<"${context}")"
	manifest="$(jq -r '.manifest_file' <<<"${context}")"
	while IFS= read -r path; do
		expected="$(jq -r --arg path "${path}" '.payload.entries[] | select(.path == $path) | .sha256' "${manifest}")"
		[ -n "${expected}" ] || {
			starter_state_error "managed path is absent from exact payload: ${path}"
			return 1
		}
		[ -f "${project_root}/${path}" ] && [ ! -L "${project_root}/${path}" ] || return 1
		actual="$(sha256sum "${project_root}/${path}" | cut -d' ' -f1)"
		[ "${actual}" = "${expected}" ] || {
			starter_state_error "managed fingerprint mismatch: ${path}"
			return 1
		}
		fingerprints="$(jq -cn --argjson fingerprints "${fingerprints}" --arg path "${path}" --arg sha "${actual}" \
			'$fingerprints + [{path:$path,ownership:"managed",sha256:$sha}]')"
	done < <(jq -r '.managed[].path' "${inventory}")
	printf '%s\n' "${fingerprints}"
}

starter_state_build() {
	local project_root="$1" source_result="$2" plan="$3"
	local context envelope_file target_release migrations fingerprints state state_sha fusion='[]' path
	context="$(starter_manifest_load "${source_result}")" || return 1
	envelope_file="$(jq -r '.envelope_file' <<<"${context}")"
	target_release="$(jq -c '.target_release' <<<"${context}")"
	starter_state_validate_plan "${plan}" "${target_release}" || return 1
	migrations="$(starter_state_migration_bindings "${context}" "${plan}")" || return 1
	fingerprints="$(starter_state_v2_managed_fingerprints "${project_root}" "${context}")" || return 1
	for path in .devcontainer/devcontainer.json .devcontainer/docker-compose.yml; do
		[ -f "${project_root}/${path}" ] && [ ! -L "${project_root}/${path}" ] || return 1
		fusion="$(jq -cn --argjson accepted "${fusion}" --arg path "${path}" \
			--arg sha "$(sha256sum "${project_root}/${path}" | cut -d' ' -f1)" --arg mode "$(stat -c '%a' "${project_root}/${path}")" \
			'$accepted + [{path:$path,presence:"present",sha256:$sha,mode:$mode}]')"
	done
	state="$(jq -cn \
		--argjson source "$(jq '.source' "${envelope_file}")" \
		--argjson release "$(jq '.release' "${envelope_file}")" \
		--argjson immutable_identities "$(jq '.immutable_identities' "${envelope_file}")" \
		--arg envelope_schema "$(jq -r '.schema' "${envelope_file}")" \
		--arg envelope_sha "$(jq -r '.integrity.envelope_sha256' "${envelope_file}")" \
		--arg manifest_schema "$(jq -r '.manifest.schema' "${envelope_file}")" \
		--arg manifest_sha "$(jq -r '.manifest.sha256' "${envelope_file}")" \
		--argjson migrations "${migrations}" \
		--argjson fingerprints "${fingerprints}" \
		--argjson fusion "${fusion}" \
		--argjson evidence "$(jq '.evidence' "${envelope_file}")" '
		{
			schema:"gentle-starter.state/v2",
			source:$source,
			release:$release,
			immutable_identities:$immutable_identities,
			envelope:{schema:$envelope_schema,sha256:$envelope_sha},
			manifest:{schema:$manifest_schema,sha256:$manifest_sha},
			migrations:$migrations,
			managed_fingerprints:$fingerprints,
			fusion:{contract:"F-manual/v1",accepted:$fusion},
			evidence:$evidence
		}')" || return 1
	state_sha="$(jq -cS . <<<"${state}" | sha256sum | cut -d' ' -f1)"
	jq -cn --argjson state "${state}" --arg sha "${state_sha}" \
		'$state + {integrity:{canonicalization:"jq-sorted-utf8-v1",state_sha256:$sha}}'
}

starter_state_persist() {
	local project_root="$1" state="$2"
	local physical_root state_file temporary
	physical_root="$(starter_path_root "${project_root}")" || return 1
	[ -d "${physical_root}/.starter" ] || {
		starter_state_error "state directory is unavailable"
		return 1
	}
	state_file="$(starter_path_resolve_beneath "${physical_root}" ".starter/state.json")" || return 1
	temporary="$(mktemp "${state_file}.XXXXXX")" || return 1
	if ! printf '%s\n' "${state}" >"${temporary}" || ! chmod 0644 "${temporary}" || ! mv -f -- "${temporary}" "${state_file}"; then
		rm -f -- "${temporary}"
		starter_state_error "could not persist state marker"
		return 1
	fi
}

starter_state_write_last() {
	local project_root="$1" source_result="$2" plan="$3"
	local physical_root state
	physical_root="$(starter_path_root "${project_root}")" || return 1
	starter_state_require_clean_workspace "${physical_root}" || return 1
	state="$(starter_state_build "${physical_root}" "${source_result}" "${plan}")" || return 1
	starter_state_persist "${physical_root}" "${state}"
}
