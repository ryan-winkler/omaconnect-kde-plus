# Settings and task completeness audit

Date: 29 October 2026. **Status: DONE_WITH_CONCERNS.** This is a finite baseline
review for the next implementation. It does not accept source changes made after
the captured inputs. The parent owns fixes, final native checks and publication.

**Recommendation:** finish optional sections, explain Syncthing as a local device
reminder, and expose reviewed native action routes through the existing catalog.
Keep one settings window, one file-review lifecycle and the native KDE owner.

## Evidence and workflow

The requested Product Design `design-qa` skill explicitly routes broad product
audits to `audit`; that route was used with the requested `/qa` and Ponytail
workflows. No matching approved visual target exists for these exact Settings
states. **Design-fidelity final result: blocked.** This blocks a claim that the
implementation matches an approved picture, not the product audit or fixes.

One fresh native fixture probe ran at 20:23 UTC. It reused the repository's
`NativeUi` runner and `settings_panel_ui.qml`, retaining captures in an owned
private evidence directory. No product fixture or installed UI was edited.

- Native Settings contract: **pass**, 19 assertions and six captures.
- Evidence producer: `gstack-qa-evidence`, capture `001`; materialized verdict
  `pass`, with no open item for that captured contract.
- Captured Settings source SHA-256:
  `1e0fd4152b141fdeaacd14ab53d8e2e26939b58e7591cbd71b2d6bc87f904f3d`.
- All six actual PNGs were opened and inspected in this review. These are native
  Qt component captures, not HTML recreations or old screenshots.
- Private HOME/XDG, D-Bus, fake owner actions, software/offscreen Qt and the existing
  native Omarchy UI kit were used. The fixture substitutes the panel host boundary;
  it does not prove mapped compositor behavior. Offscreen `raise()` warnings remain.

| Step | Captured state | Health and limit |
| --- | --- | --- |
| 1 | `settings-720-appearance.png`, 720×640 | Clear icon/name actions, local scope and fixed return route. No icon chooser interaction was captured in this probe. |
| 2 | `settings-720-connections.png`, 720×640 | Separate provider labels, explanations and help links. Long content scrolls. No VPN or owner launch ran. |
| 3 | `settings-720-actions.png`, 720×640 | Add/remove/order controls and default actions are visible. Additional content extends below the viewport. |
| 4 | `settings-720-features.png`, 720×640 | Native settings route and task/ID search are present. Repeated explanation pushes feature results down. |
| 5 | `settings-520-connections.png`, 520×640 | Provider guidance wraps at the narrow width. Footer remains visible while the page scrolls. |
| 6 | `settings-520-features.png`, 520×640 | Search remains reachable, but repeated prose consumes most of the first screen. |

These are 1× native pixel captures. CSS viewport/density normalization does not
apply. There is no source/implementation comparison pair, so no fidelity match,
pixel-difference score or comparison iteration is claimed. The Syncthing form,
bar drop and new section controls were not rendered by this baseline probe.

## Findings and minimum corrections

| ID / priority | Evidence and user effect | Minimum correction | Acceptance check |
| --- | --- | --- | --- |
| SC01 / P2 | `SyncthingLinkSection.qml` keeps editor text across `device` changes, while Save uses the live selected KDE ID. An ID typed for A can be saved against B after navigation. This is a source-backed finding, not a native reproduction. | Rebase/clear the draft when the KDE identity changes, or freeze a reviewed draft identity and require review before saving. Keep asynchronous results attached to the original identity. | Type a valid Syncthing ID for A, select B, then activate Save. No A draft may be applied to B. Test saved, unsaved, removed and late-result cases with owned fake state. |
| SC02 / P2 | The existing association is stored/read/displayed as metadata. `openSyncthingPanel()` opens generic Syncshell without passing the linked ID. The form explains what linking does not do, but gives little reason to fill it in. | Call it an optional local device link. Explain the useful result before the form: remember which Syncthing ID belongs to this KDE device when names differ. Use “Save local link”. Keep owner launch available without requiring a link. | A reader can state the benefit, where folders are configured and what the link does. Missing Syncshell gives a useful next step. Do not claim per-device deep-linking or live synchronization status. |
| SC03 / P2 | Devices always exposes the Syncthing disclosure. There is no saved show/hide preference for it or the saved-address/native-feature sections. Collapsing one session is not a settings option. | Add typed display preferences in the existing settings helper/manifest. Syncthing should be optional and off by default for new users; preserve existing links when hidden. Put its configuration in a named settings domain. | Hide, reopen and reload: no unwanted daily section. Re-enable: prior metadata survives. Hiding changes presentation, not pairing, sync, VPN policy or files. |
| SC04 / P2 | Media and commands have session expansion state; saved addresses and Syncthing start collapsed. There is no explicit saved section-state control for the requested layout choice. | Offer Show and Start collapsed for optional sections where useful. Keep current session expansion separate from the saved initial preference. Keep review recipient, errors and progress visible. | Each optional section can show/hide/collapse using keyboard and pointer. A hidden section leaves no focusable ghost. Unrelated settings updates do not unexpectedly reset an active review. |
| SC05 / P2 | The baseline action catalog has seven explicit actions. Search preserves safe native module IDs but does not turn every module into a selectable action. A loaded plugin is not automatically an invocable command. | Extend the existing catalog with verified action or selected-device native-owner routes. Keep unfamiliar modules searchable with an explained native route. Do not derive flags or commands from plugin IDs. | Catalog, preference allowlist, dispatch and help stay in parity. Test unsupported/unloaded/offline states, empty choices and safe unknown IDs. Every offered action has a real effect or an explicit owner route. |
| SC06 / P2 | Baseline `BarWidget.qml` has no drop receiver. File review exists in Send and the persistent Send window. The requested direct bar entry is missing. | Route bar drops into the same `stageDroppedFiles` and persistent review window. Freeze a valid selected recipient and accept Copy only. Explain refusal when no recipient, busy state or an existing draft prevents staging. | Native component check plus a real file-manager drop: original retained, correct recipient/files, zero send before explicit Send, no retargeting after navigation. Test invalid URLs, folders, excessive counts, busy state and existing drafts. |
| SC07 / P3 | At 520 pixels, Device features has several similar explanations before search/results. The screenshots show vertical scanning work even though navigation and the footer remain reachable. | Keep one short owner/permission explanation and one support/loading legend. Place the search and primary native-owner route early. Keep detailed help one step away. | Fresh 520/720 captures show clear task entry, readable wrapping and reachable footer/search. No diagnostic identity or required permission meaning is lost. |
| SC08 / P2 | Plugin update and native KDE package update have different owners. `omarchy pkg add` installs missing packages; its help does not describe an update operation. | In Help, distinguish `omarchy plugin update Omaconnect.plus` from the supported `omarchy update` system route. Explain that system updates can include KDE Connect and other packages. Keep privilege/setup outside the plugin. | Verify help/command text and owner handoff. Do not add silent package/firewall actions or claim an update ran from reading help. |

The captured UI already has useful strengths: explicit domain navigation, a
separate native Settings window, a fixed Back to devices route, visible field
labels, short action descriptions and separate native-owner responsibility.
Search found “browse” and a safe unknown third-party ID in the actual component
fixture. Back, Escape and scrolling also passed. The native-owner callback in
that fixture is a fake request, not proof that KDE's real window opened.

## Syncthing decision

The current link is a local cross-reference, not a synchronization feature.
That can be useful, but it should earn its place through a clear, small task.

Suggested copy:

> Save a local reminder that this KDE Connect device and a Syncthing ID belong
> to the same device. This helps when their names differ. Open Syncthing to set
> up folders and check synchronization. Saving this link does not pair devices
> or verify ownership.

Keep the saved KDE ID and full Syncthing ID visible when reviewing the link.
Show a useful empty state, save/error feedback and Remove local link. Do not
require a link before opening Syncthing. Do not infer an association from names,
IP addresses or similar-looking IDs. Hiding the section must retain the link.

No live status adapter, API-key import, extra Syncthing core, background poller or
automatic folder setup is needed for this task. Add a per-device owner route only
when the owner exposes and verifies that contract.

## Domain and contribution plan

| Responsibility | Existing owner to reuse | Boundary |
| --- | --- | --- |
| Device identity, native capabilities and actions | `KdeConnectController.qml`, `Service.qml`, `ActionCatalog.js` | Native KDE keeps pairing, modules and permissions. |
| File entry, review, queue and truthful results | Existing staging API, Send window, `TransferModel.js`, file helpers | Every entry route reaches one draft/recipient/cancel lifecycle. |
| Section visibility and initial expansion | Settings window, typed preference helper and manifest | These are display choices, not provider enablement or protocol state. |
| Local aliases, icons and explicit device notes | Existing private metadata/store | A local note does not become pairing trust or a sync command. |
| VPN choices and approved route hints | Existing network owners and discovery domain | Hide/control visibility without a second policy writer. |

Use the existing small catalogs and independent helper validation. Add parity
checks where both must agree. Do not combine UI fallback normalization with
storage validation solely to remove a short repeated allowlist. Keep the root
manifest, entry points, bridge and relative resolution stable.

The current large Panel/controller files are a maintenance cost. A folder move
does not fix that cost by itself. Extract one real lifecycle only when a touched
change needs the seam, with its state, processes and cancellation together. This
settings work does not need a provider framework, arbitrary plugin loader,
second native KDE settings implementation or another daemon.

## Bounded frontier panel

This is a **simulated review by eight disciplines**, not eight real experts,
independent model runs, user interviews or clinical evidence.

| Discipline | Challenge | Decision |
| --- | --- | --- |
| Cognitive accessibility | Does an optional technical form interrupt a simple send task? | Hide unused Syncthing by default; benefit first, details on demand. |
| Assistive technology | Can a hidden/collapsed region leave stray focus targets or unclear state? | Named controls, exposed expanded/checked state, ordinary keyboard paths and focused native tests. |
| KDE platform maintenance | Can every reported plugin safely become a command? | Use reviewed routes and native settings; preserve unknown inventory without invented invocation. |
| Syncthing operations | Does the saved ID do more than act as a note? | State its current local reminder value; do not imply live state or per-peer navigation. |
| Security and privacy | Can names or route hints become identity, URLs or commands? | Keep stable IDs, plain text, fixed dispatch, explicit association and existing file review. |
| Domain design | Does another settings controller improve ownership? | Reuse the typed preference boundary; one owner per lifecycle. Extract only a demonstrated seam. |
| Release operations | Will “Update KDE Connect” run hidden system changes? | Explain and delegate to the supported Omarchy system updater with normal user interaction. |
| QA and skeptical maintainer | Can fixture success close external drop/physical delivery gates? | No. Recheck changed native UI and test actual bar/file-manager DND separately. |

## Verification needed after implementation

1. Reuse the native settings fixture for new domains/section controls and Syncthing
   draft identity changes. Extend existing preference and catalog parity checks.
2. Reuse drop staging/window fixtures for the bar route. Add no second file parser
   or send dispatcher. Confirm Copy, explicit Send and immutable recipient.
3. Capture changed Settings pages at 520 and 720 pixels and the expanded/collapsed
   optional states. Inspect each saved image; retain actual inputs and hashes.
4. Run one owned external file-manager bar-drop check on each claimed host. A
   pre-Send cancellation check does not prove post-Send delivery.
5. Preserve open checks for real native-owner launch, phone effects, offsite VPN,
   Orca/AT-SPI, RTL, scale 2, theme contrast and personal ADHD/AuDHD suitability.

Typography, spacing, colors and imagery were inspected in the six baseline
captures. Native monospace text and hierarchy are legible at these sizes;
content scrolls while navigation/footer remain. No matching source font/palette
or artwork target exists, and no contrast ratio or full accessibility compliance
was measured. Copy duplication is the observed improvement above, not a claim
that a different visual style is required.

The only update commands executed were their `--help` forms. No package, plugin,
VPN, pairing, synchronization or real file-transfer change ran in this review.
The shared dirty checkout was preserved; the reviewer owns only this report.
Tool-upgrade onboarding was deferred to the parent because this audit does not
authorize changing the shared workflow installation. No outside voice was used.

## Parent implementation follow-up

The following changes were made after this baseline. Final integrated QA and
installed receipts are recorded in [VERIFICATION.md](VERIFICATION.md).

| Item | Applied correction / evidence boundary |
| --- | --- |
| SC01–SC02 | Syncthing draft state is bound to the reviewed KDE identity, with save/remove readback and a selectable saved ID. The component names its small local-note benefit and generic owner route. A dedicated native fake-store fixture checks switching peers, pending results and failures. |
| SC03–SC04 | Typed visibility settings cover Syncthing, saved addresses, native entry, network controls, media and commands. Saved start-expanded defaults stay separate from session collapse. Hiding preserves metadata/provider settings. |
| SC05 | One catalogue now offers 18 reviewed shortcuts and explicit native-owner routes. Unknown native modules remain searchable; no command is generated from their names. |
| SC06 | Bar and Send share one Copy-only DropArea. Native component/controller probes check refusal, recipient review and no automatic Send. A physical file-manager drop onto the bar icon remains a separate owner check. |
| SC07 | Repeated native-owner prose was shortened; the task search precedes the detailed guide link. Fresh 520/720 captures belong to final QA. |
| SC08 | Both hosts have native KDE Connect26.08.2-1. Fresh temporary-database package checks found no KDE update; no packages changed. Help distinguishes plugin update from system update. |

The source-target fidelity comparison remains unavailable. This follow-up does
not turn that design-specific gap into a pass or claim clinical ADHD/AuDHD
acceptance. Clear controls, nearby help, keyboard paths and retained review state
are engineering checks; actual personal suitability remains for the owner.
