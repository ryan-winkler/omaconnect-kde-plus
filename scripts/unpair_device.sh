#!/usr/bin/env bash
set -euo pipefail

# The controller passes the exact peer and unique connection from the reviewed scan.
owner=${1:-}
peer=${2:-}
[[ $# == 2 && $owner =~ ^:[0-9]{1,30}\.[0-9]{1,30}$ && $peer =~ ^[A-Za-z0-9_]{1,128}$ ]] || exit 64

export LC_ALL=C
path="/modules/kdeconnect/devices/$peer"
interface=org.kde.kdeconnect.device
read_bus() {
    busctl --user --timeout=2 --auto-start=no "$@" 2>/dev/null | head -c 128
}

# Preserve KDE Connect CLI's paired-state check, using the reviewed connection.
paired=$(read_bus get-property "$owner" "$path" "$interface" isPaired) || exit 69
[[ $paired == 'b true' ]] || exit 69
live_owner=$(read_bus call org.freedesktop.DBus /org/freedesktop/DBus \
    org.freedesktop.DBus GetNameOwner s org.kde.kdeconnect) || exit 69
[[ $live_owner == "s \"$owner\"" ]] || exit 69
exec busctl --user --timeout=5 --auto-start=no call "$owner" "$path" "$interface" unpair
