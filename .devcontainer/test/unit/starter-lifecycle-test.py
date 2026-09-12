#!/usr/bin/env python3
"""Safe tests: no real Docker, Task lifecycle, installers, or Git commits."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, call, patch


ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("lifecycle", ROOT / ".devcontainer/test/lifecycle/starter-lifecycle.py")
assert SPEC and SPEC.loader
H = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(H)


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        # Any accidentally unmocked external execution fails before reaching the host.
        self.process = patch.object(H.subprocess, "check_output", side_effect=AssertionError("unmocked process"))
        self.process.start()
        self.addCleanup(self.process.stop)
        self.spawn = patch.object(H.subprocess, "run", side_effect=AssertionError("unmocked process"))
        self.spawn.start()
        self.addCleanup(self.spawn.stop)
        self.popen = patch.object(H.subprocess, "Popen", side_effect=AssertionError("unmocked process"))
        self.popen.start()
        self.addCleanup(self.popen.stop)

    def lifecycle(self):
        ownership = Mock(lease=3)
        ownership.data = {"run": "00000000-0000-4000-8000-000000000001"}
        with patch.object(H, "snapshot", return_value={}), patch.object(H, "run", return_value=""):
            lifecycle = H.Lifecycle(self.root, self.root, ownership)
        return lifecycle

    def fixture(self):
        for name in (".devcontainer/install/02-enabled", ".taskfiles/scripts"):
            (self.root / name).mkdir(parents=True)
        for name in (".devcontainer/devcontainer.json", ".devcontainer/docker-compose.yml",
                     ".devcontainer/docker-compose.ssh-agent.yml", ".devcontainer/docker-compose.ssh-server.yml",
                     ".devcontainer/docker-compose.audio.yml", ".taskfiles/scripts/compose-manifest.py"):
            shutil.copyfile(ROOT / name, self.root / name)
        links = self.root / ".devcontainer/install/02-enabled"
        for name in ("30-ai-pi-coding.sh", "30-ai-pi-gentle.sh", "20-tool-ssh-server.sh", "30-ai-gentle-ai.sh"):
            (links / name).symlink_to("../available/" + name)

    def test_base_selection_removes_optional_activation_and_private_mounts(self):
        self.fixture()
        H.configure(self.root)
        config = json.loads((self.root / ".devcontainer/devcontainer.json").read_text())
        self.assertEqual(config["dockerComposeFile"], ["./docker-compose.yml"])
        self.assertEqual(len(config["mounts"]), 1)
        self.assertNotIn("SSH", json.dumps(config))
        self.assertNotIn("pulse", json.dumps(config))
        self.assertEqual(sorted(p.name for p in (self.root / ".devcontainer/install/02-enabled").iterdir()), ["30-ai-gentle-ai.sh"])
        self.assertEqual((self.root / ".env").read_bytes(), b"")
        self.assertEqual((self.root / ".devcontainer/.env").stat().st_mode & 0o777, 0o600)

    def test_custom_service_fails_actionably(self):
        self.fixture()
        config = self.root / ".devcontainer/devcontainer.json"
        config.write_text('{"service":"custom","dockerComposeFile":["docker-compose.yml"]}')
        with self.assertRaisesRegex(ValueError, "review customization"):
            H.configure(self.root)

    def test_environment_does_not_inherit_credentials_or_remote_daemon(self):
        with patch.dict(os.environ, {"SSH_AUTH_SOCK": "/private/socket", "SSH_AUTHORIZED_KEYS": "private",
                                     "DOCKER_HOST": "tcp://remote", "TOKEN": "private"}):
            lifecycle = self.lifecycle()
        self.assertEqual(lifecycle.env["DOCKER_HOST"], "unix:///var/run/docker.sock")
        self.assertFalse({"SSH_AUTH_SOCK", "SSH_AUTHORIZED_KEYS", "TOKEN"} & lifecycle.env.keys())
        self.assertEqual(lifecycle.env["HOME"], str(self.root / "home"))
        self.assertNotIn("FORCE_HOST_CONTEXT", lifecycle.env)

    def test_execute_orders_build_up_persistence_restart_and_rechecks_source(self):
        lifecycle = self.lifecycle()
        lifecycle.docker = Mock(return_value="")
        lifecycle.validate_base = Mock()
        lifecycle.label_candidate = Mock()
        lifecycle.container = Mock(side_effect=["first", "second"])
        events = Mock()
        lifecycle.task = events.task
        lifecycle.assert_state = events.state
        with patch.object(H, "configure"), patch.object(H, "snapshot", return_value={}), \
                patch.object(H, "run", return_value="12000"), patch.object(H.subprocess, "run"):
            lifecycle.execute()
        self.assertEqual(events.mock_calls, [call.task("build"), call.task("up"), call.state("first", write=True),
                                            call.task("restart"), call.state("second")])

    def test_task_failure_keeps_diagnosis_and_does_not_continue(self):
        lifecycle = self.lifecycle()
        lifecycle.ownership.produce.side_effect = H.Unsafe("build failed (17)")
        with self.assertRaisesRegex(RuntimeError, r"build failed \(17\)"):
            lifecycle.task("build")
        args = lifecycle.ownership.produce.call_args.args
        self.assertEqual(args[0], ["task", "container:build"])
        self.assertEqual(args[1], lifecycle.candidate)
        self.assertEqual(args[2]["FORCE_HOST_CONTEXT"], "1")

    def test_interrupted_task_stops_process_group_before_cleanup(self):
        lifecycle = self.lifecycle()
        lifecycle.ownership.produce.side_effect = RuntimeError("interrupted")
        with self.assertRaisesRegex(RuntimeError, "interrupted"):
            lifecycle.task("up")
        lifecycle.ownership.produce.assert_called_once()

    def test_collision_does_not_claim_cleanup_authority(self):
        lifecycle = self.lifecycle()
        lifecycle.ownership.arm.side_effect = H.Unsafe("collision")
        with self.assertRaisesRegex(RuntimeError, "collision"):
            lifecycle.execute()
        lifecycle.ownership.stage.assert_not_called()

    def test_cleanup_delegates_to_shared_engine_and_preserves_failure(self):
        lifecycle = self.lifecycle()
        lifecycle.ownership.cleanup.return_value = {"failed": ["unverifiable"], "removed": [], "retained": []}
        with patch.object(H, "snapshot", return_value={}), patch.object(H, "run", return_value=""):
            errors = lifecycle.cleanup()
        lifecycle.ownership.cleanup.assert_called_once_with(apply=True)
        self.assertEqual(errors, ["unverifiable"])

    def test_cleanup_reports_daemon_failure_and_still_checks_primary(self):
        lifecycle = self.lifecycle()
        lifecycle.ownership.cleanup.return_value = {"failed": ["daemon failed"], "removed": [], "retained": []}
        with patch.object(H, "snapshot", return_value={"changed": True}), patch.object(H, "run", return_value=""), patch.object(H.shutil, "rmtree") as remove:
            errors = lifecycle.cleanup()
        self.assertEqual(len(errors), 2)
        self.assertIn("primary", errors[1])
        remove.assert_not_called()

    def test_candidate_labels_do_not_change_primary_compose(self):
        lifecycle = self.lifecycle()
        path = lifecycle.candidate / ".devcontainer/docker-compose.yml"
        path.parent.mkdir(parents=True)
        module = Mock()
        module.read_compose_fragment.return_value = {"services": {"container-svc": {"build": {}}}}
        with patch.object(H, "resolver", return_value=module):
            lifecycle.label_candidate()
        data = json.loads(path.read_text())
        labels = {H.LABEL: lifecycle.ownership.data["run"]}
        self.assertEqual(data["services"]["container-svc"]["build"]["labels"], labels)
        self.assertEqual(data["networks"]["default"]["labels"], labels)

    def test_snapshot_preserves_exact_modes_and_links_without_reading_env(self):
        (self.root / "source").write_text("public")
        (self.root / "link").symlink_to("source")
        (self.root / ".env").symlink_to("/unreadable/private")
        def git(*args, **kwargs):
            return "source\0link\0.env\0" if "-co" in args else "metadata"
        with patch.object(H, "run", side_effect=git):
            before = H.snapshot(self.root)
            (self.root / "source").chmod(0o640)
            after = H.snapshot(self.root)
        self.assertNotEqual(before, after)
        self.assertNotIn(".env", before["files"])
        self.assertEqual(before["files"]["link"][1:], ["link", "source"])

    def test_mount_validation_checks_identity_before_any_marker_write(self):
        lifecycle = self.lifecycle()
        lifecycle.docker = Mock(side_effect=["[]", "wrong-id"])
        module = Mock()
        module.load_manifest.return_value = {"id": "expected"}
        with patch.object(H, "resolver", return_value=module):
            with self.assertRaisesRegex(RuntimeError, "applied manifest"):
                lifecycle.assert_state("container", write=True)
        self.assertEqual(lifecycle.docker.call_count, 2)

    def test_persistence_checks_actual_mount_owner_and_unique_marker(self):
        lifecycle = self.lifecycle()
        source = lifecycle.candidate / ".env.d/state"
        source.mkdir(parents=True)
        marker = "." + lifecycle.candidate.name + "-marker"
        (source / marker).write_text(marker)
        metadata = source.stat()
        record = {"source": ".env.d/state", "target": "/home/ubuntu/state"}
        lifecycle.bind_metadata[record["target"]] = f"{metadata.st_uid}:{metadata.st_gid}:{metadata.st_mode & 0o777:o}"
        module = Mock()
        module.load_manifest.return_value = {"id": "expected", "volumes": [record]}
        mounts = [{"Type": "bind", "Source": str(source), "Destination": record["target"], "RW": True}]
        lifecycle.docker = Mock(side_effect=[json.dumps(mounts), "expected", "ubuntu",
                                            f"{metadata.st_uid}:{metadata.st_gid}:{metadata.st_mode & 0o777:o}", ""])
        with patch.object(H, "resolver", return_value=module):
            lifecycle.assert_state("container")
        command = lifecycle.docker.call_args.args
        self.assertEqual(command[:4], ("exec", "--user", "ubuntu", "container"))
        self.assertEqual(command[-2:], (record["target"], marker))
        self.assertIn('test "$(cat', command[6])

    def test_mount_mismatch_never_writes_markers(self):
        lifecycle = self.lifecycle()
        module = Mock()
        module.load_manifest.return_value = {"id": "expected", "volumes": [{"source": ".env.d/state", "target": "/state"}]}
        lifecycle.docker = Mock(side_effect=["[]", "expected", "ubuntu"])
        with patch.object(H, "resolver", return_value=module):
            with self.assertRaisesRegex(RuntimeError, "Actual managed bind"):
                lifecycle.assert_state("container", write=True)
        self.assertEqual(lifecycle.docker.call_count, 3)

    def test_external_env_file_is_rejected_before_compose_resolution(self):
        lifecycle = self.lifecycle()
        module = Mock()
        module.read_compose_fragment.return_value = {"services": {"container-svc": {"env_file": ["/private/auth"]}}}
        lifecycle.resolve = Mock(side_effect=AssertionError("must not resolve external env files"))
        with patch.object(H, "resolver", return_value=module):
            with self.assertRaisesRegex(ValueError, "synthetic ../.env"):
                lifecycle.validate_base()
        lifecycle.resolve.assert_not_called()


if __name__ == "__main__":
    unittest.main()
