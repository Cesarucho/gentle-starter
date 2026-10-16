#!/usr/bin/env python3
import json
import os
import sys


def volume_pair(volume):
    if isinstance(volume, dict):
        if volume.get("type") != "bind":
            return None
        source = volume.get("source", "")
        target = volume.get("target", "")
    elif isinstance(volume, str) and ":" in volume:
        source, remainder = volume.split(":", 1)
        target = remainder.split(":", 1)[0]
    else:
        return None
    if not isinstance(source, str) or not isinstance(target, str):
        return None
    if not source or not target or "\0" in source or "\0" in target:
        return None
    return source, target


def main():
    volumes = json.load(sys.stdin)
    if not isinstance(volumes, list):
        raise SystemExit("Compose volumes must be a JSON array")
    output = sys.stdout.buffer
    for volume in volumes:
        pair = volume_pair(volume)
        if pair is None:
            continue
        for value in pair:
            output.write(os.fsencode(value))
            output.write(b"\0")


if __name__ == "__main__":
    main()
