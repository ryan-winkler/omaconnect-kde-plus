#!/usr/bin/python3
"""One bounded Plus notice over the native notification bus, with no private argv."""
import json
import os
import resource
import sys
import unicodedata

MAX_INPUT = 8192
APP_NAME = "Omaconnect KDE Plus"
ACTIVITY_ARGV = ["/usr/bin/omarchy-shell", "omaconnect.plus", "activity"]


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError()
        result[key] = value
    return result


def read_request(stream):
    raw = stream.read(MAX_INPUT + 1)
    if not raw or len(raw) > MAX_INPUT:
        raise ValueError()
    value = json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object)
    if not isinstance(value, dict) or set(value) != {"summary", "body", "includeDeviceName", "deviceName"}:
        raise ValueError()
    for key, limit in (("summary", 256), ("body", 1024), ("deviceName", 256)):
        text = value[key]
        if not isinstance(text, str) or len(text) > limit or "\0" in text:
            raise ValueError()
        text.encode("utf-8", "strict")
    if not value["summary"] or not value["body"] or type(value["includeDeviceName"]) is not bool:
        raise ValueError()
    if not value["includeDeviceName"] and value["deviceName"]:
        raise ValueError()
    return value


def plain_name(value):
    # Omarchy decodes entities before rendering markup. HTML escaping alone
    # would revive a remote tag. Neutralize syntax and automatic URL linking.
    value = "".join(char for char in value if unicodedata.category(char) not in {"Cc", "Cf"})
    value = " ".join(value.split())[:128]
    return value.translate(str.maketrans({"<": "‹", ">": "›", "&": "＆", ":": "∶"}))


def parameters(value, GLib):
    body = value["body"]
    if value["includeDeviceName"]:
        name = plain_name(value["deviceName"])
        if name:
            body += "\n" + name
    # Same fixed Omarchy hints as `omarchy notification send --action`.
    # The fixed action is safe after history replay and does not identify a task.
    action = {"label": "Activity", "argv": ACTIVITY_ARGV}
    hints = {
        "urgency": GLib.Variant("y", 1),
        "omarchy-exec-argv": GLib.Variant("s", json.dumps(ACTIVITY_ARGV)),
        "omarchy-actions": GLib.Variant("s", json.dumps([action]))
    }
    return GLib.Variant("(susssasa{sv}i)", (APP_NAME, 0, "kdeconnect", value["summary"], body, [], hints, -1))


def notify(value):
    # A missing session address must not start a different bus or service.
    if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        raise ValueError()
    from gi.repository import Gio, GLib
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    bus.call_sync("org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                  "org.freedesktop.Notifications", "Notify", parameters(value, GLib),
                  GLib.VariantType.new("(u)"), Gio.DBusCallFlags.NO_AUTO_START, 3500, None)


def main():
    try:
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        if len(sys.argv) != 1:
            raise ValueError()
        notify(read_request(sys.stdin.buffer))
    except Exception:
        # Do not echo bus errors, request content, names or tracebacks.
        print('{"ok":false}')
        return 1
    print('{"ok":true}')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
