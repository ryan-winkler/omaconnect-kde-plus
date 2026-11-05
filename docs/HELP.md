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

## Screenshots

These screenshots show the current UI with example devices, files and media.
Select an image to view its full size. Your theme, installed native modules and
reported device features can change the available controls.

<details>
<summary>Bar, Devices and the open device dropdown</summary>

The bar icon and battery appear above the daily panel. Device details can collapse
without hiding the device selector.

![Bar icon and daily Devices panel with example device details and quick actions](../preview.png)

The open dropdown keeps connected, offline and unpaired devices in one list.

![Opened device dropdown with three example device states](screenshots/bar-dropdown.png)

</details>

<details>
<summary>Recent-file icons and guided image previews</summary>

File-type icons help identify recent files. Select **Image previews…** to browse
supported images with your recipient and next action visible. **Back to files**
keeps that recipient and send/review choice. Browsing alone does not send.

![Native recent-file menu with image, document, video, audio and archive icons and an Image previews entry](screenshots/recent-file-menu.png)

The preview uses an example image here. Your installed image codecs and theme
can change the available previews.

![Guided image preview showing the recipient, filename, Back, Cancel and explicit image action](screenshots/image-previews.png)

</details>

<details>
<summary>File review, pending Cancel and submission activity</summary>

The persistent Send window keeps the recipient and reviewed files visible while
you use a file manager.

![Persistent Send window reviewing two example files and showing Send and Cancel](screenshots/send-review.png)

A pending submission shows its acceptance count and delivery status. **Cancel**
and **Cancel pending files** stop Plus work. See [Send files](#send-files-and-read-activity)
for the native transfer limits.

![Pending file submission with visible local and global Cancel controls and delivery unknown](screenshots/pending-cancel.png)

Activity distinguishes request acceptance from delivery.

![Activity with two accepted example requests and delivery still unknown](screenshots/activity.png)

</details>

<details>
<summary>Media controls and remote commands</summary>

Expand reported media controls to select a player or use playback actions.
Configured remote commands remain explicit actions.

![Expanded sample media player with playback controls and a configured remote command](screenshots/media-commands.png)

</details>

<details>
<summary>Phone folders and direct layout editing</summary>

Select **Browse phone files** to open folders advertised by KDE Connect. If the
phone exposes several folders, choose one. **Cancel browse** clears the pending
choice; phone permissions remain in KDE Connect.
On Arch/Omarchy, browsing also needs KDE Connect's optional `sshfs` package; see
[installation prerequisites](INSTALL.md#install).

![Phone file controls with two example shared folders, Cancel browse and native settings](screenshots/phone-files.png)

Select the **Edit layout** pencil beside Plus settings in **Devices** to change
visibility and position on the actual
sections. Hidden sections remain available in the editor. Availability rules use
reported capability or configured local tools; they do not confirm delivery.

![Devices in Edit layout mode with visibility policies and position controls](screenshots/edit-layout.png)

</details>

<details>
<summary>Appearance and icons</summary>

Appearance holds bar and device identity choices and daily navigation preferences.

![Appearance settings with icon actions and popup navigation preferences](screenshots/appearance.png)

Choose a preset, alias or installed icon, then preview before Apply.

![Device appearance dialog with example device alias, icon presets and preview](screenshots/icons.png)

Turn off **Show Edit layout in Devices** to hide the pencil. Use **Edit Devices
layout** in **Appearance** to open the editor with the shortcut hidden.

</details>

<details>
<summary>Connections, sharing preferences and native device features</summary>

Connections exposes the existing provider integrations. Its switches show or hide
their controls; they do not connect a VPN.

![Connections settings with optional Tailscale, Back to Home and WireGuard visibility controls](screenshots/connections.png)

Quick actions sharing preferences are shown here scrolled to **Use desktop file
chooser**, **Review files before Send**, and task-notice preferences. These
settings are independent. Device names are excluded from desktop notices by
default; enable that option only if you want names in native notification history.

![Quick actions sharing, file-review, task-notice and device-name privacy preferences](screenshots/sharing-preferences.png)

Device features lists installed native modules and their observed state, with
Configure links to the native settings owner.

![Device features settings with native module search, On or Off values and Configure links](screenshots/device-features.png)

</details>

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

Each daily section has an Expand or Collapse control. Select **Devices → Edit
layout** to change the actual sections in place. All sections appear while editing,
including hidden sections. **Visibility** offers **Show**, **Hide**, **When
available** and **When unavailable**. Loading or unknown data matches neither
condition. Availability describes reported capability or configured local tools;
it does not confirm delivery, playback or a VPN connection.

Use a section's **Move to** menu to select its position. This works with a pointer
or keyboard. Hidden sections keep their positions. **Use default section order**
resets order only. Select **Done** to return to the daily view. Changes apply to
all devices on this computer. The device selector always stays available.

Choices save when selected. Controls show saved configuration after readback.
While a save is pending, another layout edit is not submitted. A missing readback
shows recovery text; follow it before making another change. Save status and failures stay beside the section you edited. Leaving edit mode
does not discard a submitted save. Layout editing does not change native modules,
VPN modes or accepted file operations, and preserves file and text drafts.

**Start expanded** remains on each section's settings page:

| Settings domain | Daily sections |
| --- | --- |
| Quick actions | Quick actions; File sharing |
| Device features | Device details; Native KDE Connect; Media controls; Remote commands |
| Connections | Connection controls; Saved addresses; Syncthing identity note |

The device switcher shows the device state and stays available when **Device
details** collapse. Device details show the battery, cellular state, ID, reported
addresses, connection providers and **Pair** or **Unpair**. Rows the device does
not report are hidden. Switching devices does not change the recipient of a file
review. Devices and Quick actions start expanded; the other sections start
collapsed. Section headings show a short description on hover and to screen
readers; this guide has the full help. Hiding a section keeps
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
Active Plus buttons expose named accessibility actions. The guarded Settings
buttons, preference toggles, composer actions and Refresh control reject
retained accessibility actions while hidden. Guarded Settings buttons also
ignore Return and Space after their view hides. Preference toggles also ignore
Return, Enter and Space while hidden; saves already accepted can finish. Closing the popup,
changing views or editing layout blocks composer submission and keeps unsent
drafts. Collapsing Remote commands returns Refresh focus to its section header.

## Quick actions

Choose a shortcut, then select **Add selected action**. Use **Up**, **Down** or
**Remove** to change the toolbar. **Use default actions** restores Files, Text, and Clipboard. These choices do not enable a native module or execute it.
Each action shows its description and selected-device availability.

- **Files:** Open the original Omarchy recent-file menu. Selection sends to the
  recipient shown when the menu opened. Enable **Use desktop file chooser** for
  any local file and multiselect. Enable **Review files before Send** to check
  chosen files before an explicit Send. These settings are independent. Drops
  always require review. Invalid stored settings fall back to desktop review.
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

## Browse phone files

In Devices, expand **File sharing** and select **Browse phone files**. You can
also add **Browse phone files** in Quick actions settings. KDE Connect prepares
the phone's shared storage, then Plus asks your default file manager to open it.
One advertised folder opens directly. If the phone shares several folders,
select one from the list. Plus uses the advertised folders; it does not guess
Photos or Downloads paths.

The phone must be paired, reachable and permit **Filesystem expose** in KDE
Connect. **Phone file settings in KDE** opens the native settings fallback.
A launch request does not confirm that a file-manager window appeared. If it
fails, check the default file manager and the native KDE storage settings.
Switching devices or closing the popup cancels pending browsing. A file manager
that has already started opening can still appear. Browsing does not change the
recipient or files in a Send draft. Copying, moving or deleting files in the file
manager remains a separate action owned by that application.

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
2. Select **Choose files**. By default the original Omarchy recent-file menu opens;
   selecting a file submits it immediately to the recipient shown in the prompt.
   Set **Plus settings → Quick actions → Review files before Send** to review
   first. **Use desktop file chooser** switches to the graphical chooser with
   multiselect. The popup can close when you focus a file manager. Select
   **Keep Send window open** in Devices, or **Open Send window** in Send, for a
   persistent target. Dragging local file URLs over the bar icon also opens and
   reveals the inline target, even if its section is hidden. This reveal lasts
   for that popup session and does not change its saved visibility.
3. The recent-file menu offers one supported file from Downloads, Documents,
   Pictures, Videos or Desktop, within four levels, most recently changed first.
   These five starting folders can link to moved storage. The menu uses their
   resolved locations and skips links and hidden items inside them. Search stops
   between filesystem operations after 20,000 entries or two seconds. Blocked
   storage can take longer; a large tree can omit files. The menu options have a
   64 KiB budget.
   File-type icons identify images, videos, audio, documents and archives.
   **Image previews…** opens a preview window with your recipient and filename
   always visible. Search or use **Previous** and **Next** to find the image.
   Browsing never sends. Select **Send image** to send it, or **Review image** to
   check it before the separate Send step when review is enabled.
   **Back to files** returns to the file list for the same recipient and saved
   send/review choice. **Cancel**, Escape or closing the preview clears this
   selection. Previews support JPEG, PNG, WebP and GIF, with up to 200 images
   within a 48 KiB list budget. Other formats stay in the normal file list.
   Use the desktop chooser for other files, names with controls, or larger trees.
   The desktop chooser and drops support up to 100 local regular files, 1 TiB combined.
   Directories and remote URLs are not accepted. Drops use Copy and preserve originals.
4. With review enabled, or after any drop, check the recipient, files, count and
   size. Select **Send files**. Changing devices or settings while a chooser is
   open does not change its captured recipient or review policy.
5. Read Activity. **Request accepted** confirms command acceptance. Check the
   recipient for actual receipt.

**Cancel pending files** stays in daily navigation while choosing, preparing or
submitting, even when File sharing is collapsed or you change views. **Cancel**
in the Send window uses the same controller. A draft Cancel discards the selection.
An operation Cancel stops remaining requests and asks the active helper to stop;
after two seconds Plus force-stops a picker, inspector or submission helper
that has not exited. A lost final
acknowledgement stays **Cancellation unconfirmed**. Cancellation after a native
invocation does not prove that the transfer stopped.

**Task notices:** In **Plus settings → Quick actions**, **Show task notices**
controls desktop notices after a file operation. Plus suppresses these notices
while its popup, Send window or image preview is open. It reports request evidence, not receipt.
The **Activity** button opens current Activity. It never retries or restores an
old task. Desktop Do Not Disturb and notification history apply.

**Include device name in task notices** is off by default. Enable it only if you
want the reviewed device name on desktop cards and in their history. File names,
paths, device IDs and message content stay excluded. Changing this preference
does not remove earlier desktop history. If desktop notices fail, Activity keeps
the submission result and shows a short notice-status message. Plus does not
retry the file request. Notice text currently ships in English and uses the
native plugin translation fallback.

KDE Connect owns phone notification forwarding, its native actions and phone
permissions. Open **Native KDE Connect settings** in **Device features** for
those controls. The Plus task-notice preferences do not grant phone permissions
or collect phone notifications.

For an accepted **LAN** transfer, select **Cancel** in KDE Connect's native transfer
progress window or job notification. The native job can contain other submissions
to the same device. The public sharing API returns no transfer ID or cancel method,
and the Bluetooth path has no evidenced equivalent. Plus cannot cancel a specific
accepted transfer or recall a received file. See [native API limits](CONTRACTS.md#native-transfer-cancellation).

If the original file menu remains visible after Cancel or timeout, press
**Escape**. That native menu belongs to the shell. Plus cannot close only its
request without risking another caller's picker. A late choice from a cancelled
picker cannot send a file. Use the desktop chooser when you need a picker whose
Close request Plus can control.

Closing the Send window preserves a draft. It does not cancel pending work.
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

In **Devices → Edit layout**, set **Syncthing identity note** to **Show** or **When available**, then select **Done**. Select a
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
