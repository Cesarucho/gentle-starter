#!/usr/bin/env bash
# Compatibility boundary for the supported yq command-line dialects.

yq_compatibility_error() {
	printf 'yq compatibility: %s\n' "$*" >&2
}

yq_compatibility_detect() {
	local version help
	unset YQ_COMPATIBILITY_DIALECT
	command -v yq >/dev/null 2>&1 || {
		yq_compatibility_error 'yq is required; install Mike Farah yq v4 (recommended) or Kislyuk yq'
		return 1
	}
	version="$(yq --version 2>&1)" || {
		yq_compatibility_error 'could not execute yq --version'
		return 1
	}
	if [[ "${version}" =~ (^|[[:space:]])version[[:space:]]v4([.][0-9]+)+([[:space:]]|$) ]]; then
		YQ_COMPATIBILITY_DIALECT=mike-farah-v4
		return 0
	fi
	help="$(yq --help 2>&1)" || {
		yq_compatibility_error "unsupported yq implementation (${version})"
		return 1
	}
	if [[ "${help}" == *'jq wrapper for YAML documents'* ]] &&
		[[ "${help}" == *'--yaml-output'* ]]; then
		YQ_COMPATIBILITY_DIALECT=kislyuk
		return 0
	fi
	yq_compatibility_error "unsupported yq implementation (${version}); install Mike Farah yq v4 (recommended) or Kislyuk yq"
	return 1
}

yq_compatibility_require() {
	yq_compatibility_detect
}

yq_compatibility_yaml() {
	local expression="$1" input="$2"
	yq_compatibility_require || return 1
	case "${YQ_COMPATIBILITY_DIALECT}" in
	mike-farah-v4) yq -o=yaml "${expression}" "${input}" ;;
	kislyuk) yq -y "${expression}" "${input}" ;;
	*)
		yq_compatibility_error "unsupported detected yq dialect: ${YQ_COMPATIBILITY_DIALECT}"
		return 1
		;;
	esac
}

yq_compatibility_yaml_in_place() {
	local expression="$1" input="$2"
	yq_compatibility_require || return 1
	case "${YQ_COMPATIBILITY_DIALECT}" in
	mike-farah-v4) yq -o=yaml -i "${expression}" "${input}" ;;
	kislyuk) yq -y -i "${expression}" "${input}" ;;
	*)
		yq_compatibility_error "unsupported detected yq dialect: ${YQ_COMPATIBILITY_DIALECT}"
		return 1
		;;
	esac
}

yq_compatibility_raw() {
	local expression="$1" input="$2"
	yq_compatibility_require || return 1
	case "${YQ_COMPATIBILITY_DIALECT}" in
	mike-farah-v4 | kislyuk) yq -r "${expression}" "${input}" ;;
	*)
		yq_compatibility_error "unsupported detected yq dialect: ${YQ_COMPATIBILITY_DIALECT}"
		return 1
		;;
	esac
}

yq_compatibility_service_is_object() {
	local service="$1" input="$2"
	yq_compatibility_require || return 1
	# $service in the Kislyuk expression is a jq variable supplied by --arg.
	# shellcheck disable=SC2016
	case "${YQ_COMPATIBILITY_DIALECT}" in
	mike-farah-v4) SERVICE="${service}" yq -e '.services[strenv(SERVICE)] | type == "!!map"' "${input}" >/dev/null ;;
	kislyuk) yq -e --arg service "${service}" '.services[$service] | type == "object"' "${input}" >/dev/null ;;
	*)
		yq_compatibility_error "unsupported detected yq dialect: ${YQ_COMPATIBILITY_DIALECT}"
		return 1
		;;
	esac
}

yq_compatibility_service_dockerfile() {
	local service="$1" input="$2"
	yq_compatibility_require || return 1
	# $service in the Kislyuk expression is a jq variable supplied by --arg.
	# shellcheck disable=SC2016
	case "${YQ_COMPATIBILITY_DIALECT}" in
	mike-farah-v4) SERVICE="${service}" yq -r '.services[strenv(SERVICE)].build.dockerfile' "${input}" ;;
	kislyuk) yq -r --arg service "${service}" '.services[$service].build.dockerfile' "${input}" ;;
	*)
		yq_compatibility_error "unsupported detected yq dialect: ${YQ_COMPATIBILITY_DIALECT}"
		return 1
		;;
	esac
}
