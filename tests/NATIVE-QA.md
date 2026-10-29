# Native QML fixture QA — 29 October 2026

Run from this checkout:

```sh
python3 -m unittest discover -s tests -p test_native_ui.py
```

The current run passes one integration test with 31 QML assertions. Runtime: about
1.7 seconds on this ARM host. Prerequisites: Quickshell, Python Gio, Bubblewrap,
and dbus-run-session. Missing required programs skip this optional native test.

The test copies the actual Service, BarWidget, Panel, controllers and controls.
It uses the installed Commons and Ui components, with the hosting exception below.
It activates actual control signals; it does not claim pointer hit testing or
keyboard focus acceptance.

| Contract | Current evidence |
| --- | --- |
| Own-service bridge and fallback in actual bar/panel | Pass |
| Devices, Send, Activity, Appearance tab signals | Pass |
| Panel icon chooser Apply, saved state reload, Cancel | Pass |
| Device alias reaches own-service display name | Pass |
| Actual portal multiselect reaches actual inspection helper | Pass; two regular files, seven bytes |
| Closing chooser causes no send | Pass; no operation before explicit Send |
| Draft and active peer survive device changes and action reset | Pass; all fake KDE invocations target reviewed peer A |
| One sequential KDE invocation per file | Pass; two accepted calls, then one separately cancelled call |
| Accepted requests retain delivery unknown | Pass |
| In-memory operation summaries omit paths | Pass |
| Cancellation after recorded backend start | Pass; cancellation unconfirmed |
| Clear finished activity | Pass |
| Owner-panel command exits zero without `ok` confirmation | Pass; unavailable remains visible |
| Runtime binding errors after Color qualification repair | Pass; no TypeError or ReferenceError |

## Isolation

Bubblewrap gives the run private process and network namespaces, a read-only host
root, a private writable temporary directory, and a private `/tmp`. HOME, all XDG
directories and the runtime directory belong to that temporary fixture. A fresh
D-Bus session holds only the fake portal. The environment contains no host display,
Wayland, Hyprland or session-bus connection. Qt uses the software offscreen backend.

The command search path is closed. KDE actions, the signal watcher, style probes,
and the BTH helper are fake executables. Fixed absolute paths for KDE, nmcli,
Hyprland and omarchy-shell are overlaid with the fake executable as well. Discovery
uses a fixture helper. Appearance persistence and portal file inspection use the
actual production helpers against fixture files. Temporary receipts are removed
with the fixture. No real transfer, VPN mode action, shell summon or network access
is available to this run.

## Reproduced and repaired finding

The first product load produced `TypeError: Cannot read property 'text' of
undefined` for unqualified `Color.popups.text`, plus undefined color assignments.
On this Qt runtime, the unqualified name selected QtQuick's color type. The parent
qualified product references with `Commons.Color`. The same native integration
command then passed, with the actual Commons singleton and no binding errors.

## Platform gate and remaining limits

A first run with the untouched installed Ui/KeyboardPanel failed before product
instantiation:

```text
Type Plugin.Panel unavailable
Type KeyboardPanel unavailable
No PanelWindow backend loaded.
```

Quickshell has no PanelWindow backend under `QT_QPA_PLATFORM=offscreen`. The passing
fixture therefore substitutes **only KeyboardPanel's window-hosting boundary** with
an Item that supplies its sizing and ownership interface. Actual product Panel
contents and the other native Ui controls remain loaded.

This is native QML logic and control integration evidence. Genuine layer-shell
mapping, positioning, click geometry, compositor focus, scale-two appearance,
RTL layout, AT-SPI/Orca, resource budgets, x86 packaging, real KDE delivery and
physical-device acceptance remain open. The expected Hyprland-unset warning
confirms that this test has no live compositor connection.

## Explicit desktop session check — 29 October 2026

Run only when the owner has requested validation on the current desktop:

```sh
OMACONNECT_DESKTOP_VALIDATION=1 python3 -m unittest discover -s tests -p test_native_ui.py
```

This opt-in keeps the private HOME/D-Bus/fake-provider boundaries. It connects to
only the current Wayland socket and exposes the existing DRI devices for native
OpenGL rendering. It copies only the current public colors.toml/shell.toml into
the private fixture. No installed bar/plugin configuration is changed. The sample
window and panel close when the bounded test exits. The default suite remains
offscreen and never connects to the desktop.

On asahi-omarchy/aarch64, the desktop mode passes **32 assertions**, including
opening the genuine unmodified native KeyboardPanel/PanelWindow. This closes the
previous native-window backend prerequisite for this desktop session. It does not
prove activation inside the installed replacement bar, pointer hit testing,
physical keyboard/AT behavior, x86_64 or physical file delivery.

Optional content-only PNGs and a log are saved outside the source checkout in
`outputs/desktop-validation`. The PNGs have transparent backgrounds and omit the
native popup card. They are layout evidence, not composited contrast acceptance.
Expected isolation warning: no Hyprland IPC connection. Qt Wayland text-input
warnings also occurred during popup focus changes; the run is not warning-free.

## Current follow-up evidence

The full runner now executes 141 Python tests plus the three JS suites. In addition
to the original control-signal fixture, `test_keyboard.py` sends actual Qt key
events and passes 29 assertions. It reaches native feature details and each new
owner button without launching a live owner, then BTH and both text editors.
This offscreen evidence uses the same hosting substitution described above.

On Kintsugi x86_64, the updated native integration passed 32 assertions with the real
installed KeyboardPanel and Wayland socket under the opt-in isolated desktop mode.
No hosting substitution is used for that run. Provider actions remain fake and
private HOME/D-Bus/network isolation remain. Nonfatal Wayland text-input warnings
were observed; pointer/focus/AT, scale/RTL and owner-launch acceptance remain open.
