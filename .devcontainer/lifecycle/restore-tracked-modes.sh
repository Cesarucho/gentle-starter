#!/usr/bin/env bash
# Restore regular-file executable bits from the repository index.
set -euo pipefail

workspace_dir="${1:?workspace directory is required}"

while IFS= read -r -d '' tracked_entry; do
	tracked_mode="${tracked_entry%% *}"
	tracked_path="${tracked_entry#*$'\t'}"
	[ -f "${workspace_dir}/${tracked_path}" ] || continue
	[ ! -L "${workspace_dir}/${tracked_path}" ] || continue
	case "${tracked_mode}" in
	100644) sudo chmod 644 "${workspace_dir}/${tracked_path}" ;;
	100755) sudo chmod 755 "${workspace_dir}/${tracked_path}" ;;
	esac
done < <(git -C "${workspace_dir}" ls-files --stage -z)
