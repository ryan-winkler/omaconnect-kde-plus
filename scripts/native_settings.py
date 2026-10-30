#!/usr/bin/env python3
"""Read or change native KDE Connect module state through its device API.

Read: {"operation":"read","peerId":"peer_1","pluginIds":["kdeconnect_share"]}
Set: {"operation":"set","peerId":"peer_1","pluginId":"kdeconnect_share","enabled":true}
Only an observed native value is returned as enabled. No native files are read.
"""
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import os
import re
import sys
import threading
import time

SERVICE = "org.kde.kdeconnect"
INTERFACE = "org.kde.kdeconnect.device"
PEER_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9_]{0,127}")
PLUGIN_ID = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}")
MAX_INPUT = 65536
MAX_PLUGINS = 256
TIME_BUDGET = 5


class RequestError(Exception):
    pass


def unique_fields(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate-field")
        result[key] = value
    return result


def valid_plugin(value):
    return isinstance(value, str) and PLUGIN_ID.fullmatch(value) is not None


def read_request(stream):
    raw = stream.read(MAX_INPUT + 1)
    if not raw or len(raw) > MAX_INPUT:
        raise RequestError("invalid-input")
    try:
        value = json.loads(raw, object_pairs_hook=unique_fields)
    except (ValueError, UnicodeError):
        raise RequestError("invalid-input") from None
    if not isinstance(value, dict):
        raise RequestError("invalid-input")
    peer, operation = value.get("peerId"), value.get("operation")
    if not isinstance(peer, str) or not PEER_ID.fullmatch(peer):
        raise RequestError("invalid-input")
    if operation == "read" and set(value) == {"operation", "peerId", "pluginIds"}:
        ids = value["pluginIds"]
        if (not isinstance(ids, list) or not 1 <= len(ids) <= MAX_PLUGINS
                or not all(valid_plugin(item) for item in ids) or len(set(ids)) != len(ids)):
            raise RequestError("invalid-input")
    elif operation == "set" and set(value) == {"operation", "peerId", "pluginId", "enabled"}:
        if not valid_plugin(value["pluginId"]) or type(value["enabled"]) is not bool:
            raise RequestError("invalid-input")
    else:
        raise RequestError("invalid-input")
    return value


def operate(bus, Gio, GLib, cancellable, request, deadline=None):
    deadline = time.monotonic() + TIME_BUDGET if deadline is None else deadline
    path = "/modules/kdeconnect/devices/" + request["peerId"]
    result = {"state": "failed", "peerId": request["peerId"], "enabled": {}, "error": ""}
    mutation_started = False

    def call(method, args, interface=INTERFACE, mutation=False):
        nonlocal mutation_started
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RequestError("provider-unavailable")
        try:
            if mutation:
                mutation_started = True
            return bus.call_sync(SERVICE, path, interface, method, args, None,
                                 Gio.DBusCallFlags.NO_AUTO_START,
                                 min(1500, max(1, int(remaining * 1000))), cancellable).unpack()
        except Exception:
            raise RequestError("submission-unknown" if mutation else "provider-unavailable") from None

    def enabled(plugin):
        reply = call("isPluginEnabled", GLib.Variant("(s)", (plugin,)))
        if not isinstance(reply, tuple) or len(reply) != 1 or type(reply[0]) is not bool:
            raise RequestError("provider-unavailable")
        return reply[0]

    try:
        properties = call("GetAll", GLib.Variant("(s)", (INTERFACE,)), "org.freedesktop.DBus.Properties")
        if not isinstance(properties, tuple) or len(properties) != 1 or not isinstance(properties[0], dict):
            raise RequestError("provider-unavailable")
        # Native per-peer preferences remain editable while a paired peer is offline.
        if properties[0].get("isPaired") is not True:
            raise RequestError("capability-unavailable")
        if request["operation"] == "read":
            # GDBusConnection supports calls from multiple threads. The shared
            # deadline/cancellable bounds every worker and queued native request.
            with ThreadPoolExecutor(max_workers=8) as workers:
                pending = {workers.submit(enabled, plugin): plugin for plugin in request["pluginIds"]}
                for future in as_completed(pending):
                    try:
                        result["enabled"][pending[future]] = future.result()
                    except RequestError:
                        result["error"] = "provider-unavailable"
            result["state"] = "failed" if result["error"] else "observed"
        else:
            plugin = request["pluginId"]
            try:
                reply = call("setPluginEnabled", GLib.Variant("(sb)", (plugin, request["enabled"])), mutation=True)
                if reply != ():
                    raise RequestError("submission-unknown")
                actual = enabled(plugin)
            except RequestError:
                # The request might have changed native state before a lost
                # reply or readback. Never retry automatically or invent state.
                result["state"] = "unknown" if mutation_started else "failed"
                result["error"] = "submission-unknown" if mutation_started else "provider-unavailable"
                return result
            result["state"] = "observed"
            result["enabled"][plugin] = actual
            if actual != request["enabled"]:
                result["error"] = "readback-mismatch"
    except RequestError as error:
        result["error"] = str(error)
    except Exception:
        result["state"] = "unknown" if mutation_started else "failed"
        result["error"] = "submission-unknown" if mutation_started else "provider-unavailable"
    return result


def main():
    result = {"state": "failed", "peerId": "", "enabled": {}, "error": "invalid-input"}
    try:
        request = read_request(sys.stdin.buffer)
        result["peerId"] = request["peerId"]
        result["error"] = "provider-unavailable"
        if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
            raise RequestError("provider-unavailable")
        import gi
        gi.require_version("Gio", "2.0")
        gi.require_version("GLib", "2.0")
        from gi.repository import Gio, GLib
        cancellable = Gio.Cancellable()
        deadline = time.monotonic() + TIME_BUDGET
        timer = threading.Timer(TIME_BUDGET, cancellable.cancel)
        timer.daemon = True
        timer.start()
        try:
            bus = Gio.bus_get_sync(Gio.BusType.SESSION, cancellable)
            result = operate(bus, Gio, GLib, cancellable, request, deadline)
        finally:
            timer.cancel()
    except RequestError as error:
        result["error"] = str(error)
    except Exception:
        # operate handles all mutation ambiguity before returning.
        result["error"] = "provider-unavailable"
    print(json.dumps(result, separators=(",", ":")))
    return 0 if result["state"] == "observed" and not result["error"] else 1


if __name__ == "__main__":
    sys.exit(main())
