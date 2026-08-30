#!/usr/bin/env bash
# Durable pre-mutation journals and CAS-guarded migration application.

STARTER_JOURNAL_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.taskfiles/scripts/starter-lib/core/state.sh
source "${STARTER_JOURNAL_CORE_DIR}/state.sh"

starter_journal_error() {
	printf 'starter journal: %s\n' "$*" >&2
}

starter_journal_fingerprint() {
	local path="$1"
	if [ -L "${path}" ] || { [ -e "${path}" ] && [ ! -f "${path}" ]; }; then
		starter_journal_error "owned target is not a regular file"
		return 1
	fi
	if [ -f "${path}" ]; then
		sha256sum "${path}" | cut -d' ' -f1
	else
		printf 'null\n'
	fi
}

starter_journal_sync() {
	local path="$1"
	sync -f "${path}" 2>/dev/null || {
		starter_journal_error "could not durably sync transaction data"
		return 1
	}
}

starter_journal_validate() {
	local project_root="$1" journal_file="$2" physical_root expected_file expected_sha actual_sha
	physical_root="$(starter_path_root "${project_root}")" || return 1
	expected_file="$(starter_path_existing_file_beneath "${physical_root}" \
		"${journal_file#"${physical_root}/"}")" || return 1
	case "${expected_file}" in
	"${physical_root}/.starter/journals/"*/journal.json) ;;
	*)
		starter_journal_error "journal is outside the transaction store"
		return 1
		;;
	esac
	jq -e --arg root "${physical_root}" '
		def sha: type == "string" and test("^[0-9a-f]{64}$");
		type == "object" and .schema == "gentle-starter.journal/v2" and .fusion.contract == "F-manual/v1" and
		(.fusion.status == "pending" or .fusion.status == "applying") and (.progress.applied | type == "number") and
		.project_root == $root and (.source_result | type == "object") and
		.plan.schema == "gentle-starter.plan/v2" and
		(.state_before_sha256 == null or (.state_before_sha256 | sha)) and
		(.integrity == {canonicalization:"jq-sorted-utf8-v1",journal_sha256:.integrity.journal_sha256}) and
		(.integrity.journal_sha256 | sha) and
		(.operations | type == "array" and all(
			(.index | type == "number") and (.type == "copy" or .type == "delete" or .type == "fusion") and
			(.ownership == "managed" or .ownership == "fusion") and
			(.target | type == "string" and length > 0) and
			(.before.sha256 == null or (.before.sha256 | sha)) and
			(.after.sha256 == null or (.after.sha256 | sha)) and
			(.before.backup == null or (.before.backup | type == "string")) and
			(.after.staged == null or (.after.staged | type == "string"))))
	' "${expected_file}" >/dev/null || {
		starter_journal_error "invalid transaction journal"
		return 1
	}
	expected_sha="$(jq -r '.integrity.journal_sha256' "${expected_file}")"
	actual_sha="$(jq -cS 'del(.integrity)' "${expected_file}" | sha256sum | cut -d' ' -f1)"
	[ "${actual_sha}" = "${expected_sha}" ] || {
		starter_journal_error "journal integrity mismatch"
		return 1
	}
	printf '%s\n' "${expected_file}"
}

starter_journal_prepare() {
	local project_root="$1" source_result="$2" plan="$3"
	local physical_root context journal_root transaction_dir journal_file temporary payload_root state_before journal_sha
	local operations='[]' count index operation target resolved expected before backup source staged after
	physical_root="$(starter_path_root "${project_root}")" || return 1
	starter_state_require_clean_workspace "${physical_root}" || return 1
	context="$(starter_manifest_load "${source_result}")" || return 1
	starter_state_validate_plan "${plan}" "$(jq -c '.target_release' <<<"${context}")" || return 1
	count="$(jq '.operations | length' <<<"${plan}")"
	for ((index = 0; index < count; index++)); do
		operation="$(jq -c --argjson index "${index}" '.operations[$index]' <<<"${plan}")"
		target="$(jq -r '.target' <<<"${operation}")"
		resolved="$(starter_path_resolve_beneath "${physical_root}" "${target}")" || return 1
		before="$(starter_journal_fingerprint "${resolved}")" || return 1
		expected="$(jq -r '.expected_before_sha256 // "null"' <<<"${operation}")"
		[ "${before}" = "${expected}" ] || {
			starter_journal_error "pre-mutation CAS mismatch: ${target}"
			return 1
		}
	done
	journal_root="$(starter_path_resolve_beneath "${physical_root}" '.starter/journals')" || return 1
	mkdir -p -- "${journal_root}" || return 1
	transaction_dir="$(mktemp -d "${journal_root}/transaction.XXXXXX")" || return 1
	mkdir -p "${transaction_dir}/prestate" "${transaction_dir}/staged" || {
		rm -rf -- "${transaction_dir}"
		return 1
	}
	payload_root="$(jq -r '.payload_root + "/" + .manifest.payload.root' <<<"${context}")"
	state_before="$(starter_journal_fingerprint "${physical_root}/.starter/state.json")" || return 1
	for ((index = 0; index < count; index++)); do
		operation="$(jq -c --argjson index "${index}" '.operations[$index]' <<<"${plan}")"
		target="$(jq -r '.target' <<<"${operation}")"
		resolved="$(starter_path_resolve_beneath "${physical_root}" "${target}")" || return 1
		before="$(starter_journal_fingerprint "${resolved}")" || return 1
		expected="$(jq -r '.expected_before_sha256 // "null"' <<<"${operation}")"
		[ "${before}" = "${expected}" ] || {
			starter_journal_error "pre-mutation CAS mismatch: ${target}"
			rm -rf -- "${transaction_dir}"
			return 1
		}
		backup=null
		if [ "${before}" != null ]; then
			backup="prestate/${index}"
			cp -p -- "${resolved}" "${transaction_dir}/${backup}" || return 1
			starter_journal_sync "${transaction_dir}/${backup}" || return 1
		fi
		source="$(jq -r '.source // empty' <<<"${operation}")"
		staged=null
		after=null
		if [ -n "${source}" ]; then
			staged="staged/${index}"
			starter_path_existing_file_beneath "${payload_root}" "${source}" >/dev/null || return 1
			cp -p -- "${payload_root}/${source}" "${transaction_dir}/${staged}" || return 1
			after="$(sha256sum "${transaction_dir}/${staged}" | cut -d' ' -f1)"
			[ "${after}" = "$(jq -r '.content_sha256' <<<"${operation}")" ] || {
				starter_journal_error "staged payload digest mismatch"
				return 1
			}
			starter_journal_sync "${transaction_dir}/${staged}" || return 1
		fi
		operations="$(jq -cn --argjson operations "${operations}" --argjson index "${index}" \
			--arg type "$(jq -r '.type' <<<"${operation}")" --arg ownership "$(jq -r '.ownership' <<<"${operation}")" \
			--arg target "${target}" --arg before "${before}" --arg backup "${backup}" \
			--arg after "${after}" --arg staged "${staged}" '
			$operations + [{index:$index,type:$type,ownership:$ownership,target:$target,
				before:{sha256:(if $before == "null" then null else $before end),backup:(if $backup == "null" then null else $backup end)},
				after:{sha256:(if $after == "null" then null else $after end),staged:(if $staged == "null" then null else $staged end)}}]')"
	done
	starter_journal_sync "${transaction_dir}/prestate" || return 1
	starter_journal_sync "${transaction_dir}/staged" || return 1
	journal_file="${transaction_dir}/journal.json"
	temporary="${journal_file}.tmp"
	jq -n --arg root "${physical_root}" --argjson source_result "${source_result}" --argjson plan "${plan}" \
		--arg state_before "${state_before}" --argjson operations "${operations}" \
		'{schema:"gentle-starter.journal/v2",project_root:$root,
			state_before_sha256:(if $state_before == "null" then null else $state_before end),
			source_result:$source_result,plan:$plan,operations:$operations,
			fusion:{contract:"F-manual/v1",status:"applying",pending:[]},progress:{applied:0}}' >"${temporary}" || return 1
	journal_sha="$(jq -cS . "${temporary}" | sha256sum | cut -d' ' -f1)"
	jq --arg sha "${journal_sha}" '.integrity={canonicalization:"jq-sorted-utf8-v1",journal_sha256:$sha}' \
		"${temporary}" >"${temporary}.integrity" || return 1
	mv -f -- "${temporary}.integrity" "${temporary}" || return 1
	chmod 0600 "${temporary}" && mv -f -- "${temporary}" "${journal_file}" || return 1
	starter_journal_sync "${journal_file}" || return 1
	starter_journal_sync "${transaction_dir}" || return 1
	starter_journal_sync "${journal_root}" || return 1
	printf '%s\n' "${journal_file}"
}

starter_transaction_failpoint() {
	[ "${STARTER_TRANSACTION_FAILPOINT:-}" != "$1" ] || return 97
}

starter_journal_replace_source_result() {
	local journal_file="$1" source_result="$2" temporary journal_sha
	temporary="${journal_file}.next"
	jq --argjson source_result "${source_result}" '.source_result=$source_result | del(.integrity)' \
		"${journal_file}" >"${temporary}" || return 1
	journal_sha="$(jq -cS . "${temporary}" | sha256sum | cut -d' ' -f1)"
	jq --arg sha "${journal_sha}" '.integrity={canonicalization:"jq-sorted-utf8-v1",journal_sha256:$sha}' \
		"${temporary}" >"${temporary}.sealed" || return 1
	mv -f -- "${temporary}.sealed" "${journal_file}" && rm -f -- "${temporary}" || return 1
	starter_journal_sync "${journal_file}" && starter_journal_sync "$(dirname "${journal_file}")"
}

starter_transaction_apply() {
	local project_root="$1" journal_file="$2" physical_root transaction_dir count index operation target resolved
	local expected current after staged parent temporary journal_sha
	physical_root="$(starter_path_root "${project_root}")" || return 1
	journal_file="$(starter_journal_validate "${physical_root}" "${journal_file}")" || return 1
	transaction_dir="$(dirname "${journal_file}")"
	count="$(jq '.operations | length' "${journal_file}")"
	for ((index = 0; index < count; index++)); do
		operation="$(jq -c --argjson index "${index}" '.operations[$index]' "${journal_file}")"
		target="$(jq -r '.target' <<<"${operation}")"
		resolved="$(starter_path_resolve_beneath "${physical_root}" "${target}")" || return 1
		expected="$(jq -r '.before.sha256 // "null"' <<<"${operation}")"
		current="$(starter_journal_fingerprint "${resolved}")" || return 1
		[ "${current}" = "${expected}" ] || {
			starter_journal_error "mutation CAS mismatch: ${target}"
			return 1
		}
		after="$(jq -r '.after.sha256 // "null"' <<<"${operation}")"
		if [ "${after}" = null ]; then
			[ "$(starter_journal_fingerprint "${resolved}")" = "${expected}" ] || return 1
			rm -f -- "${resolved}" || return 1
		else
			parent="$(dirname "${resolved}")"
			[ -d "${parent}" ] || {
				starter_journal_error "target parent directory is absent"
				return 1
			}
			staged="${transaction_dir}/$(jq -r '.after.staged' <<<"${operation}")"
			[ "$(sha256sum "${staged}" | cut -d' ' -f1)" = "${after}" ] || return 1
			temporary="$(mktemp "${parent}/.starter-transaction.XXXXXX")" || return 1
			cp -p -- "${staged}" "${temporary}" || {
				rm -f -- "${temporary}"
				return 1
			}
			[ "$(starter_journal_fingerprint "${resolved}")" = "${expected}" ] || {
				rm -f -- "${temporary}"
				starter_journal_error "mutation CAS mismatch: ${target}"
				return 1
			}
			mv -f -- "${temporary}" "${resolved}" || {
				rm -f -- "${temporary}"
				return 1
			}
		fi
		[ "$(starter_journal_fingerprint "${resolved}")" = "${after}" ] || return 1
		starter_journal_sync "$(dirname "${resolved}")" || return 1
		if [ "$(jq -r '.schema' "${journal_file}")" = gentle-starter.journal/v2 ]; then
			jq --argjson applied "$((index + 1))" '.progress.applied=$applied | del(.integrity)' "${journal_file}" >"${journal_file}.next" || return 1
			journal_sha="$(jq -cS . "${journal_file}.next" | sha256sum | cut -d' ' -f1)"
			jq --arg sha "${journal_sha}" '.integrity={canonicalization:"jq-sorted-utf8-v1",journal_sha256:$sha}' \
				"${journal_file}.next" >"${journal_file}.sealed" || return 1
			mv -f -- "${journal_file}.sealed" "${journal_file}" && rm -f -- "${journal_file}.next" || return 1
			starter_journal_sync "${journal_file}" || return 1
		fi
		if [ -n "${STARTER_TRANSACTION_AFTER_OPERATION_HOOK:-}" ]; then
			"${STARTER_TRANSACTION_AFTER_OPERATION_HOOK}" "${index}" "${resolved}" || return $?
		fi
		starter_transaction_failpoint "after-operation-$((index + 1))" || return $?
	done
}

starter_journal_remove() {
	local journal_file="$1" transaction_dir journal_root
	transaction_dir="$(dirname "${journal_file}")"
	journal_root="$(dirname "${transaction_dir}")"
	rm -rf -- "${transaction_dir}" || return 1
	rmdir -- "${journal_root}" 2>/dev/null || true
}

starter_transaction_run() {
	local project_root="$1" source_result="$2" plan="$3" journal_file state apply_status
	journal_file="$(starter_journal_prepare "${project_root}" "${source_result}" "${plan}")" || return 1
	starter_transaction_failpoint after-journal || return $?
	starter_transaction_apply "${project_root}" "${journal_file}" || {
		apply_status=$?
		return "${apply_status}"
	}
	starter_transaction_failpoint before-state || return $?
	state="$(starter_state_build "${project_root}" "${source_result}" "${plan}")" || return 1
	starter_state_persist "${project_root}" "${state}" || return 1
	starter_transaction_failpoint after-state || return $?
	starter_journal_remove "${journal_file}"
}
