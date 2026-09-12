#!/usr/bin/env python3
"""Isolated contract tests; never start containers or invoke real sudo."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[3]


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


manifest = load_module("manifest", ROOT / ".taskfiles/scripts/compose-manifest.py")
prep = load_module("prep", ROOT / ".taskfiles/scripts/prepare-bind-mounts.py")


class ManifestTests(unittest.TestCase):
    def setUp(self):
        environment = patch.dict(os.environ, {"COMPOSE_PROJECT_NAME": "", "COMPOSE_ENV_FILES": ""})
        environment.start()
        self.addCleanup(environment.stop)
        self.temporary = tempfile.TemporaryDirectory(prefix="compose-unit-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / ".devcontainer").mkdir()
        self.config = self.root / ".devcontainer/devcontainer.json"
        self.config.write_text('{"service":"custom", "dockerComposeFile":["base.yml", /* note */ "extra.yml",]}')
        for name in ("base.yml", "extra.yml"):
            (self.root / ".devcontainer" / name).write_text("services: {}\n")
        self.selected = {"container_name": "fixture", "environment": {"SECRET": "private-fixture-value"},
                         "volumes": [self.bind(str(self.root / ".env.d/state"), "/home/ubuntu/.pi"),
                                     self.bind("/host/session/agent.sock", "/ssh-agent")]}

    @staticmethod
    def bind(source, target):
        return {"type": "bind", "source": source, "target": target,
                "bind": {"create_host_path": False}}

    def projection(self):
        return manifest.project_manifest(self.root, *manifest.selection(self.root), self.selected)

    def publish(self):
        value = self.projection()
        (self.root / manifest.MANIFEST).write_text(json.dumps(value))
        return value

    def test_selection_preserves_order_and_jsonc_strings(self):
        service, files, _ = manifest.selection(self.root)
        self.assertEqual(service, "custom")
        self.assertEqual([path.name for path in files], ["base.yml", "extra.yml"])
        self.config.write_text('{"service":"http://service", "dockerComposeFile":"base.yml"}')
        self.assertEqual(manifest.selection(self.root)[0], "http://service")

    def test_compose_owns_resolution_order_and_output_is_never_written(self):
        result = subprocess.CompletedProcess([], 0, json.dumps({"services": {"custom": self.selected}}).encode(), b"")
        with patch.object(manifest.subprocess, "run", return_value=result) as execute:
            model = manifest.compose_model(self.root)
        command = execute.call_args.args[0]
        self.assertEqual(command[-3:], ["config", "--format", "json"])
        self.assertLess(command.index(str(self.root / ".devcontainer/base.yml")),
                        command.index(str(self.root / ".devcontainer/extra.yml")))
        self.assertEqual(model[3], self.selected)
        self.assertFalse((self.root / manifest.MANIFEST).exists())

    def test_task_up_prepares_after_env_and_passes_creation_identity(self):
        scripts = self.root / ".taskfiles/scripts"
        scripts.mkdir(parents=True)
        for name in ("compose-manifest.py", "prepare-bind-mounts.py", "prepare-bind-mounts.sh",
                     "project-identity.sh", "yq-compatibility.sh"):
            shutil.copy2(ROOT / ".taskfiles/scripts" / name, scripts / name)
        shutil.copy2(ROOT / ".taskfiles/devcontainer.yml", self.root / ".taskfiles/devcontainer.yml")
        (self.root / "Taskfile.yml").write_text('version: "3"\nincludes:\n  container: .taskfiles/devcontainer.yml\n')
        (self.root / ".devcontainer/base.yml").write_text('''services:
  custom:
    image: fixture:local
    container_name: fixture
    volumes:
      - type: bind
        source: ../.env.d/${COMPOSE_PROJECT_NAME}/${FIXTURE_STATE:?Missing fixture env}
        target: /state
        bind: {create_host_path: false}
''')
        (self.root / ".devcontainer/.env").write_text("FIXTURE_STATE=prepared\nCOMPOSE_PROJECT_NAME=fixture-project\n")
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        docker = shutil.which("docker")
        (bin_dir / "docker").write_text(f'''#!/bin/bash
if [ "$1" = compose ]; then exec "{docker}" "$@"; fi
if [ "$1 $2" = 'container ls' ]; then exit 0; fi
exit 97
''')
        (bin_dir / "devcontainer").write_text('''#!/bin/bash
[ "$COMPOSE_PROJECT_NAME" = fixture-project ] || exit 96
if [ "$1" = build ]; then exit 0; fi
[ "$1" = up ] || exit 97
[ -d .env.d/fixture-project/prepared ] || exit 98
# Reproduce the creation config invocation verified in CLI 0.89.0 source, not up.
docker compose --project-name "$COMPOSE_PROJECT_NAME" -f .devcontainer/base.yml -f .devcontainer/extra.yml config --format json |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["services"]["custom"]["volumes"][0]["source"])' >creation-source
printf '%s' "$GENTLE_VOLUME_MANIFEST_ID" >creation-identity
''')
        for command in bin_dir.iterdir():
            command.chmod(0o755)
        environment = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}", "FORCE_HOST_CONTEXT": "1",
                       "PYTHONDONTWRITEBYTECODE": "1"}
        result = subprocess.run(["task", "container:up"], cwd=self.root, env=environment, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        value = manifest.load_manifest(self.root)
        self.assertEqual((self.root / "creation-identity").read_text(), value["id"])
        self.assertEqual((self.root / "creation-source").read_text().strip(),
                         str(self.root / ".env.d/fixture-project/prepared"))
        self.assertEqual(value["project_name_fingerprint"], manifest.digest("fixture-project"))
        result = subprocess.run(["task", "container:build"], cwd=self.root, env=environment, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        result = subprocess.run(["task", "--silent", "container:resolve-container-name"], cwd=self.root,
                                env=environment, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "fixture")
        self.assertIn(f"HOST_UID={os.getuid()}\n", (self.root / ".devcontainer/.env").read_text())
        if Path("/.dockerenv").exists():
            before = (self.root / ".devcontainer/.env").read_bytes()
            environment.pop("FORCE_HOST_CONTEXT")
            result = subprocess.run(["task", "container:up"], cwd=self.root, env=environment, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((self.root / ".devcontainer/.env").read_bytes(), before)

    def test_projection_minimizes_and_tracks_host_volume_interpolation(self):
        value = self.projection()
        serialized = json.dumps(value)
        self.assertNotIn("private-fixture-value", serialized)
        self.assertNotIn("/host/session/agent.sock", serialized)
        self.assertNotIn(str(self.root), serialized)
        self.assertEqual(value["volumes"][0]["source"], ".env.d/state")
        self.selected["volumes"][1]["source"] = "/host/other/agent.sock"
        self.assertNotEqual(value["id"], self.projection()["id"])

    def test_missing_malformed_and_stale_fail(self):
        with self.assertRaises(FileNotFoundError):
            manifest.load_manifest(self.root)
        path = self.root / manifest.MANIFEST
        path.write_text("{}")
        with self.assertRaises(ValueError):
            manifest.load_manifest(self.root)
        self.publish()
        (self.root / ".devcontainer/extra.yml").write_text("# changed\n")
        with self.assertRaisesRegex(ValueError, "Stale"):
            manifest.load_manifest(self.root)

    def test_runtime_rejects_desired_only_and_ignores_host_shell_differences(self):
        value = self.publish()
        with patch.dict(os.environ, {"GENTLE_VOLUME_MANIFEST_ID": "old"}):
            with self.assertRaisesRegex(ValueError, "not applied"):
                manifest.load_manifest(self.root, runtime=True)
        with patch.dict(os.environ, {"GENTLE_VOLUME_MANIFEST_ID": value["id"],
                                     "HOME": "/container/home", "SSH_AUTH_SOCK": "/ssh-agent"}):
            self.assertEqual(manifest.load_manifest(self.root, runtime=True), value)

    def test_preparation_is_atomic_and_preserves_data(self):
        old = self.publish()
        state = self.root / ".env.d/state"
        state.mkdir(parents=True)
        state.chmod(0o700)
        (state / "sentinel").write_text("preserve")
        self.selected["volumes"][0]["source"] = str(self.root / ".env.d/new")
        resolved = (*manifest.selection(self.root), self.selected, "fixture-project")
        with patch.object(manifest, "compose_model", return_value=resolved), \
                patch.object(manifest, "check_existing_container"), contextlib.redirect_stdout(io.StringIO()):
            manifest.prepare(self.root)
        self.assertEqual((state / "sentinel").read_text(), "preserve")
        self.assertEqual(state.stat().st_mode & 0o777, 0o700)
        self.assertEqual((self.root / ".env.d/new").stat().st_mode & 0o777, 0o755)
        published = (self.root / manifest.MANIFEST).read_bytes()
        self.assertNotEqual(json.loads(published)["id"], old["id"])
        with patch.object(manifest, "compose_model", side_effect=ValueError("failed")):
            with self.assertRaises(ValueError):
                manifest.prepare(self.root)
        self.assertEqual((self.root / manifest.MANIFEST).read_bytes(), published)

    def test_unapplied_existing_container_fails_before_preparation(self):
        listing = subprocess.CompletedProcess([], 0, "fixture\n", "")
        inspect = subprocess.CompletedProcess([], 0, b'[{"Config":{"Env":["SECRET=fixture"]}}]', b"")
        with patch.object(manifest.subprocess, "run", side_effect=[listing, inspect]):
            with self.assertRaisesRegex(ValueError, "recreate"):
                manifest.check_existing_container("fixture", "desired")
        self.assertFalse((self.root / ".env.d").exists())

    def test_external_sources_are_never_prepared(self):
        with contextlib.redirect_stdout(io.StringIO()):
            paths = list(prep.managed_bind_sources(self.projection()["volumes"], str(self.root)))
        self.assertEqual(paths, [str(self.root / ".env.d/state")])

    def test_symlink_file_and_wrong_owner_fail_without_sudo(self):
        target = self.root / "file"
        target.write_text("keep")
        link = self.root / "link"
        link.symlink_to(target)
        for path in (target, link):
            with self.assertRaises(SystemExit):
                prep.prepare_directory(str(path), (os.getuid(), os.getgid()))
        directory = self.root / "directory"
        directory.mkdir()
        with self.assertRaisesRegex(SystemExit, "wrong owner"):
            prep.prepare_directory(str(directory), (os.getuid() + 1, os.getgid()))
        self.assertEqual(target.read_text(), "keep")

    def test_unsafe_bind_and_empty_service_fail(self):
        self.selected["volumes"][0]["bind"]["create_host_path"] = True
        with self.assertRaises(ValueError):
            self.projection()
        self.selected["volumes"] = []
        with self.assertRaises(ValueError):
            self.projection()

    def test_runtime_dispatch_is_checked_and_activation_is_canonical(self):
        for relative in (".devcontainer/lifecycle", ".devcontainer/install/available",
                         ".devcontainer/install/02-enabled", ".taskfiles/scripts"):
            (self.root / relative).mkdir(parents=True, exist_ok=True)
        for relative in (".devcontainer/lifecycle/setup-volumes.sh",
                         ".devcontainer/lifecycle/compose-volume-records.py",
                         ".taskfiles/scripts/compose-manifest.py"):
            shutil.copy2(ROOT / relative, self.root / relative)
        installer = self.root / ".devcontainer/install/available/30-ai-pi-gentle.sh"
        installer.write_text('#!/bin/bash\nprintf repaired >"$WORKSPACE_DIR/calls"\n')
        link = self.root / ".devcontainer/install/02-enabled/47-custom.sh"
        link.symlink_to("../available/30-ai-pi-gentle.sh")
        value = self.publish()
        environment = {**os.environ, "WORKSPACE_DIR": str(self.root), "GENTLE_VOLUME_MANIFEST_ID": "old"}
        command = ["bash", "-c", 'source "$WORKSPACE_DIR/.devcontainer/lifecycle/setup-volumes.sh"; repair_installed_volumes']
        result = subprocess.run(command, env=environment, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "calls").exists())
        environment["GENTLE_VOLUME_MANIFEST_ID"] = value["id"]
        result = subprocess.run(command, env=environment, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "calls").read_text(), "repaired")
        (self.root / "calls").unlink()
        link.unlink()
        result = subprocess.run(command, env=environment, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "calls").exists())

    def test_pi_seeding_is_gated_and_preserves_existing_state(self):
        source = (ROOT / ".devcontainer/setup.sh").read_text()
        function = source[source.index("setup_versioned_configs() {"):source.index("\nsetup_pi_workspace_trust()")]
        command = ('install_script_is_enabled() { [[ "$1" == *30-ai-gentle-ai.sh ]]; }; '
                   'seed_config_tree() { printf unexpected; }; ' + function + '\nsetup_versioned_configs')
        result = subprocess.run(["bash", "-c", command], env={**os.environ, "SCRIPT_DIR": str(self.root),
                                "WORKSPACE_DIR": str(self.root)}, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_server_requires_both_enabled_installer_and_persisted_override(self):
        installer = self.root / ".devcontainer/install/available/20-tool-ssh-server.sh"
        installer.parent.mkdir(parents=True)
        installer.write_text("# fixture\n")
        enabled = self.root / ".devcontainer/install/02-enabled"
        enabled.mkdir()
        server = self.root / ".devcontainer/docker-compose.ssh-server.yml"
        server.write_text("# fixture override\n")
        self.selected["volumes"] = [self.bind(str(self.root / ".env.d/.ssh-server"), "/home/ubuntu/.ssh-server")]
        self.config.write_text('{"service":"custom","dockerComposeFile":["base.yml","docker-compose.ssh-server.yml"]}')
        value = self.publish()
        with patch.dict(os.environ, {"GENTLE_VOLUME_MANIFEST_ID": value["id"]}), \
                patch.object(manifest.sys, "argv", ["manifest", "ssh-server", str(self.root)]):
            with self.assertRaisesRegex(ValueError, "disabled"):
                manifest.main()
            (enabled / "29-custom.sh").symlink_to("../available/20-tool-ssh-server.sh")
            with contextlib.redirect_stdout(io.StringIO()):
                manifest.main()
            self.config.write_text('{"service":"custom","dockerComposeFile":"base.yml"}')
            value = self.publish()
            with patch.dict(os.environ, {"GENTLE_VOLUME_MANIFEST_ID": value["id"]}):
                with self.assertRaisesRegex(ValueError, "persisted-key override"):
                    manifest.main()

    def test_optional_installers_are_downstream_and_do_not_install_each_other(self):
        available = ROOT / ".devcontainer/install/available"
        for name in ("20-tool-ssh-server.sh", "20-tool-pulseaudio-utils.sh", "30-ai-pi-coding.sh", "30-ai-pi-gentle.sh"):
            self.assertTrue((available / name).is_file())
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        calls = self.root / "package-calls"
        (bin_dir / "apt-get").write_text('#!/bin/bash\nprintf "%s\\n" "$*" >>"$CALLS"\n')
        (bin_dir / "sudo").write_text('#!/bin/bash\n[ "$1" = apt-get ] || exit 97\nexec "$@"\n')
        for command in bin_dir.iterdir():
            command.chmod(0o755)
        environment = {**os.environ, "PATH": f"{bin_dir}:/usr/bin:/bin", "CALLS": str(calls),
                       "DEVCONTAINER_PHASE": "build"}
        for script, package in (("20-tool-ssh.sh", "openssh-client"),
                                ("20-tool-ssh-server.sh", "openssh-server"),
                                ("20-tool-pulseaudio-utils.sh", "pulseaudio-utils")):
            calls.write_text("")
            result = subprocess.run(["bash", str(available / script)], env=environment, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(calls.read_text().splitlines(), ["update -qq", f"install -y -qq {package}"])

    def test_real_repository_overrides_are_independent(self):
        # Copy only public Compose/JSONC files; never read the real .env or state.
        for source in (ROOT / ".devcontainer").glob("docker-compose*.yml"):
            shutil.copy2(source, self.root / ".devcontainer" / source.name)
        (self.root / ".env").write_text("")
        environment = {"APP_NAME": "fixture", "APP_PORT": "12340", "OPENCODE_PORT": "12341",
                       "SSH_PORT": "12342", "HOST_UID": "1234", "SSH_AUTH_SOCK": "/fixture/agent.sock",
                       "GENTLE_VOLUME_MANIFEST_ID": "fixture-creation-identity"}
        for optional, expected in ((None, None), ("pi", "/home/ubuntu/.pi"),
                                   ("ssh-agent", "/ssh-agent"), ("ssh-server", "/home/ubuntu/.ssh-server"),
                                   ("audio", "/pulse-native")):
            files = ["docker-compose.yml"]
            if optional:
                files.append(f"docker-compose.{optional}.yml")
            self.config.write_text(json.dumps({"service": "container-svc", "dockerComposeFile": files}))
            with patch.dict(os.environ, environment):
                selected = manifest.compose_model(self.root)[3]
            targets = {volume["target"] for volume in selected["volumes"]}
            optional_targets = targets & {"/home/ubuntu/.pi", "/ssh-agent", "/home/ubuntu/.ssh-server", "/pulse-native"}
            self.assertEqual(optional_targets, {expected} if expected else set())
            self.assertEqual(len(selected["ports"]), 3 if optional == "ssh-server" else 2)
            self.assertEqual(selected["environment"]["GENTLE_VOLUME_MANIFEST_ID"], "fixture-creation-identity")
            if optional == "audio":
                self.assertEqual(selected["environment"]["PULSE_SERVER"], "unix:/pulse-native")
                audio = next(volume for volume in selected["volumes"] if volume["target"] == expected)
                self.assertTrue(audio["read_only"])
                self.assertEqual(audio["source"], "/run/user/1234/pulse/native")
            if optional == "ssh-agent":
                self.assertEqual(selected["environment"]["SSH_AUTH_SOCK"], "/ssh-agent")
            manifest.project_manifest(self.root, *manifest.selection(self.root), selected)

    def test_audio_stays_outside_dind_tmp_and_is_never_managed(self):
        config = (ROOT / ".devcontainer/devcontainer.json").read_text()
        self.assertRegex(config, r'(?m)^\s*"ghcr.io/devcontainers/features/docker-in-docker:3":\s*\{\}')
        selected = manifest.read_compose_fragment(
            ROOT / ".devcontainer/docker-compose.audio.yml")["services"]["container-svc"]
        self.assertEqual(len(selected["volumes"]), 1)
        audio = selected["volumes"][0]
        # DinD's startup tmpfs over /tmp must not hide the socket bind.
        self.assertNotIn(Path("/tmp"), (Path(audio["target"]), *Path(audio["target"]).parents))
        self.assertEqual(audio["target"], "/pulse-native")
        self.assertEqual(selected["environment"]["PULSE_SERVER"], f'unix:{audio["target"]}')
        self.assertEqual(audio["source"], "/run/user/${HOST_UID:?Missing HOST_UID}/pulse/native")
        self.assertEqual(audio["type"], "bind")
        self.assertIs(audio["read_only"], True)
        self.assertIs(audio["bind"]["create_host_path"], False)
        audio["source"] = "/run/user/1234/pulse/native"
        projected = manifest.project_manifest(self.root, *manifest.selection(self.root), selected)
        record, = projected["volumes"]
        self.assertEqual(record["source"], "external")
        self.assertIs(record["managed"], False)
        with contextlib.redirect_stdout(io.StringIO()):
            for volumes in (selected["volumes"], projected["volumes"]):
                self.assertEqual(list(prep.managed_bind_sources(volumes, str(self.root))), [])
        self.assertFalse((self.root / ".env.d").exists())

    def test_real_compose_merge_and_interpolation_in_isolated_fixture(self):
        version = subprocess.run(["docker", "compose", "version"], capture_output=True)
        if version.returncode:
            self.skipTest("Docker Compose CLI unavailable")
        (self.root / ".devcontainer/base.yml").write_text('''services:
  custom:
    image: fixture:local
    container_name: fixture
    volumes:
      - type: bind
        source: ../.env.d/original
        target: /state
        bind: {create_host_path: false}
''')
        (self.root / ".devcontainer/extra.yml").write_text('''services:
  custom:
    volumes:
      - type: bind
        source: ${FIXTURE_BIND:?Missing FIXTURE_BIND}
        target: /state
        read_only: true
        bind: {create_host_path: false}
''')
        with patch.dict(os.environ, {"FIXTURE_BIND": "../.env.d/replacement"}):
            selected = manifest.compose_model(self.root)[3]
        self.assertEqual(len(selected["volumes"]), 1)
        self.assertEqual(selected["volumes"][0]["source"], str(self.root / ".env.d/replacement"))
        self.assertTrue(selected["volumes"][0]["read_only"])
        self.assertIs(selected["volumes"][0].get("bind", {}).get("create_host_path", False), False)
        self.assertFalse((self.root / ".env.d").exists())

    def test_transitive_compose_inputs_are_rejected_before_publication(self):
        previous = self.publish()
        shared = self.root / ".devcontainer/shared.yml"
        variants = (
            'services: {custom: {extends: {file: shared.yml, service: shared}}}\n',
            '"include": [shared.yml]\n',
            'x-base: &base {extends: {file: shared.yml, service: shared}}\nservices: {custom: *base}\n',
            'services: {custom: {extends: shared}}\n',
        )
        for source in variants:
            (self.root / ".devcontainer/base.yml").write_text(source)
            for state in ("before", "after"):
                shared.write_text(f'services: {{shared: {{volumes: ["../.env.d/{state}:/state"]}}}}\n')
                with self.subTest(source=source, state=state), patch.object(manifest, "check_existing_container") as check:
                    with self.assertRaisesRegex(ValueError, "include and extends are unsupported"):
                        manifest.prepare(self.root)
                    check.assert_not_called()
            self.assertEqual(json.loads((self.root / manifest.MANIFEST).read_text()), previous)
        self.assertFalse((self.root / ".env.d").exists())

    def test_default_env_changes_and_legacy_manifests_cannot_bypass_freshness(self):
        for relative in (".env", ".devcontainer/.env"):
            path = self.root / relative
            for content in ("FIXTURE_BIND=before\n", "FIXTURE_BIND=after\n", None):
                self.publish()
                if content is None:
                    path.unlink()
                else:
                    path.write_text(content)
                with self.assertRaisesRegex(ValueError, "Stale"):
                    manifest.load_manifest(self.root)
        legacy = self.projection()
        legacy["schema"] = 1
        legacy["id"] = manifest.digest({key: value for key, value in legacy.items() if key != "id"})
        (self.root / manifest.MANIFEST).write_text(json.dumps(legacy))
        with self.assertRaisesRegex(ValueError, "Unsupported"):
            manifest.load_manifest(self.root)

    def test_alternate_interpolation_env_files_are_rejected(self):
        with patch.dict(os.environ, {"COMPOSE_ENV_FILES": "shared.env"}):
            with self.assertRaisesRegex(ValueError, "COMPOSE_ENV_FILES"):
                manifest.compose_model(self.root)
        (self.root / ".env").write_text("COMPOSE_ENV_FILES=shared.env\n")
        with self.assertRaisesRegex(ValueError, "COMPOSE_ENV_FILES"):
            manifest.compose_model(self.root)

    def test_real_compose_project_authority_and_fingerprint(self):
        base = '''services:
  custom:
    image: fixture:local
    container_name: literal-container
    volumes:
      - type: bind
        source: ../.env.d/${COMPOSE_PROJECT_NAME}
        target: /state
        bind: {create_host_path: false}
'''
        (self.root / ".devcontainer/base.yml").write_text(base)
        for top_name, environment_name, expected in (
            (None, "", self.root.name + "_devcontainer"),
            ("literal-project", "", "literal-project"),
            ("literal-project", "host-project", "host-project"),
            ("devcontainer", "", "devcontainer"),
        ):
            (self.root / ".devcontainer/extra.yml").write_text(f"name: {top_name}\n" if top_name else "services: {}\n")
            with self.subTest(project=expected), patch.dict(os.environ, {"COMPOSE_PROJECT_NAME": environment_name}):
                resolved = manifest.compose_model(self.root)
                self.assertEqual(resolved[4], expected)
                self.assertEqual(resolved[3]["container_name"], "literal-container")
                self.assertEqual(resolved[3]["volumes"][0]["source"], str(self.root / ".env.d" / expected))
                value = manifest.project_manifest(self.root, *resolved)
                self.assertEqual(value["project_name_fingerprint"], manifest.digest(expected))
        service, paths, inputs = manifest.selection(self.root)
        first = manifest.project_manifest(self.root, service, paths, inputs, self.selected, "one")
        second = manifest.project_manifest(self.root, service, paths, inputs, self.selected, "two")
        self.assertNotEqual(first["id"], second["id"])
        (self.root / ".devcontainer/extra.yml").write_text('name: ${PROJECT}\n')
        with self.assertRaisesRegex(ValueError, "top-level name must be literal"):
            manifest.compose_model(self.root)

    def test_optional_guide_migration_without_identity_removal(self):
        source_dir = self.root / "docs/en"
        source_dir.mkdir(parents=True)
        for name in ("extending.md", "install-tree.md", "install-volumes.md", "configs.md", "optional-integrations.md"):
            shutil.copy2(ROOT / "docs/en" / name, source_dir / name)
        readme = self.root / ".devcontainer/README.md"
        shutil.copy2(ROOT / ".devcontainer/README.md", readme)
        original = (source_dir / "optional-integrations.md").read_bytes()
        result = subprocess.run(["bash", "-euc", 'source "$1"; clean_migrate_devcontainer_docs',
                                 "migration-fixture", str(ROOT / ".taskfiles/scripts/clean-lib.sh")],
                                cwd=self.root, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        target = self.root / ".devcontainer/docs"
        self.assertEqual((target / "optional-integrations.md").read_bytes(), original)
        self.assertEqual((source_dir / "optional-integrations.md").read_bytes(), original)
        self.assertIn("./docs/optional-integrations.md", readme.read_text())
        self.assertNotIn("../docs/en/optional-integrations.md", readme.read_text())
        self.assertIn("./optional-integrations.md", (target / "README.md").read_text())
        self.assertIn("./optional-integrations.md", (target / "install-volumes.md").read_text())


if __name__ == "__main__":
    unittest.main()
