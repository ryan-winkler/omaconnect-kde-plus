# Provider and storage contracts

Provider helpers use fixed argv plus bounded JSON stdin/stdout. The original-style
native file menu passes bounded local candidate paths through the platform menu
arguments; they can be visible to same-user process inspection. File submission
paths use D-Bus instead of argv. Raw provider stderr
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

An icon object accepts only `mode`, `value`, `render`, `font` and `tint`.
`mode` is required. `render` defaults to `symbolic`. Automatic/inherit omit
`value`; inherit is device-only. Other modes require a trimmed nonempty value
of at most 128 characters. Presets use the IDs in `Appearance.js`; theme names
match `[A-Za-z0-9][A-Za-z0-9_.-]{0,127}`; glyphs have at most eight characters;
images use the imported hash filename validated by `appearance.py:ASSET`.
An optional glyph font is trimmed and bounded to 128 characters. `font` on other
modes is ignored. Alias input is trimmed before its 80-character limit. Text
control validation uses `appearance.py:BAD_TEXT`. Appearance records reject
unknown top-level and device-record fields. Optional retained `addresses` are
local metadata, at most 64 entries, and do not change native registration.

## File chooser and submission

The UI's boolean settings are `useDesktopFileChooser=false` and
`reviewFilesBeforeSend=false`. Explicit chooser selection therefore sends by
default. Present non-boolean settings fall back to desktop review. UI callers
pass `{useDesktopFileChooser, reviewFilesBeforeSend}` through the existing
Service/controller API; omitted or mistyped options retain desktop review for
compatibility. Options and recipient are captured at chooser launch. Only that
generation can submit its result. Drops always use review regardless of settings.

`portal_files.py recent` accepts one JSON line `{recipient:string}` of at most
2048 bytes. `recent_files.py` adapts the original parent menu's roots, extensions,
depth and ordering. It resolves each conventional starting folder to its existing
canonical root, so a Downloads/Documents/Pictures/Videos/Desktop alias to moved
storage remains usable. Duplicate canonical roots are scanned once; broken or
looping aliases are skipped. Descendant symlinks and hidden items remain excluded.
Offered paths use the resolved root, so changing its alias while the menu is open
does not redirect a selection. Normal file inspection and private-source trust
checks still apply. It scans at most 20,000 entries with a cooperative two-second
work deadline. Cancellation and both budgets are checked before resolving each
root and between scan operations. A blocking filesystem call cannot be preempted
by these checks and can exceed the deadline. Escaped options are bounded to
64 KiB, including each file-type glyph/TAB prefix and the optional preview row.
The native menu displays the glyph and returns only the original canonical path.
Files with controls or
line separators use the desktop chooser instead. The menu uses a fixed executable and fixed option flags with bounded candidate
path arguments and a sanitized recipient label. Paths can appear in process
inspection, including inside the native wrapper. It has a 120-second deadline
and at most 4097 output bytes.
Only an exact offered path is accepted. Cancellation/timeout terminates and reaps
the wrapper process group. The native menu is owned by the persistent shell;
there is no scoped request-close API. It can remain visible after wrapper exit,
so Cancel guidance tells the user to press Escape. Cancelled generations cannot
submit a later selection. Wrapper result files use an owned private temporary
directory which is removed after exit, so a stale native menu cannot recreate
its deleted result paths. No unscoped global hide is used. The menu does not submit; it returns inspected metadata.

When displayed candidates include JPEG, PNG, WebP or GIF files, **Image previews…**
returns an internal `{state:"preview",files:[...]}` handoff instead of a selected
file. Each record holds an exact displayed canonical raster path and the existing
inspection identity. The helper captures these identities before display without
reading image content. It uses the open file descriptor to check the canonical
path and excludes paths that other local accounts can replace or edit. The
desktop chooser remains available for files in shared locations. The helper
checks the scan and menu deadlines between files. The
records fit within 48 KiB of conservative ASCII-escaped JSON and at most 200
entries. Distinct paths with the same basename remain available. SVG, video and
optional image codecs stay in the ordinary list. The helper opens no image
overlay and creates no preview result files or cache.

`FileTransferController` validates the handoff before display: nonempty bounded
array, unique absolute raster paths, no control/bidi separators or dot segments,
4096 UTF-8 bytes per path and the same 48 KiB serialized budget. Only the native
recent-menu generation can enter preview. `ImagePreviewWindow.qml` uses existing
Qt image decoding with requested source dimensions capped at 1600 × 1200 pixels
and one current preview. Loading is asynchronous and caching is disabled.
Confirmation stays disabled until the image is ready and its resolved source
matches the selected path. Loading and unavailable-image states keep Back and
Cancel available. The window shows the captured recipient, filename, Back,
Cancel and an explicit Send image or Review image action. Search and Previous/Next only change the displayed image;
they never submit. No image-picker global summon/hide or result-file IPC remains.

Back relaunches the original file chooser for the frozen recipient and policy,
with a new selection generation. Navigation does not require the recipient to
stay connected; confirmation and submission still check it. Back does not adopt
current settings or device navigation. Cancel, Escape and window close clear the preview and draft; scoped
preview cancellation closes only that window. Confirm accepts only an exact
candidate, rechecks the original peer, then sends its captured identity to the
existing file inspector as `{preview: file}`. The inspector rechecks the
protected canonical path and rejects changed identity fields or unavailable
paths. Only a match for the current
generation can enter the normal immediate/review flow. The Send
window shows inspection/submission or the review draft; Review still needs a
separate explicit Send. Metadata identity and private-source checks are unchanged.

The Panel that starts a chooser records the service's selection generation.
Only a matching generation activates its preview window; other preview windows
do not show, decode or act on that selection. The existing global Cancel pending
files action still stops shared pending work from any Panel or daily view.
Send-window chooser starts record the
same owner, and Back renews it after a successful restart. Destroying an owner
releases only its unfinished choosing/preview generation. Review drafts,
explicit confirmation, provider work and other generations remain with the
controller. Standalone preview hosts can use the window's default owner mode.

`scripts/pick_file.sh` runs `portal_files.py choose`. A normal FileChooser portal
response is inspected before a draft reaches QML. Only local file URIs, readable
regular files and at most 100 files/1 TiB are allowed. Final symlinks, folders,
FIFO/devices and changed source identity are rejected. Parent-path links are
resolved by the normal filesystem; they are not treated as trust credentials.

Picker and inspector replies are `{state:"selected", files:[...]}`, or
`{state:"cancelled",files:[]}`, or `{state:"failed",error:<fixed code>}`.
Each inspected file contains `path` (absolute string), `name` (basename string),
`size` (nonnegative number), and decimal strings `device`, `inode`, `mtimeNs`,
`ctimeNs`. Submit accepts `{peerId:string,file:<inspected object>}`. It rechecks
the size and all four identity fields; `name` is display metadata. Extra inspected
object fields are ignored. Inspection uses at most 512 KiB input; QML also bounds
the selection to 100 files/1 TiB. Errors are fixed values from
`portal_files.py:main` and `recent_files.py`; raw diagnostics are never reflected.
For a failed submission with the `source-changed` error, Activity prompts the
user to choose the file again and shows the submission counts and delivery status.

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
housekeeping as best effort except cancellation and the shared preparation deadline;
shared-file snapshots still require a safe cache. Cleanup accepts only the exact owned flat snapshot
shape; it preserves unrelated or unexpected state. The D-Bus call deadline is
15 seconds, after preparation; it is not an end-to-end process deadline. The
queue invokes one helper per file in order.
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

### Native transfer cancellation

`cancelOperation()` stops queued files and sends SIGTERM to the active submission
helper. Picker/inspector cancellation also retains `selectionCancelling` until
exit. After two seconds without exit, the owning controller timer sends SIGKILL. A final
pre-invocation acknowledgement is required for confirmed cancellation; other
interrupted outcomes remain unconfirmed. A persistent daily navigation button
stays reachable while choosing or submitting, independent of view and collapse.
It disables repeats and shows Cancelling while stopping. The Send window shares
the same actions. Status remains in Activity; native-cancellation guidance remains in the Send
activity block after submission finishes.

The native [`shareUrls` API](https://github.com/KDE/kdeconnect-kde/blob/v26.08.2/plugins/share/shareplugin.h)
returns void and exposes no job ID or cancellation method. Native LAN uploads use
a killable [`CompositeUploadJob`](https://github.com/KDE/kdeconnect-kde/blob/v26.08.2/core/backends/lan/compositeuploadjob.cpp).
Users can select Cancel in native progress UI when available. A composite can
include multiple submissions to the same device; Plus must not guess its identity
from filenames or timing. The native
[Bluetooth upload object](https://github.com/KDE/kdeconnect-kde/blob/v26.08.2/core/backends/bluetooth/bluetoothuploadjob.h)
exposes no equivalent stop method. Direct cancellation of a specific accepted
transfer remains unavailable in Plus. Stopping the helper cannot recall files.

## Native task notices

`FileTransferController.operationFinished(operation)` emits once after a started
operation publishes its final snapshot, clears busy flags and clears its transient
queue. The existing KDE controller forwards that event to the service's
`TaskNotificationController`. Intermediate/per-file updates do not notify. Notice
failure never changes transfer evidence or retries a notification or file request.

`taskNotificationsEnabled` is a typed saved boolean, default true.
`taskNotificationDeviceName` is a separate typed saved boolean, default false.
The bar host supplies these values; absent or malformed values restore these
defaults. A missing fake service property is not written. The existing Quick
actions/sharing preferences expose both settings. They do not alter KDE Connect
phone-forwarding permissions, native notification actions or module state.

New notices are suppressed while the Plus popup, persistent Send window or
image preview is visible. A service-owned list records those visible instances;
closing or destroying one removes only its own entry. Notices remain suppressed
until every instance closes, including instances on different monitors. Service
changes unregister the old owner. Existing `panelOpened` discovery behavior stays
separate. Opening any of these surfaces, disabling notices or changing the device-name
opt-in discards waiting notices. There is no deferred replay. A policy generation is captured before process launch and rechecked before stdin is written; opt-out or a transient surface open/close discards an unwritten payload without reporting sender failure. Already submitted native notices cannot be recalled. One helper can run
at a time; only the latest three pending outcomes are retained. Activity retains
its existing 50-operation limit independently of desktop history.

`task_notification.py` accepts at most 8192 stdin bytes and exact fields
`summary` (nonempty, at most 256 characters), `body` (nonempty, at most 1024),
`includeDeviceName` (boolean) and `deviceName` (at most 256). All strings must be
valid UTF-8 without NUL. False opt-in requires an empty name; QML sends at most
128 Unicode code points without splitting a surrogate pair. The helper strips control/bidi formatting from an opted-in
name and substitutes visible angle/ampersand/colon characters so native entity
decoding cannot revive markup or clickable URLs. Names never enter argv, logs
or helper output. No IDs, paths, filenames, user messages or provider errors are
sent. Host notification history can retain the optional name after opt-out.

Gio calls `org.freedesktop.Notifications.Notify` with app name
`Omaconnect KDE Plus`, normal urgency, no transient hint and no service autostart.
The fixed `omarchy-exec-argv` hint is a JSON string encoding the argv array
`["/usr/bin/omarchy-shell", "omaconnect.plus", "activity"]`. The `omarchy-actions`
hint is a JSON string encoding an array with one action object: `label` is
`"Activity"` and `argv` is that same argv array. This current Activity action
remains valid when replayed from history; it does not retain a
task ID, recipient or retry command. The host owns cards, actions, DND and history.
The helper's Gio call has a 3500 ms deadline; the process has a five-second total
deadline and one-second kill grace. Each output stream has a 2 KiB cap. Failures
expose only a coarse message in Plus Activity. New notice/settings strings use
the plugin-owned `i18n/en.json` catalogue and native English fallback; other
Plus UI strings remain outside this translation increment.

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

Request changes accept `op` values `add`, `remove` or `auto`, plus required
`peer_id` and `address`. `source` defaults to `manual`. `add` and `auto` require
`approved:true`; `auto_discover` defaults to false and must be a boolean.
`remove_from_kde` defaults to false; true also requires approval. Remove without
that flag removes local metadata only. Unknown change fields are ignored;
unknown top-level request fields are rejected. An auto change needs an existing
record. Metadata rows contain exactly `peer_id`, `address`, `source`,
`auto_discover` and `manual_baseline`. Success replies contain
`{schema_version:1,ok:true,error:"",custom_addresses:[...],addresses:[...]}`;
each returned record adds `registered:boolean`. Failure replies contain only
`{schema_version:1,ok:false,error:<fixed code>}`. Fixed error codes are defined
by `AddressError` sites in `scripts/manage_addresses.py`; no raw provider text
is returned. Existing native addresses remain the baseline.

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

Discovery and media helpers give each busctl call a deadline of 5 seconds or
less and read at most 64 KiB of each reply; a larger reply is refused. The panel
runs a scan, a command list read and a media status read under coreutils
`timeout` (30, 10 and 10 seconds). It signals the provider's process group, then
sends SIGKILL 2 seconds later, also to a descendant that outlives the provider. The panel applies output only after exit 0, so a
stopped or failed read shows the usual unavailable or empty state. The existing
signal monitor watches the KDE Connect bus name. A change invalidates the old
device and address snapshot, keeps the selected ID, and schedules one debounced
read-only scan. Late replies from the old owner cannot restore controls or
complete a pending action. Interrupted requests report uncertainty and are
never replayed. The command
list read stops one byte over 64 KiB and is then refused. The list keeps at most
100 entries. It drops a command key over 256 characters and cuts a longer label.

Network options delegate Tailscale to its existing Omarchy panel and generic
WireGuard profiles to the installed NetworkManager editor. Launch requests use
fixed arguments and bounded feedback. They do not install, connect, copy keys,
choose a profile or introduce a second policy writer. BTH mode control remains
on the reviewed helper contract above. No native-owner launch is a reachability
receipt.

## Settings window and typed preferences

### Native information, metadata and virtual monitor

Discovery preserves the original first 16 DEVICE fields. The current producer
always emits a trailing JSON field. It carries up to 16 addresses and 16 provider
names of at most 256 characters each, plus native virtual-monitor
known/active/available booleans. It also carries `pairingKnown`,
`reachabilityKnown`, and `requestKnown`. A flag is true only when KDE Connect
returned a boolean for the corresponding property. `requestKnown` requires both
incoming and outgoing request flags. QML revalidates these bounds and accepts
legacy 16-field records. A missing native property does not establish a false
value. Virtual-monitor properties are read only for reported support, with a
five-second native-call timeout shared by discovery properties.
The serialized information field is at most 16,384 characters after JSON escaping.
Oversized information lists are omitted as needed; valid monitor state is retained.

The helper resolves the KDE Connect daemon to its unique D-Bus connection
before enumeration. All enumeration and property reads address that connection.
After the reads, the helper checks the owner again and emits
`DEVICE_OWNER<TAB><unique-name>` only if the owner still matches. The name is at
most 64 characters and uses the form `:1.42` with two decimal components.
An owner change or owner lookup failure exits nonzero. Consumers must discard
all records from a failed scan, including any rows written before the final
owner check.

After a successful enumeration the helper ends its output with
`DEVICE_SCAN<TAB><enumerated><TAB><readable>`. Counts are nonnegative decimal
integers. The first count is the number of distinct device IDs and the second is
the number of DEVICE records emitted. IDs use 1–128 ASCII characters from the
letters, digits, underscore, dot, and hyphen, and start with a letter, digit, or
underscore. A canonical device object path and its bare ID count once. A failed
device-object read or format produces no DEVICE row and makes the scan partial.
Optional plugin reads do not affect these counts. An empty enumeration emits
`0<TAB>0`. An unavailable or malformed top-level enumeration exits nonzero and
emits no scan summary. Legacy helper output without this summary remains valid.

Unpair requires a current snapshot with an explicit paired flag and a reviewed
peer ID. The Unpair helper rechecks the paired flag on the reviewed unique
connection and verifies that connection still owns the KDE Connect service
name. It addresses the write to the same unique connection with auto-start
disabled. A later scan must report the same owner and explicit unpaired state
before Plus confirms removal. A missing peer or failed readback leaves the
outcome unknown. KDE Connect owns the trust record.

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

The manifest's `settings` map is the source of preference names, types and
defaults. Settings and network-owner helpers return a stable result code with
their existing success flag and bounded English fallback. The panel uses the
code for live translation. `scripts/network_preferences.py:KEYS` and `STRING_KEYS` define the
writable subset; retired/legacy display keys are not all writable. A boolean
request has exactly `{key,enabled:boolean}`. A string request has exactly
`{key,value:string}`. Extra request fields are rejected. Strings have at most
4096 characters: Ping permits newline/tab but no other C0 controls; the BTH path
is empty or absolute, ends in `/remote-access-mode`, has no `..` component and
no C0/DEL controls. Quick-action CSV is at most 512 characters, has known IDs
and no duplicates. Section-order validation uses `section_order.py` and the
catalogue below. Replies are `{ok:boolean,code:string,message:string}` with fixed feedback.

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
draft protection. Dropped files require the explicit Send action. Chooser
selections follow the captured review setting. The native
DropArea accepts Copy, never Move. Directories, symlinks and remote/active URIs
remain rejected by the shared file inspector. A normal Send Window stays mapped
while the user focuses a file manager; closing it preserves service-owned draft
and activity. Physical external Wayland DND is a separate acceptance claim.

Ring remains discoverable when advertised. Known missing loaded metadata blocks
dispatch with a native Plugin Settings next step. Unknown loading state retains
older-version fallback. Successful CLI return means a ring request was accepted,
not that a person heard a phone.

## Native phone-file handoff

`PhoneFilesController.qml` owns one captured peer, generation and bounded helper
process. `browse_phone_files.py` accepts one JSON stdin line, at most 16 KiB:
`{peerId, operation:"prepare"}` or `{peerId, operation:"open", location}`. IDs are
1–128 ASCII letters, digits or underscores. Exact request fields are required.
No peer, path or folder name enters argv. Output is one bounded JSON result.

Prepare uses the unique owner of `org.kde.kdeconnect`, with NO_AUTO_START, to
check pairing, reachability, loaded SFTP and native `mountAndWait`, `isMounted`,
`mountPoint` and `getDirectories`. The advertised absolute directory keys are the
only candidates. No Android path, mount location or file-manager executable is
invented. At most 16 shares are accepted. Canonical roots must exist inside the
native mount, on its filesystem, with a matching `fuse.sshfs` mountinfo entry.
Symlinks and escapes are rejected. KDE Connect owns mounting. If it reports
success and then reports `isMounted` as false, Prepare rechecks peer and owner
before returning `mount-not-ready`. If KDE Connect reports a mount before the
kernel lists it, Prepare waits up to 500 ms for the record, observes
cancellation, and rechecks owner, peer and all locations. Prepare issues one
mount request. Open continues to reject any missing record.

Each prepared location carries `peerId`, `providerOwner`, `path`, `name`,
`mountPath`, `mountIdentity`, `rootIdentity` and `advertisements`. Open accepts the
unchanged selected item and rechecks owner, peer, capability, advertised roots
and mount/root identity before `Gio.AppInfo.launch_default_for_uri`. After the
final filesystem probe, it reads peer state again and verifies that the captured
unique connection still owns the well-known KDE Connect service name. A lost or
replaced owner cannot authorize the handoff through its old connection. One root
opens automatically; multiple roots require explicit selection. `opened` means
launch requested, not visible-window acceptance. No file content is read here.

Calls share a 27-second helper deadline. Ordinary D-Bus calls have a five-second
maximum; native mount has twenty seconds. The QML process has a thirty-second
outer timeout and one-second kill grace. Output is capped at 16 KiB; errors are
fixed public codes, not raw diagnostics. Peer changes, popup closure and
cancellation advance the generation and discard stale results. A desktop launch
already in progress cannot be recalled. Mount validation and launch are separate
operations; no atomic handoff is claimed. Send drafts and transfer operations
have separate owners. Native tests use private fake providers and no real mount.

## Optional section and action contract

Legacy section visibility and start-expanded flags remain typed boolean preferences. The
native helper allowlists their keys and requires the native API's `ok` reply.
The controls display host-provided settings. Expanding a
section is session UI state; opening the panel restores the selected defaults.
Hiding a section preserves provider configuration and local metadata. Collapsed
or hidden BTH controls do not poll their controller.

`PanelSections.json` is the fixed catalogue for the daily sections. It owns
their IDs, legacy visibility keys, default policies, expansion defaults and settings domain. Visible titles and help use the matching section IDs in the native string catalogue.
`PanelSectionCatalog.qml` reads this trusted local file. `SectionOrder.js` and
`scripts/section_order.py` validate the same catalogue and bounded `sectionOrder`
CSV. The retired `information` ID is discarded for compatibility. Unknown or repeated active IDs are rejected on save. Missing known IDs append in
catalogue order; an empty value restores that order. Malformed stored values use
the default order. The catalogue contains no component paths or commands.
An unavailable catalogue or missing section entry keeps that optional section
hidden, so it cannot start owner-status polls. The device picker and fixed View
routes stay available; a load failure shows recovery text in the daily panel.

`Panel.qml` moves existing `QtQml.Models.ObjectModel` objects. It preserves draft
and control identity while changing visual and Tab order. Devices has one inline
Edit layout mode with native visibility and position menus; the former Appearance
ordering list is replaced by a route to this editor. Every frame stays present
while editing, including hidden and unavailable sections. Optional bodies are
concealed without destroying them; display-driven BTH and Syncthing polling stops.
The device selector stays visible. Domain settings retain expansion defaults.

`sectionVisibility` is a JSON object string capped at 2048 characters. Optional
catalogue IDs map to `show`, `hide`, `available` or `unavailable`. Arrays, duplicate
keys, unknown IDs/policies and a policy for mandatory `devices` are rejected by
independent JavaScript and Python boundaries. Missing entries retain legacy
boolean behavior; explicit entries override it. No eager migration rewrites flags.
Unknown/checking readiness matches neither conditional policy. Availability uses
reported capability/readiness or configured tool display options, never inferred
transfer delivery, command count, playback or VPN state. Explicit Show on an
unavailable section exposes a reason rather than active provider controls.

Saves wait for matching host readback; pending requests keep focus and refuse
repeats without a queue. A layout-specific key/value guard spans helper execution
and readback so a second full-map edit cannot overwrite an unobserved save.
`PreferenceControls.lastSaveOk` reflects the validated helper `ok` field and
exit status. Feedback wording does not control the pending-save guard.
Missing readback reports recovery text instead of silently accepting another edit. Feedback retains its originating section after the pending lock clears, so failed-save messages remain visible beside lower sections. Status changes use native polite accessibility announcements. Editor keyboard guards prevent hidden daily action dispatch; locked controls let Tab, Backtab and Escape pass. Every section can move, including
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
