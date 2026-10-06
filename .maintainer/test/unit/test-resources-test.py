#!/usr/bin/env python3
"""Ownership regressions using synthetic files and an in-memory Docker API only."""

import copy
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

HERE = Path(__file__).resolve().parents[1] / "lifecycle"
sys.path.insert(0, str(HERE))
import test_resources as R


def load_script(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), HERE / (name + ".py"))
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakeDocker:
    def __init__(self):
        self.identity = "synthetic-daemon"
        self.items = {kind: {} for kind in R.KINDS}
        self.mutations = []
        self.error = False
        self.references = {}
        self.busy_images = set()

    def daemon(self):
        if self.error:
            raise R.Unsafe("synthetic query failure")
        return self.identity

    def ids(self, kind, filters=()):
        self.daemon()
        items = self.items[kind]
        for value in filters:
            if value.startswith("label="):
                key, expected = value[6:].split("=", 1)
                items = {key_id: item for key_id, item in items.items() if item["labels"].get(key) == expected}
            elif value.startswith("reference="):
                return set(self.references.get(value[10:], ()))
            elif value.startswith("ancestor="):
                return {"foreign"} if value[9:] in self.busy_images else set()
            elif value.startswith("name="):
                return set()
            else:
                raise AssertionError(value)
        return set(items)

    def inspect(self, kind, identity):
        self.daemon()
        return copy.deepcopy(self.items[kind].get(identity))

    def mounts(self, identity):
        return copy.deepcopy(self.items["container"][identity]["mounts"])

    def __call__(self, *args):
        self.daemon()
        self.mutations.append(args)
        kind = "container" if args[0] == "rm" else args[0]
        target = args[-1]
        if target in self.references:
            target = next(iter(self.references.pop(target)))
        self.items[kind].pop(target)
        return ""

    def add(self, run, kind="container", digit="a", tags=None):
        identity = "sha256:" + digit * 64 if kind == "image" else digit * 64
        tags = tags or []
        self.items[kind][identity] = {"id": identity, "labels": run.expected(kind), "tags": tags, "digests": [],
                                     "created": "2026-01-01T00:00:00Z" if kind == "volume" else ""}
        for tag in tags:
            self.references[tag] = {identity}
        return identity


class ResourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir="/tmp/opencode")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / "source"
        self.root.mkdir()
        self.store = self.root / "metadata" / "starter-test-runs"
        self.store.parent.mkdir()
        self.docker = FakeDocker()
        for method in ("check_output", "run", "Popen"):
            process = patch.object(R.subprocess, method, side_effect=AssertionError("real process forbidden"))
            process.start()
            self.addCleanup(process.stop)
        for target, method, effect in ((R.os, "killpg", AssertionError("real signal forbidden")),
                                       (R, "process_status", AssertionError("unmocked proc read"))):
            guard = patch.object(target, method, side_effect=effect)
            guard.start()
            self.addCleanup(guard.stop)
        anchor = patch.object(R, "producer_identity", side_effect=lambda pid: self.anchor(pid))
        anchor.start()
        self.addCleanup(anchor.stop)
        self.owner = R.Run.create(self.root, self.base, self.store, self.docker)
        self.addCleanup(self.owner.close)
        self.scratch = Path(self.owner.data["scratch"])

    def anchor(self, pid=123):
        return {"pid": pid, "start": 100, "session": pid, "boot": "00000000-0000-4000-8000-000000000001"}

    def arm(self):
        self.owner.arm()

    def feature_volumes(self):
        self.owner = R.Run.create(self.root, self.base, self.store, self.docker, variant="consumer")
        self.addCleanup(self.owner.close)
        self.owner.arm()
        container = self.docker.add(self.owner)
        suffix = "fixture-id"
        volumes = {}
        for name, target in (("dind-var-lib-docker-", "/var/lib/docker"),
                             ("dind-var-lib-containerd-", "/var/lib/containerd")):
            identity = self.owner.data["project"] + "_" + name + suffix
            self.docker.items["volume"][identity] = {
                "id": identity, "labels": {"com.docker.compose.project": self.owner.data["project"],
                                            "com.docker.compose.volume": name.removesuffix("-") + "-" + suffix,
                                            "com.docker.compose.config-hash": "hash", "com.docker.compose.version": "2.0"},
                "tags": [], "digests": [], "created": "2026-01-01T00:00:00Z"}
            volumes[identity] = target
        self.docker.items["container"][container]["mounts"] = [
            {"Type": "volume", "Name": name, "Destination": target}
            for name, target in volumes.items()]
        return volumes

    def test_consumer_feature_volumes_are_retained_not_owned(self):
        volumes = self.feature_volumes()
        before = self.owner.path.read_bytes()
        preview = self.owner.cleanup()
        self.assertFalse(preview["failed"])
        self.assertEqual(self.owner.path.read_bytes(), before)
        self.assertEqual(self.docker.mutations, [])
        recovered = R.Run.open(self.owner.path, self.root, docker=self.docker)
        self.assertFalse(recovered.cleanup()["failed"])
        self.assertEqual(self.owner.path.read_bytes(), before)
        result = self.owner.cleanup(apply=True)
        self.assertFalse(result["failed"])
        self.assertEqual(self.owner.data["outcome"], "retained")
        self.assertEqual(self.owner.data["resources"]["volume"], {})
        self.assertEqual(set(volumes), set(self.docker.items["volume"]))
        self.assertTrue(all(name in " ".join(result["retained"]) for name in volumes))
        recovered = R.Run.open(self.owner.path, self.root, docker=self.docker)
        self.assertFalse(recovered.cleanup()["failed"])
        with self.assertRaises(R.Unsafe):
            self.owner.forget()

    def test_consumer_cli_expected_retention_succeeds_but_forget_refuses(self):
        volumes = self.feature_volumes()
        cli = load_script("starter-test-clean")
        self.owner.close()
        with patch.object(cli, "command", return_value=str(self.root)), patch.object(cli, "registry_path", return_value=self.store), \
                patch.object(R, "Docker", return_value=self.docker), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(cli.main(["--run", self.owner.data["run"]]), 0)
            self.assertEqual(cli.main(["--run", self.owner.data["run"], "--apply"]), 0)
            self.assertEqual(cli.main(["--run", self.owner.data["run"], "--apply", "--forget"]), 1)
        self.assertEqual(set(volumes), set(self.docker.items["volume"]))
        self.assertTrue(self.owner.path.exists())

    def test_consumer_rejects_extra_or_mismounted_volume(self):
        volumes = self.feature_volumes()
        self.docker.items["volume"]["unexpected"] = {
            **next(iter(self.docker.items["volume"].values())), "id": "unexpected"}
        self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.assertEqual(self.docker.mutations, [])
        del self.docker.items["volume"]["unexpected"]
        container = next(iter(self.docker.items["container"].values()))
        container["mounts"][0]["Destination"] = "/wrong"
        self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.assertEqual(self.docker.mutations, [])

    def test_consumer_rejects_foreign_labels_replacement_and_tracked_collision(self):
        for condition in ("project", "logical", "run-label", "created", "tracked"):
            with self.subTest(condition=condition):
                self.docker.items["container"].clear()
                self.docker.items["volume"].clear()
                volumes = self.feature_volumes()
                identity = next(iter(volumes))
                item = self.docker.items["volume"][identity]
                if condition == "project":
                    item["labels"]["com.docker.compose.project"] = "foreign"
                    item["labels"][R.LABEL] = self.owner.data["run"]
                elif condition == "logical":
                    item["labels"]["com.docker.compose.volume"] = "foreign"
                elif condition == "run-label":
                    item["labels"][R.LABEL] = self.owner.data["run"]
                elif condition == "created":
                    self.owner.data["feature_volumes"] = {name: "original" for name in volumes}
                    self.owner.save()
                else:
                    self.owner.data["resources"]["volume"][identity] = {
                        "labels": self.owner.expected("volume"), "tags": [], "created": item["created"]}
                    self.owner.save()
                self.assertTrue(self.owner.cleanup(apply=True)["failed"])
                self.assertEqual(self.docker.mutations, [])

    def test_consumer_record_rejects_unprefixed_or_mismatched_suffix(self):
        volumes = self.feature_volumes()
        for names in (("dind-var-lib-docker-fixture-id", "dind-var-lib-containerd-fixture-id"),
                      (next(iter(volumes)), self.owner.data["project"] + "_dind-var-lib-containerd-other")):
            with self.subTest(names=names):
                self.owner.data["feature_volumes"] = dict.fromkeys(names, "created")
                with self.assertRaises(R.Unsafe):
                    self.owner.save()

    def test_old_inventory_cannot_infer_consumer_variant(self):
        self.arm()
        name = "dind-var-lib-docker-fixture-id"
        self.docker.items["volume"][name] = {
            "id": name, "labels": {"com.docker.compose.project": self.owner.data["project"]},
            "tags": [], "created": "2026-01-01T00:00:00Z"}
        before = self.owner.path.read_bytes()
        self.assertTrue(self.owner.cleanup()["failed"])
        self.assertEqual(self.owner.path.read_bytes(), before)
        self.assertEqual(self.docker.mutations, [])

    def test_intent_is_private_outside_scratch_and_bound_to_worktree(self):
        self.assertFalse(self.owner.path.is_relative_to(self.scratch))
        self.assertEqual(self.owner.path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.store.stat().st_mode & 0o777, 0o700)
        self.assertEqual(R.read_record(self.owner.path, self.root)["run"], self.owner.data["run"])
        with self.assertRaises(R.Unsafe):
            R.read_record(self.owner.path, self.base)

    def test_inventory_exists_before_scratch_creation(self):
        original = Path.mkdir
        def mkdir(path, *args, **kwargs):
            if path.name.startswith("starter-test-"):
                token = path.name.removeprefix("starter-test-")
                self.assertEqual(json.loads((self.store / (token + ".json")).read_text())["scratch"], str(path))
            return original(path, *args, **kwargs)
        with patch.object(Path, "mkdir", mkdir):
            other = R.Run.create(self.root, self.base, self.store, self.docker)
        other.close()

    def test_preview_is_byte_for_byte_read_only(self):
        self.arm()
        identity = self.docker.add(self.owner)
        before = self.owner.path.read_bytes()
        result = self.owner.cleanup()
        self.assertFalse(result["failed"])
        self.assertIn(identity, " ".join(result["removed"]))
        self.assertEqual(self.owner.path.read_bytes(), before)
        self.assertTrue(self.scratch.exists())
        self.assertEqual(self.docker.mutations, [])

    def test_cleanup_removes_exact_ids_and_is_idempotent(self):
        self.arm()
        for kind in R.KINDS:
            self.docker.add(self.owner, kind, tags=[self.owner.data["tag"]] if kind == "image" else [])
        foreign = "f" * 64
        self.docker.items["container"][foreign] = {"labels": {}}
        result = self.owner.cleanup(apply=True)
        self.assertFalse(result["failed"])
        self.assertEqual(len(self.docker.mutations), 4)
        self.assertTrue(all(foreign not in call for call in self.docker.mutations))
        self.assertIn(("image", "rm", "--no-prune", self.owner.data["tag"]), self.docker.mutations)
        self.assertFalse(self.scratch.exists())
        self.assertFalse(self.owner.cleanup(apply=True)["failed"])

    def test_wrong_daemon_and_query_failure_never_delete_scratch(self):
        self.arm()
        self.docker.add(self.owner)
        for failure in ("wrong", "query"):
            self.docker.identity = "wrong" if failure == "wrong" else self.owner.data["daemon"]
            self.docker.error = failure == "query"
            self.assertTrue(self.owner.cleanup(apply=True)["failed"])
            self.assertTrue(self.scratch.exists())
        self.assertEqual(self.docker.mutations, [])

    def test_foreign_labels_abort_whole_scope_before_any_removal(self):
        self.arm()
        self.docker.add(self.owner)
        network = self.docker.add(self.owner, "network")
        self.docker.items["network"][network]["labels"].pop(R.LABEL)
        self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.assertEqual(self.docker.mutations, [])

    def test_preexisting_scope_is_never_claimed(self):
        self.docker.add(self.owner)
        with self.assertRaises(R.Unsafe):
            self.arm()
        self.assertFalse(self.owner.data["armed"])
        self.owner.cleanup(apply=True)
        self.assertEqual(self.docker.mutations, [])

    def test_existing_image_tag_blocks_arming(self):
        self.docker.references[self.owner.data["tag"]] = {"foreign"}
        with self.assertRaises(R.Unsafe):
            self.arm()
        self.assertFalse(self.owner.data["armed"])

    def test_recovery_accepts_recreate_and_legacy_restart_stages(self):
        for stage in ("recreate", "restart"):
            with self.subTest(stage=stage):
                self.owner.stage(stage)
                self.assertEqual(R.read_record(self.owner.path, self.root)["stage"], stage)

    def test_recovery_discovers_uncaptured_recreate_replacement(self):
        self.arm()
        first = self.docker.add(self.owner)
        self.owner.capture()
        self.docker.items["container"].pop(first)
        second = self.docker.add(self.owner, digit="b")
        self.owner.close()
        recovered = R.Run.open(self.owner.path, self.root, apply=True, docker=self.docker)
        self.addCleanup(recovered.close)
        self.assertFalse(recovered.cleanup(apply=True)["failed"])
        self.assertEqual(self.docker.mutations, [("rm", "-f", second)])

    def test_images_with_foreign_tags_digests_or_users_are_retained(self):
        self.arm()
        identity = self.docker.add(self.owner, "image", tags=[self.owner.data["tag"]])
        self.owner.capture()
        item = self.docker.items["image"][identity]
        for condition in ("tag", "digest", "used"):
            item["tags"] = [self.owner.data["tag"], "foreign:tag"] if condition == "tag" else [self.owner.data["tag"]]
            item["digests"] = ["foreign@sha256:abc"] if condition == "digest" else []
            self.docker.busy_images = {identity} if condition == "used" else set()
            result = self.owner.cleanup(apply=True)
            self.assertGreater(len(result["retained"]), 1)
            self.assertEqual(self.docker.mutations, [])

    def test_reused_tag_does_not_remove_replacement(self):
        self.arm()
        self.docker.add(self.owner, "image", tags=[self.owner.data["tag"]])
        self.owner.capture()
        self.docker.references[self.owner.data["tag"]] = {"foreign"}
        self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.assertEqual(self.docker.mutations, [])

    def uid_tag(self):
        candidate = self.scratch / ("starter-lifecycle-" + self.owner.data["run"])
        digest = hashlib.sha256(str(candidate).encode()).hexdigest()
        return f"vsc-{candidate.name}-{digest}-uid:latest"

    def test_local_base_and_uid_digest_references_are_removed_by_exact_tag(self):
        self.arm()
        identities = []
        for digit, tag in zip(("a", "b"), (self.owner.data["tag"], self.uid_tag())):
            identity = self.docker.add(self.owner, "image", digit=digit, tags=[tag])
            self.docker.items["image"][identity]["digests"] = [tag.rsplit(":", 1)[0] + "@" + identity]
            identities.append(identity)
        self.owner.capture()
        before = self.owner.path.read_bytes()
        preview = self.owner.cleanup()
        self.assertFalse(preview["failed"])
        self.assertEqual(len(preview["retained"]), 1)
        self.assertEqual(self.owner.path.read_bytes(), before)
        self.assertEqual(self.docker.mutations, [])
        result = self.owner.cleanup(apply=True)
        self.assertFalse(result["failed"])
        self.assertEqual(len(result["retained"]), 1)
        self.assertCountEqual(self.docker.mutations, [
            ("image", "rm", "--no-prune", self.owner.data["tag"]),
            ("image", "rm", "--no-prune", self.uid_tag()),
        ])
        self.assertTrue(all(identity not in self.docker.items["image"] for identity in identities))
        self.assertFalse(self.owner.cleanup(apply=True)["failed"])
        self.assertEqual(len(self.docker.mutations), 2)

    def test_exact_uid_tag_collision_blocks_arming(self):
        self.docker.references[self.uid_tag()] = {"foreign"}
        with self.assertRaises(R.Unsafe):
            self.arm()
        self.assertFalse(self.owner.data["armed"])
        self.assertEqual(self.docker.mutations, [])

    def test_recorded_prefix_lookalike_and_unrelated_tags_are_not_authority(self):
        self.arm()
        wrong_hash = "vsc-starter-lifecycle-" + self.owner.data["run"] + "-" + "0" * 64 + "-uid:latest"
        for digit, tag in zip(("a", "b", "c"), (self.uid_tag().replace("-uid:", "-extra-uid:"), "foreign:tag", wrong_hash)):
            self.docker.add(self.owner, "image", digit=digit, tags=[tag])
        self.owner.capture()
        result = self.owner.cleanup(apply=True)
        self.assertFalse(result["failed"])
        self.assertEqual(len(result["retained"]), 4)
        self.assertEqual(self.docker.mutations, [])

    def test_uid_foreign_refs_changed_tags_and_container_users_are_retained(self):
        self.arm()
        tag = self.uid_tag()
        identity = self.docker.add(self.owner, "image", tags=[tag])
        self.owner.capture()
        item = self.docker.items["image"][identity]
        for condition in ("registry", "wrong-digest", "extra-tag", "changed-tag", "used"):
            with self.subTest(condition=condition):
                item["tags"] = [tag]
                item["digests"] = [tag.rsplit(":", 1)[0] + "@" + identity]
                self.docker.busy_images = {identity} if condition == "used" else set()
                if condition == "registry":
                    item["digests"] = ["registry.example/" + item["digests"][0]]
                elif condition == "wrong-digest":
                    item["digests"] = [tag.rsplit(":", 1)[0] + "@sha256:" + "f" * 64]
                elif condition == "extra-tag":
                    item["tags"].append("foreign:tag")
                elif condition == "changed-tag":
                    item["tags"] = [self.owner.data["tag"]]
                result = self.owner.cleanup(apply=True)
                self.assertGreater(len(result["retained"]), 1)
                self.assertEqual(self.docker.mutations, [])

    def test_uid_replaced_tag_or_mismatched_labels_fail_closed(self):
        self.arm()
        tag = self.uid_tag()
        identity = self.docker.add(self.owner, "image", tags=[tag])
        self.owner.capture()
        self.docker.references[tag] = {"foreign"}
        self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.docker.references[tag] = {identity}
        self.docker.items["image"][identity]["labels"][R.LABEL] = "foreign"
        self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.assertEqual(self.docker.mutations, [])

    def test_changed_recorded_image_evidence_aborts_before_removal(self):
        self.arm()
        identity = self.docker.add(self.owner, "image", tags=[self.uid_tag()])
        self.owner.capture()
        changed = copy.deepcopy(self.owner.data)
        changed["resources"]["image"][identity]["tags"] = [self.owner.data["tag"]]
        self.owner.path.write_text(json.dumps(changed))
        self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.assertEqual(self.docker.mutations, [])
        self.assertTrue(self.scratch.exists())

    def test_symlink_escape_preserves_primary_files(self):
        self.arm()
        primary = self.root / "precious"
        primary.write_text("preserve")
        moved = self.base / "moved"
        self.scratch.rename(moved)
        self.scratch.symlink_to(self.root, target_is_directory=True)
        self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.assertEqual(primary.read_text(), "preserve")
        self.assertEqual(self.docker.mutations, [])

    def test_malformed_record_never_mutates_resources(self):
        self.arm()
        self.docker.add(self.owner)
        self.owner.path.write_text('{"run":"invalid"}')
        self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.assertEqual(self.docker.mutations, [])
        self.assertEqual(self.owner.path.read_text(), '{"run":"invalid"}')

    def test_root_owned_content_failure_keeps_marker_and_inventory(self):
        self.arm()
        (self.scratch / "state").mkdir()
        with patch.object(R.shutil, "rmtree", side_effect=PermissionError):
            self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.assertEqual((self.scratch / R.MARKER).read_text(), self.owner.data["run"])
        self.assertTrue(self.owner.path.exists())

    def test_active_lease_and_live_producer_refuse_recovery(self):
        with self.assertRaises(R.Unsafe):
            R.Run.open(self.owner.path, self.root, apply=True, docker=self.docker)
        self.owner.data["worker"] = 123
        self.owner.save()
        with patch.object(R.os, "killpg", return_value=None):
            self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.assertEqual(self.docker.mutations, [])

    def test_structured_diagnostics_survive_failure_without_raw_logs(self):
        self.arm()
        self.owner.stage("build", 17)
        (self.scratch / "task.log").write_text("secret Error raw-token --credential private")
        self.assertFalse(self.owner.cleanup(apply=True)["failed"])
        record = self.owner.path.read_text()
        self.assertNotIn("raw-token", record)
        self.assertNotIn("credential", record)
        self.assertEqual(json.loads(record)["exit"], 17)
        self.assertTrue(self.owner.path.exists())
        self.owner.forget()
        self.assertFalse(self.owner.path.exists())

    def test_inspect_query_error_is_not_absence(self):
        docker = R.Docker(self.base / "home")
        with patch.object(docker, "ids", return_value={"a" * 64}), patch.object(R, "command", side_effect=R.Unsafe("query")):
            with self.assertRaises(R.Unsafe):
                docker.inspect("container", "a" * 64)

    def test_common_directory_resolution_supports_worktrees_without_writes(self):
        with patch.object(R, "command", return_value=str(self.store.parent)) as command:
            self.assertEqual(R.registry_path(self.root), self.store)
        self.assertIn("--git-common-dir", command.call_args.args)

    def test_volume_replacement_cannot_reuse_name_and_labels(self):
        self.arm()
        identity = self.docker.add(self.owner, "volume")
        self.owner.capture()
        self.docker.items["volume"][identity]["created"] = "2026-02-01T00:00:00Z"
        self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.assertEqual(self.docker.mutations, [])

    def test_producer_is_registered_before_handshake_and_failure_retains_status(self):
        self.arm()
        process = Mock(pid=123)
        process.wait.return_value = 17
        def release(token):
            self.assertEqual(token, b"x")
            self.assertEqual(json.loads(self.owner.path.read_text())["worker"], 123)
            self.assertEqual(json.loads(self.owner.path.read_text())["producer"], self.anchor())
        process.stdin.write.side_effect = release
        with patch.object(R.subprocess, "Popen", return_value=process):
            with self.assertRaisesRegex(R.Unsafe, r"build failed \(17\)"):
                self.owner.produce(["synthetic", "private-argument"], self.scratch, {}, "build")
        self.assertEqual(self.owner.data["exit"], 17)
        self.assertIsNone(self.owner.data["producer"])
        self.assertNotIn("private-argument", self.owner.path.read_text())

    def test_interrupt_stops_group_before_shared_cleanup(self):
        self.arm()
        process = Mock(pid=123)
        process.poll.return_value = None
        process.wait.side_effect = [KeyboardInterrupt(), 0]
        with patch.object(R.subprocess, "Popen", return_value=process), patch.object(R.os, "killpg") as kill:
            with self.assertRaises(KeyboardInterrupt):
                self.owner.produce(["synthetic"], self.scratch, {}, "up")
        kill.assert_called_once_with(123, R.signal.SIGTERM)
        self.assertEqual(self.owner.data["worker"], 123)
        self.assertTrue(self.owner.path.exists())

    def test_failed_anchor_or_save_never_releases_stopped_worker(self):
        self.arm()
        for failure in ("anchor", "save"):
            with self.subTest(failure=failure):
                process = Mock(pid=123)
                process.poll.return_value = 0
                self.owner.data.update(worker=0, producer=None)
                with patch.object(R.subprocess, "Popen", return_value=process), \
                        patch.object(R.os, "killpg") as signal:
                    if failure == "anchor":
                        with patch.object(R, "producer_identity", side_effect=R.Unsafe("anchor failed")):
                            with self.assertRaises(R.Unsafe):
                                self.owner.produce(["synthetic"], self.scratch, {}, "build")
                    else:
                        original = self.owner.save
                        def save():
                            if self.owner.data["producer"] is not None:
                                raise R.Unsafe("save failed")
                            original()
                        with patch.object(self.owner, "save", side_effect=save):
                            with self.assertRaises(R.Unsafe):
                                self.owner.produce(["synthetic"], self.scratch, {}, "build")
                process.stdin.write.assert_not_called()
                signal.assert_not_called()
                process.stdin.close.assert_called()
                self.assertIsNone(self.owner.data["producer"])

    def test_pid_reuse_never_releases_or_signals_replacement(self):
        self.arm()
        process = Mock(pid=123)
        process.poll.return_value = None
        changed = {**self.anchor(), "start": 101}
        with patch.object(R.subprocess, "Popen", return_value=process), \
                patch.object(R, "producer_identity", side_effect=[self.anchor(), changed, changed]), \
                patch.object(R.os, "killpg") as signal:
            with self.assertRaisesRegex(R.Unsafe, "refusing group signal"):
                self.owner.produce(["synthetic"], self.scratch, {}, "build")
        process.stdin.write.assert_not_called()
        signal.assert_not_called()

    def test_anchor_validation_and_legacy_preview_preserve_evidence(self):
        self.owner.data.update(worker=123, producer=self.anchor())
        for field, value in (("start", True), ("session", 124), ("boot", "invalid"), ("pid", 0)):
            with self.subTest(field=field):
                self.owner.data["producer"] = {**self.anchor(), field: value}
                with self.assertRaises(R.Unsafe):
                    self.owner.save()
        self.owner.data.update(worker=0, producer=None)
        self.owner.data.pop("producer")
        self.owner.save()
        before = self.owner.path.read_bytes()
        recovered = R.Run.open(self.owner.path, self.root, docker=self.docker)
        self.assertFalse(recovered.cleanup()["failed"])
        self.assertEqual(self.owner.path.read_bytes(), before)
        self.assertNotIn("producer", recovered.data)

    def test_missing_marker_or_replaced_directory_refuses_all_deletion(self):
        self.arm()
        self.docker.add(self.owner)
        marker = self.scratch / R.MARKER
        marker.write_text("foreign")
        self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        marker.unlink()
        self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.assertEqual(self.docker.mutations, [])

    def test_deleted_resource_that_still_exists_stops_before_scratch_removal(self):
        self.arm()
        self.docker.add(self.owner)
        with patch.object(FakeDocker, "__call__", return_value=""):
            self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.assertTrue(self.scratch.exists())

    def test_readonly_cli_does_not_create_missing_store_or_contact_docker(self):
        cli = load_script("starter-test-clean")
        missing = self.root / "absent"
        with patch.object(cli, "command", return_value=str(self.root)), \
                patch.object(cli, "registry_path", return_value=missing), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(cli.main([]), 0)
        self.assertFalse(missing.exists())

    def test_cli_requires_explicit_selection_and_apply_for_forget(self):
        cli = load_script("starter-test-clean")
        for args in (["--apply"], ["--forget"], ["--run", "invalid", "--apply"]):
            with contextlib.redirect_stderr(io.StringIO()), patch.object(cli, "command", return_value=str(self.root)), \
                    patch.object(cli, "registry_path", return_value=self.store):
                if "invalid" in args:
                    self.assertEqual(cli.main(args), 1)
                else:
                    with self.assertRaises(SystemExit):
                        cli.main(args)
        self.assertEqual(self.docker.mutations, [])

    def test_cli_preview_then_explicit_apply_and_forget_use_same_engine(self):
        cli = load_script("starter-test-clean")
        self.arm()
        self.docker.add(self.owner)
        self.owner.close()
        before = self.owner.path.read_bytes()
        with patch.object(cli, "command", return_value=str(self.root)), patch.object(cli, "registry_path", return_value=self.store), \
                patch.object(R, "Docker", return_value=self.docker), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(cli.main([]), 0)
            self.assertEqual(self.owner.path.read_bytes(), before)
            self.assertEqual(self.docker.mutations, [])
            self.assertEqual(cli.main(["--run", self.owner.data["run"], "--apply", "--forget"]), 0)
        self.assertFalse(self.owner.path.exists())
        self.assertFalse(self.scratch.exists())

    def test_image_fixture_assertion_failure_retains_evidence(self):
        fixture = load_script("image-contract")
        owner = Mock()
        owner.data = self.owner.data
        owner.docker.return_value = "wrong-assertion"
        owner.cleanup.return_value = {"removed": [], "retained": ["shared cache"], "failed": []}
        with patch.object(fixture.Run, "create", return_value=owner), patch.object(fixture.signal, "signal"), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(fixture.main(self.root, self.base), 1)
        owner.retain.assert_called_once_with()
        owner.cleanup.assert_not_called()
        owner.finish.assert_called_once_with("failed")
        owner.close.assert_called_once()

    def test_adapter_uses_full_ids_minimal_inspection_and_no_environment_dump(self):
        docker = R.Docker(self.base / "home")
        identity = "a" * 64
        labels = self.owner.expected("container")
        with patch.object(R, "command", side_effect=[identity, json.dumps([identity, labels])]) as command:
            self.assertEqual(docker.inspect("container", identity)["labels"], labels)
        self.assertIn("--no-trunc", command.call_args_list[0].args)
        template = command.call_args_list[1].args[-2]
        self.assertNotIn(".Env", template)
        self.assertIn(".Config.Labels", template)

    def test_unfinished_registration_preserves_directory_instead_of_guessing(self):
        self.owner.data["inode"] = None
        self.owner.save()
        self.assertTrue(self.owner.cleanup(apply=True)["failed"])
        self.assertTrue(self.scratch.exists())
        self.assertEqual(self.docker.mutations, [])

    def test_bind_probe_uses_owned_container_and_verifies_bytes_and_removal(self):
        self.arm()
        self.docker.env = {"DOCKER_HOST": R.ENDPOINT}
        identity = "a" * 64
        calls = []

        def produce(argv, cwd, env, stage):
            calls.append(argv)
            self.assertEqual(stage, "prepare")
            self.assertEqual(cwd, self.scratch)
            self.assertIn("--pull=never", argv)
            self.assertIn("none", argv)
            self.assertIn(f"type=bind,source={self.scratch},target=/probe,readonly", argv)
            self.assertEqual(env["DOCKER_HOST"], R.ENDPOINT)
            marker = self.scratch / argv[-1].removeprefix("/probe/")
            self.assertEqual(len(marker.read_bytes()), 64)
            self.assertTrue(json.loads(self.owner.path.read_text())["armed"])
            (self.scratch / "task.log").write_bytes(marker.read_bytes())
            self.docker.add(self.owner)
            self.owner.capture()

        original = self.docker.__call__
        def docker(_fake, *args):
            calls.append(args)
            if args[:2] == ("image", "inspect"):
                return "sha256:" + "b" * 64
            if args[:2] == ("container", "inspect"):
                return json.dumps([identity, "/starter-bind-probe-" + self.owner.data["run"]])
            return original(*args)

        with patch.object(self.owner, "produce", side_effect=produce), patch.object(FakeDocker, "__call__", docker):
            self.owner.probe_bind()
        self.assertEqual(self.docker.mutations, [("rm", "-f", identity)])
        self.assertEqual(list(self.scratch.glob(".bind-probe-*")), [])
        self.assertFalse(any("build" in str(call) for call in calls))

    def test_bind_probe_rejects_matching_labels_with_wrong_or_unverifiable_name(self):
        self.arm()
        self.docker.env = {"DOCKER_HOST": R.ENDPOINT}
        identity = "a" * 64

        def produce(argv, cwd, env, stage):
            marker = self.scratch / argv[-1].removeprefix("/probe/")
            (self.scratch / "task.log").write_bytes(marker.read_bytes())
            self.docker.add(self.owner)
            self.owner.capture()

        for response in (json.dumps([identity, "/foreign"]),
                         json.dumps(["b" * 64, "/starter-bind-probe-" + self.owner.data["run"]]),
                         "", "null"):
            with self.subTest(response=response):
                def docker(_fake, *args):
                    if args[:2] == ("image", "inspect"):
                        return "sha256:" + "b" * 64
                    if args[:2] == ("container", "inspect"):
                        self.assertEqual(args[-1], identity)
                        return response
                    raise AssertionError("probe must not remove an unverified container")

                with patch.object(self.owner, "produce", side_effect=produce), \
                        patch.object(FakeDocker, "__call__", docker):
                    with self.assertRaisesRegex(R.Unsafe, "bind probe container name is unverifiable"):
                        self.owner.probe_bind()
                self.assertIn(identity, self.docker.items["container"])
                self.assertEqual(self.docker.mutations, [])
                self.assertTrue(self.owner.path.exists())
                self.assertEqual(list(self.scratch.glob(".bind-probe-*")), [])

    def test_bind_probe_missing_image_fails_before_container_creation(self):
        self.arm()
        self.docker.env = {"DOCKER_HOST": R.ENDPOINT}
        with patch.object(FakeDocker, "__call__", side_effect=R.Unsafe("cached image unavailable")), \
                patch.object(self.owner, "produce") as produce:
            with self.assertRaises(R.Unsafe):
                self.owner.probe_bind()
        produce.assert_not_called()
        self.assertEqual(self.docker.mutations, [])

    def test_bind_probe_wrong_bytes_and_interrupt_keep_recovery_scope(self):
        self.arm()
        self.docker.env = {"DOCKER_HOST": R.ENDPOINT}
        def image(*args):
            return "sha256:" + "b" * 64
        for failure in ("wrong", "interrupt"):
            with self.subTest(failure=failure):
                def produce(argv, cwd, env, stage):
                    self.docker.add(self.owner)
                    if failure == "interrupt":
                        raise KeyboardInterrupt()
                    (self.scratch / "task.log").write_bytes(b"wrong")
                    self.owner.capture()
                with patch.object(FakeDocker, "__call__", image), patch.object(self.owner, "produce", side_effect=produce):
                    with self.assertRaises(KeyboardInterrupt if failure == "interrupt" else R.Unsafe):
                        self.owner.probe_bind()
                self.assertTrue(self.owner.path.exists())
                self.assertTrue(self.scratch.exists())
                self.assertEqual(self.docker.mutations, [])
                self.assertFalse(self.owner.cleanup(apply=True)["failed"])
                if failure == "wrong":
                    self.owner = R.Run.create(self.root, self.base, self.store, self.docker)
                    self.addCleanup(self.owner.close)
                    self.scratch = Path(self.owner.data["scratch"])
                    self.arm()
                    self.docker.mutations.clear()

    def test_nested_sandbox_symlink_is_unlinked_without_following_primary(self):
        self.arm()
        primary = self.root / "precious"
        primary.write_text("preserve")
        (self.scratch / "foreign-link").symlink_to(self.root, target_is_directory=True)
        self.assertFalse(self.owner.cleanup(apply=True)["failed"])
        self.assertEqual(primary.read_text(), "preserve")


class ProcessIdentityTests(unittest.TestCase):
    def test_linux_stat_parser_pins_start_boot_and_session(self):
        fields = ["S", "1", "123", "123", *(["0"] * 15), "100"]
        raw = ("123 (fixture name with spaces) " + " ".join(fields)).encode()
        with patch.object(R.Path, "stat", return_value=Mock(st_uid=R.os.getuid())), \
                patch.object(R.Path, "open", return_value=io.BytesIO(raw)), \
                patch.object(R.Path, "read_text", return_value="00000000-0000-4000-8000-000000000001\n"):
            self.assertEqual(R.producer_identity(123), {
                "pid": 123, "session": 123, "start": 100, "boot": "00000000-0000-4000-8000-000000000001"})

    def test_dead_malformed_foreign_or_nonleader_process_is_rejected(self):
        for raw in (b"malformed", b"123 (dead) Z 1 123 123", b"x" * 4097):
            with patch.object(R.Path, "stat", return_value=Mock(st_uid=R.os.getuid())), \
                    patch.object(R.Path, "open", return_value=io.BytesIO(raw)):
                with self.assertRaises(R.Unsafe):
                    R.process_status(123)
        with patch.object(R.Path, "stat", return_value=Mock(st_uid=R.os.getuid() + 1)):
            with self.assertRaises(R.Unsafe):
                R.process_status(123)
        with patch.object(R, "process_status", return_value=({"session": 124}, 1, 123)):
            with self.assertRaises(R.Unsafe):
                R.producer_identity(123)


if __name__ == "__main__":
    unittest.main()
