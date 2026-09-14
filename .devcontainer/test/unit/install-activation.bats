#!/usr/bin/env bats

load install-fixture

@test "enable activates transitive required dependencies but not companions" {
	activate enable 1020-tool-leaf
	[ "$status" -eq 0 ]
	for name in 1000-runtime-base 1010-tool-middle 1020-tool-leaf; do
		[ "$(readlink "${INSTALL}/03-enabled/${name}.sh")" = "../available/${name}.sh" ]
	done
	[ ! -e "${INSTALL}/03-enabled/1030-tool-companion.sh" ]
}

@test "already active consumer repairs missing dependencies without renaming its alias" {
	ln -s ../available/1020-tool-leaf.sh "${INSTALL}/03-enabled/99-custom.sh"
	activate enable 1020-tool-leaf
	[ "$status" -eq 0 ]
	[ -L "${INSTALL}/03-enabled/1000-runtime-base.sh" ]
	[ -L "${INSTALL}/03-enabled/1010-tool-middle.sh" ]
	[ ! -L "${INSTALL}/03-enabled/1020-tool-leaf.sh" ]
	[ "$(readlink "${INSTALL}/03-enabled/99-custom.sh")" = ../available/1020-tool-leaf.sh ]
}

@test "enable rejects an unrelated cycle before creating any links" {
	printf '%s\n' '1000-runtime-base.sh|enabled|1010-tool-middle.sh|middle' >>"${INSTALL}/dependencies.conf"
	activate enable 1030-tool-companion
	[ "$status" -ne 0 ]
	[[ "$output" == *cycle* ]]
	[ -z "$(ls -A "${INSTALL}/03-enabled")" ]
}

@test "enable refuses a preexisting filename collision without replacing it" {
	ln -s ../available/1030-tool-companion.sh "${INSTALL}/03-enabled/1020-tool-leaf.sh"
	activate enable 1020-tool-leaf
	[ "$status" -ne 0 ]
	[ "$(readlink "${INSTALL}/03-enabled/1020-tool-leaf.sh")" = ../available/1030-tool-companion.sh ]
	[ ! -L "${INSTALL}/03-enabled/1000-runtime-base.sh" ]
}

@test "missing mandatory dependency fails rather than duplicating it into optional" {
	printf 'FROM foundation AS core-tools\nCOPY install/available/1000-runtime-base.sh /install/available/\nCOPY install/02-core-tools/ /install/02-core-tools/\nFROM core-tools AS devcontainer\n' >"${FIXTURE}/.devcontainer/Dockerfile"
	activate enable 1020-tool-leaf
	[ "$status" -ne 0 ]
	[[ "$output" == *core* ]]
	[ -z "$(ls -A "${INSTALL}/03-enabled")" ]
}

@test "projected actual alias order is checked before dependency creation" {
	ln -s ../available/1020-tool-leaf.sh "${INSTALL}/03-enabled/00-custom.sh"
	activate enable 1020-tool-leaf
	[ "$status" -ne 0 ]
	[[ "$output" == *"must run before"* ]]
	[ ! -L "${INSTALL}/03-enabled/1000-runtime-base.sh" ]
	[ ! -L "${INSTALL}/03-enabled/1010-tool-middle.sh" ]
}

@test "core dependencies precede optional tools regardless of alias numbers" {
	core_base
	activate enable 1020-tool-leaf
	[ "$status" -eq 0 ]
	[ ! -L "${INSTALL}/03-enabled/1000-runtime-base.sh" ]
	activate doctor
	[ "$status" -eq 0 ]
}

@test "core tools reject enable and disable by canonical name or custom alias" {
	core_base
	for operation in enable disable; do
		activate "$operation" 1000-runtime-base
		[ "$status" -ne 0 ]
		[[ "$output" == *"mandatory 02-core-tools"* ]]
	done
	activate disable 99-custom-base
	[ "$status" -ne 0 ]
	[ -L "${INSTALL}/02-core-tools/99-custom-base.sh" ]
}

@test "disable protects dependents resolved through custom aliases and retains orphans" {
	activate enable 1020-tool-leaf
	[ "$status" -eq 0 ]
	mv "${INSTALL}/03-enabled/1010-tool-middle.sh" "${INSTALL}/03-enabled/1010-custom.sh"
	activate disable 1010-custom
	[ "$status" -ne 0 ]
	[[ "$output" == *"required by enabled installer(s): 1020-tool-leaf.sh"* ]]
	activate disable 1020-tool-leaf
	[ "$status" -eq 0 ]
	activate disable 1010-custom
	[ "$status" -eq 0 ]
	[ -L "${INSTALL}/03-enabled/1000-runtime-base.sh" ]
}

@test "companion activation does not protect a disabled companion dependency" {
	activate enable 1020-tool-leaf
	[ "$status" -eq 0 ]
	activate enable 1030-tool-companion
	[ "$status" -eq 0 ]
	activate disable 1030-tool-companion
	[ "$status" -eq 0 ]
	[ -L "${INSTALL}/03-enabled/1020-tool-leaf.sh" ]
}

@test "unknown graph nodes and invalid edge kinds fail even when unrelated" {
	for record in '1030-tool-companion.sh|enabled|9999-tool-unknown.sh|unknown' \
		'9999-tool-unknown.sh|enabled|1000-runtime-base.sh|base' \
		'1030-tool-companion.sh|optional|1000-runtime-base.sh|base'; do
		printf '%s\n' "$record" >"${INSTALL}/dependencies.conf"
		activate enable 1000-runtime-base
		[ "$status" -ne 0 ]
		[[ "$output" == *unknown* ]]
		[ -z "$(ls -A "${INSTALL}/03-enabled")" ]
	done
}

@test "catalog and alias prefix duplicates fail without mutation" {
	touch "${INSTALL}/available/1000-tool-duplicate.sh"
	activate enable 1020-tool-leaf
	[ "$status" -ne 0 ]
	[[ "$output" == *"duplicate catalog prefix"* ]]
	rm "${INSTALL}/available/1000-tool-duplicate.sh"
	ln -s ../available/1030-tool-companion.sh "${INSTALL}/03-enabled/1010-custom.sh"
	activate enable 1020-tool-leaf
	[ "$status" -ne 0 ]
	[[ "$output" == *"duplicate alias prefix"* ]]
	[ ! -L "${INSTALL}/03-enabled/1000-runtime-base.sh" ]
}

@test "duplicate canonical identity across groups fails before planning" {
	core_base
	ln -s ../available/1000-runtime-base.sh "${INSTALL}/03-enabled/01-duplicate.sh"
	activate enable 1020-tool-leaf
	[ "$status" -ne 0 ]
	[[ "$output" == *"duplicate installer"* ]]
}

@test "broken escaping and regular-file aliases are rejected by both operations" {
	for target in ../available/missing.sh "${FIXTURE}/outside.sh"; do
		touch "${FIXTURE}/outside.sh"
		ln -s "$target" "${INSTALL}/03-enabled/99-unsafe.sh"
		for operation in enable disable; do
			activate "$operation" 1020-tool-leaf
			[ "$status" -ne 0 ]
			[ "$(readlink "${INSTALL}/03-enabled/99-unsafe.sh")" = "$target" ]
		done
		rm "${INSTALL}/03-enabled/99-unsafe.sh"
	done
	touch "${INSTALL}/03-enabled/99-file.sh"
	activate enable 1020-tool-leaf
	[ "$status" -ne 0 ]
	[ -f "${INSTALL}/03-enabled/99-file.sh" ]
}

@test "catalog symlinks and redirected selection directories fail closed" {
	mv "${INSTALL}/available/1030-tool-companion.sh" "${FIXTURE}/outside.sh"
	ln -s "${FIXTURE}/outside.sh" "${INSTALL}/available/1030-tool-companion.sh"
	activate enable 1020-tool-leaf
	[ "$status" -ne 0 ]
	[[ "$output" == *"unsafe catalog"* ]]
	rm "${INSTALL}/available/1030-tool-companion.sh"
	mv "${INSTALL}/03-enabled" "${FIXTURE}/outside-selection"
	ln -s "${FIXTURE}/outside-selection" "${INSTALL}/03-enabled"
	activate enable 1020-tool-leaf
	[ "$status" -ne 0 ]
	[[ "$output" == *"unsafe install directory"* ]]
}

@test "image requirements are checked structurally without running their commands" {
	printf '#!/usr/bin/env bash\nexit 99\n' >"${INSTALL}/01-foundation/10-image.sh"
	printf '%s\n' '1030-tool-companion.sh|image|01-foundation/10-image.sh|missing-host-command' >>"${INSTALL}/dependencies.conf"
	activate enable 1030-tool-companion
	[ "$status" -eq 0 ]
	rm "${INSTALL}/01-foundation/10-image.sh"
	activate enable 1000-runtime-base
	[ "$status" -ne 0 ]
	[[ "$output" == *"image dependency"* ]]
}

@test "unrelated missing dependencies are not silently autoactivated" {
	ln -s ../available/1020-tool-leaf.sh "${INSTALL}/03-enabled/1020-tool-leaf.sh"
	activate enable 1030-tool-companion
	[ "$status" -ne 0 ]
	[[ "$output" == *"requires enabled installer"* ]]
	[ ! -L "${INSTALL}/03-enabled/1030-tool-companion.sh" ]
}

@test "enable and disable share a lock covering inspection and application" {
	run python3 - "${INSTALL}" "${FIXTURE}/.taskfiles/scripts/install.sh" <<'PY'
import fcntl
import subprocess
import sys
import time
from pathlib import Path
install, script = Path(sys.argv[1]), sys.argv[2]
fd = __import__('os').open(install, __import__('os').O_RDONLY)
fcntl.flock(fd, fcntl.LOCK_EX)
processes = [subprocess.Popen(['bash', script, operation, '1030-tool-companion'], stdout=subprocess.PIPE, stderr=subprocess.PIPE) for operation in ('enable', 'disable')]
try:
    time.sleep(0.3)
    assert all(process.poll() is None for process in processes)
    assert not list((install / '03-enabled').iterdir())
    fcntl.flock(fd, fcntl.LOCK_UN)
    for process in processes:
        out, err = process.communicate(timeout=5)
        assert process.returncode == 0, (out, err)
finally:
    __import__('os').close(fd)
    for process in processes:
        if process.poll() is None:
            process.kill()
            process.wait()
PY
	[ "$status" -eq 0 ]
}

@test "failed application rolls back only links owned by the operation" {
	run python3 - "${INSTALL}" <<'PY'
import importlib.util
import sys
from pathlib import Path
from unittest.mock import patch
install = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location('selection', install / 'lib/selection.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
catalog = module.read_catalog(install)
graph = module.read_graph(install, catalog, {})
plan = module.plan_enable('1020-tool-leaf.sh', {}, graph)
original = Path.symlink_to
calls = 0
def fail_after_first(link, target, *args, **kwargs):
    global calls
    calls += 1
    if calls == 2:
        original(link, '../available/1030-tool-companion.sh')
        raise FileExistsError('injected concurrent collision')
    return original(link, target, *args, **kwargs)
with patch.object(Path, 'symlink_to', fail_after_first):
    try:
        module.apply_enable(install, plan, catalog, graph)
    except FileExistsError:
        pass
    else:
        raise AssertionError('expected injected failure')
assert not (install / '03-enabled/1000-runtime-base.sh').is_symlink()
assert (install / '03-enabled/1010-tool-middle.sh').readlink() == Path('../available/1030-tool-companion.sh')
assert not (install / '03-enabled/1020-tool-leaf.sh').is_symlink()
PY
	[ "$status" -eq 0 ]
}

@test "real catalog has valid BBPP names unique prefixes graph references and execution order" {
	run python3 "${REPO_ROOT}/.devcontainer/install/lib/selection.py" "${REPO_ROOT}/.devcontainer/install" validate
	[ "$status" -eq 0 ]
	run env PYTHONDONTWRITEBYTECODE=1 python3 - "${REPO_ROOT}/.devcontainer/install" <<'PY'
import importlib.util
import sys
from pathlib import Path
install = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location('selection', install / 'lib/selection.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
catalog = module.read_catalog(install)
selection = module.read_selection(install, catalog)
graph = module.read_graph(install, catalog, selection)
for name in catalog:
    if name not in selection:
        module.plan_enable(name, selection, graph)
PY
	[ "$status" -eq 0 ]
}

@test "a diamond graph creates its shared prerequisite exactly once" {
	printf '%s\n' '1020-tool-leaf.sh|enabled|1000-runtime-base.sh|base' >>"${INSTALL}/dependencies.conf"
	activate enable 1020-tool-leaf
	[ "$status" -eq 0 ]
	local aliases=("${INSTALL}/03-enabled/"*.sh)
	[ "${#aliases[@]}" -eq 3 ]
	activate doctor
	[ "$status" -eq 0 ]
}

@test "a core consumer cannot depend on a later optional layer" {
	ln -s ../available/1010-tool-middle.sh "${INSTALL}/02-core-tools/99-consumer.sh"
	ln -s ../available/1000-runtime-base.sh "${INSTALL}/03-enabled/01-base.sh"
	printf 'FROM foundation AS core-tools\nCOPY install/available/1010-tool-middle.sh /install/available/\nCOPY install/02-core-tools/ /install/02-core-tools/\nFROM core-tools AS devcontainer\n' >"${FIXTURE}/.devcontainer/Dockerfile"
	activate enable 1030-tool-companion
	[ "$status" -ne 0 ]
	[[ "$output" == *"must run before"* ]]
	[ ! -L "${INSTALL}/03-enabled/1030-tool-companion.sh" ]
}

@test "handled termination after link creation rolls back the owned link" {
	run env PYTHONDONTWRITEBYTECODE=1 python3 - "${INSTALL}" <<'PY'
import importlib.util
import os
import signal
import sys
from pathlib import Path
from unittest.mock import patch
install = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location('selection', install / 'lib/selection.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
catalog = module.read_catalog(install)
graph = module.read_graph(install, catalog, {})
original = Path.symlink_to
def terminate_after_create(link, target):
    original(link, target)
    os.kill(os.getpid(), signal.SIGTERM)
signal.signal(signal.SIGTERM, module.interrupted)
with patch.object(Path, 'symlink_to', terminate_after_create):
    try:
        module.apply_enable(install, [('03-enabled/1030-tool-companion.sh', '1030-tool-companion.sh')], catalog, graph)
    except InterruptedError:
        pass
    else:
        raise AssertionError('expected termination')
assert not list((install / '03-enabled').iterdir())
PY
	[ "$status" -eq 0 ]
}
