#!/usr/bin/python3
"""Prepare private migration/rollback candidates. Never activate or edit sources.

Native omarchy.bar and custom.bar share Registry's config.bar.layout schema.
Snapshots contain only understood settings, exact slots and binding hashes.
Unknown old settings require review; they are never copied to the fork.
"""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import sys

OLD = "omaconnect"
NEW = "Omaconnect.plus"
MAX_BYTES = 2097152
BOOL_SETTINGS = {"showBatteryStats", "showBarBattery", "showNetworkStats", "showTailscale", "showDeviceTypeIcons", "showMediaPlayer", "showRemoteCommands", "showTroubleshooting", "showActionRing", "showActionClipboard", "showActionFile", "showActionSms", "showActionPing", "showActionText"}
BOOL_SETTINGS |= {"networkTailscaleEnabled", "networkBthEnabled", "networkWireguardEnabled"}
BOOL_SETTINGS |= frozenset(('showSavedAddresses', 'showSyncthingLinks', 'showNetworkControls', 'networkStartExpanded', 'mediaStartExpanded', 'commandsStartExpanded', 'addressesStartExpanded', 'syncthingStartExpanded'))
BOOL_SETTINGS |= frozenset(("showNativeFeatures",))
BOOL_SETTINGS |= frozenset(("navigationAtTop", "showSendShortcut", "showActivityShortcut"))
STRING_SETTINGS = {"defaultPingMessage", "bthHelperPath", "quickActionsOrder"}
ALLOWED = BOOL_SETTINGS | STRING_SETTINGS
ACTION_IDS = set(('ring', 'clipboard', 'file', 'sms', 'ping', 'text', 'native-features', 'plus-settings', 'quick-share', 'media', 'media-previous', 'media-play-pause', 'media-next', 'commands', 'browse-files', 'native-notifications', 'native-volume', 'native-input', 'native-lock'))
SECTIONS = ("left", "centerBegin", "center", "centerEnd", "right", "tray")


class MigrationError(Exception):
    pass


def source_identity(value):
    if (not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,95}", value)
            or ".." in value or value.startswith("omarchy.") or value == NEW):
        raise MigrationError("source-id-invalid")
    return value


def identifier(entry):
    return entry.get("id") if isinstance(entry, dict) else entry


def locations(config, target):
    if not isinstance(config, dict):
        raise MigrationError("config-invalid")
    layout = config.get("bar", {}).get("layout", {})
    result = []
    for section in SECTIONS:
        entries = layout.get(section, [])
        if not isinstance(entries, list):
            raise MigrationError("layout-invalid")
        result.extend({"kind":"bar", "section":section, "index":i} for i,e in enumerate(entries) if identifier(e) == target)
    plugins = config.get("plugins", [])
    if not isinstance(plugins, list):
        raise MigrationError("plugins-invalid")
    result.extend({"kind":"plugin", "index":i} for i,e in enumerate(plugins) if identifier(e) == target)
    return result


def entries_at(config, location):
    return config["bar"]["layout"][location["section"]] if location["kind"] == "bar" else config["plugins"]


def source_shape(entry):
    if isinstance(entry, str):
        return "string"
    if not isinstance(entry, dict):
        raise MigrationError("entry-needs-review")
    if "settings" in entry:
        if set(entry) - {"id", "settings"}:
            raise MigrationError("entry-needs-review")
        return "nested"
    return "inline"


def settings(entry):
    shape = source_shape(entry)
    value = {} if shape == "string" else entry.get("settings", {}) if shape == "nested" else {k:v for k,v in entry.items() if k != "id"}
    if not isinstance(value, dict) or set(value) - ALLOWED:
        raise MigrationError("settings-need-review")
    for key, item in value.items():
        if key in BOOL_SETTINGS and type(item) is not bool:
            raise MigrationError("settings-invalid")
        if key in STRING_SETTINGS and (not isinstance(item, str) or len(item) > 4096 or any(ord(c) < 32 and c not in "\n\t" for c in item)):
            raise MigrationError("settings-invalid")
        if key == "quickActionsOrder":
            ids = item.split(",") if item else []
            if len(item) > 512 or len(set(ids)) != len(ids) or any(i not in ACTION_IDS for i in ids):
                raise MigrationError("settings-invalid")
        if key == "bthHelperPath" and item and (not item.startswith("/") or not item.endswith("/remote-access-mode") or ".." in item.split("/") or any(ord(c) < 32 or ord(c) == 127 for c in item)):
            raise MigrationError("settings-invalid")
    return dict(value)


def legacy_actions(before):
    # Preserve the old toolbar's visible membership and order as explicit data.
    values = [("ring", "showActionRing", True), ("clipboard", "showActionClipboard", True),
              ("file", "showActionFile", True), ("sms", "showActionSms", True),
              ("ping", "showActionPing", False), ("text", "showActionText", True)]
    return ",".join(action for action, key, default in values if before.get(key, default))


def set_disabled(config, target, disabled):
    values = config.get("disabledPlugins", [])
    if not isinstance(values, list) or any(not isinstance(v, str) for v in values):
        raise MigrationError("disabled-list-invalid")
    values = [v for v in values if v != target]
    if disabled:
        values.append(target)
    config["disabledPlugins"] = values


def prepare(config, source_id=OLD):
    source_id = source_identity(source_id)
    found = locations(config, source_id)
    if not found or sum(l["kind"] == "bar" for l in found) > 1 or sum(l["kind"] == "plugin" for l in found) > 1 or locations(config, NEW):
        raise MigrationError("entry-conflict")
    result = copy.deepcopy(config)
    disabled = config.get("disabledPlugins", [])
    if not isinstance(disabled, list) or len(disabled) != len(set(disabled)):
        raise MigrationError("disabled-list-invalid")
    snapshot = {"schema_version":1, "old_id":source_id, "new_id":NEW, "entries":[], "bindings":[], "disabled_present":"disabledPlugins" in config,
        "old_disabled":source_id in disabled, "new_disabled":NEW in disabled,
        "disabled_positions":{key:disabled.index(key) for key in (source_id, NEW) if key in disabled}}
    legacy_icon = True
    for loc in reversed(found):
        source = entries_at(config, loc)[loc["index"]]
        before = settings(source)
        after = {k:v for k,v in before.items() if k != "showDeviceTypeIcons" and not k.startswith("showAction")}
        after.update(showTailscale=False, showTroubleshooting=False, quickActionsOrder=before.get("quickActionsOrder", legacy_actions(before)))
        # Registry reads native bar/service entry settings inline, not under settings.
        entries_at(result, loc)[loc["index"]] = dict(after, id=NEW)
        snapshot["entries"].append(dict(loc, source_shape=source_shape(source), target_shape="inline", was_string=isinstance(source,str), settings_present=isinstance(source,dict) and "settings" in source, before=dict(before), after=dict(after)))
        if "showDeviceTypeIcons" in before:
            legacy_icon = before["showDeviceTypeIcons"]
    set_disabled(result, source_id, True)
    set_disabled(result, NEW, snapshot["old_disabled"])
    snapshot["disabled_after"] = {source_id:True, NEW:snapshot["old_disabled"]}
    appearance = {"schema_version":1, "bar_icon": {"mode":"automatic", "render":"symbolic"} if legacy_icon else {"mode":"preset", "value":"phone", "render":"symbolic"}, "devices":{}}
    return result, snapshot, appearance if source_id == OLD else None


def rollback(config, snapshot):
    if not isinstance(snapshot, dict) or type(snapshot.get("schema_version")) is not int or snapshot.get("schema_version") != 1 or snapshot.get("new_id") != NEW:
        raise MigrationError("snapshot-invalid")
    source_id = source_identity(snapshot.get("old_id"))
    result = copy.deepcopy(config)
    try:
        for receipt in snapshot["entries"]:
            entries = entries_at(result, receipt)
            entry = entries[receipt["index"]]
            if identifier(entry) != NEW or not isinstance(entry, dict):
                raise MigrationError("rollback-conflict")
            # Old staged snapshots used nested output; new ones name the actual
            # native target shape. Never silently merge two configuration surfaces.
            target_shape = receipt.get("target_shape", "nested")
            if target_shape == "nested":
                if not isinstance(entry.get("settings"), dict):
                    raise MigrationError("rollback-conflict")
                current = dict(entry["settings"])
                extra = {k:v for k,v in entry.items() if k not in {"id", "settings"}}
            elif target_shape == "inline" and "settings" not in entry:
                current = {k:v for k,v in entry.items() if k != "id"}
                extra = {}
            else:
                raise MigrationError("rollback-conflict")
            for key, expected in receipt["after"].items():
                if key not in current or current[key] != expected or type(current[key]) is not type(expected):
                    raise MigrationError("rollback-conflict")
                current.pop(key)
            if any(key in current for key in receipt["before"]):
                raise MigrationError("rollback-conflict")
            current.update(receipt["before"])
            shape = receipt.get("source_shape", "string" if receipt["was_string"] else "nested" if receipt["settings_present"] else "inline")
            if shape == "string" and not current and not extra:
                restored = source_id
            elif shape == "nested":
                restored = dict(extra, id=source_id, settings=current)
            elif shape in ("inline", "string"):
                restored = dict(extra, **current, id=source_id)
            else:
                raise MigrationError("rollback-conflict")
            entries[receipt["index"]] = restored
        disabled = result.get("disabledPlugins", [])
        for target, expected in snapshot["disabled_after"].items():
            if (target in disabled) != expected:
                raise MigrationError("rollback-conflict")
        set_disabled(result, source_id, snapshot["old_disabled"])
        set_disabled(result, NEW, snapshot["new_disabled"])
        positions = snapshot.get("disabled_positions")
        if positions is not None:
            if not isinstance(positions, dict) or set(positions) - {source_id, NEW} or any(type(index) is not int or index < 0 for index in positions.values()):
                raise MigrationError("rollback-conflict")
            values = [key for key in result["disabledPlugins"] if key not in positions]
            for target, index in sorted(positions.items(), key=lambda row: row[1]):
                if not snapshot["old_disabled" if target == source_id else "new_disabled"]:
                    raise MigrationError("rollback-conflict")
                values.insert(min(index, len(values)), target)
            result["disabledPlugins"] = values
        if not snapshot["disabled_present"] and not result["disabledPlugins"]:
            result.pop("disabledPlugins")
    except (KeyError, IndexError, TypeError):
        raise MigrationError("rollback-conflict") from None
    return result


def read_json(path):
    with Path(path).open("rb") as source:
        raw = source.read(MAX_BYTES+1)
    if len(raw) > MAX_BYTES:
        raise MigrationError("source-limit")
    return json.loads(raw), hashlib.sha256(raw).hexdigest()


def binding_provenance(paths, source_id=OLD):
    source_id = source_identity(source_id)
    rows = []
    pattern = re.compile(r"(?<![A-Za-z0-9_.-])" + re.escape(source_id) + r"(?![A-Za-z0-9_.-])")
    for path in paths:
        raw = Path(path).read_bytes()
        if len(raw) > MAX_BYTES:
            raise MigrationError("binding-limit")
        for number, line in enumerate(raw.decode("utf-8").splitlines(), 1):
            count = len(pattern.findall(line)) if not line.lstrip().startswith("#") else 0
            if count:
                rows.append({"path":str(Path(path).resolve()), "line":number, "sha256":hashlib.sha256(line.encode()).hexdigest(), "old_id":source_id, "new_id":NEW, "occurrences":count, "action":"review-exact-binding"})
    return rows


def write_stage(directory, artifacts):
    directory = Path(directory).absolute()
    resolved = directory.resolve()
    protected = (Path.home() / ".config/omarchy", Path("/usr/share/omarchy"))
    if any(resolved == p.resolve() or p.resolve() in resolved.parents for p in protected):
        raise MigrationError("staging-path-required")
    directory.mkdir(mode=0o700)
    created = []
    try:
        for name, document in artifacts.items():
            data = json.dumps(document, indent=2, ensure_ascii=False).encode() + b"\n"
            if len(data) > MAX_BYTES:
                raise MigrationError("output-limit")
            path = directory / name
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            created.append(path)
            with os.fdopen(fd, "wb") as target:
                target.write(data)
                target.flush()
                os.fsync(target.fileno())
            if path.read_bytes() != data:
                raise MigrationError("snapshot-verification-failed")
    except Exception:
        for path in created:
            path.unlink()
        directory.rmdir()
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("prepare", "rollback"))
    parser.add_argument("--source-id", default=OLD, help="Existing plugin ID; target is fixed to Omaconnect.plus")
    parser.add_argument("--source", required=True, help="Source shell JSON; never modified")
    parser.add_argument("--output", required=True, help="New private staging directory; must not exist")
    parser.add_argument("--snapshot", help="Previously staged minimal snapshot for rollback")
    parser.add_argument("--bindings", action="append", default=[], help="Read-only binding file; stores hashes only")
    args = parser.parse_args()
    try:
        config, digest = read_json(args.source)
        if args.action == "prepare":
            candidate, snapshot, appearance = prepare(config, args.source_id)
            snapshot.update(source={"path":str(Path(args.source).resolve()), "sha256":digest}, bindings=binding_provenance(args.bindings, args.source_id))
            artifacts = {"candidate-shell.json":candidate, "snapshot.json":snapshot}
            if appearance is not None: artifacts["candidate-appearance.json"] = appearance
            write_stage(args.output, artifacts)
        else:
            if not args.snapshot:
                raise MigrationError("snapshot-required")
            snapshot, _ = read_json(args.snapshot)
            write_stage(args.output, {"candidate-shell.json":rollback(config, snapshot)})
        print(json.dumps({"ok":True,"state":"staged-only","path":str(Path(args.output).absolute())}))
        return 0
    except (MigrationError, ValueError, OSError, AttributeError, TypeError):
        print(json.dumps({"ok":False,"error":"Migration needs review. No source configuration was changed."}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
