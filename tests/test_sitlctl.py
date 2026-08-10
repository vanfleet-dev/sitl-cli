import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
SITLCTL = REPO / "sitlctl"


FAKE_DOCKER = r'''#!/usr/bin/env python3
import os
import sys
from pathlib import Path

args = sys.argv[1:]
state_dir = Path(os.environ["FAKE_DOCKER_STATE_DIR"])
state_dir.mkdir(parents=True, exist_ok=True)

if not args:
    raise SystemExit(2)
if args[0] in {"info", "context"}:
    if args[0] == "context":
        print("fake")
    raise SystemExit(0)
if args[:2] == ["image", "inspect"]:
    raise SystemExit(0)

def filtered_name():
    for arg in args:
        if arg.startswith("name=^/") and arg.endswith("$"):
            return arg[len("name=^/"):-1]
    return None

if args[0] == "ps":
    name = filtered_name()
    if name and (state_dir / name).exists():
        print(name)
    raise SystemExit(0)
if args[0] == "inspect":
    name = args[-1]
    if not (state_dir / name).exists():
        raise SystemExit(1)
    format_text = " ".join(args)
    if ".State.Status" in format_text:
        print("running")
    elif ".Config.Env" in format_text:
        print((state_dir / f"{name}.env").read_text(), end="")
    raise SystemExit(0)
if args[:2] == ["rm", "-f"]:
    name = args[-1]
    (state_dir / name).unlink(missing_ok=True)
    (state_dir / f"{name}.env").unlink(missing_ok=True)
    print(name)
    raise SystemExit(0)
if args[0] in {"logs", "exec"}:
    raise SystemExit(0)
raise SystemExit(f"unsupported fake docker call: {args}")
'''


FAKE_COMPOSE = r'''#!/usr/bin/env python3
import os
import sys
from pathlib import Path

args = sys.argv[1:]
state_dir = Path(os.environ["FAKE_DOCKER_STATE_DIR"])
state_dir.mkdir(parents=True, exist_ok=True)
name = os.environ["SITL_CONTAINER_NAME"]
with (state_dir / "compose.calls").open("a") as handle:
    handle.write(" ".join(args) + "\n")

if "up" in args:
    (state_dir / name).write_text("running\n")
    keys = [
        "SITL_INSTANCE", "SITL_CONTAINER_NAME", "SITL_LOG_DIR",
        "SITL_PORT_BASE", "SITL_INSTANCE_OFFSET", "SITL_SYSID_BASE",
        "SITL_VEHICLE", "SITL_FRAME", "SITL_LOCATION", "SITL_WIPE",
        "SITL_SPEEDUP", "SWARM_MODE", "SWARM_COUNT", "OFFSET_LINE",
    ] + [f"SITL_PORT_{index}" for index in range(20)]
    lines = [f"{key}={os.environ.get(key, '')}" for key in keys]
    (state_dir / f"{name}.env").write_text("\n".join(lines) + "\n")
    print(f"started {name}")
    raise SystemExit(0)
if "down" in args:
    (state_dir / name).unlink(missing_ok=True)
    (state_dir / f"{name}.env").unlink(missing_ok=True)
    print(f"stopped {name}")
    raise SystemExit(0)
raise SystemExit(f"unsupported fake compose call: {args}")
'''


class SitlctlTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.fake_bin = self.root / "bin"
        self.state = self.root / "state"
        self.logs = self.root / "logs"
        self.fake_bin.mkdir()
        self.state.mkdir()
        self._write_executable("docker", FAKE_DOCKER)
        self._write_executable("docker-compose", FAKE_COMPOSE)
        self.env = os.environ.copy()
        self.env.update(
            {
                "PATH": f"{self.fake_bin}:{self.env['PATH']}",
                "FAKE_DOCKER_STATE_DIR": str(self.state),
                "SITL_LOG_ROOT": str(self.logs),
                "SITLCTL_START_WAIT_SECONDS": "0",
                "TERM": "dumb",
            }
        )

    def tearDown(self):
        self.temporary.cleanup()

    def _write_executable(self, name, content):
        path = self.fake_bin / name
        path.write_text(textwrap.dedent(content))
        path.chmod(0o755)

    def run_sitlctl(self, *args):
        return subprocess.run(
            ["bash", str(SITLCTL), *args],
            cwd=REPO,
            env=self.env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def test_help_exposes_only_canonical_command(self):
        result = self.run_sitlctl("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("sitlctl start <1|2> <vehicle>", result.stdout)
        self.assertNotIn("\n  sitl ", result.stdout)
        self.assertFalse((REPO / "sitl").exists())

    def test_installer_replaces_reversed_alias_with_real_sitlctl(self):
        home = self.root / "home"
        bin_dir = home / "bin"
        bin_dir.mkdir(parents=True)
        legacy = bin_dir / "sitl"
        legacy.write_text("old launcher\n")
        legacy.chmod(0o755)
        (bin_dir / "sitlctl").symlink_to("sitl")

        environment = self.env.copy()
        environment["HOME"] = str(home)
        environment["PATH"] = f"{bin_dir}:{environment['PATH']}"
        result = subprocess.run(
            ["bash", str(REPO / "install.sh")],
            cwd=REPO,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        installed = bin_dir / "sitlctl"
        self.assertTrue(installed.is_file())
        self.assertFalse(installed.is_symlink())
        self.assertFalse(legacy.exists())
        self.assertIn("sitlctl start <1|2> <vehicle>", installed.read_text())
        for name in ("docker-compose.yml", "docker-entrypoint.sh", "locations.txt"):
            self.assertTrue((bin_dir / name).is_file(), name)

    def test_second_instance_uses_distinct_runtime_contract(self):
        result = self.run_sitlctl("start", "2", "rover", "--speedup", "3")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SYSID 21", result.stdout)
        self.assertIn("tcp:localhost:5960", result.stdout)

        environment = (self.state / "ardupilot-sitl-2.env").read_text()
        self.assertIn("SITL_INSTANCE_OFFSET=20\n", environment)
        self.assertIn("SITL_SYSID_BASE=21\n", environment)
        self.assertIn("SITL_PORT_0=5960\n", environment)
        self.assertIn("SITL_PORT_19=6150\n", environment)
        self.assertIn("SITL_VEHICLE=Rover\n", environment)
        self.assertIn("SITL_SPEEDUP=3\n", environment)
        calls = (self.state / "compose.calls").read_text()
        self.assertIn("-p sitlctl-2", calls)

    def test_stopping_one_instance_preserves_the_other(self):
        for instance, vehicle in (("1", "copter"), ("2", "rover")):
            result = self.run_sitlctl("start", instance, vehicle)
            self.assertEqual(result.returncode, 0, result.stderr)

        result = self.run_sitlctl("stop", "1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.state / "ardupilot-sitl-1").exists())
        self.assertTrue((self.state / "ardupilot-sitl-2").exists())

        result = self.run_sitlctl("status", "2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Instance 2: running", result.stdout)
        self.assertIn("SYSID 21", result.stdout)
        self.assertIn("tcp:localhost:5960", result.stdout)

    def test_stop_requires_an_explicit_target(self):
        result = self.run_sitlctl("stop")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("sitlctl stop <1|2|all>", result.stderr)

    def test_unknown_start_option_fails(self):
        result = self.run_sitlctl("start", "1", "copter", "--mystery")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unknown option: --mystery", result.stderr)

    def test_unavailable_heli_is_not_advertised(self):
        result = self.run_sitlctl("start", "1", "copter-heli")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unknown vehicle: copter-heli", result.stderr)


if __name__ == "__main__":
    unittest.main()
