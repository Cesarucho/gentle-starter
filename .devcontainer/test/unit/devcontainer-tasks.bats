#!/usr/bin/env bats
#
# devcontainer-tasks.bats — unit tests for public devcontainer task entrypoints
#
# Run from the repo root:
#   bats .devcontainer/test/unit/devcontainer-tasks.bats

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"

@test "container:opencode continues OpenCode in the default devcontainer workspace" {
	cd "${REPO_ROOT}"

	run task --dry container:opencode

	[ "${status}" -eq 0 ]

	task_definition="$(awk '/^  opencode:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  opencode:/{exit} capture' .taskfiles/devcontainer.yml)"
	[[ "${task_definition}" == *"interactive: true"* ]]
	[[ "${task_definition}" == *"- task: ensure-running"* ]]
	[[ "${task_definition}" == *"- task: run-devcontainer"* ]]
	[[ "${task_definition}" == *"ARGS: exec --workspace-folder {{.WORKSPACE}} opencode --continue"* ]]
}

@test "container:up prepares managed bind sources after the host guard and before startup" {
	cd "${REPO_ROOT}"
	task_definition="$(awk '/^  up:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  up:/{exit} capture' .taskfiles/devcontainer.yml)"
	guard_line="$(grep -nF 'if [ -f /.dockerenv ]' <<<"${task_definition}" | cut -d: -f1)"
	prepare_line="$(grep -nF 'bash .taskfiles/scripts/prepare-bind-mounts.sh' <<<"${task_definition}" | cut -d: -f1)"
	up_line="$(grep -nF 'devcontainer up --workspace-folder' <<<"${task_definition}" | cut -d: -f1)"

	[ -n "${guard_line}" ]
	[ "${guard_line}" -lt "${prepare_line}" ]
	[ "${prepare_line}" -lt "${up_line}" ]
	env_line="$(grep -nF '. .devcontainer/.env' <<<"${task_definition}" | cut -d: -f1)"
	[ "${env_line}" -lt "${prepare_line}" ]
	[[ "${task_definition}" == *'export GENTLE_VOLUME_MANIFEST_ID'* ]]
}

@test "host UID generation is guarded and running containers do not bypass preparation" {
	definition="$(awk '/^  ensure-identity-env:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  ensure-identity-env:/{exit} capture' "${REPO_ROOT}/.taskfiles/devcontainer.yml")"
	guard="$(grep -nF 'if [ -f /.dockerenv ]' <<<"${definition}" | cut -d: -f1)"
	uid="$(grep -nF 'host_uid="$(id -u)"' <<<"${definition}" | cut -d: -f1)"
	[ "${guard}" -lt "${uid}" ]
	[[ "${definition}" != *'HOST_GID'* ]]
	definition="$(awk '/^  ensure-running:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  ensure-running:/{exit} capture' "${REPO_ROOT}/.taskfiles/devcontainer.yml")"
	prepare="$(grep -nF 'prepare-bind-mounts.sh' <<<"${definition}" | cut -d: -f1)"
	running="$(grep -nF 'if docker ps' <<<"${definition}" | cut -d: -f1)"
	[ "${prepare}" -lt "${running}" ]
}

@test "container:rebuild runs remove build and up in exact order" {
	cd "${REPO_ROOT}"
	task_definition="$(awk '/^  rebuild:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  rebuild:/{exit} capture' .taskfiles/devcontainer.yml)"
	rm_line="$(grep -nF 'task container:rm' <<<"${task_definition}" | cut -d: -f1)"
	build_line="$(grep -nF 'task container:build' <<<"${task_definition}" | cut -d: -f1)"
	up_line="$(grep -nF 'task container:up' <<<"${task_definition}" | cut -d: -f1)"

	[ -n "${rm_line}" ]
	[ "${rm_line}" -lt "${build_line}" ]
	[ "${build_line}" -lt "${up_line}" ]
}

@test "container:rebuild host guard precedes all lifecycle calls" {
	cd "${REPO_ROOT}"
	task_definition="$(awk '/^  rebuild:/{capture=1} capture && /^  [[:alnum:]-]+:/ && !/^  rebuild:/{exit} capture' .taskfiles/devcontainer.yml)"
	guard_line="$(grep -nF 'if [ -f /.dockerenv ]' <<<"${task_definition}" | cut -d: -f1)"
	rm_line="$(grep -nF 'task container:rm' <<<"${task_definition}" | cut -d: -f1)"

	[ -n "${guard_line}" ]
	[ "${guard_line}" -lt "${rm_line}" ]
}

@test "Dockerfile isolates core inputs in the foundation cache boundary" {
	cd "${REPO_ROOT}"
	foundation="$(awk '/^FROM \$\{IMAGE\} AS foundation$/{capture=1; next} capture && /^FROM /{exit} capture' .devcontainer/Dockerfile)"
	mapfile -t copy_directives < <(awk '$1 == "COPY" || $1 == "ADD" {$1=$1; print}' <<<"${foundation}")

	[ "${#copy_directives[@]}" -eq 2 ]
	[ "${copy_directives[0]}" = "COPY install/01-foundation/ ./.devcontainer-install/01-foundation/" ]
	[ "${copy_directives[1]}" = "COPY install/lib/common.sh install/lib/run-installers.sh ./.devcontainer-install/lib/" ]
}

@test "Dockerfile routes every installer group through the fail-fast runner" {
	cd "${REPO_ROOT}"
	dockerfile="$(<.devcontainer/Dockerfile)"

	[ "$(grep -c '&& ./.devcontainer-install/lib/run-installers.sh' <<<"${dockerfile}")" -eq 4 ]
	[[ "${dockerfile}" != *'| sort | while'* ]]
}

@test "Dockerfile installs tool-specific inputs only downstream of foundation" {
	cd "${REPO_ROOT}"
	downstream="$(awk '/^FROM foundation AS core-tools$/{capture=1} capture' .devcontainer/Dockerfile)"

	[[ "${downstream}" == *"ARG ENGRAM_VERSION="* ]]
	[[ "${downstream}" == *"COPY tool-versions.conf"* ]]
	[[ "${downstream}" == *"COPY install/available/"* ]]
	[[ "${downstream}" == *"COPY install/02-core-tools/"* ]]
	[[ "${downstream}" == *"COPY install/03-enabled/"* ]]
	[[ "${downstream}" == *"COPY install/04-hooks/"* ]]
}

@test "Dockerfile keeps the cheap version contract independent and synchronized" {
	cd "${REPO_ROOT}"
	contract="$(awk '/^FROM \$\{IMAGE\} AS devcontainer-version-contract$/{capture=1; next} capture && /^FROM /{exit} capture' .devcontainer/Dockerfile)"
	devcontainer="$(awk '/^FROM foundation AS core-tools$/{capture=1; next} capture' .devcontainer/Dockerfile)"
	contract_variables="$(awk '$1 == "ARG" || ($1 == "ENV" && $2 ~ /^(ENGRAM_VERSION|NODE_MAJOR|PLAYWRIGHT_VERSION)=/) {print}' <<<"${contract}")"
	devcontainer_variables="$(awk '$1 == "ARG" && $2 ~ /^(ENGRAM_VERSION|NODE_MAJOR|PLAYWRIGHT_VERSION)=/ || ($1 == "ENV" && $2 ~ /^(ENGRAM_VERSION|NODE_MAJOR|PLAYWRIGHT_VERSION)=/) {print}' <<<"${devcontainer}")"

	[ "$(sort <<<"${contract_variables}")" = "$(sort <<<"${devcontainer_variables}")" ]
	[[ "${contract}" != *"COPY "* ]]
	[[ "${contract}" != *"RUN "* ]]
}

@test "core cache inputs match canonical aliases and exclude project and optional inputs" {
	run python3 - "${REPO_ROOT}" <<'PY'
import re
import shlex
import sys
from pathlib import Path

root = Path(sys.argv[1])
context = root / ".devcontainer"
dockerfile = (context / "Dockerfile").read_text()
core = dockerfile.split("FROM foundation AS core-tools\n", 1)[1].split("\nFROM ", 1)[0]
final = dockerfile.split("FROM core-tools AS devcontainer\n", 1)[1]
foundation = dockerfile.split("AS foundation\n", 1)[1].split("\nFROM ", 1)[0]
assert "APP_NAME" not in foundation + core
assert "PLAYWRIGHT_VERSION" not in foundation + core
assert "ARG APP_NAME=" in final and "ARG PLAYWRIGHT_VERSION=" in final
assert "install/03-enabled" not in core and "install/04-hooks" not in core
copies = [shlex.split(line)[1:-1] for line in core.splitlines() if line.startswith("COPY ")]
sources = {source for instruction in copies for source in instruction}
assert "install/available/" not in sources
aliases = list((context / "install/02-core-tools").glob("*.sh"))
assert all(alias.is_symlink() and alias.is_file() for alias in aliases)
targets = {str(alias.resolve().relative_to(context)) for alias in aliases}
assert len(targets) == len(aliases), "duplicate canonical core installer"
assert targets == {source for source in sources if source.startswith("install/available/")}
assert "tool-versions.conf" in sources and "install/02-core-tools/" in sources
helpers = {"install/lib/common.sh", "install/lib/run-installers.sh"}
helpers |= {source for source in sources if source.startswith("install/lib/")}
for source in targets | helpers:
    assert (context / source).is_file(), source
    for helper in re.findall(r'\$\{SCRIPT_DIR\}/\.\./lib/([^"\s]+)', (context / source).read_text()):
        assert "install/lib/" + helper in helpers, helper
assert core.index("COPY install/02-core-tools/") < core.index("RUN ")
assert final.index("COPY install/03-enabled/") < final.index("run-installers.sh ./.devcontainer-install/03-enabled")
PY
	[ "${status}" -eq 0 ]
}
