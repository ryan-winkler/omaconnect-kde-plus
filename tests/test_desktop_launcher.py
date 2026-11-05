"""Exercise the optional desktop entry through GLib with owned commands."""
import json
import os
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

from gi.repository import Gio

ROOT = Path(__file__).resolve().parents[1]


class DesktopLauncher(unittest.TestCase):
    @patch.dict(os.environ, {"GIO_USE_VFS": "local"})
    def test_routes_and_inactive_feedback_use_fixed_arguments(self):
        """Check the three GLib routes, ignored file input, and inactive notice."""
        with tempfile.TemporaryDirectory(prefix="plus-launcher-") as directory:
            fixture = Path(directory)
            log = fixture / "calls.jsonl"
            commands = {
                "/usr/bin/omarchy-shell": fixture / "shell",
                "/usr/bin/omarchy notification": fixture / "notify",
            }
            for executable in commands.values():
                fail = executable.name == "shell"
                executable.write_text(
                    "#!/usr/bin/python3\n"
                    "import json, os, sys\n"
                    f"with open({str(log)!r}, 'a') as stream:\n"
                    "    stream.write(json.dumps([os.path.basename(sys.argv[0]), *sys.argv[1:]]) + '\\n')\n"
                    f"sys.exit(1 if {fail!r} and os.environ.get('PLUS_TEST_DISABLED') == '1' else 0)\n"
                )
                executable.chmod(0o700)
            launcher = fixture / "omaconnect.plus.desktop"
            source = (ROOT / "launcher" / launcher.name).read_text()
            for original, executable in commands.items():
                source = source.replace(original, str(executable))
            launcher.write_text(source)
            app = Gio.DesktopAppInfo.new_from_filename(str(launcher))
            self.assertIsNotNone(app)
            self.assertEqual(list(app.list_actions()), ["SendFiles", "Activity"])
            unexpected = fixture / "unexpected"
            untrusted = Gio.File.new_for_path(str(fixture / f"ignored %f; touch {unexpected.name}"))

            def expect(count):
                """Wait for the asynchronous desktop commands to record their arguments."""
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline:
                    if log.exists():
                        rows = log.read_text().splitlines()
                        if len(rows) >= count:
                            return [json.loads(row) for row in rows]
                    time.sleep(0.02)
                self.fail(f"Expected {count} owned calls")

            self.assertTrue(app.launch([untrusted], None))
            self.assertEqual(expect(1), [["shell", "omaconnect.plus", "open"]])
            app.launch_action("SendFiles", None)
            self.assertEqual(expect(2)[-1], ["shell", "omaconnect.plus", "sendWindow"])
            app.launch_action("Activity", None)
            self.assertEqual(expect(3)[-1], ["shell", "omaconnect.plus", "activity"])
            context = Gio.AppLaunchContext()
            context.setenv("PLUS_TEST_DISABLED", "1")
            app.launch_action("SendFiles", context)
            self.assertEqual(expect(5)[-2:], [
                ["shell", "omaconnect.plus", "sendWindow"],
                ["notify", "send", "Omaconnect KDE Plus unavailable",
                 "Check that Plus is enabled and present in the Omarchy bar."],
            ])
            self.assertFalse(unexpected.exists())
