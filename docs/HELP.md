# Help with Omaconnect KDE Plus

Open **Settings** from the bar menu. Choose the domain that matches your task.
Use **Back to devices** to return. Native KDE Connect opens in its own window;
your Plus settings remain available. Select a device before changing its features.

## Appearance

- **Bar icon:** Select **Change bar icon**. Choose a labelled preset, search the
  installed icon theme, or use a custom symbol or local PNG/SVG. Preview, then Apply.
- **Device icon and name:** Select a device, then **Change selected device icon and
  alias**. A local alias changes its display here. It does not change pairing.
- **Battery beside the icon:** Enable this to show a reported charge. Missing
  battery information stays unknown.
- **Contribute an icon:** Read the [icon source and storage guide](ICONS.md).
  It explains the renderer, presets, private assets and contribution checks.

## Connections

Enable only the integrations you use. Each display switch shows or hides its
controls. It does not install, connect or disconnect a VPN.

| Integration | Use it | Official setup guide |
| --- | --- | --- |
| Tailscale | Open the existing Tailscale panel. Connect in its owner app. Approve the peer’s Tailscale IP under **Manage saved addresses**. | [Tailscale quickstart](https://tailscale.com/docs/how-to/quickstart) |
| MikroTik Back to Home | Use the existing reviewed helper. **Automatic** uses its policy; **On** requests activation; **Off** requests that it stay stopped. Read actual connection state separately. | [MikroTik Back to Home](https://manual.mikrotik.com/docs/network-management/cloud/back-to-home/) |
| Other WireGuard profiles | Open the existing NetworkManager profiles. The manager owns profiles and keys. Approve the peer’s private VPN IP for rediscovery. | [WireGuard quickstart](https://www.wireguard.com/quickstart/) |

**BTH helper path** is optional. Empty uses `~/.local/bin/remote-access-mode`.
Use an absolute path to your existing reviewed controller. Plus does not create
that controller or import keys. A missing provider shows an unavailable result.
See [provider contracts](CONTRACTS.md) before connecting a different controller.

**Saved addresses:** Select a device. Open **Manage saved addresses**. Enter one IP,
choose its source and approve it. An address is a route hint; the KDE identity
still owns trust. Automatic rediscovery requires both the address opt-in and the
panel-session switch. It runs while the panel is open, with a 60-second interval.
**Forget local address record** removes Plus metadata. **Review removal from KDE**
needs a second selection and preserves pre-existing native addresses.

## Quick actions

Choose a shortcut, then select **Add selected action**. Use **Up**, **Down** or
**Remove** to change the toolbar. **Use default actions** restores Files, Text or
link, and Clipboard. These choices do not enable a native module or execute it.
Each action shows its description and selected-device availability.

- **Files:** Open the normal desktop file chooser, then review before Send.
- **Text or link:** Compose up to 8192 characters and send explicitly. Plus uses the native session bus; private content stays out of process command arguments.
- **Clipboard:** Send the current clipboard to the selected device.
- **Ring:** Request a sound. If unavailable, open native **Plugin settings** and
  check Find my phone. A successful command does not confirm an audible sound.
- **SMS:** Open native KDE Connect conversations, where the platform permits it.
- **Ping:** Compose a notification. The optional default message fills the draft;
  you can edit up to 8192 characters before sending. Private Ping content also uses the session bus. Ping and Ring use different native modules.
- **KDE Connect features:** Open the selected peer in native KDE Connect.

## Device features

Open **All KDE Connect features**, then use native **Plugin settings** to enable
or configure installed modules and permissions. Search in Plus by task or plugin
ID to find reported features, including unfamiliar third-party IDs. Supported
means compatible; Loaded describes the local daemon. Neither confirms permission.
The native page manages installed modules; it is not a plugin download store.
Read the [KDE Connect user guide](https://kdeconnect.kde.org/users.html).

- **Battery details:** Show charge and charging state when reported.
- **Cellular connection details:** Show reported cellular type and signal; this
  does not describe Wi-Fi or VPN reachability.
- **Media controls:** Expand Media in Devices. Choose a reported player and use
  previous, play/pause or next. Playback stays in the owner app. Track text and
  controls remain available; provider-supplied album-art URLs are not displayed or fetched.
- **Remote commands:** Expand Remote commands in Devices. Commands run on the
  selected device. Add or edit them in that device’s KDE Connect Run commands settings.

## Send files and read activity

1. Select a paired, reachable device. Open **Send**.
2. Select **Choose files** for the graphical desktop chooser. For file-manager
   drag and drop, select **Open Send window** so the target stays open.
3. Choose or drop up to 100 local regular files, at most 1 TiB combined.
   Directories and remote URLs are not accepted. Drops use Copy and preserve originals.
4. Check the recipient, files, count and size. Select **Send files**. A changed
   device selection does not redirect a reviewed batch.
5. Read Activity. **Request accepted** confirms command acceptance. Check the
   recipient for actual receipt. **Stop submitting** can stop remaining requests;
   it does not confirm cancellation of work already accepted by KDE Connect.

**Cancel selection** discards the draft. Closing the Send window preserves it.
Activity keeps at most 50 summaries for this session and excludes raw paths.
Files that another local user can change need a private snapshot before submission.
Plus tries a filesystem clone, then a bounded copy. This can need free disk space.
The preparation deadline is 120 seconds, checked between copy chunks. A blocked
filesystem call can take longer. Copies live in
`$XDG_CACHE_HOME/Omaconnect.plus/share-snapshots/` (default:
`~/.cache/Omaconnect.plus/share-snapshots/`), with owner-only directories and files.
They become eligible after 24 hours. Cleanup is attempted on later preparation
when the cache is safe and available; there is no guaranteed maximum retention time. Plus preserves unexpected files.
Private canonical sources normally use their existing path. KDE owns its later
file open; programs running as your user and root remain trusted.
Text, Ping, Clipboard and remote-command success messages also report request acceptance. Check the recipient or remote result for delivery or execution.
Read [current verification and limits](VERIFICATION.md) for tested device scope.

## Syncthing identity note

Enable **Show Syncthing identity notes** in **Settings → Appearance**. Select a
device, expand its note and compare the names and full identities in both owner
apps. Paste the full Syncthing ID and select **Save local identity note**. This
helps when a machine has different names in the two apps. Changing the selected
KDE device resets the draft; a pending save stays attached to its reviewed device.
Saved readback confirms a save or removal. **Remove local note** removes only this
association. Select the saved ID to copy it with the normal keyboard command.

The note does not pair devices, start sync, check live state or verify ownership.
**Open existing Syncthing panel** opens the general Syncshell panel, where you
configure folders and check synchronization. It is not a per-device deep link.
Syncshell retains the synchronization engine and keys. Read the official
[Syncthing device setup guide](https://docs.syncthing.net/intro/getting-started.html).

## Install, update or recover

Use the supported commands in [Install and open](../README.md#install-and-open)
and [Update, disable and remove](../README.md#update-disable-and-remove).
Read [migration and recovery](MIGRATION.md) before moving settings. Native plugin
removal does not remove pairing, VPN profiles or private Plus metadata.

## Get help or contribute

Use [support](../SUPPORT.md) for task help and safe issue evidence,
[contributing](../CONTRIBUTING.md) for small changes, or
[security reporting](../SECURITY.md) for private vulnerability reports.
Do not publish private IDs, addresses, configurations or credentials.

---

# Contextual help coverage

Each feature has short task guidance beside its controls, a direct documentation
link, or both. External links open only when the user selects them. Help stays in
the owning domain; there is no extra daily help dashboard to search first.

| Feature | In-app help and documentation |
| --- | --- |
| Bar/device icons and local aliases | Appearance explains identity versus display; chooser explains preview/Apply, advanced choices and validation. Appearance opens the installed ICONS.md contribution guide. |
| Quick actions | Add/Up/Down/Remove instructions; each catalog item has a description and selected-device availability. Adding a shortcut does not enable or execute a native plugin. |
| Native features and permissions | Search scope/state legend, offline next step, selected-device native route, and official KDE user guide. |
| Tailscale | Independent display switch, existing-owner/address instructions and official quickstart. |
| MikroTik BTH | Independent display switch, Automatic/On/Off intent-versus-state help, trusted helper-path help and official BTH manual. |
| Other WireGuard profiles | Independent display switch, native manager/address instructions and official quickstart. |
| File chooser and drop | Choose files or persistent Send window; local-file/count/size limits; review before explicit Send; Copy protects originals; existing draft/busy reasons remain visible. |
| File activity and cancellation | Accepted-versus-delivered explanation, session-only retention and unconfirmed cancellation state. |
| Saved addresses | Source labels, explicit approval, identity warning, opt-in rediscovery and separate removal review. Provider setup documentation is in Connections. |
| Syncthing identity link | Full identity check, explicit local-only association explanation, existing owner button and official device setup guide. |
| Ring unavailable | Known-unloaded module message and native Plugin Settings next step; command acceptance does not claim sound. |

The official links were checked against provider documentation. Do not put API
keys, addresses, private IDs or configuration contents into help URLs. Do not
add a shell command or arbitrary URL field as a shortcut for documented features.

A future native action needs a verified dispatch contract and catalog entry before
it is offered as an executable shortcut. Safe unknown native modules remain
searchable through the native owner route without inventing invocation semantics.

## Choose visible sections and shortcuts

In **Settings → Appearance**, choose saved addresses, optional Syncthing identity
notes and network controls. Choose which sections start expanded. Media and remote
command visibility lives in **Device features**. Each visible section can also
collapse in Devices. These display choices preserve saved metadata and provider
settings. They do not disconnect a VPN or change native plugin permissions.

In **Quick actions**, add, remove and reorder the reviewed shortcuts. Media
transport needs a reported player. Locally inactive modules show a reason. Native
navigation shortcuts open KDE Connect for browsing, notifications, volume,
input/presentation or locking; choose the action there. The complete native
inventory remains searchable, including unknown future plugin IDs. Plus does not
guess a command from a plugin name or install arbitrary plugin code.

You can also drop local files onto the Plus bar icon. The same Copy-only boundary
opens the persistent Send window for the selected device. Check the recipient and
files; nothing is sent until **Send files**. Busy or existing drafts refuse a new
drop so that the target cannot silently change.

## Update KDE Connect itself

`omarchy plugin update Omaconnect.plus` updates this UI fork. KDE Connect's native
package follows the supported Omarchy system update route, `omarchy update`.
That can update other packages, so review its normal system update scope first.
Plus does not compile KDE's development branch or run a package update for you.

On 29 October 2026, both comparison hosts had KDE Connect `26.08.2-1`. Fresh
`checkupdates` runs used temporary repository databases and found no KDE Connect
update on either architecture. No packages were installed or upgraded in that
check. The [upstream watcher](UPSTREAM-WATCH.md) monitors provider changes separately.
