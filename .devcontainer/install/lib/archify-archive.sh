#!/usr/bin/env bash
# Shared validation for official Archify release ZIPs.

devcontainer_validate_archify_archive() {
	local archive="$1"
	local version="$2"
	local sha256="$3"
	local destination="$4"
	local entries package_root package_version release_version required

	devcontainer_verify_sha256 "${archive}" "${sha256}" || return 1
	entries="$(mktemp)" || return 1
	if ! unzip -Z1 "${archive}" >"${entries}"; then
		devcontainer_log_error "Archify ZIP directory is malformed"
		rm -f "${entries}"
		return 1
	fi
	if [ ! -s "${entries}" ]; then
		devcontainer_log_error "Archify ZIP is empty"
		rm -f "${entries}"
		return 1
	fi
	if ! awk '
		/^\// || /^[A-Za-z]:[\\/]/ || /\\/ || /(^|\/)\.\.?(\/|$)/ { exit 1 }
		$0 !~ /^archify\// { exit 1 }
	' "${entries}"; then
		devcontainer_log_error "Archify ZIP contains an unsafe path or multiple top-level trees"
		rm -f "${entries}"
		return 1
	fi
	if [ "$(sort -u "${entries}" | wc -l)" -ne "$(wc -l <"${entries}")" ]; then
		devcontainer_log_error "Archify ZIP contains duplicate entries"
		rm -f "${entries}"
		return 1
	fi
	for required in archify/SKILL.md archify/package.json archify/skill-release.json archify/bin/archify.mjs; do
		if [ "$(grep -Fxc "${required}" "${entries}")" -ne 1 ]; then
			devcontainer_log_error "Archify ZIP is missing required entry: ${required}"
			rm -f "${entries}"
			return 1
		fi
	done
	rm -f "${entries}"

	if unzip -Z -l "${archive}" | awk 'NF >= 10 && $1 !~ /^[-d]/ { found=1 } END { exit found ? 0 : 1 }'; then
		devcontainer_log_error "Archify ZIP contains a symlink or special entry"
		return 1
	fi

	rm -rf "${destination}"
	mkdir -p "${destination}"
	if ! unzip -q "${archive}" -d "${destination}"; then
		devcontainer_log_error "Archify ZIP extraction failed"
		return 1
	fi
	package_root="${destination}/archify"
	package_version="$(node -e 'const p=require(process.argv[1]); process.stdout.write(p.version || "")' "${package_root}/package.json" 2>/dev/null || true)"
	release_version="$(node -e 'const p=require(process.argv[1]); process.stdout.write(p.version || "")' "${package_root}/skill-release.json" 2>/dev/null || true)"
	if [ "${package_version}" != "${version}" ] || [ "${release_version}" != "${version}" ]; then
		devcontainer_log_error "Archify embedded version does not match ${version}"
		return 1
	fi
}
