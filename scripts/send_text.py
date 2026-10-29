#!/usr/bin/env python3
"""Submit one text/ping request from a bounded JSON stdin line, never argv."""

import json
import os
import re
import resource
import sys
import threading

MAX_INPUT = 65536
MAX_TEXT = 8192
TIMEOUT_MS = 5000
DEVICE_ID = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}\Z")
SERVICE = "org.kde.kdeconnect"
OPERATIONS = {
    "text": ("share", "org.kde.kdeconnect.device.share", "shareText"),
    "ping": ("ping", "org.kde.kdeconnect.device.ping", "sendPing"),
}


class SubmissionError(Exception):
    pass


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate-field")
        result[key] = value
    return result


def read_request(stream):
    raw = stream.readline(MAX_INPUT + 1)
    if not raw or len(raw) > MAX_INPUT:
        raise SubmissionError("invalid-input")
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object)
    except (UnicodeError, ValueError, RecursionError):
        raise SubmissionError("invalid-input") from None
    if not isinstance(value, dict) or set(value) != {"peerId", "operation", "text"}:
        raise SubmissionError("invalid-input")
    peer, operation, text = value["peerId"], value["operation"], value["text"]
    if (not isinstance(peer, str) or not DEVICE_ID.fullmatch(peer)
            or not isinstance(operation, str) or operation not in OPERATIONS
            or not isinstance(text, str) or len(text) > MAX_TEXT or "\0" in text
            or (operation == "text" and not text)):
        raise SubmissionError("invalid-input")
    try:
        text.encode("utf-8", "strict")
    except UnicodeError:
        raise SubmissionError("invalid-input") from None
    return peer, operation, text


def submit(peer, operation, text):
    # Do not let a missing session address trigger session-bus autolaunch.
    if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        raise SubmissionError("provider-unavailable")
    try:
        import gi
        gi.require_version("Gio", "2.0")
        gi.require_version("GLib", "2.0")
        from gi.repository import Gio, GLib
    except (ImportError, ValueError):
        raise SubmissionError("provider-unavailable") from None
    component, interface, method = OPERATIONS[operation]
    path = "/modules/kdeconnect/devices/" + peer + "/" + component
    # The launcher grammar is broad; D-Bus path components have a narrower grammar.
    # Check before Gio can emit an invalid-path diagnostic containing input data.
    if not GLib.Variant.is_object_path(path):
        raise SubmissionError("invalid-input")
    cancellable = Gio.Cancellable()
    timer = threading.Timer(TIMEOUT_MS / 1000, cancellable.cancel)
    timer.daemon = True
    attempted = False
    timer.start()
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, cancellable)
        attempted = True
        bus.call_sync(SERVICE, path, interface, method, GLib.Variant("(s)", (text,)),
                      GLib.VariantType.new("()"), Gio.DBusCallFlags.NO_AUTO_START,
                      TIMEOUT_MS, cancellable)
    except GLib.Error as error:
        remote = Gio.DBusError.get_remote_error(error)
        if remote in {"org.freedesktop.DBus.Error.ServiceUnknown", "org.freedesktop.DBus.Error.NameHasNoOwner"}:
            code = "provider-unavailable"
        elif remote in {"org.freedesktop.DBus.Error.UnknownObject", "org.freedesktop.DBus.Error.UnknownInterface", "org.freedesktop.DBus.Error.UnknownMethod"}:
            code = "capability-unavailable"
        elif (remote in {"org.freedesktop.DBus.Error.NoReply", "org.freedesktop.DBus.Error.Timeout", "org.freedesktop.DBus.Error.TimedOut", "org.freedesktop.DBus.Error.Disconnected"}
              or error.matches(Gio.io_error_quark(), Gio.IOErrorEnum.TIMED_OUT)
              or error.matches(Gio.io_error_quark(), Gio.IOErrorEnum.CANCELLED)
              or error.matches(Gio.io_error_quark(), Gio.IOErrorEnum.CLOSED)):
            code = "submission-unknown" if attempted else "provider-unavailable"
        else:
            code = "submission-failed" if attempted else "provider-unavailable"
        raise SubmissionError(code) from None
    finally:
        timer.cancel()


def emit(state, error):
    print(json.dumps({"state": state, "error": error}, separators=(",", ":")), flush=True)


def main():
    try:
        # Request text must not become a helper core file if a native library fails.
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        if len(sys.argv) != 1:
            raise SubmissionError("invalid-input")
        request = read_request(sys.stdin.buffer)
        submit(*request)
    except SubmissionError as error:
        emit("failed", str(error))
        return 1
    except Exception:
        # Never reflect exceptions, D-Bus error bodies, IDs or request text.
        emit("failed", "submission-failed")
        return 1
    emit("request_accepted", "")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
