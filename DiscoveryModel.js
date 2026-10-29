.pragma library

var MAX_BYTES = 262144
var MAX_CANDIDATES = 256
var MAX_BATCH = 32
var ERRORS = {
    "address-invalid": "Enter one LAN or VPN IP address. Subnets and hostnames are not accepted.",
    "address-not-private": "Use a private IP, or select Tailscale for its 100.64.0.0/10 addresses.",
    "bth-ipv6-disabled": "BTH IPv6 addresses are disabled by the current policy.",
    "approval-required": "Approve this address before registration.",
    "peer-invalid": "Select the KDE device identity for this local address record.",
    "address-conflict": "Another writer changed the saved KDE addresses. Refresh and review them.",
    "address-timeout": "The address action timed out. Refresh before retrying.",
    "address-busy": "Another address action is busy. Retry after it stops.",
    "metadata-invalid": "Address metadata is invalid. The file was preserved. Review it before changing addresses.",
    "metadata-permissions": "Address metadata needs private owner permissions.",
    "metadata-missing": "This address record no longer exists. Refresh the list.",
    "candidate-limit": "The address list is full (256 entries).",
    "batch-limit": "Change at most 32 registrations in one batch.",
    "provider-missing": "The KDE address tool is not installed.",
    "provider-unavailable": "KDE Connect address storage is unavailable. Start KDE Connect, then refresh."
}

function errorText(code) { return ERRORS[code] || "Address storage is unavailable. Refresh and review the saved addresses." }
function parse(raw) {
    if (typeof raw !== "string" || raw.length > MAX_BYTES) return null
    var data
    try { data = JSON.parse(raw) } catch (_) { return null }
    if (!data || data.schema_version !== 1 || typeof data.ok !== "boolean") return null
    if (!data.ok) return {ok: false, error: errorText(data.error)}
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
