import json
import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
ENTRYPOINT = REPO / "docker-entrypoint.sh"


class EntrypointTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name) / "ardupilot"
        self.sim_vehicle = self.root / "Tools" / "autotest" / "sim_vehicle.py"
        self.sim_vehicle.parent.mkdir(parents=True)
        self.sim_vehicle.write_text(
            textwrap.dedent(
                """\
                #!/usr/bin/env python3
                import json
                import os
                import sys
                from pathlib import Path

                Path(os.environ["CAPTURE_ARGS"]).write_text(json.dumps(sys.argv[1:]))
                """
            )
        )
        self.sim_vehicle.chmod(0o755)
        self.capture = Path(self.temporary_directory.name) / "args.json"
        self.state_directory = Path(self.temporary_directory.name) / "state"

    def tearDown(self):
        self.temporary_directory.cleanup()

    def run_entrypoint(self, vehicle, frame, **overrides):
        environment = os.environ.copy()
        environment.update(
            {
                "ARDUPILOT_ROOT": str(self.root),
                "CAPTURE_ARGS": str(self.capture),
                "SITL_FRAME": frame,
                "SITL_INSTANCE": "1",
                "SITL_INSTANCE_OFFSET": "0",
                "SITL_LOCATION": "MAVPROXY_USGS1M",
                "SITL_PORT_BASE": "5760",
                "SITL_SPEEDUP": "1",
                "SITL_STATE_DIR": str(self.state_directory),
                "SITL_SYSID_BASE": "1",
                "SITL_VEHICLE": vehicle,
                "SITL_WIPE": "false",
                "SWARM_MODE": "false",
            }
        )
        environment.update(overrides)
        result = subprocess.run(
            ["bash", str(ENTRYPOINT)],
            cwd=REPO,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        arguments = json.loads(self.capture.read_text()) if self.capture.exists() else []
        return result, arguments

    @staticmethod
    def option_value(arguments, option):
        index = arguments.index(option)
        return arguments[index + 1]

    def test_single_vehicle_frames_use_sim_vehicle_metadata(self):
        cases = (
            ("ArduPlane", "plane"),
            ("ArduPlane", "quadplane"),
            ("ArduCopter", "quad"),
            ("ArduCopter", "hexa"),
            ("ArduCopter", "octa"),
            ("ArduCopter", "tri"),
            ("Rover", "rover"),
            ("Rover", "rover-skid"),
        )

        for vehicle, frame in cases:
            with self.subTest(vehicle=vehicle, frame=frame):
                self.capture.unlink(missing_ok=True)
                result, arguments = self.run_entrypoint(vehicle, frame)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.option_value(arguments, "-v"), vehicle)
                self.assertEqual(self.option_value(arguments, "-f"), frame)
                self.assertEqual(self.option_value(arguments, "-I"), "0")
                self.assertEqual(self.option_value(arguments, "--sysid"), "1")
                self.assertEqual(
                    self.option_value(arguments, "--use-dir"),
                    str(self.state_directory),
                )
                self.assertIn("--no-mavproxy", arguments)
                self.assertIn("--no-rebuild", arguments)
                self.assertNotIn("--count", arguments)
                self.assertNotIn("--auto-sysid", arguments)

    def test_second_instance_single_vehicle_keeps_offset_and_sysid(self):
        result, arguments = self.run_entrypoint(
            "Rover",
            "rover-skid",
            SITL_INSTANCE="2",
            SITL_INSTANCE_OFFSET="20",
            SITL_PORT_BASE="5960",
            SITL_SYSID_BASE="21",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.option_value(arguments, "-I"), "20")
        self.assertEqual(self.option_value(arguments, "--sysid"), "21")

    def test_swarm_uses_auto_sysids_and_the_instance_state_root(self):
        result, arguments = self.run_entrypoint(
            "ArduCopter",
            "quad",
            SITL_INSTANCE="2",
            SITL_INSTANCE_OFFSET="20",
            SITL_PORT_BASE="5960",
            SITL_SYSID_BASE="21",
            SWARM_COUNT="2",
            SWARM_MODE="true",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.option_value(arguments, "--count"), "2")
        self.assertIn("--auto-sysid", arguments)
        self.assertNotIn("--sysid", arguments)
        self.assertEqual(
            self.option_value(arguments, "--use-dir"),
            str(self.state_directory),
        )


if __name__ == "__main__":
    unittest.main()
