#!/usr/bin/env bash
set -euo pipefail

host="${1:-}"
port="${2:-}"
output="${3:-}"
attempts="${SSH_HOSTKEY_SCAN_ATTEMPTS:-3}"
retry_delay="${SSH_HOSTKEY_SCAN_RETRY_DELAY:-1}"

if [ -z "${host}" ] || [ -z "${port}" ] || [ -z "${output}" ]; then
	printf 'usage: %s HOST PORT OUTPUT\n' "${0##*/}" >&2
	exit 2
fi

output_dir="$(dirname "${output}")"
raw="$(mktemp "${output_dir}/ssh-hostkeys.raw.XXXXXXXX")"
normalized="$(mktemp "${output_dir}/ssh-hostkeys.normalized.XXXXXXXX")"
key="$(mktemp "${output_dir}/ssh-hostkey.one.XXXXXXXX")"
chmod 0600 "${raw}" "${normalized}" "${key}"
trap 'rm -f "${raw}" "${normalized}" "${key}"' EXIT

for ((attempt = 1; attempt <= attempts; attempt++)); do
	: >"${raw}"
	ssh-keyscan -T 3 -t rsa,ed25519 -p "${port}" "${host}" >"${raw}" 2>/dev/null || true
	: >"${normalized}"
	complete=1
	for algorithm in ssh-rsa ssh-ed25519; do
		if [ "$(awk -v algorithm="${algorithm}" '$2 == algorithm { count++ } END { print count + 0 }' "${raw}")" -ne 1 ]; then
			complete=0
			continue
		fi
		awk -v algorithm="${algorithm}" '$2 == algorithm' "${raw}" >"${key}"
		fingerprint="$(ssh-keygen -E sha256 -lf "${key}" 2>/dev/null | awk 'NR == 1 { print $2 }')"
		if [ -z "${fingerprint}" ]; then
			complete=0
			continue
		fi
		printf '%s %s\n' "${algorithm}" "${fingerprint}" >>"${normalized}"
	done
	if [ "${complete}" -eq 1 ] && [ "$(wc -l <"${normalized}")" -eq 2 ]; then
		sort "${normalized}" >"${output}"
		chmod 0600 "${output}"
		exit 0
	fi
	[ "${attempt}" -eq "${attempts}" ] || sleep "${retry_delay}"
done

rm -f "${output}"
printf 'required SSH host-key algorithms unavailable after %s scans: rsa and ed25519 are both required\n' "${attempts}" >&2
exit 1
