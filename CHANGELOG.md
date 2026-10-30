# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Security

- Plus now also tries to remove private copies of shared files at plugin start,
  not only before a later send. Copies become eligible after 24 hours.
- File paths go to KDE Connect over D-Bus, no longer in `kdeconnect-cli`
  arguments that other local accounts can list.
- The README now says that a saved default Ping message passes through process
  arguments.

## [0.1.3] - 2026-10-30

### Fixed

- Use the lowercase machine ID `omaconnect.plus` required by the Community
  marketplace. The display name remains Omaconnect KDE Plus.
- Preserve existing uppercase private-data paths. Explicit former Plus migration
  stages all understood settings, positions and enablement without resetting
  icons or changing original OmaConnect. Native updates alone do not rename IDs.

## [0.1.2] - 2026-10-30

### Added

- A shared daily device picker, inline reviewed file drop, and settings to move
  every daily section up or down. Sections can collapse and have saved display
  defaults. Native features and saved addresses can be hidden without data loss.
- An optional Quick Share shortcut opens an installed RQuickShare app.
- Linked Syncthing devices show their last checked pause state, with explicit
  refresh and pause/resume controls. Changes wait for Syncthing readback.

### Changed

- Device settings lists every installed KDE Connect module, with native On/Off
  readback, offline support, search and exact-module Configure links. Information
  and occasional actions expand on demand. Native KDE Connect retains ownership
  of configuration forms and phone permissions.
- Installed icons have searchable thumbnails. Symbolic icons render with the
  software scene graph and follow the current theme. Full-colour installed artwork
  keeps its native colours and internal detail; custom image colours remain
  an explicit choice. Installed icons also support a custom foreground tint,
  including names without a symbolic suffix. Appearance uses one current-theme preview.
- The string-sharing shortcut is labelled Text and uses less toolbar space.

- Settings has a persistent Device dropdown, with shared selection, text states
  for offline and unpaired devices, keyboard control and native launch feedback.
- Device gears open the selected device's Plus settings. The explicit Native
  KDE Connect settings link opens the full native settings application.
- Device Information now includes native addresses and connection providers.
  Feature names come from installed KDE metadata, with unknown IDs preserved.
  A native external-monitor action exposes observed availability and Start/Stop.
- Device features discovers installed native configuration pages and opens the
  exact module for the selected device. Run commands configuration now states
  which computer runs the commands; older frontends have an explicit fallback.
  A separate request can open a compatible peer's command editor without running
  a command. Keyboard focus now scrolls into view in every Settings page.
  Settings buttons and checkboxes support assistive-technology activation.
  Native launch feedback uses readable theme foreground text.
- Daily navigation uses a compact View menu and settings icon. Place it at Top
  or Bottom, with optional direct Send and Activity shortcuts. All routes remain
  available, and draft and submission reminders stay visible.

- Trimmed the docs to user and contributor guides; install, update and
  migration now live in `docs/INSTALL.md`.
- Settings and panel help use plain words, one sentence per control, at a
  larger text size. Longer caveats moved to the help guide.
- Each settings switch shows **On** or **Off** below its name.
- Each section's show and start-expanded switches now sit on the settings page
  for that section: network controls and saved addresses on Connections, media
  and remote commands on Device features.
- When KDE Connect is missing, Devices shows the install command to copy.
- Media player choices and transport controls support keyboard and accessible activation.

### Security

- A pairing response checks the device ID before it builds a D-Bus path.
- Discovery, media status and saved addresses are read as structured D-Bus
  data. Device names and media metadata stay plain text.

## [0.1.1] - 2026-10-29

### Changed

- The plugin ID is now `Omaconnect.plus` and stays fixed from this release on.
  Installs of the 0.1.0 development ID need a fresh install.
- Settings let you hide optional sections and choose which start collapsed.
- Quick actions come from one catalogue of 18 shortcuts with readiness checks.
- Bar-icon drops and the Send window share one copy-only review.

### Added

- Optional Syncthing identity note with a link to the existing Syncshell panel.
- Daily upstream watcher for OmaConnect and KDE Connect.

### Security

- Typed text and Ping messages use stdin and D-Bus instead of process arguments.
- Files in shared locations are sent from a private snapshot.
- Activity is plain text, and provider album art is no longer fetched.
- Removed the in-panel dependency and firewall setup launchers.

## [0.1.0] - 2026-10-29

### Added

- First release of the fork: Settings window by domain, icon and alias chooser,
  configurable quick actions, native feature search, file chooser with review,
  drop review, honest transfer activity, optional network sections and help
  next to each control.

[Unreleased]: https://github.com/ryan-winkler/omaconnect-kde-plus/compare/v0.1.3...main
[0.1.3]: https://github.com/ryan-winkler/omaconnect-kde-plus/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/ryan-winkler/omaconnect-kde-plus/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/ryan-winkler/omaconnect-kde-plus/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/ryan-winkler/omaconnect-kde-plus/releases/tag/v0.1.0
