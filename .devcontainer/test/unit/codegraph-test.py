#!/usr/bin/env python3
"""Offline fixtures only: npm/sudo/native runtime are sandbox stubs."""
import json
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
INSTALLER = ROOT / ".devcontainer/install/available/3060-ai-codegraph.sh"
SPEC = importlib.util.spec_from_file_location("codegraph_fixture", ROOT / ".devcontainer/test/integration/codegraph-fixture.py")
assert SPEC and SPEC.loader
FIXTURE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FIXTURE)

NPM = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ["CALLS"], "a") as stream: stream.write(json.dumps(args) + "\n")
if os.environ.get("NPM_FAIL"): sys.exit(27)
assert "--include=optional" in args and "--ignore-scripts" in args and "--global" in args
root = pathlib.Path(args[args.index("--prefix") + 1])
scope = root / "lib/node_modules/@colbymchenry"
arch = "arm64" if os.environ.get("ARCH") == "aarch64" else "x64"
version = args[-1].rsplit("@", 1)[1]
name = "codegraph-linux-" + arch
main = scope / "codegraph"
main.mkdir(parents=True)
(main / "package.json").write_text(json.dumps({"name":"@colbymchenry/codegraph", "version":version,
    "optionalDependencies":{"@colbymchenry/" + name:version}}))
if os.environ.get("MISSING_BUNDLE"): sys.exit(0)
bundle = main / "node_modules/@colbymchenry" / name
(bundle / "bin").mkdir(parents=True)
(bundle / "lib/dist/bin").mkdir(parents=True)
(bundle / "package.json").write_text(json.dumps({"name":"@colbymchenry/" + name,
    "version":version, "os":["linux"], "cpu":[arch]}))
(bundle / "node").write_text('#!/bin/sh\nexit "${SQLITE_FAIL:-0}"\n')
(bundle / "node").chmod(0o755)
launcher = bundle / "bin/codegraph"
launcher.write_text('#!/usr/bin/env python3\nimport json, os, sys\n'
    'if sys.argv[1:] == ["--version"]: print(os.environ.get("BAD_VERSION", ' + repr(version) + '))\n'
    'else: print(json.dumps({"args":sys.argv[1:], "telemetry":os.environ.get("CODEGRAPH_TELEMETRY"), '
    '"download":os.environ.get("CODEGRAPH_NO_DOWNLOAD"), "update":os.environ.get("CODEGRAPH_NO_UPDATE_CHECK")}))\n')
launcher.chmod(0o755)
(bundle / "lib/dist/bin/codegraph.js").write_text("// fixture\n")
if not os.environ.get("MISSING_GRAMMAR"): (bundle / "lib/dist/parser.wasm").write_bytes(b"fixture")
(bundle / "lib/dist/schema.sql").write_text("-- fixture\n")
'''


class CodeGraphTests(unittest.TestCase):
    def test_isolated_environment_runs_directly_without_unshare(self):
        with patch.object(FIXTURE.socket, "if_nameindex", return_value=[(1, "lo")]), \
                patch.object(FIXTURE, "main") as execute, patch.object(FIXTURE.subprocess, "run") as spawn:
            FIXTURE.run_with_isolation(["1.6.0"])
        execute.assert_called_once_with(["1.6.0"])
        spawn.assert_not_called()

    def test_nonisolated_or_empty_interface_inventory_requires_unshare(self):
        for interfaces in ([(1, "lo"), (2, "eth0")], []):
            with self.subTest(interfaces=interfaces), \
                    patch.object(FIXTURE.socket, "if_nameindex", return_value=interfaces), \
                    patch.object(FIXTURE, "main") as execute, \
                    patch.object(FIXTURE.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as spawn:
                FIXTURE.run_with_isolation(["1.6.0"])
                command = spawn.call_args.args[0]
                self.assertEqual(command[:4], ["unshare", "--user", "--map-current-user", "--net"])
                self.assertNotIn("--isolate", command)  # Child must independently verify isolation.
                self.assertNotIn("capture_output", spawn.call_args.kwargs)
                execute.assert_not_called()

    def test_namespace_failure_or_missing_command_never_runs_unisolated(self):
        for outcome in (subprocess.CompletedProcess([], 17), FileNotFoundError("unshare unavailable")):
            with patch.object(FIXTURE.socket, "if_nameindex", return_value=[(2, "eth0")]), \
                    patch.object(FIXTURE, "main") as execute, patch.object(FIXTURE.subprocess, "run") as spawn:
                if isinstance(outcome, Exception):
                    spawn.side_effect = outcome
                else:
                    spawn.return_value = outcome
                with self.assertRaisesRegex(SystemExit, "isolation|exit 17"):
                    FIXTURE.run_with_isolation(["1.6.0"])
                execute.assert_not_called()

    def test_direct_entry_rechecks_isolation_before_any_cli(self):
        with patch.object(FIXTURE.socket, "if_nameindex", return_value=[(1, "lo"), (2, "eth0")]), \
                patch.object(FIXTURE.shutil, "which") as lookup:
            with self.assertRaisesRegex(SystemExit, "network-isolated"):
                FIXTURE.main(["1.6.0"])
            lookup.assert_not_called()

    def test_interface_inspection_error_fails_closed(self):
        with patch.object(FIXTURE.socket, "if_nameindex", side_effect=OSError("interface inspection failed")), \
                patch.object(FIXTURE, "main") as execute, patch.object(FIXTURE.subprocess, "run") as spawn:
            with self.assertRaisesRegex(OSError, "inspection failed"):
                FIXTURE.run_with_isolation(["1.6.0"])
            execute.assert_not_called()
            spawn.assert_not_called()

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.root / "home").mkdir()
        self.policy = self.root / "policy"
        self.policy.write_text('LOCK_CODEGRAPH_VERSION="1.6.0"\n')
        scripts = {"npm": NPM, "sudo": '#!/bin/sh\nexec "$@"\n',
                   "uname": '#!/bin/sh\nif [ "$1" = -s ]; then echo Linux; else echo "${ARCH:-x86_64}"; fi\n'}
        for name, body in scripts.items():
            (self.bin / name).write_text(body)
            (self.bin / name).chmod(0o755)
        node = shutil.which("node")
        assert node is not None
        self.env = {"PATH": f'{self.bin}:{Path(node).parent}:/usr/bin:/bin',
                    "HOME": str(self.root / "home"), "CALLS": str(self.root / "calls"),
                    "CODEGRAPH_INSTALL_ROOT": str(self.root / "installed"),
                    "CODEGRAPH_BIN": str(self.bin / "codegraph"),
                    "DEVCONTAINER_TOOL_VERSIONS_FILE": str(self.policy)}

    def install(self, **extra):
        return subprocess.run(["bash", str(INSTALLER)], env={**self.env, **extra},
                              capture_output=True, text=True, timeout=15)

    def test_complete_bundle_installs_and_reuses_exact_version(self):
        first = self.install()
        self.assertEqual(first.returncode, 0, first.stderr)
        before = (self.root / "calls").read_bytes()
        second = self.install()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual((self.root / "calls").read_bytes(), before)
        self.assertEqual(list((self.root / "home").iterdir()), [])

    def test_arm64_bundle(self):
        result = self.install(ARCH="aarch64")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_failures_never_publish_launcher_or_leave_staging(self):
        for key, value in (("NPM_FAIL", "1"), ("MISSING_BUNDLE", "1"),
                           ("MISSING_GRAMMAR", "1"), ("BAD_VERSION", "9.0.0"), ("SQLITE_FAIL", "1")):
            with self.subTest(key=key):
                result = self.install(**{key: value})
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((self.bin / "codegraph").exists())
                self.assertEqual(list((self.root / "installed").iterdir()), [])

    def test_unsupported_architecture_and_missing_policy_fail_before_npm(self):
        self.assertNotEqual(self.install(ARCH="riscv64").returncode, 0)
        self.policy.write_text("# empty\n")
        self.assertNotEqual(self.install().returncode, 0)
        self.assertFalse((self.root / "calls").exists())

    def test_runtime_does_not_install_or_initialize(self):
        self.assertEqual(self.install(DEVCONTAINER_PHASE="runtime").returncode, 0)
        self.assertFalse((self.root / "calls").exists())
        self.assertFalse((self.root / "installed").exists())

    def test_new_version_failure_preserves_old_launcher(self):
        self.assertEqual(self.install().returncode, 0)
        old = (self.bin / "codegraph").readlink()
        self.policy.write_text('LOCK_CODEGRAPH_VERSION="1.6.1"\n')
        self.assertNotEqual(self.install(NPM_FAIL="1").returncode, 0)
        self.assertEqual((self.bin / "codegraph").readlink(), old)
        self.assertEqual(self.install().returncode, 0)
        self.assertNotEqual((self.bin / "codegraph").readlink(), old)

    def test_launcher_uses_scoped_defaults_and_preserves_arguments(self):
        self.assertEqual(self.install().returncode, 0)
        result = subprocess.run([str(self.bin / "codegraph"), "query", "two words"],
                                env=self.env, capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(result.stdout), {"args": ["query", "two words"],
                         "telemetry": "0", "update": "1", "download": "1"})
        bundle = (self.root / "installed/1.6.0/bundle").resolve()
        (bundle / "node").unlink()
        result = subprocess.run([str(self.bin / "codegraph"), "--version"], env=self.env, capture_output=True)
        self.assertNotEqual(result.returncode, 0)

    def test_mcp_seeds_are_disabled_and_consistent(self):
        entries = []
        for name in ("opencode.json", "opencode-non-sdd.json"):
            config = json.loads((ROOT / ".devcontainer/opencode-config" / name).read_text())
            entries.append(config["mcp"]["codegraph"])
        self.assertEqual(entries[0], entries[1])
        self.assertIs(entries[0]["enabled"], False)
        self.assertEqual(entries[0]["type"], "local")
        self.assertEqual(entries[0]["command"], ["codegraph", "serve", "--mcp"])

    def test_catalog_is_optional_and_reuses_core_node(self):
        tree = ROOT / ".devcontainer/install"
        self.assertIn('3060-ai-codegraph.sh|enabled|2000-runtime-node.sh|npm',
                      (tree / "dependencies.conf").read_text())
        for group in ("02-core-tools", "03-enabled"):
            self.assertFalse(any(link.resolve() == INSTALLER for link in (tree / group).iterdir()))

    def test_integration_selection_skips_only_disabled_not_missing_cli(self):
        integration = self.root / ".devcontainer/test/integration"
        integration.mkdir(parents=True)
        tree = self.root / ".devcontainer/install"
        for group in ("available", "02-core-tools", "03-enabled"):
            (tree / group).mkdir(parents=True)
        (tree / "available/3060-ai-codegraph.sh").write_text("# never executed\n")
        shutil.copyfile(ROOT / ".devcontainer/test/integration/install-selection.sh", integration / "install-selection.sh")
        fixture = integration / "selection.bats"
        fixture.write_text('load install-selection.sh\n@test "selected CodeGraph" {\n'
                           ' skip_if_install_disabled "3060-ai-codegraph.sh" "enable CodeGraph"\n'
                           ' PATH=/nonexistent command -v codegraph\n}\n')
        disabled = subprocess.run(["bats", str(fixture)], capture_output=True, text=True)
        self.assertEqual(disabled.returncode, 0, disabled.stdout)
        self.assertIn("# skip disabled install", disabled.stdout)
        (tree / "03-enabled/custom.sh").symlink_to("../available/3060-ai-codegraph.sh")
        enabled = subprocess.run(["bats", str(fixture)], capture_output=True, text=True)
        self.assertNotEqual(enabled.returncode, 0)
        self.assertNotIn("# skip", enabled.stdout)

    def test_actual_bats_entry_surfaces_fixture_failure_output(self):
        integration = self.root / ".devcontainer/test/integration"
        integration.mkdir(parents=True)
        tree = self.root / ".devcontainer/install"
        for group in ("available", "02-core-tools", "03-enabled"):
            (tree / group).mkdir(parents=True)
        (tree / "available/3060-ai-codegraph.sh").write_text('printf "CODEGRAPH_VERSION=1.6.0\\n"\n')
        (tree / "03-enabled/custom.sh").symlink_to("../available/3060-ai-codegraph.sh")
        (self.bin / "codegraph").write_text("#!/bin/sh\nexit 0\n")
        (self.bin / "codegraph").chmod(0o755)
        shutil.copyfile(ROOT / ".devcontainer/test/integration/install-selection.sh", integration / "install-selection.sh")
        (integration / "codegraph-fixture.py").write_text('import sys\nprint("fixture isolation diagnostic", file=sys.stderr)\nsys.exit(9)\n')
        source = (ROOT / ".devcontainer/test/integration/tools.bats").read_text()
        heading = '@test "ai: selected CodeGraph'
        block = heading + source.split(heading, 1)[1].split('\n@test ', 1)[0]
        test = integration / "failure.bats"
        test.write_text("load install-selection.sh\n" + block)
        bats = shutil.which("bats")
        assert bats is not None
        result = subprocess.run([bats, str(test)], env={**os.environ, "PATH": self.env["PATH"]},
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture isolation diagnostic", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
