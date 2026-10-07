#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:-}"
shift || exit 2
case "$mode" in
skills) ;;
tools | all)
	if (($#)); then
		printf 'Task arguments are not accepted.\n' >&2
		exit 2
	fi
	;;
*) exit 2 ;;
esac

# Capture validated catalogs before showing either menu. These arrays are the
# confirmation snapshot: do not reload skill sources or recommendation indices.
skill_names=() tool_names=() selected_skills=() selected_tools=()
declare -A sources=()
if [[ "$mode" != tools ]]; then
	data="$(python3 "${script_dir}/skills-catalog.py" --lines)" || exit 1
	if [[ -n "$data" ]]; then
		mapfile -t records <<<"$data"
		for ((i = 0; i < ${#records[@]}; i += 2)); do
			skill_names+=("${records[i]}")
			sources["${records[i]}"]="${records[i + 1]}"
		done
	fi
fi
if [[ "$mode" != skills ]]; then
	data="$(python3 "${script_dir}/tools-catalog.py")" || exit 1
	# Passed by name to choose(), which reads the array through a nameref.
	# shellcheck disable=SC2034
	[[ -z "$data" ]] || mapfile -t tool_names <<<"$data"
fi

choose() {
	local kind="$1" answer number i
	local -n names="$2" selected="$3"
	local -a numbers=()
	local -A chosen=()
	if ((${#names[@]} == 0)); then
		printf 'No suggested %s available.\n' "$kind"
		return 0
	fi
	printf 'Suggested %s:\n' "$kind"
	for ((i = 0; i < ${#names[@]}; i++)); do
		if [[ "$kind" == skills ]]; then
			printf '%d. %s (%s)\n' "$((i + 1))" "${names[i]}" "${sources[${names[i]}]}"
		else
			printf '%d. %s\n' "$((i + 1))" "${names[i]}"
		fi
	done
	if ! read -r -p 'Choose numbers (space/comma separated), all, or none: ' answer; then
		printf 'suggest:%s: selection required\n' "$kind" >&2
		return 1
	fi
	case "$answer" in
	none) return 0 ;;
	all)
		selected=("${names[@]}")
		return 0
		;;
	*)
		if [[ -z "${answer//[[:space:],]/}" || ! "$answer" =~ ^[0-9,[:space:]]+$ ]]; then
			printf 'suggest:%s: invalid selection\n' "$kind" >&2
			return 1
		fi
		read -r -a numbers <<<"${answer//,/ }"
		for number in "${numbers[@]}"; do
			if [[ ! "$number" =~ ^[1-9][0-9]*$ ]] || ((${#number} > 6)) ||
				((10#$number > ${#names[@]})); then
				printf 'suggest:%s: invalid selection\n' "$kind" >&2
				return 1
			fi
			chosen["$((10#$number - 1))"]=1
		done
		for ((i = 0; i < ${#names[@]}; i++)); do
			[[ ! -v chosen[$i] ]] || selected+=("${names[i]}")
		done
		;;
	esac
}

if [[ "$mode" != tools ]]; then
	if (($#)); then
		declare -A seen=()
		for name in "$@"; do
			if [[ ! -v sources[$name] || -v seen[$name] ]]; then
				printf 'suggest:skills: unknown or duplicate skill name: %s\n' "$name" >&2
				exit 1
			fi
			seen["$name"]=1
			selected_skills+=("$name")
		done
	else
		choose skills skill_names selected_skills || exit 1
	fi
fi
if [[ "$mode" != skills ]]; then
	choose tools tool_names selected_tools || exit 1
fi
planner="${script_dir}/../../.devcontainer/install/lib/selection.py"
if ((${#selected_tools[@]})); then
	python3 "$planner" .devcontainer/install plan-many "${selected_tools[@]}" || exit 1
fi
if ((${#selected_skills[@]} + ${#selected_tools[@]} == 0)); then
	printf 'Nothing selected; nothing changed.\n'
	exit 0
fi
printf 'Selected skills: %s\nSelected tools: %s\n' "${selected_skills[*]:-none}" "${selected_tools[*]:-none}"
if ! read -r -p 'Apply this selection? [y/N]: ' confirmation ||
	[[ ! "$confirmation" =~ ^([yY]|[yY][eE][sS])$ ]]; then
	printf 'Cancelled; nothing changed.\n'
	exit 0
fi
if ((${#selected_tools[@]})); then
	# Reinspect roots, core, graph, aliases and the whole projection under the
	# existing enable/disable lock. Never apply the earlier, potentially stale plan.
	if ! python3 "$planner" .devcontainer/install enable-many "${selected_tools[@]}"; then
		printf 'Tool stage failed; Skills stage not started. Inspect tool selection; only operation-owned links are rolled back.\n' >&2
		exit 1
	fi
	printf 'Tool stage complete: activation for future builds only; no installers executed.\n'
fi
failed=()
for name in "${selected_skills[@]}"; do
	if ! skills add "${sources[$name]}" --skill "$name" --agent universal --copy -y; then
		failed+=("$name")
	fi
done
if ((${#failed[@]})); then
	printf 'suggest:skills: install failed for: %s; other selected installs may have succeeded; inspect skills-lock.json and installed skills\n' "${failed[*]}" >&2
	if ((${#selected_tools[@]})); then
		printf 'Tool stage remains applied; no cross-system rollback.\n' >&2
	fi
	exit 1
fi
if ((${#selected_skills[@]})); then
	printf 'Installed: %s\n' "${selected_skills[*]}"
fi
