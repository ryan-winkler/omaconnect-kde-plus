#!/usr/bin/env bash
set -Eeuo pipefail

# Keep the QML process boundary stable: one tab-separated record per device,
# and a non-zero exit for missing dependencies, D-Bus errors, or bad replies.
base=/modules/kdeconnect

for command in gdbus sed grep tr; do
    command -v "$command" >/dev/null 2>&1 || exit 127
done

# kdeconnect-cli is optional: daemon discovery works without it; --refresh is best-effort.

is_daemon_running() {
    gdbus call --session --dest org.freedesktop.DBus \
        --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.NameHasOwner org.kde.kdeconnect 2>/dev/null \
        | grep -q '(true,)'
}

ensure_daemon() {
    if ! is_daemon_running; then
        gdbus call --session --dest org.freedesktop.DBus \
            --object-path /org/freedesktop/DBus \
            --method org.freedesktop.DBus.StartServiceByName org.kde.kdeconnect 0 >/dev/null 2>&1 || true
        sleep 0.5
    fi
}

if [[ "${1:-}" == "--refresh" || "${1:-}" == "-r" ]]; then
    ensure_daemon
    if command -v kdeconnect-cli >/dev/null 2>&1; then
        kdeconnect-cli --refresh >/dev/null 2>&1 || true
    fi
    gdbus call --session --dest org.kde.kdeconnect \
        --object-path /modules/kdeconnect \
        --method org.kde.kdeconnect.daemon.forceOnNetworkChange >/dev/null 2>&1 || true
    sleep 1.2
fi

is_daemon_running || exit 69

property() {
    local path=$1 interface=$2 name=$3
    gdbus call --session --dest org.kde.kdeconnect \
        --object-path "$path" --method org.freedesktop.DBus.Properties.Get \
        "$interface" "$name" 2>/dev/null || return 69
}

sanitize_field() {
    local field=$1
    field=${field//$'\t'/ }
    field=${field//$'\n'/ }
    printf '%s' "$field"
}

value() {
    # gdbus quotes strings as <'value'> and scalar values as <value>.
    printf '%s' "$1" | sed -E "s/^\((true|false),\)$/\1/; s/^\(<[[:space:]]*'(.*)',[[:space:]]*>,\)$/\1/; s/^\(<('([^']|\\\\')*'|[^>]+)>.*$/\1/; s/^<'(.*)'>,?$/\1/; s/^<([^>]*)>,?$/\1/; s/^'(.*)'$/\1/; s/^'(.*)',$/\1/"
}

plugin_ids() {
    # Native GVariant string arrays only. Keep future plugin IDs without a UI whitelist.
    # ponytail: 256 IDs / 32 KiB per list; raise with evidence if native KDE grows past this.
    local raw=$1 list token result="" count=0
    local pattern="^[[:space:]]*'([A-Za-z0-9_][A-Za-z0-9_.-]{0,127})'[[:space:]]*(,|$)"
    [[ ${#raw} -le 32768 && "$raw" == *'['*']'* ]] || return 1
    list=${raw#*\[}
    list=${list%%\]*}
    while [[ "$list" =~ $pattern ]]; do
        token=${BASH_REMATCH[1]}
        list=${list:${#BASH_REMATCH[0]}}
        ((count+=1))
        [[ $count -le 256 ]] || return 1
        [[ ",$result," == *",$token,"* ]] || result="${result:+$result,}$token"
    done
    [[ "$list" =~ ^[[:space:]]*$ ]] || return 1
    printf '%s' "$result"
}

ids=$(gdbus call --session --dest org.kde.kdeconnect --object-path "$base" \
    --method org.kde.kdeconnect.daemon.devices false false) || exit 69
entries=$(printf '%s' "$ids" | sed -E 's/.*\[//; s/\].*//' | tr ',' '\n' \
    | sed -nE "s/^[[:space:]]*['\"]?([^'\"]+)['\"]?[[:space:]]*$/\1/p")
[[ -n "$entries" || "$ids" =~ ^\((@as[[:space:]]+)?\[[[:space:]]*\],[[:space:]]*\)$ ]] || exit 70

# KDE Connect owns this list and persists it. Exposing it in the same snapshot
# lets the UI add Tailscale or other VPN addresses without a second database.
if custom_raw=$(property "$base" org.kde.kdeconnect.daemon customDevices 2>/dev/null); then
    printf 'CUSTOM_ADDRESSES_READY\n'
    custom_entries=$(printf '%s' "$custom_raw" | sed -E 's/.*\[//; s/\].*//' | tr ',' '\n' \
        | sed -nE "s/^[[:space:]]*['\"]?([^'\"]+)['\"]?[[:space:]]*$/\1/p")
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
    name=$(value "$(property "$path" org.kde.kdeconnect.device name)") || continue
    type=$(value "$(property "$path" org.kde.kdeconnect.device type)") || continue
    paired=$(value "$(property "$path" org.kde.kdeconnect.device isPaired)") || continue
    reachable=$(value "$(property "$path" org.kde.kdeconnect.device isReachable)") || continue
    pair_requested=$(value "$(property "$path" org.kde.kdeconnect.device isPairRequested 2>/dev/null)") || pair_requested=false
    pair_requested_by_peer=$(value "$(property "$path" org.kde.kdeconnect.device isPairRequestedByPeer 2>/dev/null)") || pair_requested_by_peer=false
    verification_key=$(value "$(property "$path" org.kde.kdeconnect.device verificationKey 2>/dev/null)") || verification_key=""
    [[ "$pair_requested" == true ]] || pair_requested=false
    [[ "$pair_requested_by_peer" == true ]] || pair_requested_by_peer=false

    supported=$(property "$path" org.kde.kdeconnect.device supportedPlugins) || continue
    plugins=$(plugin_ids "$supported") || plugins=""
    # Loading is distinct from support and from a user's enabled setting.
    loaded_plugins=""
    loaded_known=false
    if loaded_raw=$(gdbus call --session --dest org.kde.kdeconnect \
        --object-path "$path" --method org.kde.kdeconnect.device.loadedPlugins 2>/dev/null) \
        && loaded_plugins=$(plugin_ids "$loaded_raw"); then
        loaded_known=true
    fi

    charge=-1
    charging=false
    if [[ "$plugins" == *kdeconnect_battery* ]]; then
        battery="$path/battery"
        charge_raw=$(value "$(property "$battery" org.kde.kdeconnect.device.battery charge)") || charge_raw=""
        [[ "$charge_raw" =~ ^[0-9]+$ ]] && charge=$charge_raw
        charging_raw=$(value "$(property "$battery" org.kde.kdeconnect.device.battery isCharging)") || charging_raw=false
        [[ "$charging_raw" == true ]] && charging=true
    fi
    net_type=
    net_strength=-1
    if [[ "$plugins" == *kdeconnect_connectivity_report* ]]; then
        conn="$path/connectivity_report"
        type_raw=$(value "$(property "$conn" org.kde.kdeconnect.device.connectivity_report cellularNetworkType)") || type_raw=""
        strength_raw=$(value "$(property "$conn" org.kde.kdeconnect.device.connectivity_report cellularNetworkStrength)") || strength_raw=""
        [[ -n "$type_raw" && "$type_raw" != "null" ]] && net_type=$type_raw
        [[ "$strength_raw" =~ ^[0-9]+$ ]] && net_strength=$strength_raw
    fi
    printf 'DEVICE\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(sanitize_field "$id")" "$(sanitize_field "$name")" "$(sanitize_field "$type")" "$paired" "$reachable" "$charge" "$charging" "$plugins" "$(sanitize_field "$net_type")" "$net_strength" "$pair_requested" "$pair_requested_by_peer" "$(sanitize_field "$verification_key")" "$loaded_plugins" "$loaded_known"
done <<< "$entries"
