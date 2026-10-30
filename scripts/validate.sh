#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

# Never inherit the host display, runtime sockets or personal configuration.
validation_home="$(mktemp -d)"
trap 'rm -rf "$validation_home"' EXIT
export HOME="$validation_home"
export XDG_CONFIG_HOME="$validation_home/config"
export XDG_DATA_HOME="$validation_home/data"
export XDG_CACHE_HOME="$validation_home/cache"
export XDG_STATE_HOME="$validation_home/state"
export XDG_RUNTIME_DIR="$validation_home/runtime"
mkdir -m 700 "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY DISPLAY DBUS_SESSION_BUS_ADDRESS HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP DESKTOP_SESSION GTK_USE_PORTAL GDK_BACKEND
export QT_QPA_PLATFORMTHEME=generic QT_STYLE_OVERRIDE=Fusion QT_QUICK_CONTROLS_STYLE=Basic
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software PYTHONDONTWRITEBYTECODE=1
# Tests substitute all provider mutations. Portal fixtures create their own bus.
dbus-run-session -- python3 -m unittest discover -s tests -p 'test_*.py' -q
node tests/appearance.cjs
node tests/test-bth-control.cjs
node tests/transfer_model_test.js
python3 .github/check_doc_links.py
for script in scripts/*.sh; do
    bash -n "$script"
done

validator=""
if command -v omarchy-plugin-validate >/dev/null 2>&1; then
    validator="$(command -v omarchy-plugin-validate)"
elif [ -n "${OMARCHY_PATH:-}" ] && [ -x "${OMARCHY_PATH}/bin/omarchy-plugin-validate" ]; then
    validator="${OMARCHY_PATH}/bin/omarchy-plugin-validate"
fi

if [ -n "$validator" ] && [ -x "$validator" ]; then
    "$validator" .
    printf '%s\n' "Omarchy plugin validator passed"
else
    printf '%s\n' "exact Omarchy validator unavailable; skipped"
fi

qmllint_cmd=""
if [[ -x /usr/lib/qt6/bin/qmllint ]]; then
    qmllint_cmd=/usr/lib/qt6/bin/qmllint
elif command -v qmllint >/dev/null 2>&1; then
    qmllint_cmd="$(command -v qmllint)"
fi

if [[ -n "$qmllint_cmd" ]]; then
    qml_output="$(mktemp)"
    trap 'rm -f "$qml_output"; rm -rf "$validation_home"' EXIT
    set +e
    omarchy_shell="${OMARCHY_PATH:-/usr/share/omarchy}/shell"
    
    qml_files=(Service.qml BarWidget.qml KdeConnectController.qml AppearanceStore.qml BthControlCard.qml DiscoveryController.qml PanelSectionCatalog.qml)
    if [ -f Panel.qml ]; then qml_files+=(Panel.qml); fi
    for file in controller/*.qml components/*.qml; do
        if [ -f "$file" ]; then qml_files+=("$file"); fi
    done

    "$qmllint_cmd" -I "$omarchy_shell" \
        -I "$omarchy_shell/Ui" \
        -I "$omarchy_shell/Commons" \
        "${qml_files[@]}" >"$qml_output" 2>&1
    status=$?
    set -e
    if [ "$status" -ne 0 ]; then
        printf '%s\n' "qmllint reported actual errors; runtime loader checks are also required"
        printf '%s\n' "$(<"$qml_output")"
        exit "$status"
    elif rg -q 'Warning:' "$qml_output"; then
        printf '%s\n' "qmllint emitted host-import/unqualified-type diagnostics; not claimed warning-free"
        printf '%s\n' "QML loader/runtime verification is the authoritative error check"
    else
        printf '%s\n' "qmllint completed without diagnostics"
    fi
else
    printf '%s\n' "qmllint unavailable; skipped"
fi

printf '%s\n' "validation completed"
