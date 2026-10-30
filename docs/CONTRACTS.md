# Provider and storage contracts

All new helpers use fixed argv plus bounded JSON stdin/stdout. Raw provider stderr
is not shown in the UI. These are local process contracts; the fork adds no HTTP
server, arbitrary REST proxy, protocol daemon or cross-plugin service API.

## Runtime identity and retained storage

The Community machine ID and IPC target are `omaconnect.plus`. The display name
remains Omaconnect KDE Plus. The private config, data and cache directories keep
the existing `Omaconnect.plus` spelling. This preserves aliases, icons, address
records and cache ownership without copying or resetting them. Plugin ID and
storage path are separate contracts; do not derive one from the other.

A former uppercase-ID installation needs an explicit bar/service reference and
source-directory migration; native update alone does not do this. The stage-only
migration helper accepts `--source-id Omaconnect.plus`, preserves understood
settings and enablement, and emits no appearance candidate for that source.
See [install and recovery](INSTALL.md). Native pairings remain with KDE Connect.

## Appearance helper

`python3 scripts/appearance.py read|update|import|library` reads one JSON line.
Responses contain `ok` plus a validated `snapshot`, private `asset_dir`, warnings
and invalid asset names, or a bounded user-facing error. Update actions are:

| Action | Request fields |
| --- | --- |
| `bar` | `icon` |
| `device` | `device_id`, `alias`, `icon` |
| `link` | `device_id`, `syncthing_device_id` or null |
| `forget` | `device_id` |

Metadata schema 1 contains `schema_version`, `bar_icon` and `devices` keyed by
`kdeconnect:<stable-id>`. A device record has an alias, icon and optional explicit
Syncthing ID. ID namespaces remain separate. A syntactically valid link is local
metadata; it does not prove that Syncthing has configured that peer.

Modes are automatic, preset, theme, glyph, image and device inherit. Rendering is
symbolic or color. Limits: 80 Unicode characters per alias, 8 per symbol, 256 device
records and 256 KiB metadata. State is in XDG_CONFIG_HOME/Omaconnect.plus; copied
assets are in XDG_DATA_HOME/Omaconnect.plus/icons. Private directories/files use
0700/0600. Writes lock, merge and atomically replace; incompatible state is kept.
Imported PNG/SVG is at most 1 MiB and 512×512. Active/external SVG, animation,
recursive reuse, invalid PNG structure and unsafe files are rejected. Hash-named
assets are checked on load. Missing/rejected assets show Phone with a warning.

The installed-icon inventory includes a `library_truncated` boolean and at most
1,024 candidate names. The UI resolves them through the active Qt theme; presence
in the inventory alone is not an availability claim. See [icon sources](ICONS.md).

Theme-icon metadata can include `tint: true` with `render: "symbolic"` for an
explicit foreground override. The field is a boolean and valid only for theme
icons. Other types, other modes and a conflicting colour-render value are
rejected. Legacy theme entries without the flag retain automatic rendering;
reading does not rewrite their stored metadata.

## File chooser and submission

`scripts/pick_file.sh` runs `portal_files.py choose`. A normal FileChooser portal
response is inspected before a draft reaches QML. Only local file URIs, readable
regular files and at most 100 files/1 TiB are allowed. Final symlinks, folders,
FIFO/devices and changed source identity are rejected. Parent-path links are
resolved by the normal filesystem; they are not treated as trust credentials.

`portal_files.py submit` reads `peerId` and one inspected `file` through stdin.
The helper rechecks file identity and holds an `O_NOFOLLOW` descriptor. It uses a
canonical existing path only when the source and every ancestor have trusted
ownership and write permissions. Other sources use a private descriptor-backed
snapshot through `private_sources.py`, with a reflink first and a 1 MiB copy loop
fallback. The helper then calls `shareUrls` on `org.kde.kdeconnect.device.share`
at `/modules/kdeconnect/devices/<reviewed-id>/share` with one percent-encoded
`file://` URL, as `kdeconnect-cli --share` does. The path never enters process
arguments. The call uses `send_text.py`'s D-Bus client without service autostart.
Preparation has a 120-second work deadline, cancellation checks between chunks,
a 64 MiB free-space reserve, and source identity checks after copying. Blocking
filesystem calls cannot be forcibly preempted by that deadline. Snapshots have
0700 directories and 0600 files below the XDG cache path documented in [Help](HELP.md).
They become eligible after 24 hours. `portal_files.py sweep` tries to remove eligible
copies once when the plugin starts, and later preparation retries, when the cache
is safe and available. The sweep never creates the cache. KDE opens the file later
and reports no completion for the request, so Plus cannot delete a copy sooner. Protected-file preparation treats cache
housekeeping as best effort; shared-file snapshots still require a safe cache. Cleanup accepts only the exact owned flat snapshot
shape; it preserves unrelated or unexpected state. A process deadline is 15 seconds. The queue invokes one helper per file in order.
There is no automatic retry after an ambiguous timeout.

| State | Evidence |
| --- | --- |
| `queued` | Not yet submitted |
| `preparing` | Validating or snapshotting; this file has not reached KDE |
| `submitting` | D-Bus share call has started |
| `request_accepted` | KDE accepted the call; delivery unknown |
| `submission_failed` | Request could not be submitted / D-Bus error |
| `submission_unknown` | Deadline after invocation; check for duplicates |
| `cancelled_before_submit` | Queue item stopped before invocation |
| `cancellation_unconfirmed` | Stop requested after invocation; remote result unknown |

Operation summaries contain provider, reviewed ID/name, count/size, aggregate
counters and timestamps. They hold no raw paths and have a 50-operation memory
limit. The transient draft/queue does hold selected paths until use/cancellation.
Shared sources reach KDE
through the retained private snapshot. Protected private sources keep the native
pathname flow. Same-UID code and root remain trusted. No native atomic descriptor
handoff is claimed. A running helper without a final cancellation acknowledgement
leaves cancellation unconfirmed, even if the progress event was not observed.

## Private text and ping submission

Text/link composition and custom Ping messages use `scripts/send_text.py`.
The process command is fixed: Python plus the installed helper path. The reviewed
peer, operation and content travel in one JSON line through stdin. Content does
not enter argv, environment variables or temporary files. The bound is 8192 text
characters and 64 KiB input. Native D-Bus object-path validation is independent
of the normal device label.

The helper uses the existing session bus with a fixed service, object path suffix,
interface and method: KDE `shareText(s)` or `sendPing(s)`. It disables service
auto-start and applies a five-second method timeout. Replies/errors use fixed
codes and never reflect payloads or provider diagnostics. A successful method
reply means request acceptance; it does not prove delivery. The user session,
KDE daemon and same-user bus clients remain trusted.

## Existing BTH controller

The configured absolute helper path receives only `control-status`, `auto`,
`bth-on` or `bth-off`. Status deadline: 4 seconds; action: 8 seconds; reply limit:
8 KiB. Schema version 1, booleans/enums and errors are checked by BthControlModel.
Unknown/invalid status cannot authorize an action. On/Automatic need safe,
authorized state. Off can stop the exact authorized configured profile after a
safety drift. Saved intent and observed interface state remain separate. The card
polls only while the panel is open. It does not inspect keys, call WireGuard,
change NM directly, enroll profiles or prove a handshake/service connection.

## Saved addresses

`python3 scripts/manage_addresses.py` receives `{"changes":[...]}`. Batch maximum:
32; metadata/candidate maximum: 256 / 256 KiB. Entries require `peer_id`, a private
IP literal, source manual/bth/wireguard/tailscale and explicit approval. Tailscale
provenance additionally permits IPv4 100.64.0.0/10. Other sources still reject that
range; it is an address hint, not an authenticated Tailscale identity. BTH IPv6 is disabled
under the current policy. No hostnames, subnets, scans, automatic pairing or trust
from an address is accepted.

An owner-only record stores provenance, automatic opt-in, manual baseline and
registration state. The helper serializes fork writers, reads KDE customDevices,
merges, writes and reads back. It permits two retries under one five-second
deadline. KDE exposes no compare-and-swap operation: an unrelated simultaneous
writer remains a limit. Existing external/manual baselines are preserved. Forget
removes metadata only; KDE removal has a separate explicit review step.

Automatic rediscovery requires opt-in and an open panel. It runs at 60 seconds,
coalesces NM/BTH route hints for two seconds and backs off failures for five
minutes. A read-only NM monitor exists only during opted-in open panels. Closing
or disabling removes delayed automatic work. A remote phone may own BTH while the
local desktop stays on native LAN; no local WireGuard interface is required.

## Syncthing owner UI

The fixed `omarchy-shell shell summon io.github.ilyazar.syncthing {}` call must
return `ok` before the UI reports it opened. A missing plugin, unknown response or
failed call remains unavailable. No API key, CoreProcess or raw owner object is
loaded.

Pause/resume runs only for the saved, validated Syncthing ID:
`timeout 4 syncthing cli config devices <ID> paused get|set true|false`. Syncthing's
CLI reads its own API key; Plus never reads its configuration. Each change is
followed by a `get` readback. A failed call or other output shows "unknown" and
disables the action. Folder operations stay with Syncthing/Syncshell.

## Native feature visibility and network owners

KDE native plugin discovery preserves bounded safe IDs instead of a quick-action
whitelist. `pluginIds` is supported metadata. Optional `loadedPluginIds` plus
`loadedKnown` report the daemon's runtime list. Neither means an enabled setting
or granted phone permission. Failed metadata reads remain unknown. Quick actions
must use the matching sender interface, not a receiver plugin with a similar name.
The selected-peer native route passes a validated device ID to
`kdeconnect-app --device`. An optional validated module ID adds `--plugin-config`
only after a two-second offscreen help probe confirms that option. Configuration
requires a paired selected device. Older frontends retain the ordinary device-list
route; direct configuration returns unavailable with a manual Plugin Settings next
step instead of claiming a module opened. Launch acceptance does not prove a
window rendered or settings were saved.

Network options delegate Tailscale to its existing Omarchy panel and generic
WireGuard profiles to the installed NetworkManager editor. Launch requests use
fixed arguments and bounded feedback. They do not install, connect, copy keys,
choose a profile or introduce a second policy writer. BTH mode control remains
on the reviewed helper contract above. No native-owner launch is a reachability
receipt.

## Settings window and typed preferences

### Native information, metadata and virtual monitor

Discovery preserves the original first 16 DEVICE fields. An optional trailing JSON
field carries up to 16 addresses and 16 provider names of at most 256 characters each,
plus native virtual-monitor known/active/available booleans. QML revalidates these
bounds. Legacy 16-field records remain valid. Unknown reads never mean false or
available. Virtual-monitor properties are read only for reported support, with a
two-second native-call timeout.
The serialized information field is at most 16,384 characters after JSON escaping.
Oversized information lists are omitted as needed; valid monitor state is retained.

Feature display names use the installed `PluginModel.pluginDisplayName` API in an
optional loader. The metadata model has no device target. Its Instantiator requests
only pluginId, name, description and configSource; it never requests isChecked or
reads/writes plugin check state. All installed rows form the module catalogue,
independent of the peer's reported feature list. Installed configuration sources
identify the rows with a native Configure link. Plus passes IDs
to the native app and does not load those configuration QML files itself. Missing
metadata falls back to the reported ID and the native settings route. Local Run
commands configuration controls what the peer can run on this computer; it does
not edit the peer's command definitions. Native actions still need a reviewed
dispatcher.

`native_settings.py` accepts complete JSON on stdin, at most 64 KiB. A read has
exact keys `{operation:"read", peerId, pluginIds}` with at most 256 unique safe
module IDs. A set has `{operation:"set", peerId, pluginId, enabled}` with a boolean
value. It validates the device D-Bus path and rechecks native pairing. Offline
paired devices are allowed. Fixed Device `isPluginEnabled` / `setPluginEnabled`
calls use NO_AUTO_START, 1.5-second call timeouts and a shared five-second deadline.
Reads use at most eight workers. No configuration file is read or written.

Replies contain exactly `state`, `peerId`, `enabled` and `error`. The enabled map
contains only observed boolean values. A set succeeds only after native readback;
a mismatch retains the actual value. An uncertain submission has state `unknown`
and no observed value. The UI does not retry it. A read-only Refresh can recover
state. QML revalidates the reply and bounds each output stream to 64 KiB.
`NativeModuleController` serializes requests, rejects duplicate writes and captures
the original peer for an initiated write. Selection changes invalidate stale
responses and queue only the latest visible target's read. Hidden pages do not
start requests. This state is separate from shared device-action feedback.

`edit_remote_commands.py` accepts only JSON stdin `{peerId}` of at most 512 bytes.
It validates the D-Bus path ID and rechecks paired/reachable and native
`canAddCommand` before the fixed `remotecommands.editCommands` call. Reads and
mutation use NO_AUTO_START, a 1.5 second call timeout and a 5 second total cancellation
deadline. It reports request acceptance only; a lost mutation reply stays
submission-unknown. It does not add, edit or execute command definitions. Plus
does not retry automatically or manage the remote editor.

`virtual_monitor.py` accepts one bounded 512-byte JSON line containing `peerId` and
`operation` (`start` or `stop`). It validates the D-Bus path ID, rechecks native
paired/reachable and monitor state, then uses only `requestVirtualMonitor` or
`stop` on `org.kde.kdeconnect.device.virtualmonitor`. Calls prohibit daemon
auto-start, have 1.5-second timeouts and a five-second overall cancellation limit.
Starting an already-active session is a no-op. Native KDE Connect owns KRDP,
credentials and remote permission. Unknown mutation replies stay unknown; there
is no automatic retry. Request acceptance is not remote display confirmation.

These APIs and Information fields were checked against
[KDE Connect 26.08.2's device page](https://github.com/KDE/kdeconnect-kde/blob/v26.08.2/app/qml/DevicePage.qml),
[metadata model](https://github.com/KDE/kdeconnect-kde/blob/v26.08.2/models/pluginmodel.cpp)
and [virtual-monitor interface](https://github.com/KDE/kdeconnect-kde/blob/v26.08.2/plugins/virtualmonitor/virtualmonitorplugin.h).

`SettingsPanel.qml` is an independent nonmodal native Window. Its four domains
share the current device context and retain a Back to devices route. Native KDE
configuration forms open in KDE Connect with the selected ID; peer pairing and
reachability conditions are explained. The searchable inventory is the installed
module catalogue, independent of peer-reported features. It is not a module download catalogue. Its On/Off rows
read and change native state only through the `native_settings.py` contract above.

The persistent Settings Device selector uses the existing `Panel.selectDevice`
path. It does not store another selected ID. Options include offline and unpaired
devices, and equal display names include stable IDs. Selection uses `valueRole`
and `currentValue`, so replacing or reordering discovery rows preserves identity.
A changed inventory closes the popup before it can submit a stale row. A changed
selected ID closes an old icon editor. Device switching keeps the current domain
and scroll position, with the existing panel draft/action resets.
Native launch progress, request acceptance and errors use the controller's
`nativeAppMessage` and `nativeAppFailed`; unrelated actions cannot appear as launch
feedback. Native launches never write shared device action state, so completion
cannot overwrite a running, failed or uncertain device submission.
`nativeAppOpening` exposes its existing process-running state to prevent
repeat requests. A late launch result for another selected ID is ignored.
Offline feature reports never claim a current loaded status.
The panel's device gears use `Panel.openDeviceSettings(id)`, which validates the
current inventory, selects through the same panel path, then opens Device features.
Neither the header gear nor paired-device gears launch KDE Connect implicitly.
The explicit Native KDE Connect settings link retains the native launch boundary.

The shared preference helper has a fixed fork ID, an allowlist of active boolean
keys, four bounded strings (`defaultPingMessage`, `bthHelperPath`, `quickActionsOrder`, `sectionOrder`) and a 32 KiB request limit. Each string has its own validator. `setBarWidget` receives fixed
arguments and JSON-typed values. `omarchy-shell` takes values only as process
arguments, so a saved string is briefly visible to local process listings. Exact `ok` confirms the native API accepted the
write and controls success feedback. The controls display host-provided settings;
the helper does not independently read back or verify persistence. A visibility
setting never changes a VPN. Hidden BTH does not poll.

## Drop selection and persistent Send window

`stageDroppedFiles(id, urls)` accepts at most 100 local URI strings with a bounded
aggregate payload, freezes the reviewed recipient before the existing inspector,
and refuses busy state or overwriting a review draft. Choose files uses the same
draft protection. Only the existing explicit submit action sends files. The native
DropArea accepts Copy, never Move. Directories, symlinks and remote/active URIs
remain rejected by the shared file inspector. A normal Send Window stays mapped
while the user focuses a file manager; closing it preserves service-owned draft
and activity. Physical external Wayland DND is a separate acceptance claim.

Ring remains discoverable when advertised. Known missing loaded metadata blocks
dispatch with a native Plugin Settings next step. Unknown loading state retains
older-version fallback. Successful CLI return means a ring request was accepted,
not that a person heard a phone.

## Optional section and action contract

Section visibility and start-expanded flags are typed boolean preferences. The
native helper allowlists their keys and requires the native API's `ok` reply.
The controls display host-provided settings. Expanding a
section is session UI state; opening the panel restores the selected defaults.
Hiding a section preserves provider configuration and local metadata. Collapsed
or hidden BTH controls do not poll their controller.

`PanelSections.json` is the fixed catalogue for the ten daily sections. It owns
their IDs, labels, help, visibility keys, expansion defaults and settings domain.
`PanelSectionCatalog.qml` reads this trusted local file. `SectionOrder.js` and
`scripts/section_order.py` validate the same catalogue and bounded `sectionOrder`
CSV. Unknown or repeated IDs are rejected on save. Missing known IDs append in
catalogue order; an empty value restores that order. Malformed stored values use
the default order. The catalogue contains no component paths or commands.
An unavailable catalogue or missing section entry keeps that optional section
hidden, so it cannot start owner-status polls. The device picker and fixed View
routes stay available; a load failure shows recovery text in the daily panel.

`Panel.qml` moves existing `QtQml.Models.ObjectModel` objects. It preserves draft
and control identity while changing visual and Tab order. Settings uses stable
rows and native Up/Down buttons. Saves wait for host readback; pending requests
keep focus and refuse repeats without a queue. Every section can move, including
hidden sections. The device switcher stays visible when its details collapse.
Pairing warnings, pending unpair confirmation and launch feedback remain reachable.

The inline Devices target reuses `FileDropZone.qml` and `SendSection.qml`; it has
no transfer engine. Accepted local-URL hover over the bar opens and reveals it,
then settles layout before scrolling it into view. Hover never stages or sends.
That temporary reveal does not save visibility. An actual drop locks the current
recipient through the existing inspector. Switching devices does not redirect a
review draft. An unsaved address/removal review clears when its device changes.
Moving, hiding or collapsing sections alone does not clear saved records or drafts.
Collapsed or hidden Syncthing controls do not begin new owner-status polls.

`ActionCatalog.js` owns the reviewed shortcut IDs, groups, help, supported and
locally-active readiness. The preference/migration boundary accepts only those
IDs, no duplicates, with a 512-character CSV limit. Native handoffs remain explicit
and keep the selected KDE peer. They do not directly invoke a guessed plugin
method. Explicit media/command navigation can reveal a hidden section for the
current view without changing its saved preference.

The bar and the Send card instantiate the same `FileDropArea.qml`. It locks the
selected recipient through `stageDroppedFiles`, refuses busy/existing drafts,
accepts Copy only, and emits a review-window signal after staging. It never sends.

Discovery keeps missing helper tools distinct from confirmed KDE absence.
The discovery helper returns `78` when `busctl` or `python3` is missing, before
any D-Bus call or parser run. The controller maps `78` to `unavailable`, marks
the session bus unverified and shows fixed dependency and recovery text. Exit
`127` is reserved for confirmed KDE absence. A failed or
malformed session-bus reply is unavailable. A valid stopped-daemon reply with
an installed KDE command or activatable KDE service is also unavailable. Only
confirmed absence of both command and activation evidence reports missing KDE
tools. A running daemon can be discovered without `kdeconnect-cli`.


Quick Share uses only the fixed `/usr/bin/rquickshare` app path. The launcher
rechecks the executable and detaches its standard streams. Success confirms
process creation, not an open window, pairing or delivery.
`quickShareOpening`, `quickShareMessage` and `quickShareFailed` own launcher
feedback. A launch never changes the selected device's action state, message or
error. Only duplicate Quick Share launches wait for its result; device actions
retain their existing readiness rules. The toolbar shows the launch result separately.

## Daily navigation

`CompactNavigation.qml` owns the fixed Devices, Send, Activity and Plus settings
routes. It accepts no command or provider IDs. `navigationAtTop`,
`showSendShortcut` and `showActivityShortcut` are typed boolean preferences with
false defaults. Native settings save and migration validate the same keys.
Placement changes only the fixed navigation row; content keeps a bounded scroll
region. Hidden direct shortcuts do not remove routes from the menu.

Navigation preserves service-owned file review and activity. A pending draft
remains visible outside Send. Submission activity uses words, with no delivery
claim. Menu Escape restores trigger focus without closing the daily panel.
Choosing Devices returns to its existing keyboard navigation.
