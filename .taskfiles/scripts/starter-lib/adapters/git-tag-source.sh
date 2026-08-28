#!/usr/bin/env bash
# Git-only verified source adapter. Fetched content is treated strictly as data.

GIT_TAG_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.taskfiles/scripts/starter-lib/contracts/source-port.sh
source "${GIT_TAG_SOURCE_DIR}/../contracts/source-port.sh"

git_tag_source_error() {
	printf 'GitTagSource: %s\n' "$*" >&2
}

git_tag_sha256_id() {
	local domain="$1" value="$2"
	printf '%s\n%s\n' "${domain}" "${value}" | sha256sum | cut -d' ' -f1 | sed 's/^/sha256:/'
}

git_tag_relative_path() {
	jq -en --arg path "$1" '$path | type == "string" and length > 0 and
		(startswith("/") | not) and (split("/") | all(. != "" and . != "." and . != ".."))' >/dev/null
}

git_tag_remote_url() {
	local remote="$1"
	case "${remote}" in
	https://* | ssh://* | git://* | file:///*) ;;
	*)
		git_tag_source_error "remote must be an explicit URL"
		return 1
		;;
	esac
	[[ "${remote}" != *[$'\n\r\t ']* ]] || {
		git_tag_source_error "remote must be an explicit URL"
		return 1
	}
}

git_tag_verify_signature() {
	local repository="$1" tag_oid="$2" key_file="$3" key_home verify_output
	key_home="$(mktemp -d)"
	chmod 0700 "${key_home}"
	if ! GNUPGHOME="${key_home}" gpg --batch --quiet --import "${key_file}" >/dev/null 2>&1; then
		rm -rf "${key_home}"
		git_tag_source_error "pinned release key is invalid"
		return 1
	fi
	if ! verify_output="$(GNUPGHOME="${key_home}" git --git-dir="${repository}" -c gpg.program=gpg verify-tag --raw "${tag_oid}" 2>&1)"; then
		rm -rf "${key_home}"
		git_tag_source_error "annotated tag signature is invalid"
		return 1
	fi
	rm -rf "${key_home}"
	GTS_SIGNER_FINGERPRINT="$(sed -n 's/^\[GNUPG:\] VALIDSIG \([0-9A-F]\{40\}\).*/\1/p' <<<"${verify_output}" | head -n 1)"
	[ -n "${GTS_SIGNER_FINGERPRINT}" ] || {
		git_tag_source_error "annotated tag signature has no valid signer identity"
		return 1
	}
}

git_tag_verify_release() {
	local repository="$1" selector="$2" source_id="$3" policy_file="$4" key_file="$5" manifest_out="$6"
	local selected_version tag_type metadata key_name policy_key manifest_blob manifest_sha
	selected_version="${selector#starter/v}"
	GTS_TAG_OID="$(git --git-dir="${repository}" rev-parse --verify "refs/tags/${selector}^{tag}" 2>/dev/null)" || {
		git_tag_source_error "selected ref is not an annotated tag"
		return 1
	}
	tag_type="$(git --git-dir="${repository}" cat-file -t "${GTS_TAG_OID}" 2>/dev/null)"
	[ "${tag_type}" = tag ] || {
		git_tag_source_error "selected ref is not an annotated tag"
		return 1
	}
	git_tag_verify_signature "${repository}" "${GTS_TAG_OID}" "${key_file}" || return 1
	GTS_POLICY_RESULT="$(signer_policy_evaluate "${policy_file}" "openpgp:${GTS_SIGNER_FINGERPRINT}" "${selected_version}")" || return 1
	key_name="$(basename "${key_file}")"
	policy_key="$(jq -r --arg signer "openpgp:${GTS_SIGNER_FINGERPRINT}" '.signers[] | select(.subject_id == $signer) | .key_file' "${policy_file}")"
	[ "${policy_key}" = "${key_name}" ] || {
		git_tag_source_error "policy signer key does not match pinned key file"
		return 1
	}
	metadata="$(git --git-dir="${repository}" for-each-ref --format='%(contents:subject)' "refs/tags/${selector}")"
	jq -e 'def oid: type == "string" and test("^[0-9a-f]{40,64}$");
		def sha: type == "string" and test("^[0-9a-f]{64}$");
		type == "object" and (keys | sort) == ["commit_oid","manifest","schema","source_id","tree_oid","version"] and
		.schema == "gentle-starter.git-tag/v1" and (.source_id | type == "string" and length > 0) and
		(.version | test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")) and
		(.commit_oid | oid) and (.tree_oid | oid) and
		(.manifest | type == "object" and (keys | sort) == ["blob_oid","path","sha256"] and
			(.blob_oid | oid) and (.path == "manifest.json") and (.sha256 | sha))' <<<"${metadata}" >/dev/null || {
		git_tag_source_error "signed tag metadata is invalid"
		return 1
	}
	if [ "$(jq -r '.version' <<<"${metadata}")" != "${selected_version}" ] ||
		[ "$(jq -r '.source_id' <<<"${metadata}")" != "${source_id}" ]; then
		git_tag_source_error "release binding mismatch"
		return 1
	fi
	GTS_COMMIT_OID="$(git --git-dir="${repository}" rev-parse "${GTS_TAG_OID}^{commit}")"
	[ "$(jq -r '.commit_oid' <<<"${metadata}")" = "${GTS_COMMIT_OID}" ] || {
		git_tag_source_error "commit binding mismatch"
		return 1
	}
	GTS_TREE_OID="$(git --git-dir="${repository}" rev-parse "${GTS_COMMIT_OID}^{tree}")"
	[ "$(jq -r '.tree_oid' <<<"${metadata}")" = "${GTS_TREE_OID}" ] || {
		git_tag_source_error "tree binding mismatch"
		return 1
	}
	manifest_blob="$(git --git-dir="${repository}" rev-parse "${GTS_COMMIT_OID}:manifest.json" 2>/dev/null)" || {
		git_tag_source_error "manifest binding mismatch"
		return 1
	}
	git --git-dir="${repository}" cat-file blob "${manifest_blob}" >"${manifest_out}"
	manifest_sha="$(sha256sum "${manifest_out}" | cut -d' ' -f1)"
	if [ "$(jq -r '.manifest.blob_oid' <<<"${metadata}")" != "${manifest_blob}" ] ||
		[ "$(jq -r '.manifest.sha256' <<<"${metadata}")" != "${manifest_sha}" ]; then
		git_tag_source_error "manifest binding mismatch"
		return 1
	fi
	jq -e --arg source "${source_id}" --arg release "${selector}" --arg version "${selected_version}" '
		def relative: type == "string" and length > 0 and (startswith("/") | not) and
			(split("/") | all(. != "" and . != "." and . != ".."));
		def sha: type == "string" and test("^[0-9a-f]{64}$");
		type == "object" and ((keys | sort) == ["payload","release","schema","source"] or
			(keys | sort) == ["migrations","payload","release","schema","source"]) and
		.schema == "starter-manifest/v1" and
		(.source == {id:$source,release:$release}) and
		(.release | type == "object" and (keys | sort) == ["predecessor_id","version"] and .version == $version and
			(.predecessor_id == null or (.predecessor_id | type == "string" and test("^sha256:[0-9a-f]{64}$")))) and
		(.payload | type == "object" and (keys | sort) == ["entries","root"] and .root == "payloads" and
			(.entries | type == "array" and length > 0 and all(type == "object" and
				(keys | sort) == ["bytes","path","sha256"] and (.path | relative) and (.sha256 | sha) and
				(.bytes | type == "number" and . >= 0 and floor == .)) and
				(map(.path) as $paths | ($paths | length) == ($paths | unique | length)))) and
		(if has("migrations") then
			(.migrations | type == "object" and (keys | sort) == ["entries","root"] and .root == "migrations" and
				(.entries | type == "array" and length > 0 and all(type == "object" and
					(keys | sort) == ["id","path","sha256"] and (.id | type == "string" and length > 0) and
					(.path | relative) and (.sha256 | sha)) and
					(map(.id) as $ids | ($ids | length) == ($ids | unique | length)) and
					(map(.path) as $paths | ($paths | length) == ($paths | unique | length))))
		 else true end)
	' "${manifest_out}" >/dev/null || {
		git_tag_source_error "release binding mismatch"
		return 1
	}
	GTS_MANIFEST_BLOB="${manifest_blob}"
	GTS_MANIFEST_SHA="${manifest_sha}"
}

git_tag_materialize_payload() {
	local repository="$1" manifest="$2" destination="$3" count index path object_path mode sha bytes
	mkdir -p "${destination}/payloads"
	cp "${manifest}" "${destination}/manifest.json"
	count="$(jq '.payload.entries | length' "${manifest}")"
	for ((index = 0; index < count; index++)); do
		path="$(jq -r ".payload.entries[${index}].path" "${manifest}")"
		git_tag_relative_path "${path}" || {
			git_tag_source_error "manifest payload path is unsafe"
			return 1
		}
		object_path="payloads/${path}"
		mode="$(git --git-dir="${repository}" ls-tree "${GTS_COMMIT_OID}" -- "${object_path}" | cut -d' ' -f1)"
		case "${mode}" in 100644 | 100755) ;; *)
			git_tag_source_error "payload entry is not a regular blob"
			return 1
			;;
		esac
		mkdir -p "${destination}/payloads/$(dirname "${path}")"
		git --git-dir="${repository}" show "${GTS_COMMIT_OID}:${object_path}" >"${destination}/payloads/${path}"
		sha="$(jq -r ".payload.entries[${index}].sha256" "${manifest}")"
		bytes="$(jq -r ".payload.entries[${index}].bytes" "${manifest}")"
		if [ "$(sha256sum "${destination}/payloads/${path}" | cut -d' ' -f1)" != "${sha}" ] ||
			[ "$(wc -c <"${destination}/payloads/${path}")" -ne "${bytes}" ]; then
			git_tag_source_error "manifest payload binding mismatch"
			return 1
		fi
	done
}

git_tag_materialize_migrations() {
	local repository="$1" manifest="$2" destination="$3"
	local count index path object_path mode sha
	jq -e 'has("migrations")' "${manifest}" >/dev/null || return 0
	mkdir -p "${destination}/migrations"
	count="$(jq '.migrations.entries | length' "${manifest}")"
	for ((index = 0; index < count; index++)); do
		path="$(jq -r ".migrations.entries[${index}].path" "${manifest}")"
		object_path="migrations/${path}"
		mode="$(git --git-dir="${repository}" ls-tree "${GTS_COMMIT_OID}" -- "${object_path}" | cut -d' ' -f1)"
		case "${mode}" in 100644 | 100755) ;; *)
			git_tag_source_error "migration descriptor is not a regular blob"
			return 1
			;;
		esac
		mkdir -p "${destination}/migrations/$(dirname "${path}")"
		git --git-dir="${repository}" show "${GTS_COMMIT_OID}:${object_path}" >"${destination}/migrations/${path}"
		sha="$(jq -r ".migrations.entries[${index}].sha256" "${manifest}")"
		[ "$(sha256sum "${destination}/migrations/${path}" | cut -d' ' -f1)" = "${sha}" ] || {
			git_tag_source_error "manifest migration binding mismatch"
			return 1
		}
	done
}

git_tag_validate_materialized_migrations() {
	local manifest="$1" materialized="$2"
	local count index path sha
	jq -e 'has("migrations")' "${manifest}" >/dev/null || return 0
	count="$(jq '.migrations.entries | length' "${manifest}")"
	for ((index = 0; index < count; index++)); do
		path="$(jq -r ".migrations.entries[${index}].path" "${manifest}")"
		sha="$(jq -r ".migrations.entries[${index}].sha256" "${manifest}")"
		if [ ! -f "${materialized}/migrations/${path}" ] ||
			[ "$(sha256sum "${materialized}/migrations/${path}" | cut -d' ' -f1)" != "${sha}" ]; then
			git_tag_source_error "materialized migration binding mismatch"
			return 1
		fi
	done
}

git_tag_write_closure() {
	local repository="$1" tag_oid="$2" output="$3" oid type size
	{
		printf '%s\n' "${tag_oid}"
		git --git-dir="${repository}" rev-list --objects "${tag_oid}^{}" | cut -d' ' -f1
	} | sort -u >"${output}.oids"
	: >"${output}.tsv"
	while IFS= read -r oid; do
		type="$(git --git-dir="${repository}" cat-file -t "${oid}")" || return 1
		size="$(git --git-dir="${repository}" cat-file -s "${oid}")" || return 1
		printf '%s\t%s\t%s\n' "${oid}" "${type}" "${size}" >>"${output}.tsv"
	done <"${output}.oids"
	jq -Rn '[inputs | split("\t") | {oid:.[0],type:.[1],bytes:(.[2]|tonumber)}]' <"${output}.tsv" >"${output}"
	rm -f "${output}.oids" "${output}.tsv"
}

git_tag_pack_bytes() {
	local repository="$1" pack pack_bytes=0
	for pack in "${repository}"/objects/pack/*.pack; do
		[ -f "${pack}" ] || continue
		pack_bytes=$((pack_bytes + $(wc -c <"${pack}")))
	done
	printf '%s\n' "${pack_bytes}"
}

git_tag_enforce_evidence_limits() {
	local repository="$1" policy_file="$2" closure_file="$3"
	local object_count max_object_bytes retained_bytes pack_bytes
	local object_limit object_bytes_limit pack_limit retained_limit
	object_count="$(jq 'if type == "array" then length else .closure | length end' "${closure_file}")" || return 1
	max_object_bytes="$(jq 'if type == "array" then [.[].bytes] else [.closure[].bytes] end | max // 0' "${closure_file}")" || return 1
	retained_bytes="$(jq 'if type == "array" then [.[].bytes] else [.closure[].bytes] end | add // 0' "${closure_file}")" || return 1
	pack_bytes="$(git_tag_pack_bytes "${repository}")" || return 1
	object_limit="$(jq -r '.evidence_limits.max_reachable_objects' "${policy_file}")"
	object_bytes_limit="$(jq -r '.evidence_limits.max_object_bytes' "${policy_file}")"
	pack_limit="$(jq -r '.evidence_limits.max_pack_bytes' "${policy_file}")"
	retained_limit="$(jq -r '.evidence_limits.max_retained_bytes' "${policy_file}")"
	[ "${object_count}" -le "${object_limit}" ] || {
		git_tag_source_error "reachable object count exceeds policy limit"
		return 1
	}
	[ "${max_object_bytes}" -le "${object_bytes_limit}" ] || {
		git_tag_source_error "per-object size exceeds policy limit"
		return 1
	}
	[ "${pack_bytes}" -le "${pack_limit}" ] || {
		git_tag_source_error "pack size exceeds policy limit"
		return 1
	}
	[ "${retained_bytes}" -le "${retained_limit}" ] || {
		git_tag_source_error "aggregate retained bytes exceed policy limit"
		return 1
	}
}

git_tag_source_acquire() (
	local request_file="$1" remote selector output_dir policy_file key_file source_id governance_file output_parent temporary
	local repository manifest evidence retained_key index_sha source_identity release_identity content_identity envelope_sha
	trap '[ -z "${temporary:-}" ] || rm -rf "${temporary}"' EXIT
	jq -e 'type == "object" and
		((keys | sort) == ["key_file","output_dir","policy_file","remote","schema","selector","source_id"] or
		 (keys | sort) == ["key_file","output_dir","policy_file","publisher_governance_file","remote","schema","selector","source_id"]) and
		.schema == "gentle-starter.git-tag-source-request/v1" and
		all(.remote,.selector,.output_dir,.policy_file,.key_file,.source_id; type == "string" and length > 0) and
		(.publisher_governance_file? | . == null or (type == "string" and length > 0))' "${request_file}" >/dev/null || {
		git_tag_source_error "acquisition request is invalid"
		return 1
	}
	remote="$(jq -r '.remote' "${request_file}")"
	selector="$(jq -r '.selector' "${request_file}")"
	output_dir="$(jq -r '.output_dir' "${request_file}")"
	policy_file="$(jq -r '.policy_file' "${request_file}")"
	key_file="$(jq -r '.key_file' "${request_file}")"
	source_id="$(jq -r '.source_id' "${request_file}")"
	governance_file="$(jq -r '.publisher_governance_file // empty' "${request_file}")"
	git_tag_remote_url "${remote}" || return 1
	[[ "${selector}" =~ ^starter/v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
		git_tag_source_error "selector must be an exact starter semantic tag"
		return 1
	}
	if [[ "${output_dir}" != /* ]] || [ -e "${output_dir}" ] || [ ! -f "${policy_file}" ] || [ ! -f "${key_file}" ] ||
		{ [ -n "${governance_file}" ] && [ ! -f "${governance_file}" ]; }; then
		git_tag_source_error "acquisition paths are invalid or output already exists"
		return 1
	fi
	starter_require_command git
	starter_require_command gpg
	starter_require_command jq
	output_parent="$(dirname "${output_dir}")"
	[ -d "${output_parent}" ] || {
		git_tag_source_error "output parent is unavailable"
		return 1
	}
	temporary="$(mktemp -d "${output_parent}/.git-tag-source.XXXXXX")"
	repository="${temporary}/evidence/repository.git"
	manifest="${temporary}/manifest.json"
	evidence="${temporary}/evidence"
	mkdir -p "${evidence}"
	git init -q --bare "${repository}"
	git --git-dir="${repository}" fetch -q --no-tags "${remote}" "+refs/tags/${selector}:refs/tags/${selector}" 2>/dev/null || {
		git_tag_source_error "exact tag is unavailable"
		return 1
	}
	git_tag_verify_release "${repository}" "${selector}" "${source_id}" "${policy_file}" "${key_file}" "${manifest}" || return 1
	git --git-dir="${repository}" -c gc.writeCommitGraph=false repack -adq || {
		git_tag_source_error "fetched Git closure could not be packed"
		return 1
	}
	git --git-dir="${repository}" fsck --full --strict --no-dangling >/dev/null 2>&1 || {
		git_tag_source_error "fetched Git closure is incomplete"
		return 1
	}
	git_tag_materialize_payload "${repository}" "${manifest}" "${temporary}/materialized" || return 1
	git_tag_materialize_migrations "${repository}" "${manifest}" "${temporary}/materialized" || return 1
	git_tag_write_closure "${repository}" "${GTS_TAG_OID}" "${temporary}/closure.json" || {
		git_tag_source_error "fetched Git closure is incomplete"
		return 1
	}
	git_tag_enforce_evidence_limits "${repository}" "${policy_file}" "${temporary}/closure.json" || return 1
	retained_key="$(basename "${key_file}")"
	cp "${policy_file}" "${evidence}/policy.json"
	cp "${key_file}" "${evidence}/${retained_key}"
	jq -n --arg source_id "${source_id}" --arg selector "${selector}" --arg tag "${GTS_TAG_OID}" --arg commit "${GTS_COMMIT_OID}" \
		--arg tree "${GTS_TREE_OID}" --arg blob "${GTS_MANIFEST_BLOB}" --arg manifest_sha "${GTS_MANIFEST_SHA}" \
		--arg signer "openpgp:${GTS_SIGNER_FINGERPRINT}" --arg policy_sha "$(sha256sum "${evidence}/policy.json" | cut -d' ' -f1)" \
		--arg key_file "${retained_key}" --arg key_sha "$(sha256sum "${evidence}/${retained_key}" | cut -d' ' -f1)" --slurpfile closure "${temporary}/closure.json" '{
		schema:"gentle-starter.git-evidence/v1",source_id:$source_id,selector:$selector,tag_oid:$tag,commit_oid:$commit,
		tree_oid:$tree,manifest_blob_oid:$blob,manifest_sha256:$manifest_sha,signer_subject_id:$signer,
		policy_sha256:$policy_sha,key_file:$key_file,key_sha256:$key_sha,closure:$closure[0]
	}' >"${evidence}/index.json"
	rm "${temporary}/closure.json"
	index_sha="$(jq -cS . "${evidence}/index.json" | sha256sum | cut -d' ' -f1)"
	source_identity="$(git_tag_sha256_id source "${source_id}")"
	release_identity="$(git_tag_sha256_id release "${GTS_TAG_OID}")"
	content_identity="$(git_tag_sha256_id content "${GTS_TREE_OID}")"
	jq -n --arg source "${source_identity}" --arg release "${release_identity}" --arg content "${content_identity}" \
		--arg version "${selector#starter/v}" --argjson predecessor "$(jq '.release.predecessor_id' "${manifest}")" \
		--arg manifest_sha "${GTS_MANIFEST_SHA}" --argjson entries "$(jq '.payload.entries' "${manifest}")" \
		--argjson verification "${GTS_POLICY_RESULT}" --arg evidence_ref "${output_dir}/evidence" --arg evidence_sha "${index_sha}" '{
		schema:"gentle-starter.verified-payload/v1",source:{adapter_id:"GitTagSource/v1",source_id:$source},
		release:{id:$release,version:$version,predecessor_id:$predecessor},immutable_identities:[{role:"release",id:$release},{role:"content",id:$content}],
		manifest:{schema:"starter-manifest/v1",path:"manifest.json",sha256:$manifest_sha},payload:{root:"payloads",entries:$entries},
		verification:$verification,evidence:{adapter_id:"GitTagSource/v1",ref:$evidence_ref,sha256:$evidence_sha}
	}' >"${temporary}/envelope.json"
	envelope_sha="$(jq -cS 'del(.integrity)' "${temporary}/envelope.json" | sha256sum | cut -d' ' -f1)"
	jq --arg sha "${envelope_sha}" '.integrity={canonicalization:"jq-sorted-utf8-v1",envelope_sha256:$sha}' "${temporary}/envelope.json" >"${temporary}/envelope.tmp"
	mv "${temporary}/envelope.tmp" "${temporary}/envelope.json"
	verified_payload_validate "${temporary}/envelope.json" "${temporary}/materialized" || return 1
	mv "${temporary}" "${output_dir}"
	temporary=""
	jq -cn --arg envelope_file "${output_dir}/envelope.json" --arg payload_root "${output_dir}/materialized" '{envelope_file:$envelope_file,payload_root:$payload_root}'
)

git_tag_evidence_revalidate() (
	local evidence="$1" root repository index envelope materialized key_file expected actual temporary count index_position oid type bytes
	if [[ "${evidence}" != /* ]] || [ ! -d "${evidence}" ]; then
		git_tag_source_error "evidence reference is invalid"
		return 1
	fi
	root="$(dirname "${evidence}")"
	repository="${evidence}/repository.git"
	index="${evidence}/index.json"
	envelope="${root}/envelope.json"
	materialized="${root}/materialized"
	if [ ! -f "${index}" ] || [ ! -f "${envelope}" ] || [ ! -d "${repository}" ]; then
		git_tag_source_error "retained evidence is incomplete"
		return 1
	fi
	expected="$(jq -r '.evidence.sha256' "${envelope}")"
	actual="$(jq -cS . "${index}" | sha256sum | cut -d' ' -f1)"
	[ "${actual}" = "${expected}" ] || {
		git_tag_source_error "evidence digest mismatch"
		return 1
	}
	key_file="$(jq -r '.key_file' "${index}")"
	[[ "${key_file}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.asc$ ]] || {
		git_tag_source_error "retained trust evidence is corrupt"
		return 1
	}
	if [ "$(sha256sum "${evidence}/policy.json" | cut -d' ' -f1)" != "$(jq -r '.policy_sha256' "${index}")" ] ||
		[ "$(sha256sum "${evidence}/${key_file}" | cut -d' ' -f1)" != "$(jq -r '.key_sha256' "${index}")" ]; then
		git_tag_source_error "retained trust evidence is corrupt"
		return 1
	fi
	git_tag_enforce_evidence_limits "${repository}" "${evidence}/policy.json" "${index}" || return 1
	git --git-dir="${repository}" fsck --full --strict --no-dangling >/dev/null 2>&1 || {
		git_tag_source_error "retained Git closure is corrupt"
		return 1
	}
	count="$(jq '.closure | length' "${index}")"
	for ((index_position = 0; index_position < count; index_position++)); do
		oid="$(jq -r ".closure[${index_position}].oid" "${index}")"
		type="$(jq -r ".closure[${index_position}].type" "${index}")"
		bytes="$(jq -r ".closure[${index_position}].bytes" "${index}")"
		if [ "$(git --git-dir="${repository}" cat-file -t "${oid}" 2>/dev/null)" != "${type}" ] ||
			[ "$(git --git-dir="${repository}" cat-file -s "${oid}" 2>/dev/null)" != "${bytes}" ]; then
			git_tag_source_error "retained Git closure index is corrupt"
			return 1
		fi
	done
	temporary="$(mktemp)"
	trap 'rm -f "${temporary}"' EXIT
	git_tag_verify_release "${repository}" "$(jq -r '.selector' "${index}")" "$(jq -r '.source_id' "${index}")" \
		"${evidence}/policy.json" "${evidence}/${key_file}" "${temporary}" || return 1
	if [ "${GTS_TAG_OID}" != "$(jq -r '.tag_oid' "${index}")" ] || [ "${GTS_COMMIT_OID}" != "$(jq -r '.commit_oid' "${index}")" ] ||
		[ "${GTS_TREE_OID}" != "$(jq -r '.tree_oid' "${index}")" ] || [ "${GTS_MANIFEST_BLOB}" != "$(jq -r '.manifest_blob_oid' "${index}")" ]; then
		git_tag_source_error "retained identity binding mismatch"
		return 1
	fi
	verified_payload_validate "${envelope}" "${materialized}" || return 1
	git_tag_validate_materialized_migrations "${temporary}" "${materialized}" || return 1
	jq -cn --arg envelope_file "${envelope}" --arg payload_root "${materialized}" '{envelope_file:$envelope_file,payload_root:$payload_root}'
)
