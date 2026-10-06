#!/usr/bin/env python3
"""Isolated contract tests; never start containers or invoke real sudo."""
import contextlib
import copy
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


class ManifestFixture(unittest.TestCase):
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
        return manifest.project_manifest(self.root, *manifest.selection(self.root)[:2], self.selected)

    def publish(self):
        value = self.projection()
        (self.root / manifest.MANIFEST).write_text(json.dumps(value))
        return value


class ManifestTests(ManifestFixture):
    def test_agent_override_static_independence(self):
        selected = manifest.read_compose_fragment(
            ROOT / ".devcontainer/config/compose/docker-compose.ssh-agent.yml")["services"]["container-svc"]
        self.assertEqual(selected["environment"], {"SSH_AUTH_SOCK": "/ssh-agent"})
        self.assertEqual(set(selected), {"environment", "volumes"})
        self.assertEqual(selected["volumes"], [
            self.bind("${SSH_AUTH_SOCK:?Missing SSH_AUTH_SOCK}", "/ssh-agent"),
            self.bind("../.env.d/.ssh", "/home/ubuntu/.ssh")])

    def test_connect_agent_applied_snapshot_only(self):
        self.selected["volumes"][0] = self.bind(str(self.root / ".env.d/.ssh"), "/home/ubuntu/.ssh")
        value = self.projection()
        value["files"].append(".devcontainer/config/compose/docker-compose.ssh-agent.yml")
        value["id"] = manifest.digest({key: value[key] for key in manifest.IDENTITY_FIELDS})
        value["snapshot_digest"] = manifest.digest({key: item for key, item in value.items()
                                                     if key != "snapshot_digest"})
        (self.root / manifest.MANIFEST).write_text(json.dumps(value))
        with patch.object(manifest.sys, "argv", ["manifest", "ssh-agent", str(self.root)]), \
                patch.object(manifest.subprocess, "run", side_effect=AssertionError("external command")), \
                patch.object(manifest, "selection", side_effect=AssertionError("live selection")):
            with patch.dict(os.environ, {"DEVCONTAINER_BIND_MANIFEST_ID": "old"}):
                with self.assertRaisesRegex(ValueError, "not applied"):
                    manifest.main()
            with patch.dict(os.environ, {"DEVCONTAINER_BIND_MANIFEST_ID": value["id"]}):
                manifest.main()
        for change in ("selection", "readonly", "source", "agent"):
            invalid = copy.deepcopy(value)
            if change == "selection":
                invalid["files"].pop()
            elif change == "agent":
                invalid["volumes"] = [record for record in invalid["volumes"] if record["target"] != "/ssh-agent"]
            else:
                state = next(record for record in invalid["volumes"] if record["target"] == "/home/ubuntu/.ssh")
                state["read_only" if change == "readonly" else "source"] = True if change == "readonly" else ".env.d/other"
            with self.subTest(change=change), self.assertRaises(ValueError):
                manifest.check_ssh_agent(invalid)

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
                     "project-identity.sh", "locale-env.py", "yq-compatibility.sh"):
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
printf '%s' "$DEVCONTAINER_BIND_MANIFEST_ID" >creation-identity
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

    def test_missing_malformed_fail_and_comments_preserve_snapshot(self):
        with self.assertRaises(FileNotFoundError):
            manifest.load_manifest(self.root)
        path = self.root / manifest.MANIFEST
        path.write_text("{}")
        with self.assertRaises(ValueError):
            manifest.load_manifest(self.root)
        value = self.publish()
        (self.root / ".devcontainer/extra.yml").write_text("# changed\n")
        self.assertEqual(manifest.load_manifest(self.root), value)

    def test_runtime_rejects_desired_only_and_ignores_host_shell_differences(self):
        value = self.publish()
        with patch.dict(os.environ, {"DEVCONTAINER_BIND_MANIFEST_ID": "old"}):
            with self.assertRaisesRegex(ValueError, "not applied"):
                manifest.load_manifest(self.root, runtime=True)
        with patch.dict(os.environ, {"DEVCONTAINER_BIND_MANIFEST_ID": value["id"],
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
            with self.assertRaisesRegex(ValueError, "task container:recreate"):
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
                         ".devcontainer/install/03-enabled", ".devcontainer/install/lib", ".taskfiles/scripts"):
            (self.root / relative).mkdir(parents=True, exist_ok=True)
        for relative in (".devcontainer/lifecycle/setup-volumes.sh",
                          ".devcontainer/install/lib/activation.sh",
                          ".devcontainer/install/lib/selection.py",
                         ".devcontainer/lifecycle/compose-volume-records.py",
                         ".taskfiles/scripts/compose-manifest.py"):
            shutil.copy2(ROOT / relative, self.root / relative)
        installer = self.root / ".devcontainer/install/available/3010-ai-engram.sh"
        installer.write_text('#!/bin/bash\nprintf repaired >"$WORKSPACE_DIR/calls"\n')
        link = self.root / ".devcontainer/install/03-enabled/47-custom.sh"
        link.symlink_to("../available/3010-ai-engram.sh")
        (self.root / ".devcontainer/install/02-core-tools").mkdir()
        (self.root / ".devcontainer/install/dependencies.conf").write_text("")
        (self.root / ".devcontainer/Dockerfile").write_text("FROM fixture AS core-tools\nCOPY install/02-core-tools/ /tmp/\n")
        self.selected["volumes"] = [self.bind(str(self.root / ".env.d/.engram"), "/home/ubuntu/.engram")]
        value = self.publish()
        environment = {**os.environ, "WORKSPACE_DIR": str(self.root), "DEVCONTAINER_BIND_MANIFEST_ID": "old"}
        command = ["bash", "-c", 'source "$WORKSPACE_DIR/.devcontainer/lifecycle/setup-volumes.sh"; repair_installed_volumes']
        result = subprocess.run(command, env=environment, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "calls").exists())
        environment["DEVCONTAINER_BIND_MANIFEST_ID"] = value["id"]
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
        command = ('install_script_is_enabled() { [[ "$1" == *3020-ai-gentle-ai.sh ]]; }; '
                   'seed_config_tree() { printf unexpected; }; ' + function + '\nsetup_versioned_configs')
        result = subprocess.run(["bash", "-c", command], env={**os.environ, "SCRIPT_DIR": str(self.root),
                                "WORKSPACE_DIR": str(self.root)}, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_core_config_seeding_copies_missing_files_without_pi_or_user_overwrite(self):
        install = self.root / ".devcontainer/install"
        for name in ("available", "02-core-tools", "03-enabled"):
            (install / name).mkdir(parents=True)
        for name in ("3000-ai-opencode.sh", "3020-ai-gentle-ai.sh"):
            (install / "available" / name).write_text("# Never executed\n")
            (install / "02-core-tools" / name).symlink_to("../available/" + name)
        baseline = self.root / ".devcontainer/config/opencode"
        (baseline / "nested").mkdir(parents=True)
        (baseline / "nested/agent.md").write_text("baseline\n")
        (baseline / "opencode.json").write_text("baseline config\n")
        home = self.root / "home"
        target = home / ".config/opencode"
        target.mkdir(parents=True)
        (target / "opencode.json").write_text("user config\n")
        source = (ROOT / ".devcontainer/setup.sh").read_text()
        seed = source[source.index("seed_config_tree() {"):source.index("\nrepair_user_local_parents()")]
        setup = source[source.index("setup_versioned_configs() {"):source.index("\nsetup_pi_workspace_trust()")]
        command = ('source "$1"; install_script_is_enabled() { '
                   'devcontainer_install_is_active "$SCRIPT_DIR/install" "$1"; }; '
                   + seed + setup + '\nsetup_versioned_configs\nsetup_versioned_configs')
        result = subprocess.run(["bash", "-eu", "-c", command, "_",
                                 str(ROOT / ".devcontainer/install/lib/activation.sh")],
                                env={**os.environ, "HOME": str(home), "SCRIPT_DIR": str(self.root / ".devcontainer"),
                                     "WORKSPACE_DIR": str(self.root)}, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((target / "nested/agent.md").read_text(), "baseline\n")
        self.assertFalse((target / "nested/agent.md").is_symlink())
        self.assertEqual((target / "opencode.json").read_text(), "user config\n")
        self.assertFalse((home / ".pi").exists())

    def test_base_pi_and_core_gentle_seed_only_base_preferences_and_preserve_trust(self):
        source = (ROOT / ".devcontainer/setup.sh").read_text()
        seed = source[source.index("seed_config_tree() {"):source.index("\nrepair_user_local_parents()")]
        setup = source[source.index("setup_versioned_configs() {"):source.index("\nsetup_pi_workspace_trust()")]
        trust = source[source.index("setup_pi_workspace_trust() {"):source.index("\n# Setup git files configurations")]
        baseline = self.root / ".devcontainer/config/pi/agent"
        shutil.copytree(ROOT / ".devcontainer/config/pi/agent", baseline)
        settings = json.loads((baseline / "settings.json").read_text())
        self.assertEqual(settings["defaultModel"], "gpt-5.6-sol")
        self.assertEqual(settings["defaultProvider"], "openai-codex")
        self.assertEqual(settings["defaultThinkingLevel"], "low")
        self.assertFalse(set(settings) & {"packages", "hud", "subagents", "theme", "powerline"})
        home = self.root / "home"
        agent = home / ".pi/agent"
        agent.mkdir(parents=True)
        (agent / "trust.json").write_text('{"/existing": true}')
        command = ('install_script_is_enabled() { [[ "$1" == *3030-ai-pi-coding.sh || '
                   '"$1" == *3020-ai-gentle-ai.sh ]]; }; ' + seed + setup + trust +
                   '\nsetup_versioned_configs\nsetup_pi_workspace_trust\nsetup_versioned_configs')
        result = subprocess.run(["bash", "-eu", "-c", command],
                                env={**os.environ, "HOME": str(home), "WORKSPACE_DIR": str(self.root),
                                     "SCRIPT_DIR": str(self.root / ".devcontainer")}, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((agent / "settings.json").read_bytes(), (baseline / "settings.json").read_bytes())
        self.assertFalse((home / ".pi/gentle-ai").exists())
        self.assertFalse((agent / "mcp.json").exists())
        self.assertFalse((agent / "subagents.json").exists())
        trusted = json.loads((agent / "trust.json").read_text())
        self.assertTrue(trusted["/existing"])
        self.assertTrue(trusted[str(self.root)])
        self.assertTrue(trusted["/home/ubuntu/code"])
        (agent / "settings.json").write_text('{"defaultModel":"user-preference"}')
        result = subprocess.run(["bash", "-eu", "-c", command],
                                env={**os.environ, "HOME": str(home), "WORKSPACE_DIR": str(self.root),
                                     "SCRIPT_DIR": str(self.root / ".devcontainer")}, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((agent / "settings.json").read_text())["defaultModel"], "user-preference")

    def test_server_requires_both_enabled_installer_and_persisted_override(self):
        installer = self.root / ".devcontainer/install/available/4010-tool-ssh-server.sh"
        installer.parent.mkdir(parents=True)
        installer.write_text("# fixture\n")
        enabled = self.root / ".devcontainer/install/03-enabled"
        enabled.mkdir()
        server = self.root / ".devcontainer/config/compose/docker-compose.ssh-server.yml"
        server.parent.mkdir(parents=True)
        server.write_text("# fixture override\n")
        self.selected["volumes"] = [self.bind(str(self.root / ".env.d/.ssh-server"), "/home/ubuntu/.ssh-server")]
        self.config.write_text('{"service":"custom","dockerComposeFile":["base.yml","config/compose/docker-compose.ssh-server.yml"]}')
        value = self.publish()
        with patch.dict(os.environ, {"DEVCONTAINER_BIND_MANIFEST_ID": value["id"]}), \
                patch.object(manifest.sys, "argv", ["manifest", "ssh-server", str(self.root)]):
            with self.assertRaisesRegex(ValueError, "disabled"):
                manifest.main()
            (enabled / "29-custom.sh").symlink_to("../available/4010-tool-ssh-server.sh")
            with contextlib.redirect_stdout(io.StringIO()):
                manifest.main()
            self.selected["volumes"][0]["read_only"] = True
            value = self.publish()
            with patch.dict(os.environ, {"DEVCONTAINER_BIND_MANIFEST_ID": value["id"]}):
                with self.assertRaisesRegex(ValueError, "persisted-key override"):
                    manifest.main()
            self.selected["volumes"][0]["read_only"] = False
            self.config.write_text('{"service":"custom","dockerComposeFile":"base.yml"}')
            value = self.publish()
            with patch.dict(os.environ, {"DEVCONTAINER_BIND_MANIFEST_ID": value["id"]}):
                with self.assertRaisesRegex(ValueError, "persisted-key override"):
                    manifest.main()

    def test_optional_installers_are_downstream_and_do_not_install_each_other(self):
        available = ROOT / ".devcontainer/install/available"
        for name in ("4010-tool-ssh-server.sh", "4100-tool-pulseaudio-utils.sh", "3030-ai-pi-coding.sh"):
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
        for script, package in (("4000-tool-ssh.sh", "openssh-client"),
                                ("4010-tool-ssh-server.sh", "openssh-server"),
                                ("4100-tool-pulseaudio-utils.sh", "pulseaudio-utils")):
            calls.write_text("")
            result = subprocess.run(["bash", str(available / script)], env=environment, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(calls.read_text().splitlines(), ["update -qq", f"install -y -qq {package}"])

    def test_real_repository_overrides_are_independent(self):
        # Copy only public Compose/JSONC files; never read the real .env or state.
        for source in (ROOT / ".devcontainer").glob("docker-compose*.yml"):
            shutil.copy2(source, self.root / ".devcontainer" / source.name)
        shutil.copytree(ROOT / ".devcontainer/config/compose", self.root / ".devcontainer/config/compose")
        base = self.root / ".devcontainer/docker-compose.yml"
        definition = manifest.read_compose_fragment(base)
        definition["services"]["container-svc"].setdefault("ports", []).append("15551:15551")
        base.write_text(json.dumps(definition))
        (self.root / ".env").write_text("")
        environment = {"APP_NAME": "fixture", "APP_PORT": "12340", "OPENCODE_PORT": "12341",
                       "SSH_PORT": "12342", "HOST_UID": "1234", "SSH_AUTH_SOCK": "/fixture/agent.sock",
                       "DEVCONTAINER_BIND_MANIFEST_ID": "fixture-creation-identity"}
        base_ports = set()
        for optional, expected in ((None, None), ("pi", "/home/ubuntu/.pi"),
                                   ("ssh-agent", "/ssh-agent"), ("ssh-server", "/home/ubuntu/.ssh-server"),
                                   ("audio", "/pulse-native"), ("codegraph", "/home/ubuntu/fixture/.codegraph")):
            files = ["docker-compose.yml", "config/compose/docker-compose-core-tools.yml"]
            if optional:
                files.append(f"config/compose/docker-compose.{optional}.yml")
            self.config.write_text(json.dumps({"service": "container-svc", "dockerComposeFile": files}))
            with patch.dict(os.environ, environment):
                selected = manifest.compose_model(self.root)[3]
            targets = {volume["target"] for volume in selected["volumes"]}
            for volume in selected["volumes"]:
                if volume["target"].startswith("/home/ubuntu/"):
                    self.assertTrue(Path(volume["source"]).is_relative_to(self.root / ".env.d"))
            if optional == "codegraph":
                graph = next(volume for volume in selected["volumes"] if volume["target"] == expected)
                self.assertEqual(graph["source"], str(self.root / ".env.d/.codegraph"))
                records = manifest.project_manifest(self.root, *manifest.selection(self.root)[:2], selected)["volumes"]
                managed = list(prep.managed_bind_sources(records, str(self.root)))
                self.assertIn(str(self.root / ".env.d/.codegraph"), managed)
            optional_targets = targets & {"/home/ubuntu/.pi", "/ssh-agent", "/home/ubuntu/.ssh-server", "/pulse-native", "/home/ubuntu/fixture/.codegraph"}
            self.assertEqual(optional_targets, {expected} if expected else set())
            ports = {(port["target"], port.get("published"), port.get("protocol", "tcp"),
                      port.get("host_ip")) for port in selected.get("ports", [])}
            if optional is None:
                base_ports = ports
            elif optional == "ssh-server":
                self.assertEqual(ports, base_ports | {(22, "12342", "tcp", None)})
            else:
                self.assertEqual(ports, base_ports)
            self.assertEqual(selected["environment"]["DEVCONTAINER_BIND_MANIFEST_ID"], "fixture-creation-identity")
            if optional == "audio":
                self.assertEqual(selected["environment"]["PULSE_SERVER"], "unix:/pulse-native")
                audio = next(volume for volume in selected["volumes"] if volume["target"] == expected)
                self.assertTrue(audio["read_only"])
                self.assertEqual(audio["source"], "/run/user/1234/pulse/native")
            if optional == "ssh-agent":
                self.assertEqual(selected["environment"]["SSH_AUTH_SOCK"], "/ssh-agent")
            manifest.project_manifest(self.root, *manifest.selection(self.root)[:2], selected)

    def test_core_extraction_preserves_original_mounts_and_port(self):
        base = manifest.read_compose_fragment(ROOT / ".devcontainer/docker-compose.yml")["services"]["container-svc"]
        core = manifest.read_compose_fragment(
            ROOT / ".devcontainer/config/compose/docker-compose-core-tools.yml")["services"]["container-svc"]
        expected = [
            (".engram", "/home/ubuntu/.engram"),
            (".opencode/share", "/home/ubuntu/.local/share/opencode"),
            (".gentle-ai", "/home/ubuntu/.gentle-ai"),
            (".gitconfig", "/home/ubuntu/.gitconfig-volume"),
        ]
        self.assertEqual(core["volumes"], [self.bind(f"../.env.d/{source}", target) for source, target in expected])
        self.assertEqual(core["ports"], ["${OPENCODE_PORT}:4096"])
        self.assertNotIn("volumes", base)
        self.assertEqual(base["ports"], ["${APP_PORT}:${APP_PORT}"])
        self.assertEqual(base["env_file"], ["../.env"])
        self.assertIn("DEVCONTAINER_BIND_MANIFEST_ID", base["environment"])

    def test_default_selection_keeps_core_active_and_optional_overrides_disabled(self):
        shutil.copytree(ROOT / ".devcontainer/config/compose", self.root / ".devcontainer/config/compose")
        shutil.copyfile(ROOT / ".devcontainer/docker-compose.yml", self.root / ".devcontainer/docker-compose.yml")
        self.config.write_text('''{
  "service": "container-svc",
  "dockerComposeFile": [
    "./docker-compose.yml",
    "./config/compose/docker-compose-core-tools.yml"
    // , "./config/compose/docker-compose.pi.yml"
    // , "./config/compose/docker-compose.codegraph.yml"
    // , "./config/compose/docker-compose.ssh-agent.yml"
    // , "./config/compose/docker-compose.ssh-server.yml"
    // , "./config/compose/docker-compose.audio.yml"
  ]
}''')
        paths = [str(path.relative_to(self.root / ".devcontainer")) for path in manifest.selection(self.root)[1]]
        self.assertEqual(paths, ["docker-compose.yml", "config/compose/docker-compose-core-tools.yml"])

    def test_audio_stays_outside_dind_tmp_and_is_never_managed(self):
        selected = manifest.read_compose_fragment(
            ROOT / ".devcontainer/config/compose/docker-compose.audio.yml")["services"]["container-svc"]
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
        projected = manifest.project_manifest(self.root, *manifest.selection(self.root)[:2], selected)
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
        self.assertIs(selected["volumes"][0].get("bind", {}).get("create_host_path"), False)
        self.assertFalse((self.root / ".env.d").exists())

    def test_real_compose_creation_flags_fail_closed_before_preparation(self):
        long_bind = '{type: bind, source: ../.env.d/state, target: /state%s}'
        cases = (
            ("explicit false", ', bind: {create_host_path: false}', None, True),
            ("YAML FALSE", ', bind: {create_host_path: FALSE}', None, True),
            ("interpolated false", ', bind: {create_host_path: "${FIXTURE_CREATE}"}', None, True),
            ("explicit true", ', bind: {create_host_path: true}', None, False),
            ("omitted flag", ', bind: {}', None, False),
            ("omitted bind", '', None, False),
            ("short syntax", None, None, False),
            ("true overridden by false", ', bind: {create_host_path: true}', False, True),
            ("false overridden by true", ', bind: {create_host_path: false}', True, False),
        )
        for name, options, override, safe in cases:
            with self.subTest(case=name), patch.dict(os.environ, {"FIXTURE_CREATE": "false"}):
                volume = long_bind % options if options is not None else '"../.env.d/state:/state"'
                (self.root / ".devcontainer/base.yml").write_text(
                    'services:\n  custom:\n    image: fixture:local\n    container_name: fixture\n'
                    '    volumes:\n      - ' + volume + '\n')
                extra = {"services": {}}
                if override is not None:
                    changed = self.bind("../.env.d/state", "/state")
                    changed["bind"]["create_host_path"] = override
                    extra["services"]["custom"] = {"volumes": [changed]}
                (self.root / ".devcontainer/extra.yml").write_text(json.dumps(extra))
                if safe:
                    service, paths, _, selected, project = manifest.compose_model(self.root)
                    value = manifest.project_manifest(self.root, service, paths, selected, project)
                    self.assertIs(value["volumes"][0]["bind"]["create_host_path"], False)
                    self.assertIs(value["volumes"][0]["read_only"], False)
                else:
                    with patch.object(manifest, "check_existing_container",
                                      side_effect=AssertionError("Unsafe bind reached container check")) as check:
                        with self.assertRaisesRegex(ValueError, "must set create_host_path: false"):
                            manifest.prepare(self.root)
                        check.assert_not_called()
                self.assertFalse((self.root / ".env.d").exists())
                self.assertFalse((self.root / manifest.MANIFEST).exists())

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

    def test_default_env_changes_preserve_snapshot_and_legacy_is_rejected(self):
        for relative in (".env", ".devcontainer/.env"):
            path = self.root / relative
            for content in ("FIXTURE_BIND=before\n", "FIXTURE_BIND=after\n", None):
                value = self.publish()
                if content is None:
                    path.unlink()
                else:
                    path.write_text(content)
                self.assertEqual(manifest.load_manifest(self.root), value)
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
                service, paths, _, selected, project = resolved
                value = manifest.project_manifest(self.root, service, paths, selected, project)
                self.assertEqual(value["project_name_fingerprint"], manifest.digest(expected))
        service, paths, _ = manifest.selection(self.root)
        first = manifest.project_manifest(self.root, service, paths, self.selected, "one")
        second = manifest.project_manifest(self.root, service, paths, self.selected, "two")
        self.assertNotEqual(first["id"], second["id"])
        (self.root / ".devcontainer/extra.yml").write_text('name: ${PROJECT}\n')
        with self.assertRaisesRegex(ValueError, "top-level name must be literal"):
            manifest.compose_model(self.root)


class AttachmentTests(ManifestFixture):
    """Only local files and mocked subprocesses; no daemon or Compose execution."""

    def setUp(self):
        super().setUp()
        self.value = self.publish()
        self.container = {"Name": "/fixture", "Config": {"Env": [
            "DEVCONTAINER_BIND_MANIFEST_ID=" + self.value["id"]]},
            "State": {"Status": "running", "Running": True, "Paused": False, "Restarting": False}}

    def attach(self, lookup="fixture\n", failure=None, race=False):
        service, paths, inputs = manifest.selection(self.root)
        before = {str(path): path.read_bytes() for path in self.root.rglob("*") if path.is_file()}
        calls = []

        def engine(command, **kwargs):
            calls.append(command)
            if command[2] == "ls":
                return subprocess.CompletedProcess(command, 1 if failure == "lookup" else 0, lookup)
            self.assertEqual(command, ["docker", "container", "inspect", "fixture"])
            if race:
                self.config.write_text('{}')
            return subprocess.CompletedProcess(command, 1 if failure == "inspect" else 0,
                                               json.dumps([self.container]))

        output = io.StringIO()
        with patch.object(manifest, "compose_model", return_value=(service, paths, inputs, self.selected, "")), \
                patch.object(manifest.subprocess, "run", side_effect=engine), \
                patch.object(manifest, "prepare", side_effect=AssertionError("preparation forbidden")), \
                patch.object(manifest.os, "replace", side_effect=AssertionError("publication forbidden")), \
                contextlib.redirect_stderr(output):
            result = manifest.attachment(self.root)
        after = {str(path): path.read_bytes() for path in self.root.rglob("*") if path.is_file()}
        self.assertEqual(before, after)
        self.assertFalse((self.root / ".env.d").exists())
        return result, output.getvalue(), calls

    def test_running_verified_is_read_only(self):
        state, warning, calls = self.attach()
        self.assertEqual(state, "running")
        self.assertEqual(warning, "")
        self.assertEqual(len(calls), 2)

    def test_drift_missing_token_and_bad_snapshot_warn_without_writes(self):
        for condition in ("drift", "missing", "snapshot", "unapplied", "projection"):
            with self.subTest(condition=condition):
                self.setUp()
                if condition == "drift":
                    self.selected["volumes"][0]["read_only"] = True
                elif condition == "missing":
                    self.container["Config"]["Env"] = []
                elif condition == "snapshot":
                    (self.root / manifest.MANIFEST).write_text('private-invalid-json')
                elif condition == "unapplied":
                    self.container["Config"]["Env"] = ["DEVCONTAINER_BIND_MANIFEST_ID=" + "a" * 64]
                else:
                    self.selected["volumes"][0]["bind"] = {}
                state, warning, _ = self.attach()
                self.assertEqual(state, "running")
                self.assertIn("[attachment:warning]", warning)
                self.assertNotIn("private", warning)
                self.assertNotIn(str(self.root), warning)

    def test_absent_and_stopped_require_strict_startup(self):
        self.assertEqual(self.attach(lookup="other-fixture\n")[0], "absent")
        for state in ("created", "exited"):
            self.container["State"].update(Status=state, Running=False)
            self.assertEqual(self.attach()[0], "stopped")

    def test_lookup_inspect_and_malformed_results_block(self):
        for failure in ("lookup", "inspect"):
            with self.assertRaises(ValueError):
                self.attach(failure=failure)
        for lookup in ("fixture\nfixture\n", "invalid name\n"):
            with self.assertRaises(ValueError):
                self.attach(lookup=lookup)
        for mutation in ({"Name": "/other"}, {"State": {}}, {"Config": {"Env": "secret"}}):
            original = copy.deepcopy(self.container)
            self.container.update(mutation)
            with self.assertRaises(ValueError):
                self.attach()
            self.container = original

    def test_unsupported_and_contradictory_states_block(self):
        for state in ("paused", "restarting", "dead", "removing", "unknown", "exited"):
            self.container["State"]["Status"] = state
            with self.assertRaises(ValueError):
                self.attach()

    def test_concurrent_input_change_blocks(self):
        with self.assertRaises(ValueError):
            self.attach(race=True)

    def test_legacy_token_is_not_runtime_authority(self):
        self.container["Config"]["Env"] = ["GENTLE_VOLUME_MANIFEST_ID=" + self.value["id"]]
        self.assertIn("missing or unverified", self.attach()[1])
        with patch.dict(os.environ, {"GENTLE_VOLUME_MANIFEST_ID": self.value["id"]}, clear=True):
            with self.assertRaisesRegex(ValueError, "not applied"):
                manifest.load_manifest(self.root, runtime=True)


class SemanticManifestTests(ManifestFixture):
    def test_env_and_input_bytes_do_not_define_mount_identity(self):
        original = self.publish()
        for relative in (".env", ".devcontainer/.env", ".devcontainer/extra.yml"):
            path = self.root / relative
            for content in ("APP_SECRET=fixture-before\n", "# comment\nAPP_SECRET=fixture-after\n", None):
                with self.subTest(relative=relative, content=content):
                    if content is None and relative.endswith(".yml"):
                        continue
                    if content is None:
                        path.unlink()
                    else:
                        path.write_text("# reformatted\nservices: {}\n" if relative.endswith(".yml") else content)
                    self.assertEqual(self.projection()["id"], original["id"])
                    with patch.dict(os.environ, {"DEVCONTAINER_BIND_MANIFEST_ID": original["id"]}):
                        self.assertEqual(manifest.load_manifest(self.root, runtime=True), original)
        self.assertEqual(original["schema"], 3)
        self.assertNotIn("inputs", original)
        self.assertNotEqual(original["id"], original["snapshot_digest"])

    def test_canonical_order_defaults_and_lexical_sources(self):
        original = self.projection()
        self.selected["volumes"].reverse()
        for volume in self.selected["volumes"]:
            volume["read_only"] = False
            volume["source"] = volume["source"].replace("/state", "/unused/../state")
        self.assertEqual(self.projection(), original)

    def test_missing_creation_flag_is_not_a_safe_default(self):
        for bind in ({}, None):
            with self.subTest(bind=bind):
                selected = copy.deepcopy(self.selected)
                if bind is None:
                    del selected["volumes"][0]["bind"]
                else:
                    selected["volumes"][0]["bind"] = bind
                with self.assertRaisesRegex(ValueError, "must set create_host_path: false"):
                    manifest.project_manifest(self.root, *manifest.selection(self.root)[:2], selected)

    def test_semantic_changes_change_identity(self):
        original = self.projection()["id"]
        for field, value in (("source", "/other/state"), ("target", "/other"), ("read_only", True)):
            with self.subTest(field=field):
                selected = copy.deepcopy(self.selected)
                selected["volumes"][0][field] = value
                changed = manifest.project_manifest(self.root, *manifest.selection(self.root)[:2], selected)
                self.assertNotEqual(changed["id"], original)
        service, paths, _ = manifest.selection(self.root)
        for args in (("other", paths, self.selected, ""),
                     (service, list(reversed(paths)), self.selected, ""),
                     (service, paths[:1], self.selected, ""),
                     (service, paths, self.selected, "other-project")):
            self.assertNotEqual(manifest.project_manifest(self.root, *args)["id"], original)

    def test_unsupported_bind_options_and_invalid_paths_fail_closed(self):
        for changes in ({"consistency": "cached"}, {"read_only": "false"},
                        {"read_only": 0}, {"bind": {"propagation": "rprivate"}},
                        {"bind": {"selinux": "z"}}, {"bind": {"create_host_path": 0}},
                        {"bind": {"create_host_path": True}}, {"target": "/a/../b"},
                        {"target": "/a//b"}, {"source": ""}, {"source": "/a\0b"}):
            with self.subTest(changes=changes):
                selected = copy.deepcopy(self.selected)
                selected["volumes"][0].update(changes)
                with self.assertRaises(ValueError):
                    manifest.project_manifest(self.root, *manifest.selection(self.root)[:2], selected)
        self.selected["volumes"].append(copy.deepcopy(self.selected["volumes"][0]))
        with self.assertRaises(ValueError):
            self.projection()

    def test_runtime_has_no_host_namespace_dependencies(self):
        value = self.publish()
        self.config.unlink()
        (self.root / ".devcontainer/base.yml").unlink()
        with patch.dict(os.environ, {"DEVCONTAINER_BIND_MANIFEST_ID": value["id"]}), \
                patch.object(manifest, "selection", side_effect=AssertionError("host selection read")), \
                patch.object(manifest.subprocess, "run", side_effect=AssertionError("host command")):
            self.assertEqual(manifest.load_manifest(self.root, runtime=True), value)

    def test_strict_snapshot_shape_even_with_recomputed_digests(self):
        original = self.projection()
        variants = []
        for field, value in (("schema", True), ("service", ""), ("files", ["../escape"]),
                             ("files", ["a", "a"]), ("files", ["a/./b"]),
                             ("files", ["/host/a"]), ("files", []), ("files", [1]),
                             ("project_name_fingerprint", 3), ("extra", "unknown")):
            variant = copy.deepcopy(original)
            variant[field] = value
            variants.append(variant)
        for field, value in (("source", ".env.d/../escape"), ("source", ".env.d//state"),
                             ("target", "/a/../b"), ("target", "/a\0b"), ("managed", 1), ("read_only", 0),
                             ("source_fingerprint", "A" * 64), ("bind", {"create_host_path": 0}),
                             ("bind", []), ("type", "volume"), ("extra", True)):
            variant = copy.deepcopy(original)
            variant["volumes"][0][field] = value
            variants.append(variant)
        duplicate = copy.deepcopy(original)
        duplicate["volumes"].append(copy.deepcopy(duplicate["volumes"][0]))
        variants.append(duplicate)
        reversed_records = copy.deepcopy(original)
        reversed_records["volumes"].reverse()
        variants.append(reversed_records)
        for variant in variants:
            with self.subTest(variant=variant):
                variant.pop("snapshot_digest", None)
                variant.pop("id", None)
                variant["id"] = manifest.digest(variant)
                variant["snapshot_digest"] = manifest.digest(variant)
                (self.root / manifest.MANIFEST).write_text(json.dumps(variant))
                with self.assertRaises(ValueError):
                    manifest.load_manifest(self.root)

    def test_integrity_and_applied_identity_are_independent_gates(self):
        original = self.publish()
        for field in ("id", "snapshot_digest"):
            value = copy.deepcopy(original)
            value[field] = "0" * 64
            if field == "id":
                value["snapshot_digest"] = manifest.digest({k: v for k, v in value.items() if k != "snapshot_digest"})
            (self.root / manifest.MANIFEST).write_text(json.dumps(value))
            with self.assertRaises(ValueError):
                manifest.load_manifest(self.root)
        self.publish()
        for applied in ("", "0" * 64):
            with patch.dict(os.environ, {"DEVCONTAINER_BIND_MANIFEST_ID": applied}):
                with self.assertRaisesRegex(ValueError, "not applied"):
                    manifest.load_manifest(self.root, runtime=True)

    def test_legacy_load_never_rewrites_and_requires_intentional_host_recreate(self):
        for schema in (1, 2):
            value = self.projection()
            value["schema"] = schema
            path = self.root / manifest.MANIFEST
            path.write_text(json.dumps(value))
            before = path.read_bytes()
            with self.assertRaisesRegex(ValueError, "intentional host.*task container:recreate"):
                manifest.load_manifest(self.root, runtime=True)
            self.assertEqual(path.read_bytes(), before)
            self.assertFalse((self.root / ".env.d").exists())

    def test_concurrency_before_preparation_and_before_publication(self):
        for late in (False, True):
            for initial in (None, "before\n", "edit\n"):
                with self.subTest(late=late, initial=initial):
                    env = self.root / ".env"
                    if initial is None:
                        env.unlink(missing_ok=True)
                    else:
                        env.write_text(initial)
                    self.publish()
                    previous = (self.root / manifest.MANIFEST).read_bytes()
                    resolved = (*manifest.selection(self.root), self.selected, "fixture-project")

                    def change(*_):
                        if initial is None:
                            env.write_text("added\n")
                        elif initial == "before\n":
                            env.unlink()
                        else:
                            env.write_text("after\n")

                    original_selection = manifest.selection
                    calls = 0

                    def observed_selection(workspace):
                        nonlocal calls
                        calls += 1
                        if late and calls == 2:
                            change()
                        return original_selection(workspace)

                    with patch.object(manifest, "compose_model", return_value=resolved), \
                            patch.object(manifest, "check_existing_container", side_effect=None if late else change), \
                            patch.object(manifest, "selection", side_effect=observed_selection), \
                            contextlib.redirect_stdout(io.StringIO()):
                        with self.assertRaisesRegex(ValueError, "changed during host preparation"):
                            manifest.prepare(self.root)
                    self.assertEqual((self.root / manifest.MANIFEST).read_bytes(), previous)
                    if not late:
                        self.assertFalse((self.root / ".env.d").exists())

    def test_existing_container_mismatch_precedes_all_state_mutation(self):
        self.publish()
        previous = (self.root / manifest.MANIFEST).read_bytes()
        resolved = (*manifest.selection(self.root), self.selected, "fixture-project")
        with patch.object(manifest, "compose_model", return_value=resolved), \
                patch.object(manifest, "check_existing_container", side_effect=ValueError("mismatch")):
            with self.assertRaisesRegex(ValueError, "mismatch"):
                manifest.prepare(self.root)
        self.assertEqual((self.root / manifest.MANIFEST).read_bytes(), previous)
        self.assertFalse((self.root / ".env.d").exists())

    def test_selection_token_hashes_the_same_config_bytes_it_parsed(self):
        original_read = Path.read_bytes
        before = self.config.read_bytes()

        def changing_read(path):
            value = original_read(path)
            if path == self.config:
                self.config.write_text('{"service":"other","dockerComposeFile":"base.yml"}')
            return value

        with patch.object(Path, "read_bytes", changing_read):
            service, _, inputs = manifest.selection(self.root)
        self.assertEqual(service, "custom")
        self.assertEqual(inputs[".devcontainer/devcontainer.json"], manifest.hashlib.sha256(before).hexdigest())
        with self.assertRaisesRegex(ValueError, "changed during host preparation"):
            manifest.check_preparation_inputs(self.root, inputs)


if __name__ == "__main__":
    unittest.main()
