#!/usr/bin/env python3
"""Shell persistence contracts with a mocked Compose model; never invoke Docker."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


manifest = load("shell_manifest", ROOT / ".taskfiles/scripts/compose-manifest.py")
prep = load("shell_prep", ROOT / ".taskfiles/scripts/prepare-bind-mounts.py")


class ShellStateTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="shell-state-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        config = self.root / ".devcontainer/config/compose"
        config.mkdir(parents=True)
        self.fragment = config / "docker-compose.gentle-shell.yml"
        shutil.copy2(ROOT / ".devcontainer/config/compose/docker-compose.gentle-shell.yml", self.fragment)
        (self.root / ".devcontainer/base.yml").write_text("services: {}\n")
        (self.root / ".devcontainer/devcontainer.json").write_text(
            '{"service":"container-svc","dockerComposeFile":["base.yml","config/compose/docker-compose.gentle-shell.yml"]}')

    def test_optional_selection_and_exact_passive_contract(self):
        selected = manifest.read_compose_fragment(self.fragment)["services"]["container-svc"]
        self.assertEqual(selected, {"volumes": [{"type": "bind", "source": "../.env.d/.gentle-shell",
            "target": "/home/ubuntu/.gentle-shell", "bind": {"create_host_path": False}}]})
        _, paths, _ = manifest.selection(ROOT)
        self.assertNotIn("docker-compose.gentle-shell.yml", [path.name for path in paths])
        lifecycle = (ROOT / ".devcontainer/lifecycle/setup-volumes.sh").read_text()
        self.assertNotIn('"/home/ubuntu/.gentle-shell")', lifecycle)

    def test_host_preparation_preserves_bytes_ownership_and_applied_manifest(self):
        service, paths, inputs = manifest.selection(self.root)
        source = self.root / ".env.d/.gentle-shell"
        selected = {"container_name": "fixture", "volumes": [{"type": "bind", "source": str(source),
            "target": "/home/ubuntu/.gentle-shell", "bind": {"create_host_path": False}}]}
        with patch.object(manifest, "compose_model", return_value=(service, paths, inputs, selected, "fixture")), \
                patch.object(manifest, "check_existing_container") as check, \
                patch.object(manifest.subprocess, "run", side_effect=AssertionError("external execution")), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            manifest.prepare(self.root)
            self.assertEqual(source.stat().st_uid, os.getuid())
            self.assertEqual(source.stat().st_gid, os.getgid())
            sentinel = source / "preferences"
            sentinel.write_bytes(b"preserved\x00bytes")
            sentinel.chmod(0o600)
            before = sentinel.stat()
            manifest.prepare(self.root)
            self.assertEqual(sentinel.stat(), before)
            self.assertEqual(sentinel.read_bytes(), b"preserved\x00bytes")
            value = manifest.load_manifest(self.root)
            check.assert_called_with("fixture", value["id"])
            self.assertEqual(value["volumes"][0]["source"], ".env.d/.gentle-shell")
            with patch.dict(os.environ, {"GENTLE_VOLUME_MANIFEST_ID": "wrong"}):
                with self.assertRaisesRegex(ValueError, "not applied"):
                    manifest.load_manifest(self.root, runtime=True)
            with patch.dict(os.environ, {"GENTLE_VOLUME_MANIFEST_ID": value["id"]}):
                self.assertEqual(manifest.load_manifest(self.root, runtime=True), value)
        with self.assertRaises(SystemExit):
            prep.prepare_directory(str(source), (os.getuid() + 1, os.getgid()))
        self.assertEqual(sentinel.read_bytes(), b"preserved\x00bytes")


if __name__ == "__main__":
    unittest.main()
