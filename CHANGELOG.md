# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.5] - 2026-11-07

### Added

- Optional **Review saved screenshot** Quick action. Choose a `.png` file in
  the desktop picker and review its filename and recipient before sending.
  Screenshot review also applies when ordinary file selection sends immediately.
  The help gallery shows review and the Activity result.

- Daily views, Settings, file choosers and Plus feedback use Omarchy's live
  language catalogue. Shared controls use Omarchy translations when Plus has no
  matching entry. Arabic, German, French, Mexican Spanish and Portuguese include
  partial Plus translations. Other missing Plus copy uses English. Right-to-left reading
  order applies to the Send, Settings and image preview windows.

- Optional desktop entry for the Plus panel, Send files and Activity.

- File-type icons in the recent-file menu and an Image previews entry for the
  image preview window with the recipient, filename, Back and Cancel.
  Browsing never sends. Explicit Send image or Review image follows the captured
  preference; Back keeps that preference and recipient. Other files stay in the
  searchable list.
- Edit layout on the actual Devices sections, with direct visibility and position
  menus. Show, Hide and available/unavailable rules replace the detached ordering
  list. Hidden sections remain recoverable while editing; drafts stay intact.
- Browse native phone shares in the default file manager. A single advertised
  folder opens directly; several folders show a choice. Device and mount identity
  are rechecked before opening.

- Native desktop notices report final Plus file-request outcomes while the
  popup, Send window and image preview are closed. Device names are excluded by default;
  an explicit sharing preference adds them to notices and desktop history.
  The Activity action opens current activity without repeating a request.
- The desktop chooser and review are on by default. Check the files and
  recipient before you select **Send files**. Quick actions keeps separate controls
  for the Omarchy recent-file menu and direct submission. The chooser setting
  explains who may see the recent menu’s process arguments. Drops always require
  review.
- A Cancel pending files control stays available across daily views and collapsed
  sections. Cancellation stops the Plus queue and active helper. Accepted LAN
  uploads use KDE Connect’s native progress Cancel; Bluetooth and per-transfer
  native cancellation remain outside the public sharing API.

### Changed

- Activity and Recent submissions show a submission number and update time.
  Only devices with the same name in the history show an ID suffix.
- Device details now include the device information: battery, cellular state,
  ID, addresses, connection providers and Pair or Unpair. Unreported rows are
  hidden. The separate Device information section is gone, and saved section
  orders that name it still load.
- Inline help paragraphs moved to the help guide, heading descriptions and empty
  states. The Native KDE Connect section no longer repeats the device settings
  button.

- Keep the selected device and unsent drafts when the device list updates.
- Open native KDE Connect for pairing and verification. Plus reports when
  it can read only part of the KDE Connect device list.

### Fixed

- Preview images in locations protected from other local accounts. Use the
  desktop chooser for images in shared writable folders. Plus asks for a new
  selection if the file changes during preview.
- Keep saved addresses out of local process arguments during editor writes.
- Activity explains what to check before sending a missing file again.
- Explain why the device dropdown closes when its list changes.
- Keep daily actions for paired, connected devices when KDE Connect cannot read
  every device. Open native KDE Connect directly when the device list is empty.

- Keep File sharing collapsed when the Browse phone files shortcut opens a
  single shared folder. Use the same shortcut to cancel while it runs.
- Disable stale device actions when KDE Connect loses or changes its bus name.
  A read-only scan restores the selected device when it returns. Interrupted
  actions remain unconfirmed.
- Let Browse phone files wait briefly for the verified SSHFS mount after
  KDE Connect reports a successful mount. A cancelled or stale request
  still opens nothing.
- Explain when KDE Connect reports phone storage as unmounted after Prepare.
  Offer native file settings and a manual retry.

- Retained hidden preference toggles ignore Return, Enter and Space without
  interrupting saves accepted before their window closed.
- Retained hidden composer actions cannot send drafts. Closed popups and layout
  editing block submission; collapsing remote commands returns Refresh focus to
  its header and blocks stale activation.
- Active Plus actions expose named accessible buttons and guarded Press actions,
  including Activity, composers, Syncthing, home-access modes and the bar icon.
- Layout menu selections use native popup colors so muted theme accents do not
  reduce the contrast of selected text.
- Settings navigation responds to the accessibility Toggle action exposed by
  its native radio-button role.
- The persistent Send window exposes Back and Choose files as named accessible
  button actions. Disabled Choose files cannot dispatch through accessibility.
- Opted-in task notices keep complete Unicode characters when a long device name
  reaches the display limit.
- Phone-file browsing rechecks current KDE Connect ownership and peer state after
  slow storage probes, before requesting the file-manager handoff.
- Layout saves use the structured helper result, so a valid success message
  cannot release the pending readback guard before settings are confirmed.

- The recent-file menu finds files when the conventional user folders link to
  moved storage. Links inside those folders remain excluded.
- Native direct-socket IPC registration preserves existing Plus routes and adds
  a safe Activity action for notification history.
- Managed Settings, Send and image-preview windows follow live native text direction. Settings
  width no longer feeds back through mirrored row positioning.
- Task-notice suppression tracks all visible popup, Send and image-preview instances instead
  of treating one closed window as every window being closed.

- Address automatic-discovery requests consistently apply the validated false
  default when the optional field is absent.
- Unsupported URL drags no longer receive accepted file-hover feedback.
- Provider contracts describe actual D-Bus deadlines, discovery timeouts, section
  normalization and request schemas.

- Bar and device icons are sharp and centred on HiDPI screens. Presets use their
  symbol-font glyph, as the original OmaConnect does, and symbolic theme icons
  are tinted at full size.
- Settings and device actions have button frames. Unpair uses the theme's urgent
  colour, and section headings use muted capitals.
- The device switcher uses the theme's chevron and hover fill.
- The bar icon picker lists symbolic icons first.
- Only Devices and Quick actions start expanded, so the panel opens shorter.

## [0.1.4] - 2026-10-30

### Fixed

- Refresh and automatic rediscovery ask KDE Connect to search the network.
- Remote command rows support keyboard and assistive-technology activation.
- Saved-address input clears only after readback confirms the save.
- Network guidance separates Tailscale/WireGuard provider links from requests to
  the existing Back to Home helper. Plus does not ship that helper.
- Discovery, the command list and media status read at most 64 KiB per reply.
  Each read stops at a deadline, and a provider that ignores the stop request is
  killed, so a stuck provider cannot hang the panel. The command list keeps at
  most 100 commands.

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

[Unreleased]: https://github.com/ryan-winkler/omaconnect-kde-plus/compare/v0.1.5...main
[0.1.5]: https://github.com/ryan-winkler/omaconnect-kde-plus/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/ryan-winkler/omaconnect-kde-plus/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/ryan-winkler/omaconnect-kde-plus/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/ryan-winkler/omaconnect-kde-plus/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/ryan-winkler/omaconnect-kde-plus/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/ryan-winkler/omaconnect-kde-plus/releases/tag/v0.1.0
