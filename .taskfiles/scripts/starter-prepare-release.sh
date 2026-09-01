#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.taskfiles/scripts/starter-lib/contracts/ownership.sh
source "${SCRIPT_DIR}/starter-lib/contracts/ownership.sh"
# shellcheck source=.taskfiles/scripts/starter-lib/core/derived-tree.sh
source "${SCRIPT_DIR}/starter-lib/core/derived-tree.sh"

prepare_error() { printf 'starter prepare release: %s\n' "$*" >&2; }

PREPARE_WORKSPACE=""
PREPARE_STAGING_OUTPUT=""

starter_prepare_cleanup() {
	[ -z "${PREPARE_WORKSPACE}" ] || rm -rf -- "${PREPARE_WORKSPACE}"
	[ -z "${PREPARE_STAGING_OUTPUT}" ] || rm -rf -- "${PREPARE_STAGING_OUTPUT}"
}

main() {
	local version="${1:-}" predecessor="" root inventory workspace derived official identity official_identity tracked_modes
	local prepared_root output staging_output
	if { [ "$#" -ne 1 ] && [ "$#" -ne 3 ]; } ||
		{ [ "$#" -eq 3 ] && [ "${2:-}" != --predecessor ]; } ||
		[[ ! "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
		prepare_error 'usage: task starter:prepare-release -- X.Y.Z [--predecessor A.B.C]'
		return 1
	fi
	root="$(git rev-parse --show-toplevel)"
	[ "${root}" = "${PWD}" ] || {
		prepare_error 'run from repository root'
		return 1
	}
	inventory=.starter/distribution/ownership.json
	starter_ownership_validate_file "${inventory}"
	prepared_root=".starter/distribution/prepared"
	mkdir -p "${prepared_root}"
	output="${prepared_root}/${version}"
	[ ! -e "${output}" ] || {
		prepare_error "prepared release already exists: ${version}"
		return 1
	}
	if [ "$#" -eq 3 ]; then
		predecessor="$3"
		[[ "${predecessor}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
			prepare_error 'predecessor must be a semantic version'
			return 1
		}
	else
		predecessor="$(starter_prepare_infer_predecessor "${prepared_root}" "${version}")" || return 1
	fi
	if [ "$(printf '%s\n%s\n' "${predecessor}" "${version}" | sort -V | sed -n '$p')" != "${version}" ] || [ "${predecessor}" = "${version}" ]; then
		prepare_error 'predecessor must be lower than the target version'
		return 1
	fi
	printf 'starter: selected predecessor %s\n' "${predecessor}"
	staging_output="$(mktemp -d "${prepared_root}/.${version}.prepare.XXXXXX")"
	workspace="$(mktemp -d "${TMPDIR:-/tmp}/starter-prepare.XXXXXX")"
	PREPARE_STAGING_OUTPUT="${staging_output}"
	PREPARE_WORKSPACE="${workspace}"
	trap 'starter_prepare_cleanup' EXIT
	tracked_modes="${workspace}/tracked-modes"
	starter_git_capture_tracked_modes "${root}" "${tracked_modes}"
	derived="${workspace}/derived"
	starter_derived_transform "${root}" "${derived}" "${tracked_modes}" || return 1
	identity="$(starter_derived_identity "${derived}")"
	official="${workspace}/official"
	mkdir -p "${official}"
	rsync -a --exclude=.git --exclude=.env.d --exclude=.starter/evidence --exclude=.starter/journals \
		--exclude=.starter/caches --exclude=.starter/distribution/prepared --exclude=context.md "${root}/" "${official}/"
	starter_tree_canonicalize_modes "${official}" "${tracked_modes}"
	official_identity="$(starter_derived_identity "${official}")"
	cp -a "${derived}" "${staging_output}/tree"
	starter_prepare_distribution "${derived}" "${staging_output}" "${version}" "${predecessor}" "${official_identity}" "${identity}"
	jq -n --arg version "${version}" --arg predecessor "${predecessor}" --arg identity "${identity}" --arg official "${official_identity}" '{
		schema:"gentle-starter.prepared-release/v2",version:$version,predecessor_version:$predecessor,
		official_tree_sha256:$official,
		transformation:{schema:"gentle-starter.derived-tree-transformation/v1",derived_tree_sha256:$identity},
		artifacts:{manifest:"manifest.json",ownership:"ownership.json",migration_root:"migrations",payload_root:"payloads"}
	}' >"${staging_output}/index.json"
	[ "${STARTER_PREPARE_FAILPOINT:-}" != after-build ] || return 97
	starter_prepare_validate "${staging_output}" "${version}" "${predecessor}"
	if ! mv -T --no-clobber -- "${staging_output}" "${output}" || [ -e "${staging_output}" ]; then
		prepare_error "prepared release appeared during publication: ${version}"
		return 1
	fi
	staging_output=""
	PREPARE_STAGING_OUTPUT=""
	printf 'starter: prepared reviewable derived tree %s (sha256:%s)\n' "${output}" "${identity}"
}

starter_prepare_infer_predecessor() {
	local prepared_root="$1" target="$2" candidate version predecessor previous=0.0.0 selected=""
	local candidates=()
	while IFS= read -r candidate; do
		[ -n "${candidate}" ] || continue
		version="${candidate##*/}"
		[[ "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
			prepare_error "malformed prepared release candidate: ${version}"
			return 1
		}
		candidates+=("${version}")
	done < <(find "${prepared_root}" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print | LC_ALL=C sort -V)
	for version in "${candidates[@]}"; do
		if [ "$(printf '%s\n%s\n' "${version}" "${target}" | sort -V | sed -n '$p')" != "${target}" ] || [ "${version}" = "${target}" ]; then
			prepare_error "prepared release does not form a lower predecessor chain: ${version}"
			return 1
		fi
		predecessor="$(jq -r '.release.predecessor_version // empty' "${prepared_root}/${version}/manifest.json" 2>/dev/null)"
		if [ -z "${predecessor}" ] || ! starter_prepare_validate "${prepared_root}/${version}" "${version}" "${predecessor}"; then
			prepare_error "prepared release candidate is invalid: ${version}"
			return 1
		fi
		[ "${predecessor}" = "${previous}" ] || {
			prepare_error "prepared releases do not form one unique chain at ${version}"
			return 1
		}
		previous="${version}"
		selected="${version}"
	done
	printf '%s\n' "${selected:-0.0.0}"
}

starter_prepare_validate() {
	local output="$1" version="$2" predecessor="$3" manifest count index path expected bytes mode actual_paths recorded_paths
	local operation_count operation_index operation ownership target
	manifest="${output}/manifest.json"
	jq -e --arg version "${version}" --arg predecessor "${predecessor}" '
		def sha: type == "string" and test("^[0-9a-f]{64}$");
		def semver: type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$");
		def relative: type == "string" and length > 0 and (startswith("/")|not) and
			(split("/")|all(. != "" and . != "." and . != ".."));
		type == "object" and (keys|sort) == ["identities","migrations","ownership","payload","release","schema","source","transformation"] and
		.schema == "starter-manifest/v2" and .source == {id:"gentle-starter",release:("starter/v"+$version)} and
		.release == {version:$version,predecessor_version:$predecessor,predecessor_id:null} and
		($version|semver) and ($predecessor|semver) and
		.identities.official_tree != .identities.derived_tree and
		(.identities.official_tree|test("^sha256:[0-9a-f]{64}$")) and (.identities.derived_tree|test("^sha256:[0-9a-f]{64}$")) and
		.transformation == {schema:"gentle-starter.derived-tree-transformation/v1"} and
		.ownership.schema == "gentle-starter.ownership-inventory/v2" and .ownership.path == "ownership.json" and (.ownership.sha256|sha) and
		.payload.root == "payloads" and .payload.closure == "exact" and
		(.payload.entries|type == "array" and length > 0 and
			(map(.path) as $paths | ($paths|length) == ($paths|unique|length)) and all(
			(keys|sort) == ["bytes","mode","path","presence","sha256"] and (.path|relative) and (.sha256|sha) and
			(.bytes|type == "number" and . >= 0 and floor == .) and (.mode == "644" or .mode == "755") and .presence == "present")) and
		.migrations.root == "migrations" and (.migrations.entries|type == "array" and length > 0 and
			(map(.id) as $ids | ($ids|length) == ($ids|unique|length)) and
			(map(.path) as $paths | ($paths|length) == ($paths|unique|length)) and all(
			(keys|sort) == ["id","path","sha256"] and (.id|type == "string" and length > 0) and (.path|relative) and (.sha256|sha)))
	' "${manifest}" >/dev/null || {
		prepare_error "manifest schema validation failed: ${manifest}"
		return 1
	}
	[ "$(sha256sum "${output}/ownership.json" | cut -d' ' -f1)" = "$(jq -r '.ownership.sha256' "${manifest}")" ] || return 1
	starter_ownership_validate_file "${output}/ownership.json" || return 1
	count="$(jq '.payload.entries | length' "${manifest}")"
	for ((index = 0; index < count; index++)); do
		path="$(jq -r ".payload.entries[${index}].path" "${manifest}")"
		expected="$(jq -r ".payload.entries[${index}].sha256" "${manifest}")"
		bytes="$(jq -r ".payload.entries[${index}].bytes" "${manifest}")"
		mode="$(jq -r ".payload.entries[${index}].mode" "${manifest}")"
		[ -f "${output}/payloads/${path}" ] && [ ! -L "${output}/payloads/${path}" ] || return 1
		[ "$(sha256sum "${output}/payloads/${path}" | cut -d' ' -f1)" = "${expected}" ] || return 1
		[ "$(wc -c <"${output}/payloads/${path}")" -eq "${bytes}" ] || return 1
		[ "$(stat -c '%a' "${output}/payloads/${path}")" = "${mode}" ] || return 1
	done
	actual_paths="$(find "${output}/payloads" \( -type f -o -type l \) -printf '%P\n' | LC_ALL=C sort)"
	recorded_paths="$(jq -r '.payload.entries[].path' "${manifest}" | LC_ALL=C sort)"
	[ "${actual_paths}" = "${recorded_paths}" ] || return 1
	count="$(jq '.migrations.entries | length' "${manifest}")"
	for ((index = 0; index < count; index++)); do
		path="$(jq -r ".migrations.entries[${index}].path" "${manifest}")"
		expected="$(jq -r ".migrations.entries[${index}].sha256" "${manifest}")"
		[ -f "${output}/migrations/${path}" ] && [ ! -L "${output}/migrations/${path}" ] || return 1
		[ "$(sha256sum "${output}/migrations/${path}" | cut -d' ' -f1)" = "${expected}" ] || return 1
		jq -e --arg id "$(jq -r ".migrations.entries[${index}].id" "${manifest}")" --slurpfile manifest "${manifest}" '
			def relative: type == "string" and length > 0 and (startswith("/")|not) and
				(split("/")|all(. != "" and . != "." and . != ".."));
			.schema == "starter-migration/v2" and (keys|sort) == ["from_version","id","operations","schema","to_version"] and
			.id == $id and (.from_version|test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")) and
			(.to_version|test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")) and .from_version != .to_version and
			.to_version as $migration_target | (.operations|type == "array" and all(
				((keys|sort) == ["after","expected_before","ownership","source","target","type"] or
				 (keys|sort) == ["after","contract","expected_before","ownership","source","target","type"]) and
				(.type == "copy" or .type == "delete" or .type == "fusion") and
				(.ownership == "managed" or .ownership == "fusion") and
				(.target|relative) and (.source|relative) and
				(.expected_before|keys|sort) == ["mode","presence","sha256"] and
				(.after|keys|sort) == ["mode","presence","sha256"] and
				(.expected_before.presence|IN("any","present","absent")) and
				(.expected_before.sha256 == null or (.expected_before.sha256|test("^[0-9a-f]{64}$"))) and
				(.expected_before.mode == null or (.expected_before.mode == "644" or .expected_before.mode == "755")) and
				.after.presence == "present" and (.after.sha256|test("^[0-9a-f]{64}$")) and
				(.after.mode == "644" or .after.mode == "755") and
				(if $migration_target == $manifest[0].release.version then (. as $operation | any($manifest[0].payload.entries[];
					.path == $operation.source and .sha256 == $operation.after.sha256 and
					.mode == $operation.after.mode and .presence == $operation.after.presence)) else true end) and
				(if .ownership == "fusion" then .type == "fusion" and .contract == "F-manual/v1"
				 else .type == "copy" and (has("contract")|not) end))) and
			([.operations[].target] as $targets | ($targets|length) == ($targets|unique|length) and
				([range(0;$targets|length) as $left | range(0;$targets|length) as $right |
					select($left != $right and ($targets[$right]|startswith($targets[$left] + "/")))] | length == 0))
		' "${output}/migrations/${path}" >/dev/null || return 1
		operation_count="$(jq '.operations|length' "${output}/migrations/${path}")"
		for ((operation_index = 0; operation_index < operation_count; operation_index++)); do
			operation="$(jq -c ".operations[${operation_index}]" "${output}/migrations/${path}")"
			ownership="$(jq -r '.ownership' <<<"${operation}")"
			target="$(jq -r '.target' <<<"${operation}")"
			[ "$(starter_ownership_classify "${output}/ownership.json" "${target}")" = "${ownership}" ] || return 1
		done
	done
	actual_paths="$(find "${output}/migrations" \( -type f -o -type l \) -printf '%P\n' | LC_ALL=C sort)"
	recorded_paths="$(jq -r '.migrations.entries[].path' "${manifest}" | LC_ALL=C sort)"
	[ "${actual_paths}" = "${recorded_paths}" ] || return 1
	starter_prepare_validate_topology "${output}" "${version}" "${predecessor}" || return 1
	jq -e --arg version "${version}" --arg predecessor "${predecessor}" --argjson manifest "$(jq . "${manifest}")" \
		'.schema == "gentle-starter.prepared-release/v2" and (keys|sort) == ["artifacts","official_tree_sha256","predecessor_version","schema","transformation","version"] and
		.version == $version and .predecessor_version == $predecessor and
		.official_tree_sha256 == ($manifest.identities.official_tree|sub("^sha256:";"")) and
		.transformation == {schema:"gentle-starter.derived-tree-transformation/v1",derived_tree_sha256:($manifest.identities.derived_tree|sub("^sha256:";""))} and
		.artifacts == {manifest:"manifest.json",ownership:"ownership.json",migration_root:"migrations",payload_root:"payloads"}' \
		"${output}/index.json" >/dev/null || return 1
	[ "$(starter_derived_identity "${output}/tree")" = "$(jq -r '.transformation.derived_tree_sha256' "${output}/index.json")" ] || return 1
	jq -e --arg version "${version}" --arg sha "$(sha256sum "${manifest}" | cut -d' ' -f1)" '
		. == {schema:"gentle-starter.publication/v2",selector:("starter/v"+$version),manifest_sha256:$sha,publish:false}
	' "${output}/publication.json" >/dev/null || return 1
	actual_paths="$(find "${output}" -mindepth 1 -maxdepth 1 -printf '%f\n' | LC_ALL=C sort)"
	[ "${actual_paths}" = $'index.json\nmanifest.json\nmigrations\nownership.json\npayloads\npublication.json\ntree' ]
}

starter_prepare_validate_topology() {
	local output="$1" version="$2" predecessor="$3" documents='[]' path current matches next steps maximum from
	while IFS= read -r path; do
		documents="$(jq -cn --argjson documents "${documents}" --argjson document "$(jq -c . "${output}/migrations/${path}")" '$documents+[$document]')"
	done < <(jq -r '.migrations.entries[].path' "${output}/manifest.json")
	[ "$(jq '[group_by([.from_version,.to_version])[]|select(length>1)]|length' <<<"${documents}")" -eq 0 ] || return 1
	[ "$(jq '[group_by(.from_version)[]|select(length>1)]|length' <<<"${documents}")" -eq 0 ] || return 1
	jq -e --arg target "${version}" 'all(.[]; .from_version as $from | .to_version as $to |
		$to != $from and ([$from,$to]|sort_by(split(".")|map(tonumber))|.[-1] == $to) and
		([$to,$target]|sort_by(split(".")|map(tonumber))|.[-1] == $target))' <<<"${documents}" >/dev/null || return 1
	jq -e --arg predecessor "${predecessor}" --arg version "${version}" \
		'any(.[]; .from_version == $predecessor and .to_version == $version)' <<<"${documents}" >/dev/null || return 1
	maximum="$(jq 'length' <<<"${documents}")"
	while IFS= read -r from; do
		current="${from}"
		steps=0
		while [ "${current}" != "${version}" ]; do
			matches="$(jq -c --arg current "${current}" '[.[]|select(.from_version == $current)]' <<<"${documents}")"
			[ "$(jq 'length' <<<"${matches}")" -eq 1 ] || return 1
			next="$(jq -r '.[0].to_version' <<<"${matches}")"
			current="${next}"
			steps=$((steps + 1))
			[ "${steps}" -le "${maximum}" ] || return 1
		done
	done < <(jq -r '.[].from_version' <<<"${documents}" | LC_ALL=C sort -u)
}

starter_prepare_distribution() {
	local derived="$1" output="$2" version="$3" predecessor="$4" official="$5" identity="$6"
	local source path sha bytes mode payload_entries='[]' operations='[]' ownership_sha migration_sha migration_path
	local predecessor_root predecessor_manifest migration_entries='[]' count index migration_id
	mkdir -p "${output}/payloads" "${output}/migrations"
	cp -p .starter/distribution/ownership.json "${output}/ownership.json"
	while IFS= read -r source; do
		path="${source#"${derived}"/}"
		case "${path}" in .starter/state.json | .starter/evidence/* | .starter/journals/* | .starter/caches/*) return 1 ;; esac
		if [ "$(starter_ownership_classify "${output}/ownership.json" "${path}")" != managed ]; then
			continue
		fi
		mkdir -p "${output}/payloads/$(dirname "${path}")"
		cp -p -- "${source}" "${output}/payloads/${path}"
		sha="$(sha256sum "${source}" | cut -d' ' -f1)"
		bytes="$(wc -c <"${source}")"
		mode="$(stat -c '%a' "${source}")"
		payload_entries="$(jq -cn --argjson entries "${payload_entries}" --arg path "${path}" --arg sha "${sha}" \
			--argjson bytes "${bytes}" --arg mode "${mode}" '$entries + [{path:$path,sha256:$sha,bytes:$bytes,mode:$mode,presence:"present"}]')"
		operations="$(jq -cn --argjson operations "${operations}" --arg path "${path}" --arg sha "${sha}" --arg mode "${mode}" \
			'$operations + [{type:"copy",ownership:"managed",source:$path,target:$path,expected_before:{presence:"any",sha256:null,mode:null},after:{presence:"present",sha256:$sha,mode:$mode}}]')"
	done < <(find "${derived}" -type f -print | LC_ALL=C sort)
	for path in .devcontainer/devcontainer.json .devcontainer/docker-compose.yml; do
		source="${derived}/${path}"
		mkdir -p "${output}/payloads/$(dirname "${path}")"
		cp -p -- "${source}" "${output}/payloads/${path}"
		sha="$(sha256sum "${source}" | cut -d' ' -f1)"
		bytes="$(wc -c <"${source}")"
		mode="$(stat -c '%a' "${source}")"
		payload_entries="$(jq -cn --argjson entries "${payload_entries}" --arg path "${path}" --arg sha "${sha}" \
			--argjson bytes "${bytes}" --arg mode "${mode}" '$entries + [{path:$path,sha256:$sha,bytes:$bytes,mode:$mode,presence:"present"}]')"
		operations="$(jq -cn --argjson operations "${operations}" --arg path "${path}" --arg sha "${sha}" --arg mode "${mode}" \
			'$operations + [{type:"fusion",ownership:"fusion",contract:"F-manual/v1",source:$path,target:$path,expected_before:{presence:"present",sha256:null,mode:null},after:{presence:"present",sha256:$sha,mode:$mode}}]')"
	done
	ownership_sha="$(sha256sum "${output}/ownership.json" | cut -d' ' -f1)"
	if [ "${predecessor}" != 0.0.0 ]; then
		predecessor_root=".starter/distribution/prepared/${predecessor}"
		predecessor_manifest="${predecessor_root}/manifest.json"
		if ! jq -e --arg predecessor "${predecessor}" '.schema == "starter-manifest/v2" and .release.version == $predecessor' \
			"${predecessor_manifest}" >/dev/null 2>&1 ||
			! starter_prepare_validate "${predecessor_root}" "${predecessor}" \
				"$(jq -r '.release.predecessor_version // empty' "${predecessor_manifest}" 2>/dev/null)"; then
			prepare_error "prepared predecessor is missing or invalid: ${predecessor}"
			return 1
		fi
		count="$(jq '.migrations.entries | length' "${predecessor_manifest}")"
		for ((index = 0; index < count; index++)); do
			path="$(jq -r ".migrations.entries[${index}].path" "${predecessor_manifest}")"
			migration_id="$(jq -r ".migrations.entries[${index}].id" "${predecessor_manifest}")"
			cp -p -- "${predecessor_root}/migrations/${path}" "${output}/migrations/${path}"
			migration_sha="$(sha256sum "${output}/migrations/${path}" | cut -d' ' -f1)"
			migration_entries="$(jq -cn --argjson entries "${migration_entries}" --arg id "${migration_id}" --arg path "${path}" --arg sha "${migration_sha}" \
				'$entries + [{id:$id,path:$path,sha256:$sha}]')"
		done
	fi
	migration_path="from-${predecessor}-to-${version}.json"
	migration_id="${predecessor}-to-${version}"
	jq -n --arg id "${migration_id}" --arg predecessor "${predecessor}" --arg version "${version}" --argjson operations "${operations}" \
		'{schema:"starter-migration/v2",id:$id,from_version:$predecessor,to_version:$version,operations:$operations}' >"${output}/migrations/${migration_path}"
	migration_sha="$(sha256sum "${output}/migrations/${migration_path}" | cut -d' ' -f1)"
	migration_entries="$(jq -cn --argjson entries "${migration_entries}" --arg id "${migration_id}" --arg path "${migration_path}" --arg sha "${migration_sha}" \
		'$entries + [{id:$id,path:$path,sha256:$sha}]')"
	jq -n --arg version "${version}" --arg official "${official}" --arg derived_id "${identity}" \
		--arg predecessor "${predecessor}" --arg ownership_sha "${ownership_sha}" --argjson migrations "${migration_entries}" --argjson entries "${payload_entries}" '{
		schema:"starter-manifest/v2",source:{id:"gentle-starter",release:("starter/v"+$version)},release:{version:$version,predecessor_version:$predecessor,predecessor_id:null},
		identities:{official_tree:("sha256:"+$official),derived_tree:("sha256:"+$derived_id)},
		transformation:{schema:"gentle-starter.derived-tree-transformation/v1"},
		ownership:{schema:"gentle-starter.ownership-inventory/v2",path:"ownership.json",sha256:$ownership_sha},
		payload:{root:"payloads",closure:"exact",entries:$entries},
		migrations:{root:"migrations",entries:$migrations}
	}' >"${output}/manifest.json"
	jq -n --arg version "${version}" --arg manifest_sha "$(sha256sum "${output}/manifest.json" | cut -d' ' -f1)" \
		'{schema:"gentle-starter.publication/v2",selector:("starter/v"+$version),manifest_sha256:$manifest_sha,publish:false}' >"${output}/publication.json"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	main "$@"
fi
