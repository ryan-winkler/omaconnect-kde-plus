# Help with Omaconnect KDE Plus

Open **Plus settings** from the **View** menu or the settings icon beside it.
Choose the domain that matches your task.
Use **Back to devices** to return. Native KDE Connect opens in its own window;
your Plus settings remain available. Select a device before changing its features.
Settings switches show **On** or **Off** below their names.

## Daily popup

The **View: Devices** menu also opens **Send**, **Activity** and **Plus settings**.
Navigation stays at **Bottom** by default, so devices come first. In
**Plus settings → Appearance**, enable **Place navigation at Top** to move the
whole row. Add optional direct Send or Activity shortcuts there. Hiding a
shortcut keeps its route in the menu. The row stays visible while content scrolls.
When space is tight, enabled shortcuts move below View and settings.
To restore the default layout, turn all three options off.

A ready draft keeps its recipient and files when you change views. Outside Send,
a draft reminder names its recipient. Activity shows pending or uncertain
submission state even when its shortcut is hidden. Accepted requests do not
confirm delivery.

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
controls. It does not install, connect or disconnect a VPN. In this page, choose
whether network controls and saved addresses show or start expanded. Hiding a
section keeps its saved data.

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

Addresses must be private IP literals, not hostnames. Tailscale's `100.64.0.0/10`
range is accepted only with the Tailscale source, and the BTH source accepts IPv4 only.

## Keyboard

In the Devices view, use the arrow keys or `h` `j` `k` `l` to move, and `Enter`
or `Space` to activate. Press `r` to refresh, `p` to pair the selected device,
`u` to unpair it and `y` to confirm, `c` to cancel, and `Esc` to close. `Tab`
moves into the normal control order. The View menu supports Enter or Space to
open, Up or Down to choose, and Enter or Space to select. Escape closes the menu
and returns focus to its trigger. Choosing Devices returns to device navigation.

## Quick actions

Choose a shortcut, then select **Add selected action**. Use **Up**, **Down** or
**Remove** to change the toolbar. **Use default actions** restores Files, Text or
link, and Clipboard. These choices do not enable a native module or execute it.
Each action shows its description and selected-device availability.

- **Files:** Open the normal desktop file chooser, then review before Send.
- **Text or link:** Compose up to 8192 characters and send explicitly. Plus uses the native session bus; private content stays out of process command arguments.
- **Clipboard:** Send the current clipboard to the selected device.
- **Quick Share:** Open [RQuickShare](https://github.com/Martichou/rquickshare)
  to share with Android Quick Share. Install the `r-quick-share` package first.
  It is a separate app with its own pairing; KDE Connect does not use it.
- **Ring:** Request a sound. If unavailable, open native **Plugin settings** and
  check Find my phone. A successful command does not confirm an audible sound.
- **SMS:** Open native KDE Connect conversations, where the platform permits it.
- **Ping:** Compose a notification. The optional default message fills the draft;
  you can edit up to 8192 characters before sending. Private Ping content also uses the session bus. Ping and Ring use different native modules.
- **KDE Connect features:** Open the selected peer in native KDE Connect.

If the Quick Share window does not appear after launch, check its tray icon.
See [RQuickShare setup and limitations](https://github.com/Martichou/rquickshare#installation).

## Device features

Media player choices and transport buttons support Tab, Enter, Space and
assistive-technology activation. The current player starts with **Current:**,
so its state remains clear without color or hover. Unavailable controls do not
submit an action.

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

## Syncthing identity note

Enable **Show Syncthing identity notes** in **Settings → Appearance**. Select a
device, expand its note and compare the names and full identities in both owner
apps. Paste the full Syncthing ID and select **Save local identity note**. This
helps when a machine has different names in the two apps. Changing the selected
KDE device resets the draft; a pending save stays attached to its reviewed device.
Saved readback confirms a save or removal. **Remove local note** removes only this
association. Select the saved ID to copy it with the normal keyboard command.

When a note is saved, the section shows whether Syncthing has paused that device.
Select **Pause in Syncthing** or **Resume in Syncthing** to change it. Syncthing's
own `syncthing cli` makes the change and a readback confirms it. "State unknown"
means Plus could not confirm the state. Possible causes include a stopped
Syncthing, a different configuration folder, an unknown ID, a CLI timeout or an
unexpected reply. Select **Refresh Syncthing state** to retry. The last checked
state refreshes every 15 seconds while this section is visible.

The note does not pair devices, start sync or verify ownership.
**Open existing Syncthing panel** opens the general Syncshell panel, where you
configure folders and check synchronization. It is not a per-device deep link.
Syncshell retains the synchronization engine and keys. Read the official
[Syncthing device setup guide](https://docs.syncthing.net/intro/getting-started.html).

## Install, update or recover

Use the supported commands in [install, update and recovery](INSTALL.md),
including how to move settings from the original OmaConnect. If KDE Connect is
missing, Devices shows `omarchy pkg add kdeconnect python python-gobject`. Copy
it into a terminal, run it, then select **Refresh**. Plus never runs it for you. Native plugin
removal does not remove pairing, VPN profiles or private Plus metadata.

If discovery reports missing **busctl and Python 3**, check those system tools,
then select **Refresh**. This is a discovery dependency problem, not proof that
KDE Connect is missing. On Omarchy, `busctl` comes from systemd and `python3`
comes from Python. Plus does not install or change these packages.

## Get help or contribute

Use [support](../SUPPORT.md) for task help and safe issue evidence,
[contributing](../CONTRIBUTING.md) for small changes, or
[security reporting](../SECURITY.md) for private vulnerability reports.
Do not publish private IDs, addresses, configurations or credentials.


## Update KDE Connect itself

`omarchy plugin update Omaconnect.plus` updates this UI fork. KDE Connect's native
package follows the supported Omarchy system update route, `omarchy update`.
That can update other packages, so review its normal system update scope first.
Plus does not compile KDE's development branch or run a package update for you.

The [upstream watcher](UPSTREAM-WATCH.md) monitors provider changes separately.
