# Omaconnect KDE Plus

Use [KDE Connect](https://kdeconnect.kde.org/) from the
[Omarchy](https://omarchy.org/) bar. Send files. Open folders that your phone
shares. Select the Quick actions for the bar menu.

Omaconnect KDE Plus is a fork of
[Jitendra Dara’s OmaConnect](https://github.com/jitendradara12/omaconnect).
KDE Connect pairs devices and sends data between them.

<img src="preview.png" width="380" alt="The Send window shows an example phone and the Send files button">

The screenshots show example devices, files and media.
Refer to the [screenshot gallery](docs/HELP.md#screenshots) for examples of the
device list, file sharing, media controls, layout editor and settings.

[![Functional checks](https://github.com/ryan-winkler/omaconnect-kde-plus/actions/workflows/validate.yml/badge.svg)](https://github.com/ryan-winkler/omaconnect-kde-plus/actions/workflows/validate.yml)
[![CodeQL](https://github.com/ryan-winkler/omaconnect-kde-plus/actions/workflows/codeql.yml/badge.svg)](https://github.com/ryan-winkler/omaconnect-kde-plus/actions/workflows/codeql.yml)

## Install

If you have Plus 0.1.2 or a version before 0.1.2, read the
[ID migration guide](docs/INSTALL.md#former-uppercase-development-id) before
you add Plus. This procedure keeps the bar position and the settings. It
prevents a second active copy of Plus.

If you have OmaConnect, read the
[guide for an installed copy](docs/INSTALL.md#move-from-an-existing-installation)
before you add Plus. The guide shows how to add Plus without the `--enable`
option.

For a new installation, install the packages.

```bash
omarchy pkg add kdeconnect python python-gobject
```

Then use this command to add and enable Plus.

```bash
omarchy plugin add https://github.com/ryan-winkler/omaconnect-kde-plus.git --enable
```

Select the Plus icon in the bar. To pair a device, select **Pair in KDE Connect**
or **Open KDE Connect**. If you cannot see these buttons, open **KDE Connect**
from the application launcher. Compare the verification keys on the two
devices. If the keys are the same, accept the pairing request.

The Plus plugin ID is `omaconnect.plus`.

## Features

- **Files.** Select the recipient in Devices. In the default settings, select
  up to 100 local files in the desktop file chooser. In the Send window, make
  sure that the files and the recipient are correct. Select **Send files**.
  If you set **Review files before Send** to Off, make sure that the recipient
  is correct before you open the file chooser. Plus sends the files when you
  accept the selection in the chooser. To use the Omarchy recent-file menu and
  **Image previews…**, set **Use desktop file chooser** to Off. Both options
  are in **Plus settings → Quick actions**.
  You can drag and drop files on Devices, the bar icon or the Send window.
  Plus always shows a review for dropped files. The source files stay in
  the same locations.
- **Phone folders.** Select **Browse phone files** to open folders from your
  phone in the default file manager. To use the shortcut from Devices, add it to
  **Quick actions**. If the phone shares more than one folder, Plus shows a list.
  If Plus shows that the storage is unmounted, select **Phone file settings in KDE ↗**.
  You can also select **Browse phone files** again. If the button cannot open
  the settings, open the settings in KDE Connect. Refer to
  [Browse phone files](docs/HELP.md#browse-phone-files) for the package and
  storage instructions.
- **Screenshots.** Add **Review saved screenshot** to **Quick actions**. Save an
  image with Omarchy Screenshot. In Devices, select **Review saved screenshot**.
  Select one PNG file. In the Send window, make sure that the file and the
  recipient are correct. Select **Send files**.
- **Cancel.** Use **Cancel** to stop queued file requests from a daily view or
  the Send window. If the request was active when you selected **Cancel**, the
  receiving device can receive the file. If KDE Connect shows a **Cancel**
  button for the LAN transfer, select it. Refer to the
  [task guide](docs/HELP.md) for the Bluetooth limits.
- **Activity.** Activity shows **Request accepted** when KDE Connect accepts
  the request. Make sure that the receiving device has the file. All file
  requests in a batch use the same recipient.
- **Desktop notices.** Plus shows file request results while the popup, Send
  window and image preview are closed. In the default settings, the notices
  show the results without device names. To show the names, enable the option in
  **Quick actions**. Omarchy controls notification history and Do Not Disturb.
- **Quick actions.** Add or remove shortcuts. Move shortcuts to change their
  sequence. The shortcuts include media controls, KDE Connect functions and
  an optional Quick Share shortcut.
- **Appearance.** Select a phone icon, computer icon, theme icon, symbol or
  local PNG or SVG file. You can set an alias for each device. See the preview.
  To keep the change, select **Apply**.
- **Daily layout.** You can put the View menu at the top or at the bottom.
  You can add Send and Activity shortcuts. Select the device from the device
  list. You can collapse the sections in Devices. Open **Devices → Edit layout**
  to show, hide or move a section. You can move a hidden section.
  You can open all views from the View menu.
- **Language and launcher.** Plus uses the Omarchy language and reading
  direction. If a Plus translation is missing, Plus shows the text in English.
  The optional
  [application launcher](docs/INSTALL.md#optional-application-launcher)
  opens Devices, Send files or Activity.
- **Settings.** The Plus settings have four sections. Each control has help.
  - Appearance
  - Connections
  - Quick actions
  - Device features
- **Device features.** Find an installed KDE Connect module. Set it to On or
  Off. Plus shows the state from KDE Connect. To configure the module, open
  its native settings. KDE Connect supplies pairing, battery information,
  notifications, file browsing and media controls, including player switching.
  It also supplies remote commands, clipboard, text, SMS and remote input.
- **Network access.** The optional Tailscale, MikroTik Back to Home and
  WireGuard sections include guides. Select **Open Tailscale panel** for
  Tailscale. Select **Open WireGuard profiles** for WireGuard.
  These two controls do not start or stop VPN connections.
  The optional Back to Home card shows the mode of its helper. You can use
  the card to set the helper to Automatic, On or Off. The helper controls the
  Back to Home connection.
- **Private addresses.** Use **Saved addresses** to give approval for a LAN
  or VPN address for each device. You can enable rediscovery. Plus keeps the
  addresses that KDE Connect has before you save a new address.
- **Syncthing notes.** You can add a local note with the KDE Connect device and
  the Syncthing ID for the same computer. You can pause synchronization with
  that computer. You can start synchronization with that computer again.
  You can open the Syncshell panel.

Read the [task guide](docs/HELP.md) for information about the controls.

## Screenshots

Select an image to see it at full size. The [gallery](docs/HELP.md#screenshots)
also shows appearance, icon options, section sequence, connections and native
device functions.

| Device list | File review in the Send window |
| --- | --- |
| [![The bar icon and the device list show connected, offline and unpaired devices](docs/screenshots/bar-dropdown.png)](docs/screenshots/bar-dropdown.png) | [![The Send window shows two files and the recipient](docs/screenshots/send-review.png)](docs/screenshots/send-review.png) |

| Pending file request and Cancel | File sharing settings |
| --- | --- |
| [![A pending file request shows Cancel and Cancel pending files](docs/screenshots/pending-cancel.png)](docs/screenshots/pending-cancel.png) | [![Quick actions settings show the desktop file chooser and review options](docs/screenshots/sharing-preferences.png)](docs/screenshots/sharing-preferences.png) |

| Recent files with file type icons | Image previews |
| --- | --- |
| [![The Omarchy recent-file menu shows file type icons and the Image previews option](docs/screenshots/recent-file-menu.png)](docs/screenshots/recent-file-menu.png) | [![The image preview shows the recipient, file name, Back, and Send image or Review image](docs/screenshots/image-previews.png)](docs/screenshots/image-previews.png) |

| Review a saved screenshot | Read the request result |
| --- | --- |
| [![The Send window shows a recipient, a PNG file, Send files and Cancel](preview.png)](preview.png) | [![Activity shows one accepted request and unknown delivery](docs/screenshots/screenshot-activity.png)](docs/screenshots/screenshot-activity.png) |

## Why Plus?

OmaConnect includes pairing, battery information, clipboard, SMS, media
controls and remote commands. If OmaConnect has the functions you use, you can
keep it.

| Function | What Plus adds |
| --- | --- |
| Bar and device icons | Icon search, local images, aliases and preview. |
| File selection and review | Omarchy recent-file menu and desktop file chooser. Select multiple files. You can drag and drop files for review or set the chooser to show a review. |
| Quick actions | Add, remove or move shortcuts. Ring is optional. |
| Menu layout | Move the View row. Add Send and Activity shortcuts. Move or collapse the sections in Devices. |
| Installed KDE Connect modules | Find modules. Set modules to On or Off. Open native settings for each device. |
| Remote access | You can enable each of the Tailscale, Back to Home and WireGuard sections. |

## Requirements

Plus uses Omarchy, KDE Connect, Python 3 with PyGObject and a desktop file
portal. The optional Back to Home card uses a `remote-access-mode` helper.
You can set the path to the helper. The Syncshell panel uses the
`io.github.ilyazar.syncthing` plugin. The Quick Share shortcut opens RQuickShare
(`r-quick-share` package). RQuickShare uses the Quick Share protocol. Plus does
not include the Back to Home helper. Plus does not install the optional tools.

## Privacy

Plus keeps appearance and address data in files that only the owner can read.
Plus uses stdin and D-Bus to send typed text, Ping messages and file paths to
KDE Connect. During that operation, Plus does not put these values in process
arguments.

The optional recent-file menu puts the file paths it shows and the recipient
name in Omarchy’s process arguments. On some systems, other local accounts can
read these arguments. With the desktop file chooser, Plus does not put these
values in Omarchy's process arguments. Omarchy also puts saved settings in
process arguments for a short time. A default Ping message is one example.
Do not put private text in these settings.

For files in shared locations, Plus sends a private copy. Activity keeps up to
50 summaries in memory. Plus does not put file paths in these summaries. Media
shows only track text and controls.

## Contributing

You can send changes to the code, documentation or design. You can also
send accessibility changes or results from device tests. Read the
[contribution guide](CONTRIBUTING.md). For a first change, select a
[good first issue](https://github.com/ryan-winkler/omaconnect-kde-plus/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22).
Write questions in [Discussions](https://github.com/ryan-winkler/omaconnect-kde-plus/discussions).
Read the [support guide](SUPPORT.md). To report a vulnerability privately,
follow the [security policy](SECURITY.md).
Refer to the [changelog](CHANGELOG.md) for release changes.

## Credits and license

Plus is a fork of OmaConnect 1.5.0
([`71282d2`](https://github.com/jitendradara12/omaconnect/tree/71282d2042b1a1cda1cb1cac84251694eaabb7cb))
and keeps its Git history and MIT license.
[KDE Connect](https://kdeconnect.kde.org/) pairs devices, controls permissions
and supplies the device protocol. Read the
[upstream contribution instructions](CONTRIBUTING.md#share-reusable-improvements-upstream).
The Back to Home card keeps the
[Bananet](https://plugins.omarchy.org/plugin.html?id=banan.bananet) notice in
`BthControlCard.qml`. This is a community project. KDE and Omarchy
do not supply it. Refer to [AUTHORS.md](AUTHORS.md) and [LICENSE](LICENSE).
