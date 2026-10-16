#!/usr/bin/env python3
"""Actual CLI proof, requiring an externally isolated network namespace.

No installs or daemons. Default: temporary project, HOME and cross-process DB
reopen. Explicit init/check modes support two isolated containers sharing only
the caller-owned project/state. The caller owns cleanup in those modes.
"""
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import tempfile


def cli(binary, project, home, *arguments):
    env = {"PATH": os.environ["PATH"], "HOME": str(home), "LANG": "C.UTF-8",
           "CODEGRAPH_TELEMETRY": "0", "CODEGRAPH_NO_UPDATE_CHECK": "1",
           "CODEGRAPH_NO_DOWNLOAD": "1", "CODEGRAPH_NO_DAEMON": "1",
           "NODE_COMPILE_CACHE": str(home / "compile-cache")}
    process = subprocess.Popen([binary, *arguments], cwd=project, env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               text=True, start_new_session=True)
    try:
        stdout, stderr = process.communicate(timeout=90)
        if process.returncode:
            raise RuntimeError(f"CodeGraph {arguments[0]} failed: {stderr}")
        return stdout
    finally:
        # Bound all fixture descendants, including workers on errors/timeouts.
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        # A parent can exit before a worker; bound any remaining group members too.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def exercise(mode, project, home, binary, expected):
    if cli(binary, project, home, "--version").strip() != expected:
        raise RuntimeError("Installed CLI does not match LOCK_CODEGRAPH_VERSION")
    if mode == "init":
        if (project / "sample.ts").exists() or (project / ".codegraph/codegraph.db").exists():
            raise RuntimeError("Refusing to overwrite an existing fixture")
        (project / "sample.ts").write_text("export function starterGraphFixture(value: number) { return value + 1; }\n")
        (project / "AGENTS.md").write_text("Fixture instructions must remain unchanged.\n")
        cli(binary, project, home, "init", "--yes")
    status = json.loads(cli(binary, project, home, "status", "--json"))
    assert status["initialized"] is True and status["nodeCount"] > 0, status
    assert status["index"]["state"] == "complete", status
    assert Path(status["indexPath"]) == project / ".codegraph", status
    assert (project / ".codegraph/codegraph.db").stat().st_uid == os.getuid()
    results = json.loads(cli(binary, project, home, "query", "starterGraphFixture", "--json"))
    assert any(result["node"]["name"] == "starterGraphFixture" for result in results), results
    assert (project / "AGENTS.md").read_text() == "Fixture instructions must remain unchanged.\n"
    assert not (home / ".config/opencode").exists()


def network_isolated():
    # Inspect this process's interfaces, not a caller claim or container marker.
    return [name for _, name in socket.if_nameindex()] == ["lo"]


def run_with_isolation(arguments):
    if network_isolated():
        main(arguments)
        return
    try:
        result = subprocess.run(["unshare", "--user", "--map-current-user", "--net",
                                 sys.executable, "-B", str(Path(__file__).resolve()), *arguments],
                                check=False)
    except OSError as error:
        raise SystemExit(f"Cannot create CodeGraph network isolation: {error}") from error
    if result.returncode:
        raise SystemExit(f"Network-isolated CodeGraph fixture failed (exit {result.returncode}); see subprocess output above.")


def main(arguments=None):
    if not network_isolated():
        raise SystemExit("Run in a network-isolated namespace/container; opt-out variables alone are not offline proof.")
    binary = shutil.which("codegraph")
    if not binary:
        raise SystemExit("Selected CodeGraph CLI is missing; rebuild the enabled installer.")
    arguments = sys.argv[1:] if arguments is None else arguments
    expected = arguments[0]
    with tempfile.TemporaryDirectory(prefix="codegraph-proof-") as temporary:
        root = Path(temporary)
        home = root / "home"
        home.mkdir()
        if len(arguments) == 3:
            mode, raw_path = arguments[1:]
            if mode not in {"init", "check"}:
                raise SystemExit("Expected init or check")
            project = Path(raw_path).resolve(strict=True)
            exercise(mode, project, home, binary, expected)
        else:
            project = root / "project"
            project.mkdir()
            exercise("init", project, home, binary, expected)
            # A second HOME/process sees the persisted database, not global state.
            other_home = root / "other-home"
            other_home.mkdir()
            exercise("check", project, other_home, binary, expected)
            other_project = root / "other-project"
            other_project.mkdir()
            status = json.loads(cli(binary, other_project, other_home, "status", "--json"))
            assert status["initialized"] is False, status
    print("CodeGraph offline index/query and persistent reopen verified.")


if __name__ == "__main__":
    if sys.argv[1:2] == ["--isolate"]:
        run_with_isolation(sys.argv[2:])
    else:
        main()
