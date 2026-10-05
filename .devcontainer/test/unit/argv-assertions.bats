#!/usr/bin/env bats

load ../helpers/argv-assertions.bash

@test "argv assertion preserves zero empty space and multiline arguments" {
    local file="${BATS_TEST_TMPDIR}/raw argv" count
    local -a expected=('' ' with spaces\literal ' $'line\nbreak')
    for count in 0 1 3; do
        : >"$file"
        if [ "$count" -gt 0 ]; then printf '%s\0' "${expected[@]:0:count}" >"$file"; fi
        assert_recorded_argv "$file" "${expected[@]:0:count}"
        if [ "$count" -eq 0 ]; then
            if assert_recorded_argv "$file" ''; then return 1; fi
        elif [ "$count" -eq 1 ]; then
            if assert_recorded_argv "$file"; then return 1; fi
        fi
    done
}

@test "argv assertion rejects count order and every mismatch in conditional context" {
    local file="${BATS_TEST_TMPDIR}/argv" mutation
    local -a actual
    for mutation in extra missing zero empty order first last; do
        case "$mutation" in
            extra) actual=(first last extra) ;;
            missing) actual=(first) ;;
            zero) actual=() ;;
            empty) actual=('') ;;
            order) actual=(last first) ;;
            first) actual=(wrong last) ;;
            last) actual=(first wrong) ;;
        esac
        : >"$file"
        if [ "${#actual[@]}" -gt 0 ]; then printf '%s\0' "${actual[@]}" >"$file"; fi
        if assert_recorded_argv "$file" first last; then
            printf 'Unexpected match: %s\n' "$mutation" >&2
            return 1
        fi
    done
}

@test "argv assertion rejects missing files and unterminated raw captures" {
    local file="${BATS_TEST_TMPDIR}/argv" bytes
    if assert_recorded_argv "$file"; then return 1; fi
    for bytes in first 'first\0last'; do
        printf '%b' "$bytes" >"$file"
        if assert_recorded_argv "$file" first; then return 1; fi
    done
    if assert_recorded_argv "$file" first last; then return 1; fi
}
