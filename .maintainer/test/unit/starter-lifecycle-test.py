#!/usr/bin/env python3
"""Safe tests: no real Docker, Task lifecycle, installers, or Git commits."""

import copy
import importlib.util
import itertools
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, Mock, call, patch


ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("lifecycle", ROOT / ".maintainer/test/lifecycle/starter-lifecycle.py")
assert SPEC and SPEC.loader
H = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(H)
METADATA_QUERY = H.metadata_query


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
        # Existing execution tests exercise post-readiness behavior only.
        readiness = patch.object(H, "preflight", return_value={"readiness": "ready"})
        readiness.start()
        self.addCleanup(readiness.stop)

    def lifecycle(self):
        ownership = Mock(lease=3)
        ownership.data = {"run": "00000000-0000-4000-8000-000000000001"}
        with patch.object(H, "snapshot", return_value={}), patch.object(H, "run", return_value=""):
            lifecycle = H.Lifecycle(self.root, self.root, ownership)
        return lifecycle

    def fixture(self):
        for name in (".devcontainer/install/03-enabled", ".devcontainer/install/02-core-tools", ".taskfiles/scripts", ".devcontainer/config/compose"):
            (self.root / name).mkdir(parents=True)
        for name in (".devcontainer/devcontainer.json", ".devcontainer/docker-compose.yml",
                     ".devcontainer/config/compose/docker-compose.ssh-agent.yml", ".devcontainer/config/compose/docker-compose.ssh-server.yml",
                      ".devcontainer/config/compose/docker-compose.audio.yml",
                      ".devcontainer/config/compose/docker-compose.pi.yml",
                      ".devcontainer/config/compose/docker-compose.gentle-shell.yml",
                     ".devcontainer/config/compose/docker-compose-core-tools.yml", ".taskfiles/scripts/compose-manifest.py"):
            shutil.copyfile(ROOT / name, self.root / name)
        links = self.root / ".devcontainer/install/03-enabled"
        for name in ("3030-ai-pi-coding.sh", "4010-tool-ssh-server.sh", "3020-ai-gentle-ai.sh"):
            (links / name).symlink_to("../available/" + name)
        (self.root / ".devcontainer/install/02-core-tools/3020-ai-gentle-ai.sh").symlink_to("../available/3020-ai-gentle-ai.sh")

    def test_base_selection_removes_optional_activation_and_private_mounts(self):
        self.fixture()
        H.configure(self.root)
        config = json.loads((self.root / ".devcontainer/devcontainer.json").read_text())
        self.assertEqual(config["dockerComposeFile"], ["./docker-compose.yml", "./config/compose/docker-compose-core-tools.yml"])
        self.assertEqual(len(config["mounts"]), 1)
        self.assertNotIn("SSH", json.dumps(config))
        self.assertNotIn("pulse", json.dumps(config))
        self.assertEqual(sorted(p.name for p in (self.root / ".devcontainer/install/03-enabled").iterdir()), ["3020-ai-gentle-ai.sh"])
        self.assertTrue((self.root / ".devcontainer/install/02-core-tools/3020-ai-gentle-ai.sh").is_symlink())
        self.assertEqual((self.root / ".env").read_text(), "LOCALE=en_GB.UTF-8\nTZ=Europe/Madrid\n")
        self.assertEqual((self.root / ".devcontainer/.env").read_bytes(), b"")
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

    def test_execute_orders_build_up_persistence_recreate_and_rechecks_source(self):
        lifecycle = self.lifecycle()
        source_snapshot = {"head": "commit", "branch": "main", "index": "", "files": {}}
        lifecycle.docker = Mock(return_value="")
        lifecycle.validate_base = Mock()
        lifecycle.label_candidate = Mock()
        lifecycle.container = Mock(side_effect=["first", "second"])
        events = Mock()
        lifecycle.task = events.task
        lifecycle.assert_state = events.state
        lifecycle.assert_locale = events.locale
        with patch.object(H, "configure"), patch.object(H, "snapshot", return_value=source_snapshot) as snapshot, \
                patch.object(H, "run", return_value="12000"), patch.object(H.subprocess, "run"):
            lifecycle.execute()
        self.assertEqual(events.mock_calls, [call.task("build"), call.task("up"), call.state("first", write=True),
                                             call.locale("first"), call.task("recreate"), call.state("second"),
                                             call.locale("second")])
        lifecycle.ownership.arm.assert_called_once_with()
        lifecycle.ownership.probe_bind.assert_called_once_with()
        self.assertEqual(snapshot.call_args_list, [call(lifecycle.candidate), call(lifecycle.candidate)])

    def test_locale_assertion_checks_generated_values_runtime_locale_and_timezone(self):
        lifecycle = self.lifecycle()
        lifecycle.candidate.mkdir()
        (lifecycle.candidate / ".devcontainer").mkdir()
        (lifecycle.candidate / ".env").write_text("LOCALE=en_GB.UTF-8\nTZ=Europe/Madrid\n")
        (lifecycle.candidate / ".devcontainer/.env").write_text("LOCALE=en_GB.UTF-8\nTZ=Europe/Madrid\n")
        lifecycle.docker = Mock(side_effect=["en_GB.UTF-8", "en_GB.UTF-8", "en_GB.UTF-8",
                                              "Europe/Madrid", "C\nen_GB.utf8", "/usr/share/zoneinfo/Europe/Madrid"])
        lifecycle.assert_locale("candidate")
        self.assertEqual(lifecycle.docker.call_count, 6)
        (lifecycle.candidate / ".devcontainer/.env").write_text("LOCALE=es_MX.UTF-8\nTZ=Europe/Madrid\n")
        with self.assertRaisesRegex(RuntimeError, "generated LOCALE"):
            lifecycle.assert_locale("candidate")

    def test_probe_failure_prevents_candidate_and_build(self):
        lifecycle = self.lifecycle()
        lifecycle.ownership.probe_bind.side_effect = H.Unsafe("probe failed")
        with self.assertRaisesRegex(H.Unsafe, "probe failed"):
            lifecycle.execute()
        lifecycle.ownership.arm.assert_called_once_with()
        lifecycle.ownership.produce.assert_not_called()
        lifecycle.ownership.stage.assert_not_called()

    def test_cli_default_and_explicit_parent_both_require_probe_before_build(self):
        for argv, parent in ((["lifecycle"], Path("/home/ubuntu")),
                             (["lifecycle", "--daemon-visible-scratch", str(self.root.parent)], self.root.parent)):
            with self.subTest(argv=argv):
                owner = Mock()
                owner.data = {"run": "00000000-0000-4000-8000-000000000001", "scratch": str(self.root / "scratch")}
                owner.path = self.root / "inventory.json"
                owner.cleanup.return_value = {"failed": [], "removed": [], "retained": ["shared cache"]}
                events = []
                def execute(lifecycle):
                    lifecycle.ownership.arm()
                    events.append("armed")
                    lifecycle.ownership.probe_bind()
                    events.append("probe")
                    raise H.Unsafe("probe failed")
                with patch.object(sys, "argv", argv), patch.object(H, "run", return_value=str(self.root)), \
                     patch.object(H, "Run") as run, patch.object(H, "Lifecycle") as lifecycle_class, \
                     patch.object(H.shutil, "which", return_value="available"), patch.object(H.Path, "cwd", return_value=self.root), \
                     patch.object(H.Path, "is_dir", return_value=True), patch.object(H, "snapshot", return_value={}), \
                     patch.object(H.signal, "signal"), patch("builtins.print"):
                    run.create.return_value = owner
                    lifecycle = lifecycle_class.return_value
                    lifecycle.env = dict(os.environ)
                    lifecycle.execute.side_effect = lambda: execute(lifecycle)
                    lifecycle.retain.side_effect = lambda: events.append("retain")
                    self.assertEqual(H.main(), 1)
                run.create.assert_called_once_with(self.root, parent)
                self.assertEqual(events, ["armed", "probe", "retain"])
                owner.finish.assert_called_once_with("failed")
                owner.close.assert_called_once_with()

    def test_default_missing_parent_fails_without_registering_run(self):
        with patch.object(sys, "argv", ["lifecycle"]), patch.object(H, "run", return_value=str(self.root)), \
             patch.object(H.Path, "cwd", return_value=self.root), patch.object(H.Path, "is_dir", return_value=False), \
             patch.object(H, "Run") as run, patch.object(H, "preflight", return_value={"readiness": "not-ready"}), \
             patch("builtins.print"):
            self.assertEqual(H.main(), 1)
        run.create.assert_not_called()

    def test_retention_exception_persists_failed_probe_outcome_and_restores_environment(self):
        owner = Mock()
        owner.data = {"run": "00000000-0000-4000-8000-000000000001", "scratch": str(self.root / "scratch")}
        owner.path = self.root / "inventory.json"
        original_env = dict(os.environ)
        with patch.object(sys, "argv", ["lifecycle", "--daemon-visible-scratch", str(self.root.parent)]), \
             patch.object(H, "run", return_value=str(self.root)), patch.object(H, "Run") as run, \
             patch.object(H, "Lifecycle") as lifecycle_class, \
             patch.object(H.shutil, "which", return_value="available"), \
             patch.object(H.Path, "cwd", return_value=self.root), \
             patch.object(H.signal, "signal"), patch("builtins.print"):
            run.create.return_value = owner
            lifecycle = lifecycle_class.return_value
            lifecycle.env = {"PATH": original_env["PATH"], "HOME": str(self.root / "home")}
            owner.probe_bind.side_effect = H.Unsafe("probe failed")
            lifecycle.execute.side_effect = lambda: (owner.arm(), owner.probe_bind())
            lifecycle.retain.side_effect = H.Unsafe("retention failed")
            self.assertEqual(H.main(), 1)
        owner.finish.assert_called_once_with("failed")
        owner.close.assert_called_once_with()
        self.assertEqual(os.environ, original_env)
        owner.produce.assert_not_called()
        lifecycle.task.assert_not_called()

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

    def test_diagnostic_bounds_untrusted_stage_run_and_snapshot_values(self):
        lifecycle = self.lifecycle()
        lifecycle.verify_check = "candidate-unchanged"
        lifecycle.snapshot_diagnostic = {"mode": "private-secret", "private-key": "private-secret"}
        lifecycle.ownership.data.update(run="private-secret", stage="private-secret")
        message = H.failure_message(lifecycle)
        self.assertIn("run=none", message)
        self.assertIn("stage=unknown", message)
        self.assertIn("reason=candidate-unchanged", message)
        self.assertNotIn("private-secret", message)
        self.assertNotIn("private-key", message)

    def test_execution_and_cleanup_exceptions_remain_distinct_and_never_escape(self):
        owner = Mock()
        owner.data = {"run": "00000000-0000-4000-8000-000000000001", "scratch": str(self.root), "stage": "build"}
        lifecycle = Mock(env={"PATH": os.environ["PATH"]}, before={}, source_status="", verify_check=None)
        lifecycle.ownership = owner
        lifecycle.execute.side_effect = RuntimeError("Authorization: secret-original")
        lifecycle.retain.side_effect = ValueError("traceID=secret-cleanup")
        with patch.object(sys, "argv", ["lifecycle"]), patch.object(H.Run, "create", return_value=owner), \
                patch.object(H, "Lifecycle", return_value=lifecycle), patch.object(H.signal, "signal"), \
                patch.object(H, "snapshot", return_value={}), patch.object(H, "run", return_value=""), \
                patch.object(sys, "stdout", io.StringIO()), patch.object(sys, "stderr", io.StringIO()) as output:
            self.assertEqual(H.main(), 1)
        message = output.getvalue()
        self.assertIn("stage=build", message)
        self.assertIn("stage=cleanup", message)
        self.assertNotIn("secret-original", message)
        self.assertNotIn("secret-cleanup", message)
        owner.finish.assert_called_once_with("failed")
        owner.close.assert_called_once_with()

    def test_cleanup_transport_and_each_exception_boundary_cannot_report_pass(self):
        secret = 'Authorization: synthetic-secret traceID=private {"key":"private"}'
        for boundary in ("constructor", "environment", "cleanup", "cleanup-result", "finish", "close"):
            with self.subTest(boundary=boundary):
                owner = Mock()
                owner.data = {"run": "00000000-0000-4000-8000-000000000001", "scratch": str(self.root), "stage": "verify"}
                lifecycle = Mock(env={"PATH": os.environ["PATH"]}, before={}, source_status="", verify_check=None)
                lifecycle.ownership = owner
                lifecycle.cleanup.return_value = []
                if boundary == "environment":
                    lifecycle.env = {"PATH": object()}
                elif boundary == "cleanup-result":
                    lifecycle.cleanup.return_value = [secret, {"key": secret}]
                elif boundary in {"finish", "close"}:
                    getattr(owner, boundary).side_effect = RuntimeError(secret)
                elif boundary == "cleanup":
                    lifecycle.cleanup.side_effect = RuntimeError(secret)
                original_env = dict(os.environ)
                with patch.object(sys, "argv", ["lifecycle"]), patch.object(H.Run, "create", return_value=owner), \
                        patch.object(H, "Lifecycle", return_value=lifecycle,
                                     side_effect=RuntimeError(secret) if boundary == "constructor" else None), \
                        patch.object(H.signal, "signal"), patch.object(H, "snapshot", return_value={}), \
                        patch.object(H, "run", return_value=""), patch.object(sys, "stdout", io.StringIO()) as public, \
                        patch.object(sys, "stderr", io.StringIO()) as output:
                    self.assertEqual(H.main(), 1)
                self.assertNotIn(secret, public.getvalue() + output.getvalue())
                self.assertNotIn("Primary preservation verified", public.getvalue())
                self.assertIn("stage=" + ("environment" if boundary in {"constructor", "environment"} else "cleanup"), output.getvalue())
                owner.close.assert_called_once_with()
                self.assertEqual(dict(os.environ), original_env)

    def test_normal_task_route_exports_candidate_identity_and_never_bypasses_task(self):
        lifecycle = self.lifecycle()
        lifecycle.env.update(APP_NAME=lifecycle.candidate.name, APP_PORT="3000", OPENCODE_PORT="3001")
        lifecycle.task("up")
        argv, candidate, environment, stage = lifecycle.ownership.produce.call_args.args
        self.assertEqual(argv, ["task", "container:up"])
        self.assertEqual(candidate, lifecycle.candidate)
        self.assertEqual(environment["APP_NAME"], lifecycle.candidate.name)
        self.assertEqual(environment["APP_PORT"], "3000")
        self.assertEqual(environment["OPENCODE_PORT"], "3001")
        self.assertEqual(stage, "up")

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

    def test_base_validation_projects_synthetic_model_without_external_execution(self):
        lifecycle = self.lifecycle()
        lifecycle.candidate.mkdir()
        self.root = lifecycle.candidate
        self.fixture()
        H.configure(self.root)
        module = H.resolver(self.root)
        selected = {
            "build": {"context": str(self.root / ".devcontainer")},
            "container_name": self.root.name + "-run",
            "image": self.root.name + "-img:0.1",
            "volumes": [{"type": "bind", "source": str(self.root / ".env.d/state"),
                         "target": "/state", "bind": {"create_host_path": False}}],
        }
        base = {"services": {"container-svc": {"env_file": ["../.env"]}}}
        core = {"services": {"container-svc": {"volumes": selected["volumes"]}}}
        lifecycle.resolve = Mock(return_value=(module, "container-svc", selected))
        with patch.object(H, "resolver", return_value=module), \
                patch.object(module, "read_compose_fragment", side_effect=[base, core, base]):
            value = lifecycle.validate_base()
        module.validate_manifest(value)
        self.assertEqual(value["service"], "container-svc")
        self.assertEqual(value["project_name_fingerprint"], module.digest(lifecycle.project))
        self.assertEqual(value["files"], [".devcontainer/docker-compose.yml",
                                         ".devcontainer/config/compose/docker-compose-core-tools.yml"])
        record, = value["volumes"]
        self.assertEqual(record["source"], ".env.d/state")
        self.assertTrue(record["managed"])
        self.assertFalse(record["read_only"])
        self.assertFalse((self.root / module.MANIFEST).exists())
        self.assertFalse((self.root / ".env.d").exists())

    def test_external_env_file_is_rejected_before_compose_resolution(self):
        lifecycle = self.lifecycle()
        module = Mock()
        module.read_compose_fragment.return_value = {"services": {"container-svc": {"env_file": ["/private/auth"]}}}
        lifecycle.resolve = Mock(side_effect=AssertionError("must not resolve external env files"))
        with patch.object(H, "resolver", return_value=module):
            with self.assertRaisesRegex(ValueError, "synthetic ../.env"):
                lifecycle.validate_base()
        lifecycle.resolve.assert_not_called()

    def attachment_fixture(self):
        lifecycle = self.lifecycle()
        for name in (".devcontainer", ".env.d", ".maintainer", ".taskfiles"):
            (lifecycle.candidate / name).mkdir(parents=True, exist_ok=True)
        for name in (".env", ".devcontainer/.env", ".devcontainer/.volume-manifest.json", ".env.d/managed"):
            (lifecycle.candidate / name).write_text("synthetic")
        return lifecycle

    def test_attachment_state_includes_excluded_env_manifest_bytes_and_metadata(self):
        lifecycle = self.attachment_fixture()
        before = lifecycle.fixture_state()
        self.assertEqual(len(before), 5)
        for name in (".env", ".devcontainer/.env", ".devcontainer/.volume-manifest.json", ".env.d/managed"):
            path = lifecycle.candidate / name
            path.write_text("changed")
            self.assertNotEqual(before, lifecycle.fixture_state())
            path.write_text("synthetic")
        (lifecycle.candidate / ".env.d/managed").chmod(0o600)
        self.assertNotEqual(before, lifecycle.fixture_state())

    def test_attachment_state_records_links_without_reading_destination(self):
        lifecycle = self.attachment_fixture()
        (lifecycle.candidate / ".env.d/link").symlink_to("/private/not-readable")
        self.assertEqual(lifecycle.fixture_state()[".env.d/link"][-2:], ("link", "/private/not-readable"))

    def test_real_task_payload_is_bounded_and_requires_warning_and_exact_receipt(self):
        lifecycle = self.attachment_fixture()
        marker = lifecycle.ownership.data["run"] + ":target"
        lifecycle.container = Mock(return_value="target")
        lifecycle.docker = Mock(side_effect=["", marker])
        def produce(argv, cwd, env, stage):
            self.assertEqual(argv, ["timeout", "--kill-after=10", "120", "task", "container:connect"])
            self.assertEqual(cwd, lifecycle.candidate)
            self.assertEqual(env["FORCE_HOST_CONTEXT"], "1")
            self.assertEqual(stage, "verify")
            script = (cwd / ".maintainer/attachment-payload.sh").read_text()
            self.assertIn('test "$(id -un)" = ubuntu', script)
            self.assertIn('test "$PWD" = /home/ubuntu/', script)
            self.assertIn(marker, script)
            (lifecycle.scratch / "task.log").write_text("warn drift\nATTACHMENT_OK:" + marker + "\n")
        lifecycle.ownership.produce.side_effect = produce
        self.assertEqual(lifecycle.connect_payload("target", "warn drift"), "target")
        self.assertFalse((lifecycle.candidate / ".maintainer/attachment-payload.sh").exists())

    def test_missing_warning_or_wrong_target_fails_even_with_successful_task(self):
        lifecycle = self.attachment_fixture()
        lifecycle.docker = Mock(return_value="")
        lifecycle.container = Mock(return_value="wrong")
        marker = lifecycle.ownership.data["run"] + ":target"
        (lifecycle.scratch / "task.log").write_text("ATTACHMENT_OK:" + marker + "\n")
        with self.assertRaisesRegex(H.Unsafe, "warning missing"):
            lifecycle.connect_payload("target", "missing warning")
        with self.assertRaisesRegex(H.Unsafe, "different target"):
            lifecycle.connect_payload("target")

    def test_expected_startup_error_does_not_accept_timeout_or_engine_failure(self):
        lifecycle = self.attachment_fixture()
        lifecycle.docker = Mock()
        lifecycle.ownership.produce.side_effect = H.Unsafe("failed")
        (lifecycle.scratch / "task.log").write_text("duplicate LOCALE\n")
        for status in (None, 0, 124, 137):
            lifecycle.ownership.data["exit"] = status
            with self.assertRaises(H.Unsafe):
                lifecycle.connect_payload(None, expect_failure=True)
        lifecycle.ownership.data["exit"] = 1
        lifecycle.connect_payload(None, expect_failure=True)
        lifecycle.docker.assert_not_called()

    def test_preserving_attachment_rejects_changed_bytes_or_mounts(self):
        lifecycle = self.attachment_fixture()
        lifecycle.attachment_identity = Mock(side_effect=["original", "changed"])
        lifecycle.connect_payload = Mock()
        with self.assertRaisesRegex(H.Unsafe, "mutated"):
            lifecycle.preserving_attachment("target", "warning")

    def test_attachment_fixture_operations_refuse_unregistered_targets(self):
        lifecycle = self.lifecycle()
        lifecycle.ownership.data["resources"] = {"container": {}}
        with self.assertRaisesRegex(H.Unsafe, "not registered"):
            lifecycle.owned_operation("target", "stop")
        lifecycle.ownership.produce.assert_not_called()

    def test_attachment_selector_cannot_expand_to_consumer_dind(self):
        with patch.object(sys, "argv", ["lifecycle", "--consumer", "--attachment"]), patch.object(H, "Run") as run:
            with self.assertRaisesRegex(SystemExit, "not both"):
                H.main()
        run.create.assert_not_called()

    def test_generated_read_requires_supported_scenario_and_rejects_duplicate_selectors(self):
        for flags in (["--allow-generated-dockerfile-read"], ["--consumer", "--allow-generated-dockerfile-read"],
                      ["--attachment", "--allow-generated-dockerfile-read", "--allow-generated-dockerfile-read"]):
            with self.subTest(flags=flags), patch.object(sys, "argv", ["lifecycle", *flags]), patch.object(H, "Run") as run:
                with self.assertRaises(SystemExit):
                    H.main()
                run.create.assert_not_called()

    def test_generated_read_defaults_off(self):
        lifecycle = self.lifecycle()
        self.assertFalse(lifecycle.allow_generated_dockerfile_read)
        self.assertNotIn("HGDR_BINDING", lifecycle.env)
        self.assertNotIn("DOCKER_CONFIG", lifecycle.env)

    def test_generated_read_opt_in_reaches_attachment_lifecycle(self):
        owner = Mock()
        owner.data = {"run": "00000000-0000-4000-8000-000000000001", "scratch": str(self.root / "scratch")}
        owner.path = self.root / "inventory.json"
        with patch.object(sys, "argv", ["lifecycle", "--attachment", "--allow-generated-dockerfile-read"]), \
                patch.object(H, "run", return_value=str(self.root)), patch.object(H, "Run") as run, \
                patch.object(H, "Lifecycle") as lifecycle_class, patch.object(H, "ConsumerLifecycle") as consumer, \
                patch.object(H.shutil, "which", return_value="available"), \
                patch.object(H.Path, "cwd", return_value=self.root), patch.object(H.signal, "signal"), patch("builtins.print"):
            run.create.return_value = owner
            lifecycle = lifecycle_class.return_value
            lifecycle.env = dict(os.environ)
            lifecycle.cleanup.return_value = []
            self.assertEqual(H.main(), 0)
            self.assertTrue(lifecycle.attachment_scenario)
            self.assertTrue(lifecycle.allow_generated_dockerfile_read)
            consumer.assert_not_called()

    def test_scenario_restores_fixture_and_routes_both_startup_states_through_connect(self):
        lifecycle = self.attachment_fixture()
        taskfile = lifecycle.candidate / ".taskfiles/devcontainer.yml"
        taskfile.write_bytes((ROOT / ".taskfiles/devcontainer.yml").read_bytes())
        core = lifecycle.candidate / ".devcontainer/config/compose/docker-compose-core-tools.yml"
        core.parent.mkdir(parents=True)
        core.write_text('{"services":{"container-svc":{"volumes":[]}}}')
        before = taskfile.read_bytes(), core.read_bytes(), (lifecycle.candidate / ".env").read_bytes()
        module = Mock()
        module.read_compose_fragment.return_value = {"services": {"container-svc": {"volumes": []}}}
        lifecycle.preserving_attachment = Mock()
        lifecycle.owned_operation = Mock()
        lifecycle.docker = Mock(side_effect=["original false", ""])
        lifecycle.connect_payload = Mock(side_effect=[None, "original", None, "replacement"])
        lifecycle.missing_token_attachment = Mock()
        with patch.object(H, "resolver", return_value=module), patch("builtins.print"):
            lifecycle.assert_attachment("original")
        self.assertEqual(lifecycle.connect_payload.call_args_list, [
            call(None, expect_failure=True), call("original", prepare_marker=False),
            call(None, expect_failure=True), call(None)])
        self.assertEqual(lifecycle.owned_operation.call_args_list,
                         [call("original", "stop"), call("original", "stop"), call("original", "rm")])
        lifecycle.missing_token_attachment.assert_called_once_with("replacement")
        self.assertEqual(before, (taskfile.read_bytes(), core.read_bytes(), (lifecycle.candidate / ".env").read_bytes()))
        self.assertFalse((lifecycle.candidate / ".maintainer/attachment-workspace").exists())

    def test_missing_token_creation_reuses_image_labels_and_mounts_without_startup(self):
        lifecycle = self.attachment_fixture()
        labels = {H.LABEL: lifecycle.ownership.data["run"], "com.docker.compose.project": lifecycle.project,
                  "com.docker.compose.service": "container-svc", "devcontainer.local_folder": str(lifecycle.candidate),
                  "devcontainer.config_file": str(lifecycle.candidate / ".devcontainer/devcontainer.json")}
        mounts = [{"Type": "bind", "Source": str(lifecycle.candidate),
                   "Destination": "/home/ubuntu/" + lifecycle.candidate.name, "RW": True}]
        lifecycle.docker = Mock(side_effect=[json.dumps(mounts), json.dumps(labels), "sha256:image", "fixture", ""])
        lifecycle.owned_operation = Mock()
        lifecycle.preserving_attachment = Mock()
        lifecycle.missing_token_attachment("original")
        argv = lifecycle.ownership.produce.call_args.args[0]
        self.assertEqual(argv[:2], ["docker", "create"])
        self.assertEqual(argv[-3:], ["sha256:image", "sleep", "infinity"])
        self.assertIn("--mount", argv)
        self.assertIn("none", argv)
        self.assertNotIn("DEVCONTAINER_BIND_MANIFEST_ID", " ".join(argv))
        self.assertEqual(lifecycle.owned_operation.call_args_list,
                         [call("original", "stop"), call("original", "rm"), call("fixture", "start")])
        lifecycle.preserving_attachment.assert_called_once_with("fixture", "Creation bind identity is missing")

    def test_missing_token_external_mount_is_rejected_before_removing_original(self):
        lifecycle = self.attachment_fixture()
        labels = {H.LABEL: lifecycle.ownership.data["run"], "com.docker.compose.project": lifecycle.project,
                  "com.docker.compose.service": "container-svc", "devcontainer.local_folder": "workspace",
                  "devcontainer.config_file": "config"}
        mounts = [{"Type": "bind", "Source": "/private", "Destination": "/workspace", "RW": True}]
        lifecycle.docker = Mock(side_effect=[json.dumps(mounts), json.dumps(labels), "image"])
        lifecycle.owned_operation = Mock()
        with self.assertRaisesRegex(H.Unsafe, "Unsupported"):
            lifecycle.missing_token_attachment("original")
        lifecycle.owned_operation.assert_not_called()
        lifecycle.ownership.produce.assert_not_called()

    def runtime_fixture(self):
        lifecycle = self.lifecycle()
        lifecycle.candidate.mkdir()
        (lifecycle.candidate / ".git").mkdir(mode=0o755)
        (lifecycle.candidate / ".env.d").mkdir(mode=0o755)
        lifecycle.__class__ = H.RuntimeDirectoriesLifecycle
        return lifecycle

    def test_runtime_seed_is_candidate_only_and_preserves_distinct_descendants(self):
        lifecycle = self.runtime_fixture()
        lifecycle.seed_runtime_directories()
        authority = lifecycle.candidate / H.AUTHORITY
        self.assertEqual(authority.stat().st_mode & 0o777, 0o755)
        self.assertEqual((authority / "preserved").stat().st_mode & 0o777, 0o750)
        self.assertEqual((authority / "preserved/sentinel").stat().st_mode & 0o777, 0o640)
        self.assertFalse((lifecycle.candidate / H.SSH_SOURCE / "ssh").exists())
        self.assertFalse((self.root / H.AUTHORITY).exists())
        authority.chmod(0o700)
        (lifecycle.candidate / H.SSH_SOURCE).chmod(0o700)
        lifecycle.assert_preserved_trees()
        (authority / "preserved/sentinel").write_bytes(b"corruption")
        with self.assertRaisesRegex(H.Unsafe, "preserved"):
            lifecycle.assert_preserved_trees()

    def test_runtime_selection_enables_only_canonical_ssh_and_final_port_reset(self):
        self.fixture()
        available = self.root / ".devcontainer/install/available"
        available.mkdir()
        (available / "4010-tool-ssh-server.sh").write_text("synthetic installer")
        original = (self.root / ".devcontainer/docker-compose.yml").read_bytes()
        H.configure(self.root, runtime_directories=True)
        config = json.loads((self.root / ".devcontainer/devcontainer.json").read_text())
        self.assertEqual(config["dockerComposeFile"][-2:], ["./config/compose/docker-compose.ssh-server.yml",
            "./config/compose/starter-runtime-no-ports.yml"])
        self.assertEqual((self.root / ".devcontainer/config/compose/starter-runtime-no-ports.yml").read_text(), H.PORT_RESET)
        link = self.root / ".devcontainer/install/03-enabled/4010-tool-ssh-server.sh"
        self.assertEqual(link.resolve(), available / link.name)
        self.assertFalse((link.parent / "3030-ai-pi-coding.sh").exists())
        self.assertEqual((self.root / ".devcontainer/docker-compose.yml").read_bytes(), original)

    def test_runtime_resolution_rejects_ports_or_wrong_managed_target_before_seed(self):
        lifecycle = self.runtime_fixture()
        module = Mock()
        names = ["docker-compose.yml", "config/compose/docker-compose-core-tools.yml",
                 "config/compose/docker-compose.ssh-server.yml", "config/compose/starter-runtime-no-ports.yml"]
        paths = [lifecycle.candidate / ".devcontainer" / name for name in names]
        paths[-1].parent.mkdir(parents=True)
        paths[-1].write_text(H.PORT_RESET)
        module.selection.return_value = ("container-svc", paths, {})
        module.read_compose_fragment.return_value = {"services": {"container-svc": {
            "ports": ["${SSH_PORT}:22"], "volumes": [{"type": "bind", "source": "../" + H.SSH_SOURCE,
            "target": H.SSH_TARGET, "bind": {"create_host_path": False}}]}}}
        manifest = {"volumes": [{"source": H.SSH_SOURCE, "target": H.SSH_TARGET}]}
        lifecycle.resolve = Mock(return_value=(module, "container-svc", {"ports": [{"published": "22"}]}))
        with patch.object(H, "resolver", return_value=module), patch.object(H.Lifecycle, "validate_base", return_value=manifest):
            with self.assertRaisesRegex(H.Unsafe, "resolved ports"):
                lifecycle.validate_base()
            lifecycle.resolve.return_value = (module, "container-svc", {})
            self.assertEqual(lifecycle.validate_base(), manifest)
            manifest["volumes"][0]["target"] = "/wrong"
            with self.assertRaisesRegex(H.Unsafe, "managed SSH mapping"):
                lifecycle.validate_base()
        self.assertFalse((lifecycle.candidate / H.AUTHORITY).exists())

    def test_runtime_tree_rejects_symlinks_and_unsafe_modes(self):
        lifecycle = self.runtime_fixture()
        lifecycle.seed_runtime_directories()
        authority = lifecycle.candidate / H.AUTHORITY
        (authority / "escape").symlink_to("/unreadable/private")
        with self.assertRaisesRegex(H.Unsafe, "symlink|unsupported"):
            H.tree_state(authority)
        with self.assertRaisesRegex(H.Unsafe, "already exists"):
            lifecycle.seed_runtime_directories()

    def test_runtime_seed_refuses_symlinked_or_writable_parents_without_mutation(self):
        lifecycle = self.runtime_fixture()
        (lifecycle.candidate / ".git").chmod(0o777)
        with self.assertRaisesRegex(H.Unsafe, "parent"):
            lifecycle.seed_runtime_directories()
        self.assertFalse((lifecycle.candidate / H.AUTHORITY).exists())
        (lifecycle.candidate / ".git").chmod(0o755)
        (lifecycle.candidate / ".env.d/.ssh-server").symlink_to("/unreadable/private")
        with self.assertRaisesRegex(H.Unsafe, "already exists"):
            lifecycle.seed_runtime_directories()
        self.assertFalse((lifecycle.candidate / ".git/gentle-ai").exists())

    def test_runtime_selector_rejects_other_scenarios_before_registration(self):
        for flags in (["--consumer"], ["--attachment"], ["--runtime-directories"],
                      ["--allow-generated-dockerfile-read", "--allow-generated-dockerfile-read"],
                      ["--consumer", "--allow-generated-dockerfile-read"],
                      ["--attachment", "--allow-generated-dockerfile-read"]):
            with self.subTest(flags=flags), patch.object(sys, "argv", ["lifecycle", "--runtime-directories", *flags]), \
                    patch.object(H, "Run") as owner:
                with self.assertRaises(SystemExit):
                    H.main()
                owner.create.assert_not_called()

    def test_runtime_execution_seeds_before_build_and_asserts_after_both_creations(self):
        lifecycle = self.runtime_fixture()
        events = Mock()
        lifecycle.validate_base = Mock()
        lifecycle.label_candidate = Mock()
        lifecycle.prepare_runtime_directories = events.prepare
        lifecycle.assert_runtime_seed = events.seed
        lifecycle.assert_runtime_directories = events.runtime
        lifecycle.task = events.task
        lifecycle.assert_state = events.state
        lifecycle.assert_locale = events.locale
        lifecycle.container = Mock(side_effect=["first", "second"])
        source = {"head": "commit", "branch": "main", "index": "", "files": {}}
        with patch.object(H, "configure"), patch.object(H, "snapshot", return_value=source), \
                patch.object(H, "run", return_value="12000"):
            lifecycle.execute()
        self.assertEqual(events.mock_calls, [call.prepare(), call.task("build"), call.seed(), call.task("up"),
            call.runtime("first", first=True), call.state("first", write=True), call.locale("first"),
            call.task("recreate"), call.runtime("second"), call.state("second"), call.locale("second")])

    def test_runtime_assertions_reject_public_ports_and_wrong_workspace_before_reading_keys(self):
        lifecycle = self.runtime_fixture()
        lifecycle.assert_preserved_trees = Mock()
        lifecycle.docker = Mock(return_value='{"22/tcp":[{"HostPort":"22"}]}')
        with self.assertRaisesRegex(H.Unsafe, "ports"):
            lifecycle.assert_runtime_directories("first", first=True)
        self.assertEqual(lifecycle.docker.call_count, 1)
        lifecycle.docker = Mock(side_effect=["{}", "[]"])
        with self.assertRaisesRegex(H.Unsafe, "workspace"):
            lifecycle.assert_runtime_directories("first", first=True)
        self.assertEqual(lifecycle.docker.call_count, 2)

    def test_runtime_generated_read_prepares_pinned_scenario_before_build(self):
        lifecycle = self.runtime_fixture()
        lifecycle.allow_generated_dockerfile_read = True
        events = Mock()
        lifecycle.validate_base = Mock()
        lifecycle.label_candidate = Mock()
        lifecycle.prepare_runtime_directories = events.runtime_prepare
        lifecycle.assert_runtime_seed = Mock()
        lifecycle.assert_runtime_directories = Mock()
        lifecycle.task = events.task
        lifecycle.assert_state = Mock()
        lifecycle.assert_locale = Mock()
        lifecycle.container = Mock(side_effect=["first", "second"])
        adapter = Mock()
        adapter.prepare = events.adapter_prepare
        source = {"head": "commit", "branch": "main", "index": "", "files": {}}
        with patch.object(H, "configure"), patch.object(H, "snapshot", return_value=source), \
                patch.object(H, "run", return_value="12000"), \
                patch.object(H.importlib.util, "spec_from_file_location"), \
                patch.object(H.importlib.util, "module_from_spec", return_value=adapter):
            lifecycle.execute()
        self.assertEqual(events.mock_calls, [call.runtime_prepare(),
            call.adapter_prepare(lifecycle, runtime_directories=True), call.task("build"),
            call.task("up"), call.task("recreate")])
        self.assertIs(lifecycle._generated_read_adapter, adapter)

    def test_runtime_preparation_failure_prevents_build(self):
        lifecycle = self.runtime_fixture()
        lifecycle.validate_base = Mock()
        lifecycle.label_candidate = Mock()
        lifecycle.prepare_runtime_directories = Mock(side_effect=H.Unsafe("unsafe seed"))
        lifecycle.task = Mock()
        with patch.object(H, "configure"), patch.object(H, "run", return_value="12000"):
            with self.assertRaisesRegex(H.Unsafe, "unsafe seed"):
                lifecycle.execute()
        lifecycle.task.assert_not_called()

    def test_runtime_postcreate_failure_prevents_recreate(self):
        lifecycle = self.runtime_fixture()
        lifecycle.validate_base = Mock()
        lifecycle.label_candidate = Mock()
        lifecycle.prepare_runtime_directories = Mock()
        lifecycle.assert_runtime_seed = Mock()
        lifecycle.assert_runtime_directories = Mock(side_effect=H.Unsafe("postCreate contract failed"))
        lifecycle.container = Mock(return_value="first")
        lifecycle.task = Mock()
        source = {"head": "commit", "branch": "main", "index": "", "files": {}}
        with patch.object(H, "configure"), patch.object(H, "snapshot", return_value=source), \
                patch.object(H, "run", return_value="12000"):
            with self.assertRaisesRegex(H.Unsafe, "postCreate"):
                lifecycle.execute()
        self.assertEqual(lifecycle.task.call_args_list, [call("build"), call("up")])
        self.assertIn("runtime-directories", H.failure_message(lifecycle))

    def test_runtime_selector_constructs_only_the_opt_in_lifecycle(self):
        owner = Mock()
        owner.data = {"run": "00000000-0000-4000-8000-000000000001", "scratch": str(self.root / "scratch")}
        owner.path = self.root / "inventory.json"
        with patch.object(sys, "argv", ["lifecycle", "--runtime-directories"]), \
                patch.object(H, "run", return_value=str(self.root)), patch.object(H, "Run") as run, \
                patch.object(H, "RuntimeDirectoriesLifecycle") as runtime, patch.object(H, "Lifecycle") as base, \
                patch.object(H, "ConsumerLifecycle") as consumer, patch.object(H.shutil, "which", return_value="available"), \
                patch.object(H.Path, "cwd", return_value=self.root), patch.object(H.signal, "signal"), patch("builtins.print"):
            run.create.return_value = owner
            runtime.return_value.env = dict(os.environ)
            runtime.return_value.cleanup.return_value = []
            self.assertEqual(H.main(), 0)
            runtime.assert_called_once_with(self.root, self.root / "scratch", owner)
            base.assert_not_called()
            consumer.assert_not_called()

    def test_runtime_generated_read_selector_constructs_only_runtime_lifecycle(self):
        owner = Mock()
        owner.data = {"run": "00000000-0000-4000-8000-000000000001", "scratch": str(self.root / "scratch")}
        owner.path = self.root / "inventory.json"
        with patch.object(sys, "argv", ["lifecycle", "--runtime-directories", "--allow-generated-dockerfile-read"]), \
                patch.object(H, "run", return_value=str(self.root)), patch.object(H, "Run") as run, \
                patch.object(H, "RuntimeDirectoriesLifecycle") as runtime, patch.object(H, "Lifecycle") as base, \
                patch.object(H, "ConsumerLifecycle") as consumer, patch.object(H.shutil, "which", return_value="available"), \
                patch.object(H.Path, "cwd", return_value=self.root), patch.object(H.signal, "signal"), patch("builtins.print"):
            run.create.return_value = owner
            runtime.return_value.env = dict(os.environ)
            runtime.return_value.cleanup.return_value = []
            self.assertEqual(H.main(), 0)
            self.assertTrue(runtime.return_value.allow_generated_dockerfile_read)
            runtime.assert_called_once_with(self.root, self.root / "scratch", owner)
            base.assert_not_called()
            consumer.assert_not_called()

    def test_runtime_full_assertion_preserves_generated_keys_without_disclosing_bytes(self):
        lifecycle = self.runtime_fixture()
        lifecycle.seed_runtime_directories()
        (lifecycle.candidate / H.AUTHORITY).chmod(0o700)
        ssh = lifecycle.candidate / H.SSH_SOURCE
        ssh.chmod(0o700)
        child = ssh / "ssh"
        child.mkdir(mode=0o700)
        for kind in ("rsa", "ed25519"):
            for suffix in ("", ".pub"):
                path = child / ("ssh_host_" + kind + "_key" + suffix)
                path.write_bytes(b"synthetic generated key stand-in, never a real credential")
                path.chmod(0o644 if suffix else 0o600)
        workspace = "/home/ubuntu/" + lifecycle.candidate.name
        mounts = [{"Type": "bind", "Source": str(lifecycle.candidate), "Destination": workspace, "RW": True},
                  {"Type": "bind", "Source": str(ssh), "Destination": H.SSH_TARGET, "RW": True}]
        parents = [f"{uid}:{gid}:{mode:o}" for uid, gid, mode in lifecycle.runtime_parents.values()]
        lifecycle.docker = Mock(side_effect=["{}", json.dumps(mounts), "applied", *parents] * 3)
        lifecycle.container_tree = Mock(side_effect=lambda _, target: H.tree_state(
            ssh if target == H.SSH_TARGET else lifecycle.candidate / H.AUTHORITY))
        module = Mock()
        module.load_manifest.return_value = {"id": "applied", "volumes": [{"source": H.SSH_SOURCE,
            "target": H.SSH_TARGET, "managed": True, "read_only": False}]}
        with patch.object(H, "resolver", return_value=module):
            lifecycle.assert_runtime_directories("first", first=True)
            lifecycle.assert_runtime_directories("replacement")
            (child / "ssh_host_rsa_key").write_bytes(b"corrupted key")
            with self.assertRaisesRegex(H.Unsafe, "host keys changed"):
                lifecycle.assert_runtime_directories("replacement")

    def test_runtime_initial_state_is_rechecked_before_up(self):
        lifecycle = self.runtime_fixture()
        lifecycle.seed_runtime_directories()
        lifecycle.assert_runtime_seed()
        (lifecycle.candidate / H.SSH_SOURCE / "ssh").mkdir(mode=0o700)
        with self.assertRaisesRegex(H.Unsafe, "before up"):
            lifecycle.assert_runtime_seed()

    def test_runtime_public_snapshot_excludes_authority_without_opening_it(self):
        (self.root / ".git").mkdir()
        (self.root / ".git/gentle-ai").symlink_to("/unreadable/private")
        with patch.object(H, "run", return_value=H.AUTHORITY + "/receipt\0"):
            self.assertEqual(H.snapshot(self.root)["files"], {})

    def opt_in(self, lifecycle):
        lifecycle.allow_generated_dockerfile_read = True
        lifecycle._generated_read_adapter = Mock()
        return lifecycle._generated_read_adapter

    def test_opted_in_task_requires_prepared_adapter_before_producer(self):
        lifecycle = self.lifecycle()
        lifecycle.allow_generated_dockerfile_read = True
        for action in ("build", "up", "recreate", "connect"):
            with self.subTest(action=action), self.assertRaisesRegex(H.Unsafe, "not been prepared"):
                lifecycle.task(action)
        lifecycle.ownership.produce.assert_not_called()

    def test_private_selection_failures_block_all_task_and_connect_routes(self):
        lifecycle = self.attachment_fixture()
        adapter = self.opt_in(lifecycle)
        lifecycle.docker = Mock()
        for failure in ("missing config", "tampered config", "missing launcher", "tampered launcher",
                        "missing native", "tampered native", "tampered dependency"):
            adapter.validate_selection.side_effect = H.Unsafe(failure)
            for action in ("build", "up", "recreate", "connect"):
                with self.subTest(failure=failure, action=action), self.assertRaises(H.Unsafe):
                    lifecycle.task(action)
            for container, prepare_marker in (("running", True), ("stopped", False), (None, True)):
                with self.subTest(failure=failure, container=container), self.assertRaises(H.Unsafe):
                    lifecycle.connect_payload(container, prepare_marker=prepare_marker, expect_failure=True)
        lifecycle.ownership.produce.assert_not_called()
        lifecycle.docker.assert_not_called()
        lifecycle.ownership.stage.assert_not_called()
        self.assertFalse((lifecycle.candidate / ".maintainer/attachment-payload.sh").exists())

    def test_valid_task_checks_selection_before_launch_and_preserves_arguments(self):
        lifecycle = self.lifecycle()
        adapter = self.opt_in(lifecycle)
        events = Mock()
        events.attach_mock(adapter.validate_selection, "validate")
        events.attach_mock(lifecycle.ownership.produce, "produce")
        lifecycle.task("build")
        self.assertEqual(events.mock_calls, [call.validate(lifecycle.env), call.produce(
            ["task", "container:build"], lifecycle.candidate,
            {**lifecycle.env, "FORCE_HOST_CONTEXT": "1"}, "build")])

    def test_default_and_consumer_do_not_load_or_validate_private_adapter(self):
        lifecycle = self.lifecycle()
        adapter = Mock()
        lifecycle._generated_read_adapter = adapter
        lifecycle.task("up")
        (self.root / "consumer").mkdir()
        with patch.object(H, "snapshot", return_value={}), patch.object(H, "run", return_value=""):
            consumer = H.ConsumerLifecycle(self.root, self.root / "consumer", Mock(data={"run": "consumer"}))
        consumer._generated_read_adapter = adapter
        consumer.task("build")
        adapter.validate_selection.assert_not_called()
        lifecycle.ownership.produce.assert_called_once()
        consumer.ownership.produce.assert_called_once()

    def test_valid_connect_routes_recheck_selection_without_current_core_validation(self):
        lifecycle = self.attachment_fixture()
        adapter = self.opt_in(lifecycle)
        core = lifecycle.candidate / ".devcontainer/config/compose/docker-compose-core-tools.yml"
        core.parent.mkdir(parents=True)
        core.write_text("temporary desired drift")
        for container, prepare_marker in (("running", True), ("stopped", False), (None, True)):
            adapter.validate_selection.reset_mock()
            target = container or "replacement"
            marker = lifecycle.ownership.data["run"] + ":" + (container or "startup")
            lifecycle.container = Mock(return_value=target)
            lifecycle.docker = Mock(side_effect=["", marker] if container and prepare_marker else [marker])
            def produce(argv, cwd, environment, stage):
                self.assertEqual(argv[0:2], ["timeout", "--kill-after=10"])
                self.assertEqual(argv[2], "120" if container and prepare_marker else "600")
                self.assertEqual(argv[3:], ["task", "container:connect"])
                self.assertEqual(environment, {**lifecycle.env, "FORCE_HOST_CONTEXT": "1"})
                self.assertEqual(stage, "verify")
                (lifecycle.scratch / "task.log").write_text("Desired bind contract differs\nATTACHMENT_OK:" + marker + "\n")
            lifecycle.ownership.produce.side_effect = produce
            with self.subTest(container=container):
                self.assertEqual(lifecycle.connect_payload(container, "Desired bind contract differs",
                                                          prepare_marker=prepare_marker), target)
                self.assertEqual(adapter.validate_selection.call_args_list, [call(lifecycle.env), call(lifecycle.env)])
                self.assertEqual(core.read_text(), "temporary desired drift")

    def test_connect_selection_race_cannot_be_accepted_as_expected_startup_error(self):
        lifecycle = self.attachment_fixture()
        adapter = self.opt_in(lifecycle)
        adapter.validate_selection.side_effect = [None, H.Unsafe("selection replaced")]
        lifecycle.ownership.data["exit"] = 1
        with self.assertRaisesRegex(H.Unsafe, "selection replaced"):
            lifecycle.connect_payload(None, expect_failure=True)
        lifecycle.ownership.produce.assert_not_called()
        self.assertFalse((lifecycle.candidate / ".maintainer/attachment-payload.sh").exists())

    def test_attachment_docker_producers_are_guarded_before_inspection(self):
        lifecycle = self.attachment_fixture()
        adapter = self.opt_in(lifecycle)
        adapter.validate_selection.side_effect = H.Unsafe("selection unavailable")
        lifecycle.docker = Mock()
        for operation in (lambda: lifecycle.owned_operation("target", "stop"),
                          lambda: lifecycle.missing_token_attachment("target")):
            with self.assertRaises(H.Unsafe):
                operation()
        lifecycle.docker.assert_not_called()
        lifecycle.ownership.capture.assert_not_called()
        lifecycle.ownership.produce.assert_not_called()

    def test_execute_reuses_adapter_only_after_successful_preparation(self):
        lifecycle = self.lifecycle()
        lifecycle.allow_generated_dockerfile_read = True
        lifecycle.validate_base = Mock()
        lifecycle.label_candidate = Mock()
        lifecycle.container = Mock(side_effect=["first", "second"])
        lifecycle.assert_state = Mock()
        lifecycle.assert_locale = Mock()
        snapshot = {"head": "commit", "branch": "main", "index": "", "files": {}}
        adapter = Mock()
        adapter.prepare.side_effect = lambda instance: self.assertFalse(hasattr(instance, "_generated_read_adapter"))
        with patch.object(H, "configure"), patch.object(H, "snapshot", return_value=snapshot), \
                patch.object(H, "run", return_value="12000"), \
                patch.object(H.importlib.util, "spec_from_file_location", return_value=Mock()), \
                patch.object(H.importlib.util, "module_from_spec", return_value=adapter):
            lifecycle.execute()
        self.assertIs(lifecycle._generated_read_adapter, adapter)
        adapter.prepare.assert_called_once_with(lifecycle)
        self.assertEqual(adapter.validate_selection.call_args_list, [call(lifecycle.env)] * 3)


class PreflightTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(dir="/tmp/opencode")
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.root = self.base / "source"
        self.root.mkdir()
        (self.root / ".git").mkdir(mode=0o755)
        self.parent = self.base / "scratch-parent"
        self.parent.mkdir()
        self.store = self.root / ".git/starter-test-runs"
        self.compose_version = "5.5.1"
        self.cli_version = "0.89.0"
        self.image = "sha256:" + "a" * 64
        self.daemon = "synthetic-daemon"
        self.query = Mock(side_effect=self.metadata)
        self.scope = patch.object(H, "scope_preflight", return_value={"04-hooks": 1})
        replacements = [(H, "metadata_query", self.query), (H.Path, "cwd", Mock(return_value=self.root)),
                        (H.shutil, "which", Mock(return_value="available")),
                        (H, "local_endpoint", Mock(return_value=True)),
                        (H.subprocess, "run", Mock(side_effect=AssertionError("unmocked process"))),
                        (H.subprocess, "check_output", Mock(side_effect=AssertionError("unmocked process"))),
                        (H.subprocess, "Popen", Mock(side_effect=AssertionError("unmocked process")))]
        for target, name, value in replacements:
            replacement = patch.object(target, name, value)
            replacement.start()
            self.addCleanup(replacement.stop)
        self.scope.start()
        self.addCleanup(self.scope.stop)

    def metadata(self, *args, **kwargs):
        if args[0] == "git":
            return str(self.root / ".git") if "--git-common-dir" in args else str(self.root)
        if args[0] == "devcontainer":
            return self.cli_version
        if args[:3] != ("docker", "--host", H.ENDPOINT):
            raise AssertionError("unselected endpoint or unexpected command")
        if "info" in args:
            return self.daemon
        if "image" in args:
            self.assertEqual(args[-1], "ubuntu:24.04")
            return self.image
        if "compose" in args:
            return self.compose_version
        if "buildx" in args:
            return "github.com/docker/buildx v0.38.0 synthetic"
        raise AssertionError("mutating or unexpected Docker command")

    def options(self, *flags):
        return H.parse_options([*flags, "--daemon-visible-scratch", str(self.parent)])

    def report(self, *flags):
        return H.preflight(self.options(*flags))

    def assert_main_refuses(self, stage):
        for explicit in (False, True):
            with self.subTest(explicit=explicit), patch.object(sys, "argv", ["lifecycle", *(
                    ["--preflight"] if explicit else []), "--daemon-visible-scratch", str(self.parent)]), \
                    patch.object(H, "Run") as owner, patch.object(H, "Lifecycle") as lifecycle, \
                    patch.object(H, "configure") as configure, patch("builtins.print") as output:
                self.assertEqual(H.main(), 1)
                report = json.loads(output.call_args.args[0])
                self.assertEqual(report["stage"], stage)
                self.assertEqual(report["readiness"], "not-ready")
                self.assertIsNone(report["run"])
                owner.create.assert_not_called()
                lifecycle.assert_not_called()
                configure.assert_not_called()
                self.assertLess(len(json.dumps(report)), 4096)

    def test_explicit_preflight_is_inert_and_reports_no_run(self):
        report = {"schema": 1, "scenario": "base", "readiness": "ready", "checks": [],
                  "stage": "complete", "reason": "metadata-ready", "next_step": "run-authorized-proof", "run": None}
        with patch.object(sys, "argv", ["lifecycle", "--preflight"]), \
                patch.object(H, "preflight", return_value=report), \
                patch.object(H, "Run") as owner, patch.object(H, "Lifecycle") as lifecycle, \
                patch("builtins.print") as output:
            self.assertEqual(H.main(), 0)
        owner.create.assert_not_called()
        lifecycle.assert_not_called()
        self.assertEqual(json.loads(output.call_args.args[0]), report)

    def test_all_supported_selector_combinations_share_parser_and_preflight(self):
        selectors = ["--consumer", "--attachment", "--runtime-directories", "--allow-generated-dockerfile-read"]
        for bits in itertools.product((False, True), repeat=4):
            flags = [flag for flag, selected in zip(selectors, bits) if selected]
            consumer, attachment, runtime, generated = bits
            valid = sum((consumer, attachment, runtime)) <= 1 and (not generated or not consumer and (attachment or runtime))
            for explicit in (False, True):
                args = [*flags, *(["--preflight"] if explicit else [])]
                with self.subTest(args=args):
                    if valid:
                        options = self.options(*args)
                        self.assertEqual(options["generated_read"], generated)
                        self.assertEqual(options["preflight"], explicit)
                        self.assertEqual(options["scenario"], "consumer" if consumer else "attachment" if attachment
                                         else "runtime-directories" if runtime else "base")
                    else:
                        with self.assertRaises(SystemExit):
                            self.options(*args)

    def test_malformed_options_return_sanitized_json_without_any_query(self):
        cases = [[flag, flag] for flag in ("--preflight", "--consumer", "--attachment", "--runtime-directories",
                                          "--allow-generated-dockerfile-read")]
        cases += [["--daemon-visible-scratch"], ["--daemon-visible-scratch", "/a", "--daemon-visible-scratch", "/b"],
                  ["--unknown=private-secret"], ["private-secret"], ["--consumer", "--attachment"],
                  ["--allow-generated-dockerfile-read"]]
        for flags in cases:
            with self.subTest(flags=flags), patch.object(sys, "argv", ["lifecycle", "--preflight", *flags]), \
                    patch.object(H, "Run") as owner, patch("builtins.print") as output:
                self.assertEqual(H.main(), 1)
                self.assertEqual(json.loads(output.call_args.args[0]), H.preflight_report())
                self.assertNotIn("private-secret", output.call_args.args[0])
                owner.create.assert_not_called()
        self.query.assert_not_called()

    def test_ready_report_plans_missing_registry_without_creating_any_state(self):
        before = dict(os.environ), sorted(str(path) for path in self.base.rglob("*"))
        report = self.report()
        self.assertEqual(report["readiness"], "ready")
        self.assertIn({"stage": "registry", "reason": "registry-planned-0755"}, report["checks"])
        self.assertEqual(report["checks"][4]["selected_scripts"], {"04-hooks": 1})
        self.assertEqual(before, (dict(os.environ), sorted(str(path) for path in self.base.rglob("*"))))
        self.assertFalse(self.store.exists())
        self.assertEqual(report["reason"], "metadata-ready")

    def test_existing_safe_legacy_registry_modes_are_preserved(self):
        self.store.mkdir()
        for mode in (0o700, 0o750, 0o755):
            self.store.chmod(mode)
            self.assertEqual(self.report()["readiness"], "ready")
            self.assertEqual(self.store.stat().st_mode & 0o777, mode)
            self.assertEqual(list(self.store.iterdir()), [])

    def test_unsafe_registry_and_missing_registry_parent_refuse_without_repair(self):
        self.store.mkdir(mode=0o777)
        self.store.chmod(0o777)
        self.assert_main_refuses("registry")
        self.assertEqual(self.store.stat().st_mode & 0o777, 0o777)
        with patch.object(H, "registry_directory", side_effect=H.Unsafe("private-secret")):
            self.assert_main_refuses("registry")
        self.assertEqual(list(self.store.iterdir()), [])

    def test_symlinked_registry_or_scratch_is_rejected(self):
        self.store.symlink_to(self.parent, target_is_directory=True)
        self.assert_main_refuses("registry")
        other = self.base / "scratch-link"
        other.symlink_to(self.parent, target_is_directory=True)
        report = H.preflight(H.parse_options(["--daemon-visible-scratch", str(other)]))
        self.assertEqual(report["stage"], "scratch")
        self.assertEqual(list(self.parent.iterdir()), [])

    def test_missing_registry_creation_is_only_planned_under_a_safe_parent(self):
        common = self.root / ".git"
        common.chmod(0o777)
        self.assert_main_refuses("registry")
        self.assertFalse(self.store.exists())
        self.assertEqual(common.stat().st_mode & 0o777, 0o777)
        common.chmod(0o755)
        with patch.object(H.os, "getuid", return_value=os.getuid() + 1):
            self.assert_main_refuses("registry")
        self.assertFalse(self.store.exists())

    def test_tools_source_scratch_scope_endpoint_fail_before_registration(self):
        cases = [(H.shutil, "which", None, "tools"), (H.os, "access", False, "scratch"),
                 (H, "local_endpoint", False, "endpoint")]
        for target, name, value, stage in cases:
            with self.subTest(stage=stage), patch.object(target, name, return_value=value):
                self.assert_main_refuses(stage)
        with patch.object(H, "metadata_query", return_value="/different-source"):
            self.assert_main_refuses("source")
        with patch.object(H, "scope_preflight", side_effect=ValueError("private-secret")):
            self.assert_main_refuses("scope")

    def test_scratch_requires_absolute_existing_plain_external_parent(self):
        for parent in (Path("relative"), self.base / "missing", self.root, self.root / ".git"):
            with self.subTest(parent=parent):
                options = self.options()
                options["parent"] = parent
                self.assertEqual(H.preflight(options)["stage"], "scratch")

    def test_failed_or_invalid_daemon_and_cache_metadata_block_registration(self):
        for attribute, values, stage in (("daemon", ("", "a" * 129), "daemon"),
                                         ("image", ("", "private-secret", "sha256:" + "g" * 64), "image")):
            original = getattr(self, attribute)
            for value in values:
                with self.subTest(stage=stage, value=value):
                    setattr(self, attribute, value)
                    self.assert_main_refuses(stage)
            setattr(self, attribute, original)
        for selected, stage in (("info", "daemon"), ("image", "image"), ("compose", "toolchain")):
            def query(*args, **kwargs):
                if selected in args:
                    raise subprocess.TimeoutExpired(args, 10, output="private-secret")
                return self.metadata(*args, **kwargs)
            with patch.object(H, "metadata_query", side_effect=query):
                self.assert_main_refuses(stage)

    def test_toolchain_versions_are_exact_not_ranges_or_error_text_admission(self):
        for version in ("5.5.1", "5.6.0"):
            self.compose_version = version
            self.assertEqual(self.report()["readiness"], "ready")
        for version in ("5.6.1", "v5.6.0", "5.5.2", "5.6", "*", ">=5.5.1", "private-secret 5.5.1"):
            self.compose_version = version
            self.assert_main_refuses("toolchain")
        self.compose_version = "5.5.1"
        for version in ("0.89.1", "v0.89.0", "0.89.0 private-secret", "0.90.0"):
            self.cli_version = version
            self.assert_main_refuses("toolchain")

    def test_consent_checks_fixed_native_capability_without_preparing_adapter(self):
        adapter = Mock(COMPOSE_VERSIONS=("5.5.1", "5.6.0"), CLI_VERSION="0.89.0")
        adapter.NativeSnapshot = MagicMock()
        adapter.find_native.side_effect = [Path("/system/docker-compose"), Path("/system/docker-buildx")]
        def query(*args, **kwargs):
            if args[0] == "/system/docker-compose":
                return "5.6.0"
            if args[0] == "/system/docker-buildx":
                return "synthetic Buildx version"
            return self.metadata(*args, **kwargs)
        with patch.object(H.importlib.util, "spec_from_file_location", return_value=Mock()), \
                patch.object(H.importlib.util, "module_from_spec", return_value=adapter), \
                patch.object(H, "metadata_query", side_effect=query):
            self.assertEqual(self.report("--attachment", "--allow-generated-dockerfile-read")["readiness"], "ready")
            self.assertEqual(adapter.find_native.call_args_list, [call("docker-compose"), call("docker-buildx")])
            adapter.prepare.assert_not_called()
            adapter.validate_selection.assert_not_called()
            self.assertEqual(adapter.NativeSnapshot.call_args_list,
                             [call(Path("/system/docker-compose")), call(Path("/system/docker-buildx"))])
            self.assertEqual(adapter.NativeSnapshot.return_value.__enter__.return_value.recheck.call_count, 2)
            adapter.find_native.side_effect = H.Unsafe("private-secret")
            self.assertEqual(self.report("--runtime-directories", "--allow-generated-dockerfile-read")["stage"], "toolchain")

    def test_metadata_queries_are_bounded_and_do_not_inherit_context_or_secrets(self):
        with patch.dict(os.environ, {"DOCKER_HOST": "ssh://private-secret", "DOCKER_CONTEXT": "private-secret",
                                     "DOCKER_CONFIG": "/private-secret", "TOKEN": "private-secret", "BASH_ENV": "/private-secret"}):
            environment = H.preflight_environment()
            self.assertEqual(environment["DOCKER_HOST"], H.ENDPOINT)
            self.assertEqual(environment["DOCKER_CONFIG"], H.PREFLIGHT_HOME)
            self.assertNotIn("private-secret", json.dumps(environment))
            self.assertNotIn("DOCKER_CONTEXT", environment)
        self.assertEqual(H.PREFLIGHT_TIMEOUT, 10)
        self.assertLessEqual(H.PREFLIGHT_LIMIT, 262144)
        result = Mock(returncode=0, stdout="synthetic\n")
        with patch.object(H.subprocess, "run", return_value=result) as process:
            self.assertEqual(METADATA_QUERY("docker", "--host", H.ENDPOINT, "info"), "synthetic")
            kwargs = process.call_args.kwargs
            self.assertEqual(kwargs["timeout"], 10)
            self.assertEqual(kwargs["env"], H.preflight_environment())
            self.assertEqual(kwargs["stderr"], subprocess.PIPE)
            for result in (Mock(returncode=1, stdout="private-secret"),
                           Mock(returncode=0, stdout="s" * (H.PREFLIGHT_LIMIT + 1))):
                process.return_value = result
                with self.assertRaisesRegex(H.Unsafe, "metadata query refused"):
                    METADATA_QUERY("docker", "--host", H.ENDPOINT, "info")

    def test_normal_execution_waits_for_every_preflight_check_before_registering(self):
        with patch.object(sys, "argv", ["lifecycle", "--daemon-visible-scratch", str(self.parent)]), \
                patch.object(H.Run, "create", side_effect=AssertionError("registration boundary")) as create, \
                patch.object(sys, "stdout", io.StringIO()), patch.object(sys, "stderr", io.StringIO()) as output:
            self.assertEqual(H.main(), 1)
            self.assertIn("run=none stage=registration reason=unknown", output.getvalue())
            self.assertNotIn("registration boundary", output.getvalue())
        create.assert_called_once_with(self.root, self.parent)
        self.assertEqual(self.query.call_args.args, ("docker", "--host", H.ENDPOINT, "buildx", "version"))
        self.assertFalse(self.store.exists())

    def scope_fixture(self):
        self.scope.stop()
        names = [".devcontainer/devcontainer.json", ".devcontainer/Dockerfile",
                 ".taskfiles/scripts/yq-compatibility.sh", ".taskfiles/scripts/compose-manifest.py",
                 ".devcontainer/docker-compose.yml", ".devcontainer/config/compose/docker-compose-core-tools.yml",
                 ".devcontainer/config/compose/docker-compose.ssh-server.yml",
                 ".devcontainer/config/compose/docker-compose.pi.yml", ".devcontainer/config/compose/docker-compose.gentle-shell.yml"]
        for name in names:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        for group in ("01-foundation", "02-core-tools", "03-enabled", "04-hooks", "available"):
            (self.root / ".devcontainer/install" / group).mkdir(parents=True)
        available = self.root / ".devcontainer/install/available"
        for name in ("4010-tool-ssh-server.sh", "3030-ai-pi-coding.sh", "3020-ai-gentle-ai.sh"):
            (available / name).write_text("synthetic public script, never executed")
            (available.parent / "03-enabled" / name).symlink_to("../available/" + name)
        (available.parent / "04-hooks/10-project.sh").write_text("synthetic hook, never executed")
        (self.root / ".maintainer").mkdir()
        (self.root / ".maintainer/starter-tools.json").write_text('["3030-ai-pi-coding.sh"]')
        self.fragments = [
            {"services": {"container-svc": {"image": "${APP_NAME}-img:0.1", "container_name": "${APP_NAME}-run",
                                          "build": {"context": ".", "dockerfile": "./Dockerfile"}, "env_file": ["../.env"]}}},
            {"services": {"container-svc": {"volumes": [{"type": "bind", "source": "../.env.d/state", "target": "/state",
                                                        "bind": {"create_host_path": False}}]}}},
            {"services": {"container-svc": {"ports": ["${SSH_PORT}:22"], "volumes": [
                {"type": "bind", "source": "../" + H.SSH_SOURCE, "target": H.SSH_TARGET,
                 "bind": {"create_host_path": False}}]}}},
        ]

    def scope_report(self, *flags):
        fragments = iter(self.fragments[:2] + ([
            {"services": {"container-svc": {"volumes": [{"type": "bind", "source": "../.env.d/.pi", "target": "/pi",
                                                        "bind": {"create_host_path": False}}]}}},
            {"services": {"container-svc": {"volumes": [{"type": "bind", "source": "../.env.d/.gentle-shell", "target": "/gentle-shell",
                                                        "bind": {"create_host_path": False}}]}}},
        ] if "--consumer" in flags else self.fragments[2:]))
        def query(*args, **kwargs):
            if args[0] == "bash":
                self.assertNotIn("private-secret", kwargs["payload"])
                return json.dumps(next(fragments))
            return self.metadata(*args, **kwargs)
        with patch.object(H, "metadata_query", side_effect=query):
            return self.report(*flags)

    def test_selected_build_and_hook_scope_is_read_only_for_each_scenario(self):
        self.scope_fixture()
        before = [(str(path), path.lstat().st_mode, os.readlink(path) if path.is_symlink()
                   else path.read_bytes() if path.is_file() else None) for path in self.base.rglob("*")]
        for flags, enabled in (([], 1), (["--attachment"], 1), (["--runtime-directories"], 2), (["--consumer"], 1)):
            with self.subTest(flags=flags):
                report = self.scope_report(*flags)
                self.assertEqual(report["readiness"], "ready", report)
                scope = next(check for check in report["checks"] if check["stage"] == "scope")
                self.assertEqual(scope["selected_scripts"]["03-enabled"], enabled)
                self.assertEqual(scope["selected_scripts"]["04-hooks"], 1)
        after = [(str(path), path.lstat().st_mode, os.readlink(path) if path.is_symlink()
                  else path.read_bytes() if path.is_file() else None) for path in self.base.rglob("*")]
        self.assertEqual(before, after)

    def test_unsupported_build_bind_and_file_backed_inputs_fail_before_daemon_query(self):
        self.scope_fixture()
        original = copy.deepcopy(self.fragments)
        changes = [(0, "env_file", ["/private-secret"]), (0, "secrets", ["private-secret"]),
                   (0, "build", {"context": "/external", "dockerfile": "Dockerfile"}),
                   (0, "build", {"context": ".", "dockerfile": "../elsewhere"}),
                   (0, "build", {"context": ".", "ssh": ["default"]}),
                   (1, "volumes", [{"type": "volume", "source": "external", "target": "/state"}]),
                   (1, "volumes", [{"type": "bind", "source": "../.env.d/../external", "target": "/state",
                                    "bind": {"create_host_path": False}}]),
                   (1, "volumes", [{"type": "bind", "source": "../.env.d/state", "target": "relative",
                                    "bind": {"create_host_path": False}}]), (1, "volumes", [])]
        for index, key, value in changes:
            with self.subTest(key=key, value=value):
                self.fragments = copy.deepcopy(original)
                self.fragments[index]["services"]["container-svc"][key] = value
                report = self.scope_report()
                self.assertEqual(report["stage"], "scope", report)
                self.assertEqual(report["readiness"], "not-ready", report)
                self.assertNotIn("private-secret", json.dumps(report))
        self.fragments = original

    def test_escaping_hooks_and_noncanonical_public_files_fail_closed(self):
        self.scope_fixture()
        hooks = self.root / ".devcontainer/install/04-hooks"
        (hooks / "escape.sh").symlink_to("/private-secret")
        self.assertEqual(self.scope_report()["stage"], "scope")
        for name in (".env", ".git/secret", ".devcontainer/credential.pem"):
            with self.assertRaises((H.Unsafe, OSError)):
                H.public_input(self.root, name)
        (self.root / "link").symlink_to("/private-secret")
        with self.assertRaises((H.Unsafe, OSError)):
            H.public_input(self.root, "link")

    def test_unknown_consumer_feature_or_attachment_shape_fails_early(self):
        self.scope_fixture()
        path = self.root / ".devcontainer/devcontainer.json"
        original = path.read_bytes()
        # These exact replacements preserve JSONC parsing and isolate the gate.
        for old, new in ((b"docker-in-docker:4", b"docker-in-docker:5"),
                         (b"bash ${containerWorkspaceFolder}/.devcontainer/setup.sh", b"private-secret")):
            with self.subTest(new=new):
                path.write_bytes(original.replace(old, new))
                report = self.scope_report("--consumer")
                self.assertEqual(report["stage"], "scope")
                self.assertNotIn("private-secret", json.dumps(report))

    def test_public_input_read_has_a_size_bound_and_never_reads_excluded_state(self):
        path = self.root / "public.txt"
        path.write_text("synthetic")
        self.assertEqual(H.public_input(self.root, "public.txt"), "synthetic")
        path.write_bytes(b"s" * (H.PREFLIGHT_LIMIT + 1))
        with self.assertRaises(H.Unsafe):
            H.public_input(self.root, "public.txt")
        excluded = self.root / ".env"
        excluded.write_text("synthetic private-secret")
        with patch.object(H.os, "open", side_effect=AssertionError("must not open excluded bytes")):
            with self.assertRaises(H.Unsafe):
                H.public_input(self.root, ".env")


if __name__ == "__main__":
    unittest.main()
