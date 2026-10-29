# Icon chooser audit

Date: 29 October 2026. This note separates the source snapshot before the UX
correction, local runtime evidence and the implemented correction. It does not
claim a mapped desktop or assistive-technology acceptance result. No installed
source, host setting or real device was changed by this audit.

## Observed causes before the correction

| Finding | Evidence in the source snapshot | User effect |
| --- | --- | --- |
| The actual choices were hidden in Automatic/inherit. | `IconChooser.prepare()` mapped those modes to index 0. Both search and the list required index 1 or 2. A fresh bar's Phone preset was index 1, so this did not affect every opening. | A device without an override, or a migrated automatic bar, could show only the two preview swatches. |
| Two copies of the selected icon resembled two options. | The Light/Dark repeater displayed `resolvedDraft` twice. Neither swatch selected a different icon. | Two identical phone previews could be mistaken for the entire catalogue. |
| Preset fallback discarded the intended identity. | `Appearance.js` had five nonempty glyph values. `AppearanceIcon` used glyphs only for `mode: glyph`; a failed theme lookup drew the same built-in Phone for every preset. | Theme availability could make Laptop, Desktop, Link and Share look alike. |
| Browsing changed the draft and could hide the list. | The storage-mode ComboBox reset Preset/Theme to Phone. `choose(glyph)` changed the mode to 3, hiding the list. It did not synchronize the symbol field. | A navigation action could replace a choice or remove the list from view. |
| The bounded inventory omitted available names. | Local `appearance.py library` returned 1,024 names. `smartphone-symbolic` and `laptop-symbolic` were absent, although the explicit-path Qt probe resolved both in Yaru-blue. The cap preceded Qt's active-theme filter. | An installed icon could be unavailable in the browsable results. |

The Antigravity review described the preset glyph values as empty. Direct source
inspection disproved that detail. The values existed; the renderer did not use
them for presets. The independent Claude review correctly identified that path.

## Native Omarchy reuse

The inspected installed public `qs.Ui/qmldir` exports `Button`, `ButtonGroup`,
`Dropdown`, `SearchableDropdown`, `TextField`, `FilterInput`, `CursorSurface` and
`OpticalGlyph`. It does not export an `IconPicker`. A source search of the installed
Ui, plugins and command scripts found no dedicated general icon-return picker.

| Existing component | Verified contract | Fit for this task |
| --- | --- | --- |
| `qs.Ui.SearchableDropdown` | Strings or `{value,label,description}`; `changed(value)`; search-first popup; native keyboard/focus handling. Its option delegates display text, not icon components. | Reuse directly for installed names, with the selected icon's existing preview. |
| `qs.Ui.Button` in `Flow` | Label, glyph, selected/focus styling, explicit `clicked()` and keyboard activation. | Reuse for five visible labelled presets. Flow wraps at narrow widths. |
| `qs.Ui.ButtonGroup` | Single Tab stop and left/right navigation; fixed Row layout. | Useful for short groups. Five labelled icons can overflow a narrow panel; do not force this layout without a width check. |
| `qs.Ui.OpticalGlyph` | Tight glyph bounds, scale-to-size and native font rendering. | Reuse for installed Nerd Font fallbacks instead of custom centering. |
| `omarchy.image-picker` | Overlay accepts image directories or rows and returns via selection/done files. Its normal directory helper lists PNG/JPEG/GIF/etc. and videos, but not SVG. | Possible external image workflow, with more IPC/lifecycle work. It is not an embeddable icon-return control. Manually supplied rows would still need the fork's validation. |
| `omarchy.emojis` | Selection calls `omarchy-menu-emoji-insert`; that command temporarily copies text and sends Shift+Insert to the focused app. | An input utility, not a metadata-return callback. Do not invoke it to replace this chooser. |

Installed primary sources inspected:

- `/usr/share/omarchy/shell/Ui/qmldir`, lines 3–41.
- `/usr/share/omarchy/shell/Ui/SearchableDropdown.qml`, interface comments and
  `options`, `value`, `changed`, keyboard handlers and text delegates.
- `/usr/share/omarchy/shell/Ui/Button.qml`, `ButtonGroup.qml` and `OpticalGlyph.qml`.
- `/usr/share/omarchy/shell/plugins/image-picker/ImagePicker.qml`, `open(payload)`
  and `applySelected()`; its `list.sh`, lines 91–98.
- `/usr/share/omarchy/shell/plugins/emojis/Emojis.qml`, `applySelected()`;
  `/usr/share/omarchy/bin/omarchy-menu-emoji-insert`.

These are read-only references. No native component was copied into or changed by
the fork. The existing kit components are imported through `qs.Ui`.

## Local runtime evidence and its limits

Local packages reported Omarchy `4.0.0.r7412.g4872b40-1`, Quickshell
`0.3.2.r7.g2b4501a-5`, Qt base `6.12.0-3`, Qt SVG `6.12.0-1`, Yaru icons
`26.10.3-3`, Adwaita icons `51.0-1` and JetBrainsMono Nerd Font basic `3.5.1-2`.
Read-only GSettings reported `Yaru-blue` for the GTK icon theme.

A temporary C++ probe used the installed Qt libraries and created **no QWindow or
QQuickWindow**. It performed theme lookup and decoded each icon at 24 px. With
explicit installed icon search paths, it reported:

| Theme | Phone | Desktop | Laptop | Link | Share |
| --- | --- | --- | --- | --- | --- |
| Yaru-blue | Found/decoded | Found/decoded | Found/decoded | Found/decoded | Found/decoded |
| Adwaita | Missing | Found/decoded | Missing | Found/decoded | Found/decoded |
| candy-icons | Found/decoded | Found/decoded | Missing | Found/decoded | Found/decoded |
| breeze-dark | Found/decoded | Found/decoded | Missing | Found/decoded | Found/decoded |

The names tested were `smartphone-symbolic`, `computer-symbolic`,
`laptop-symbolic`, `insert-link-symbolic` and `document-send-symbolic`.

The same offscreen process initially had an empty theme name and only `:/icons`
in `QIcon::themeSearchPaths()`. Every lookup failed until the probe supplied
installed search paths. Therefore, an isolated fixture that copies shell colours
without the session's Qt theme context cannot prove live icon availability.
The matrix is a controlled local lookup result, not a claim about another host's
mapped shell. Qt documents theme lookup, search paths and fallback behavior in its
[QIcon API](https://doc.qt.io/qt-6/qicon.html).

## Preset provenance

The five fallback characters are Nerd Fonts Material Design mappings. The official
[Nerd Fonts glyph map](https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/glyphnames.json)
was checked during this audit:

| Preset | Fallback code point | Official map key |
| --- | --- | --- |
| Phone | U+F011C | `md-cellphone` |
| Desktop | U+F0379 | `md-monitor` |
| Laptop | U+F0322 | `md-laptop` |
| Link | U+F0337 | `md-link` |
| Share | U+F0497 | `md-share_variant` |

The old Share value was U+F04AA (`md-sitemap`). The correction changes it to
U+F0497. System theme icons remain runtime resources owned by their installed
packages. The built-in final Phone fallback is QML geometry. User symbols use
installed fonts; imported images come from the user's explicit local selection.
This change adds no downloaded or vendored icon pack. See the contributor icon
contract for source and licence checks before any future asset vendoring.

## Implemented correction

The chooser retains its schema 1 and existing store APIs. It now:

- Shows Automatic and five labelled native preset buttons on every opening.
- Uses native `SearchableDropdown` without a storage-mode selector.
- Keeps browsing and choice state separate. Opening search does not replace the
  draft; choosing a symbol does not hide search or presets.
- Shows a plain-text **Choice** label and checked accessibility state, so selection
  does not depend on colour alone.
- Labels the Light/Dark swatches **Preview — Apply saves your choice**.
- Keeps custom symbols, font, exact theme name and image import under More options.
  Opening this section does not open a file dialog.
- Resolves a preset as theme image, then its installed Nerd Font glyph, then the
  built-in Phone. Rejected imported assets still pass through `store.safeIcon()`.

The parent owns inventory prioritization/truncation reporting and contributor
contracts. No registry, new generic picker, daemon or asset dependency was added.

## Focused evidence

The appearance suite passed **12 tests** after the correction. Native offscreen
checks cover initial choices in automatic mode, retained search after symbol
selection, synchronized symbol input, unchanged draft on browsing, explicit preset
click and Cancel, and earlier Apply/reload and rejected-asset checks. Five forced
missing-theme presets produced five different actual 32 px image captures using
installed symbol fonts. A valid theme source took precedence over font fallback.
The JavaScript resolver checks passed, including the Share mapping and absence of
an installed symbol font. `qmllint` returned exit 0; installed native singleton
metadata produced warnings, so this is not a warning-free lint claim.

The parent owns the final full suite and current-desktop capture. Actual
AT-SPI/Orca behavior, all keyboard paths, enlarged text, real scale/RTL and the
second host remain acceptance checks. Fifty-persona review is a structured
inspection, not fifty observed users.
