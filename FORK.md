# Omaconnect KDE Plus: upstream and ownership

This is a UI fork of [Jitendra Dara’s OmaConnect](https://github.com/jitendradara12/omaconnect).
It starts from OmaConnect 1.5.0 at `71282d2042b1a1cda1cb1cac84251694eaabb7cb`.
The original MIT license and copyright remain in [LICENSE](LICENSE).
The [original README](docs/UPSTREAM-README.md) is kept as a historical reference.

- Fork: [ryan-winkler/omaconnect-kde-plus](https://github.com/ryan-winkler/omaconnect-kde-plus).
- Stable plugin identity: `ryan.omaconnect`. The upstream identity is `omaconnect`.
- [KDE Connect](https://kdeconnect.kde.org/) owns pairing, its native modules,
  permissions and the device protocol. It is a separate upstream dependency,
  licensed under its own terms. This repository does not copy its settings UI.
- The optional existing BTH helper owns VPN policy. The BTH card retains the
  [Bananet](https://plugins.omarchy.org/plugin.html?id=banan.bananet) attribution
  and license notice in [BthControlCard.qml](BthControlCard.qml).
- [Omarchy](https://omarchy.org/) supplies the shell and native UI controls.
  Syncshell owns synchronization. This fork adds no second protocol daemon,
  UniFi collector, VPN provisioner or Syncthing core.

Keep reusable fixes small enough to propose to Jitendra’s upstream or the owning
provider. Check both upstreams before adding protocol work here. Preserve authors
and licenses when adapting changes. Do not represent this fork as an official
KDE or Omarchy project.

Normal migration replaces the original UI after review. Separate IDs permit an
explicit side-by-side comparison, as used during development; both use the same
existing KDE daemon and pairings. See [migration and recovery](docs/MIGRATION.md).
