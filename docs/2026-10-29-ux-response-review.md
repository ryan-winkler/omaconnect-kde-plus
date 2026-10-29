# Focused UX response review — 29 October 2026

**Scope:** Read-only review of the working diff after the 50-persona source audit. The source base is `b3bb4ff84f6349a49a8e4f36c45fd45a35a5d94f`; review references below describe the uncommitted working tree as read. Other assigned agents may change it after this review. This review changed only this document. No GUI, test, real provider, installation, activation or commit ran here.

This is same-model source analysis, not user research, clinical/accessibility validation or an independent expert vote. Test code was inspected, but its presence is not a passing result. The parent owns final integration and test receipts.

## Response to the requested direction

| Requirement / audit priority | Current source response | Review conclusion |
| --- | --- | --- |
| More than two apparent icon choices | `IconChooser.qml:135–181` places five labelled preset buttons and native `SearchableDropdown` before `Preview — Apply saves your choice` at line 193. Both samples consume the same `resolvedDraft`. | The source addresses the Light/Dark ambiguity. Actual discoverability and pointer acceptance still require an interaction check. |
| Use supported native choices and explain the icon bank | `IconChooser.qml:120–181,242–342` uses native Button/TextField/SearchableDropdown, with advanced glyph, exact-name and local-image actions behind More options. `appearance.py:275–300` inventories XDG/legacy roots with count/visit bounds; `AppearanceStore.qml:87–89` resolves candidates through Qt and carries truncation. | Reuses the platform instead of adding another picker framework. The docs correctly distinguish inventory from active-theme availability. |
| One daily UI with truthful task context | `Panel.qml:582–588` routes Tab into view tabs; `Panel.qml:670–671` shows the reviewed draft recipient; `Panel.qml:776–788` places the existing Syncthing link component under Devices. | Addresses the main navigation/context findings without another backend owner. Keyboard event fixtures cover BTH/address/link reachability, but this reviewer did not run them. |
| Contributions remain DRY/YAGNI and understandable | `Appearance.js` remains the single presentation resolver. CONTRIBUTING.md and docs/ICONS.md map work to owners, storage and checks. Independent persistence validation remains in Python with a catalog parity check. | No new runtime plugin registry, schema migration, broad file move, protocol daemon, router provisioner or generic API proxy appears in this focused diff. |

## Remaining P2 findings at review time

### UX-R1 — An actionable operation error can be hidden by a preview warning

**Source:** `components/IconChooser.qml:232–240`, especially line 236:

```qml
text: validationPreview.warning || (root.store ? root.store.error || root.store.warnings.join("\n") : "")
```

**Trigger:** Keep a draft whose theme/font cannot render, then attempt an invalid local-image import or a rejected save. `AppearanceStore.qml:60,82–85` sets an operation error, but the existing preview warning wins the `||` expression. The dialog can show only “Theme icon is unavailable” while concealing why the import/save failed. This ordering is a source-visible issue, not a claim that the scenario was run.

**Small correction:** Give operation errors priority or render them separately from fallback warnings. Preserve plain text and the existing alert surface. Do not replace secure import rejection with a permissive fallback.

**Check UX-C1:** With an owned fake store, set a missing-theme draft, then emit a rejected import/save error. The actionable reason is visible and exposed through the alert. The fallback warning remains available without hiding the failure. Stored state is unchanged.

### UX-R2 — A late image import can overwrite the user's newer explicit choice

**Source:** `components/IconChooser.qml:63–68,142–158,315–321,381–386`. A local import sets `pendingImport`; preset selection remains enabled and calls `choose()`. Import completion then calls `choose(icon)` whenever `pendingImport` is true, without checking whether a later choice superseded the import.

**Trigger:** Start a delayed import, explicitly select Phone while the helper is busy, then let the import finish. The result handler can replace Phone with the imported image. Apply is blocked while the helper is busy, so this is draft replacement rather than an automatic save or send. It still violates the user's latest explicit choice.

**Small correction:** Invalidate the pending import on a newer choice, use an operation generation, or temporarily disable competing choices with a clear loading reason. Preserve Cancel's stored-state boundary and avoid a new general job framework.

**Check UX-C2:** Delay image completion in an owned fixture. Select a preset after import starts, then deliver the result. The later explicit preset remains selected. Also test Cancel/reopen and a normal unopposed import; no old result reaches a new dialog context.

These findings were sent to the parent for integration. Re-read the affected functions and attach focused test evidence before marking them resolved.

## Semantics, focus and warning checks that remain bounded

- **Chosen versus focused:** Automatic and the five presets expose `Accessible.checkable/checked` and a visible `Choice:` label (`IconChooser.qml:120–168`). Native focus styling remains separate. The advanced glyph buttons at lines 260–268 still rely on `selected` presentation without the same explicit checked semantics. This is a consistency/AT follow-up, not proof of a screen-reader failure. Check glyph selection plus the Choice label through actual AT-SPI/Orca before making an accessibility claim.
- **Advanced keyboard path:** More options is focusable and its fields use native controls. The inspected `tests/keyboard_ui.qml` exercises panel tabs, BTH, disclosure and address/Syncthing text entry; it does not by itself establish the chooser's installed-icon popup, Escape focus return, More options traversal or offscreen-field scrolling. Inspect the appearance agent's focused evidence for those cases. No source-only claim of a focus failure is made here.
- **Validation:** Symbol text can still be temporarily invalid before helper validation; the helper rejects more than eight code points (`appearance.py:68–76`). Retain the error message and saved-state protection. UX-R1 must not conceal it. Actual enlarged text, scale 2, RTL and reduced-motion acceptance remain separate.
- **Identity and side effects:** New chooser actions target only the appearance store. Bar/device precedence stays in the shared resolver. Device IDs, pairing and trust are not derived from artwork or alias. `Panel.qml` now promotes the immutable reviewed draft target instead of showing the unrelated current peer. No new send, VPN-mode, sync-control or router action is introduced by this diff.

## Documentation accuracy and scope

The storage table in `docs/ICONS.md:47–55` agrees with `appearance.py:104–109` and `manage_addresses.py:275–278`: appearance metadata uses XDG config, assets use XDG data, and address metadata is a separate XDG-data file. The inventory text describes candidates and truncation instead of claiming all installed themes are usable. Preset theme→font glyph→Phone fallback agrees with `AppearanceIcon.qml:17–26`.

The 50-persona audit intentionally describes the pre-response source snapshot. Its old line references and findings are historical inputs, not claims that all those defects remain. Link this response review and the final test receipt when presenting current status. Contribution-architecture findings that describe prior hardcoded counts should likewise be read with the implemented parity change.

**No blocking scope or architecture overreach was found in the inspected focused diff.** UX-R1 and UX-R2 are concrete remaining P2 behavior cases at review time. Keyboard/AT/physical acceptance must be reported from the owning checks, not inferred from this source review or the number of personas.

## Parent resolution after this review

UX-R1 and UX-R2 are fixed in the subsequent chooser revision. Operation errors
now take priority over preview fallback warnings. A newer explicit draft choice
invalidates a pending image import. Focused native fake-store checks cover the
failure cases and a normal import. The review above remains a dated source
snapshot; final integrated test evidence is recorded in VERIFICATION.md.
