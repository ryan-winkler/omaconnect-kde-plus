# Ring investigation — 29 October 2026

**Finding:** The laptop's local KDE Connect **Find My Phone** module is disabled
for the paired phone. Its ring endpoint is absent. The desktop's module for that
phone is enabled, loaded and exposes the endpoint. This explains why a laptop
ring request cannot reach its local sender interface. It does not yet establish
which host/device/UI produced the owner's reported failure.

No audible ring, pairing action, plugin toggle, phone setting change, daemon
restart or VPN action ran in this investigation. Device IDs, addresses, keys,
phone payloads and raw service logs are omitted from this report.

## Verified path

The fork's action toolbar calls `Panel.triggerAction("ring")`, then
`Service.ringDevice(id)`, then `KdeConnectController.ringDevice(id)`. The controller
checks the selected peer and advertised `kdeconnect_findmyphone` support, then
uses the fixed argument array `kdeconnect-cli -d <ID> --ring`. The original
installed OmaConnect uses the same CLI argument shape. Both hosts have KDE
Connect `26.08.2-1`; both CLI help outputs document `--ring`.

KDE's CLI source sends a D-Bus `ring` call to
`/modules/kdeconnect/devices/<ID>/findmyphone`, interface
`org.kde.kdeconnect.device.findmyphone`. There is no alternative spelling or
missing argument in the fork's command.

## Read-only live observations

| Phone state | Laptop / ARM | Desktop / x86_64 |
| --- | --- | --- |
| Paired | Yes | Yes |
| Reachable | Yes | Yes |
| Advertises Find My Phone support | Yes | Yes |
| Local `isPluginEnabled("kdeconnect_findmyphone")` | **False** | True |
| Local `loadedPlugins()` includes Find My Phone | **No** | Yes |
| Ring interface present at its native D-Bus path | **No**; introspection fails | Yes |

The same phone was identified from each daemon's existing device snapshot.
Queries were limited to pairing/reachability, support, loading, enabled state and
endpoint introspection. No ring method was invoked. The original and fork share
the same native daemon and its per-device plugin setting; installing a second UI
does not enable a disabled native module.

Support, loading and enabled state are separate facts. For this live laptop
observation, the explicit enabled-state read establishes disabled. In the general
UI, **not loaded must not be labelled disabled**: other failures can also leave a
module unloaded.

## Minimal source correction

Keep the supported Ring action discoverable. Before dispatch, if loaded metadata
is known and the local Find My Phone module is absent, block with this recovery:

> Ring is not active locally for this device. Open KDE Connect → Plugin Settings
> and check Find My Phone.

Do not silently enable it. Keep the existing native route available. If loading
metadata is unknown in an older snapshot, retain the existing native-command
fallback rather than inventing a disabled state.

For a successful CLI request, say **Ring request accepted. Audible ringing is not
confirmed.** A command result is not a physical sound receipt. This matches the
fork's existing separation between file submission and actual delivery.

The parent owns the shared controller edit. The independent regression in
`tests/test_ring_readiness.py` executes the actual controller function with fake
devices and a fake action dispatcher. Its initial run failed at **known unloaded
ring must not dispatch**. It also covers known loaded and unknown metadata,
unsupported devices, unchanged capability visibility, exact fixed arguments and
honest request wording. No test can emit a real sound.

## Open checks

1. Confirm the reported target, host and whether the owner used original or Plus.
2. If the failed attempt was laptop → this phone, open the native device's Plugin
   Settings and review Find My Phone. The observed disabled setting is the clear
   local blocker. Enabling it is a separate owner action.
3. With a confirmed target and test authorization, dispatch one ring request and
   ask the owner whether the phone sounded. Observe native-command acceptance
   separately from physical sound. Do not repeat rings as a polling mechanism.
4. If the report was desktop → phone, its local sender path was healthy at this
   snapshot. Investigate that exact attempt's native error and phone state next;
   the laptop finding does not establish a desktop cause.

## Primary sources

- [KDE 26.08.2 CLI](https://github.com/KDE/kdeconnect-kde/blob/v26.08.2/cli/kdeconnect-cli.cpp): `--ring` and its native D-Bus target.
- [KDE 26.08.2 device API](https://github.com/KDE/kdeconnect-kde/blob/v26.08.2/core/device.h): separate supported, loaded and enabled surfaces.
- [KDE 26.08.2 Plugin Settings](https://github.com/KDE/kdeconnect-kde/blob/v26.08.2/app/qml/PluginSettings.qml): native per-device module controls.
- Current source functions and read-only native metadata checks listed above.

## Parent fix and verification

The shared controller now blocks a known-unloaded Ring action with an explicit
native Plugin Settings next step. It preserves the supported capability and does
not infer disabled status from loading state. Accepted dispatch copy describes a
request without claiming audible output. The actual-function regression passes
after the previously failing control. No native module was enabled by this fix.

## Owner confirmation

The owner confirmed the failed action was Plus → the owner-selected phone on the laptop, and that
Ping worked while Ring did not. This matches the read-only disabled-module and
absent-endpoint finding. Ping is a separate native plugin and does not establish
Ring readiness. No native setting or phone sound was changed by this investigation.
