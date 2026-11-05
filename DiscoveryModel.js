.pragma library

var MAX_BYTES = 262144
var MAX_CANDIDATES = 256
var MAX_BATCH = 32
var ERRORS = {
    "address-invalid": "discovery.address-invalid",
    "address-not-private": "discovery.address-not-private",
    "bth-ipv6-disabled": "discovery.bth-ipv6-disabled",
    "approval-required": "discovery.approval-required",
    "peer-invalid": "discovery.peer-invalid",
    "address-conflict": "discovery.address-conflict",
    "address-timeout": "discovery.address-timeout",
    "address-busy": "discovery.address-busy",
    "metadata-invalid": "discovery.metadata-invalid",
    "metadata-permissions": "discovery.metadata-permissions",
    "metadata-missing": "discovery.metadata-missing",
    "candidate-limit": "discovery.candidate-limit",
    "batch-limit": "discovery.batch-limit",
    "provider-missing": "discovery.provider-missing",
    "provider-unavailable": "discovery.provider-unavailable"
}

function errorKey(code) { return Object.prototype.hasOwnProperty.call(ERRORS, code) ? ERRORS[code] : "discovery.address-unavailable" }
function parse(raw) {
    if (typeof raw !== "string" || raw.length > MAX_BYTES) return null
    var data
    try { data = JSON.parse(raw) } catch (_) { return null }
    if (!data || data.schema_version !== 1 || typeof data.ok !== "boolean") return null
    if (!data.ok) return {ok: false, errorKey: errorKey(data.error)}
    if (!Array.isArray(data.addresses) || data.addresses.length > MAX_CANDIDATES
        || !Array.isArray(data.custom_addresses) || data.custom_addresses.length > MAX_CANDIDATES) return null
    var rows = []
    for (var i=0; i<data.addresses.length; i++) {
        var r = data.addresses[i]
        if (!r || typeof r.peer_id !== "string" || r.peer_id.length > 256
            || typeof r.address !== "string" || r.address.length > 80
            || ["manual", "bth", "wireguard", "tailscale"].indexOf(r.source) < 0
            || typeof r.auto_discover !== "boolean" || typeof r.manual_baseline !== "boolean"
            || typeof r.registered !== "boolean") return null
        rows.push({peer_id: r.peer_id, address: r.address, source: r.source,
            auto_discover: r.auto_discover, manual_baseline: r.manual_baseline, registered: r.registered})
    }
    for (var j=0; j<data.custom_addresses.length; j++)
        if (typeof data.custom_addresses[j] !== "string" || data.custom_addresses[j].length > 1024) return null
    return {ok: true, addresses: rows, customAddresses: data.custom_addresses.slice()}
}
function approvedChanges(rows) {
    return rows.filter(function(r) { return r.auto_discover }).map(function(r) {
        return {op: "add", peer_id: r.peer_id, address: r.address, source: r.source,
            auto_discover: true, approved: true}
    })
}
function canAuto(enabled, opened, rows, now, backoffUntil) {
    return enabled && opened && now >= backoffUntil && rows.some(function(r) { return r.auto_discover })
}
