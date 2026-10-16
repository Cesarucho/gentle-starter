#!/usr/bin/env python3
"""Execute the PHPUnit installer with closed, recording command stubs only."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]


class PhpUnitInstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir="/tmp/opencode")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ("available", "lib", "bin", "home"):
            (self.root / name).mkdir()
        self.script = self.root / "available/2320-php-test.sh"
        shutil.copyfile(ROOT / ".devcontainer/install/available/2320-php-test.sh", self.script)
        (self.root / "bin/dirname").symlink_to("/usr/bin/dirname")
        (self.root / "resolved-bin").mkdir()
        (self.root / "resolved-bin/phpunit").write_text("fixture")
        (self.root / "resolved-bin/phpunit").chmod(0o755)
        (self.root / "lib/common.sh").write_text("""
devcontainer_load_tool_versions() { LOCK_PHPUNIT_VERSION=10.5.64; }
devcontainer_require_cmd() { return 0; }
devcontainer_has_cmd() { [[ "$1" != phpunit || -f "$RECORD/installed" ]]; }
devcontainer_log_info() { :; }
devcontainer_log_error() { printf '%s\\n' "$*" >&2; }
devcontainer_run_as_root() {
    printf '%s\\n' "$*" >> "$RECORD/root-calls"
    case "$1" in
        env) shift; export "$1"; shift; [[ "$1" == composer ]] || return 99; shift; composer "$@" ;;
        ln) : ;;
        *) return 99 ;;
    esac
}
composer() {
    printf '%s\\n' "${COMPOSER_HOME:-unset}" >> "$RECORD/composer-home"
    if [[ "$*" == 'global config bin-dir --absolute' ]]; then
        [[ "${FAIL_QUERY:-0}" == 0 ]] || return 23
        printf '%s/resolved-bin\\n' "$RECORD"
        return
    fi
    printf '%s\\n' "$@" >> "$RECORD/composer-args"
    [[ "${FAIL_COMPOSER:-0}" == 0 ]] || return 19
    : > "$RECORD/installed"
}
phpunit() { printf 'PHPUnit recording stub\\n'; }
""")
        self.env = {"PATH": str(self.root / "bin"), "HOME": str(self.root / "home"),
                    "RECORD": str(self.root), "LANG": "C"}

    def run_installer(self):
        return subprocess.run(["/bin/bash", str(self.script)], env=self.env,
                              capture_output=True, text=True, timeout=10)

    def test_requires_exact_composer_version_argument(self):
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "composer-args").read_text().splitlines(),
                         ["global", "require", "--quiet", "phpunit/phpunit:10.5.64"])

    def test_uses_shared_home_and_resolved_binary_without_user_config_changes(self):
        config = self.root / "home/config.json"
        config.write_text('{"preserve": true}\n')
        self.assertEqual(self.run_installer().returncode, 0)
        self.assertEqual((self.root / "composer-home").read_text().splitlines(),
                         ["/usr/local/share/phpunit", "/usr/local/share/phpunit"])
        calls = (self.root / "root-calls").read_text().splitlines()
        self.assertEqual(calls[-1], f"ln -sfn {self.root}/resolved-bin/phpunit /usr/local/bin/phpunit")
        self.assertEqual(config.read_text(), '{"preserve": true}\n')

    def test_composer_failure_stops_before_link_or_success(self):
        self.env["FAIL_COMPOSER"] = "1"
        self.assertEqual(self.run_installer().returncode, 19)
        self.assertFalse((self.root / "installed").exists())
        calls = self.root / "root-calls"
        self.assertNotIn("ln -sfn", calls.read_text() if calls.exists() else "")

    def test_missing_resolved_binary_fails_without_linking(self):
        (self.root / "resolved-bin/phpunit").unlink()
        result = self.run_installer()
        self.assertEqual(result.returncode, 1)
        self.assertIn("binary missing from Composer bin-dir", result.stderr)
        self.assertNotIn("ln -sfn", (self.root / "root-calls").read_text())

    def test_bin_directory_query_failure_stops_without_linking(self):
        self.env["FAIL_QUERY"] = "1"
        self.assertEqual(self.run_installer().returncode, 23)
        self.assertNotIn("ln -sfn", (self.root / "root-calls").read_text())

    def test_existing_phpunit_skips_composer(self):
        (self.root / "installed").touch()
        self.assertEqual(self.run_installer().returncode, 0)
        self.assertFalse((self.root / "composer-args").exists())


if __name__ == "__main__":
    unittest.main()
