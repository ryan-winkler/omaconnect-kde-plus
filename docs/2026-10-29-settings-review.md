# Settings, file-drop and outside review — 29 October 2026

Identity note: this report describes the previous development identity. It does not establish runtime or migration acceptance for the current `Omaconnect.plus` ID. See [current verification](VERIFICATION.md).

**Decision: continue the dedicated Plus Settings window and native KDE handoff.**
The separate 50-scenario/RICE report challenges full native control duplication
and a module installer. RICE inputs remain hypothetical planning assumptions.

## Independent reviews and reconciliation

Claude and Antigravity each completed an independent restricted/analysis-only CLI
review of the same sanitized design brief and public code excerpts. Claude's CLI
metadata identifies claude-sonnet-5-5; Antigravity returned SUCCESS, with backend
identity not independently verified. No private config, credentials, peer inventory
or raw chat was supplied. Neither CLI received pixels or claimed screenshot tests.
Both favored the native-owner approach with focused corrections.

| Finding | Disposition |
| --- | --- |
| Both claimed the fixed fork ID collides with the original | Rejected for the inspected snapshot. The original `omaconnect` and previous development identity were distinct. Source manifest, side-by-side installation and a parity check established that historical isolation. The later `Omaconnect.plus` change requires its own migration and readback. |
| Header/list/native handoff could use different peers | Current Panel.device is an alias of service.selectedDevice; the controller passes selectedDeviceId. No second authority exists. Keep the selected context visible and native launch argv checks. |
| Choose could replace an existing reviewed draft while Drop refused | Fixed. Both now preserve draft/busy boundaries and require clear/review before another selection. |
| Raw search field and mixed typography | Fixed with native Kit.TextField and shared font tokens. |
| Native Plugin Settings is hidden for offline/unpaired peers | Fixed explanation. Search remains available from reported metadata; the native route stays discoverable without inventing usable permission state. |
| No clear scroll affordance for long pages | Fixed with a visible native scroll thumb when overflowing; actual Qt mouse-wheel test reaches lower settings. |
| Preferences need another queue to avoid concurrent config writers | Not added. Fixed IPC delegates mutation to the existing serialized native shell JS/config owner. No helper writes shell.json itself. Host readback checks preserve the original entry and both keys. |
| BTH helper-path suffix proves a reviewed script | It does not. Existing explicit trusted-user helper configuration stays user-owned and bounded; no automatic installation or claimed code attestation. |
| Unknown IDs hidden under identical generic titles | Fixed. Unlabelled safe IDs use their actual ID and remain searchable. |
| Scope labels imply that all choices are per-peer | Fixed. Computer-wide preferences are labelled; device-specific appearance and native context remain explicit. |
| Ping default belongs beside Ping visibility | Fixed in Device features. |
| BTH copy said controls appear below Settings | Fixed: controls appear in Devices. Save confirmation is short and contextual. |
| Drag readiness only changed color; normal popover can close | Fixed text on drag; persistent normal Send window remains while file manager has focus. Copy only; no autosend. |
| Successful Ring means sound was heard | Fixed. CLI acceptance describes a request; known-unloaded Ring gives native settings next step. |

An independent fresh-context native visual reviewer inspected six filled captures
at 720/520 widths. Its first pass found two P2 items: mixed fonts and invisible
scroll continuation. Both were resolved in one batch. Its single follow-up scored
both resolved and shipped those fixes at that scope. It did not certify actual
user theme, physical assistive technology, RTL or a real Wayland file-manager drag.
No web detector was used: its HTML/CSS rules do not evaluate native QML.

## Runnable evidence and open checks

The complete runner passes 152 Python tests and three JavaScript suites, manifest
validation, shell syntax and QML lint with host/unqualified warnings. Native
fixtures cover 19 Settings assertions, 27 keyboard assertions, 9 drop assertions,
6 persistent-window assertions and 9 network preference assertions, with fake state
and providers. They include real Qt keys/mouse wheel but not a physical external
file-manager drag. A loaded-state Ring regression executes the actual JS entry.

The ring investigation found the phone's Find My Phone module explicitly disabled
and endpoint absent on the laptop, enabled/loaded on the desktop. The exact failed
user incident still needs host/target confirmation; no audible ring or native
plugin change was issued by the investigation or fix.

Production installation and current live readback are recorded separately.
Do not infer live transfer, native module permission, AT or offsite acceptance
from these fixtures or the 50 synthetic scenarios.
