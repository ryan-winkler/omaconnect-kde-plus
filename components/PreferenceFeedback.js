.pragma library

var keys = {
    "saved": "preferences.saved",
    "invalid-setting": "preferences.invalid",
    "save-unconfirmed": "preferences.unconfirmed",
    "tailscale-opened": "networkOptions.tailscaleOpened",
    "tailscale-unavailable": "networkOptions.tailscaleUnavailable",
    "wireguard-requested": "networkOptions.wireguardRequested",
    "wireguard-unavailable": "networkOptions.wireguardUnavailable",
    "unknown-owner": "networkOptions.unknownOwner"
}

function parse(exitCode, text, oversized) {
    if (oversized) return null
    var result
    try { result = JSON.parse(text) } catch (_) { return null }
    if (!result || typeof result.ok !== "boolean" || (exitCode === 0) !== result.ok
            || typeof result.message !== "string" || result.message.length >= 512) return null
    var key = typeof result.code === "string" && Object.prototype.hasOwnProperty.call(keys, result.code)
        ? keys[result.code] : ""
    return {ok: result.ok, key: key, message: result.message}
}

function display(strings, result, fallbackKey) {
    if (!result) return strings.live(fallbackKey)
    return result.key ? strings.live(result.key) : result.message
}
