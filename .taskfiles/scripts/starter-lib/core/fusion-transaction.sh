#!/usr/bin/env bash
# Durable, CAS-safe F-manual/v1 resolution transactions.

STARTER_F_PATHS=(.devcontainer/devcontainer.json .devcontainer/docker-compose.yml)

starter_f_sha() {
	local path="$1"
	if [ ! -f "${path}" ] || [ -L "${path}" ]; then
		printf 'null\n'
		return
	fi
	sha256sum "${path}" | cut -d' ' -f1
}

starter_f_sync() { sync -f "$1" 2>/dev/null; }

starter_f_seal_journal() {
	local journal="$1" temporary sha
	temporary="$(mktemp "$(dirname "${journal}")/.journal.XXXXXX")" || return 1
	jq 'del(.integrity)' "${journal}" >"${temporary}" || return 1
	sha="$(jq -cS . "${temporary}" | sha256sum | cut -d' ' -f1)"
	jq --arg sha "${sha}" '.integrity={canonicalization:"jq-sorted-utf8-v1",journal_sha256:$sha}' "${temporary}" >"${temporary}.sealed" || return 1
	mv -f -- "${temporary}.sealed" "${journal}" && rm -f -- "${temporary}"
	starter_f_sync "${journal}" && starter_f_sync "$(dirname "${journal}")"
}

starter_f_validate_journal() {
	local root="$1" journal="$2" expected actual count index path proposal prestate
	case "${journal}" in "${root}/.starter/journals/"*/journal.json) ;; *) return 1 ;; esac
	jq -e --arg root "${root}" '
		type == "object" and .schema == "gentle-starter.journal/v2" and .project_root == $root and
		.fusion.contract == "F-manual/v1" and (.fusion.status == "pending" or .fusion.status == "applying") and
		(.fusion.pending | type == "array" and length > 0) and (.progress.applied | type == "number" and . >= 0) and
		(.integrity.canonicalization == "jq-sorted-utf8-v1") and (.integrity.journal_sha256 | test("^[0-9a-f]{64}$"))
	' "${journal}" >/dev/null || return 1
	expected="$(jq -r '.integrity.journal_sha256' "${journal}")"
	actual="$(jq -cS 'del(.integrity)' "${journal}" | sha256sum | cut -d' ' -f1)"
	[ "${expected}" = "${actual}" ] || return 1
	count="$(jq '.fusion.pending | length' "${journal}")"
	[ "$(jq -r '.progress.applied' "${journal}")" -le "${count}" ] || return 1
	for ((index = 0; index < count; index++)); do
		path="$(jq -r ".fusion.pending[${index}].path" "${journal}")"
		case "${path}" in .devcontainer/devcontainer.json | .devcontainer/docker-compose.yml) ;; *) return 1 ;; esac
		proposal="$(dirname "${journal}")/$(jq -r ".fusion.pending[${index}].proposal" "${journal}")"
		prestate="$(dirname "${journal}")/$(jq -r ".fusion.pending[${index}].prestate" "${journal}")"
		[ "$(starter_f_sha "${proposal}")" = "$(jq -r ".fusion.pending[${index}].theirs_sha256" "${journal}")" ] || return 1
		[ "$(starter_f_sha "${prestate}")" = "$(jq -r ".fusion.pending[${index}].ours_sha256" "${journal}")" ] || return 1
	done
}

starter_f_pending_journal() {
	local root="$1"
	local journals=("${root}"/.starter/journals/*/journal.json)
	[ "${#journals[@]}" -eq 1 ] && [ -f "${journals[0]}" ] || return 1
	starter_f_validate_journal "${root}" "${journals[0]}" || return 1
	printf '%s\n' "${journals[0]}"
}

starter_f_prepare_conflicts() {
	local root="$1" release="$2" base_root="$3" theirs_root="$4" transaction journal path count=0
	local base ours theirs proposal prestate entries='[]' state_before
	transaction="$(mktemp -d "${root}/.starter/journals/f-manual.XXXXXX")" || return 1
	mkdir -p "${transaction}/proposed" "${transaction}/prestate" "${transaction}/staged"
	for path in "${STARTER_F_PATHS[@]}"; do
		base="$(starter_f_sha "${base_root}/${path}")"
		ours="$(starter_f_sha "${root}/${path}")"
		theirs="$(starter_f_sha "${theirs_root}/${path}")"
		if [ "${ours}" = "${base}" ] || [ "${theirs}" = "${base}" ]; then continue; fi
		if [ "${ours}" = null ] || [ "${theirs}" = null ]; then
			rm -rf -- "${transaction}"
			return 1
		fi
		proposal="proposed/${path}"
		prestate="prestate/${path}"
		mkdir -p "${transaction}/$(dirname "${proposal}")" "${transaction}/$(dirname "${prestate}")"
		cp -p -- "${theirs_root}/${path}" "${transaction}/${proposal}" && cp -p -- "${root}/${path}" "${transaction}/${prestate}" || return 1
		entries="$(jq -cn --argjson entries "${entries}" --arg path "${path}" --arg base "${base}" --arg ours "${ours}" --arg theirs "${theirs}" --arg proposal "${proposal}" --arg prestate "${prestate}" '$entries+[{path:$path,base_sha256:$base,ours_sha256:$ours,theirs_sha256:$theirs,proposal:$proposal,prestate:$prestate}]')"
		count=$((count + 1))
	done
	[ "${count}" -gt 0 ] || {
		rm -rf -- "${transaction}"
		return 2
	}
	state_before="$(starter_f_sha "${root}/.starter/state.json")"
	journal="${transaction}/journal.json"
	jq -n --arg root "${root}" --arg release "${release}" --arg state "${state_before}" --argjson pending "${entries}" '{schema:"gentle-starter.journal/v2",project_root:$root,target_release:$release,state_before_sha256:$state,fusion:{contract:"F-manual/v1",status:"pending",pending:$pending},progress:{applied:0}}' >"${journal}"
	starter_f_seal_journal "${journal}" || return 1
	printf '%s\n' "${journal}"
}

starter_f_require_clean_except_pending() {
	local root="$1" journal="$2" status path current before after
	while IFS= read -r status; do
		[ -n "${status}" ] || continue
		path="${status:3}"
		case "${path}" in .starter/journals/*) continue ;; esac
		if jq -e 'has("source_result")' "${journal}" >/dev/null 2>&1; then
			case "${path}" in ".starter/evidence/releases/$(jq -r '.plan.target_release.version' "${journal}")" | \
				".starter/evidence/releases/$(jq -r '.plan.target_release.version' "${journal}")/"*) continue ;; esac
			if jq -e --arg path "${path}" 'any(.operations[]; .target == $path)' "${journal}" >/dev/null; then
				current="$(starter_f_sha "${root}/${path}")"
				before="$(jq -r --arg path "${path}" '.operations[] | select(.target == $path) | .before.sha256 // "null"' "${journal}")"
				after="$(jq -r --arg path "${path}" '.operations[] | select(.target == $path) | .after.sha256 // "null"' "${journal}")"
				if [ "${current}" = "${before}" ] || [ "${current}" = "${after}" ]; then continue; fi
			fi
		fi
		jq -e --arg path "${path}" 'any(.fusion.pending[]; .path == $path)' "${journal}" >/dev/null || return 1
	done < <(git -C "${root}" status --porcelain=v1 --untracked-files=all)
}

starter_f_atomic_copy() {
	local source="$1" target="$2" expected="$3" temporary
	[ "$(starter_f_sha "${target}")" = "${expected}" ] || return 1
	temporary="$(mktemp "$(dirname "${target}")/.starter-f.XXXXXX")" || return 1
	if ! cp -p -- "${source}" "${temporary}" || [ "$(starter_f_sha "${target}")" != "${expected}" ] || ! mv -f -- "${temporary}" "${target}"; then
		rm -f -- "${temporary}"
		return 1
	fi
	starter_f_sync "$(dirname "${target}")"
}

starter_f_promote_combined_journal() {
	local journal="$1" transaction pending count index path operation_index proposal prestate entries='[]'
	transaction="$(dirname "${journal}")"
	pending="$(jq -c '.plan.fusion.pending' "${journal}")" || return 1
	count="$(jq 'length' <<<"${pending}")"
	[ "${count}" -gt 0 ] || return 2
	for ((index = 0; index < count; index++)); do
		path="$(jq -r ".[$index].path" <<<"${pending}")"
		operation_index="$(jq -r --arg path "${path}" '.operations[] | select(.target == $path) | .index' "${journal}")"
		[[ "${operation_index}" =~ ^[0-9]+$ ]] || return 1
		proposal="$(jq -r --argjson index "${operation_index}" '.operations[] | select(.index == $index) | .after.staged' "${journal}")"
		prestate="$(jq -r --argjson index "${operation_index}" '.operations[] | select(.index == $index) | .before.backup' "${journal}")"
		[ -n "${proposal}" ] && [ "${proposal}" != null ] && [ -n "${prestate}" ] && [ "${prestate}" != null ] || return 1
		entries="$(jq -cn --argjson entries "${entries}" --argjson pending_entry "$(jq -c ".[$index]" <<<"${pending}")" \
			--arg proposal "${proposal}" --arg prestate "${prestate}" --argjson operation_index "${operation_index}" \
			'$entries + [$pending_entry + {proposal:$proposal,prestate:$prestate,operation_index:$operation_index}]')"
	done
	jq --argjson entries "${entries}" '.schema="gentle-starter.journal/v2" |
		.fusion={contract:"F-manual/v1",status:"pending",pending:$entries} | .progress={applied:0} |
		.target_release=.plan.target_release.version | del(.integrity)' "${journal}" >"${journal}.next" || return 1
	mv -f -- "${journal}.next" "${journal}" && starter_f_seal_journal "${journal}" || return 1
	starter_f_validate_journal "$(jq -r '.project_root' "${journal}")" "${journal}"
}

starter_f_combined_resume() {
	local root="$1" action="$2" journal="$3" transaction count index operation_index source staged expected state target_version status=0
	transaction="$(dirname "${journal}")"
	target_version="$(jq -r '.plan.target_release.version' "${journal}")"
	starter_f_require_clean_except_pending "${root}" "${journal}" || return 1
	case "${action}" in
	abort)
		if [ "$(jq -r '.progress.applied' "${journal}")" -gt 0 ]; then
			starter_rollback_recover "${root}" "${journal}" || return 1
		else
			rm -rf -- "${root}/.starter/evidence/releases/$(jq -r '.plan.target_release.version' "${journal}")"
			starter_journal_remove "${journal}"
		fi
		printf 'starter: pending combined update aborted; operation-owned states restored\n'
		return
		;;
	take-starter | keep-project | continue) ;;
	*) return 1 ;;
	esac
	count="$(jq '.fusion.pending | length' "${journal}")"
	for ((index = 0; index < count; index++)); do
		operation_index="$(jq -r ".fusion.pending[$index].operation_index" "${journal}")"
		staged="${transaction}/$(jq -r --argjson operation_index "${operation_index}" '.operations[] | select(.index == $operation_index) | .after.staged' "${journal}")"
		expected="$(jq -r ".fusion.pending[$index].ours_sha256" "${journal}")"
		case "${action}" in
		take-starter) source="${transaction}/$(jq -r ".fusion.pending[$index].proposal" "${journal}")" ;;
		keep-project) source="${transaction}/$(jq -r ".fusion.pending[$index].prestate" "${journal}")" ;;
		continue)
			source="${root}/$(jq -r ".fusion.pending[$index].path" "${journal}")"
			cp -p -- "${source}" "${transaction}/$(jq -r ".fusion.pending[$index].prestate" "${journal}")" || return 1
			expected="$(starter_f_sha "${source}")"
			;;
		esac
		[ -f "${source}" ] && [ ! -L "${source}" ] || return 1
		if [ "${action}" != continue ]; then
			[ "$(starter_f_sha "${root}/$(jq -r ".fusion.pending[$index].path" "${journal}")")" = "${expected}" ] || return 1
		fi
		cp -p -- "${source}" "${staged}.next" && mv -f -- "${staged}.next" "${staged}" || return 1
		jq --argjson operation_index "${operation_index}" --arg sha "$(starter_f_sha "${staged}")" --arg expected "${expected}" '
			(.operations[] | select(.index == $operation_index) | .after.sha256)=$sha |
			(.operations[] | select(.index == $operation_index) | .before.sha256)=$expected | del(.integrity)' \
			"${journal}" >"${journal}.next" && mv -f -- "${journal}.next" "${journal}" && starter_f_seal_journal "${journal}" || return 1
	done
	jq '.fusion.status="applying" | del(.integrity)' "${journal}" >"${journal}.next" && mv -f -- "${journal}.next" "${journal}" && starter_f_seal_journal "${journal}" || return 1
	starter_transaction_apply "${root}" "${journal}" || status=$?
	if [ "${status}" -eq 0 ]; then
		state="$(starter_state_build "${root}" "$(jq -c '.source_result' "${journal}")" "$(jq -c '.plan' "${journal}")")" || status=$?
	fi
	[ "${status}" -ne 0 ] || starter_state_persist "${root}" "${state}" || status=$?
	[ "${status}" -ne 0 ] || starter_journal_remove "${journal}" || status=$?
	if [ "${status}" -ne 0 ]; then
		if starter_rollback_recover "${root}" "${journal}"; then
			rm -rf -- "${root}/.starter/evidence/releases/${target_version}"
		fi
		return "${status}"
	fi
	printf 'starter: resolved and applied combined managed/F-manual update with %s\n' "${action}"
}

starter_f_rollback_applied() {
	local root="$1" journal="$2" transaction count index path before after prestate ambiguous=0
	transaction="$(dirname "${journal}")"
	count="$(jq -r '.progress.applied' "${journal}")"
	for ((index = count - 1; index >= 0; index--)); do
		path="$(jq -r ".fusion.pending[${index}].path" "${journal}")"
		before="$(jq -r ".fusion.pending[${index}].ours_sha256" "${journal}")"
		after="$(jq -r ".fusion.pending[${index}].accepted_sha256" "${journal}")"
		prestate="${transaction}/$(jq -r ".fusion.pending[${index}].prestate" "${journal}")"
		if [ "${before}" = "${after}" ] || [ "$(jq -r ".fusion.pending[${index}].mutation_owned // true" "${journal}")" = false ]; then
			continue
		elif [ "$(starter_f_sha "${root}/${path}")" = "${after}" ]; then
			starter_f_atomic_copy "${prestate}" "${root}/${path}" "${after}" || ambiguous=1
		elif [ "$(starter_f_sha "${root}/${path}")" != "${before}" ]; then ambiguous=1; fi
	done
	[ "${ambiguous}" -eq 0 ]
}

starter_f_transaction_resume() {
	local root="$1" action="$2" journal transaction count index path ours source staged accepted='[]' state state_sha state_expected status=0
	journal="$(starter_f_pending_journal "${root}")" || {
		printf 'starter F-manual: no valid pending transaction\n' >&2
		return 1
	}
	if jq -e 'has("source_result") and has("operations")' "${journal}" >/dev/null; then
		starter_f_combined_resume "${root}" "${action}" "${journal}"
		return
	fi
	transaction="$(dirname "${journal}")"
	starter_f_require_clean_except_pending "${root}" "${journal}" || return 1
	case "${action}" in abort)
		starter_f_rollback_applied "${root}" "${journal}" || return 1
		rm -rf -- "${transaction}"
		return
		;;
	take-starter | keep-project | continue) ;; *) return 1 ;; esac
	count="$(jq '.fusion.pending | length' "${journal}")"
	for ((index = 0; index < count; index++)); do
		path="$(jq -r ".fusion.pending[${index}].path" "${journal}")"
		ours="$(jq -r ".fusion.pending[${index}].ours_sha256" "${journal}")"
		case "${action}" in take-starter)
			source="${transaction}/$(jq -r ".fusion.pending[${index}].proposal" "${journal}")"
			[ "$(starter_f_sha "${root}/${path}")" = "${ours}" ] || return 1
			;;
		keep-project)
			source="${transaction}/$(jq -r ".fusion.pending[${index}].prestate" "${journal}")"
			[ "$(starter_f_sha "${root}/${path}")" = "${ours}" ] || return 1
			;;
		continue)
			source="${root}/${path}"
			[ -f "${source}" ] && [ ! -L "${source}" ] || return 1
			;;
		esac
		staged="${transaction}/staged/${index}"
		cp -p -- "${source}" "${staged}" || return 1
		jq --argjson index "${index}" --arg sha "$(starter_f_sha "${staged}")" --arg expected "$(starter_f_sha "${root}/${path}")" \
			'.fusion.pending[$index].accepted_sha256=$sha | .fusion.pending[$index].apply_expected_sha256=$expected |
			.fusion.pending[$index].mutation_owned=($sha != $expected)' "${journal}" >"${journal}.next" && mv -f -- "${journal}.next" "${journal}" && starter_f_seal_journal "${journal}" || return 1
	done
	jq '.fusion.status="applying"' "${journal}" >"${journal}.next" && mv -f -- "${journal}.next" "${journal}" && starter_f_seal_journal "${journal}" || return 1
	for ((index = 0; index < count; index++)); do
		path="$(jq -r ".fusion.pending[${index}].path" "${journal}")"
		ours="$(jq -r ".fusion.pending[${index}].apply_expected_sha256" "${journal}")"
		staged="${transaction}/staged/${index}"
		starter_f_atomic_copy "${staged}" "${root}/${path}" "${ours}" || {
			status=$?
			break
		}
		accepted="$(jq -cn --argjson accepted "${accepted}" --arg path "${path}" --arg sha "$(starter_f_sha "${root}/${path}")" --arg mode "$(stat -c '%a' "${root}/${path}")" '$accepted+[{path:$path,presence:"present",sha256:$sha,mode:$mode}]')"
		if ! jq --argjson applied "$((index + 1))" '.progress.applied=$applied' "${journal}" >"${journal}.next" ||
			! mv -f -- "${journal}.next" "${journal}" || ! starter_f_seal_journal "${journal}"; then
			status=1
			break
		fi
		[ "${STARTER_F_FAILPOINT:-}" != "after-write-$((index + 1))" ] || {
			status=97
			break
		}
	done
	if [ "${status}" -ne 0 ]; then
		starter_f_rollback_applied "${root}" "${journal}" || true
		return "${status}"
	fi
	state_expected="$(jq -r '.state_before_sha256' "${journal}")"
	[ "$(starter_f_sha "${root}/.starter/state.json")" = "${state_expected}" ] || {
		starter_f_rollback_applied "${root}" "${journal}" || true
		return 1
	}
	if [ -f "${root}/.starter/state.json" ]; then state="$(jq --arg release "$(jq -r '.target_release' "${journal}")" --argjson accepted "${accepted}" 'del(.integrity)|.schema="gentle-starter.state/v2"|.release.version=$release|.fusion={contract:"F-manual/v1",accepted:$accepted}' "${root}/.starter/state.json")"; else state="$(jq -n --arg release "$(jq -r '.target_release' "${journal}")" --argjson accepted "${accepted}" '{schema:"gentle-starter.state/v2",release:{version:$release},fusion:{contract:"F-manual/v1",accepted:$accepted}}')"; fi
	state_sha="$(jq -cS . <<<"${state}" | sha256sum | cut -d' ' -f1)"
	jq -n --argjson state "${state}" --arg sha "${state_sha}" '$state+{integrity:{canonicalization:"jq-sorted-utf8-v1",state_sha256:$sha}}' >"${transaction}/staged/state.json"
	starter_f_atomic_copy "${transaction}/staged/state.json" "${root}/.starter/state.json" "${state_expected}" || {
		starter_f_rollback_applied "${root}" "${journal}" || true
		return 1
	}
	rm -rf -- "${transaction}"
	printf 'starter: resolved all pending F-manual conflicts with %s\n' "${action}"
}
