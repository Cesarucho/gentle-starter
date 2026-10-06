#!/usr/bin/env python3
"""Synthetic files only; daemon, /proc, subprocess, signals and native exec mocked."""

import copy
import importlib.util
import io
import json
import os
import stat
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


class SnapshotTests(unittest.TestCase):
    """Only synthetic bytes and temporary directories; every execution is barred."""

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(dir="/tmp/opencode")
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.origin = self.base / "origin"
        self.origin.mkdir(mode=0o775)
        self.origin.chmod(0o2775)
        self.source = self.origin / "docker-buildx"
        self.source.write_bytes(b"synthetic plugin bytes")
        self.source.chmod(0o775)
        self.destination = self.base / "private"
        self.destination.mkdir(mode=0o700)
        replacements = [(G, "NATIVE_DIRECTORIES", (str(self.origin),))]
        for target, name in ((R.subprocess, "Popen"), (R.subprocess, "run"),
                             (R.subprocess, "check_output"), (R, "command"),
                             (G.os, "execvpe"), (G.os, "execv"), (G.os, "execve"),
                             (G.os, "system"), (G.os, "killpg")):
            replacements.append((target, name, Mock(side_effect=AssertionError("execution forbidden"))))
        for target, name, value in replacements:
            replacement = patch.object(target, name, value)
            replacement.start()
            self.addCleanup(replacement.stop)

    def publish(self):
        return G.publish_native_snapshot(self.source, self.destination, "docker-buildx")

    def refused(self):
        with self.assertRaises((R.Unsafe, OSError)):
            self.publish()
        self.assertFalse((self.destination / "docker-buildx").exists())
        self.assertEqual(list(self.destination.glob(".snapshot-*")), [])

    def test_group_writable_origin_copies_exact_bytes_without_changing_source(self):
        before = self.source.read_bytes(), G.identity(self.source.stat())
        path = self.publish()
        self.assertEqual(path.read_bytes(), before[0])
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o500)
        self.assertEqual(path.stat().st_uid, os.getuid())
        self.assertEqual((self.source.read_bytes(), G.identity(self.source.stat())), before)
        self.assertEqual(stat.S_IMODE(self.origin.stat().st_mode), 0o2775)
        with self.assertRaises(R.Unsafe):
            G.Inputs().read(self.source, native=True)

    def test_unknown_origin_and_name_refuse(self):
        with self.assertRaises(R.Unsafe):
            G.NativeSnapshot(self.destination / "docker-buildx")
        with self.assertRaises(R.Unsafe):
            G.NativeSnapshot(self.origin / "unknown")
        with self.assertRaises(R.Unsafe):
            G.publish_native_snapshot(self.source, self.destination, "unknown")

    def test_source_symlink_refuses(self):
        self.source.unlink()
        self.source.symlink_to(self.base / "absent")
        self.refused()

    def test_source_parent_symlink_refuses(self):
        moved = self.base / "moved"
        self.origin.rename(moved)
        self.origin.symlink_to(moved, target_is_directory=True)
        self.refused()

    def test_directory_fifo_and_nonexecutable_sources_refuse_without_blocking(self):
        self.source.chmod(0o664)
        self.refused()
        self.source.unlink()
        self.source.mkdir()
        self.refused()
        self.source.rmdir()
        os.mkfifo(self.source, 0o700)
        self.refused()

    def test_world_writable_source_and_origin_refuse(self):
        self.source.chmod(0o777)
        self.refused()
        self.source.chmod(0o775)
        self.origin.chmod(0o777)
        self.refused()

    def test_wrong_source_and_directory_owners_refuse(self):
        original = G.os.fstat
        for path in (self.source, self.origin):
            inode = path.stat().st_ino
            def foreign(descriptor):
                metadata = original(descriptor)
                if metadata.st_ino == inode:
                    return SimpleNamespace(**{name: getattr(metadata, name) for name in (
                        "st_dev", "st_ino", "st_gid", "st_mode", "st_size", "st_mtime_ns", "st_ctime_ns")},
                        st_uid=os.getuid() + 10000)
                return metadata
            with patch.object(G.os, "fstat", side_effect=foreign):
                self.refused()

    def test_oversized_source_refuses_before_read(self):
        with patch.object(G, "NATIVE_LIMIT", 4), patch.object(G.os, "read") as read:
            self.refused()
            read.assert_not_called()

    def test_bounded_descriptor_read_rejects_growth(self):
        with patch.object(G, "NATIVE_LIMIT", 4), patch.object(G.os, "read", return_value=b"12345"):
            with self.assertRaises(R.Unsafe):
                G.bounded_native_read(123)

    def test_source_mutation_and_membership_replacement_during_read_refuse(self):
        original_read = G.os.read
        for replace in (False, True):
            with self.subTest(replace=replace):
                changed = False
                def read(descriptor, size):
                    nonlocal changed
                    payload = original_read(descriptor, size)
                    if not changed:
                        changed = True
                        if replace:
                            self.source.rename(self.origin / "old")
                        self.source.write_bytes(b"changed synthetic bytes")
                        self.source.chmod(0o775)
                    return payload
                with patch.object(G.os, "read", side_effect=read):
                    self.refused()

    def test_held_source_rechecks_before_publication(self):
        original = G.verify_snapshot_destination
        def verify(*args):
            metadata = original(*args)
            self.source.write_bytes(b"changed after copy")
            return metadata
        with patch.object(G, "verify_snapshot_destination", side_effect=verify):
            self.refused()

    def test_ancestor_replacement_refuses_but_sibling_creation_is_allowed(self):
        with G.NativeSnapshot(self.source) as snapshot:
            (self.origin / "sibling").write_bytes(b"unrelated")
            snapshot.recheck()
            self.origin.rename(self.base / "moved")
            self.origin.mkdir(mode=0o775)
            with self.assertRaises(R.Unsafe):
                snapshot.recheck()

    def test_collision_and_dangling_destination_symlink_are_never_overwritten(self):
        target = self.destination / "docker-buildx"
        target.write_bytes(b"preserve collision")
        with self.assertRaises(FileExistsError):
            self.publish()
        self.assertEqual(target.read_bytes(), b"preserve collision")
        target.unlink()
        target.symlink_to(self.base / "absent")
        with self.assertRaises((FileExistsError, R.Unsafe)):
            self.publish()
        self.assertTrue(target.is_symlink())
        self.assertEqual(list(self.destination.glob(".snapshot-*")), [])

    def test_independent_destination_hash_mismatch_refuses_publication(self):
        original = G.os.write
        environment = dict(os.environ)
        with patch.object(G.os, "write", side_effect=lambda fd, data: original(fd, b"x" * len(data))):
            self.refused()
        self.assertEqual(dict(os.environ), environment)

    def test_destination_directory_replacement_prevents_publication(self):
        original = G.verify_snapshot_destination
        moved = self.base / "moved"
        def verify(*args):
            metadata = original(*args)
            self.destination.rename(moved)
            self.destination.mkdir(mode=0o700)
            return metadata
        with patch.object(G, "verify_snapshot_destination", side_effect=verify):
            self.refused()
        self.assertEqual(list(moved.iterdir()), [])

    def test_staged_mode_tampering_is_rejected_by_independent_read(self):
        original = G.verify_snapshot_destination
        def verify(parent, name, payload):
            os.chmod(name, 0o775, dir_fd=parent, follow_symlinks=False)
            return original(parent, name, payload)
        with patch.object(G, "verify_snapshot_destination", side_effect=verify):
            self.refused()

    def test_private_destination_mode_and_parent_symlink_refuse(self):
        self.destination.chmod(0o750)
        self.refused()
        self.destination.chmod(0o700)
        moved = self.base / "moved"
        self.destination.rename(moved)
        self.destination.symlink_to(moved, target_is_directory=True)
        self.refused()


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
        self.origin_directory = self.native_directory
        self.native_directory = self.home / ".docker/native"
        self.compose_native = self.home / ".docker/plugins/docker-compose"
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
        self.parent_argv = [str(self.compose_native), "compose", "--project-name", self.owner.data["project"],
                            "-f", str(self.context / "docker-compose.yml"), "-f", str(self.core),
                            "-f", str(self.override), "build", "container-svc"]
        self.parent = self.mock(G, "compose_process", side_effect=lambda: (
            self.compose_native, b"\0".join(x.encode() for x in self.parent_argv) + b"\0"))
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
            "cliPluginsExtraDirs": [str(directory / "plugins")]})
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
        native = self.native_directory / "docker-buildx"
        native.chmod(0o700)
        native.write_bytes(b"replaced")
        native.chmod(0o500)
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
                    if path.parent == self.native_directory:
                        path.chmod(0o700)
                    path.write_bytes(original + b"changed")
                    if path.parent == self.native_directory:
                        path.chmod(0o500)
                    original_recheck(inputs)
                with patch.object(G.Inputs, "recheck", changed):
                    self.refused()
                if path.parent == self.native_directory:
                    path.chmod(0o700)
                path.write_bytes(original)
                if path.parent == self.native_directory:
                    path.chmod(0o500)
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
        self.parent.side_effect = [(self.compose_native, b"\0".join(x.encode() for x in self.parent_argv) + b"\0"),
                                   (self.compose_native, b"foreign\0")]
        self.refused()
        self.parent.side_effect = lambda: (self.compose_native, b"\0".join(x.encode() for x in self.parent_argv) + b"\0")
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

    def test_private_layout_exact_pins_and_nonrecursive_native_selection(self):
        value = G.validate_selection(self.environment)
        paths = G.selection_paths(self.owner.data, self.home / ".docker")
        self.assertEqual(set(value["pins"]), {str(path) for path in paths.values()})
        self.assertEqual(len(value["pins"]), 9)
        self.assertEqual(value["native"]["compose"], str(self.compose_native))
        self.assertNotEqual(value["native"]["buildx"], str(paths["launcher"]))
        for name in ("compose", "buildx", "launcher"):
            self.assertEqual(paths[name].stat().st_mode & 0o777, 0o500)
        for directory in (self.home, self.home / ".docker", self.home / ".docker/plugins", self.native_directory):
            self.assertEqual(directory.stat().st_mode & 0o777, 0o700)

    def test_private_selection_allows_desired_core_drift_without_daemon(self):
        self.core.write_bytes(b"temporary desired drift")
        G.validate_selection(self.environment)
        self.docker.daemon.assert_not_called()
        self.refused()  # Bake still requires original candidate bytes.

    def test_selection_config_and_missing_launcher_prevent_delegation(self):
        config = self.home / ".docker/config.json"
        config.write_text(json.dumps({"cliPluginsExtraDirs": [str(self.origin_directory)]}))
        self.refused(args=["docker-cli-plugin-metadata"])
        config.write_text(json.dumps({"cliPluginsExtraDirs": [str(self.home / ".docker/plugins")]}))
        (self.home / ".docker/plugins/docker-buildx").unlink()
        with self.assertRaises((R.Unsafe, OSError)):
            G.validate_selection(self.environment)

    def test_dependency_tamper_detected_without_mutating_repository(self):
        original = G.Inputs.read
        for path in (HERE / "generated-dockerfile-read.py", HERE / "test_resources.py"):
            def altered(inputs, selected, native=False):
                payload = original(inputs, selected, native=native)
                if Path(selected) == path:
                    inputs.files[Path(selected)][1] = "0" * 64
                return payload
            with patch.object(G.Inputs, "read", altered):
                self.refused(args=["docker-cli-plugin-metadata"])

    def test_private_pin_set_and_native_path_cannot_be_expanded(self):
        record = self.home / ".docker/generated-read.json"
        original = json.loads(record.read_text())
        for change in ("extra", "missing", "native"):
            value = copy.deepcopy(original)
            if change == "extra":
                value["pins"][str(self.root)] = next(iter(value["pins"].values()))
            elif change == "missing":
                value["pins"].pop(str(self.core))
            else:
                value["native"]["buildx"] = str(self.home / ".docker/plugins/docker-buildx")
            record.write_text(json.dumps(value))
            self.refused(args=["docker-cli-plugin-metadata"])

    def test_prepare_collision_and_copy_failure_leave_environment_unpublished(self):
        environment = {"sentinel": "unchanged", "DOCKER_CONFIG": "existing", "HGDR_BINDING": "existing"}
        self.lifecycle.env = dict(environment)
        with self.assertRaises(FileExistsError):
            G.prepare(self.lifecycle)
        self.assertEqual(self.lifecycle.env, environment)
        # Move only this synthetic fixture's config; no retained resources.
        (self.home / ".docker").rename(self.home / "previous-config")
        with patch.object(G, "publish_native_snapshot", side_effect=R.Unsafe("synthetic copy failure")):
            with self.assertRaises(R.Unsafe):
                G.prepare(self.lifecycle)
        self.assertEqual(self.lifecycle.env, environment)

    def test_prepare_rejects_foreign_root_without_daemon_or_environment_change(self):
        self.lifecycle.home = self.root
        before = dict(self.lifecycle.env)
        with self.assertRaises(R.Unsafe):
            G.prepare(self.lifecycle)
        self.assertEqual(self.lifecycle.env, before)
        self.docker.daemon.assert_not_called()

    def bootstrap_namespace(self):
        path = self.home / ".docker/plugins/docker-buildx"
        namespace: dict = {"__name__": "synthetic_bootstrap"}
        exec(compile(path.read_bytes(), str(path), "exec"), namespace)
        return namespace

    def test_bootstrap_metadata_uses_verified_bytes_and_injects_only_expected_binding(self):
        namespace = self.bootstrap_namespace()
        environment = dict(self.environment)
        environment.pop("HGDR_BINDING")
        original_compile = compile
        compiled = []
        def capture(payload, filename, mode, *args, **kwargs):
            if filename in {str(HERE / "generated-dockerfile-read.py"), str(HERE / "test_resources.py")}:
                self.assertIsInstance(payload, bytes)
                compiled.append(filename)
            return original_compile(payload, filename, mode, *args, **kwargs)
        with patch.dict(os.environ, environment, clear=True), \
                patch.object(sys, "argv", ["private-buildx", "docker-cli-plugin-metadata"]), \
                patch.object(sys, "stdin", SimpleNamespace(buffer=Mock())), \
                patch("builtins.compile", side_effect=capture):
            namespace["bootstrap"]()
        self.assertEqual(compiled, [str(HERE / "test_resources.py"), str(HERE / "generated-dockerfile-read.py")])
        native, argv, forwarded = self.exec.call_args.args
        self.assertEqual(native, str(self.native_directory / "docker-buildx"))
        self.assertEqual(argv, [native, "docker-cli-plugin-metadata"])
        self.assertEqual(forwarded["HGDR_BINDING"], self.environment["HGDR_BINDING"])
        self.docker.daemon.assert_not_called()

    def test_bootstrap_foreign_binding_and_dependency_tamper_refuse_before_import(self):
        namespace = self.bootstrap_namespace()
        with patch.dict(os.environ, {**self.environment, "HGDR_BINDING": str(self.root)}, clear=True):
            with self.assertRaises(RuntimeError):
                namespace["bootstrap"]()
        item = namespace["STARTUP"]["modules"]["test_resources"]
        item[1][1] = "0" * 64
        with patch.dict(os.environ, self.environment, clear=True):
            with self.assertRaises(RuntimeError):
                namespace["bootstrap"]()
        self.exec.assert_not_called()

    def test_bootstrap_compiles_frozen_payloads_after_both_paths_disappear(self):
        namespace = self.bootstrap_namespace()
        helper, adapter = self.base / "helper.py", self.base / "adapter.py"
        helper.write_bytes(b'VALUE = "synthetic frozen helper"\n')
        adapter.write_bytes(b'import os\nfrom test_resources import VALUE\n'
                            b'def delegate(argv, environment, stream):\n'
                            b'    os.execvpe(VALUE, argv, environment)\n')
        inputs = G.Inputs()
        for name, path in (("test_resources", helper), ("generated_read", adapter)):
            inputs.read(path)
            namespace["STARTUP"]["modules"][name] = [str(path), inputs.files[path]]
        verified = namespace["verified"]
        def freeze(path, pin):
            payload = verified(path, pin)
            Path(path).unlink()  # Synthetic modules only; import must use frozen bytes.
            return payload
        namespace["verified"] = freeze
        with patch.dict(os.environ, self.environment, clear=True), \
                patch.object(sys, "argv", ["private-buildx", "docker-cli-plugin-metadata"]), \
                patch.object(sys, "stdin", SimpleNamespace(buffer=Mock())):
            namespace["bootstrap"]()
        self.assertEqual(self.exec.call_args.args[0], "synthetic frozen helper")

    def test_prepare_checks_marker_inode_and_held_lease_before_copy(self):
        marker = self.home.parent / R.MARKER
        marker.write_text("foreign")
        with self.assertRaises(R.Unsafe):
            G.prepare(self.lifecycle)
        marker.write_text(self.owner.data["run"])
        original_inode = list(self.owner.data["inode"])
        self.owner.data["inode"] = [0, 0]
        self.owner.save()
        with self.assertRaises(R.Unsafe):
            G.prepare(self.lifecycle)
        self.owner.data["inode"] = original_inode
        self.owner.save()
        G.fcntl.flock(self.owner.lease, G.fcntl.LOCK_UN)
        with self.assertRaisesRegex(R.Unsafe, "lease is not held"):
            G.prepare(self.lifecycle)
        G.fcntl.flock(self.owner.lease, G.fcntl.LOCK_EX | G.fcntl.LOCK_NB)
        self.docker.daemon.assert_not_called()

    def test_prepare_accepts_group_writable_origins_but_creates_strict_private_copies(self):
        (self.home / ".docker").rename(self.home / "previous-config")
        self.origin_directory.chmod(0o2775)
        for path in self.origin_directory.iterdir():
            path.chmod(0o775)
        before = {str(path): (path.read_bytes(), G.identity(path.stat()))
                  for path in self.origin_directory.iterdir()}
        G.prepare(self.lifecycle)
        G.validate_selection(self.environment)
        self.assertEqual(before, {str(path): (path.read_bytes(), G.identity(path.stat()))
                                  for path in self.origin_directory.iterdir()})
        self.assertEqual(self.compose_native.stat().st_mode & 0o777, 0o500)
        self.docker.daemon.assert_not_called()


if __name__ == "__main__":
    unittest.main()
