#!/usr/bin/env bash
set -euo pipefail

MIN_PORT=10000
MAX_PORT=59999
OUTPUT="code"

usage() {
	cat <<EOF
Usage:
  project-identity.sh [PROJECT_NAME] [--output name|code]
  project-identity.sh [PROJECT_NAME] -o name|code

Examples:
  project-identity.sh "César-Fernando"
  project-identity.sh "César-Fernando" --output name
  project-identity.sh "Gentle-Starter" -o code
  project-identity.sh -o code
EOF
}

normalize_name() {
	local input="$1"

	printf "%s" "$input" |
		iconv -f UTF-8 -t ASCII//TRANSLIT |
		tr '[:upper:]' '[:lower:]' |
		sed -E '
            s/[^a-z0-9]+/-/g;
            s/^-+//;
            s/-+$//;
            s/-+/-/g
        '
}

generate_code() {
	local normalized_name="$1"
	local range=$((MAX_PORT - MIN_PORT + 1))

	local hash
	hash="$(printf "%s" "$normalized_name" | sha256sum | cut -c1-8)"

	local decimal=$((16#$hash))

	echo $((MIN_PORT + (decimal % range)))
}

main() {
	local project_name=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-o | --output)
			OUTPUT="${2:-}"
			shift 2
			;;
		-h | --help)
			usage
			exit 0
			;;
		-*)
			echo "Unknown option: $1" >&2
			usage >&2
			exit 1
			;;
		*)
			project_name="$1"
			shift
			;;
		esac
	done

	project_name="${project_name:-$(basename "$PWD")}"

	local normalized_name
	normalized_name="$(normalize_name "$project_name")"

	case "$OUTPUT" in
	name)
		echo "$normalized_name"
		;;
	code)
		generate_code "$normalized_name"
		;;
	*)
		echo "Invalid output: $OUTPUT" >&2
		echo "Allowed values: name, code" >&2
		exit 1
		;;
	esac
}

main "$@"
