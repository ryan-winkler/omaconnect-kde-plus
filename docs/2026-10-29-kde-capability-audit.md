# Native KDE Connect capability audit — 29 October 2026

**Decision:** Keep daily actions in OmaConnect. Provide an always-visible **All
KDE Connect features** route to the selected peer in the native app. Native KDE
Connect keeps plugin settings, permissions, pairing and protocol ownership.

This audit host has `kdeconnect 26.08.2-1` and 31 native plugin libraries. A library
being installed does not establish that a peer supports it, that the user enabled
it, or that an operation can succeed. Other devices and platforms can differ.

## Findings and repair

| Finding | Repair | Evidence |
|---|---|---|
| Discovery retained only 11 hardcoded IDs; other native features disappeared from the snapshot. | Preserve safe IDs from the full returned support list, including unknown third-party IDs. | Real discovery-script fixture retains notifications, SFTP, a future KDE ID and `thirdparty.custom-addon`. |
| Support could be mistaken for enabled or loaded state. | Append an optional loaded list and explicit `loadedKnown` flag. Show support and loading separately. Never infer enabled state. | Actual QML parser fixture covers known loaded state and older records; shell fixtures cover missing, invalid and empty replies. |
| Gear icon offered a weak route to the native feature set. | Add a labelled native-app button and optional feature details with task names and raw IDs. | `components/NativeFeaturesSection.qml`; parent composes it into Devices. |
| Remote-command quick action checked the receiver plugin `kdeconnect_runcommand`. | Check sender-side `kdeconnect_remotecommands`, matching the CLI's `RemoteCommandsDbusInterface`. | Actual QML parser direction fixture and KDE CLI source. |
| Media controls target `/mprisremote`, while their capability also accepted receiver-side `mpriscontrol` and an old alias. | Require `kdeconnect_mprisremote` for these controls. Receiver capability stays visible in full details. | Actual QML parser direction fixture; existing media dispatch tests. |
| Native app opened its generic page. | Pass the selected KDE ID as a fixed `--device` argument to `kdeconnect-app`. Older frontends open their device list. | Closed-PATH launcher fixtures check exact argv, all fallbacks and invalid inputs. |

No plugin is automatically enabled, installed or configured. Features such as
SMS, file browsing, notifications, input and commands remain subject to native
permissions and peer support. Native Plugin settings is the authority. The fork
cannot grant phone permissions or manufacture a missing remote capability.

## Boundary contract

Discovery retains the existing TSV fields 0–13. Field 8 is the full supported-ID
CSV. Field 14 is loaded-ID CSV; field 15 is literal `true` when the loaded list is
known. Older records omit both and become unknown. The optional daemon call is
`org.kde.kdeconnect.device.loadedPlugins`, a method, not a property.

Lists accept at most 256 IDs and 32 KiB of raw GVariant text. Each ID matches
`[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}`. The `kdeconnect_` prefix is not required.
Unknown safe IDs retain the native-app route. Invalid or oversized metadata is
not passed through as feature names. It does not remove the known device.

The launcher accepts zero or one device ID with the same safe argument grammar.
It uses fixed argv. It never accepts a command, plugin argument or URL. In KDE
26.08.2, `--plugin-config` requires a plugin ID plus `--device`; it is not a
standalone route to all plugin settings. The fork deliberately opens the device
page instead. Starting the app is a launch request, not proof that the page was
rendered or accepted by the user.

## Validation and limits

`python3 -m unittest tests/test_native_features.py tests/test_state.py -q` passed
**92 tests** after integration of the source changes. Four focused checks execute
the real scripts or the actual QML parser. External providers are fake, with a
closed PATH for launcher checks. No installed application was launched, no
notification/SMS/file payload was read, and no plugin setting was written.

Native loading of the new component and mapped keyboard/assistive-technology
acceptance are separate integration checks. Source and fake-provider evidence
do not establish that every native plugin works on every paired device.

## Primary sources

- [KDE 26.08.2 device API](https://github.com/KDE/kdeconnect-kde/blob/v26.08.2/core/device.h): supported list, loaded method, enabled setting are distinct surfaces.
- [KDE 26.08.2 CLI](https://github.com/KDE/kdeconnect-kde/blob/v26.08.2/cli/kdeconnect-cli.cpp): remote commands use `RemoteCommandsDbusInterface`.
- [KDE 26.08.2 application arguments](https://github.com/KDE/kdeconnect-kde/blob/v26.08.2/app/main.cpp): selected-device and plugin-configuration arguments.
- Installed plugin libraries and the fork's existing `scripts/media_control.sh`.
