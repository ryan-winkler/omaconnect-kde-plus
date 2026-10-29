"""Only run on an owned dbus-run-session bus by test_text_privacy.py."""

import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import time

import gi
gi.require_version("Gio", "2.0")
gi.require_version("GLib", "2.0")
from gi.repository import Gio, GLib

ROOT = Path(__file__).resolve().parents[1]
PEER = "Owned_device_123"

if sys.argv[1] == "activation":
    Path(os.environ["HOME"], "UNEXPECTED_ACTIVATION").touch()
    raise SystemExit(1)

mode = sys.argv[1]
operation = "ping" if mode == "ping" else "text"
# Generate owned test content in memory; never place it in argv/env or a file.
sentinel = "TEXT-PRIVATE-" + secrets.token_hex(12)
payload = sentinel + ' quotes " apostrophe \' newline\nemoji \U0001f4f1 @local-test <b>plain</b>'
request = {"peerId": PEER, "operation": operation, "text": payload}
calls = []
failure = []
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
loop = GLib.MainLoop()
started = time.monotonic()


def method(connection, sender, path, interface, name, parameters, invocation):
    calls.append((path, interface, name, parameters.get_type_string(), parameters.unpack()))
    expected = ("/modules/kdeconnect/devices/" + PEER + ("/ping" if operation == "ping" else "/share"),
                "org.kde.kdeconnect.device." + ("ping" if operation == "ping" else "share"),
                "sendPing" if operation == "ping" else "shareText", "(s)", (payload,))
    if calls[-1] != expected:
        failure.append("wrong-method-or-payload")

    def inspect_and_reply():
        try:
            argv = Path(f"/proc/{child.pid}/cmdline").read_bytes()
            environment = Path(f"/proc/{child.pid}/environ").read_bytes()
            if b"send_text.py" not in argv or b"HOME=" not in environment:
                failure.append("process-metadata-probe-empty")
            if sentinel.encode() in argv or sentinel.encode() in environment:
                failure.append("process-metadata-leak")
            if mode == "remote-error":
                invocation.return_dbus_error("org.example.Rejected", "Do not log " + payload)
            elif mode == "missing-method":
                invocation.return_dbus_error("org.freedesktop.DBus.Error.UnknownMethod", "Do not log " + payload)
            elif mode == "timeout":
                # Retain the invocation beyond the helper's fixed deadline.
                held.append(invocation)
            else:
                invocation.return_value(GLib.Variant("()", ()))
        except Exception:
            failure.append("metadata-probe-failed")
            invocation.return_dbus_error("org.example.FixtureFailure", "owned fixture failure")
        return GLib.SOURCE_REMOVE

    # The helper stays alive with the request in memory while /proc is inspected.
    GLib.timeout_add(250, inspect_and_reply)


held = []
if mode != "unavailable":
    bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "RequestName",
                  GLib.Variant("(su)", ("org.kde.kdeconnect", 0)), GLib.VariantType.new("(u)"),
                  Gio.DBusCallFlags.NO_AUTO_START, 1000, None)
    for component, interface, member in [("share", "org.kde.kdeconnect.device.share", "shareText"), ("ping", "org.kde.kdeconnect.device.ping", "sendPing")]:
        xml = '<node><interface name="' + interface + '"><method name="' + member + '"><arg type="s" direction="in"/></method></interface></node>'
        info = Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0]
        bus.register_object("/modules/kdeconnect/devices/" + PEER + "/" + component, info, method, None, None)

child = subprocess.Popen([sys.executable, str(ROOT / "scripts/send_text.py")], stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
child.stdin.write((json.dumps(request, ensure_ascii=True) + "\n").encode())
child.stdin.flush()
# Keep stdin open: a JSON line must be sufficient and must not wait for EOF.


def done():
    if child.poll() is None:
        return GLib.SOURCE_CONTINUE
    child.stdin.close()
    child.stdin = None
    output, error = child.communicate()
    expected = {"state": "request_accepted", "error": ""}
    if mode in {"remote-error", "missing-method", "timeout", "unavailable"}:
        expected = {"state": "failed", "error": {"remote-error": "submission-failed", "missing-method": "capability-unavailable", "timeout": "submission-unknown", "unavailable": "provider-unavailable"}[mode]}
    try:
        if json.loads(output) != expected or bool(child.returncode) != (mode in {"remote-error", "missing-method", "timeout", "unavailable"}):
            failure.append("wrong-fixed-result")
    except ValueError:
        failure.append("invalid-result")
    if sentinel.encode() in output + error or payload.encode() in output + error or error:
        failure.append("output-leak")
    if len(calls) != (0 if mode == "unavailable" else 1):
        failure.append("unexpected-call-count")
    if Path(os.environ["HOME"], "UNEXPECTED_ACTIVATION").exists():
        failure.append("service-auto-started")
    # Inspect only this fixture's private directory, never user files or other projects.
    for item in Path(os.environ["HOME"]).rglob("*"):
        if item.is_file() and sentinel.encode() in item.read_bytes():
            failure.append("owned-file-leak")
    elapsed = time.monotonic() - started
    if mode == "timeout" and not 4.5 <= elapsed <= 6.5:
        failure.append("timeout-not-bounded")
    print(json.dumps({"passed": not failure, "checks": sorted(set(failure)), "mode": mode}), flush=True)
    loop.quit()
    return GLib.SOURCE_REMOVE


def expired():
    child.kill()
    child.wait()
    print(json.dumps({"passed": False, "checks": ["fixture-deadline"], "mode": mode}), flush=True)
    loop.quit()
    return GLib.SOURCE_REMOVE


GLib.timeout_add(20, done)
GLib.timeout_add_seconds(8, expired)
loop.run()
if failure or child.returncode is None:
    raise SystemExit(1)
