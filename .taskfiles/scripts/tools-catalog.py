#!/usr/bin/env python3
"""Validate consumer recommendations without changing installer selection."""

import importlib.util
import json
from pathlib import Path
import sys

# Validation should not create bytecode state in the consumer install tree.
sys.dont_write_bytecode = True
library = Path(__file__).resolve().parents[2] / '.devcontainer/install/lib/selection.py'
spec = importlib.util.spec_from_file_location('selection', library)
assert spec is not None and spec.loader is not None
selection = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selection)


def recommendations(install):
    path = install / 'recommended-tools.json'
    selection.require(path.is_file() and not path.is_symlink(), 'missing or unsafe recommended-tools.json')
    document = json.loads(path.read_text())
    selection.require(isinstance(document, dict) and set(document) == {'version', 'tools'}
                      and type(document['version']) is int and document['version'] == 1
                      and isinstance(document['tools'], list), 'unsupported tools catalog format')
    roots = document['tools']
    selection.require(all(isinstance(name, str) and selection.CATALOG_NAME.fullmatch(name) for name in roots),
                      'invalid tools catalog entry')
    selection.require(len(roots) == len(set(roots)), 'duplicate tools catalog entry')
    catalog = selection.read_catalog(install)
    active = selection.read_selection(install, catalog)
    selection.validate_core(install, catalog, active)
    graph = selection.read_graph(install, catalog, active)
    if roots:
        names = selection.normalize_roots(roots, catalog, active)
        selection.validate_executable_closure(names, catalog, graph)
    return roots


if __name__ == '__main__':
    try:
        install = Path('.devcontainer/install').absolute()
        with selection.selection_lock(install):
            selection.validate_directories(install)
            roots = recommendations(install)
        for name in roots:
            print(name)
    except (ValueError, OSError, RuntimeError) as error:
        sys.exit(f'suggest:tools: {error}')
