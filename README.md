# OmaConnect Plus

An isolated Omarchy UI fork of [Jitendra Dara’s OmaConnect](https://github.com/jitendradara12/omaconnect).

**Candidate version: 0.1.0-alpha.1.** The fork adds one place for known devices,
file submission, appearance and the existing home-access controller. KDE Connect
owns pairing and transfers. Your existing BTH helper owns VPN policy.

## First release

- **Appearance:** Choose a phone, computer, theme icon, custom symbol or local
  PNG/SVG for the bar. Set a separate icon and local alias for each KDE identity.
  Preview before Apply. Reset to Phone or follow the selected device.
- **Files:** Use the desktop portal to select up to 100 regular files, with a
  combined maximum of 1 TiB. Check the recipient, count and size, then select
  Send. Selection alone sends nothing. Directories are not archived.
- **Honest activity:** Each batch keeps its reviewed recipient. Changing the
  selected device does not redirect it. “Request accepted” means KDE accepted
  the command; delivery remains unknown. Timeout and cancellation remain explicit.
- **Home access:** View the existing helper’s Automatic / On / Off controls.
  Selected mode and actual interface state are separate. Missing or invalid
  status disables unsafe actions. No VPN keys or profiles are imported.
- **Private addresses:** Approve private IP literals for a specific KDE identity.
  Preserve existing KDE addresses. Opt in to rediscovery while the panel is open;
  route events are debounced and failures back off. An IP does not prove identity.
- **Syncthing links:** Explicitly associate two full device IDs in local metadata
  and open the existing Syncshell panel. Syncshell retains its own core and keys.

Quick Share, router rosters, new VPN setup and inline Syncthing pause/resume are
later work. This fork does not implement the separate Banatik/UniFi collector.

Existing pairing, battery, media playback and player switching, remote commands,
clipboard, text and SMS entry points remain available through KDE Connect.

## Requirements

Omarchy’s Quickshell UI, KDE Connect, Python 3 with PyGObject/Gio, a desktop file
portal, and the existing system tools used by Omarchy. Node is for tests only.
Optional home-access controls require the existing `remote-access-mode` helper.
Its absolute path is configurable in plugin settings; an empty setting uses
`~/.local/bin/remote-access-mode`. Syncthing opening requires the existing
`io.github.ilyazar.syncthing` plugin. Missing optional providers remain unavailable.

This branch uses plugin ID `ryan.omaconnect`. It can be staged separately from
`omaconnect`. **No installation or activation occurs from the tests or checkout.**
Read [migration and recovery](docs/MIGRATION.md) before an eventual activation.

## Verify the candidate

```bash
./scripts/validate.sh
```

The runner uses temporary state, fake providers and private D-Bus sessions.
Native offscreen tests run when Quickshell is available. The report identifies
skipped prerequisites. A passing fixture is not proof of real-device delivery,
an offsite VPN, a mapped desktop or assistive-technology acceptance.

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
