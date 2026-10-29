# Icon and contribution decision — 29 October 2026

**Decision: fix the existing chooser with native Omarchy controls, document the
current domains, and add focused contract/interaction checks.** Preserve the
existing engines, metadata schema, public entry points and installed setup.

## What the audit established

The reported two-phone experience has two sources. Light/Dark are previews of
one draft, but looked like the available choices. Automatic/inherited mode hid
the actual list; selecting a glyph could also hide it. Separately, missing theme
icons fell back to the same Phone geometry while preset fallback glyphs were
unused. The isolated fixture had no normal Qt icon theme configuration, so it
could amplify this effect. That fixture result is not proof of every live theme.

The installed Omarchy kit has reusable Button, SearchableDropdown and OpticalGlyph
controls. There is no exported dedicated IconPicker in the inspected kit. Its
image and emoji overlays have different file/focus contracts. Reuse the kit
controls inside the current draft dialog. Keep the validated local importer.

## Options considered

| Option | Benefit | Cost / reason |
| --- | --- | --- |
| **Focused chooser repair + native controls — selected** | Visible choices, familiar search, deterministic fallback, stable state/backend contracts | Small scoped UI changes and interaction regressions |
| Delegate to native image/emoji overlays | Reuses whole existing screens | Image picker does not match SVG/PNG boundary; emoji inserts into focus; cross-overlay state/focus contract adds risk |
| New icon-pack/provider plugin framework and domain-wide moves | More extension points in theory | No second concrete provider requirement; new lifecycle/config/import surface and broad test churn; deferred |

## Applied scope

- Show all five labelled presets from the opening state, including Automatic.
- Use native searchable installed-icon selection. Keep previews explicitly labelled.
- Preserve the draft while browsing. Only selecting a choice changes it; Apply
  saves and Cancel preserves stored state. Keep custom symbol, exact icon name
  and validated local image under More options.
- Resolve preset theme icons first, then their distinct installed-font glyphs,
  then an explicit Phone fallback with a warning. Correct the Share glyph.
- Keep required defaults in bounded inventories; support XDG icon roots and
  ordinary PNG/SVG icon names. Report truncation instead of claiming completeness.
- Make keyboard Tab enter the form and retain the device-arrow route. Check actual
  key events, BTH reachability, expansion and text entry with fake providers.
- Explain device-dependent unavailable appearance actions. Keep the reviewed
  recipient prominent during sharing. Place Syncthing association with Devices.
- Add CONTRIBUTING.md, docs/ICONS.md and a JS/Python preset parity check. No runtime
  plugin registry, schema migration, credential change or directory reorganization.

## DDD / DRY / YAGNI result

The existing bounded responsibilities already cover host composition, KDE devices,
file submission, appearance/local preferences, address hints and home access.
The contributor map explains ownership and facade seams. Each helper keeps its own
trust and failure boundary. Independent UI normalization and persistence validation
are intentional; a parity check prevents short-list drift.

The next justified extraction is the transfer lifecycle from the large KDE
controller, when a real next sharing provider needs that seam. Domain folders can
follow one module at a time after the seam is stable. A bulk file move now would
also change relative imports, helper URLs, validators and many source-contract
tests. Folder names alone do not establish better boundaries.

## Outside voices: actual independent runs

Both CLIs received the same sanitized code/design bundle and no private user
configuration, inventories, device state, credentials or raw chat. They ran
separately. Claude used restricted/no-tool mode; Antigravity was instructed to
return analysis only and completed one turn. Neither replaced source verification.
Their output lives in the audit delivery folder, outside the source checkout.

- **Claude**: completed successfully; CLI metadata reports `claude-sonnet-5-5`.
  Recommended the focused chooser, visible curated options, native primitives
  where available, advanced disclosure, contributor documentation and no framework.
- **Antigravity**: completed successfully in one turn. Recommended the focused
  repair and shared native primitives while preserving existing contracts.
  Backend identity in its prose is self-reported, not independently verified.
- **Fact check**: Antigravity described preset glyph values as empty. They were
  already populated; the actual defect was that the renderer did not use them.
  That incorrect claim was rejected. Both reviews' source-line references describe
  the pre-change excerpt bundle and can move after edits.

Agreement is supporting evidence, not a vote proving the best design. The decision
rests on the reproduced state/rendering defects, existing native APIs, regression
cost and the owner's requested workflow.

## Fifty-persona and accessibility evidence

[The full audit](2026-10-29-persona-audit.md) contains exactly 50 numbered synthetic
personas, scenarios, source evidence, priorities and proposed acceptance checks.
It is not recruited research, clinical validation, 50 independent agents or an
accessibility certification.

The implemented priorities target discoverable choices, predictable drafts,
plain text, explicit state/recipient identity, low initial choice count, collapsed
advanced controls and complete keyboard routes. The contributor guide uses a short
task/file/check map and one command, reducing the number of files a new contributor
must hold in working memory.

Actual screen-reader/AT, real pointer usability, RTL, enlarged text, sustained
attention and individual ADHD/AuDHD suitability remain human acceptance work.
Existing fixture/device receipts do not close those gates. Keep the 50 checks as
traceable test candidates rather than manufacture a numerical usability score.

## Sources

Inspected installed Omarchy kit/source is the primary compatibility evidence.
Theme lookup/inheritance follows the [freedesktop icon-theme specification](https://specifications.freedesktop.org/icon-theme/latest/).
The availability/fallback distinction follows [Qt QIcon](https://doc.qt.io/qt-6/qicon.html#fromTheme).
See [icon source audit](icon-audit.md) and [contribution architecture review](2026-10-29-contribution-architecture.md)
for the local source observations and separate open gates.

## Later owner steering: native features and all three networks

The [product/spec addendum](2026-10-29-product-addendum.md) extends the decision:
all native KDE plugin IDs remain discoverable, native permissions/settings retain
ownership, and Tailscale, BTH and WireGuard each have a named path. Compact quick
actions do not define the complete feature set. Clear task labels and explicit
next steps apply Sierra's user-success principles while preserving low initial
visual load. The earlier 50-persona source snapshot stays unchanged; its full-
capability and contribution findings also apply to these additions.

### Outside addendum reconciliation

Both outside CLIs completed a second independent analysis-only pass over the same
sanitized native-feature/network design brief. They did not inspect the updated
code. Their raw outputs and receipts are in the adjacent audit delivery folder.

| Recommendation | Disposition and reason |
| --- | --- |
| Distinguish inline capability, native handoff and future adapters | Applied. Product addendum and network matrix state the difference. |
| Keep complete plugin details collapsed and common tasks visible | Applied. Native page route remains discoverable. |
| Use unknown when state cannot be established | Applied. Supported/loaded are separate; no guessed enabled state. |
| Label not-loaded plugins Disabled/Ready | Rejected. Permission, reachability and enabled state cannot be derived from loaded metadata alone. |
| Require a local Tailscale daemon to approve every CGNAT hint | Rejected for this manual address contract. The peer can use Tailscale while this machine uses another route. User-selected provenance is explicitly unauthenticated; KDE identity/pairing remains authoritative. No routing/firewall privileges are granted by the label. |
| Offer direct configuration for every discovered plugin | Deferred. Only a subset has a native configuration surface. The verified native selected-device page already owns the complete settings flow. Add shortcuts only for confirmed useful configuration pages. |
| Move all searchable icons behind another view | Not applied. The user explicitly requested an icon menu. Native search plus five presets gives that path; symbol/image complexity remains collapsed. Human choice-load acceptance stays open. |

Neither outside review is a consensus score or evidence that actual users can
complete a task. The exact 50-persona source audit remains a separate synthetic
artifact. Later source review and integrated regression receipts govern completion.
