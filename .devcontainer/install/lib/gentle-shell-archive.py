#!/usr/bin/env python3
"""Validate pinned archives without executing their contents."""
import base64
import hashlib
import sys
import tarfile
from pathlib import Path, PurePosixPath


def validate(mode, archive, digest, destination):
    data = Path(archive).read_bytes()
    if mode == "package":
        expected = "sha512-" + base64.b64encode(hashlib.sha512(data).digest()).decode()
    else:
        expected = hashlib.sha256(data).hexdigest()
    if digest != expected:
        raise ValueError("archive integrity mismatch")
    with tarfile.open(archive, "r:gz") as bundle:
        members = bundle.getmembers()
        names = set()
        for member in members:
            path = PurePosixPath(member.name)
            if (not path.parts or path.is_absolute() or ".." in path.parts or str(path) in names
                    or not (member.isfile() or member.isdir())
                    or (mode == "package" and path.parts[0] != "package")):
                raise ValueError("unsafe archive path, duplicate, or entry type")
            names.add(str(path))
        if mode == "binary":
            matches = [member for member in members if member.name == "gentle-ai" and member.isfile()]
            if len(matches) != 1:
                raise ValueError("expected exactly one root gentle-ai regular file")
            stream = bundle.extractfile(matches[0])
            if stream is None:
                raise ValueError("binary content is missing")
            content = stream.read()
            Path(destination).write_bytes(content)
            print(hashlib.sha256(content).hexdigest())
        elif mode == "package":
            bundle.extractall(destination, filter="data")
        else:
            raise ValueError("unknown archive mode")


if __name__ == "__main__":
    try:
        validate(*sys.argv[1:])
    except (ValueError, OSError, tarfile.TarError) as error:
        sys.exit(f"Gentle Shell: {error}")
