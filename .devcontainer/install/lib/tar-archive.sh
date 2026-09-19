#!/usr/bin/env bash

if [ -n "${_DEVCONTAINER_TAR_ARCHIVE_SH_LOADED:-}" ]; then
	return 0
fi
readonly _DEVCONTAINER_TAR_ARCHIVE_SH_LOADED=1

devcontainer_validate_single_binary_tar() {
	local archive="$1" binary_name="$2" destination="$3"
	python3 - "${archive}" "${binary_name}" <<'PY'
import pathlib, sys, tarfile

archive, binary = sys.argv[1:]
with tarfile.open(archive, "r:gz") as bundle:
    members = bundle.getmembers()
    if len(members) != 1:
        raise SystemExit("archive must contain exactly one entry")
    member = members[0]
    path = pathlib.PurePosixPath(member.name)
    if path.is_absolute() or ".." in path.parts or path.parts != (binary,):
        raise SystemExit("archive has an unexpected binary layout")
    if not member.isfile() or member.islnk() or member.issym():
        raise SystemExit("archive binary must be one regular file")
PY
	mkdir -p "${destination}"
	tar -xzf "${archive}" -C "${destination}" -- "${binary_name}"
}

devcontainer_validate_engram_tar() {
	local archive="$1" destination="$2"
	python3 - "${archive}" <<'PY'
import pathlib, sys, tarfile

with tarfile.open(sys.argv[1], "r:gz") as bundle:
    names = set()
    binary_count = 0
    for member in bundle.getmembers():
        path = pathlib.PurePosixPath(member.name)
        normalized = path.as_posix()
        if normalized in names:
            raise SystemExit("Engram archive contains duplicate entries")
        names.add(normalized)
        if (path.is_absolute() or ".." in path.parts or len(path.parts) != 1
                or member.name != normalized):
            raise SystemExit("Engram archive has an unsafe or unexpected layout")
        if not member.isfile() or member.islnk() or member.issym():
            raise SystemExit("Engram archive entries must be regular root files")
        if normalized == "engram":
            binary_count += 1
    if binary_count != 1:
        raise SystemExit("Engram archive must contain exactly one regular root engram binary")
PY
	mkdir -p "${destination}"
	tar -xzf "${archive}" -C "${destination}" -- engram
}

devcontainer_validate_rooted_tar() {
	local archive="$1" root="$2" required_file="$3" destination="$4"
	python3 - "${archive}" "${root}" "${required_file}" <<'PY'
import pathlib, sys, tarfile

archive, root, required = sys.argv[1:]
canonical = f"{root}/{required}"
canonical_count = 0
with tarfile.open(archive, "r:gz") as bundle:
    for member in bundle.getmembers():
        path = pathlib.PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts or not path.parts or path.parts[0] != root:
            raise SystemExit("archive has an unsafe or unexpected layout")
        if not (member.isfile() or member.isdir()) or member.islnk() or member.issym():
            raise SystemExit("archive contains a link or special entry")
        if member.name.rstrip("/") == canonical:
            canonical_count += 1
            if not member.isfile():
                raise SystemExit("canonical archive file is not regular")
if canonical_count != 1:
    raise SystemExit("archive must contain exactly one canonical file")
PY
	mkdir -p "${destination}"
	tar -xzf "${archive}" -C "${destination}"
}

devcontainer_validate_bats_tar() {
	local archive="$1" root="$2" destination="$3"
	python3 - "${archive}" "${root}" <<'PY'
import pathlib, sys, tarfile

archive, root = sys.argv[1:]
allowed_links = {
    "test/fixtures/parallel/setup_file/setup_file1.bats": "./setup_file.bats",
    "test/fixtures/parallel/setup_file/setup_file2.bats": "./setup_file.bats",
    "test/fixtures/parallel/setup_file/setup_file3.bats": "./setup_file.bats",
    "test/fixtures/parallel/suite/parallel2.bats": "parallel1.bats",
    "test/fixtures/parallel/suite/parallel3.bats": "parallel1.bats",
    "test/fixtures/parallel/suite/parallel4.bats": "parallel1.bats",
    "test/fixtures/suite/recursive_with_symlinks/subsuite": "../recursive/subsuite/",
    "test/fixtures/suite/recursive_with_symlinks/test.bats": "../recursive/test.bats",
    "test/fixtures/suite_setup_teardown/pick_up_toplevel/folder1/setup_suite.bash": "../setup_suite.bash",
    "test/fixtures/suite_setup_teardown/pick_up_toplevel/folder2/setup_suite.bash": "../setup_suite.bash",
}
seen = set()
seen_links = {}
canonical = f"{root}/install.sh"
with tarfile.open(archive, "r:gz") as bundle:
    for member in bundle.getmembers():
        path = pathlib.PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts or not path.parts or path.parts[0] != root:
            raise SystemExit("BATS archive has an unsafe or unexpected layout")
        normalized = member.name.rstrip("/")
        if normalized in seen:
            raise SystemExit("BATS archive contains duplicate entries")
        seen.add(normalized)
        if member.issym():
            relative = pathlib.PurePosixPath(*path.parts[1:]).as_posix()
            if allowed_links.get(relative) != member.linkname:
                raise SystemExit("BATS archive contains an unexpected symbolic link")
            seen_links[relative] = member.linkname
        elif not (member.isfile() or member.isdir()) or member.islnk():
            raise SystemExit("BATS archive contains a hard link or special entry")
if seen_links != allowed_links:
    raise SystemExit("BATS archive does not match the expected symbolic-link manifest")
if canonical not in seen:
    raise SystemExit("BATS archive is missing install.sh")
PY
	mkdir -p "${destination}"
	tar -xzf "${archive}" -C "${destination}"
}
