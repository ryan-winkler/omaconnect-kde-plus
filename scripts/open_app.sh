#!/usr/bin/env bash
set -Eeuo pipefail

# Device IDs are data, never options or shell text.
[[ $# -le 1 ]] || exit 2
device_id=${1:-}
[[ -z "$device_id" || "$device_id" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]] || exit 2
app_args=()
[[ -z "$device_id" ]] || app_args=(--device "$device_id")

if command -v kdeconnect-app >/dev/null 2>&1; then
    nohup kdeconnect-app "${app_args[@]}" >/dev/null 2>&1 &
    exit 0

# Older settings frontends have different flags. Open their device list.
elif command -v kdeconnect-settings >/dev/null 2>&1; then
    nohup kdeconnect-settings >/dev/null 2>&1 &
    exit 0
elif command -v kcmshell6 >/dev/null 2>&1; then
    nohup kcmshell6 kcm_kdeconnect >/dev/null 2>&1 &
    exit 0
fi
exit 127
