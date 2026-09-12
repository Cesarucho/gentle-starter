#!/usr/bin/env python3
"""Publish a synthetic projection for isolated consumer tests, not host preparation."""
import importlib.util
import json
from pathlib import Path
import sys

workspace = Path(sys.argv[1]).resolve()
spec = importlib.util.spec_from_file_location("manifest", workspace / ".taskfiles/scripts/compose-manifest.py")
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
volumes = json.load(sys.stdin)
for volume in volumes:
    if volume.get("type") == "bind":
        volume["source"] = str((workspace / ".devcontainer" / volume["source"]).absolute())
value = module.project_manifest(workspace, *module.selection(workspace), {"volumes": volumes})
(workspace / module.MANIFEST).write_text(json.dumps(value))
print(value["id"])
