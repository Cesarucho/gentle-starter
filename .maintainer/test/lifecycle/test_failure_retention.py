"""Hermetic failure-retention checks; no Docker daemon is contacted."""

from pathlib import Path
import contextlib
import importlib.util
import io
import tempfile
import unittest
from unittest.mock import patch

from test_resources import LABEL, Run, Unsafe, read_record


def recovery_cli():
    spec = importlib.util.spec_from_file_location("starter_test_clean", Path(__file__).with_name("starter-test-clean.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakeDocker:
    def __init__(self):
        self.containers = {}
        self.calls = []
        self.running = set()

    def daemon(self):
        return "local-daemon"

    def ids(self, kind, filters=()):
        if kind != "container":
            return set()
        if "status=running" in filters:
            return set(self.running)
        return set(self.containers)

    def inspect(self, kind, identity):
        if kind != "container" or identity not in self.containers:
            return None
        return {"id": identity, "labels": self.containers[identity], "tags": [], "created": ""}

    def __call__(self, *args):
        self.calls.append(args)
        if args[0] == "stop":
            self.running.remove(args[1])
        elif args[0] == "rm":
            self.running.discard(args[-1])
            self.containers.pop(args[-1], None)


class RetentionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.root = base / "source"
        self.parent = base / "scratch"
        self.store = base / "metadata" / "registry"
        self.root.mkdir()
        self.parent.mkdir()
        self.store.parent.mkdir()
        self.docker = FakeDocker()
        self.owner = Run.create(self.root, self.parent, store=self.store, docker=self.docker)
        self.addCleanup(self.owner.close)
        self.owner.arm()
        self.identity = "a" * 64
        self.docker.containers[self.identity] = {
            LABEL: self.owner.data["run"],
            "com.docker.compose.project": self.owner.data["project"],
        }
        self.docker.running.add(self.identity)

    def test_failure_keeps_private_scratch_log_and_inventory_and_stops_container(self):
        scratch = Path(self.owner.data["scratch"])
        (scratch / "task.log").write_text("private diagnostic")
        self.owner.finish("interrupted")
        self.owner.retain()
        self.assertEqual(self.docker.calls, [("stop", self.identity)])
        self.assertIn(self.identity, self.docker.containers)
        self.assertEqual((scratch / "task.log").read_text(), "private diagnostic")
        record = read_record(self.owner.path, self.root)
        self.assertEqual(record["running"], [self.identity])
        self.assertEqual(record["outcome"], "retained")
        self.assertEqual(record["test"], "interrupted")
        self.assertEqual(self.store.stat().st_mode & 0o077, 0)
        self.assertEqual(scratch.stat().st_mode & 0o077, 0)
        other = Run.create(self.root, self.parent, store=self.store, docker=self.docker)
        try:
            self.assertNotEqual(other.data["run"], self.owner.data["run"])
        finally:
            other.close()

    def test_conflicting_ownership_prevents_stop(self):
        self.docker.containers[self.identity][LABEL] = "different"
        with self.assertRaises(Unsafe):
            self.owner.retain()
        self.assertEqual(self.docker.calls, [])
        self.assertIn(self.identity, self.docker.running)

    def test_stop_failure_preserves_inventory_for_recovery(self):
        self.owner.finish("failed")
        with patch.object(FakeDocker, "__call__", side_effect=Unsafe("stop failed")):
            with self.assertRaisesRegex(Unsafe, "stop failed"):
                self.owner.retain()
        record = read_record(self.owner.path, self.root)
        self.assertEqual(record["running"], [self.identity])
        self.assertEqual(record["outcome"], "retained")
        self.assertIn(self.identity, self.docker.running)
        self.assertTrue(Path(record["scratch"]).exists())

    def test_failed_discovery_preserves_scope_without_stopping(self):
        self.owner.finish("failed")
        with patch.object(self.docker, "ids", side_effect=Unsafe("query failed")):
            with self.assertRaisesRegex(Unsafe, "query failed"):
                self.owner.retain()
        self.assertEqual(self.docker.calls, [])
        self.assertTrue(self.owner.path.exists())
        self.assertTrue(Path(self.owner.data["scratch"]).exists())

    def test_success_still_removes_owned_resources_and_scratch(self):
        self.owner.finish("passed")
        self.docker.running.clear()
        result = self.owner.cleanup(apply=True)
        self.assertEqual(result["failed"], [])
        self.assertFalse(Path(self.owner.data["scratch"]).exists())
        self.assertEqual(self.owner.data["outcome"], "removed")

    def test_recovery_preview_then_selected_apply_then_forget(self):
        scratch = Path(self.owner.data["scratch"])
        (scratch / "task.log").write_text("sensitive build output")
        self.owner.finish("failed")
        self.owner.retain()
        self.owner.close()
        cli = recovery_cli()
        with patch.object(cli, "command", return_value=str(self.root)), \
             patch.object(cli, "registry_path", return_value=self.store), \
             patch("test_resources.Docker", return_value=self.docker), \
             contextlib.redirect_stdout(io.StringIO()) as output:
            before = self.owner.path.read_bytes()
            self.assertEqual(cli.main(["--run", self.owner.data["run"]]), 0)
            self.assertEqual(self.owner.path.read_bytes(), before)
            self.assertTrue(scratch.exists())
            self.assertEqual(self.docker.calls, [("stop", self.identity)])
            self.assertNotIn("sensitive build output", output.getvalue())
            self.assertEqual(cli.main(["--run", self.owner.data["run"], "--apply"]), 0)
            self.assertFalse(scratch.exists())
            self.assertTrue(self.owner.path.exists())
            self.assertEqual(cli.main(["--run", self.owner.data["run"], "--apply", "--forget"]), 0)
            self.assertFalse(self.owner.path.exists())

    def test_recovery_refuses_forget_when_ownership_changes(self):
        self.owner.finish("failed")
        self.owner.retain()
        self.owner.close()
        self.docker.containers[self.identity][LABEL] = "different"
        cli = recovery_cli()
        with patch.object(cli, "command", return_value=str(self.root)), \
             patch.object(cli, "registry_path", return_value=self.store), \
             patch("test_resources.Docker", return_value=self.docker), \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(cli.main(["--run", self.owner.data["run"], "--apply", "--forget"]), 1)
        self.assertEqual(self.docker.calls, [("stop", self.identity)])
        self.assertTrue(self.owner.path.exists())
        self.assertTrue(Path(self.owner.data["scratch"]).exists())


if __name__ == "__main__":
    unittest.main()
