#!/usr/bin/env python3
"""Synthetic files only; daemon, /proc, subprocess, signals and native exec mocked."""

import copy
import importlib.util
import io
import json
import os
from pathlib import Path
from types import SimpleNamespace
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

HERE = Path(__file__).resolve().parents[1] / "lifecycle"
sys.path.insert(0, str(HERE))
import test_resources as R

SPEC = importlib.util.spec_from_file_location("generated_read", HERE / "generated-dockerfile-read.py")
assert SPEC and SPEC.loader
G = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(G)


class AdapterTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(dir="/tmp/opencode")
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.root = self.base / "source"
        self.root.mkdir()
        self.store = self.root / "metadata/starter-test-runs"
        self.store.parent.mkdir()
        for module, method in ((R.subprocess, "Popen"), (R.subprocess, "run"),
                               (R.subprocess, "check_output"), (R.os, "killpg"),
                               (R, "process_status"), (G, "compose_process")):
            self.mock(module, method, side_effect=AssertionError("unmocked execution/proc forbidden"))
        self.docker = Mock()
        self.docker.daemon.return_value = "synthetic-daemon"
        self.docker.ids.return_value = set()
        self.owner = R.Run.create(self.root, self.base, self.store, self.docker)
        self.addCleanup(self.owner.close)
        self.owner.arm()
        self.anchor = {"pid": 123, "session": 123, "start": 100,
                       "boot": "00000000-0000-4000-8000-000000000001"}
        self.owner.data.update(worker=123, producer=self.anchor, stage="build")
        self.owner.save()
        scratch = Path(self.owner.data["scratch"])
        self.candidate = scratch / ("starter-lifecycle-" + self.owner.data["run"])
        self.context = self.candidate / ".devcontainer"
        self.context.mkdir(parents=True)
        self.core = self.context / "config/compose/docker-compose-core-tools.yml"
        self.core.parent.mkdir(parents=True)
        self.core.write_text("services: {}\n")
        (self.context / "docker-compose.yml").write_text("services: {}\n")
        self.original = b"FROM ubuntu:24.04 AS foundation\nFROM foundation AS devcontainer\nCMD [\"bash\"]\n"
        (self.context / "Dockerfile").write_bytes(self.original)
        self.native_directory = self.base / "plugins"
        self.native_directory.mkdir()
        for name in ("buildx", "compose"):
            path = self.native_directory / ("docker-" + name)
            path.write_bytes(b"synthetic native bytes, never executed")
            path.chmod(0o755)
        self.mock(G, "NATIVE_DIRECTORIES", (str(self.native_directory),))
        self.home = scratch / "home"
        self.home.mkdir(mode=0o700)
        self.lifecycle = SimpleNamespace(home=self.home, candidate=self.candidate,
                                         root=self.root, ownership=self.owner, env={})
        G.prepare(self.lifecycle)
        self.environment = {**self.lifecycle.env, "HOME": str(self.home), "DOCKER_HOST": R.ENDPOINT}
        self.generated_root = self.base / "devcontainercli-fixture"
        self.generated = self.generated_root / "container-features/0.89.0-123/Dockerfile-with-features"
        self.generated.parent.mkdir(parents=True)
        # Independently transcribed metadata-only CLI shape observed in local files.
        suffix = ('\n\nFROM $_DEV_CONTAINERS_BASE_IMAGE AS dev_containers_target_stage\n'
                  'LABEL devcontainer.metadata="[ \\\n'
                  '{\\"postCreateCommand\\":\\"bash \\${containerWorkspaceFolder}/.devcontainer/setup.sh\\",'
                  '\\"mounts\\":[\\"source=\\${localWorkspaceFolder},target=/home/ubuntu/\\${localEnv:APP_NAME},type=bind\\"],'
                  '\\"remoteUser\\":\\"ubuntu\\",\\"overrideCommand\\":true} \\\n]"\n')
        self.generated.write_bytes(b"\n    ARG _DEV_CONTAINERS_BASE_IMAGE=scratch\n" + self.original + suffix.encode())
        self.override = self.generated_root / "docker-compose/docker-compose.devcontainer.build-123.yml"
        self.override.parent.mkdir()
        self.override.write_text("services:\n  container-svc:\n    build:\n      dockerfile: " + str(self.generated)
                                 + "\n      args:\n        - BUILDKIT_INLINE_CACHE=1\n        - _DEV_CONTAINERS_BASE_IMAGE=devcontainer\n\n")
        self.mock(G, "generated_root", return_value=self.generated_root)
        self.mock(G, "Docker", return_value=self.docker)
        self.mock(G, "producer_identity", return_value=self.anchor)
        self.mock(G, "producer_started_ns", return_value=1)
        self.mock(G.os, "getppid", return_value=200)
        def status(pid):
            if pid == 200:
                return {**self.anchor, "pid": 200, "start": 101}, 123, 123
            if pid == 123:
                return self.anchor, 1, 123
            raise AssertionError("unknown synthetic process")
        self.mock(G, "process_status", side_effect=status)
        self.parent_argv = [str(self.native_directory / "docker-compose"), "compose", "--project-name", self.owner.data["project"],
                            "-f", str(self.context / "docker-compose.yml"), "-f", str(self.core),
                            "-f", str(self.override), "build", "container-svc"]
        self.parent = self.mock(G, "compose_process", side_effect=lambda: (
            self.native_directory / "docker-compose", b"\0".join(x.encode() for x in self.parent_argv) + b"\0"))
        self.exec = self.mock(G.os, "execvpe")
        for name in ("execv", "execve", "system"):
            self.mock(G.os, name, side_effect=AssertionError("unmocked exec forbidden"))
        self.frozen = []
        self.mock(G.os, "dup2", side_effect=lambda fd, target: self.frozen.append(os.read(fd, G.LIMIT + 1)))
        self.mock(G, "METADATA_DIRECTORY", self.base)
        self.metadata = self.base / "compose-build-metadataFile-00000000-0000-4000-8000-000000000001.json"
        # Source-backed Compose bakeArgs shell-out, not a Docker CLI plugin call.
        self.args = ["bake", "--file", "-", "--progress", "rawjson", "--metadata-file", str(self.metadata),
                     "--allow", "fs.read=" + str(self.context)]
        self.document = {"group": {"default": {"targets": ["container-svc"]}}, "target": {"container-svc": {
            "context": str(self.context), "dockerfile": str(self.generated),
            "args": {"APP_NAME": self.candidate.name, "LOCALE": "en_GB.UTF-8", "TZ": "Europe/Madrid",
                     "BUILDKIT_INLINE_CACHE": "1", "_DEV_CONTAINERS_BASE_IMAGE": "devcontainer"},
            "labels": {R.LABEL: self.owner.data["run"], "com.docker.compose.project": self.owner.data["project"],
                       "com.docker.compose.service": "container-svc", "com.docker.compose.version": "5.5.1"},
            "tags": [self.owner.data["tag"]], "output": ["type=docker"]}}}
        self.docker.daemon.reset_mock()

    def mock(self, target, name, *args, **kwargs):
        replacement = patch.object(target, name, *args, **kwargs)
        result = replacement.start()
        self.addCleanup(replacement.stop)
        return result

    def delegate(self, document=None, args=None, payload=None):
        raw = payload if payload is not None else json.dumps(document or self.document).encode()
        G.delegate(self.args if args is None else args, self.environment, io.BytesIO(raw))
        return raw

    def refused(self, **kwargs):
        with self.assertRaises((R.Unsafe, OSError, ValueError, TypeError, KeyError)):
            self.delegate(**kwargs)
        self.exec.assert_not_called()
        self.assertEqual(self.frozen, [])

    def test_positive_adds_one_exact_grant_and_freezes_identical_stdin(self):
        raw = self.delegate()
        native, argv, environment = self.exec.call_args.args
        self.assertEqual(native, str(self.native_directory / "docker-buildx"))
        self.assertEqual(argv, [native, *self.args, "--allow", "fs.read=" + str(self.generated)])
        self.assertEqual(environment, self.environment)
        self.assertEqual(self.frozen, [raw])
        self.assertEqual(self.docker.daemon.call_count, 2)

    def test_documented_buildx_plugin_prefix_preserves_original_native_argv(self):
        self.environment["DOCKER_CLI_PLUGIN_ORIGINAL_CLI_COMMAND"] = "/usr/bin/docker"
        args = ["buildx", *self.args]
        self.delegate(args=args)
        native, forwarded, environment = self.exec.call_args.args
        self.assertEqual(forwarded, [native, *args, "--allow", "fs.read=" + str(self.generated)])
        self.assertEqual(environment, self.environment)

    def test_documented_direct_compose_parent_without_plugin_token_is_supported(self):
        self.parent_argv.pop(1)
        self.delegate()
        self.exec.assert_called_once()

    def test_compose_default_context_is_local_but_foreign_endpoint_overrides_refuse(self):
        self.environment["DOCKER_CONTEXT"] = "default"
        self.delegate()
        self.exec.reset_mock()
        self.frozen.clear()
        for field, value in (("DOCKER_CONTEXT", "foreign"), ("DOCKER_TLS", "1"),
                             ("DOCKER_TLS_VERIFY", "1"), ("DOCKER_CERT_PATH", str(self.root))):
            original = dict(self.environment)
            self.environment[field] = value
            self.refused()
            self.environment = original

    def test_wrong_repeated_or_global_plugin_prefix_does_not_gain_a_grant(self):
        self.refused(args=["buildx", *self.args])
        self.parent_argv.insert(1, "compose")
        self.refused()
        self.parent_argv.pop(1)
        self.parent_argv.insert(1, "--context")
        self.refused()

    def test_source_backed_output_and_optional_metadata_stage_are_exact(self):
        document = copy.deepcopy(self.document)
        document["target"]["container-svc"]["target"] = "dev_containers_target_stage"
        self.delegate(document=document)
        self.exec.reset_mock()
        self.frozen.clear()
        for field, value in (("target", "devcontainer"), ("target", None),
                             ("output", ["type=local,dest=/"]), ("output", ["type=registry"]),
                             ("output", []), ("output", "type=docker")):
            with self.subTest(field=field, value=value):
                rejected = copy.deepcopy(self.document)
                rejected["target"]["container-svc"][field] = value
                self.refused(document=rejected)

    def test_metadata_output_must_be_exact_fresh_uuid_path_without_write_grants(self):
        for path in (str(self.root / self.metadata.name), str(self.base), str(self.metadata) + "/child",
                     str(self.metadata).replace("4000", "5000"), str(self.metadata).replace("metadataFile", "other")):
            rejected = [*self.args]
            rejected[6] = path
            self.refused(args=rejected)
        self.metadata.symlink_to(self.root / "absent")
        self.refused()
        self.metadata.unlink()
        self.metadata.write_text("synthetic collision")
        self.refused()

    def test_metadata_output_creation_before_exec_refuses_without_native_execution(self):
        recheck = G.Inputs.recheck
        def collision(inputs):
            self.metadata.write_text("synthetic collision")
            recheck(inputs)
        with patch.object(G.Inputs, "recheck", collision):
            self.refused()

    def test_private_config_contains_only_isolated_plugin_selection(self):
        directory = self.home / ".docker"
        self.assertEqual(json.loads((directory / "config.json").read_text()), {
            "cliPluginsExtraDirs": [str(HERE / "narrow-plugins")]})
        self.assertEqual(directory.stat().st_mode & 0o777, 0o700)
        for name in ("config.json", "generated-read.json"):
            self.assertEqual((directory / name).stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.environment["DOCKER_CONFIG"], str(directory))
        self.assertFalse((self.root / ".docker").exists())

    def test_sanctioned_core_byte_restoration_is_not_native_replacement(self):
        original = self.core.read_bytes()
        self.core.write_bytes(b"synthetic desired-bind drift")
        self.refused()
        self.core.write_bytes(original)
        self.delegate()
        self.exec.assert_called_once()

    def test_metadata_and_non_bake_are_unchanged_without_reading_stdin_or_daemon(self):
        for args in (["docker-cli-plugin-metadata"], ["buildx", "version"], ["buildx", "build", "--allow", "fs.read=/"]):
            self.exec.reset_mock()
            stream = Mock()
            before = self.docker.daemon.call_count
            G.delegate(args, self.environment, stream)
            stream.read.assert_not_called()
            native, forwarded, env = self.exec.call_args.args
            self.assertEqual(forwarded, [native, *args])
            self.assertEqual(env, self.environment)
            self.assertEqual(self.docker.daemon.call_count, before)
        self.assertEqual(self.frozen, [])

    def test_foreign_or_access_bearing_fields_are_rejected(self):
        for field in ("contexts", "dockerfile-inline", "secret", "ssh", "entitlements", "network", "devices",
                      "annotations", "cache-from", "cache-to", "platforms", "pull", "no-cache", "no-cache-filter",
                      "shm-size", "ulimits", "call", "extra-hosts", "attest", "unknown"):
            with self.subTest(field=field):
                document = copy.deepcopy(self.document)
                document["target"]["container-svc"][field] = []
                self.refused(document=document)

    def test_foreign_target_context_image_label_and_arguments_are_rejected(self):
        for field, value in (("context", str(self.root)), ("tags", ["foreign:tag"]), ("labels", {}), ("args", {})):
            with self.subTest(field=field):
                document = copy.deepcopy(self.document)
                document["target"]["container-svc"][field] = value
                self.refused(document=document)
        document = copy.deepcopy(self.document)
        document["target"]["foreign"] = document["target"]["container-svc"]
        self.refused(document=document)
        document = copy.deepcopy(self.document)
        document["group"]["foreign"] = {"targets": ["container-svc"]}
        self.refused(document=document)

    def test_permission_and_input_argv_encodings_fail_closed(self):
        for args in (["bake", "--file", "foreign.json"], [*self.args, "--allow", "fs.read=/"],
                     [*self.args, "--allow=fs.write=/"], [*self.args, "--set", "*.context=/"],
                     [*self.args[:-1], "fs.read=*"], [*self.args, "--allow", "network.host"],
                     [*self.args, "foreign"], [*self.args, "--file", "-"]):
            with self.subTest(args=args):
                self.refused(args=args)

    def test_duplicate_malformed_and_oversized_json_are_rejected(self):
        for payload in (b'{"target":{},"target":{}}', b"{", b"NaN", b" " * (G.LIMIT + 1)):
            self.refused(payload=payload)

    def test_generated_layout_must_be_exact_not_a_substring(self):
        original = self.generated.read_bytes()
        for payload in (original + b"RUN arbitrary\n", original + self.original,
                        original.replace(b"AS dev_containers_target_stage", b"AS foreign"),
                        original.replace(b"overrideCommand", b"features"), original.replace(G.PREFIX, b"")):
            self.generated.write_bytes(payload)
            self.refused()
        self.generated.write_bytes(original)

    def test_arbitrary_generated_path_and_unsafe_file_or_directory_fail_closed(self):
        document = copy.deepcopy(self.document)
        document["target"]["container-svc"]["dockerfile"] = str(self.root / "private")
        self.refused(document=document)
        self.generated.chmod(0o666)
        self.refused()
        self.generated.chmod(0o644)
        self.generated.parent.chmod(0o777)
        self.refused()
        self.generated.parent.chmod(0o755)
        self.generated.unlink()
        self.generated.symlink_to(self.context / "Dockerfile")
        self.refused()

    def test_special_oversized_and_foreign_owned_generated_inputs_refuse(self):
        original = self.generated.read_bytes()
        self.generated.write_bytes(b"x" * (G.LIMIT + 1))
        self.refused()
        self.generated.unlink()
        self.generated.mkdir()
        self.refused()
        self.generated.rmdir()
        self.generated.write_bytes(original)
        inode = self.generated.stat().st_ino
        original_stat = os.fstat
        def foreign(fd):
            metadata = original_stat(fd)
            if metadata.st_ino == inode:
                return SimpleNamespace(st_mode=metadata.st_mode, st_uid=os.getuid() + 1000)
            return metadata
        with patch.object(G.os, "fstat", side_effect=foreign):
            self.refused()

    def test_unarmed_completed_legacy_and_foreign_daemon_cannot_authorize(self):
        original = copy.deepcopy(self.owner.data)
        for field, value in (("armed", False), ("outcome", "retained"), ("test", "failed"),
                             ("exit", 0), ("producer", None), ("variant", "consumer"),
                             ("project", "foreign"), ("source", str(self.base))):
            with self.subTest(field=field):
                changed = {**original, field: value}
                self.owner.path.write_text(json.dumps(changed))
                self.refused()
        self.owner.path.write_text(json.dumps(original))
        self.docker.daemon.return_value = "foreign"
        self.refused()

    def test_missing_lease_and_changed_worker_identity_refuse(self):
        self.owner.close()
        self.refused()
        # Restore only the synthetic fixture's lock, never a retained run.
        self.owner.lease = os.open(self.owner.path.with_suffix(".lock"), os.O_RDWR)
        G.fcntl.flock(self.owner.lease, G.fcntl.LOCK_EX | G.fcntl.LOCK_NB)
        with patch.object(G, "producer_identity", return_value={**self.anchor, "start": 999}):
            self.refused()

    def test_unrelated_parent_session_and_override_fail_closed(self):
        with patch.object(G, "process_status", return_value=({**self.anchor, "session": 999}, 1, 999)):
            self.refused()
        for index, value in ((3, "foreign"), (5, str(self.root)), (9, str(self.core)), (10, "up")):
            original = self.parent_argv[index]
            self.parent_argv[index] = value
            self.refused()
            self.parent_argv[index] = original
        self.override.write_text(self.override.read_text() + "      secrets: []\n")
        self.refused()

    def test_stale_generated_input_is_not_producer_provenance(self):
        with patch.object(G, "producer_started_ns", return_value=self.generated.stat().st_ctime_ns + 1):
            self.refused()

    def test_config_escape_and_native_replacement_refuse_all_delegation(self):
        self.environment["DOCKER_CONFIG"] = str(self.root)
        self.refused()
        self.environment["DOCKER_CONFIG"] = str(self.home / ".docker")
        (self.native_directory / "docker-buildx").write_bytes(b"replaced")
        self.refused()
        with self.assertRaises(R.Unsafe):
            G.delegate(["docker-cli-plugin-metadata"], self.environment, Mock())
        self.exec.assert_not_called()

    def test_preexec_file_and_native_replacement_are_detected(self):
        original_recheck = G.Inputs.recheck
        for path in (self.generated, self.override, self.core, self.native_directory / "docker-buildx"):
            with self.subTest(path=path.name):
                original = path.read_bytes()
                def changed(inputs):
                    path.write_bytes(original + b"changed")
                    original_recheck(inputs)
                with patch.object(G.Inputs, "recheck", changed):
                    self.refused()
                path.write_bytes(original)
                # Restore the startup pin after deliberate synthetic replacement.
                value = json.loads((self.home / ".docker/generated-read.json").read_text())
                inputs = G.Inputs()
                inputs.read(path, native=path.parent == self.native_directory)
                if str(path) in value["pins"]:
                    value["pins"][str(path)] = inputs.files[path]
                    (self.home / ".docker/generated-read.json").write_text(json.dumps(value))

    def test_preexec_inventory_parent_and_process_replacement_are_detected(self):
        calls = 0
        def producer(pid):
            nonlocal calls
            calls += 1
            return self.anchor if calls == 1 else {**self.anchor, "start": 999}
        with patch.object(G, "producer_identity", side_effect=producer):
            self.refused()
        self.parent.side_effect = [(self.native_directory / "docker-compose", b"\0".join(x.encode() for x in self.parent_argv) + b"\0"),
                                   (self.native_directory / "docker-compose", b"foreign\0")]
        self.refused()
        self.parent.side_effect = lambda: (self.native_directory / "docker-compose", b"\0".join(x.encode() for x in self.parent_argv) + b"\0")
        calls = 0
        def changed_record(pid):
            nonlocal calls
            calls += 1
            if calls == 1:
                record = {**self.owner.data, "test": "failed"}
                self.owner.path.write_text(json.dumps(record))
            return self.anchor
        with patch.object(G, "producer_identity", side_effect=changed_record):
            self.refused()


if __name__ == "__main__":
    unittest.main()
