# Help with Omaconnect KDE Plus

Open **Plus settings** from the **View** menu or the settings icon beside it.
Choose the domain that matches your task.
Use **Back to devices** to return. Native KDE Connect opens in its own window;
your Plus settings remain available. Select a device before changing its features.
Settings switches show **On** or **Off** below their names.
Tab and Shift+Tab move between controls and scroll the focused control into view.
Settings buttons and switches also support assistive-technology activation.
Disabled controls do not submit a request. A switch follows the saved value;
requesting a save does not change its displayed state before readback.

Use the **Device** dropdown below the Settings title to change devices without
leaving the page. It also changes the selected device in Devices and clears the
old device's unsent text draft. Connected, offline and unpaired devices stay in
the list. Devices with the same local name also show their IDs. Offline devices
can still have a local icon or alias. Pairing and native permissions stay in KDE
Connect. Display preferences apply to Plus on this computer.

Tab to **Device**, then press Space or Enter to open the list. Use the arrow keys
and Enter to choose. Escape closes the list first; another Escape closes Settings.
If discovery changes the list, open it again to choose from the current devices.
**Native KDE Connect settings** shows launch progress or an error beside the button.
Launch requested means the command was accepted; it does not confirm a visible
window. Older KDE Connect settings frontends can open the device list instead.

In Devices, use the **Device** dropdown to switch devices. It is the only device
list in the daily view. The gear beside it opens **Device features** for that
exact device in Plus. Collapse **Device details** to keep the switcher compact.
Pairing warnings and an active unpair confirmation remain visible. Use **Native
KDE Connect settings** inside Plus for KDE Connect's full settings and permissions.

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

Each daily section has an Expand or Collapse control. In **Plus settings →
Appearance → Daily section order**, use **Up** and **Down** to move any complete
section. Hidden sections keep their position. **Use default section order** resets
only the order. These display choices apply to all devices on this computer.

Choose **Show in Devices** and **Start expanded** in the section's settings domain:

| Settings domain | Daily sections |
| --- | --- |
| Quick actions | Quick actions; File sharing |
| Device features | Device details; Native KDE Connect; Media controls; Remote commands |
| Connections | Connection controls; Saved addresses; Syncthing identity note |

The device switcher stays available when **Device details** collapse. Device
details show the status, battery, cellular state, ID, reported addresses,
connection providers and **Pair** or **Unpair**. Switching devices does not
change the recipient of a file review. Devices and Quick actions start expanded;
the other sections start collapsed. Section help is in each heading's tooltip. Hiding a section keeps
its data and provider settings. A temporary collapse lasts until you reopen the
popup. Use **Start expanded** to set the next opening.

## Appearance

- **Bar icon:** Select **Change bar icon**. Choose a labelled preset, search the
  installed icon theme (symbolic icons are listed first), or use a custom symbol or local PNG/SVG. Preview, then Apply.
  Installed artwork keeps its native colours automatically. Clear **Keep installed
  icon colours** to use the theme foreground for any monochrome icon name.
  Custom image colours have their own choice. Browsing does not save.
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
| Tailscale | Open the existing Tailscale panel. Connect in its owner app. Approve the peer’s Tailscale IP under **Saved addresses**. | [Tailscale quickstart](https://tailscale.com/docs/how-to/quickstart) |
| MikroTik Back to Home | Use the existing reviewed helper. **Automatic** uses its policy; **On** requests activation; **Off** requests that it stay stopped. Read actual connection state separately. | [MikroTik Back to Home](https://manual.mikrotik.com/docs/network-management/cloud/back-to-home/) |
| Other WireGuard profiles | Open the existing NetworkManager profiles. The manager owns profiles and keys. Approve the peer’s private VPN IP for rediscovery. | [WireGuard quickstart](https://www.wireguard.com/quickstart/) |

**BTH helper path** is optional. Empty uses `~/.local/bin/remote-access-mode`.
Use an absolute path to your existing reviewed controller. Plus does not create
that controller or import keys. A missing provider shows an unavailable result.
See [provider contracts](CONTRACTS.md) before connecting a different controller.

**Saved addresses:** Select a device. Expand **Saved addresses**. Enter one IP,
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
**Remove** to change the toolbar. **Use default actions** restores Files, Text, and Clipboard. These choices do not enable a native module or execute it.
Each action shows its description and selected-device availability.

- **Files:** Open the normal desktop file chooser, then review before Send.
- **Text:** Compose up to 8192 characters and send explicitly. Plus uses the native session bus; private content stays out of process command arguments.
- **Clipboard:** Send the current clipboard to the selected device.
- **Quick Share:** Open [RQuickShare](https://github.com/Martichou/rquickshare)
  to share with Android Quick Share. Install the `r-quick-share` package first.
  It is a separate app with its own pairing; KDE Connect does not use it.
  Its launch status appears below the shortcuts. Wait while it opens before
  choosing Quick Share again. Other device actions remain available, and their
  results stay separate from the launcher result.
- **Ring:** Request a sound. If unavailable, open native **Plugin settings** and
  check Find my phone. A successful command does not confirm an audible sound.
- **SMS:** Open native KDE Connect conversations, where the platform permits it.
- **Ping:** Compose a notification. The optional default message fills the draft;
  you can edit up to 8192 characters before sending. Private Ping content also uses the session bus. Ping and Ring use different native modules.
- **Native KDE Connect settings:** Open the selected device in native KDE Connect.

If the Quick Share window does not appear after launch, check its tray icon.
See [RQuickShare setup and limitations](https://github.com/Martichou/rquickshare#installation).

## Device features

**Device details** in Devices, and **Info** in Device features settings, show the
selected device's ID, battery, cellular state, reported addresses and connection
providers. Missing values say **Not reported**. Offline addresses are not
presented as current. Device details respect the battery and cellular visibility
preferences.
For native certificate fingerprints and protocol details, use
`kdeconnect-cli --device DEVICE_ID --encryption-info` with the ID shown in
Device details. This is a read-only native route. The pairing verification code is
different from the complete certificate information; a saved address does not
establish identity or trust.

**Use device as an external monitor** uses KDE Connect's native Virtual Monitor
module. It appears in Devices when reported and is also available in Device
features. You can add it to Quick actions. The control shows **Stop virtual monitor
session** only when native state reports an active session. The computer needs
KRDP; the other device needs a compatible RDP client. Plus does not install these
or manage display-session credentials. An accepted request does not prove that
the other device displays an image. If state is unknown or prerequisites are
unavailable, check **Native KDE Connect settings**.

**KDE Connect modules** lists all modules from the installed KDE Connect package.
Search by name, description or plugin ID. The catalogue updates with native
package metadata; it is independent of the selected device's currently reported
features. Unknown reported IDs remain visible below it. Quick actions are reviewed
entry points; Plus does not turn arbitrary plugin names into commands.

For a paired device, **On/Off** reads and changes KDE Connect's native module state
on this computer. Paired offline devices remain configurable. A change stays
pending until native readback confirms the value. **Unknown** means no reliable
value was read; use **Refresh** before changing it. An uncertain write is not
retried automatically. An unpaired device must be paired first. These switches
do not grant phone permissions or enable modules on the other device. A second
change during a request is not submitted; the status explains when to try again.

**Configure ↗** opens that exact module's native configuration page. Only modules
with an installed configuration form have this link. If direct configuration is
unavailable on an older frontend, use **Native settings ↗**, then **Plugin Settings**.
Plus does not write native configuration files or load native configuration QML.
The native daemon owns module state and the native app owns configuration forms.

**Commands on this computer → Configure** defines commands on **this computer** that the selected
device can run. It does not edit commands on the other device. To add or edit
commands that run on the selected device, use that device's KDE Connect settings.
**Request command editor on selected device** can ask a connected compatible peer
to open its setup page. It rechecks whether the peer accepts that request. Check
the other device for the editor. Request acceptance does not confirm that it
opened, and no command runs. If unavailable, open Run commands settings there.

Media player choices and transport buttons support Tab, Enter, Space and
assistive-technology activation. The current player starts with **Current:**,
so its state remains clear without color or hover. Unavailable controls do not
submit an action.

Use **Info** and **Actions** to expand device details and occasional actions.
Use **Native settings ↗** for the full KDE Connect application. Modules ship with
KDE Connect; there is no separate module download store. Install or update the
native package to receive its modules. Phone permissions stay on the phone.
Read the [KDE Connect user guide](https://kdeconnect.kde.org/users.html).

- **Battery details:** Show charge and charging state when reported.
- **Cellular connection details:** Show reported cellular type and signal; this
  does not describe Wi-Fi or VPN reachability.
- **Media controls:** Expand Media in Devices. Control music and video playing on
  the selected device. Choose a reported player and use previous, play/pause or next. Playback stays in the owner app. Track text and
  controls remain available; provider-supplied album-art URLs are not displayed or fetched.
- **Remote commands:** Expand Remote commands in Devices. Commands run on the
  selected device. Add or edit them in that device’s KDE Connect Run commands settings.

## Send files and read activity

1. Select a paired, reachable device. Expand **File sharing** in Devices, or open **Send**.
2. Drop files on the inline target or select **Choose files** for the graphical
   desktop chooser. The popup can close when you focus a file manager. Select
   **Keep Send window open** in Devices, or **Open Send window** in Send, for a
   persistent target. Dragging local file URLs over the bar icon also opens and
   reveals the inline target, even if its section is hidden. This reveal lasts
   for that popup session and does not change its saved visibility.
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
Copies become eligible for cleanup after 24 hours. Plus attempts cleanup at plugin
start and during later preparation when the cache is safe and available. Permissions
or the cleanup deadline can leave eligible copies, so 24 hours is not a maximum
retention time. Plus preserves unexpected files.
Private canonical sources normally use their existing path. KDE owns its later
file open; programs running as your user and root remain trusted.
Text, Ping, Clipboard and remote-command success messages also report request acceptance. Check the recipient or remote result for delivery or execution.

## Syncthing identity note

Enable **Show in Devices** for **Syncthing identity note** in **Settings → Connections**. Select a
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

`omarchy plugin update omaconnect.plus` updates this UI fork. KDE Connect's native
package follows the supported Omarchy system update route, `omarchy update`.
That can update other packages, so review its normal system update scope first.
Plus does not compile KDE's development branch or run a package update for you.

The [upstream watcher](UPSTREAM-WATCH.md) monitors provider changes separately.
