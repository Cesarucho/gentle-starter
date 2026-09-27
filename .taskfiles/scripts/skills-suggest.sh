#!/usr/bin/env bash
set -euo pipefail

catalog_file="$(mktemp)"
trap 'rm -f "$catalog_file"' EXIT
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if ! python3 "${script_dir}/skills-catalog.py" >"$catalog_file"; then
	exit 1
fi
mapfile -d '' -t records <"$catalog_file"
names=()
declare -A sources=()
for ((i = 0; i < ${#records[@]}; i += 2)); do
	names+=("${records[i]}")
	sources["${records[i]}"]="${records[i + 1]}"
done

selected=()
if (($#)); then
	declare -A seen=()
	for name in "$@"; do
		if [[ ! -v sources[$name] || -v seen[$name] ]]; then
			printf 'skills:suggest: unknown or duplicate skill name: %s\n' "$name" >&2
			exit 1
		fi
		seen["$name"]=1
		selected+=("$name")
	done
else
	if ((${#names[@]} == 0)); then
		printf 'No suggested skills available.\n'
		exit 0
	fi
	for ((i = 0; i < ${#names[@]}; i++)); do
		printf '%d. %s (%s)\n' "$((i + 1))" "${names[i]}" "${sources[${names[i]}]}"
	done
	if ! read -r -p 'Choose numbers (space/comma separated), all, or none: ' answer; then
		printf 'skills:suggest: selection required\n' >&2
		exit 1
	fi
	case "$answer" in
	none) ;;
	all) selected=("${names[@]}") ;;
	*)
		if [[ -z "${answer//[[:space:],]/}" ]]; then
			printf 'skills:suggest: selection required\n' >&2
			exit 1
		fi
		if [[ ! "$answer" =~ ^[0-9,[:space:]]+$ ]]; then
			printf 'skills:suggest: invalid selection\n' >&2
			exit 1
		fi
		answer="${answer//,/ }"
		read -r -a numbers <<<"$answer"
		declare -A chosen=()
		for number in "${numbers[@]}"; do
			if [[ ! "$number" =~ ^[1-9][0-9]*$ ]] || ((${#number} > 6)) ||
				((10#$number > ${#names[@]})); then
				printf 'skills:suggest: invalid selection\n' >&2
				exit 1
			fi
			chosen["$((10#$number - 1))"]=1
		done
		for ((i = 0; i < ${#names[@]}; i++)); do
			[[ -v chosen[$i] ]] && selected+=("${names[i]}")
		done
		;;
	esac
fi

if ((${#selected[@]} == 0)); then
	printf 'No skills selected; nothing installed.\n'
	exit 0
fi
printf 'Selected: %s\n' "${selected[*]}"
if ! read -r -p 'Install these skills? [y/N]: ' confirmation ||
	[[ ! "$confirmation" =~ ^([yY]|[yY][eE][sS])$ ]]; then
	printf 'Cancelled; nothing installed.\n'
	exit 0
fi

failed=()
for name in "${selected[@]}"; do
	if ! skills add "${sources[$name]}" --skill "$name" --agent pi --copy -y; then
		failed+=("$name")
	fi
done
if ((${#failed[@]})); then
	printf 'skills:suggest: install failed for: %s; other selected installs may have succeeded; inspect skills-lock.json and installed skills\n' "${failed[*]}" >&2
	exit 1
fi
printf 'Installed: %s\n' "${selected[*]}"
