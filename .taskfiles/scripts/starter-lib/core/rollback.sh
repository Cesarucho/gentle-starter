#!/usr/bin/env bash
# Fail-closed recovery for CAS-provable transaction-owned paths.

STARTER_ROLLBACK_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.taskfiles/scripts/starter-lib/core/journal.sh
source "${STARTER_ROLLBACK_CORE_DIR}/journal.sh"

starter_rollback_error() {
	printf 'starter rollback: %s\n' "$*" >&2
}

starter_rollback_restore() {
	local resolved="$1" expected_current="$2" before="$3" backup="$4"
	local parent temporary actual
	actual="$(starter_journal_fingerprint "${resolved}")" || return 1
	[ "${actual}" = "${expected_current}" ] || return 1
	if [ "${before}" = null ]; then
		rm -f -- "${resolved}" || return 1
	else
		[ -f "${backup}" ] && [ "$(sha256sum "${backup}" | cut -d' ' -f1)" = "${before}" ] || return 1
		parent="$(dirname "${resolved}")"
		temporary="$(mktemp "${parent}/.starter-rollback.XXXXXX")" || return 1
		cp -p -- "${backup}" "${temporary}" || {
			rm -f -- "${temporary}"
			return 1
		}
		[ "$(starter_journal_fingerprint "${resolved}")" = "${expected_current}" ] || {
			rm -f -- "${temporary}"
			return 1
		}
		if [ "${expected_current}" = null ]; then
			mv -n -- "${temporary}" "${resolved}" || {
				rm -f -- "${temporary}"
				return 1
			}
		else
			mv -f -- "${temporary}" "${resolved}" || {
				rm -f -- "${temporary}"
				return 1
			}
		fi
	fi
	[ "$(starter_journal_fingerprint "${resolved}")" = "${before}" ] || return 1
	starter_journal_sync "$(dirname "${resolved}")"
}

starter_rollback_recover() {
	local project_root="$1" journal_file="$2" physical_root transaction_dir count index operation
	local target resolved before after current backup ambiguous=0 state_file state_before expected_state
	physical_root="$(starter_path_root "${project_root}")" || return 1
	journal_file="$(starter_journal_validate "${physical_root}" "${journal_file}")" || return 1
	transaction_dir="$(dirname "${journal_file}")"
	state_file="${physical_root}/.starter/state.json"
	state_before="$(jq -r '.state_before_sha256 // "null"' "${journal_file}")"
	current="$(starter_journal_fingerprint "${state_file}")" || return 1
	if [ "${current}" != "${state_before}" ]; then
		expected_state="$(starter_state_build "${physical_root}" \
			"$(jq -c '.source_result' "${journal_file}")" "$(jq -c '.plan' "${journal_file}")")" || {
			starter_rollback_error "state transition is ambiguous; journal retained at ${journal_file}"
			return 1
		}
		if [ "$(jq -cS . "${state_file}" 2>/dev/null)" = "$(jq -cS . <<<"${expected_state}")" ]; then
			starter_journal_remove "${journal_file}"
			return
		fi
		starter_rollback_error "state transition is ambiguous; journal retained at ${journal_file}"
		return 1
	fi
	count="$(jq '.operations | length' "${journal_file}")"
	for ((index = count - 1; index >= 0; index--)); do
		operation="$(jq -c --argjson index "${index}" '.operations[$index]' "${journal_file}")"
		target="$(jq -r '.target' <<<"${operation}")"
		resolved="$(starter_path_resolve_beneath "${physical_root}" "${target}")" || {
			ambiguous=1
			continue
		}
		before="$(jq -r '.before.sha256 // "null"' <<<"${operation}")"
		after="$(jq -r '.after.sha256 // "null"' <<<"${operation}")"
		current="$(starter_journal_fingerprint "${resolved}")" || {
			ambiguous=1
			continue
		}
		if [ "${current}" = "${before}" ]; then
			continue
		fi
		if [ "${current}" != "${after}" ]; then
			starter_rollback_error "ambiguous concurrent change retained: ${target}"
			ambiguous=1
			continue
		fi
		backup="$(jq -r '.before.backup // empty' <<<"${operation}")"
		[ -z "${backup}" ] || backup="${transaction_dir}/${backup}"
		if ! starter_rollback_restore "${resolved}" "${after}" "${before}" "${backup}"; then
			starter_rollback_error "ambiguous recovery failure retained: ${target}"
			ambiguous=1
		fi
	done
	if [ "${ambiguous}" -ne 0 ]; then
		starter_rollback_error "recovery is ambiguous; journal retained at ${journal_file}"
		return 1
	fi
	starter_journal_remove "${journal_file}" || {
		starter_rollback_error "recovery completed but journal cleanup failed"
		return 1
	}
}
