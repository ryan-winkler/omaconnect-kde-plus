# Omaconnect KDE Plus

An Omarchy bar UI fork of [Jitendra Dara’s OmaConnect](https://github.com/jitendradara12/omaconnect), built on [KDE Connect](https://kdeconnect.kde.org/).

Jitendra’s plugin and KDE Connect are the upstream foundations. We retain their
credit, follow their interfaces, and aim to contribute reusable fixes back.
This is an independent community fork. See [lineage and licenses](FORK.md).

**Version 0.1.0.** The fork adds one place for known devices,
file submission, appearance and network access through **Tailscale, MikroTik Back
to Home, or WireGuard**. KDE Connect owns pairing and transfers. Existing native
network tools retain connection ownership; the BTH helper retains its policy.

![Native settings with invented sample device data](preview.png)

## First release

- **Settings:** Open a dedicated native window for Appearance, Connections,
  Quick actions and Device features. All active Plus preferences have a domain; native
  plugin enablement and permissions link to the selected device in KDE Connect.
- **Quick actions:** Add, remove and reorder verified shortcuts in Settings. Ring
  is optional; new installs start with Files, Text/link and Clipboard. Native
  plugin enablement stays independent.
- **Appearance:** Choose a phone, computer, theme icon, custom symbol or local
  PNG/SVG for the bar. Set a separate icon and local alias for each KDE identity.
  Preview before Apply. Reset to Phone or follow the selected device.
- **Files:** Use the desktop portal to select up to 100 regular files, with a
  combined maximum of 1 TiB. This uses the default graphical file picker requested
  in [upstream issue #17](https://github.com/jitendradara12/omaconnect/issues/17),
  through the desktop portal. Check the recipient, count and size, then select
  Send. Or open the persistent **Send window** and drag local files from your file
  manager. Drops prepare review only and accept Copy, preserving originals.
  Selection alone sends nothing. Directories are not archived.
- **Honest activity:** Each batch keeps its reviewed recipient. Changing the
  selected device does not redirect it. “Request accepted” means KDE accepted
  the command; delivery remains unknown. Timeout and cancellation remain explicit.
- **Network access:** Find Tailscale, MikroTik Back to Home and generic WireGuard
  in **Settings → Connections**. Enable only the sections you want, read the short
  guide and open official help. These saved visibility choices do not connect or
  disconnect a VPN. All optional sections start hidden; use each native owner
  for connection control.
- **Home access:** View the existing BTH helper’s Automatic / On / Off controls.
  Selected mode and actual interface state are separate. Missing or invalid
  status disables unsafe actions. No VPN keys or profiles are imported.
- **Private addresses:** Approve LAN, BTH, WireGuard or Tailscale IP literals for a
  specific KDE identity, including Tailscale’s CGNAT range for that source.
  Preserve existing KDE addresses. Opt in to rediscovery while the panel is open;
  route events are debounced and failures back off. An IP does not prove identity.
- **Syncthing links:** Explicitly associate two full device IDs in local metadata
  and open the existing Syncshell panel. Syncshell retains its own core and keys.

Quick Share, router rosters, new VPN setup and inline Syncthing pause/resume are
later work. This fork does not implement the separate Banatik/UniFi collector.

**All KDE Connect features** opens the selected peer in the native app, including
its Plugin Settings. Common actions stay in the bar; the full returned native
plugin inventory is searchable in **Settings → Device features**. Supported and
loaded states stay distinct. Native Plugin Settings becomes available when the
peer is paired and reachable. Enabling an installed module differs from installing
new native code; the standard KDE page is not an add-on store.
KDE Connect keeps permissions, plugin configuration and its native capabilities,
including pairing, battery, notifications, file browsing, media playback and
player switching, remote commands,
clipboard, text, SMS and remote input where the peer/platform supports them.

## Requirements

Omarchy’s Quickshell UI, KDE Connect, Python 3 with PyGObject/Gio, a desktop file
portal, and the existing system tools used by Omarchy. Node is for tests only.
Optional home-access controls require the existing `remote-access-mode` helper.
Its absolute path is configurable in plugin settings; an empty setting uses
`~/.local/bin/remote-access-mode`. Syncthing opening requires the existing
`io.github.ilyazar.syncthing` plugin. Missing optional providers remain unavailable.

This branch uses plugin ID `ryan.omaconnect`. It can be staged separately from
`omaconnect`. **No installation or activation occurs from the tests or checkout.**
Read [migration and recovery](docs/MIGRATION.md) before moving existing settings.

## Install and open

Requirements: an existing Omarchy shell, `kdeconnect`, `python`, `python-gobject`
and a working desktop file portal. Omarchy supplies Quickshell and its UI kit.
Install missing packages through the supported package command:

```bash
omarchy pkg add kdeconnect python python-gobject
omarchy plugin add https://github.com/ryan-winkler/omaconnect-kde-plus.git --enable
```

The native installer asks for approval and bar placement. It reads the root
manifest; it does not run a repository install script. Open the new bar icon,
select **All KDE Connect features** and pair your device in native KDE Connect.
Open **Settings** for appearance, connections, quick actions and device features.
Use the [task guide](docs/HELP.md) for each control and its owner documentation.

If you use the original OmaConnect, keep it for comparison or disable its UI after
review: `omarchy plugin disable omaconnect`. Pairings stay in KDE Connect. Read
[migration and recovery](docs/MIGRATION.md) before moving existing display settings.

## Update, disable and remove

```bash
omarchy plugin update ryan.omaconnect
omarchy plugin disable ryan.omaconnect
omarchy plugin remove ryan.omaconnect
```

Use **enable**, **disable** or **remove** only for the action you want. Removal
uses Omarchy’s confirmation flow. It does not remove KDE pairings, providers or
private Plus metadata. Appearance assets and approved-address records stay under
`~/.config/ryan.omaconnect/` and `~/.local/share/ryan.omaconnect/`
unless you explicitly remove them. XDG overrides are supported. See the
[icon storage guide](docs/ICONS.md) for exact paths and backup scope.

For rollback, disable the fork and re-enable `omaconnect` if still installed.
The migration helper prepares a reviewed rollback candidate and preserves later
unrelated edits; it never applies an old full configuration over your active one.

## Verify locally

```bash
./scripts/validate.sh
```

The runner uses temporary state, fake providers and private D-Bus sessions.
Native offscreen tests run when Quickshell is available. The report identifies
skipped prerequisites. A passing fixture is not proof of real-device delivery,
an offsite VPN, a mapped desktop or assistive-technology acceptance.

Contributors: start with [CONTRIBUTING.md](CONTRIBUTING.md) and the
[icon source/storage guide](docs/ICONS.md).

See [contextual help coverage](docs/HELP.md) for guidance and documentation links.

Read the [current product/spec addendum](docs/2026-10-29-product-addendum.md) for
native KDE features, all three network services and user-success acceptance.

See [verification evidence](docs/VERIFICATION.md), [implementation scope](docs/IMPLEMENTATION.md),
[provider contracts](docs/CONTRACTS.md) and [upstream lineage](FORK.md).
The [original README](docs/UPSTREAM-README.md) is retained as historical reference;
its installation and capability claims apply to the upstream version.

## Privacy and limits

Appearance and address metadata are owner-only. Imported images are copied into
private asset storage; originals remain unchanged. Corrupt or unsupported metadata
blocks changes. Activity stores at most 50 summaries in memory, without raw paths.
The KDE CLI requires a path argument, which can appear in process metadata. Its
later file open leaves a race after the final source check. The UI does not claim
an atomic file handoff or an end-to-end delivery receipt.

MIT license. Preserve upstream and reused Bananet notices. See `LICENSE` and the
notice in `BthControlCard.qml`.

## Help, contributions and reporting

Contributions are welcome: code, documentation, design, accessibility and device
checks. Start with [CONTRIBUTING.md](CONTRIBUTING.md). Use the
[issue chooser](https://github.com/ryan-winkler/omaconnect-kde-plus/issues/new/choose)
for defects, ideas and questions, or read [SUPPORT.md](SUPPORT.md).
Report vulnerabilities privately through [SECURITY.md](SECURITY.md).
See the [code of conduct](CODE_OF_CONDUCT.md), [review checks](docs/contributor-release-plan.md)
and [50-persona/red-team review](docs/release-personas-red-blue.md).
