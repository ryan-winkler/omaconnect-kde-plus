# Final scoped outside review — 0.1.1 identity update

Date: 2026-10-29. Product: **Omaconnect KDE Plus**. Exact technical ID: **`Omaconnect.plus`**. Original upstream ID: `omaconnect`.

## Outcome

Both authorized outside voices completed on the same frozen public-source snapshot. Antigravity reported `NO_FINDINGS`. Claude found three Low documentation items and no source-supported Critical/High defect. The three documentation corrections were applied after the snapshots were sealed. This is not a universal security guarantee, a new physical acceptance receipt or approval of files outside the supplied scope.

| Voice | Actual invocation constraints | Observed result |
| --- | --- | --- |
| Claude Code `2.1.312` | Safe mode, restricted mode, plan permission mode, empty built-in tool list, strict empty MCP config, slash commands disabled, no session persistence, JSON output; 240-second process-group bound. | Exit 0 in **116.72 seconds**. CLI metadata reports canonical model **`claude-sonnet-5-5`**, one turn and no web tool use. Three Low documentation items. |
| Antigravity `1.4.10` | Sandbox requested, plan mode requested, slash expansion disabled, JSON output, 180-second CLI timeout; 190-second outer bound. Prompt forbade tools, commands, reads, writes and provider actions. CLI logs discarded. | Exit 0 in **23.70 seconds**, `SUCCESS`, one turn, `NO_FINDINGS`. Output does not report an immutable model identity; configured default was requested. |

Antigravity warned: `--mode plan has no effect while slash command expansion is disabled.` Therefore plan mode did not enforce the no-action rule. The sandbox was requested, and no tools/actions were authorized in the prompt. We do not claim an independently enforced empty tool set for Antigravity. Claude's empty tool list and strict MCP configuration are separate controls.

## Snapshot and limits

Both prompts were identical: **122,526 bytes**, SHA-256 **`bf410614d00b992b5740309a02706756c7178dc1f1217655d7a1a055a119a7d0`**. Source files were marked as untrusted data with hashes and original line numbers. No personal configuration, pairing material, actual device inventory, credentials or chat history was supplied.

Complete files: `manifest.json`, `README.md`, `docs/WHY-PLUS.md`, `docs/CONTRACTS.md`, `docs/MIGRATION.md`, `SECURITY.md`, and the migration, portal, address, preference, native-app and network-owner helpers. Selected current ranges covered appearance paths/private state and controller submission/media handling. The complete current diff covered controller setup removal, media-art removal and deletion of the dependency/firewall scripts.

The remaining QML/service wiring, full appearance/SVG validation, BTH/Syncthing paths and tests were not supplied in full. The reviewers did not inspect live GitHub settings, execute tests, validate mailbox delivery, map native windows or test physical transfer. Outside scope is not a clean result. Historical 0.1.0 receipts do not establish new-ID migration or runtime acceptance.

## Findings and source reconciliation

| Outside item | Local assessment | Disposition |
| --- | --- | --- |
| Claude Low: cancellation appeared physically accepted although the prompt only supplied pre-Send drag/review/source-retention evidence. | The brief did not supply a separate cancellation receipt. New claims should stay within the narrow observation. | Applied wording that says the check stopped before Send. No post-drop Send/delivery claim is added. |
| Claude Low: contract says two bounded preference strings. | Verified: the helper allowlists `defaultPingMessage`, `bthHelperPath` and `quickActionsOrder`, each with validation. | Corrected the contract to three strings. |
| Claude Low: removed firewall setup lacks port guidance. | Verified gap in the supplied guide. KDE's official troubleshooting documents 1714–1764 for TCP and UDP. | Added brief README/packaging guidance and a direct official link; no firewall mutation or installer is restored. |
| Missing removed-function callers could cause a runtime error. | Focused repository source search found removed setup names only in regression assertions, not live QML/JS/helper callers. | No reproduced product defect. The source check does not replace final native loading. |
| Provider album art could remain in another sink. | Current media component has no Image/art URI sink; the controller publishes an empty art value. | No remaining source-supported sink in the checked boundary. Text/player controls remain. |
| Claude assumption: cancellation may override a final result if stdout/onExited ordering differs. | The supplied helper emits `submitting` before the final result. No failing ordering or actual false-cancellation case was reproduced by this review. | The parent added a conservative acknowledgement guard and deterministic controller regression: a running helper without explicit before-submit confirmation remains unconfirmed. No Qt event-order exploit is claimed. |
| Upstream feature matrix, conduct contact, live repository settings and new-ID installed behavior were not independently checked by the outside voices. | The matrix uses the pinned local upstream source; project contact follows the explicit owner instruction. Administrative and installed receipts are separate. | Keep those source/owner receipts distinct from outside review coverage. |

Official firewall source: [KDE Connect troubleshooting](https://userbase.kde.org/KDEConnect/en#Troubleshooting).

## Release implication

The completed outside review adds no confirmed Critical/High finding in its supplied source. It produced useful Low documentation corrections and one explicit cancellation-ordering question for local assessment. Actual post-drop Send/delivery, new-ID installed readback and the final hosted scan results retain their own acceptance boundaries. No reviewer or scanner certifies the whole application, its providers or every device.

Local private evidence retains the sanitized prompt, file hashes, scope, invocation bounds, sanitized responses and status metadata. Raw CLI logs and response session/conversation identifiers are not retained. Later source or documentation edits are not silently covered by this frozen snapshot.

## Later changes outside this snapshot

The private-source snapshot helper, typed-text/Ping stdin/D-Bus repair, settings
visibility, expanded action catalogue and bar drop target were added after this
outside snapshot. Their focused manual/native checks and integrated QA are
recorded separately. These earlier outside reviews do not certify those changes.
