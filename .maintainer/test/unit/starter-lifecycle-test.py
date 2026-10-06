#!/usr/bin/env python3
"""Safe tests: no real Docker, Task lifecycle, installers, or Git commits."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, call, patch


ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("lifecycle", ROOT / ".maintainer/test/lifecycle/starter-lifecycle.py")
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
             patch.object(H, "Run") as run:
            with self.assertRaisesRegex(SystemExit, "existing plain scratch parent"):
                H.main()
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

    def test_generated_read_requires_attachment_and_rejects_duplicate_selectors(self):
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

    def test_generated_read_opt_in_reaches_only_attachment_lifecycle(self):
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


if __name__ == "__main__":
    unittest.main()
