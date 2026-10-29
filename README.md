# Omaconnect KDE Plus

A KDE Connect companion for the [Omarchy](https://omarchy.org/) bar: send files,
run your own quick actions and choose how your devices look. It is a fork of
[Jitendra Dara’s OmaConnect](https://github.com/jitendradara12/omaconnect), built
on [KDE Connect](https://kdeconnect.kde.org/).

![Native settings with invented sample device data](preview.png)

[![Functional checks](https://github.com/ryan-winkler/omaconnect-kde-plus/actions/workflows/validate.yml/badge.svg)](https://github.com/ryan-winkler/omaconnect-kde-plus/actions/workflows/validate.yml)
[![CodeQL](https://github.com/ryan-winkler/omaconnect-kde-plus/actions/workflows/codeql.yml/badge.svg)](https://github.com/ryan-winkler/omaconnect-kde-plus/actions/workflows/codeql.yml)

## Install

```bash
omarchy pkg add kdeconnect python python-gobject
omarchy plugin add https://github.com/ryan-winkler/omaconnect-kde-plus.git --enable
```

Open the new bar icon, select **All KDE Connect features** and pair your device.
See [install, update and recovery](docs/INSTALL.md), including how to move from
the original OmaConnect. The plugin ID is `Omaconnect.plus`.

## Features

- **Files:** pick up to 100 files with the desktop file chooser, or drop them on
  the bar icon or the Send window. Review the recipient, count and size, then Send.
  Drops copy and never move originals.
- **Honest activity:** “Request accepted” means KDE accepted the transfer;
  delivery stays unknown. A batch keeps its reviewed recipient.
- **Quick actions:** add, remove and reorder 18 shortcuts, including media
  transport and native KDE Connect routes.
- **Appearance:** choose a phone, computer, theme icon, symbol or local PNG/SVG,
  and an alias per device. Preview before Apply.
- **Settings:** Appearance, Connections, Quick actions and Device features, with
  short help next to each control. Sections can be hidden or collapsed.
- **All KDE Connect features:** search the native plugin list and open the
  selected device in KDE Connect, which keeps pairing, battery, notifications,
  file browsing, media playback and player switching, remote commands, clipboard,
  text, SMS and remote input.
- **Network access:** optional Tailscale, MikroTik Back to Home and WireGuard
  sections with short guides. They show controls; they never connect a VPN.
  An optional card shows an existing Back to Home helper’s Automatic / On / Off mode.
- **Private addresses:** approve LAN or VPN addresses per device, with opt-in
  rediscovery. Existing KDE addresses are preserved.
- **Syncthing notes:** optionally record that a KDE device and a Syncthing ID are
  the same machine, and open the existing Syncshell panel.

Read the [task guide](docs/HELP.md) for every control.

## Why Plus?

OmaConnect already covers pairing, battery, clipboard, SMS, media and remote
commands. Keep it if its workflow suits you. Plus adds:

| If you need… | Plus adds… |
| --- | --- |
| Your own bar and device look | Icon search, local images, aliases and preview. |
| A normal file workflow | File chooser, multiselect, drops and explicit review. |
| Shortcuts that fit your tasks | Add, remove and reorder actions; Ring is optional. |
| Every native feature in reach | Searchable native inventory and per-device KDE settings links. |
| Your existing remote access | Separate Tailscale, Back to Home and WireGuard opt-ins. |

## Requirements

Omarchy, KDE Connect, Python 3 with PyGObject and a desktop file portal. The
optional home-access card needs the existing `remote-access-mode` helper (path
configurable). Opening Syncthing needs the `io.github.ilyazar.syncthing` plugin.
Missing optional providers stay unavailable; Plus never installs them.

## Privacy

Appearance and address metadata stay in owner-only files. Typed text and Ping
messages travel over stdin and D-Bus, never process arguments. Files in shared
locations are sent from a private snapshot. Activity keeps at most 50 summaries
in memory, without paths. Media shows track text and controls but never loads
provider-supplied album art.

## Contributing

Code, docs, design, accessibility and device testing are all welcome. Start with
[CONTRIBUTING.md](CONTRIBUTING.md) and run `./scripts/validate.sh`. Ask questions in
[Discussions](https://github.com/ryan-winkler/omaconnect-kde-plus/discussions),
see [SUPPORT.md](SUPPORT.md) for help, and report vulnerabilities privately through
[SECURITY.md](SECURITY.md). Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Credits and license

Plus starts from OmaConnect 1.5.0
([`71282d2`](https://github.com/jitendradara12/omaconnect/tree/71282d2042b1a1cda1cb1cac84251694eaabb7cb))
and keeps its history and MIT license. KDE Connect owns pairing, permissions and
the device protocol. The Back to Home card keeps its
[Bananet](https://plugins.omarchy.org/plugin.html?id=banan.bananet) notice in
`BthControlCard.qml`. This is an independent community project, not an official
KDE or Omarchy one. See [AUTHORS.md](AUTHORS.md) and [LICENSE](LICENSE).
