"""Only run on an owned dbus-run-session bus by test_transfer.py.

argv: MODE COMMAND... ; stdin: one submit request line for COMMAND.
Prints one JSON report with the helper's output and each share call it made.
"""

import json
import os
from pathlib import Path
import signal
import subprocess
import sys
from urllib.parse import unquote, urlsplit

import gi
gi.require_version("Gio", "2.0")
gi.require_version("GLib", "2.0")
from gi.repository import Gio, GLib

PEER = "reviewed_peer"
mode, command = sys.argv[1], sys.argv[2:]
request = sys.stdin.readline()
calls, held = [], []
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
loop = GLib.MainLoop()


def method(connection, sender, path, interface, name, parameters, invocation):
    urls = parameters.unpack()[0]
    pid = bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                        "GetConnectionUnixProcessID", GLib.Variant("(s)", (sender,)),
                        GLib.VariantType.new("(u)"), Gio.DBusCallFlags.NONE, 1000, None).unpack()[0]
    # What KDE's QUrl(url).toLocalFile() opens later.
    local = unquote(urlsplit(urls[0]).path, errors="strict")
    call = {"path": path, "interface": interface, "method": name, "urls": urls, "local": local,
            "argv": Path(f"/proc/{pid}/cmdline").read_bytes().decode("utf-8", "replace").split("\0")}
    calls.append(call)
    if mode == "replace":
        original = Path(os.environ["OWNED_ORIGINAL"])
        original.unlink()
        original.symlink_to(os.environ["OWNED_SECRET"])
        call["bytes"] = Path(local).read_bytes().hex()
    if mode == "fail":
        invocation.return_dbus_error("org.example.Rejected", "Do not log " + local)
    elif mode in ("hang", "cancel"):
        held.append(invocation)
        if mode == "cancel":
            child.send_signal(signal.SIGTERM)
    else:
        invocation.return_value(GLib.Variant("()", ()))


if mode != "unavailable":
    bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "RequestName",
                  GLib.Variant("(su)", ("org.kde.kdeconnect", 0)), GLib.VariantType.new("(u)"),
                  Gio.DBusCallFlags.NO_AUTO_START, 1000, None)
    xml = ('<node><interface name="org.kde.kdeconnect.device.share"><method name="shareUrls">'
           '<arg type="as" direction="in"/></method></interface></node>')
    bus.register_object("/modules/kdeconnect/devices/" + PEER + "/share",
                        Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0], method, None, None)

child = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, text=True)
child.stdin.write(request)
child.stdin.flush()


def done():
    if child.poll() is None:
        return GLib.SOURCE_CONTINUE
    output, error = child.communicate()
    print(json.dumps({"returncode": child.returncode, "stdout": output, "stderr": error, "calls": calls}))
    loop.quit()
    return GLib.SOURCE_REMOVE


def expired():
    child.kill()
    return GLib.SOURCE_REMOVE


GLib.timeout_add(20, done)
GLib.timeout_add_seconds(10, expired)
loop.run()
