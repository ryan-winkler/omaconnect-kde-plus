# Native QML tests

The native tests load the real Service, BarWidget, Panel, controllers and Omarchy
UI controls, then drive their signals against fake providers.

```sh
python3 -m unittest discover -s tests -p test_native_ui.py
```

Prerequisites: Quickshell, Python Gio, Bubblewrap and `dbus-run-session`. The test
skips when one is missing. `scripts/validate.sh` runs it with the full suite.

## Isolation

Bubblewrap gives the run private process and network namespaces, a read-only host
root and a private `/tmp`. HOME, all XDG directories and the runtime directory
belong to a temporary fixture. A fresh D-Bus session holds only a fake file portal.
There is no display, Wayland, Hyprland or session-bus connection, and Qt uses the
software offscreen backend.

KDE actions, the signal watcher, style probes and the Back to Home helper are fake
executables; fixed paths for KDE, nmcli, Hyprland and omarchy-shell point to them
too. Appearance storage and portal file inspection use the production helpers
against fixture files. No real transfer, VPN action, shell summon or network
access is possible.

Quickshell has no PanelWindow backend under `QT_QPA_PLATFORM=offscreen`, so the
offscreen run replaces only KeyboardPanel's window-hosting boundary with an Item.
The panel contents and other controls stay real.

The Settings fixtures also check exact-device native configuration launch,
unsupported-frontend feedback, the separate peer command-editor request, and
Tab/Shift+Tab visibility in all four pages at the minimum 520 × 440 window size.
The metadata fixture enumerates installed configuration pages using explicit
read-only roles, without a device target or native configuration directory.
These checks do not prove that a real native or remote editor opened or saved.

## Desktop session mode

To open the real KeyboardPanel on your current Wayland desktop:

```sh
OMACONNECT_DESKTOP_VALIDATION=1 python3 -m unittest discover -s tests -p test_native_ui.py
```

This keeps the private HOME, D-Bus and fake providers. It connects only to the
current Wayland socket and the DRI devices, and copies only the public
`colors.toml` and `shell.toml` into the fixture. No installed plugin or bar
configuration changes. The sample window closes when the test exits.

## What these tests do not cover

Offscreen screenshots stay in the private temporary fixture by default. To keep
the synthetic captures, set `OMACONNECT_CAPTURE_DIR` to an explicit output folder
when running the tests. This exports images only; no personal configuration is
read or copied.

Pointer hit testing, compositor focus, scale and RTL layout, screen readers, real
KDE delivery and physical devices need manual checks. Hyprland-unset and Qt
Wayland text-input warnings are expected.
