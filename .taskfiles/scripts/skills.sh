#!/usr/bin/env bash
# skills.sh — preserve package-managed and project-authored skills.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOCK_FILE="${REPO_ROOT}/skills-lock.json"
LOCAL_FILE="${REPO_ROOT}/.agents/local-skills.txt"
SKILLS_DIR="${REPO_ROOT}/.agents/skills"
LOCKED_SKILLS=()
LOCAL_SKILLS=()
declare -A MANAGED_SKILLS=()

load_and_validate_names() {
	local lock_json locked_output local_output skill

	test -f "${LOCK_FILE}" || {
		echo "missing: skills-lock.json" >&2
		return 1
	}
	lock_json="$(cat "${LOCK_FILE}")" || {
		echo "cannot read: skills-lock.json" >&2
		return 1
	}
	jq -e 'type == "object" and .version == 1 and (.skills | type == "object")' <<<"${lock_json}" >/dev/null || {
		echo "invalid skills-lock.json: expected version 1 with a skills object" >&2
		return 1
	}
	locked_output="$(jq -r '.skills | keys[]' <<<"${lock_json}")" || {
		echo "cannot read skill names from skills-lock.json" >&2
		return 1
	}
	if [ -n "${locked_output}" ]; then
		mapfile -t LOCKED_SKILLS <<<"${locked_output}"
	fi
	for skill in "${LOCKED_SKILLS[@]}"; do
		[[ "${skill}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || {
			echo "invalid locked skill name: ${skill}" >&2
			return 1
		}
		MANAGED_SKILLS["${skill}"]=locked
	done

	if [ -f "${LOCAL_FILE}" ]; then
		local_output="$(sed -E 's/[[:space:]]*#.*$//; /^[[:space:]]*$/d; s/^[[:space:]]+//; s/[[:space:]]+$//' "${LOCAL_FILE}")" || {
			echo "cannot read: .agents/local-skills.txt" >&2
			return 1
		}
		if [ -n "${local_output}" ]; then
			mapfile -t LOCAL_SKILLS <<<"${local_output}"
		fi
	fi
	for skill in "${LOCAL_SKILLS[@]}"; do
		[[ "${skill}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || {
			echo "invalid project-local skill name: ${skill}" >&2
			return 1
		}
		if [ -n "${MANAGED_SKILLS[${skill}]:-}" ]; then
			echo "project-local skill also exists in skills-lock.json or local manifest: ${skill}" >&2
			return 1
		fi
		MANAGED_SKILLS["${skill}"]=project-local
	done
}

validate_skill() {
	local skill="$1" source="$2" path="${SKILLS_DIR}/$1"
	if [ -L "${path}" ]; then
		echo "invalid managed skill symlink: .agents/skills/${skill}" >&2
		return 1
	fi
	test -f "${path}/SKILL.md" || {
		echo "missing: .agents/skills/${skill}/SKILL.md" >&2
		return 1
	}
	echo "ok: ${skill} (${source})"
}

cmd_prune() {
	local path skill
	load_and_validate_names
	[ -d "${SKILLS_DIR}" ] || return 0
	for skill in "${!MANAGED_SKILLS[@]}"; do
		validate_skill "${skill}" "${MANAGED_SKILLS[${skill}]}" >/dev/null
	done
	while IFS= read -r -d '' path; do
		skill="$(basename "${path}")"
		if [ -z "${MANAGED_SKILLS[${skill}]:-}" ]; then
			echo "prune: ${path#"${REPO_ROOT}/"}"
			rm -rf "${path}"
		fi
	done < <(find "${SKILLS_DIR}" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -print0 | sort -z)
}

cmd_validate() {
	local skill
	load_and_validate_names
	for skill in "${LOCKED_SKILLS[@]}"; do validate_skill "${skill}" locked; done
	for skill in "${LOCAL_SKILLS[@]}"; do validate_skill "${skill}" project-local; done
}

case "${1:-}" in
prune) cmd_prune ;;
validate) cmd_validate ;;
*)
	echo "Usage: skills.sh <prune|validate>" >&2
	exit 2
	;;
esac
