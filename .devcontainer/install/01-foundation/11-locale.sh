#!/usr/bin/env bash
#
# 11-locale.sh — activate timezone and locale after their packages are installed.
#
# Override via env: TZ, LOCALE.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${TZ:=America/Mexico_City}"
: "${LOCALE:=es_MX.UTF-8}"
locale_gen_file="${DEVCONTAINER_LOCALE_GEN_FILE:-/etc/locale.gen}"

if [[ ! "${LOCALE}" =~ ^[A-Za-z][A-Za-z0-9_.@-]*$ ]]; then
	devcontainer_log_error "Invalid locale name: ${LOCALE}"
	exit 1
fi

if ! awk -v locale="${LOCALE}" '
	{
		line = $0
		sub(/^[[:space:]]*#[[:space:]]*/, "", line)
		split(line, fields, /[[:space:]]+/)
		if (fields[1] == locale && fields[2] != "") found = 1
	}
	END { exit(found ? 0 : 1) }
' "${locale_gen_file}"; then
	devcontainer_log_error "Locale is unavailable in ${locale_gen_file}: ${LOCALE}"
	exit 1
fi

locale_gen_tmp="$(mktemp)"
trap 'rm -f "${locale_gen_tmp}"' EXIT
awk -v locale="${LOCALE}" '
	{
		line = $0
		sub(/^[[:space:]]*#[[:space:]]*/, "", line)
		split(line, fields, /[[:space:]]+/)
		if (fields[1] == locale && fields[2] != "") {
			print fields[1] " " fields[2]
			next
		}
		print
	}
' "${locale_gen_file}" >"${locale_gen_tmp}"
devcontainer_run_as_root install -m 0644 "${locale_gen_tmp}" "${locale_gen_file}"

devcontainer_log_info "Activating timezone: ${TZ}"
devcontainer_run_as_root dpkg-reconfigure -f noninteractive tzdata

devcontainer_log_info "Generating locale: ${LOCALE}"
devcontainer_run_as_root locale-gen "${LOCALE}"
devcontainer_run_as_root update-locale LANG="${LOCALE}" LANGUAGE="${LOCALE}" LC_ALL="${LOCALE}"

devcontainer_log_info "Locale configuration complete (TZ=${TZ}, LOCALE=${LOCALE})"
