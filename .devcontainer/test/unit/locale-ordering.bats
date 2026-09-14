#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_ROOT="$(mktemp -d)"
	INSTALL_ROOT="${TEST_ROOT}/install"
	BIN_DIR="${TEST_ROOT}/bin"
	CALLS="${TEST_ROOT}/calls"
	mkdir -p "${INSTALL_ROOT}/01-foundation" "${INSTALL_ROOT}/lib" "${BIN_DIR}"
	cp "${REPO_ROOT}/.devcontainer/install/01-foundation/11-locale.sh" "${INSTALL_ROOT}/01-foundation/"
	cat >"${INSTALL_ROOT}/lib/common.sh" <<'SH'
devcontainer_log_info() { :; }
devcontainer_log_error() { printf '%s\n' "$*" >&2; }
devcontainer_run_as_root() { "$@"; }
SH
	for command_name in locale-gen update-locale dpkg-reconfigure; do
		cat >"${BIN_DIR}/${command_name}" <<'SH'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >>"${CALLS}"
SH
		chmod +x "${BIN_DIR}/${command_name}"
	done
	cat >"${TEST_ROOT}/locale.gen" <<'EOF'
# en_US.UTF-8 UTF-8
# es_MX.UTF-8 UTF-8
EOF
}

teardown() {
	rm -rf "${TEST_ROOT}"
}

run_locale_installer() {
	run env PATH="${BIN_DIR}:${PATH}" CALLS="${CALLS}" \
		DEVCONTAINER_LOCALE_GEN_FILE="${TEST_ROOT}/locale.gen" LOCALE="${1:-es_MX.UTF-8}" \
		TZ=America/Mexico_City bash "${INSTALL_ROOT}/01-foundation/11-locale.sh"
}

@test "locale generation is ordered after the package installer" {
	mapfile -t core_scripts < <(find "${REPO_ROOT}/.devcontainer/install/01-foundation" -maxdepth 1 -type f -name '*.sh' -printf '%f\n' | LC_ALL=C sort)
	[ "${core_scripts[0]}" = "00-pre-apt.sh" ]
	local package_index=-1 locale_index=-1 index
	for index in "${!core_scripts[@]}"; do
		case "${core_scripts[index]}" in
		10-system.sh) package_index="${index}" ;;
		11-locale.sh) locale_index="${index}" ;;
		esac
	done
	[ "${package_index}" -ge 0 ]
	[ "${locale_index}" -gt "${package_index}" ]
	! grep -qE 'locale-gen|update-locale|dpkg-reconfigure' "${REPO_ROOT}/.devcontainer/install/01-foundation/00-pre-apt.sh"
}

@test "default locale is enabled and activated" {
	run_locale_installer
	[ "${status}" -eq 0 ]
	grep -qx 'es_MX.UTF-8 UTF-8' "${TEST_ROOT}/locale.gen"
	grep -qx 'locale-gen es_MX.UTF-8' "${CALLS}"
	grep -qx 'update-locale LANG=es_MX.UTF-8 LANGUAGE=es_MX.UTF-8 LC_ALL=es_MX.UTF-8' "${CALLS}"
}

@test "available locale override is enabled" {
	run_locale_installer en_US.UTF-8
	[ "${status}" -eq 0 ]
	grep -qx 'en_US.UTF-8 UTF-8' "${TEST_ROOT}/locale.gen"
	grep -qx 'locale-gen en_US.UTF-8' "${CALLS}"
}

@test "invalid and unavailable locale overrides fail before mutation or commands" {
	cp "${TEST_ROOT}/locale.gen" "${TEST_ROOT}/before"
	run_locale_installer 'es_MX.UTF-8;true'
	[ "${status}" -ne 0 ]
	cmp "${TEST_ROOT}/before" "${TEST_ROOT}/locale.gen"
	[ ! -e "${CALLS}" ]

	run_locale_installer zz_ZZ.UTF-8
	[ "${status}" -ne 0 ]
	cmp "${TEST_ROOT}/before" "${TEST_ROOT}/locale.gen"
	[ ! -e "${CALLS}" ]
}

@test "locale activation is idempotent" {
	run_locale_installer
	[ "${status}" -eq 0 ]
	run_locale_installer
	[ "${status}" -eq 0 ]
	[ "$(grep -c '^es_MX.UTF-8 UTF-8$' "${TEST_ROOT}/locale.gen")" -eq 1 ]
}

@test "locale setup remains entirely inside the foundation cache boundary" {
	foundation="$(awk '/^FROM \$\{IMAGE\} AS foundation$/{capture=1; next} capture && /^FROM /{exit} capture' "${REPO_ROOT}/.devcontainer/Dockerfile")"
	[[ "${foundation}" == *'ARG LOCALE=es_MX.UTF-8'* ]]
	[[ "${foundation}" == *'COPY install/01-foundation/'* ]]
	[[ "${foundation}" != *'tool-versions.conf'* ]]
	[[ "${foundation}" != *'ENV LANG=C.UTF-8'* ]]
	[[ "${foundation}" != *'ENV LANGUAGE=C.UTF-8'* ]]
	[[ "${foundation}" != *'ENV LC_ALL=C.UTF-8'* ]]
	[[ "${foundation}" == *$'RUN LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8 \\\n    chown '* ]]
	[[ "${foundation}" == *$'run-installers.sh ./.devcontainer-install/01-foundation\n\nENV LANG=${LOCALE}\nENV LANGUAGE=${LOCALE}\nENV LC_ALL=${LOCALE}'* ]]
}
