#!/usr/bin/env bash
# Read-only normalized discovery for the Ubuntu-targeted Gentle Starter install tree.
set -euo pipefail

format=text
root_arg="${PWD}"
for arg in "$@"; do
	case "${arg}" in
	--format=json) format=json ;;
	--help | -h)
		printf 'Usage: %s [--format=json] [repository]\n' "${0##*/}"
		exit 0
		;;
	-*)
		printf 'ERROR: unknown option: %s\n' "${arg}" >&2
		exit 2
		;;
	*) root_arg="${arg}" ;;
	esac
done

if [ ! -d "${root_arg}" ]; then
	printf 'ERROR: repository root is not a directory: %s\n' "${root_arg}" >&2
	exit 2
fi
root="$(git -C "${root_arg}" rev-parse --show-toplevel 2>/dev/null || realpath -e -- "${root_arg}")"
if [ ! -d "${root}/.devcontainer/install" ]; then
	printf 'ERROR: invalid repository root; missing .devcontainer/install: %s\n' "${root}" >&2
	exit 2
fi

python3 - "${root}" "${format}" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
output_format = sys.argv[2]
install = root / ".devcontainer/install"
available_dir = install / "available"
enabled_dir = install / "02-enabled"
canonical_available_dir = available_dir.resolve(strict=True) if available_dir.is_dir() else None

def classify_alias(link):
    target = str(link.readlink())
    try:
        resolved = link.resolve(strict=True)
    except (FileNotFoundError, RuntimeError):
        return {"alias": link.name, "target": target, "broken": True, "unsafe_reason": None}

    try:
        resolved.relative_to(canonical_available_dir)
    except (TypeError, ValueError):
        return {"alias": link.name, "target": target, "broken": False, "unsafe_reason": "outside_available"}

    if not resolved.is_file() or resolved.suffix != ".sh":
        return {"alias": link.name, "target": target, "broken": False, "unsafe_reason": "not_regular_shell_installer"}

    return {"alias": link.name, "target": target, "broken": False, "unsafe_reason": None}

available = []
for installer in sorted(available_dir.glob("*.sh")) if available_dir.is_dir() else []:
    aliases = []
    if enabled_dir.is_dir():
        for link in sorted(enabled_dir.iterdir()):
            if link.is_symlink():
                try:
                    classification = classify_alias(link)
                    if (not classification["broken"] and
                            classification["unsafe_reason"] is None and
                            link.resolve(strict=True) == installer.resolve(strict=True)):
                        aliases.append(link.name)
                except (FileNotFoundError, RuntimeError):
                    pass
    available.append({"installer": installer.name, "enabled_aliases": aliases})

enabled = []
slots = {}
if enabled_dir.is_dir():
    for link in sorted(enabled_dir.iterdir()):
        if not link.is_symlink():
            continue
        item = classify_alias(link)
        slot_match = re.match(r"^(\d+)-", link.name)
        slot = slot_match.group(1) if slot_match else None
        if slot:
            slots.setdefault(slot, []).append(link.name)
        item["slot"] = slot
        enabled.append(item)

policy = root / ".devcontainer/tool-versions.conf"
keys = []
if policy.is_file():
    keys = sorted(re.findall(r"^(TOOL_[A-Z0-9_]+)=", policy.read_text(), re.MULTILINE))

path_candidates = {
    "canonical_template": install / "templates/install-script.sh",
    "config_seed": root / ".devcontainer/setup.sh",
    "compose": root / ".devcontainer/docker-compose.yml",
    "bind_records": root / ".devcontainer/compose-volume-records.py",
    "host_prepare_shell": root / ".taskfiles/scripts/prepare-bind-mounts.sh",
    "host_prepare_python": root / ".taskfiles/scripts/prepare-bind-mounts.py",
    "state_owners": root / ".devcontainer/setup-volumes.sh",
    "install_helper": root / ".taskfiles/scripts/install.sh",
    "updater": root / ".taskfiles/scripts/deps-update.sh",
    "unit_tests": root / ".devcontainer/test/unit",
    "integration_tests": root / ".devcontainer/test/integration",
}
paths = {name: str(path.relative_to(root)) for name, path in path_candidates.items() if path.exists()}

facts = {
    "repository": str(root),
    "platform_assumption": "Ubuntu 24.04 / linux amd64-or-arm64; verify installer-specific support",
    "available": available,
    "enabled": enabled,
    "broken_aliases": [item["alias"] for item in enabled if item["broken"]],
    "unsafe_aliases": [
        {"alias": item["alias"], "reason": item["unsafe_reason"]}
        for item in enabled if item["unsafe_reason"]
    ],
    "duplicate_slots": {slot: names for slot, names in slots.items() if len(names) > 1},
    "policy": {"path": str(policy.relative_to(root)) if policy.exists() else None, "keys": keys},
    "paths": paths,
}

if output_format == "json":
    print(json.dumps(facts, indent=2, sort_keys=True))
else:
    print(f"Repository: {facts['repository']}")
    print(f"Assumption: {facts['platform_assumption']}")
    print(f"Available installers: {len(available)}")
    print(f"Enabled aliases: {len(enabled)}")
    for item in enabled:
        if item["broken"]:
            suffix = " [BROKEN]"
        elif item["unsafe_reason"]:
            suffix = f" [UNSAFE: {item['unsafe_reason']}]"
        else:
            suffix = ""
        print(f"  {item['alias']} -> {item['target']}{suffix}")
    print("Broken aliases: " + (", ".join(facts["broken_aliases"]) or "none"))
    unsafe_text = ", ".join(f"{item['alias']}={item['reason']}" for item in facts["unsafe_aliases"])
    print("Unsafe aliases: " + (unsafe_text or "none"))
    duplicate_text = ", ".join(f"{slot}=[{', '.join(names)}]" for slot, names in facts["duplicate_slots"].items())
    print("Duplicate slots: " + (duplicate_text or "none"))
    print(f"Policy: {facts['policy']['path'] or 'not discovered'} ({len(keys)} keys)")
    print("Discovered paths:")
    for name, path in sorted(paths.items()):
        print(f"  {name}: {path}")
    print("Next: classify the change, then read the closest real installer and focused test.")
PY
