assert_recorded_argv() {
	local file="$1" value index
	shift
	local -a actual=() expected=("$@")
	[ -f "$file" ] || return 1
	while IFS= read -r -d '' value; do
		actual+=("$value")
	done <"$file" || return 1
	# A nonempty remainder means the final argument lost its NUL terminator.
	[ -z "$value" ] || return 1
	[ "${#actual[@]}" -eq "${#expected[@]}" ] || return 1
	for ((index = 0; index < ${#expected[@]}; index++)); do
		[ "${actual[index]}" = "${expected[index]}" ] || return 1
	done
	return 0
}
