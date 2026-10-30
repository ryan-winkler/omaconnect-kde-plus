#!/usr/bin/python3
"""Save reviewed OmaConnect preferences through the native bar API.

The filename and {key, enabled} request stay compatible with network controls.
"""
import json
import sys
import time

from manage_addresses import AddressError, bounded_command

KEYS = frozenset(("networkTailscaleEnabled", "networkBthEnabled", "networkWireguardEnabled",
                  "showBatteryStats", "showBarBattery", "showNetworkStats", "showMediaPlayer",
                  "showRemoteCommands"))
KEYS |= frozenset(('showSavedAddresses', 'showSyncthingLinks', 'showNetworkControls', 'networkStartExpanded', 'mediaStartExpanded', 'commandsStartExpanded', 'addressesStartExpanded', 'syncthingStartExpanded'))
KEYS |= frozenset(("showNativeFeatures",))
KEYS |= frozenset(("navigationAtTop", "showSendShortcut", "showActivityShortcut"))
STRING_KEYS = frozenset(("defaultPingMessage", "bthHelperPath", "quickActionsOrder"))
ACTION_IDS = frozenset(('ring', 'clipboard', 'file', 'sms', 'ping', 'text', 'native-features', 'plus-settings', 'media', 'media-previous', 'media-play-pause', 'media-next', 'commands', 'browse-files', 'native-notifications', 'native-volume', 'native-input', 'native-lock'))
MAX_REQUEST = 32768


def setting_value(request):
    if not isinstance(request, dict) or not isinstance(request.get("key"), str):
        raise ValueError()
    key = request["key"]
    if key in KEYS and set(request) == {"key", "enabled"} and type(request["enabled"]) is bool:
        return request["enabled"]
    if key not in STRING_KEYS or set(request) != {"key", "value"}:
        raise ValueError()
    value = request["value"]
    if not isinstance(value, str) or len(value) > 4096:
        raise ValueError()
    if key == "quickActionsOrder":
        values = value.split(",") if value else []
        if len(value) > 512 or len(values) > len(ACTION_IDS) or len(set(values)) != len(values) or any(item not in ACTION_IDS for item in values):
            raise ValueError()
    elif key == "defaultPingMessage":
        if any(ord(char) < 32 and char not in "\n\t" for char in value):
            raise ValueError()
    elif value and (not value.startswith("/") or not value.endswith("/remote-access-mode")
                    or ".." in value.split("/") or any(ord(char) < 32 or ord(char) == 127 for char in value)):
        raise ValueError()
    return value


def save(request):
    try:
        value = setting_value(request)
    except (ValueError, KeyError, TypeError):
        return {"ok": False, "message": "Invalid setting. Check its value and try again."}
    try:
        reply = bounded_command(["/usr/bin/omarchy-shell", "shell", "setBarWidget", "Omaconnect.plus",
                                 request["key"], json.dumps(value, ensure_ascii=True), "{}"],
                                time.monotonic() + 4)
        if reply.strip() == b"ok":
            return {"ok": True, "message": "Setting saved."}
    except AddressError:
        pass
    return {"ok": False, "message": "Setting was not confirmed. Controls show the saved configuration. Try again."}


if __name__ == "__main__":
    try:
        raw = sys.stdin.buffer.read(MAX_REQUEST + 1)
        result = save(json.loads(raw)) if len(raw) <= MAX_REQUEST else save(None)
    except (ValueError, TypeError, RecursionError):
        result = save(None)
    print(json.dumps(result))
    raise SystemExit(0 if result["ok"] else 1)
