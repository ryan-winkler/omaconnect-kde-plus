# Product and implementation addendum — 29 October 2026

This addendum extends the approved PRD and technical specification. It covers the
owner's later icon, native-feature and three-network requests. The earlier design
pack remains a dated snapshot. The working source and current contracts govern
implemented behavior. Installation and live network changes remain separate.

## Help users complete tasks

Apply Kathy Sierra's user-success and cognitive-resource ideas to concrete tasks:
identify the right peer, send the intended files, recover a missing connection,
use a native device feature and customize a recognizable icon. This is our design
interpretation of the publisher's overview and contents, not a claim to have read
the full book or obtained the author's review.

- Keep common actions labelled and near the selected device.
- Keep the reviewed recipient visible until the batch ends.
- Show one clear next action for unavailable capabilities.
- Always offer **All KDE Connect features**. Compact quick actions are a subset.
- Put the complete returned plugin inventory behind **Feature support details**.
  Preserve unknown IDs. Supported, loaded and enabled mean different things.
- Let the native app own permission choices and plugin configuration. Do not
  silently enable all plugins or make remote input/commands a default.
- Keep advanced choices reachable with words and ordinary keyboard focus.
  Do not substitute hidden keyboard shortcuts for discoverable controls.

## Network scope: all three services

| User outcome | Tailscale | MikroTik Back to Home | Generic WireGuard |
| --- | --- | --- | --- |
| Recognize the service and find its owner | Explicit provider guidance/native owner route | Explicit BTH guidance and helper | Explicit provider guidance/native owner route |
| Rediscover an approved KDE peer address | Source-tagged saved private/CGNAT IP | Source-tagged saved private IP | Source-tagged saved private IP |
| Change connection policy | Existing native owner | Existing reviewed helper: Automatic / On / Off | Existing native owner |
| Prove service reachability or delivery | Separate real-device check | Separate real-device check | Separate real-device check |
| Import keys or provision a profile | Later scoped onboarding work | Later scoped onboarding work | Later scoped onboarding work |

BTH uses WireGuard, but it is a distinct managed workflow. Do not show an inactive
BTH tunnel at home as a failure. Do not label generic WireGuard Automatic unless
its actual owner implements that policy. Address hints are neither paired device
identity nor proof of an active route. Tailscale support in an open-source product
does not change the owner's personal fleet retirement policy.

The old hidden Tailscale list and legacy KDE address writer stay disabled. Safe
provider discovery adapters can follow only with bounded status parsing, explicit
approval before address enrollment, and provider-specific failure fixtures. This
release must not claim automatic Tailscale enumeration or universal three-provider
toggles. Existing native owners retain those controls.

## Small implementation units

1. Repair the existing icon chooser with native Omarchy controls and documented
   storage/resolution. Keep one presentation resolver and one validation boundary.
2. Expose all bounded native KDE plugin IDs and the native selected-device page.
   Correct quick-action direction checks for remote commands/media.
3. Extend the existing address contract with Tailscale provenance and scoped CGNAT
   validation. Show all three network owners through the same task entry.
4. Keep modules under their existing ownership; add a task/file/check contributor
   map. Extract transfer lifecycle only when another real provider needs it.
5. Run fixture, key-event and source-contract checks. Keep human pointer, AT,
   scaling/RTL and away-network acceptance open until separately observed.

## Acceptance criteria

- All labelled icon presets remain available from Automatic and custom drafts.
  Browsing does not replace a draft; Apply saves; Cancel preserves stored state.
- Missing theme icons resolve to distinct available glyphs with honest warnings.
- Every safe advertised native KDE plugin survives discovery. Unknown IDs remain
  visible. A failed loaded-state read produces unknown, never enabled/off.
- The native route targets the selected KDE ID through fixed arguments. It works
  for an offline paired peer's settings and needs no new pairing database.
- All three network names appear together. Missing owners give an actionable
  unavailable result without a background installation or connection attempt.
- Tailscale address fixtures accept its CGNAT range only with Tailscale provenance;
  unsafe/global/loopback values and invalid sources remain rejected.
- Opening a disclosure, choosing an icon, or focusing a control never sends files,
  toggles plugins or changes a VPN mode.

Source: [Kathy Sierra, publisher overview](https://www.oreilly.com/library/view/badass-making-users/9781491919057/)
and [KDE Connect features](https://kdeconnect.kde.org/). Native API details are
checked against the installed version and KDE source, not inferred from marketing.

## Owner follow-up: independent network choices and comparison installation

Connection settings has independent saved visibility choices for Tailscale, BTH
and other WireGuard profiles, with short instructions and official links. Optional
sections default off. A hidden BTH section does not poll the helper. These switches
do not change connection policy. Current owner installations explicitly show BTH
and hide the other two, matching the existing setup.

The owner explicitly requested both original and fork on both hosts for comparison.
This permits two UI signal subscribers during that test. Both use the existing KDE
daemon; the original stays installed/enabled and untouched. Keep ordinary migration
advice to replace the UI after testing; do not turn comparison into a new daemon.
The fork's Link icon and app-name tooltip distinguish it from the original.

The default graphical portal file picker implements the request in
[upstream issue #17](https://github.com/jitendradara12/omaconnect/issues/17).
This is file selection for sending, distinct from browsing a remote filesystem.

## Dedicated settings decision and file drop

The [new 50-persona/RICE challenge](2026-10-29-settings-rice-personas.md) recommends
continuing the dedicated four-domain native Settings window and native KDE handoff.
Its hypothetical RICE comparison is 97.50/19.67/5.63 for current flow/full native
control duplication/new module installer. These are declared planning assumptions,
not measured adoption or votes. Native Plugin Settings has search and installed-
module enable/config controls; a store/install action was not present in the
inspected version. A specific future adapter can be reconsidered from task evidence.

The Send view now offers a persistent managed Send window with copy-only native
drop selection, the existing inspection/review lifecycle and explicit Send. This
avoids losing the drop surface when the file manager receives focus. The default
graphical portal chooser remains an equal selection path. No drop replaces a draft
or redirects a frozen recipient.

## Configurable quick actions and contextual help

Toolbar membership/order now uses the shared verified ActionCatalog and saved
quickActionsOrder. Users add, remove and reorder shortcuts through labelled native
controls. Ring is optional; fresh defaults are Files, Text/link and Clipboard.
Plugin readiness is metadata-driven and native enablement remains independent.
The active Settings domains are Appearance, Connections, Quick actions and Device
features. Legacy showAction booleans no longer determine the toolbar.

Every feature has adjacent help text or a documentation link; docs/HELP.md records
coverage and AGENTS.md makes it a contribution requirement.
