# Current verification — 29 October 2026

Product: **Omaconnect KDE Plus 0.1.0**, stable ID `ryan.omaconnect`.
Release preparation follows installed comparison revision `f8b3e11`.
This file separates implementation checks, installed runtime, physical acceptance
and publication. [Historical snapshots](VERIFICATION-HISTORY-2026-10-29.md) retain
older observations; their blocked/staged status is superseded where shown here.

## Current evidence

| Boundary | Evidence | Limit |
| --- | --- | --- |
| ARM helper/model/UI fixtures | Final integrated preparation: 164 Python tests and three JS suites pass; manifest validation, shell syntax and local Markdown targets pass. | Private temporary state and fake providers. |
| Migration | Native inline, legacy nested and string entries; output uses native inline settings. Exact rollback, conflict refusal and unrelated later edits covered. | Stages reviewed candidates only; no live apply. |
| Daily action accessibility | Regression first failed on missing button role. Corrected native Button passes 24 actual Qt assertions: names/help, Tab, Enter, Space, accessible press, disabled refusal and Stop. | Offscreen component; no Orca acceptance claim. |
| Settings and sharing UI | Native domains, six width/page captures, scrolling, back/close/Escape; drop/controller inspection; persistent Send window and explicit review. | External file-manager drag under the actual compositor is a separate owner check. |
| Installed laptop, ARM | Original and fork enabled side by side by explicit owner request. `f8b3e11` source/runtime and native Settings checked. Appearance and connection preferences retained. | Release revision update is recorded separately. |
| Installed desktop, x86_64 | Same comparison revision; mapped native Settings and shell ping confirmed after supported shell restart. Original source and layout retained. | Source checkout alone does not prove runtime reload. |
| Real phone receipt | One generated 109-byte text payload sent from the selected desktop to the owner-selected paired phone. Owner confirmed receipt, opening and matching check code. | One LAN text payload; not all types, multifile, empty file, cancellation or offsite acceptance. |
| Ring incident | Laptop native Find my phone module was disabled/unloaded; Ping was separate and available. UI now gives native settings recovery instead of assuming support means readiness. | Native choice preserved. No automatic enable or audible Ring test. |
| Network ownership | Independent Tailscale/BTH/WireGuard visibility switches; existing native owner/helper paths and source-scoped addresses covered. | No new VPN/profile/key/policy writer; no new away-network proof. |
| Help | Each user-facing feature has nearby guidance or a direct owner/task-guide link. Display preferences and persistent field labels included. | Remote help services may change; source links are fixed official URLs. |
| Reviews | Exactly 50 new synthetic RP journeys and 13 red/blue challenges; three reproduced helper defects fixed; outside review recorded separately. | Synthetic review is not research with 50 people or a security certification. |

## Reproduce local checks

```bash
./scripts/validate.sh
python3 .github/check_doc_links.py
```

The runner uses a temporary HOME/XDG/runtime, private D-Bus sessions, fake providers
and offscreen rendering. It unsets host display/session state. Missing native
prerequisites are explicit skips. QML lint has known host-import/unqualified-type
warnings; a successful run is not warning-free lint. Hosted Ubuntu CI lacks the
full Omarchy native runtime and must report that gap.

See [native fixture scope](../tests/NATIVE-QA.md),
[helper security review](release-security-qa.md),
[50-persona/red-blue review](release-personas-red-blue.md), and
[contributor/release checks](contributor-release-plan.md), and
[bounded outside reviews](release-outside-voices.md).

## Acceptance limits

- External file-manager drag on both actual desktops awaits owner acceptance.
- Assistive technology, RTL, scale 2 and reduced-motion acceptance remain open.
- A command accepted by KDE Connect is not a delivered file or audible sound.
- No new offsite transfer or fleet-wide network conclusion is claimed.
- GitHub CI, CodeRabbit app access, public installation and marketplace state
  need live receipts. A configuration file is not a completed external check.

These limits stay in release notes. The fork does not advertise a new protocol,
VPN provisioner, Quick Share engine, native plugin store or synchronization core.

## Final release receipt

The integrated preparation command completed successfully on 29 October 2026:
164 Python tests, all three JS suites, native manifest validation, shell syntax,
and the local Markdown target gate. Six native Settings captures at widths 520
and 720 show readable labels and bounded scrolling. The updated appearance page
shows its helper text and installed task-guide link. Native provider actions were
substituted in fixtures. QML lint warnings remain as described above.

The public fork has been renamed with history retained. Issues, Discussions,
private reporting, Dependabot alerts, secret scanning and push protection are
enabled; 16 labels and relevant topics are applied. Default CodeQL setup is not
configured, so the supplied advanced workflow will be the only CodeQL setup.
App access, actual hosted checks, installed release update and catalog submission
remain separate receipts. No pending item above is implicitly accepted.


Hosted checks passed for preparation revision `a5c3470`: Functional fixtures and
local links, Analyze Python, Analyze Actions and the CodeQL result check.
[Functional run](https://github.com/ryan-winkler/omaconnect-kde-plus/actions/runs/40916543422)
and [CodeQL run](https://github.com/ryan-winkler/omaconnect-kde-plus/actions/runs/40916543493)
are separate hosted receipts. Code scanning returned no open alerts at inspection.
Hosted native prerequisites remain explicitly skipped.

Antigravity completed its scoped public-source review with no findings. Claude
returned no review within its 240-second bound; no clean Claude result or
reviewer agreement is claimed. See the outside report for snapshot and CLI limits.
The browser is signed out of GitHub, so CodeRabbit app access is awaiting the
owner. Its configuration and explicit PR review request are present; no bot
review has yet been observed. This does not block the independent local checks.
