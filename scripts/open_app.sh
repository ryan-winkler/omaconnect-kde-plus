#!/usr/bin/env bash
set -Eeuo pipefail

# Device IDs are data, never options or shell text.
[[ $# -le 2 ]] || exit 2
device_id=${1:-}
plugin_id=${2:-}
[[ -z "$device_id" || "$device_id" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]] || exit 2
[[ -z "$plugin_id" || ( -n "$device_id" && "$plugin_id" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ) ]] || exit 2
app_args=()
[[ -z "$device_id" ]] || app_args=(--device "$device_id")

if command -v kdeconnect-app >/dev/null 2>&1; then
    if [[ -n "$plugin_id" ]]; then
        # Older apps do not expose direct configuration. Do not claim success
        # for a device-list fallback. This probe cannot map a desktop window.
        command -v timeout >/dev/null 2>&1 || exit 69
        help_text=$(QT_QPA_PLATFORM=offscreen timeout 2s kdeconnect-app --help 2>/dev/null) || exit 69
        [[ "$help_text" == *--plugin-config* ]] || exit 69
        app_args+=(--plugin-config "$plugin_id")
    fi
    nohup kdeconnect-app "${app_args[@]}" >/dev/null 2>&1 &
    exit 0

# Older settings frontends have different flags. Open their device list.
elif command -v kdeconnect-settings >/dev/null 2>&1; then
    [[ -z "$plugin_id" ]] || exit 69
    nohup kdeconnect-settings >/dev/null 2>&1 &
    exit 0
elif command -v kcmshell6 >/dev/null 2>&1; then
    [[ -z "$plugin_id" ]] || exit 69
    nohup kcmshell6 kcm_kdeconnect >/dev/null 2>&1 &
    exit 0
fi
exit 127
