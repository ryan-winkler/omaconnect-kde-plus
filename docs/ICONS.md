# Icons: where choices come from and where they are saved

## User choices

| Choice | Source read by the fork | Saved value |
| --- | --- | --- |
| Built-in preset | `Appearance.js` catalog: Phone, Desktop, Laptop, Link, Share | `mode: preset` and its stable ID |
| Installed icon | The active Qt/freedesktop icon theme via `Quickshell.iconPath()` | `mode: theme` and the icon name |
| Custom symbol | Text rendered by an installed font | `mode: glyph`, value and optional font family |
| Local image | A validated copied PNG/SVG | `mode: image`, content-hash filename and rendering preference |
| Automatic | Selected device's override/type, or device type for a device override | `mode: automatic` or device `inherit` |

The light/dark samples are previews of the same draft. Selecting a choice changes
the draft. Apply saves it; Cancel leaves the stored choice unchanged.

## Source and rendering path

`IconChooser.qml` → `AppearanceStore.qml` → `scripts/appearance.py` writes local
metadata. The bar and device rows call the same pure resolver in `Appearance.js`.
`components/AppearanceIcon.qml` paints the resolved choice. Native Omarchy
`qs.Ui` supplies the reusable chooser controls; the fork retains its own small
appearance dialog and validation boundary.

Preset IDs, labels, suggested theme names and fallback glyphs are declared near
the top of **`Appearance.js`**. Presets use an available theme icon, then their
own fallback glyph. A missing arbitrary theme/icon/image never silently becomes
a claim about device type or reachability. The renderer exposes a fallback warning.
The bar's icon is presentation, not a trust, pairing, VPN or transfer indicator.

Installed names are inventory candidates. The helper searches XDG data icon roots,
the legacy user icon directory and `/usr/share/pixmaps`. It keeps at most 1,024
names and 30,000 visited entries, prioritizes required preset names, and reports
truncation. QML then keeps names resolvable by **the active Qt theme**. A file in
another installed theme is not proof that Qt can resolve its name. The list is
not a complete index of every theme. Use the exact-name field or a local image
when a desired choice is omitted. The full lookup/inheritance contract follows
the [freedesktop icon theme specification](https://specifications.freedesktop.org/icon-theme/latest/)
and [Qt QIcon lookup](https://doc.qt.io/qt-6/qicon.html#fromTheme).

The native Omarchy image picker is a general image-directory overlay, not an icon
bank; its current file list also includes video and omits SVG. The emoji overlay
inserts text into another app. Neither is used as a direct replacement for this
private draft/import flow. See [source audit](icon-audit.md) for inspected evidence.

## User storage

| Data | Default path | Environment override |
| --- | --- | --- |
| Bar icon, device icons, aliases and explicit Syncthing links | `~/.config/ryan.omaconnect/appearance.json` | `$XDG_CONFIG_HOME/ryan.omaconnect/appearance.json` |
| Imported asset copies | `~/.local/share/ryan.omaconnect/icons/<sha256>.png` or `.svg` | `$XDG_DATA_HOME/ryan.omaconnect/icons/` |
| Saved private addresses, a separate domain | `~/.local/share/ryan.omaconnect/addresses.json` | `$XDG_DATA_HOME/ryan.omaconnect/addresses.json` |

Metadata schema is version 1. Device keys use `kdeconnect:<stable KDE ID>`.
Aliases and appearance do not change the underlying provider ID. Files are 0600;
owned directories are 0700. Updates lock, read/merge and atomically replace.
Unsupported/corrupt state is preserved and blocks changes. Do not repair it by
silently resetting or copying another user's file.

Imported originals stay in place. The helper inspects actual content, enforces
1 MiB / 512×512 limits, rejects active/external/animated content, and copies the
approved image under a content hash. The renderer uses the private approved copy.
Do not commit these user files or hardcode a machine's absolute asset path.

## Add a preset

1. Add its stable ID, readable label, theme name and distinct glyph to
   `Appearance.js`. Use a glyph supported by Omarchy's installed symbol font.
2. Add the ID to the independent persistence allowlist `PRESETS` in
   `scripts/appearance.py`. Add the theme name to `PRESET_THEME_NAMES` so a full
   inventory cannot crowd it out.
3. Run `python3 -m unittest -q tests/test_icon_catalog.py` and the normal validation
   command. The parity check prevents UI/save drift; do not hardcode a total count.
4. Check distinct appearance with the theme icon present and absent, at bar size,
   on light/dark surfaces. Test the actual font/theme on each claimed host.
5. Document provenance/license and update this table if a new source is introduced.

The UI normalization and helper allowlist are separate trust boundaries. A small
parity check is deliberate; do not replace independent input validation with a
runtime code generator just to remove two short lists.
