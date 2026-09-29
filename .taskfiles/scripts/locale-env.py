#!/usr/bin/env python3
"""Read only root LOCALE/TZ settings without executing dotenv content."""

import re
import sys
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


DEFAULTS = {"LOCALE": "es_MX.UTF-8", "TZ": "America/Mexico_City"}
ASSIGNMENT = re.compile(r"^\s*(LOCALE|TZ)\s*=(.*)$")
LOCALE = re.compile(r"[A-Za-z][A-Za-z0-9_.@-]*\Z")
ZONE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_+.-]*(?:/[A-Za-z0-9_+.-]+)*\Z")


def parse(path):
    values = DEFAULTS.copy()
    seen = set()
    if not path.exists():
        return values
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        match = ASSIGNMENT.fullmatch(line)
        if not match:
            # Reject malformed attempts at the managed keys; ignore other keys.
            if re.match(r"^\s*(?:export\s+)?(?:LOCALE|TZ)\b", line):
                raise ValueError(f"{path}:{number}: invalid LOCALE/TZ assignment")
            continue
        key, raw = match.groups()
        if key in seen:
            raise ValueError(f"{path}:{number}: duplicate {key}")
        seen.add(key)
        raw = raw.strip()
        if raw.startswith(('"', "'")):
            quote = raw[0]
            end = raw.find(quote, 1)
            suffix = raw[end + 1 :].strip() if end >= 0 else ""
            if end < 0 or (suffix and not suffix.startswith("#")):
                raise ValueError(f"{path}:{number}: invalid quoted {key}")
            value = raw[1:end]
        else:
            value = raw.split("#", 1)[0].strip()
        if not (LOCALE.fullmatch(value) if key == "LOCALE" else ZONE.fullmatch(value)):
            raise ValueError(f"{path}:{number}: invalid {key}")
        if key == "TZ" and (value.startswith(".") or "/.." in value):
            raise ValueError(f"{path}:{number}: invalid TZ path")
        if key == "TZ":
            try:
                ZoneInfo(value)
            except ZoneInfoNotFoundError as error:
                raise ValueError(f"{path}:{number}: unavailable TZ: {value}") from error
        values[key] = value
    return values


if __name__ == "__main__":
    try:
        result = parse(Path(sys.argv[1]))
    except (OSError, UnicodeError, ValueError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
    for key in ([sys.argv[2]] if len(sys.argv) > 2 else DEFAULTS):
        print(result[key])
