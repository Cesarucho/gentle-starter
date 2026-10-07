"""Offline installer boundary tests; user identity is simulated, never switched."""

import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[3]
INSTALLER = REPO / ".devcontainer/install/available/2080-browser-playwright.sh"
LOCKS = dict(re.findall(r'^LOCK_(PLAYWRIGHT(?:_CLI)?_VERSION)="([^"]+)"$',
                        (REPO / ".devcontainer/tool-versions.conf").read_text(), re.MULTILINE))


class PlaywrightOwnershipTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="playwright-ownership-", dir="/tmp/opencode")
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        self.home.mkdir()
        self.bin.mkdir()
        install_tree = self.root / "install"
        (install_tree / "available").mkdir(parents=True)
        (install_tree / "lib").mkdir()
        self.installer = install_tree / "available" / INSTALLER.name
        shutil.copyfile(INSTALLER, self.installer)
        common = REPO / ".devcontainer/install/lib/common.sh"
        (install_tree / "lib/common.sh").write_text(common.read_text() + '''
devcontainer_has_cmd() {
    case "$1" in
        playwright) return 1 ;;
        playwright-cli) [ -f "${FIXTURE_HOME}/../cli-installed" ] ;;
        *) command -v "$1" >/dev/null 2>&1 ;;
    esac
}
''')
        self.calls = self.root / "calls"
        self.config = self.home / ".playwright/cli.config.json"
        self.skill = self.home / ".claude/skills/playwright-cli/SKILL.md"
        self.env = {
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "HOME": str(self.root),
            "FIXTURE_HOME": str(self.home),
            "CALLS": str(self.calls),
            "UID_NAME": "ubuntu",
            "DEVCONTAINER_TOOL_VERSIONS_FILE": str(REPO / ".devcontainer/tool-versions.conf"),
            "PLAYWRIGHT_BROWSERS_PATH": str(self.root / "image-browsers"),
        }
        self.script("id", 'printf "%s\\n" "${SIMULATED_UID:-0}"')
        self.script("getent", '''
[ "${MISSING_USER:-0}" = 0 ] || exit 2
printf 'ubuntu:x:1000:1000::%s:/bin/bash\n' "${FIXTURE_HOME}"
''')
        self.script("sudo", '''
[[ "$1 $2 $3" = '-H -u ubuntu' ]] || exit 97
shift 3
export HOME="${BAD_HOME:-${FIXTURE_HOME}}" SIMULATED_USER=ubuntu SIMULATED_UID="${SUDO_UID:-1000}"
exec "$@"
''')
        self.script("chown", "exit 97")
        self.script("npm", '''
printf 'npm:%s:%s\n' "${SIMULATED_USER:-root}" "$*" >>"${CALLS}"
if [[ "$*" = *'@playwright/cli@'* ]]; then
    touch "${FIXTURE_HOME}/../cli-installed"
fi
''')
        self.script("npx", '''
printf 'npx:%s:%s\n' "${SIMULATED_USER:-root}" "$*" >>"${CALLS}"
''')
        cli = self.bin / "playwright-cli"
        cli.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
home = pathlib.Path(os.environ["FIXTURE_HOME"])
cwd = pathlib.Path.cwd()
assert cwd == home, "CLI must run in the configured home"
assert os.environ["HOME"] == str(home)
assert os.environ.get("SIMULATED_USER") == "ubuntu", "CLI must not run as root"
with open(os.environ["CALLS"], "a") as log:
    log.write("cli:" + json.dumps({"user": os.environ["SIMULATED_USER"],
              "home": os.environ["HOME"], "cwd": str(cwd), "args": sys.argv[1:]}) + "\\n")
config = cwd / ".playwright/cli.config.json"
config.parent.mkdir(exist_ok=True)
if not config.exists():
    config.write_text('{"browser":{"browserName":"chromium"}}')
if "--skills" in sys.argv:
    skill = cwd / ".claude/skills/playwright-cli/SKILL.md"
    skill.parent.mkdir(parents=True, exist_ok=True)
    skill.write_text("upstream skill")
''')
        cli.chmod(0o755)

    def script(self, name, body):
        target = self.bin / name
        target.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + body + "\n")
        target.chmod(0o755)

    def install(self, **overrides):
        return subprocess.run(
            ["bash", str(self.installer)], cwd=self.root,
            env={**self.env, **overrides}, text=True, capture_output=True, timeout=10,
        )

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_fresh_user_artifacts_and_root_package_operations(self):
        self.assert_success(self.install())
        self.assertEqual(json.loads(self.config.read_text())["browser"]["browserName"], "chromium")
        self.assertTrue(self.skill.is_file())
        self.assertEqual((self.root / "image-browsers").stat().st_mode & 0o777, 0o755)
        calls = self.calls.read_text()
        self.assertIn(f"npm:root:install -g playwright@{LOCKS['PLAYWRIGHT_VERSION']}", calls)
        self.assertIn(f"npm:root:install -g @playwright/cli@{LOCKS['PLAYWRIGHT_CLI_VERSION']}", calls)
        self.assertIn(f"npx:root:-y playwright@{LOCKS['PLAYWRIGHT_VERSION']} install chromium --with-deps", calls)
        record = json.loads(next(line[4:] for line in calls.splitlines() if line.startswith("cli:")))
        self.assertEqual(record, {"user": "ubuntu", "home": str(self.home),
                                  "cwd": str(self.home), "args": ["install", "--skills"]})

    def test_cli_stub_rejects_original_unqualified_root_invocation(self):
        result = subprocess.run(
            [str(self.bin / "playwright-cli"), "install", "--skills"], cwd=self.home,
            env={**self.env, "HOME": str(self.home)}, text=True, capture_output=True, timeout=10,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("CLI must not run as root", result.stderr)
        self.assertFalse(self.config.exists())

    def test_existing_config_modes_and_unrelated_files_are_preserved(self):
        self.config.parent.mkdir(mode=0o750)
        self.config.write_text('{ "custom": true }\n')
        self.config.chmod(0o640)
        unrelated = self.home / "notes"
        unrelated.write_text("keep")
        self.assert_success(self.install())
        self.assertEqual(self.config.read_text(), '{ "custom": true }\n')
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o640)
        self.assertEqual(self.config.parent.stat().st_mode & 0o777, 0o750)
        self.assertEqual(unrelated.read_text(), "keep")

    def test_reexecution_does_not_rewrite_user_artifacts(self):
        self.assert_success(self.install())
        self.skill.write_text("custom skill")
        before = [(p.read_bytes(), p.stat().st_mode, p.stat().st_mtime_ns)
                  for p in (self.config, self.skill)]
        self.assert_success(self.install())
        after = [(p.read_bytes(), p.stat().st_mode, p.stat().st_mtime_ns)
                 for p in (self.config, self.skill)]
        self.assertEqual(before, after)
        self.assertEqual(self.calls.read_text().count("cli:"), 1)

    def test_existing_skills_are_not_overwritten_when_config_is_missing(self):
        self.skill.parent.mkdir(parents=True)
        self.skill.write_text("custom skill")
        self.assert_success(self.install())
        self.assertEqual(self.skill.read_text(), "custom skill")
        self.assertTrue(self.config.exists())

    def test_user_or_home_failure_never_falls_back_to_root(self):
        for overrides in ({"MISSING_USER": "1"}, {"BAD_HOME": str(self.root)}, {"SUDO_UID": "0"},
                          {"FIXTURE_HOME": str(self.root / "missing")}):
            with self.subTest(overrides=overrides):
                result = self.install(**overrides)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Playwright requires", result.stdout + result.stderr)
                self.assertFalse(self.config.exists())

    def test_symlinked_config_is_rejected_without_touching_target(self):
        target = self.root / "outside"
        target.write_text("preserve")
        self.config.parent.mkdir()
        self.config.symlink_to(target)
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Refusing unsafe Playwright configuration", result.stderr)
        self.assertEqual(target.read_text(), "preserve")

    def test_symlinked_skill_parent_is_rejected(self):
        (self.home / ".claude").symlink_to(self.root, target_is_directory=True)
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Refusing unsafe Playwright provisioning directory", result.stderr)

    def test_symlinked_home_is_rejected_before_package_operations(self):
        alias = self.root / "home-link"
        alias.symlink_to(self.home, target_is_directory=True)
        result = self.install(FIXTURE_HOME=str(alias))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("existing canonical home", result.stdout + result.stderr)
        self.assertFalse(self.calls.exists())

    def test_explicit_version_overrides_reach_package_operations(self):
        self.assert_success(self.install(PLAYWRIGHT_VERSION="9.8.7", PLAYWRIGHT_CLI_VERSION="6.5.4"))
        calls = self.calls.read_text()
        self.assertIn("npm:root:install -g playwright@9.8.7", calls)
        self.assertIn("npm:root:install -g @playwright/cli@6.5.4", calls)
        self.assertIn("npx:root:-y playwright@9.8.7 install chromium --with-deps", calls)

    def test_git_home_is_not_modified_by_upstream(self):
        (self.home / ".git").mkdir()
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("home that is a Git workspace", result.stderr)
        self.assertFalse((self.home / ".gitignore").exists())


if __name__ == "__main__":
    unittest.main()
