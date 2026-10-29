# First-release source review

Date: 29 October 2026. Scope: the integrated isolated fork, against `AGENTS.md`
and technical-spec sections 2, 4–6, 8, 10 and 11. This review covered provider
side effects, submission evidence, fixed target identity, migration and rollback,
private metadata, image approval, process arguments, bounds and absent providers.
No live provider action, host installation, shell reload or external publication
was performed for this review.

## Findings and corrections

All findings below were P2. No P0 or P1 defect was identified in the reviewed
paths. This is a bounded source review, not a guarantee for untested providers.

| Finding | Source location after correction | Correction and evidence |
| --- | --- | --- |
| The Appearance chooser could render a saved image already rejected by the store's content-hash check. Bar and device rows already used Phone, but previews bypassed the guard. | `components/IconChooser.qml`, `resolvedDraft` (line 26) | The chooser now applies `store.safeIcon()` after resolution. A new native offscreen fixture replaces an approved PNG with a different, still-decodable PNG. Both bar and device previews must resolve to Phone. The fixture failed before the correction and passed after it. |
| Automatic bar preview lacked the selected KDE ID and type. It could show Phone while the real bar showed a device override or Desktop. | `components/IconChooser.qml`, `openForBar`; `Panel.qml`, Change bar icon action | The chooser receives separate bar-device context. Native checks require its automatic preview to equal `store.barIcon()` for both a Laptop override and a Desktop type fallback. Both pass. |
| Incoming pairing names, command names and media labels still used QML's automatic rich-text detection. A remote name containing markup could change its displayed meaning. | `components/DeviceSection.qml`, incoming name; `components/RemoteCommandsSection.qml`, command label; `components/MediaPlayerSection.qml`, title/artist/player labels | Parent integration now sets `Text.PlainText` on these labels. Source correction was verified. Native malicious-label checks belong in the parent verification gate; this reviewer did not claim a visual or assistive-technology result. |
| Migration treated an omitted legacy icon setting as false, although upstream defaulted it to true. | `scripts/migrate_settings.py`, `prepare` (line 90) | Existing omitted settings now migrate to Automatic. Explicit false still maps to Phone. Fresh metadata remains Phone. The parent updated the migration fixture. |
| The documented local runner omitted the new functional suites and top-level sibling QML files. | `scripts/validate.sh`, lines 21 and 53 | The runner now discovers all Python tests, runs the three JavaScript checks and includes the new top-level QML files. Source correction was verified; the parent owns the final full-suite receipt. |

## Boundary conclusions

- File submission captures the provider and KDE ID in a draft and operation. Device
  navigation does not replace the batch target. CLI acknowledgement remains request
  acceptance with delivery unknown. Ambiguous timeout/cancellation stops the batch.
- New provider actions use fixed argument arrays. The appearance helper has no
  network or service action. Syncthing association is explicit local ID metadata;
  the open-panel action does not start another core or read an API key.
- Appearance updates reject corrupt or unsupported metadata and preserve the
  original file. Owned writes are atomic and private. PNG/SVG import uses actual
  content inspection, bounded dimensions and size, and a private content hash.
- The address helper serializes fork writers, preserves observed external entries
  and reads back changes. Its documented external-writer race remains a KDE API
  limitation. Address hints do not grant pairing trust.
- BTH controls call the existing controller only after explicit selection. Unknown
  status does not become Off. Opening the panel does not request a mode change.
- Migration prepares private candidates without modifying the source configuration.
  Rollback checks managed fields and preserves unrelated later changes. The deliberate
  Tailscale retirement and new saved-address UI were confirmed with the parent;
  they are not unresolved migration findings.

## Verification and remaining acceptance

The focused appearance suite passed **11 tests** after the preview correction.
`node tests/appearance.cjs` passed. `qmllint` returned no diagnostics for
`AppearanceStore.qml`, `AppearanceIcon.qml` and `IconChooser.qml`.
`git diff --check` passed at that point. All fixture state was temporary.

No reported source finding remains open in the inspected correction paths. The
parent's final full suite is still a separate gate. Physical Linux/Android file
delivery, mapped Omarchy/replacement-bar behavior, offsite BTH, x86_64 native UI,
scale/RTL visual checks, AT-SPI/Orca access and measured performance remain separate
acceptance work. No such result is inferred from this review.
