#!/usr/bin/env bash
set -Eeuo pipefail

# Keep this native launcher boundary aligned with the device-settings launcher.
[[ $# -le 1 ]] || exit 2
device_id=${1:-}
[[ -z "$device_id" || "$device_id" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]] || exit 2
command -v kdeconnect-sms >/dev/null 2>&1 || exit 127
if [[ -n "$device_id" ]]; then
    nohup kdeconnect-sms --device "$device_id" >/dev/null 2>&1 &
else
    nohup kdeconnect-sms >/dev/null 2>&1 &
fi
exit 0
