#!/usr/bin/python3
"""Prepare private migration/rollback candidates. Never activate or edit sources.

Native omarchy.bar and ryan.bar share Registry's config.bar.layout schema.
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
NEW = "ryan.omaconnect"
MAX_BYTES = 2097152
BOOL_SETTINGS = {"showBatteryStats", "showBarBattery", "showNetworkStats", "showTailscale", "showDeviceTypeIcons", "showMediaPlayer", "showRemoteCommands", "showTroubleshooting", "showActionRing", "showActionClipboard", "showActionFile", "showActionSms", "showActionPing", "showActionText"}
ALLOWED = BOOL_SETTINGS | {"defaultPingMessage"}
SECTIONS = ("left", "centerBegin", "center", "centerEnd", "right", "tray")


class MigrationError(Exception):
    pass


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


def settings(entry):
    if isinstance(entry, str):
        return {}
    if not isinstance(entry, dict) or set(entry) - {"id", "settings"}:
        raise MigrationError("entry-needs-review")
    value = entry.get("settings", {})
    if not isinstance(value, dict) or set(value) - ALLOWED:
        raise MigrationError("settings-need-review")
    for key, item in value.items():
        if key in BOOL_SETTINGS and type(item) is not bool:
            raise MigrationError("settings-invalid")
        if key == "defaultPingMessage" and (not isinstance(item, str) or len(item) > 4096 or any(ord(c) < 32 and c not in "\n\t" for c in item)):
            raise MigrationError("settings-invalid")
    return dict(value)


def set_disabled(config, target, disabled):
    values = config.get("disabledPlugins", [])
    if not isinstance(values, list) or any(not isinstance(v, str) for v in values):
        raise MigrationError("disabled-list-invalid")
    values = [v for v in values if v != target]
    if disabled:
        values.append(target)
    config["disabledPlugins"] = values


def prepare(config):
    found = locations(config, OLD)
    if not found or sum(l["kind"] == "bar" for l in found) > 1 or sum(l["kind"] == "plugin" for l in found) > 1 or locations(config, NEW):
        raise MigrationError("entry-conflict")
    result = copy.deepcopy(config)
    disabled = config.get("disabledPlugins", [])
    if not isinstance(disabled, list) or len(disabled) != len(set(disabled)):
        raise MigrationError("disabled-list-invalid")
    snapshot = {"schema_version":1, "old_id":OLD, "new_id":NEW, "entries":[], "bindings":[], "disabled_present":"disabledPlugins" in config,
        "old_disabled":OLD in disabled, "new_disabled":NEW in disabled}
    legacy_icon = True
    for loc in reversed(found):
        source = entries_at(config, loc)[loc["index"]]
        before = settings(source)
        after = {k:v for k,v in before.items() if k != "showDeviceTypeIcons"}
        after.update(showTailscale=False, showTroubleshooting=False)
        entries_at(result, loc)[loc["index"]] = {"id":NEW, "settings":after}
        snapshot["entries"].append(dict(loc, was_string=isinstance(source,str), settings_present=isinstance(source,dict) and "settings" in source, before=dict(before), after=dict(after)))
        if "showDeviceTypeIcons" in before:
            legacy_icon = before["showDeviceTypeIcons"]
    set_disabled(result, OLD, True)
    set_disabled(result, NEW, snapshot["old_disabled"])
    snapshot["disabled_after"] = {OLD:True, NEW:snapshot["old_disabled"]}
    appearance = {"schema_version":1, "bar_icon": {"mode":"automatic", "render":"symbolic"} if legacy_icon else {"mode":"preset", "value":"phone", "render":"symbolic"}, "devices":{}}
    return result, snapshot, appearance


def rollback(config, snapshot):
    if not isinstance(snapshot, dict) or snapshot.get("schema_version") != 1 or snapshot.get("old_id") != OLD or snapshot.get("new_id") != NEW:
        raise MigrationError("snapshot-invalid")
    result = copy.deepcopy(config)
    try:
        for receipt in snapshot["entries"]:
            entries = entries_at(result, receipt)
            entry = entries[receipt["index"]]
            if identifier(entry) != NEW or not isinstance(entry, dict) or not isinstance(entry.get("settings"), dict):
                raise MigrationError("rollback-conflict")
            current = dict(entry["settings"])
            for key, expected in receipt["after"].items():
                if key not in current or current[key] != expected or type(current[key]) is not type(expected):
                    raise MigrationError("rollback-conflict")
                current.pop(key)
            # Adding an old managed key after activation is a conflicting edit.
            if any(key in current for key in receipt["before"]):
                raise MigrationError("rollback-conflict")
            current.update(receipt["before"])
            if receipt["was_string"] and not current and set(entry) <= {"id", "settings"}:
                restored = OLD
            else:
                restored = dict(entry, id=OLD)
                if current or receipt["settings_present"]:
                    restored["settings"] = current
                else:
                    restored.pop("settings", None)
            entries[receipt["index"]] = restored
        disabled = result.get("disabledPlugins", [])
        for target, expected in snapshot["disabled_after"].items():
            if (target in disabled) != expected:
                raise MigrationError("rollback-conflict")
        set_disabled(result, OLD, snapshot["old_disabled"])
        set_disabled(result, NEW, snapshot["new_disabled"])
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


def binding_provenance(paths):
    rows = []
    pattern = re.compile(r"(?<![A-Za-z0-9_.-])omaconnect(?![A-Za-z0-9_.-])")
    for path in paths:
        raw = Path(path).read_bytes()
        if len(raw) > MAX_BYTES:
            raise MigrationError("binding-limit")
        for number, line in enumerate(raw.decode("utf-8").splitlines(), 1):
            count = len(pattern.findall(line)) if not line.lstrip().startswith("#") else 0
            if count:
                rows.append({"path":str(Path(path).resolve()), "line":number, "sha256":hashlib.sha256(line.encode()).hexdigest(), "old_id":OLD, "new_id":NEW, "occurrences":count, "action":"review-exact-binding"})
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
    parser.add_argument("--source", required=True, help="Source shell JSON; never modified")
    parser.add_argument("--output", required=True, help="New private staging directory; must not exist")
    parser.add_argument("--snapshot", help="Previously staged minimal snapshot for rollback")
    parser.add_argument("--bindings", action="append", default=[], help="Read-only binding file; stores hashes only")
    args = parser.parse_args()
    try:
        config, digest = read_json(args.source)
        if args.action == "prepare":
            candidate, snapshot, appearance = prepare(config)
            snapshot.update(source={"path":str(Path(args.source).resolve()), "sha256":digest}, bindings=binding_provenance(args.bindings))
            write_stage(args.output, {"candidate-shell.json":candidate, "snapshot.json":snapshot, "candidate-appearance.json":appearance})
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
