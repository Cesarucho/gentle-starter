"""Mock boundaries for the explicit consumer fixture; no Docker is invoked."""

import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock, patch


spec = importlib.util.spec_from_file_location("starter_lifecycle", Path(__file__).with_name("starter-lifecycle.py"))
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ConsumerFlowTests(unittest.TestCase):
    def test_nested_docker_uses_distinct_daemon_and_explicit_socket(self):
        fixture = module.ConsumerLifecycle.__new__(module.ConsumerLifecycle)
        fixture.ownership = Mock(data={"daemon": "host-id"})
        fixture.docker = Mock(side_effect=['[]', 'nested-id', 'Hello from Docker!'])
        fixture.assert_nested_docker("container-id")
        endpoint = ("exec", "--user", "ubuntu", "container-id", "docker", "-H", "unix:///var/run/docker.sock")
        self.assertEqual(fixture.docker.call_args_list[1].args, (*endpoint, "info", "--format", "{{.ID}}"))
        self.assertEqual(fixture.docker.call_args_list[2].args, (*endpoint, "run", "--rm", "hello-world"))

    def test_host_socket_bind_is_rejected_before_nested_commands(self):
        fixture = module.ConsumerLifecycle.__new__(module.ConsumerLifecycle)
        fixture.ownership = Mock(data={"daemon": "host-id"})
        fixture.docker = Mock(return_value='[{"Type":"bind","Source":"/var/run/docker.sock","Destination":"/var/run/docker.sock"}]')
        with self.assertRaisesRegex(RuntimeError, "binds the host Docker socket"):
            fixture.assert_nested_docker("container-id")
        fixture.docker.assert_called_once_with("inspect", "--format", "{{json .Mounts}}", "container-id")

    def test_host_run_directory_bind_is_rejected(self):
        fixture = module.ConsumerLifecycle.__new__(module.ConsumerLifecycle)
        fixture.ownership = Mock(data={"daemon": "host-id"})
        fixture.docker = Mock(return_value='[{"Type":"bind","Source":"/run","Destination":"/host-run"}]')
        with self.assertRaisesRegex(RuntimeError, "binds the host Docker socket"):
            fixture.assert_nested_docker("container-id")
        self.assertEqual(fixture.docker.call_count, 1)

    def test_matching_host_daemon_rejects_hello_world(self):
        fixture = module.ConsumerLifecycle.__new__(module.ConsumerLifecycle)
        fixture.ownership = Mock(data={"daemon": "host-id"})
        fixture.docker = Mock(side_effect=['[]', 'host-id'])
        with self.assertRaisesRegex(RuntimeError, "matches the host daemon"):
            fixture.assert_nested_docker("container-id")
        self.assertEqual(fixture.docker.call_count, 2)

    def test_probe_precedes_any_fixture_or_build(self):
        fixture = module.ConsumerLifecycle.__new__(module.ConsumerLifecycle)
        fixture.ownership = Mock()
        fixture.ownership.probe_bind.side_effect = module.Unsafe("probe failed")
        with self.assertRaises(module.Unsafe):
            fixture.execute()
        fixture.ownership.arm.assert_called_once_with()
        fixture.ownership.produce.assert_not_called()

    def test_consumer_inherits_registered_success_cleanup_and_failure_retention(self):
        self.assertIs(module.ConsumerLifecycle.cleanup, module.Lifecycle.cleanup)
        self.assertIs(module.ConsumerLifecycle.retain, module.Lifecycle.retain)
        fixture = module.ConsumerLifecycle.__new__(module.ConsumerLifecycle)
        fixture.ownership = Mock()
        fixture.retain()
        fixture.ownership.retain.assert_called_once_with()

    def test_consumer_cleanup_requires_exact_verified_feature_pair(self):
        fixture = module.ConsumerLifecycle.__new__(module.ConsumerLifecycle)
        fixture.ownership = Mock(data={"variant": "consumer", "feature_volumes": {}})
        fixture.root = Path("/fixture")
        fixture.ownership.cleanup.return_value = {"removed": [], "retained": ["shared build cache (no dedicated builder)"], "failed": [], "feature_volumes": set()}
        fixture.before = fixture.source_status = None
        with patch.object(module, "snapshot", return_value=None), patch.object(module, "run", return_value=None):
            self.assertTrue(fixture.cleanup())

    def test_consumer_cleanup_rejects_unexpected_retained_image(self):
        fixture = module.ConsumerLifecycle.__new__(module.ConsumerLifecycle)
        fixture.ownership = Mock(data={"variant": "consumer", "feature_volumes": {"one": "created", "two": "created"}})
        fixture.root = Path("/fixture")
        fixture.ownership.cleanup.return_value = {"removed": [], "retained": ["shared build cache (no dedicated builder)",
            "feature state volume one", "feature state volume two", "shared or unverifiable image sha256:bad"], "failed": [], "feature_volumes": {"one", "two"}}
        fixture.before = fixture.source_status = None
        with patch.object(module, "snapshot", return_value=None), patch.object(module, "run", return_value=None):
            self.assertTrue(fixture.cleanup())

    def test_consumer_cleanup_preserves_engine_failure_without_redundant_retention_error(self):
        fixture = module.ConsumerLifecycle.__new__(module.ConsumerLifecycle)
        fixture.ownership = Mock(data={"variant": "consumer", "feature_volumes": {}})
        fixture.root = Path("/fixture")
        fixture.ownership.cleanup.return_value = {"removed": [], "retained": [], "failed": ["daemon failed"], "feature_volumes": set()}
        fixture.before = fixture.source_status = None
        with patch.object(module, "snapshot", return_value=None), patch.object(module, "run", return_value=None):
            self.assertEqual(fixture.cleanup(), ["daemon failed"])

    def test_consumer_cleanup_accepts_only_exact_verified_feature_retention(self):
        fixture = module.ConsumerLifecycle.__new__(module.ConsumerLifecycle)
        fixture.ownership = Mock(data={"variant": "consumer", "feature_volumes": {"one": "created", "two": "created"}})
        fixture.root = Path("/fixture")
        fixture.ownership.cleanup.return_value = {"removed": [], "retained": ["shared build cache (no dedicated builder)",
            "feature state volume one", "feature state volume two"], "failed": [], "feature_volumes": {"one", "two"}}
        fixture.before = fixture.source_status = None
        with patch.object(module, "snapshot", return_value=None), patch.object(module, "run", return_value=None):
            self.assertEqual(fixture.cleanup(), [])

    def test_consumer_entrypoint_selects_variant_without_creating_resources(self):
        with patch.object(module, "run", return_value="/fixture"), patch.object(module.Path, "cwd", return_value=Path("/fixture")), \
                patch.object(module.shutil, "which", return_value="/bin/tool"), \
                patch.object(module.Run, "create", side_effect=module.Unsafe("stopped before allocation")) as create, \
                patch.object(module, "ConsumerLifecycle") as consumer:
            with self.assertRaises(module.Unsafe):
                with patch.object(module.sys, "argv", ["starter-lifecycle.py", "--consumer", "--daemon-visible-scratch", "/tmp"]):
                    module.main()
            consumer.assert_not_called()
            create.assert_called_once_with(Path("/fixture"), Path("/tmp"), variant="consumer")


if __name__ == "__main__":
    unittest.main()
