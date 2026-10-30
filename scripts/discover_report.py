#!/usr/bin/env python3
"""Structured busctl --json=short parsing for the discovery/address scripts.

Replaces the gdbus-text sed chains in discover_devices.sh and
update_custom_address.sh: gdbus quotes strings as <'value'> and wraps
multiline values, which no sed substitution chain can un reliably. busctl
emits JSON, so hostile device names and metadata are values again, never
syntax (a name containing a tab cannot forge extra TSV fields).

Importable as a module for unit tests; every parse function returns None on
malformed input instead of raising. Subcommands (exit 3 on malformed input,
which callers map to skip-device / exit-70):

    ids        stdin: daemon.devices() call reply          -> ids, one per line
    addresses  stdin: customDevices get-property reply     -> addresses, one per line
    truthy     stdin: single-boolean call reply            -> exit 0 iff data == [true]
    registered stdin: ListActivatableNames call reply      -> exit 0 iff KDE is registered
    device     argv: <id> <device_json> <battery_json> <connectivity_json> [<loaded_json>]
              -> DEVICE line: 16 legacy fields plus optional bounded information JSON

Dependencies: busctl (systemd) for the callers, python3.
"""

import json
import re
import sys

from media_status import parse_call_result, parse_properties

# Keep future native plugin IDs without a UI whitelist.
# ponytail: 256 IDs / 32 KiB per list; raise with evidence if native KDE grows past this.
PLUGIN_ID = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}")
MAX_PLUGIN_IDS = 256
MAX_PLUGIN_BYTES = 32768


def parse_string_list(raw):
    """as-typed string list -> list of non-empty strings, or None.

    Accepts both reply shapes: `call` wraps the return value once
    ({"data": [["a", "b"]]}), `get-property` returns the value directly
    ({"data": ["a", "b"]}).
    """
    obj = parse_call_result(raw)
    if obj is None:
        return None
    data = obj
    if len(data) == 1 and isinstance(data[0], list):
        data = data[0]
    if not isinstance(data, list):
        return None
    return [item for item in data if isinstance(item, str) and item]


def plugin_ids(value):
    """String list -> de-duplicated plugin IDs in order, or None.

    Any non-string or invalid ID, or an oversized list, rejects the whole
    list so a hostile reply cannot reach QML.
    """
    if not isinstance(value, list) or len(value) > MAX_PLUGIN_IDS:
        return None
    if sum(len(item) for item in value if isinstance(item, str)) > MAX_PLUGIN_BYTES:
        return None
    result = []
    for item in value:
        if not isinstance(item, str) or not PLUGIN_ID.fullmatch(item):
            return None
        if item not in result:
            result.append(item)
    return result


def loaded_plugin_ids(raw):
    """loadedPlugins call reply -> plugin IDs, or None when unknown."""
    data = parse_call_result(raw)
    if not data or len(data) != 1:
        return None
    return plugin_ids(data[0])


def sanitize(text):
    """Fold tabs/newlines to spaces: a remote value must never forge TSV."""
    return str(text).replace("\t", " ").replace("\n", " ")


def _field(value):
    if isinstance(value, str):
        return value
    if value is None or isinstance(value, (bool, list, dict)):
        return ""
    return str(value)


def _flag(value):
    return "true" if value is True else "false"


def _nonneg_int(value):
    if isinstance(value, int) and not isinstance(value, bool) and value >= 0:
        return value
    return None


def bounded_strings(value):
    if not isinstance(value, list) or len(value) > 16:
        return []
    if any(not isinstance(item, str) or len(item) > 256 for item in value):
        return []
    return [sanitize(item).replace("\r", " ").replace("\0", "") for item in value]


def format_device(device_id, device_props, battery_props=None, conn_props=None, loaded=None, monitor=None):
    """Flattened GetAll properties -> DEVICE TSV, with optional information JSON.

    Fields: DEVICE, id, name, type, paired, reachable, charge (-1 n/a),
    charging, plugins (comma list), netType, netStrength (-1 n/a),
    pairRequested, pairRequestedByPeer, verificationKey, loadedPlugins
    (comma list), loadedKnown. Battery and connectivity values are only
    honored when the corresponding plugin is in the device's
    supportedPlugins list. Loading is distinct from support and from a
    user's enabled setting; loaded is None when the daemon did not say.
    """
    props = device_props or {}
    plugins = plugin_ids(props.get("supportedPlugins")) or []
    plugin_set = set(plugins)

    charge = -1
    charging = False
    if "kdeconnect_battery" in plugin_set and battery_props:
        value = _nonneg_int(battery_props.get("charge"))
        if value is not None:
            charge = value
        charging = battery_props.get("isCharging") is True

    net_type = ""
    net_strength = -1
    if "kdeconnect_connectivity_report" in plugin_set and conn_props:
        raw_type = conn_props.get("cellularNetworkType")
        if isinstance(raw_type, str) and raw_type and raw_type != "null":
            net_type = raw_type
        strength = _nonneg_int(conn_props.get("cellularNetworkStrength"))
        if strength is not None:
            net_strength = strength

    fields = [
        "DEVICE",
        sanitize(_field(device_id)),
        sanitize(_field(props.get("name"))),
        sanitize(_field(props.get("type"))),
        _flag(props.get("isPaired")),
        _flag(props.get("isReachable")),
        str(charge),
        _flag(charging),
        ",".join(plugins),
        sanitize(net_type),
        str(net_strength),
        _flag(props.get("isPairRequested")),
        _flag(props.get("isPairRequestedByPeer")),
        sanitize(_field(props.get("verificationKey"))),
        ",".join(loaded or []),
        _flag(loaded is not None),
    ]
    if "reachableAddresses" in props or "activeProviderNames" in props or monitor is not None:
        known = isinstance(monitor, dict) and type(monitor.get("active")) is bool and type(monitor.get("isVirtualMonitorAvailable")) is bool
        information = {
            "addresses": bounded_strings(props.get("reachableAddresses")),
            "providers": bounded_strings(props.get("activeProviderNames")),
            "monitor": {"known": known, "active": bool(known and monitor["active"]),
                        "available": bool(known and monitor["isVirtualMonitorAvailable"])},
        }
        encoded = json.dumps(information, separators=(",", ":"))
        # Match the QML field bound after JSON escaping, keeping native state.
        for key in sorted(("addresses", "providers"), key=lambda key: len(json.dumps(information[key])), reverse=True):
            if len(encoded) <= 16384:
                break
            information[key] = []
            encoded = json.dumps(information, separators=(",", ":"))
        fields.append(encoded)
    return "\t".join(fields)


def _fail(message):
    print("discover_report: %s" % (message,), file=sys.stderr)
    return 3


def main(argv):
    if len(argv) < 2:
        print("usage: discover_report.py ids|addresses|truthy|registered|device ...", file=sys.stderr)
        return 64
    command = argv[1]

    if command == "supports" and len(argv) == 4:
        props = parse_properties(argv[2]) or {}
        return 0 if argv[3] in (plugin_ids(props.get("supportedPlugins")) or []) else 1

    if command in ("ids", "addresses"):
        items = parse_string_list(sys.stdin.read())
        if items is None:
            return _fail("malformed %s reply" % (command,))
        for item in items:
            print(sanitize(item))
        return 0

    if command == "truthy":
        data = parse_call_result(sys.stdin.read(), "b")
        if data not in ([True], [False]) or type(data[0]) is not bool:
            return _fail("malformed boolean reply")
        return 0 if data == [True] else 1

    if command == "registered":
        data = parse_call_result(sys.stdin.read(), "as")
        if (not isinstance(data, list) or len(data) != 1 or not isinstance(data[0], list)
                or any(not isinstance(name, str) for name in data[0])):
            return _fail("malformed activatable services reply")
        return 0 if "org.kde.kdeconnect" in data[0] else 1

    if command == "device":
        if len(argv) not in (6, 7, 8):
            print("usage: discover_report.py device <id> <device_json> <battery_json> <conn_json> [<loaded_json> [<monitor_json>]]", file=sys.stderr)
            return 64
        device_props = parse_properties(argv[3]) if argv[3].strip() else None
        battery_props = parse_properties(argv[4]) if argv[4].strip() else None
        conn_props = parse_properties(argv[5]) if argv[5].strip() else None
        if device_props is None:
            return _fail("malformed device GetAll reply")
        loaded = loaded_plugin_ids(argv[6]) if len(argv) >= 7 else None
        monitor = parse_properties(argv[7]) if len(argv) == 8 and argv[7].strip() else None
        print(format_device(argv[2], device_props, battery_props, conn_props, loaded, monitor))
        return 0

    print("discover_report: unknown command %r" % (command,), file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv))
