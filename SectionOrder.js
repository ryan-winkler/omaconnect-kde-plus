.pragma library

var MAX_ORDER_LENGTH = 512;
var MAX_CATALOG_LENGTH = 32768;
// Saved orders can still name sections that later releases removed.
var RETIRED_IDS = ["information"];
var fields = ["id", "label", "description", "visibilityKey", "expandedKey", "defaultVisible", "defaultExpanded", "settingsPage", "defaultPolicy"];
var POLICIES = ["show", "hide", "available", "unavailable"];
var MAX_VISIBILITY_LENGTH = 2048;
var pages = ["Appearance", "Connections", "Quick actions", "Device features"];

function parseCatalog(text) {
    if (typeof text !== "string" || text.length > MAX_CATALOG_LENGTH) return [];
    var rows;
    try { rows = JSON.parse(text); } catch (_) { return []; }
    if (!Array.isArray(rows) || rows.length < 1 || rows.length > 32) return [];
    var ids = Object.create(null), keys = Object.create(null);
    for (var i = 0; i < rows.length; ++i) {
        var row = rows[i];
        if (!row || typeof row !== "object" || Array.isArray(row) || Object.keys(row).some(function(key) { return fields.indexOf(key) < 0; })) return [];
        if (typeof row.id !== "string" || !/^[a-z][a-z0-9-]{0,31}$/.test(row.id) || ids[row.id]) return [];
        if (typeof row.label !== "string" || !row.label.trim() || row.label.length > 128
                || typeof row.description !== "string" || !row.description.trim() || row.description.length > 1024
                || typeof row.defaultVisible !== "boolean" || typeof row.defaultExpanded !== "boolean"
                || POLICIES.indexOf(row.defaultPolicy) < 0
                || (row.settingsPage !== undefined && pages.indexOf(row.settingsPage) < 0)) return [];
        var settingKeys = [row.expandedKey];
        if (row.visibilityKey !== undefined) settingKeys.push(row.visibilityKey);
        for (var j = 0; j < settingKeys.length; ++j) {
            var key = settingKeys[j];
            if (typeof key !== "string" || !/^[A-Za-z][A-Za-z0-9]{0,63}$/.test(key) || keys[key]) return [];
            keys[key] = true;
        }
        if (row.visibilityKey === undefined && !row.defaultVisible) return [];
        ids[row.id] = true;
    }
    return rows.map(function(row) { return row.id; }).join(",").length <= MAX_ORDER_LENGTH ? rows : [];
}

// Missing known IDs append in catalogue order, so new sections preserve saved order.
// null means invalid; an empty value means the complete canonical order.
function parse(value, entries) {
    if (typeof value !== "string" || value.length > MAX_ORDER_LENGTH) return null;
    var canonical = entries.map(function(row) { return row.id; });
    var ids = value === "" ? [] : value.split(",").filter(function(id) { return RETIRED_IDS.indexOf(id) < 0; }), seen = Object.create(null);
    if (ids.length > canonical.length) return null;
    for (var i = 0; i < ids.length; ++i) {
        if (canonical.indexOf(ids[i]) < 0 || seen[ids[i]]) return null;
        seen[ids[i]] = true;
    }
    return ids.concat(canonical.filter(function(id) { return !seen[id]; }));
}

function normalize(value, entries) {
    return parse(value, entries) || entries.map(function(row) { return row.id; });
}

function move(order, id, delta) {
    if (!Array.isArray(order) || (delta !== -1 && delta !== 1)) return null;
    var from = order.indexOf(id), to = from + delta;
    if (from < 0 || to < 0 || to >= order.length) return null;
    var next = order.slice();
    next[from] = next[to];
    next[to] = id;
    return next;
}

// The saved object only overrides optional sections. No eval or provider lookup.
function parseVisibility(value, entries) {
    if (typeof value !== "string" || value.length > MAX_VISIBILITY_LENGTH) return null;
    var parsed;
    try { parsed = JSON.parse(value); } catch (_) { return null; }
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
    var keys = Object.keys(parsed), rawKeys = [], match;
    var keyPattern = /"((?:\\.|[^"\\])*)"\s*:/g;
    while ((match = keyPattern.exec(value)) !== null) {
        if (!/^[a-z][a-z0-9-]*$/.test(match[1])) return null;
        rawKeys.push(match[1]);
    }
    if (rawKeys.length !== keys.length) return null;
    for (var i = 0; i < keys.length; i++) {
        var entry = entries.find(function(row) { return row.id === keys[i]; });
        if (!entry || !entry.visibilityKey || POLICIES.indexOf(parsed[keys[i]]) < 0) return null;
    }
    return parsed;
}

function policy(entry, overrides, legacy) {
    if (!entry || !entry.visibilityKey) return "show";
    if (overrides && Object.prototype.hasOwnProperty.call(overrides, entry.id)) return overrides[entry.id];
    return legacy === true ? entry.defaultPolicy : "hide";
}

function matches(policy, state) {
    return policy === "show" || (policy === "available" && state === "available")
        || (policy === "unavailable" && state === "unavailable");
}

function moveTo(order, id, position) {
    if (!Array.isArray(order) || !Number.isInteger(position) || position < 0 || position >= order.length) return null;
    var from = order.indexOf(id);
    if (from < 0) return null;
    var next = order.slice(); next.splice(from, 1); next.splice(position, 0, id); return next;
}
