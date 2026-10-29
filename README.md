# Omaconnect KDE Plus

An Omarchy bar UI fork of [Jitendra Dara’s OmaConnect](https://github.com/jitendradara12/omaconnect), built on [KDE Connect](https://kdeconnect.kde.org/).

Jitendra’s plugin and KDE Connect are the upstream foundations. We retain their
credit, follow their interfaces, and aim to contribute reusable fixes back.
This is an independent community fork. See [lineage and licenses](FORK.md).

**Current plugin ID: `Omaconnect.plus`.** The display name remains Omaconnect KDE Plus. The earlier `v0.1.0` publication used the previous development ID; the identity update needs its own release and installed-runtime receipts. See [verification](docs/VERIFICATION.md).

**Version 0.2.0 candidate.** The fork adds one place for known devices,
file submission, appearance and network access through **Tailscale, MikroTik Back
to Home, or WireGuard**. KDE Connect owns pairing and transfers. Existing native
network tools retain connection ownership; the BTH helper retains its policy.

![Native settings with invented sample device data](preview.png)

[Earlier release 0.1.0](https://github.com/ryan-winkler/omaconnect-kde-plus/releases/tag/v0.1.0) ·
[Functional checks](https://github.com/ryan-winkler/omaconnect-kde-plus/actions/workflows/validate.yml) ·
[CodeQL](https://github.com/ryan-winkler/omaconnect-kde-plus/actions/workflows/codeql.yml) ·
[Marketplace submission](https://github.com/omacom/omarchy-plugin-marketplace/issues/13289)

Marketplace submission is pending maintainer review. It is not a listing or a
security certification. Use the repository install command below in the meantime.

## Why Plus?

OmaConnect already provides pairing, battery, clipboard, SMS, media and remote commands. Plus builds on those features; KDE Connect remains the engine.

| If you need… | Plus adds… |
| --- | --- |
| Your own bar/device appearance | Searchable icon choices, local images, aliases and preview before Apply. |
| A normal file workflow | Desktop file chooser, bounded multiselect, file-manager Copy drops and explicit recipient/file review. |
| Shortcuts that match your tasks | Add/remove/reorder controls; Ring is optional. |
| Clear settings and all native features | Four domain pages, nearby help, searchable native inventory and selected-device KDE settings links. |
| Existing remote-access choices | Separate Tailscale/BTH/WireGuard opt-ins and owner routes; existing BTH policy controls. |
| Honest results and safe route hints | Accepted-versus-delivered state, private per-device addresses and reviewed rediscovery/removal. |

Read the [source-verified feature matrix and decision](docs/WHY-PLUS.md) for the exact comparison with upstream 1.5.0, inherited features and limits. Keep upstream OmaConnect if its workflow meets your needs.

## First release

- **Settings:** Choose visible sections and which ones start expanded. Open a dedicated native window for Appearance, Connections,
  Quick actions and Device features. All active Plus preferences have a domain; native
  plugin enablement and permissions link to the selected device in KDE Connect.
- **Quick actions:** Add, remove and reorder 18 reviewed shortcuts in Settings, including media transport and explicit native KDE routes. Ring
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
  manager, or drop onto the Plus bar icon to open review. Drops accept Copy and preserve originals.
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
- **Syncthing identity notes:** Optionally remember that two full device IDs refer to the same machine. The section starts hidden and is configurable. Drafts stay with their reviewed KDE peer; saved readback confirms changes. Open the general existing Syncshell panel for folders/status. Syncshell retains its own core and keys.

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
Media shows track text and player controls. Plus does not render or fetch provider-supplied album-art URLs.

## Requirements

Omarchy’s Quickshell UI, KDE Connect, Python 3 with PyGObject/Gio, a desktop file
portal, and the existing system tools used by Omarchy. Node is for tests only.
Optional home-access controls require the existing `remote-access-mode` helper.
Its absolute path is configurable in plugin settings; an empty setting uses
`~/.local/bin/remote-access-mode`. Syncthing opening requires the existing
`io.github.ilyazar.syncthing` plugin. Missing optional providers remain unavailable.

This branch uses the case-sensitive plugin ID `Omaconnect.plus`. It can be staged separately from
`omaconnect`. **No installation or activation occurs from the tests or checkout.**
Read [migration and recovery](docs/MIGRATION.md) before moving existing settings or upgrading an earlier fork identity.

## Install and open

Requirements: an existing Omarchy shell, `kdeconnect`, `python`, `python-gobject`
and a working desktop file portal. Omarchy supplies Quickshell and its UI kit.
1. **Prerequisites:** install missing packages through the supported package command:

```bash
omarchy pkg add kdeconnect python python-gobject
```

2. **Install the plugin:** run one native command:

```bash
omarchy plugin add https://github.com/ryan-winkler/omaconnect-kde-plus.git --enable
```

3. **First use:** open the new bar icon and select a device.

The native installer asks for approval and bar placement. It reads the root
manifest; it does not run a repository install script. Open the new bar icon,
select **All KDE Connect features** and pair your device in native KDE Connect.
Open **Settings** for appearance, connections, quick actions and device features.
Use the [task guide](docs/HELP.md) for each control and its owner documentation.

This is a Git-native Omarchy plugin: the root `manifest.json` is the package contract. No build step, custom installer, dependency downloader, Python virtual environment or AUR package is required. See [packaging and installation](docs/PACKAGING.md).

If you use the original OmaConnect, keep it for comparison or disable its UI after
review: `omarchy plugin disable omaconnect`. Pairings stay in KDE Connect. Read
[migration and recovery](docs/MIGRATION.md) before moving existing display settings.


If a firewall blocks discovery, use its owner tool to allow KDE Connect ports
**1714–1764 TCP and UDP** for the intended trusted network. Read the
[official troubleshooting guide](https://userbase.kde.org/KDEConnect/en#Troubleshooting).
Plus does not change firewall policy.

## Update, disable and remove

These commands apply after `Omaconnect.plus` is installed. If you have an earlier Plus identity, follow [migration](docs/MIGRATION.md) first; updating its old checkout does not register the new ID.

```bash
omarchy plugin update Omaconnect.plus
omarchy plugin disable Omaconnect.plus
omarchy plugin remove Omaconnect.plus
```

Use **enable**, **disable** or **remove** only for the action you want. Removal
uses Omarchy’s confirmation flow. It does not remove KDE pairings, providers or
private Plus metadata. Appearance assets and approved-address records stay under
`~/.config/Omaconnect.plus/` and `~/.local/share/Omaconnect.plus/`
unless you explicitly remove them. Shared-source cache copies also remain after
removal; they become eligible after 24 hours; cleanup is attempted on later
preparation when the cache is safe and available. See [cache retention](docs/HELP.md#send-files-and-read-activity).
Wait for native transfers to finish before explicitly removing that cache.
XDG overrides are supported. See the
[icon storage guide](docs/ICONS.md) for exact paths and backup scope.

For rollback, disable `Omaconnect.plus` and re-enable the source plugin by its recorded ID if still installed.
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
blocks changes. Activity stores at most 50 summaries in memory, without raw paths. Typed text and custom Ping content use stdin and native D-Bus, keeping content out of process arguments.
The KDE CLI requires a path argument, which can appear in process metadata. Files in shared locations use a private snapshot from the validated descriptor;
protected private files retain the native path flow. Copies become eligible after
24 hours. Cleanup is attempted later when the cache is safe and available. See [retention and storage](docs/HELP.md#send-files-and-read-activity).
Same-user programs and root remain trusted. The UI does not claim a native atomic
descriptor handoff or an end-to-end delivery receipt.

MIT license. Preserve upstream and reused Bananet notices. See `LICENSE` and the
notice in `BthControlCard.qml`.

## Help, contributions and reporting

Contributions are welcome: code, documentation, design, accessibility and device
checks. Start with [CONTRIBUTING.md](CONTRIBUTING.md). Use the
[issue chooser](https://github.com/ryan-winkler/omaconnect-kde-plus/issues/new/choose)
for defects, ideas and questions, or read [SUPPORT.md](SUPPORT.md).
Use [Discussions](https://github.com/ryan-winkler/omaconnect-kde-plus/discussions)
for Q&A and ideas. The [feedback form](https://github.com/ryan-winkler/omaconnect-kde-plus/issues/new?template=feedback.yml)
asks which task was hard and what would help. Share a sanitized example; omit keys,
private addresses and device identifiers.

The [upstream review](docs/UPSTREAM-REVIEW.md) records the original project's open
and closed work. The [daily upstream watcher](docs/UPSTREAM-WATCH.md) tracks KDE
Connect desktop, KDE Connect Android and original OmaConnect in one review issue.
It does not execute upstream code or merge updates. Dependabot opens dependency
and security update PRs; maintainers review application changes.
Report vulnerabilities privately through [SECURITY.md](SECURITY.md).
See the [code of conduct](CODE_OF_CONDUCT.md), [review checks](docs/contributor-release-plan.md)
and [50-persona/red-team review](docs/release-personas-red-blue.md).
