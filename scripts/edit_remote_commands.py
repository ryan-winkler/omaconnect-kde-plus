#!/usr/bin/env python3
"""Request the selected peer's native command editor. No command configuration."""
import json
import os
import re
import sys
import threading

SERVICE = "org.kde.kdeconnect"
INTERFACE = "org.kde.kdeconnect.device.remotecommands"
DEVICE_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9_]{0,127}")


class RequestError(Exception):
    pass


def unique_fields(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate-field")
        result[key] = value
    return result


def read_request(stream):
    raw = stream.readline(513)
    if not raw or len(raw) > 512:
        raise RequestError("invalid-input")
    try:
        value = json.loads(raw, object_pairs_hook=unique_fields)
    except (ValueError, UnicodeError):
        raise RequestError("invalid-input") from None
    if not isinstance(value, dict) or set(value) != {"peerId"}:
        raise RequestError("invalid-input")
    peer = value["peerId"]
    if not isinstance(peer, str) or not DEVICE_ID.fullmatch(peer):
        raise RequestError("invalid-input")
    return peer


def operate(bus, Gio, GLib, cancellable, peer):
    path = "/modules/kdeconnect/devices/" + peer

    def call(target, interface, method, args):
        try:
            return bus.call_sync(SERVICE, target, interface, method, args, None,
                                 Gio.DBusCallFlags.NO_AUTO_START, 1500, cancellable).unpack()
        except Exception:
            raise RequestError("provider-unavailable" if method == "GetAll" else "submission-unknown") from None

    def properties(target, interface):
        reply = call(target, "org.freedesktop.DBus.Properties", "GetAll", GLib.Variant("(s)", (interface,)))
        if len(reply) != 1 or not isinstance(reply[0], dict):
            raise RequestError("provider-unavailable")
        return reply[0]

    # Re-read the native prerequisites when the user requests the editor.
    device = properties(path, "org.kde.kdeconnect.device")
    if device.get("isPaired") is not True or device.get("isReachable") is not True:
        raise RequestError("capability-unavailable")
    target = path + "/remotecommands"
    if properties(target, INTERFACE).get("canAddCommand") is not True:
        raise RequestError("capability-unavailable")
    if call(target, INTERFACE, "editCommands", None) != ():
        raise RequestError("submission-unknown")


def main():
    try:
        peer = read_request(sys.stdin.buffer)
        if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
            raise RequestError("provider-unavailable")
        import gi
        gi.require_version("Gio", "2.0")
        gi.require_version("GLib", "2.0")
        from gi.repository import Gio, GLib
        cancellable = Gio.Cancellable()
        timer = threading.Timer(5, cancellable.cancel)
        timer.daemon = True
        timer.start()
        try:
            bus = Gio.bus_get_sync(Gio.BusType.SESSION, cancellable)
            operate(bus, Gio, GLib, cancellable, peer)
        finally:
            timer.cancel()
    except RequestError as error:
        print(json.dumps({"state": "failed", "error": str(error)}))
        return 1
    except (ImportError, ValueError):
        print(json.dumps({"state": "failed", "error": "provider-unavailable"}))
        return 1
    except Exception:
        # A failed reply can follow submission. Never encourage automatic retry.
        print(json.dumps({"state": "failed", "error": "submission-unknown"}))
        return 1
    print(json.dumps({"state": "request_accepted", "error": ""}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
