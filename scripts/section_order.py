"""Fixed daily-section definitions and order validation; no provider operations."""
import json
from pathlib import Path
import re

MAX_ORDER_LENGTH = 512
MAX_CATALOG_LENGTH = 32768
# Saved orders can still name sections that later releases removed.
RETIRED_IDS = ("information",)
FIELDS = {"id", "label", "description", "visibilityKey", "expandedKey", "defaultVisible", "defaultExpanded", "settingsPage"}
PAGES = {"Appearance", "Connections", "Quick actions", "Device features"}


def validate_catalog(rows):
    if not isinstance(rows, list) or not 1 <= len(rows) <= 32:
        raise ValueError("invalid-section-catalogue")
    ids, keys = set(), set()
    for row in rows:
        if not isinstance(row, dict) or set(row) - FIELDS:
            raise ValueError("invalid-section-catalogue")
        ident = row.get("id")
        if not isinstance(ident, str) or not re.fullmatch(r"[a-z][a-z0-9-]{0,31}", ident) or ident in ids:
            raise ValueError("invalid-section-catalogue")
        for field, limit in (("label", 128), ("description", 1024)):
            if not isinstance(row.get(field), str) or not row[field].strip() or len(row[field]) > limit:
                raise ValueError("invalid-section-catalogue")
        if (type(row.get("defaultVisible")) is not bool or type(row.get("defaultExpanded")) is not bool
                or not isinstance(row.get("settingsPage", "Appearance"), str) or row.get("settingsPage", "Appearance") not in PAGES
                or ("visibilityKey" not in row and not row["defaultVisible"])):
            raise ValueError("invalid-section-catalogue")
        setting_keys = [row.get("expandedKey")]
        if "visibilityKey" in row:
            setting_keys.append(row["visibilityKey"])
        for key in setting_keys:
            if not isinstance(key, str) or not re.fullmatch(r"[A-Za-z][A-Za-z0-9]{0,63}", key) or key in keys:
                raise ValueError("invalid-section-catalogue")
            keys.add(key)
        ids.add(ident)
    if len(",".join(row["id"] for row in rows)) > MAX_ORDER_LENGTH:
        raise ValueError("invalid-section-catalogue")
    return rows


def load_catalog():
    path = Path(__file__).resolve().parents[1] / "PanelSections.json"
    with path.open("rb") as stream:
        raw = stream.read(MAX_CATALOG_LENGTH + 1)
    if len(raw) > MAX_CATALOG_LENGTH:
        raise ValueError("invalid-section-catalogue")
    return validate_catalog(json.loads(raw))


CATALOG = load_catalog()
IDS = tuple(row["id"] for row in CATALOG)
BOOL_DEFAULTS = {key: row[default] for row in CATALOG
                 for key, default in ((row.get("visibilityKey"), "defaultVisible"), (row["expandedKey"], "defaultExpanded")) if key}


def order_ids(value):
    if not isinstance(value, str) or len(value) > MAX_ORDER_LENGTH:
        raise ValueError("invalid-section-order")
    ids = [ident for ident in value.split(",") if ident not in RETIRED_IDS] if value else []
    if len(ids) > len(IDS) or len(set(ids)) != len(ids) or any(ident not in IDS for ident in ids):
        raise ValueError("invalid-section-order")
    return ids + [ident for ident in IDS if ident not in ids]


def normalized_value(value):
    ids = order_ids(value)
    return ",".join(ids) if value else ""
