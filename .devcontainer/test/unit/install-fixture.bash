setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	FIXTURE="${BATS_TEST_TMPDIR}/activation"
	INSTALL="${FIXTURE}/.devcontainer/install"
	mkdir -p "${FIXTURE}/.taskfiles/scripts" "${INSTALL}/"{available,01-foundation,02-core-tools,03-enabled,04-hooks,lib,templates}
	cp "${REPO_ROOT}/.taskfiles/scripts/install.sh" "${FIXTURE}/.taskfiles/scripts/"
	cp "${REPO_ROOT}/.taskfiles/install.yml" "${FIXTURE}/.taskfiles/"
	printf 'version: "3"\nincludes:\n  install: ./.taskfiles/install.yml\n' >"${FIXTURE}/Taskfile.yml"
	cp -a "${REPO_ROOT}/.devcontainer/install/lib/." "${INSTALL}/lib/"
	touch "${INSTALL}/templates/install-script.sh"
	printf 'FROM foundation AS core-tools\nCOPY install/02-core-tools/ /install/02-core-tools/\nFROM core-tools AS devcontainer\n' >"${FIXTURE}/.devcontainer/Dockerfile"
	for name in 1000-runtime-base 1010-tool-middle 1020-tool-leaf 1030-tool-companion; do
		printf '#!/usr/bin/env bash\nexit 99 # Must never execute installers on the host.\n' >"${INSTALL}/available/${name}.sh"
		chmod 0755 "${INSTALL}/available/${name}.sh"
	done
	printf '%s\n' \
		'1020-tool-leaf.sh|enabled|1010-tool-middle.sh|middle' \
		'1010-tool-middle.sh|enabled|1000-runtime-base.sh|base' \
		'1020-tool-leaf.sh|companion|1030-tool-companion.sh|companion' >"${INSTALL}/dependencies.conf"
}

activate() { run bash "${FIXTURE}/.taskfiles/scripts/install.sh" "$@"; }

core_base() {
	ln -s ../available/1000-runtime-base.sh "${INSTALL}/02-core-tools/99-custom-base.sh"
	printf 'FROM foundation AS core-tools\nCOPY install/available/1000-runtime-base.sh /install/available/\nCOPY install/02-core-tools/ /install/02-core-tools/\nFROM core-tools AS devcontainer\n' >"${FIXTURE}/.devcontainer/Dockerfile"
}
