"""Hermetic checks for bounded lifecycle verification diagnostics."""

import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


def lifecycle_module():
    spec = importlib.util.spec_from_file_location("starter_lifecycle", Path(__file__).with_name("starter-lifecycle.py"))
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class VerifyDiagnosticTests(unittest.TestCase):
    def test_direct_ignored_files_normalize_but_ignored_directory_contents_do_not(self):
        module = lifecycle_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            (root / ".gitignore").write_text("ignored.txt\nignored.sh\nignored/\n")
            (root / "ignored.txt").write_text("file")
            (root / "ignored.sh").write_text("script")
            (root / "ignored").mkdir()
            (root / "ignored" / "private.txt").write_text("private")
            (root / "ignored" / "private.sh").write_text("private script")
            modes = {"ignored.txt": 0o600, "ignored.sh": 0o600,
                     "ignored/private.txt": 0o600, "ignored/private.sh": 0o700}
            for name, mode in modes.items():
                (root / name).chmod(mode)
            ignored = subprocess.check_output(
                ["git", "-C", str(root), "ls-files", "--others", "--ignored",
                 "--exclude-standard", "--directory", "-z"], text=True).split("\0")
            self.assertEqual(set(ignored) - {""}, {"ignored.txt", "ignored.sh", "ignored/"})
            configured = {"head": "head", "branch": "branch", "index": "",
                          "files": {name: [mode, "file", name] for name, mode in modes.items()}}
            expected = module.expected_after_setup(root, configured)
            self.assertEqual({name: value[0] for name, value in expected["files"].items()}, {
                "ignored.txt": 0o644, "ignored.sh": 0o755,
                "ignored/private.txt": 0o600, "ignored/private.sh": 0o700})
            self.assertEqual({name: value[0] for name, value in configured["files"].items()}, modes)

    def test_overlay_modes_expect_setup_normalization_without_changing_source(self):
        module = lifecycle_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            (root / ".gitignore").write_text("ignored/\n")
            (root / "tracked.txt").write_text("tracked")
            (root / "tracked.sh").write_text("executable")
            subprocess.run(["git", "-C", str(root), "add", ".gitignore", "tracked.txt", "tracked.sh"], check=True)
            subprocess.run(["git", "-C", str(root), "update-index", "--chmod=+x", "tracked.sh"], check=True)
            (root / "overlay.txt").write_text("overlay")
            (root / "overlay.sh").write_text("script")
            (root / "ignored").mkdir()
            (root / "ignored" / "private.txt").write_text("untouched")
            for name in ("tracked.txt", "overlay.txt", "ignored/private.txt"):
                (root / name).chmod(0o664)
            for name in ("tracked.sh", "overlay.sh"):
                (root / name).chmod(0o775)
            # No commit is needed: the index supplies tracked modes.
            index = subprocess.check_output(["git", "-C", str(root), "ls-files", "--stage", "-z"], text=True)
            files = {name: [mode, "file", name] for name, mode in {
                "tracked.txt": 0o664, "tracked.sh": 0o775,
                "overlay.txt": 0o664, "overlay.sh": 0o775,
                "ignored/private.txt": 0o664}.items()}
            configured = {"head": "head", "branch": "branch", "index": index, "files": files}
            expected = module.expected_after_setup(root, configured)
            self.assertEqual({name: value[0] for name, value in expected["files"].items()}, {
                "tracked.txt": 0o644, "tracked.sh": 0o755,
                "overlay.txt": 0o644, "overlay.sh": 0o755,
                "ignored/private.txt": 0o664})
            self.assertEqual([value[0] for value in configured["files"].values()],
                             [0o664, 0o775, 0o664, 0o775, 0o664])
            self.assertEqual((root / "overlay.txt").stat().st_mode & 0o777, 0o664)
            self.assertEqual((root / "overlay.sh").stat().st_mode & 0o777, 0o775)
            self.assertEqual(module.snapshot_difference(expected, expected)["mode"], 0)
            self.assertEqual(module.snapshot_difference(expected, configured)["mode"], 4)
            tampered = {**expected, "files": {**expected["files"],
                        "overlay.txt": [0o644, "file", "changed"]}}
            self.assertNotEqual(expected, tampered)
            self.assertEqual(module.snapshot_difference(expected, tampered)["hash-or-link"], 1)

    def test_snapshot_difference_counts_without_disclosing_names_or_values(self):
        module = lifecycle_module()
        before = {"head": "a", "branch": "main", "index": "i", "files": {
            "removed": [0o644, "file", "secret"],
            "modified": [0o664, "file", "old"],
            "link": [0o777, "link", "private-target"],
            "missing": None,
        }}
        after = {"head": "a", "branch": "main", "index": "j", "files": {
            "added": [0o600, "file", "new"],
            "modified": [0o644, "file", "new"],
            "link": [0o777, "file", "private-target"],
            "missing": [0o644, "file", "value"],
        }}
        counts = module.snapshot_difference(before, after)
        self.assertEqual(counts, {"added": 1, "removed": 1, "mode": 1,
                                  "kind": 2, "hash-or-link": 1, "identity": 1})
        self.assertNotIn("private-target", str(counts))
        self.assertNotIn("modified", str(counts))
        lifecycle = module.Lifecycle.__new__(module.Lifecycle)
        lifecycle.verify_check = "candidate-unchanged"
        lifecycle.snapshot_diagnostic = counts
        message = module.failure_message(lifecycle)
        self.assertIn("mode=1", message)
        self.assertNotIn("private-target", message)

    def test_verify_failure_reports_only_safe_check_id(self):
        module = lifecycle_module()
        lifecycle = module.Lifecycle.__new__(module.Lifecycle)
        lifecycle.candidate = Path("/synthetic-candidate")
        lifecycle.root = Path("/synthetic-source")
        lifecycle.env = {}
        lifecycle.ownership = type("Ownership", (), {
            "arm": lambda self: None, "probe_bind": lambda self: None,
            "stage": lambda self, stage: None, "produce": lambda self, *args: None,
        })()
        lifecycle.task = lambda action: None
        lifecycle.container = iter(("first", "second")).__next__
        secret = "private-token-123"
        lifecycle.assert_state = lambda container, write=False: (
            None if write else (_ for _ in ()).throw(RuntimeError(secret)))
        with patch.object(module, "configure"), patch.object(module, "snapshot", return_value={}), \
             patch.object(module, "expected_after_setup", return_value={}), \
             patch.object(module, "run", return_value="3000"), \
             patch.object(module.Lifecycle, "validate_base"), \
             patch.object(module.Lifecycle, "label_candidate"), \
             patch.object(Path, "rglob", return_value=[]):
            with self.assertRaisesRegex(RuntimeError, secret):
                lifecycle.execute()
        message = module.failure_message(lifecycle)
        self.assertIn("verify check: managed-state", message)
        self.assertNotIn(secret, message)
        lifecycle.verify_check = secret
        self.assertNotIn(secret, module.failure_message(lifecycle))


if __name__ == "__main__":
    unittest.main()
