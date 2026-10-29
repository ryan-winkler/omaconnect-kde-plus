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
records and 256 KiB metadata. State is in XDG_CONFIG_HOME/ryan.omaconnect; copied
assets are in XDG_DATA_HOME/ryan.omaconnect/icons. Private directories/files use
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
The helper rechecks file identity, then launches exactly
`kdeconnect-cli -d <reviewed-id> --share <path>`. No shell interpolation occurs.
A process deadline is 15 seconds. The queue invokes one helper per file in order.
There is no automatic retry after an ambiguous timeout.

| State | Evidence |
| --- | --- |
| `queued` | Not yet submitted |
| `submitting` | CLI invocation has started |
| `request_accepted` | CLI exit 0; delivery unknown |
| `submission_failed` | Request could not be submitted / nonzero exit |
| `submission_unknown` | Deadline after invocation; check for duplicates |
| `cancelled_before_submit` | Queue item stopped before invocation |
| `cancellation_unconfirmed` | Stop requested after invocation; remote result unknown |

Operation summaries contain provider, reviewed ID/name, count/size, aggregate
counters and timestamps. They hold no raw paths and have a 50-operation memory
limit. The transient draft/queue does hold selected paths until use/cancellation.
The CLI path argument can appear in process metadata and the provider's later
open is outside the helper's source check. No atomic descriptor handoff is claimed.

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
loaded. Inline status and device actions remain deferred.

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
