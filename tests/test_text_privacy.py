import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/send_text.py"
FIXTURE = ROOT / "tests/fake_text_provider.py"
spec = importlib.util.spec_from_file_location("send_text", HELPER)
send_text = importlib.util.module_from_spec(spec)
spec.loader.exec_module(send_text)
HAS_GIO = importlib.util.find_spec("gi") is not None


def encoded(value):
    return (json.dumps(value, ensure_ascii=True) + "\n").encode()


class TextInputPrivacy(unittest.TestCase):
    def test_bounded_parser_preserves_unicode_whitespace_and_exact_operation(self):
        text = "line one\nline two\t \U0001f4f1 ' \" <b>plain</b>"
        self.assertEqual(send_text.read_request(io.BytesIO(encoded({"peerId": "Owned_123", "operation": "text", "text": text}))), ("Owned_123", "text", text))
        self.assertEqual(send_text.read_request(io.BytesIO(encoded({"peerId": "Owned_123", "operation": "ping", "text": ""}))), ("Owned_123", "ping", ""))
        send_text.read_request(io.BytesIO(encoded({"peerId": "_" + "a" * 127, "operation": "text", "text": "x" * 8192})))

    def test_malformed_types_identity_size_and_control_bytes_are_rejected(self):
        valid = {"peerId": "Owned_123", "operation": "text", "text": "OWNED-PRIVATE-SENTINEL"}
        invalid = [None, [], {}, {**valid, "extra": "data"}, {**valid, "text": None}, {**valid, "text": ""}, {**valid, "text": "x" * 8193}, {**valid, "text": "a\0b"}, {**valid, "text": "\ud800"}, {**valid, "peerId": "../peer"}, {**valid, "peerId": "-device"}, {**valid, "peerId": "a" * 129}, {**valid, "peerId": "peer\nOTHER"}, {**valid, "peerId": True}, {**valid, "operation": "shareText"}, {**valid, "operation": {}}]
        for value in invalid:
            with self.subTest(kind=type(value).__name__):
                with self.assertRaisesRegex(send_text.SubmissionError, "^invalid-input$"):
                    send_text.read_request(io.BytesIO(encoded(value)))
        for raw in (b"", b"not JSON\n", b'{"peerId":"a","peerId":"b","operation":"text","text":"test"}\n', b"x" * 65537, b"\xff\n"):
            with self.assertRaisesRegex(send_text.SubmissionError, "^invalid-input$"):
                send_text.read_request(io.BytesIO(raw))

    def test_cli_invalid_unavailable_and_extra_argv_never_reflect_payload(self):
        sentinel = "OWNED-PRIVATE-SENTINEL"
        cases = [(encoded({"peerId": "bad/" + sentinel, "operation": "text", "text": sentinel}), [], "invalid-input"), (encoded({"peerId": "Owned_123", "operation": "text", "text": sentinel}), [], "provider-unavailable"), (b"{}\n", ["unsupported"], "invalid-input")]
        for data, args, expected in cases:
            with self.subTest(expected=expected), tempfile.TemporaryDirectory(prefix="omaconnect-text-invalid-") as temporary:
                env = {"PATH": "/usr/bin", "HOME": temporary, "LANG": "C.UTF-8", "PYTHONDONTWRITEBYTECODE": "1"}
                result = subprocess.run([sys.executable, str(HELPER), *args], input=data, env=env, capture_output=True, timeout=3)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(json.loads(result.stdout), {"state": "failed", "error": expected})
                self.assertNotIn(sentinel.encode(), result.stdout + result.stderr)
                self.assertEqual(result.stderr, b"")
                self.assertEqual(list(Path(temporary).iterdir()), [])


@unittest.skipUnless(HAS_GIO and shutil.which("dbus-run-session"), "Gio/private D-Bus fixture unavailable")
class PrivateTextBus(unittest.TestCase):
    def test_exact_native_methods_have_private_process_metadata_and_fixed_results(self):
        # Every service call happens on a fresh private bus with an owned fake name.
        for mode in ("text", "ping", "remote-error", "missing-method", "timeout", "unavailable"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix="omaconnect-text-bus-") as temporary:
                root = Path(temporary)
                (root / "runtime").mkdir(mode=0o700)
                service_dir = root / "data/dbus-1/services"
                service_dir.mkdir(parents=True)
                # If NO_AUTO_START is lost, the owned fake activation records that failure.
                (service_dir / "org.kde.kdeconnect.service").write_text("[D-BUS Service]\nName=org.kde.kdeconnect\nExec=" + sys.executable + " " + str(FIXTURE) + " activation\n")
                env = {"PATH": "/usr/bin", "HOME": temporary, "XDG_DATA_HOME": str(root / "data"), "XDG_DATA_DIRS": str(root / "no-system-data"), "XDG_CONFIG_HOME": str(root / "config"), "XDG_RUNTIME_DIR": str(root / "runtime"), "DBUS_SYSTEM_BUS_ADDRESS": "unix:path=" + str(root / "no-system-bus"), "LANG": "C.UTF-8", "PYTHONDONTWRITEBYTECODE": "1"}
                result = subprocess.run(["dbus-run-session", "--", sys.executable, str(FIXTURE), mode], env=env, capture_output=True, text=True, timeout=11)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(json.loads(result.stdout), {"passed": True, "checks": [], "mode": mode})
                self.assertEqual(result.stderr, "")
                self.assertFalse((root / "UNEXPECTED_ACTIVATION").exists())


if __name__ == "__main__":
    unittest.main()
