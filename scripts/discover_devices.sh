#!/usr/bin/env bash
set -Eeuo pipefail

# Device discovery over the KDE Connect daemon D-Bus interface.
#
# Transport is `busctl --user --json=short` (systemd), parsed by
# discover_report.py. The previous gdbus text output went through a
# 6-substitution sed chain that broke on apostrophes, angle-bracket type
# wrappers and multiline values; structured JSON cannot be forged by hostile
# device names. Dependency change: busctl (systemd) + python3 instead of
# gdbus (omarchy-connect already requires busctl; python3 was already
# required for the media status path).
#
# Stdout contract consumed by KdeConnectController.qml parseScanLine:
#   CUSTOM_ADDRESSES_READY or CUSTOM_ADDRESSES_UNAVAILABLE
#   CUSTOM_ADDRESS<TAB><addr>              (one per saved custom address)
#   DEVICE<TAB> + 15 more tab-separated fields:
#       id name type paired reachable charge charging plugins netType
#       netStrength pairRequested pairRequestedByPeer verificationKey
#       loadedPlugins loadedKnown
#   An optional final JSON field carries bounded addresses, providers and monitor state.
# Each device is read with ONE org.freedesktop.DBus.Properties GetAll call
# on interface org.kde.kdeconnect.device (name, type, isPaired, isReachable,
# isPairRequested, isPairRequestedByPeer, supportedPlugins, verificationKey)
# instead of one call per property, plus best-effort GetAll calls on the
# battery / connectivity_report sub-objects and a best-effort loadedPlugins
# call. Tabs/newlines in remote values are folded to spaces (anti-spoofing of
# the TSV record).
#
# Exit codes: 127 confirmed KDE absence, 78 missing helper dependencies,
# 69 daemon down / D-Bus error, 70 malformed reply, 64 bad usage.
base=/modules/kdeconnect
# Bounded provider output: busctl's method-call deadline and one reply's size
# (MAX_REPLY_BYTES matches discover_report.py).
BUSCTL_TIMEOUT=5
MAX_REPLY_BYTES=65536

for command in busctl python3 head; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf '%s\n' "Discovery needs busctl and Python 3. Check the system tools, then select Refresh." >&2
        exit 78
    fi
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
report="$script_dir/discover_report.py"

# kdeconnect-cli is optional: daemon discovery works without it; --refresh is best-effort.

busctl_json() {
    # Structured JSON only; any D-Bus failure maps onto the 69 protocol.
    # A reply over the cap is malformed (70) and never reaches the parser.
    local LC_ALL=C reply
    reply=$(busctl --user --json=short --timeout="$BUSCTL_TIMEOUT" "$@" 2>/dev/null \
        | head -c "$((MAX_REPLY_BYTES + 1))") || return 69
    (( ${#reply} <= MAX_REPLY_BYTES )) || return 70
    printf '%s' "$reply"
}

is_daemon_running() {
    local reply
    reply=$(busctl_json call org.freedesktop.DBus /org/freedesktop/DBus \
        org.freedesktop.DBus NameHasOwner s org.kde.kdeconnect) || return 69
    printf '%s' "$reply" | python3 "$report" truthy
}

ensure_daemon() {
    if ! is_daemon_running; then
        busctl --user --timeout="$BUSCTL_TIMEOUT" call org.freedesktop.DBus /org/freedesktop/DBus \
            org.freedesktop.DBus StartServiceByName su org.kde.kdeconnect 0 >/dev/null 2>&1 || true
        sleep 0.5
    fi
}

if [[ "${1:-}" == "--refresh" || "${1:-}" == "-r" ]]; then
    ensure_daemon
    if command -v kdeconnect-cli >/dev/null 2>&1; then
        kdeconnect-cli --refresh >/dev/null 2>&1 || true
    fi
    busctl --user --timeout="$BUSCTL_TIMEOUT" call org.kde.kdeconnect "$base" \
        org.kde.kdeconnect.daemon forceOnNetworkChange >/dev/null 2>&1 || true
    sleep 1.2
fi

if is_daemon_running; then
    : # A working daemon is sufficient; kdeconnect-cli remains optional.
else
    status=$?
    [[ "$status" == 1 ]] || exit 69
    # A stopped installed daemon is unavailable, not a reason to reinstall.
    for command in kdeconnect-cli kdeconnect-app kdeconnectd; do
        if command -v "$command" >/dev/null 2>&1; then exit 69; fi
    done
    registered=$(busctl_json call org.freedesktop.DBus /org/freedesktop/DBus \
        org.freedesktop.DBus ListActivatableNames) || exit 69
    if printf '%s' "$registered" | python3 "$report" registered; then
        exit 69
    else
        status=$?
        [[ "$status" == 1 ]] && exit 127
        exit 69
    fi
fi

sanitize_field() {
    local field=$1
    field=${field//$'\t'/ }
    field=${field//$'\n'/ }
    printf '%s' "$field"
}

ids_raw=$(busctl_json call org.kde.kdeconnect "$base" \
    org.kde.kdeconnect.daemon devices bb false false) || exit 69
entries=$(printf '%s' "$ids_raw" | python3 "$report" ids) || exit 70

# KDE Connect owns this list and persists it. Exposing it in the same snapshot
# lets the UI add Tailscale or other VPN addresses without a second database.
if custom_raw=$(busctl_json get-property org.kde.kdeconnect "$base" \
    org.kde.kdeconnect.daemon customDevices) \
    && custom_entries=$(printf '%s' "$custom_raw" | python3 "$report" addresses); then
    printf 'CUSTOM_ADDRESSES_READY\n'
    while IFS= read -r address; do
        [[ -n "$address" ]] || continue
        printf 'CUSTOM_ADDRESS\t%s\n' "$(sanitize_field "$address")"
    done <<< "$custom_entries"
else
    printf 'CUSTOM_ADDRESSES_UNAVAILABLE\n'
fi

while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    path="$entry"
    [[ "$path" == /* ]] || path="$base/devices/$entry"
    id=${path##*/}
    device_json=$(busctl_json call org.kde.kdeconnect "$path" \
        org.freedesktop.DBus.Properties GetAll s org.kde.kdeconnect.device) || continue
    # Sub-objects only exist while their plugin is loaded; failure means n/a.
    battery_json=$(busctl_json call org.kde.kdeconnect "$path/battery" \
        org.freedesktop.DBus.Properties GetAll s org.kde.kdeconnect.device.battery) || battery_json=""
    conn_json=$(busctl_json call org.kde.kdeconnect "$path/connectivity_report" \
        org.freedesktop.DBus.Properties GetAll s org.kde.kdeconnect.device.connectivity_report) || conn_json=""
    # Loading is distinct from support and from a user's enabled setting.
    loaded_json=$(busctl_json call org.kde.kdeconnect "$path" \
        org.kde.kdeconnect.device loadedPlugins) || loaded_json=""
    monitor_json=""
    if python3 "$report" supports "$device_json" kdeconnect_virtualmonitor; then
        monitor_json=$(busctl --user --json=short --timeout=2s call org.kde.kdeconnect "$path/virtualmonitor" \
            org.freedesktop.DBus.Properties GetAll s org.kde.kdeconnect.device.virtualmonitor 2>/dev/null) || monitor_json=""
    fi
    python3 "$report" device "$id" "$device_json" "$battery_json" "$conn_json" "$loaded_json" "$monitor_json" || continue
done <<< "$entries"
