#!/usr/bin/env python3
"""Focused native-storage contract checks; fake providers and temporary files only."""
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import browse_phone_files as helper


class BrowseContract(unittest.TestCase):
    def test_request_boundary(self):
        """Accept a prepare request and reject malformed, duplicate, oversized or unsupported input."""
        good = {"peerId": "Owned_123", "operation": "prepare"}
        self.assertEqual(helper.read_request(io.BytesIO(json.dumps(good).encode())), good)
        bad = [b'', b'[]', b'{"peerId":"a","peerId":"b","operation":"prepare"}',
               b'{"peerId":"../peer","operation":"prepare"}',
               b'{"peerId":"a-b","operation":"prepare"}',
               b'{"peerId":"a","operation":"prepare","path":"/tmp"}',
               b'{"peerId":"a","operation":"open","location":{}}',
               b'x' * (helper.MAX_INPUT + 1), b'\xff',
               b'{"peerId":"a","operation":"prepare","extra":NaN}']
        for raw in bad:
            with self.subTest(raw=raw[:80]), self.assertRaisesRegex(helper.BrowseError, "invalid-input"):
                helper.read_request(io.BytesIO(raw))

    def test_filesystem_boundary(self):
        """Use temporary roots to reject escapes, symlinks, missing paths and unverified mounts."""
        with tempfile.TemporaryDirectory() as temporary:
            mount = Path(temporary) / "mount"
            mount.mkdir()
            root = mount / "share"
            root.mkdir()
            (mount / "link").symlink_to(root, target_is_directory=True)
            with patch.object(helper, "mount_record", return_value=["owned-mount-42"]):
                identity, roots = helper.inspect_paths(str(mount), [str(root)])
                self.assertEqual(len(identity), 64)
                self.assertIn(str(root), roots)
                for path in [temporary, str(mount / "link"), str(root / ".."), str(mount / "missing")]:
                    with self.subTest(path=path), self.assertRaises(helper.BrowseError):
                        helper.inspect_paths(str(mount), [path])
            with self.assertRaisesRegex(helper.BrowseError, "storage-unavailable"):
                helper.inspect_paths(str(mount), [str(root)])

    def test_mountinfo_boundary(self):
        """Decode mount escapes and reject non-SSHFS, duplicate, missing or oversized mount records."""
        record = '42 2 0:99 / /owned\\040mount rw - fuse.sshfs owned rw\n'
        with patch("builtins.open", return_value=io.StringIO(record)):
            self.assertEqual(helper.mount_record("/owned mount")[0], "42")
        for data in [record.replace("fuse.sshfs", "ext4"), record + record, "", "x" * (1024 * 1024 + 1)]:
            with patch("builtins.open", return_value=io.StringIO(data)), self.assertRaises(helper.BrowseError):
                helper.mount_record("/owned mount")

    def test_fixed_cli_errors_and_no_bus_autolaunch(self):
        """Verify fixed CLI failures with no session-bus address and no remote diagnostic output."""
        for args, request, expected in [([], b'{}\n', "invalid-input"), (["unexpected"], b'', "invalid-input"),
                                        ([], b'{"peerId":"Owned_1","operation":"prepare"}\n', "provider-unavailable")]:
            env = dict(os.environ)
            env.pop("DBUS_SESSION_BUS_ADDRESS", None)
            result = subprocess.run([sys.executable, str(ROOT / "scripts/browse_phone_files.py"), *args],
                                    input=request, capture_output=True, env=env, timeout=2)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stderr, b'')
            self.assertEqual(json.loads(result.stdout), {"state": "failed", "error": expected})

    def test_stalled_probe_deadline_and_cancel(self):
        # Test-only process shim. Production has no environment or argv test switch.
        code = ("import sys,time;sys.path.insert(0," + repr(str(ROOT / "scripts")) + ");"
                "import browse_phone_files as h;h.TOTAL_SECONDS=0.2;"
                "h.execute=lambda *args: time.sleep(10);raise SystemExit(h.main())")
        started = time.monotonic()
        result = subprocess.run([sys.executable, "-c", code],
                                input=b'{"peerId":"Owned_1","operation":"prepare"}\n',
                                capture_output=True, timeout=2)
        self.assertLess(time.monotonic() - started, 1)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stderr, b'')
        self.assertEqual(json.loads(result.stdout), {"state": "failed", "error": "storage-timeout"})
        child = subprocess.Popen([sys.executable, "-c", code.replace("h.TOTAL_SECONDS=0.2", "h.TOTAL_SECONDS=27")],
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        child.stdin.write(b'{"peerId":"Owned_1","operation":"prepare"}\n')
        child.stdin.flush()
        time.sleep(0.1)
        child.terminate()
        output, error = child.communicate(timeout=2)
        self.assertEqual(child.returncode, 1)
        self.assertEqual(error, b'')
        self.assertEqual(json.loads(output), {"state": "failed", "error": "cancelled"})

    def test_missing_default_opener(self):
        from gi.repository import Gio
        with patch.object(Gio.AppInfo, "get_default_for_type", return_value=None), \
                patch.object(Gio.AppInfo, "launch_default_for_uri") as launch:
            with self.assertRaisesRegex(helper.BrowseError, "opener-unavailable"):
                helper.launch_uri("file:///owned/fixture")
            launch.assert_not_called()

    def test_output_bound(self):
        with patch("builtins.print") as output:
            self.assertEqual(helper.emit({"state": "prepared", "locations": ["x" * 16384]}), 1)
            self.assertEqual(json.loads(output.call_args.args[0]), {"state": "failed", "error": "share-limit"})

    def test_private_bus_contract(self):
        """Run each storage failure mode on a private bus with temporary home and runtime state."""
        modes = ["single", "multiple", "remote-name", "offline", "unpaired", "unsupported", "unsupported-method",
                 "unavailable", "no-shares", "share-limit", "escape", "symlink", "nonmount", "mount-failed",
                 "remote-error", "mount-visible-late", "mount-never-visible", "mount-visibility-cancelled",
                 "owner-replaced-during-visibility", "offline-during-visibility", "changed-advertisement", "changed-name", "stale-mount", "stale-root",
                 "owner-changed", "offline-open", "unpaired-open", "unmounted-open", "cancelled", "missing-opener",
                 "cancelled-mount", "offline-during-mount", "owner-lost-during-probe",
                 "owner-replaced-during-probe", "offline-during-probe", "timeout"]
        for mode in modes:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                env = dict(os.environ, HOME=temporary, XDG_RUNTIME_DIR=temporary, XDG_CONFIG_HOME=temporary)
                result = subprocess.run(["dbus-run-session", "--", sys.executable,
                                         str(ROOT / "tests/fake_sftp_provider.py"), mode],
                                        env=env, capture_output=True, timeout=12)
                self.assertEqual(result.returncode, 0, result.stdout.decode() + result.stderr.decode())
                self.assertTrue(json.loads(result.stdout)["passed"])
                self.assertEqual(result.stderr, b'')


if __name__ == "__main__":
    unittest.main()
