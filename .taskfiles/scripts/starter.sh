#!/usr/bin/env bash
# Public composition root for starter adoption, inspection, and updates.
# ShellCheck cannot follow SCRIPT_DIR-based repository sources without -x.
# shellcheck disable=SC1091
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/starter-lib/adapters/git-tag-source.sh"
source "${SCRIPT_DIR}/starter-lib/adapters/git-repository-status.sh"
source "${SCRIPT_DIR}/starter-lib/adapters/canonical-remote.sh"
source "${SCRIPT_DIR}/starter-lib/core/planner-v2.sh"
source "${SCRIPT_DIR}/starter-lib/core/rollback.sh"
source "${SCRIPT_DIR}/starter-lib/core/fusion-transaction.sh"

STARTER_REPOSITORY_STATUS_IMPL="${STARTER_REPOSITORY_STATUS_IMPL:-git_repository_status_inspect}"

readonly STARTER_USAGE_EXIT=64
readonly STARTER_OFFICIAL_SOURCE_URL='https://github.com/Cesarucho/gentle-starter.git'
STARTER_BLOCKER_COUNT=0
STARTER_UPDATE_PROJECT=""

starter_usage() {
	cat >&2 <<'EOF'
Usage:
  starter.sh adopt  --release starter/vX.Y.Z [--source URL] [--project-root PATH]
  starter.sh check  [--release starter/vX.Y.Z] [--source URL] [--project-root PATH]
  starter.sh update [--release starter/vX.Y.Z] [--yes] [--source URL] [--project-root PATH]

Source defaults to https://github.com/Cesarucho/gentle-starter.git.

Exit status: 0 success, 1 blocked or failed, 64 invalid command usage.
EOF
}

starter_blocker() {
	STARTER_BLOCKER_COUNT=$((STARTER_BLOCKER_COUNT + 1))
	printf 'BLOCKER %s: %s\n' "$1" "$2" >&2
}

starter_parse_args() {
	STARTER_COMMAND="${1:-}"
	shift || true
	STARTER_PROJECT_ROOT="$(pwd -P)"
	STARTER_SOURCE_URL="${STARTER_OFFICIAL_SOURCE_URL}"
	STARTER_SOURCE_EXPLICIT=0
	STARTER_RELEASE=""
	STARTER_CONFIRMED=0
	STARTER_F_ACTION=""
	case "${STARTER_COMMAND}" in adopt | check | update) ;; *)
		starter_usage
		return "${STARTER_USAGE_EXIT}"
		;;
	esac
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--project-root | --source | --release)
			if [ "$#" -lt 2 ] || [ -z "$2" ]; then
				starter_usage
				return "${STARTER_USAGE_EXIT}"
			fi
			case "$1" in
			--project-root) STARTER_PROJECT_ROOT="$2" ;;
			--source)
				STARTER_SOURCE_URL="$2"
				STARTER_SOURCE_EXPLICIT=1
				;;
			--release) STARTER_RELEASE="$2" ;;
			esac
			shift 2
			;;
		--yes)
			STARTER_CONFIRMED=1
			shift
			;;
		--take-starter | --keep-project | --continue | --abort)
			[ -z "${STARTER_F_ACTION}" ] || {
				printf 'starter: F-manual resolution flags are mutually exclusive\n' >&2
				return "${STARTER_USAGE_EXIT}"
			}
			STARTER_F_ACTION="${1#--}"
			shift
			;;
		*)
			starter_usage
			return "${STARTER_USAGE_EXIT}"
			;;
		esac
	done
	if [ -z "${STARTER_RELEASE}" ] && [ "${STARTER_COMMAND}" = adopt ]; then
		starter_usage
		return "${STARTER_USAGE_EXIT}"
	fi
	[ -z "${STARTER_F_ACTION}" ] || [ "${STARTER_COMMAND}" = update ] || return "${STARTER_USAGE_EXIT}"
	if [ "${STARTER_COMMAND}" = update ] && [ -z "${STARTER_RELEASE}" ] && [ "${STARTER_CONFIRMED}" -eq 1 ]; then
		printf 'starter: --yes requires an exact --release\n' >&2
		return "${STARTER_USAGE_EXIT}"
	fi
	[ -z "${STARTER_RELEASE}" ] || [[ "${STARTER_RELEASE}" =~ ^starter/v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
		starter_usage
		return "${STARTER_USAGE_EXIT}"
	}
	STARTER_PROJECT_ROOT="$(starter_path_root "${STARTER_PROJECT_ROOT}")" || return "${STARTER_USAGE_EXIT}"
	if [ "${STARTER_SOURCE_EXPLICIT}" -eq 0 ] && [ -f "${STARTER_PROJECT_ROOT}/.starter/source.json" ]; then
		STARTER_SOURCE_URL="$(starter_canonical_remote_query "${STARTER_PROJECT_ROOT}")" || return 1
	fi
}

starter_cache_candidate() {
	local project_id source_id release_id cache_root
	project_id="$(printf '%s' "${STARTER_PROJECT_ROOT}" | sha256sum | cut -d' ' -f1)"
	source_id="$(printf '%s' "${STARTER_SOURCE_URL}" | sha256sum | cut -d' ' -f1)"
	release_id="${STARTER_RELEASE#starter/v}"
	cache_root="${STARTER_CACHE_DIR:-${XDG_STATE_HOME:-${HOME}/.local/state}/gentle-starter}"
	printf '%s/%s/%s/%s\n' "${cache_root}" "${project_id}" "${source_id}" "${release_id}"
}

starter_retained_candidate() {
	printf '%s/.starter/evidence/releases/%s\n' "${STARTER_PROJECT_ROOT}" "${STARTER_RELEASE#starter/v}"
}

starter_bind_candidate_evidence() {
	local candidate="$1" evidence_ref envelope_sha
	evidence_ref="$(starter_retained_candidate)/evidence"
	envelope_sha="$(jq -cS --arg ref "${evidence_ref}" \
		'.evidence.ref=$ref | del(.integrity)' "${candidate}/envelope.json" | sha256sum | cut -d' ' -f1)"
	jq --arg ref "${evidence_ref}" --arg sha "${envelope_sha}" \
		'.evidence.ref=$ref | .integrity={canonicalization:"jq-sorted-utf8-v1",envelope_sha256:$sha}' \
		"${candidate}/envelope.json" >"${candidate}/envelope.tmp" || return 1
	mv -f -- "${candidate}/envelope.tmp" "${candidate}/envelope.json" || return 1
	release_payload_validate "${candidate}/envelope.json" "${candidate}/materialized"
}

starter_acquire_candidate() (
	local candidate parent request temporary result evidence selector
	candidate="$(starter_cache_candidate)"
	if [ -d "${candidate}" ]; then
		evidence="${candidate}/evidence"
		selector="$(jq -r '.selector // empty' "${evidence}/index.json" 2>/dev/null)"
		[ "${selector}" = "${STARTER_RELEASE}" ] || {
			printf 'cached release selector mismatch\n' >&2
			return 1
		}
		STARTER_EVIDENCE_REVALIDATE_IMPL=git_tag_evidence_revalidate evidence_revalidate "${evidence}" >/dev/null || return 1
		starter_bind_candidate_evidence "${candidate}" || return 1
		jq -cn --arg envelope_file "${candidate}/envelope.json" --arg payload_root "${candidate}/materialized" \
			'{envelope_file:$envelope_file,payload_root:$payload_root}'
		return
	fi
	parent="$(dirname "${candidate}")"
	mkdir -p "${parent}" || return 1
	request="$(mktemp "${parent}/request.XXXXXX.json")" || return 1
	temporary="${candidate}.candidate.$$"
	trap 'rm -f -- "${request:-}"; rm -rf -- "${temporary:-}"' EXIT
	jq -n --arg remote "${STARTER_SOURCE_URL}" --arg selector "${STARTER_RELEASE}" \
		--arg output "${temporary}" '{
		schema:"gentle-starter.git-tag-source-request/v1",source_id:"gentle-starter",
		remote:$remote,selector:$selector,output_dir:$output
	}' >"${request}" || return 1
	result="$(STARTER_SOURCE_ACQUIRE_IMPL=git_tag_source_acquire source_acquire "${request}")" || return 1
	[ "$(jq -r '.envelope_file' <<<"${result}")" = "${temporary}/envelope.json" ] || return 1
	mv -- "${temporary}" "${candidate}" || return 1
	temporary=""
	starter_bind_candidate_evidence "${candidate}" || return 1
	jq -cn --arg envelope_file "${candidate}/envelope.json" --arg payload_root "${candidate}/materialized" \
		'{envelope_file:$envelope_file,payload_root:$payload_root}'
)

starter_retain_candidate() {
	local source_result="$1" source_root destination parent temporary
	source_root="$(dirname "$(jq -r '.envelope_file' <<<"${source_result}")")"
	destination="$(starter_retained_candidate)"
	parent="$(dirname "${destination}")"
	[ ! -e "${destination}" ] || {
		printf 'retained release evidence already exists' >&2
		return 1
	}
	mkdir -p "${parent}" || return 1
	temporary="$(mktemp -d "${parent}/.candidate.XXXXXX")" || return 1
	if ! cp -a "${source_root}/." "${temporary}/" || ! mv -- "${temporary}" "${destination}"; then
		rm -rf -- "${temporary}" "${destination}"
		return 1
	fi
	starter_journal_sync "${destination}" || return 1
	starter_journal_sync "${parent}" || return 1
	jq -cn --arg envelope_file "${destination}/envelope.json" --arg payload_root "${destination}/materialized" \
		'{envelope_file:$envelope_file,payload_root:$payload_root}'
}

starter_remove_retained_candidate() {
	local destination parent
	destination="$(starter_retained_candidate)"
	parent="$(dirname "${destination}")"
	rm -rf -- "${destination}"
	rmdir -- "${parent}" "$(dirname "${parent}")" 2>/dev/null || true
}

starter_state_validate_marker() {
	local marker="$1" expected actual
	[ -f "${marker}" ] || {
		printf 'adoption marker is missing'
		return 1
	}
	jq -e '
		type == "object" and .schema == "gentle-starter.state/v2" and
		(.source.adapter_id | type == "string") and (.release.version | type == "string") and
		(.managed_fingerprints | type == "array") and (.evidence.ref | type == "string" and length > 0) and
		(.integrity == {canonicalization:"jq-sorted-utf8-v1",state_sha256:.integrity.state_sha256}) and
		(.integrity.state_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
	' "${marker}" >/dev/null || {
		printf 'adoption marker is invalid'
		return 1
	}
	expected="$(jq -r '.integrity.state_sha256' "${marker}")"
	actual="$(jq -cS 'del(.integrity)' "${marker}" | sha256sum | cut -d' ' -f1)"
	[ "${expected}" = "${actual}" ] || {
		printf 'adoption marker integrity mismatch'
		return 1
	}
	[ "$(jq -r '.source.adapter_id' "${marker}")" = GitTagSource/v1 ] || {
		printf 'state source adapter is unsupported'
		return 1
	}
}

starter_state_revalidate_evidence() {
	local marker="$1" source_result envelope
	source_result="$(STARTER_EVIDENCE_REVALIDATE_IMPL=git_tag_evidence_revalidate \
		evidence_revalidate "$(jq -r '.evidence.ref' "${marker}")")" || return 1
	envelope="$(jq -r '.envelope_file' <<<"${source_result}")"
	jq -e --slurpfile envelope "${envelope}" '
		.source == $envelope[0].source and .release == $envelope[0].release and
		.immutable_identities == $envelope[0].immutable_identities and
		.envelope == {schema:$envelope[0].schema,sha256:$envelope[0].integrity.envelope_sha256} and
		.manifest == {schema:$envelope[0].manifest.schema,sha256:$envelope[0].manifest.sha256} and
		.evidence == $envelope[0].evidence
	' "${marker}" >/dev/null || {
		printf 'retained evidence does not match state' >&2
		return 1
	}
	printf '%s\n' "${source_result}"
}

starter_state_drift() {
	local marker="$1" count index path expected resolved actual drift=''
	count="$(jq '.managed_fingerprints | length' "${marker}")"
	for ((index = 0; index < count; index++)); do
		[ "$(jq -r ".managed_fingerprints[${index}].ownership" "${marker}")" = managed ] || continue
		path="$(jq -r ".managed_fingerprints[${index}].path" "${marker}")"
		expected="$(jq -r ".managed_fingerprints[${index}].sha256 // \"null\"" "${marker}")"
		resolved="$(starter_path_resolve_beneath "${STARTER_PROJECT_ROOT}" "${path}" 2>/dev/null)" || {
			drift="${drift}${drift:+, }${path} (unsafe)"
			continue
		}
		actual="$(starter_journal_fingerprint "${resolved}" 2>/dev/null)" || actual=unsafe
		[ "${actual}" = "${expected}" ] || drift="${drift}${drift:+, }${path}"
	done
	[ -z "${drift}" ] || {
		printf '%s' "${drift}"
		return 1
	}
}

starter_build_plan() {
	local source_result="$1" current_version="$2"
	(cd "${STARTER_PROJECT_ROOT}" && starter_plan_v2_build "${source_result}" "${current_version}")
}

starter_version_is_ahead() {
	[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | sed -n '$p')" = "$1" ] && [ "$1" != "$2" ]
}

starter_plan_summary() {
	local plan="$1"
	printf 'starter: plan has %s migrations and %s operations (managed: %s, fusion: %s)\n' \
		"$(jq '.migration_ids | length' <<<"${plan}")" \
		"$(jq '.operations | length' <<<"${plan}")" \
		"$(jq '.ownership_summary.managed' <<<"${plan}")" \
		"$(jq '.ownership_summary.fusion' <<<"${plan}")"
}

starter_freeze_candidate() {
	local candidate="$1" plan="$2" root evidence
	root="$(dirname "$(jq -r '.envelope_file' <<<"${candidate}")")"
	evidence="${root}/evidence/index.json"
	jq -cn --arg selector "${STARTER_RELEASE}" --arg root "${root}" \
		--arg tag "$(jq -r '.tag_oid' "${evidence}")" --arg commit "$(jq -r '.commit_oid' "${evidence}")" \
		--arg tree "$(jq -r '.tree_oid' "${evidence}")" --arg manifest "$(jq -r '.manifest_sha256' "${evidence}")" \
		--arg envelope "$(jq -cS . "${root}/envelope.json" | sha256sum | cut -d' ' -f1)" \
		--arg payload "$(jq -cS '.payload.entries' "${root}/envelope.json" | sha256sum | cut -d' ' -f1)" \
		--arg plan "$(jq -cS . <<<"${plan}" | sha256sum | cut -d' ' -f1)" \
		'{selector:$selector,candidate_root:$root,tag_oid:$tag,commit_oid:$commit,tree_oid:$tree,
		manifest_sha256:$manifest,envelope_sha256:$envelope,payload_identity:$payload,plan_sha256:$plan}'
}

starter_verify_frozen_candidate() {
	local frozen="$1" candidate="$2" plan="$3" current
	current="$(starter_freeze_candidate "${candidate}" "${plan}")" || return 1
	[ "$(jq -cS . <<<"${current}")" = "$(jq -cS . <<<"${frozen}")" ] || {
		printf 'prepared candidate identity changed' >&2
		return 1
	}
	STARTER_EVIDENCE_REVALIDATE_IMPL=git_tag_evidence_revalidate \
		evidence_revalidate "$(jq -r '.candidate_root' <<<"${frozen}")/evidence" >/dev/null
}

starter_confirm_update() {
	local response target="${STARTER_RELEASE}"
	printf 'Apply %s? (y/N) ' "${target}" >&2
	if ! read -r response; then
		response=""
	fi
	case "${response}" in y | Y) return 0 ;; esac
	printf 'starter: update aborted; no project changes were made\n'
	return 1
}

starter_recover_pending() {
	local journal found=0
	[ -d "${STARTER_PROJECT_ROOT}/.starter/journals" ] || return 0
	while IFS= read -r journal; do
		[ -n "${journal}" ] || continue
		found=1
		if jq -e '.schema == "gentle-starter.journal/v2" and .fusion.status == "pending"' "${journal}" >/dev/null 2>&1; then
			printf 'starter: pending F-manual transaction requires --take-starter, --keep-project, --continue, or --abort\n' >&2
			return 1
		fi
		starter_rollback_recover "${STARTER_PROJECT_ROOT}" "${journal}" || return 1
	done < <(find "${STARTER_PROJECT_ROOT}/.starter/journals" -name journal.json -type f -print)
	[ "${found}" -eq 0 ] || printf 'starter: recovered pending transaction\n' >&2
}

starter_adopt() {
	local source_result retained_result plan state detail
	[ ! -e "${STARTER_PROJECT_ROOT}/.starter/state.json" ] || {
		starter_blocker state.exists 'project already has an adoption marker'
		return 1
	}
	if ! detail="$(starter_state_require_clean_workspace "${STARTER_PROJECT_ROOT}" 2>&1)"; then
		starter_blocker repository.dirty "${detail##*$'\n'}"
		return 1
	fi
	if ! source_result="$(starter_acquire_candidate 2>&1)"; then
		starter_blocker source.invalid "${source_result##*$'\n'}"
		return 1
	fi
	if ! plan="$(starter_build_plan "${source_result}" 0.0.0 2>&1)"; then
		starter_blocker plan.invalid "${plan##*$'\n'}"
		return 1
	fi
	if ! state="$(starter_state_build "${STARTER_PROJECT_ROOT}" "${source_result}" "${plan}" 2>&1)"; then
		starter_blocker state.fingerprint "${state##*$'\n'}"
		return 1
	fi
	if ! retained_result="$(starter_retain_candidate "${source_result}" 2>&1)"; then
		starter_remove_retained_candidate
		starter_blocker evidence.write "${retained_result##*$'\n'}"
		return 1
	fi
	if ! state="$(starter_state_build "${STARTER_PROJECT_ROOT}" "${retained_result}" "${plan}" 2>&1)"; then
		starter_remove_retained_candidate
		starter_blocker state.fingerprint "${state##*$'\n'}"
		return 1
	fi
	if ! starter_state_persist "${STARTER_PROJECT_ROOT}" "${state}"; then
		starter_remove_retained_candidate
		starter_blocker state.write 'state marker could not be written'
		return 1
	fi
	printf 'starter: adopted release %s; review and commit .starter/state.json\n' "${STARTER_RELEASE#starter/v}"
}

starter_check() {
	local marker="${STARTER_PROJECT_ROOT}/.starter/state.json" current_result candidate plan detail current_version
	local candidate_cache="" candidate_was_cached=0 discovered=0
	STARTER_BLOCKER_COUNT=0
	if ! detail="$(starter_state_validate_marker "${marker}" 2>&1)"; then
		starter_blocker state.marker "${detail##*$'\n'}"
	else
		current_version="$(jq -r '.release.version' "${marker}")"
		printf 'starter: current release %s\n' "${current_version}"
		if ! current_result="$(starter_state_revalidate_evidence "${marker}" 2>&1)"; then
			starter_blocker evidence.invalid "${current_result##*$'\n'}"
		fi
		if ! detail="$(starter_state_drift "${marker}")"; then
			starter_blocker state.drift "managed paths changed: ${detail}"
		fi
	fi
	if [ -z "${STARTER_RELEASE}" ]; then
		if ! STARTER_RELEASE="$(git_tag_discover_latest_release "${STARTER_SOURCE_URL}" 2>&1)"; then
			starter_blocker source.discovery "${STARTER_RELEASE##*$'\n'}"
			STARTER_RELEASE=""
		else
			discovered=1
			printf 'starter: selected latest release %s\n' "${STARTER_RELEASE#starter/v}"
		fi
	fi
	if ! detail="$(starter_state_require_clean_workspace "${STARTER_PROJECT_ROOT}" 2>&1)"; then
		starter_blocker repository.dirty "${detail##*$'\n'}"
	fi
	[ -z "${STARTER_RELEASE}" ] || candidate_cache="$(starter_cache_candidate)"
	if [ -z "${candidate_cache}" ]; then
		:
	else
		[ ! -d "${candidate_cache}" ] || candidate_was_cached=1
		if ! candidate="$(starter_acquire_candidate 2>&1)"; then
			starter_blocker source.invalid "${candidate##*$'\n'}"
		elif [ -f "${marker}" ] && current_version="$(jq -r '.release.version // empty' "${marker}" 2>/dev/null)" && [ -n "${current_version}" ]; then
			if { [ "${discovered}" -eq 0 ] || [ "$(printf '%s\n%s\n' "${current_version}" "${STARTER_RELEASE#starter/v}" | sort -V | sed -n '$p')" = "${STARTER_RELEASE#starter/v}" ]; } &&
				[ "${current_version}" != "${STARTER_RELEASE#starter/v}" ] &&
				! plan="$(starter_build_plan "${candidate}" "${current_version}" 2>&1)"; then
				starter_blocker plan.invalid "${plan##*$'\n'}"
			fi
		fi
	fi
	if [ -n "${candidate_cache}" ] && [ "${candidate_was_cached}" -eq 0 ]; then
		rm -rf -- "${candidate_cache}"
		rmdir -- "$(dirname "${candidate_cache}")" 2>/dev/null || true
	fi
	if [ "${STARTER_BLOCKER_COUNT}" -ne 0 ]; then
		printf 'starter: check blocked (%s blockers)\n' "${STARTER_BLOCKER_COUNT}" >&2
		return 1
	fi
	if [ "${discovered}" -eq 1 ]; then
		if [ "${current_version}" = "${STARTER_RELEASE#starter/v}" ]; then
			printf 'starter: project is up to date at release %s\n' "${current_version}"
			return 0
		elif [ "$(printf '%s\n%s\n' "${current_version}" "${STARTER_RELEASE#starter/v}" | sort -V | sed -n '$p')" = "${current_version}" ]; then
			printf 'starter: current release %s is ahead of selected latest %s; no downgrade applies\n' \
				"${current_version}" "${STARTER_RELEASE#starter/v}"
			return 0
		fi
		printf 'starter: update available %s -> %s\n' "${current_version}" "${STARTER_RELEASE#starter/v}"
	fi
	printf 'starter: check passed; release %s is admitted and the migration plan is safe\n' "${STARTER_RELEASE#starter/v}"
}

starter_update_signal() {
	trap - INT TERM
	[ -z "${STARTER_UPDATE_PROJECT}" ] || starter_recover_pending || true
	exit 130
}

starter_update() {
	local marker="${STARTER_PROJECT_ROOT}/.starter/state.json" current_result candidate retained_result plan state detail
	local current_version journal transaction_status=0 discovered=0 frozen
	if [ -n "${STARTER_F_ACTION}" ]; then
		starter_f_transaction_resume "${STARTER_PROJECT_ROOT}" "${STARTER_F_ACTION}"
		return
	fi
	starter_recover_pending || {
		starter_blocker recovery.ambiguous 'pending transaction requires manual recovery'
		return 1
	}
	if ! detail="$(starter_state_validate_marker "${marker}" 2>&1)"; then
		starter_blocker state.marker "${detail##*$'\n'}"
		return 1
	fi
	if ! current_result="$(starter_state_revalidate_evidence "${marker}" 2>&1)"; then
		starter_blocker evidence.invalid "${current_result##*$'\n'}"
		return 1
	fi
	if ! detail="$(starter_state_drift "${marker}")"; then
		starter_blocker state.drift "managed paths changed: ${detail}"
		return 1
	fi
	if ! detail="$(starter_state_require_clean_workspace "${STARTER_PROJECT_ROOT}" 2>&1)"; then
		starter_blocker repository.dirty "${detail##*$'\n'}"
		return 1
	fi
	current_version="$(jq -r '.release.version' "${marker}")"
	printf 'starter: current release %s\n' "${current_version}"
	if [ -z "${STARTER_RELEASE}" ]; then
		if ! STARTER_RELEASE="$(git_tag_discover_latest_release "${STARTER_SOURCE_URL}" 2>&1)"; then
			starter_blocker source.discovery "${STARTER_RELEASE##*$'\n'}"
			return 1
		fi
		discovered=1
	fi
	printf 'starter: selected target %s\n' "${STARTER_RELEASE}"
	if [ "${current_version}" = "${STARTER_RELEASE#starter/v}" ]; then
		printf 'starter: project is up to date at release %s\n' "${current_version}"
		return 0
	fi
	if [ "${discovered}" -eq 1 ] && starter_version_is_ahead "${current_version}" "${STARTER_RELEASE#starter/v}"; then
		printf 'starter: current release %s is ahead of selected latest %s; no downgrade applies\n' \
			"${current_version}" "${STARTER_RELEASE#starter/v}"
		return 0
	fi
	if ! candidate="$(starter_acquire_candidate 2>&1)"; then
		starter_blocker source.invalid "${candidate##*$'\n'}"
		return 1
	fi
	if ! plan="$(starter_build_plan "${candidate}" "${current_version}" 2>&1)"; then
		starter_blocker plan.invalid "${plan##*$'\n'}"
		return 1
	fi
	if [ "$(jq '.operations | length' <<<"${plan}")" -eq 0 ]; then
		printf 'starter: already at release %s\n' "${current_version}"
		return 0
	fi
	starter_plan_summary "${plan}"
	frozen="$(starter_freeze_candidate "${candidate}" "${plan}")" || {
		starter_blocker source.invalid 'candidate identities could not be frozen'
		return 1
	}
	if [ "${STARTER_CONFIRMED}" -ne 1 ]; then
		"${STARTER_UPDATE_BEFORE_CONFIRM_HOOK:-:}" || {
			starter_blocker confirmation.hook 'pre-confirmation hook failed'
			return 1
		}
		if ! starter_confirm_update; then
			return 0
		fi
	fi
	if ! starter_verify_frozen_candidate "${frozen}" "${candidate}" "${plan}"; then
		starter_blocker source.invalid 'prepared candidate no longer matches its admitted identities'
		return 1
	fi
	STARTER_UPDATE_PROJECT="${STARTER_PROJECT_ROOT}"
	trap starter_update_signal INT TERM
	if [ "$(jq '.fusion.pending | length // 0' <<<"${plan}")" -gt 0 ]; then
		journal="$(starter_journal_prepare "${STARTER_PROJECT_ROOT}" "${candidate}" "${plan}")" || transaction_status=$?
		if [ "${transaction_status}" -eq 0 ]; then retained_result="$(starter_retain_candidate "${candidate}")" || {
			starter_blocker evidence.write 'candidate evidence could not be retained for pending F-manual resolution'
			return 1
		}; fi
		if [ "${transaction_status}" -eq 0 ]; then
			jq --argjson source_result "${retained_result}" '.source_result=$source_result | del(.integrity)' "${journal}" >"${journal}.next" &&
				mv -f -- "${journal}.next" "${journal}" && starter_f_seal_journal "${journal}" || transaction_status=$?
		fi
		if [ "${transaction_status}" -eq 0 ] && starter_f_promote_combined_journal "${journal}"; then
			trap - INT TERM
			STARTER_UPDATE_PROJECT=""
			while IFS= read -r detail; do printf 'starter: F-manual conflict: live=%s proposed=%s\n' \
				"${STARTER_PROJECT_ROOT}/${detail}" "$(dirname "${journal}")/$(jq -r --arg path "${detail}" '.fusion.pending[] | select(.path == $path) | .proposal' "${journal}")"; done \
				< <(jq -r '.fusion.pending[].path' "${journal}")
			starter_blocker fusion.pending 'resolve all F-manual conflicts explicitly'
			return 1
		elif [ "${transaction_status}" -eq 0 ]; then
			transaction_status=1
		fi
	else
		journal="$(starter_journal_prepare "${STARTER_PROJECT_ROOT}" "${candidate}" "${plan}")" || transaction_status=$?
	fi
	[ "${transaction_status}" -ne 0 ] || starter_transaction_failpoint after-journal || transaction_status=$?
	[ "${transaction_status}" -ne 0 ] || starter_transaction_apply "${STARTER_PROJECT_ROOT}" "${journal}" || transaction_status=$?
	[ "${transaction_status}" -ne 0 ] || starter_transaction_failpoint before-state || transaction_status=$?
	if [ "${transaction_status}" -eq 0 ]; then
		retained_result="$(starter_retain_candidate "${candidate}")" || transaction_status=$?
	fi
	[ "${transaction_status}" -ne 0 ] || starter_journal_replace_source_result "${journal}" "${retained_result}" || transaction_status=$?
	if [ "${transaction_status}" -eq 0 ]; then
		state="$(starter_state_build "${STARTER_PROJECT_ROOT}" "${retained_result}" "${plan}")" || transaction_status=$?
	fi
	[ "${transaction_status}" -ne 0 ] || starter_state_persist "${STARTER_PROJECT_ROOT}" "${state}" || transaction_status=$?
	[ "${transaction_status}" -ne 0 ] || starter_transaction_failpoint after-state || transaction_status=$?
	[ "${transaction_status}" -ne 0 ] || starter_journal_remove "${journal}" || transaction_status=$?
	if [ "${transaction_status}" -ne 0 ]; then
		trap - INT TERM
		journal="$(find "${STARTER_PROJECT_ROOT}/.starter/journals" -name journal.json -type f -print -quit 2>/dev/null || true)"
		[ -z "${journal}" ] || starter_rollback_recover "${STARTER_PROJECT_ROOT}" "${journal}" || true
		if [ "$(jq -r '.release.version // empty' "${marker}" 2>/dev/null)" != "${STARTER_RELEASE#starter/v}" ]; then
			starter_remove_retained_candidate
		fi
		STARTER_UPDATE_PROJECT=""
		starter_blocker update.failed 'transaction failed; CAS-safe recovery was attempted'
		return 1
	fi
	trap - INT TERM
	STARTER_UPDATE_PROJECT=""
	printf 'starter: updated %s -> %s; review and commit the changes\n' "${current_version}" "${STARTER_RELEASE#starter/v}"
}

main() {
	starter_parse_args "$@" || return $?
	case "${STARTER_COMMAND}" in
	adopt) starter_adopt ;;
	check) starter_check ;;
	update) starter_update ;;
	esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
