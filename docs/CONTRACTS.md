# Provider and storage contracts

All new helpers use fixed argv plus bounded JSON stdin/stdout. Raw provider stderr
is not shown in the UI. These are local process contracts; the fork adds no HTTP
server, arbitrary REST proxy, protocol daemon or cross-plugin service API.

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
fallback. The helper then launches exactly
`kdeconnect-cli -d <reviewed-id> --share <path>`. No shell interpolation occurs.
Preparation has a 120-second work deadline, cancellation checks between chunks,
a 64 MiB free-space reserve, and source identity checks after copying. Blocking
filesystem calls cannot be forcibly preempted by that deadline. Snapshots have
0700 directories and 0600 files below the XDG cache path documented in [Help](HELP.md).
They become eligible after 24 hours. Cleanup is attempted on later preparation
when the cache is safe and available. Protected-file preparation treats cache
housekeeping as best effort; shared-file snapshots still require a safe cache. Cleanup accepts only the exact owned flat snapshot
shape; it preserves unrelated or unexpected state. A process deadline is 15 seconds. The queue invokes one helper per file in order.
There is no automatic retry after an ambiguous timeout.

| State | Evidence |
| --- | --- |
| `queued` | Not yet submitted |
| `preparing` | Validating or snapshotting; this file has not reached KDE |
| `submitting` | CLI invocation has started |
| `request_accepted` | CLI exit 0; delivery unknown |
| `submission_failed` | Request could not be submitted / nonzero exit |
| `submission_unknown` | Deadline after invocation; check for duplicates |
| `cancelled_before_submit` | Queue item stopped before invocation |
| `cancellation_unconfirmed` | Stop requested after invocation; remote result unknown |

Operation summaries contain provider, reviewed ID/name, count/size, aggregate
counters and timestamps. They hold no raw paths and have a 50-operation memory
limit. The transient draft/queue does hold selected paths until use/cancellation.
The CLI path argument can appear in process metadata. Shared sources reach KDE
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
The selected-peer native route passes only a validated device ID to
`kdeconnect-app --device`; older settings frontends open the device list.

Network options delegate Tailscale to its existing Omarchy panel and generic
WireGuard profiles to the installed NetworkManager editor. Launch requests use
fixed arguments and bounded feedback. They do not install, connect, copy keys,
choose a profile or introduce a second policy writer. BTH mode control remains
on the reviewed helper contract above. No native-owner launch is a reachability
receipt. See the network coverage audit for exact first-release limits.

## Settings window and typed preferences

`SettingsPanel.qml` is an independent nonmodal native Window. Its four domains
share the current device context and retain a Back to devices route. Native KDE
module settings open in KDE Connect with the selected ID; peer pairing/reachability
conditions are explained. The searchable inventory is reported support, not an
installation catalog or enabled-state writer.

The shared preference helper has a fixed fork ID, an allowlist of active boolean
keys, three bounded strings (`defaultPingMessage`, `bthHelperPath`, `quickActionsOrder`) and a 32 KiB request limit. Each string has its own validator. `setBarWidget` receives fixed
arguments and JSON-typed values. Exact `ok` plus native config readback controls
feedback. A visibility setting never changes a VPN. Hidden BTH does not poll.

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
native helper allowlists their keys and requires saved readback. Expanding a
section is session UI state; opening the panel restores the selected defaults.
Hiding a section preserves provider configuration and local metadata. Collapsed
or hidden BTH controls do not poll their controller.

`ActionCatalog.js` owns the 18 reviewed shortcut IDs, groups, help, supported and
locally-active readiness. The preference/migration boundary accepts only those
IDs, no duplicates, with a 512-character CSV limit. Native handoffs remain explicit
and keep the selected KDE peer. They do not directly invoke a guessed plugin
method. Explicit media/command navigation can reveal a hidden section for the
current view without changing its saved preference.

The bar and the Send card instantiate the same `FileDropArea.qml`. It locks the
selected recipient through `stageDroppedFiles`, refuses busy/existing drafts,
accepts Copy only, and emits a review-window signal after staging. It never sends.
