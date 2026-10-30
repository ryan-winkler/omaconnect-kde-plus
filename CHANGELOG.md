# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- An optional Quick Share shortcut opens an installed RQuickShare app.
- Linked Syncthing devices show their last checked pause state, with explicit
  refresh and pause/resume controls. Changes wait for Syncthing readback.

### Changed

- Daily navigation uses a compact View menu and settings icon. Place it at Top
  or Bottom, with optional direct Send and Activity shortcuts. All routes remain
  available, and draft and submission reminders stay visible.

- Trimmed the docs to user and contributor guides; install, update and
  migration now live in `docs/INSTALL.md`.

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
