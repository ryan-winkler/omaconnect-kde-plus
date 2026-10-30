# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

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

[Unreleased]: https://github.com/ryan-winkler/omaconnect-kde-plus/compare/v0.1.1...main
[0.1.1]: https://github.com/ryan-winkler/omaconnect-kde-plus/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/ryan-winkler/omaconnect-kde-plus/releases/tag/v0.1.0
