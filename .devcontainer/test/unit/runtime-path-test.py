#!/usr/bin/env python3
"""Parent-run configuration proof; no real .env, daemon, or containers."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]
COMPOSE = Path("/usr/libexec/docker/cli-plugins/docker-compose")
BASE = (
    "/home/ubuntu/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:"
    "/usr/bin:/sbin:/bin:/home/ubuntu/.local/share/pnpm/bin:"
    "/home/ubuntu/.local/share/pnpm"
)
MANAGED = "/home/ubuntu/.gentle-ai/bin"
PATH_ENTRY = f'PATH="{MANAGED}:${{CONTAINER_BASE_PATH}}"'


class RuntimePathTests(unittest.TestCase):
    def template_entries(self):
        return [line for line in (ROOT / ".env.example").read_text().splitlines()
                if line.startswith(("CONTAINER_BASE_PATH=", "PATH="))]

    def test_enabled_entries_match_approved_order_and_values(self):
        self.assertEqual(self.template_entries(),
                         [f"CONTAINER_BASE_PATH={BASE}", PATH_ENTRY])

    def test_compose_resolves_template_without_host_path_leakage(self):
        self.assertTrue(COMPOSE.is_file(), f"Required Compose plugin missing: {COMPOSE}")
        with tempfile.TemporaryDirectory(prefix="runtime-path-", dir="/tmp/opencode") as name:
            fixture = Path(name)
            (fixture / "runtime.env").write_bytes((ROOT / ".env.example").read_bytes())
            (fixture / "empty.env").write_text("")
            (fixture / "compose.json").write_text(json.dumps({"services": {
                "path-proof": {"image": "scratch", "env_file": ["runtime.env"]}
            }}))
            result = subprocess.run(
                [str(COMPOSE), "--project-name", "runtime-path-proof",
                 "--env-file", str(fixture / "empty.env"),
                 "-f", str(fixture / "compose.json"), "config", "--format", "json"],
                cwd=fixture, env={"PATH": "/host-path-sentinel",
                                  "HOME": name, "DOCKER_CONFIG": str(fixture / "docker")},
                text=True, capture_output=True, timeout=20, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, "")
            environment = json.loads(result.stdout)["services"]["path-proof"].get("environment", {})
            expected_path = f"{MANAGED}:{BASE}"
            self.assertEqual(environment["CONTAINER_BASE_PATH"], BASE)
            self.assertEqual(environment["PATH"], expected_path)
            self.assertNotIn("/host-", result.stdout)
            self.assertNotIn("$", environment["PATH"])
            directories = environment["PATH"].split(":")
            self.assertEqual(len(directories), len(set(directories)))
            self.assertEqual(directories[0], MANAGED)
            self.assertEqual(directories[1:], BASE.split(":"))


if __name__ == "__main__":
    unittest.main()
