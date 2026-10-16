#!/usr/bin/env bash
# Restore regular-file executable bits from the repository index.
set -euo pipefail

workspace_dir="${1:?workspace directory is required}"
shift
protected_paths=("$@")
if [ "$#" -eq 0 ]; then
	mapfile -d '' -t protected_paths < <(
		policy_status=0
		python3 "${workspace_dir}/.devcontainer/lifecycle/runtime-directory-permissions.py" exclusions "${workspace_dir}" || policy_status=$?
		printf '%s\0' "${policy_status}"
	)
	policy_status="${protected_paths[-1]}"
	unset 'protected_paths[-1]'
	[ "${policy_status}" = 0 ] || exit 1
fi

while IFS= read -r -d '' tracked_entry; do
	tracked_mode="${tracked_entry%% *}"
	tracked_path="${tracked_entry#*$'\t'}"
	protected=false
	for protected_path in "${protected_paths[@]}"; do
		if [[ "${workspace_dir}/${tracked_path}" == "${protected_path}" ||
			"${workspace_dir}/${tracked_path}" == "${protected_path}/"* ]]; then
			protected=true
			break
		fi
	done
	[ "${protected}" = false ] || continue
	[ -f "${workspace_dir}/${tracked_path}" ] || continue
	[ ! -L "${workspace_dir}/${tracked_path}" ] || continue
	case "${tracked_mode}" in
	100644) sudo chmod 644 "${workspace_dir}/${tracked_path}" ;;
	100755) sudo chmod 755 "${workspace_dir}/${tracked_path}" ;;
	esac
done < <(git -C "${workspace_dir}" ls-files --stage -z)
