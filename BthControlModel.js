.pragma library

var MAX_STATUS = 8192
var MODES = ["auto", "on", "off"]
var STATES = ["active", "activating", "deactivating", "inactive"]
var PHASES = ["ready", "degraded", "offline", "unverified", "error", "not-run", "applied", "pending"]
var ERRORS = ["invalid-control-state", "not-configured", "unsafe-profile", "not-preauthorized"]

function validHelperPath(path) {
    return typeof path === "string" && path.charAt(0) === "/" && path.length <= 4096
        && path.slice(-19) === "/remote-access-mode" && !/[\x00-\x1f\x7f]/.test(path)
        && path.split("/").indexOf("..") < 0
}

function unknown() {
    return {known: false, configured: false, profile_safe: false, control_valid: false,
        nm_control: false, pending: false, control_mode: "unknown", connection_state: "unknown", error: null, last_apply_failed: false, last_report_age_seconds: null}
}
function parse(text) {
    if (typeof text !== "string" || !text || text.length > MAX_STATUS) return unknown()
    try { if (unescape(encodeURIComponent(text)).length > MAX_STATUS) return unknown() } catch (_) { return unknown() }
    var data
    try { data = JSON.parse(text) } catch (_) { return unknown() }
    if (!data || typeof data !== "object" || Array.isArray(data) || data.schema_version !== 1
            || MODES.indexOf(data.control_mode) < 0 || STATES.indexOf(data.connection_state) < 0
            || (data.error !== null && ERRORS.indexOf(data.error) < 0)) return unknown()
    var booleans = ["configured", "profile_safe", "control_valid", "nm_control", "pending"]
    for (var i = 0; i < booleans.length; i++) if (typeof data[booleans[i]] !== "boolean") return unknown()
    var last = data.last_report
    var phase = last && typeof last === "object" && !Array.isArray(last) && PHASES.indexOf(last.phase) >= 0 ? last.phase : ""
    var age = last && typeof last.age_seconds === "number" && isFinite(last.age_seconds) && last.age_seconds >= 0 && last.age_seconds <= 31536000 ? last.age_seconds : null
    // Keep only the fixed scalar contract. Never retain arbitrary output fields.
    return {known: true, configured: data.configured, profile_safe: data.profile_safe,
        control_valid: data.control_valid, nm_control: data.nm_control, pending: data.pending,
        control_mode: data.control_mode, connection_state: data.connection_state, error: data.error,
        last_apply_failed: phase === "error", last_report_age_seconds: age}
}
function command(mode) {
    return mode === "auto" ? "auto" : mode === "on" ? "bth-on" : mode === "off" ? "bth-off" : ""
}
function modeLabel(mode) {
    return mode === "auto" ? "Automatic" : mode === "on" ? "On" : mode === "off" ? "Off" : "Unknown"
}
function selectedModeLabel(status) {
    return !status.known ? "Unknown" : status.control_valid ? modeLabel(status.control_mode) : "Needs review"
}
function isSelected(status, mode) {
    return status.known && status.control_valid && command(mode) !== "" && status.control_mode === mode
}
function stateLabel(state) {
    return state === "active" ? "On (interface active)" : state === "inactive" ? "Off"
        : state === "activating" ? "Turning on" : state === "deactivating" ? "Turning off" : "Unknown"
}
function errorText(status) {
    if (!status.known) return "Status is unavailable. The connection state is not confirmed."
    if (!status.configured || status.error === "not-configured") return "The saved bth-home profile is missing or cannot be identified."
    if (!status.nm_control || status.error === "not-preauthorized") return "NetworkManager control is not authorized. Use the normal system approval."
    if (!status.profile_safe || status.error === "unsafe-profile") return "The saved profile needs review. On and Automatic are unavailable; Off can stop this exact profile."
    if (!status.control_valid || status.error === "invalid-control-state") return "The saved control mode is invalid. Choose Off or Automatic to replace it."
    return ""
}
function canRun(status, mode, busy) {
    if (busy || !command(mode) || !status.known || !status.configured || !status.nm_control) return false
    // Off must still stop the exact managed profile after a route/DNS safety drift.
    if (mode === "off") return true
    return status.profile_safe && (mode === "auto" ? (status.error === null || status.error === "invalid-control-state") : status.control_valid && status.error === null)
}
function confirmed(status, wanted) {
    if (!canRun(status, wanted, false) || !status.control_valid || status.pending || status.last_apply_failed || status.control_mode !== wanted) return false
    return wanted === "on" ? status.connection_state === "active"
        : wanted === "off" ? status.connection_state === "inactive" : wanted === "auto" && (status.connection_state === "active" || status.connection_state === "inactive")
}
function pendingText(status, wanted) {
    if (status.last_apply_failed) return "Last apply failed. Inspect status, or choose Off or Automatic."
    if (wanted && !confirmed(status, wanted)) return "Requested " + modeLabel(wanted) + ". Waiting for actual NetworkManager state."
    return status.pending ? "The saved mode is pending. Actual interface state is shown separately." : ""
}

/*
Adapted from banan.bananet.
MIT License

Copyright (c) 2026 banan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
