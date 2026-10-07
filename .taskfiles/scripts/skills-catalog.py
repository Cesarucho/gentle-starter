#!/usr/bin/env python3
"""Validate the published recommendations and emit NUL-delimited name/source pairs."""

import json
import re
import sys
from pathlib import Path


catalog_path = Path('.devcontainer/skills/recommended.json')
if not catalog_path.is_file():
    sys.exit('suggest:skills: published catalog unavailable; use the starter branch or install directly with Skills CLI')

try:
    catalog = json.loads(catalog_path.read_text())
    if not isinstance(catalog, dict) or catalog.get('version') != 1 or not isinstance(catalog.get('skills'), dict):
        raise ValueError('unsupported catalog format')
    entries = catalog['skills']
    for name, entry in entries.items():
        if (not isinstance(name, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', name)
                or name == 'add-tool' or not isinstance(entry, dict)
                or not isinstance(entry.get('source'), str) or not entry['source']
                or entry['source'].startswith('-') or any(ord(char) < 32 for char in entry['source'])
                or not isinstance(entry.get('skillPath'), str)
                or not entry['skillPath']):
            raise ValueError('invalid catalog entry')
except (OSError, ValueError) as error:
    sys.exit(f'suggest:skills: {error}')

for name in sorted(entries):
    separator = b'\n' if sys.argv[1:] == ['--lines'] else b'\0'
    sys.stdout.buffer.write(name.encode() + separator + entries[name]['source'].encode() + separator)
