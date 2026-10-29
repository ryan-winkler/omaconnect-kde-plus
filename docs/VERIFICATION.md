# Current verification — 29 October 2026

Product: **Omaconnect KDE Plus 0.2.0 candidate**. Current case-sensitive plugin/IPC/storage ID: **`Omaconnect.plus`**.

**Identity update:** the publication, hosted checks and installed receipts below used the previous development ID. They do not establish new-ID migration or runtime acceptance. The release task must add the exact new revision and separate receipts.
Historical published release: [`v0.1.0`](https://github.com/ryan-winkler/omaconnect-kde-plus/releases/tag/v0.1.0),
commit `256d50c0c20b4bdfcef73e4111317679b817cb13`. Earlier comparison revision was `f8b3e11`.
This file separates implementation checks, installed runtime, physical acceptance
and publication. [Historical snapshots](VERIFICATION-HISTORY-2026-10-29.md) retain
older observations; their blocked/staged status is superseded where shown here.

## Evidence before the identity update

| Boundary | Evidence | Limit |
| --- | --- | --- |
| ARM helper/model/UI fixtures | Final integrated preparation: 164 Python tests and three JS suites pass; manifest validation, shell syntax and local Markdown targets pass. | Private temporary state and fake providers. |
| Migration | Native inline, legacy nested and string entries; output uses native inline settings. Exact rollback, conflict refusal and unrelated later edits covered. | Stages reviewed candidates only; no live apply. |
| Daily action accessibility | Regression first failed on missing button role. Corrected native Button passes 24 actual Qt assertions: names/help, Tab, Enter, Space, accessible press, disabled refusal and Stop. | Offscreen component; no Orca acceptance claim. |
| Settings and sharing UI | Native domains, six width/page captures, scrolling, back/close/Escape; drop/controller inspection; persistent Send window and explicit review. | Owner confirmed real external file-manager drag on both laptop and desktop: correct file/recipient review and original retained. No new transfer was part of that check. |
| Installed laptop, ARM | Original and fork enabled side by side by explicit owner request. Published `256d50c` downloaded through native `omarchy plugin update`; supported shell restart, shell ping and mapped new Settings title confirmed. Appearance and connection preferences retained. | Original UI remains active beside the fork by owner request. |
| Installed desktop, x86_64 | Published `256d50c` updated from the public repository; mapped new Settings and shell ping confirmed after supported shell restart. Original source, preferences, metadata and layout retained. | Source checkout alone does not prove runtime reload. |
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

- Pre-Send external file-manager drag review is owner-accepted on both actual computers: correct file/recipient and source retained; the check stopped before Send. Actual post-drop Send and delivery remain untested. The earlier chooser-based receipt does not close this gate.
- Assistive technology, RTL, scale 2 and reduced-motion acceptance remain open.
- A command accepted by KDE Connect is not a delivered file or audible sound.
- No new offsite transfer or fleet-wide network conclusion is claimed.
- CodeRabbit posted a real `COMMENTED` review on PR #3 at `b6860b9`, with one minor acceptance-wording finding. That review covers the earlier documentation change, not the current identity/security diff. Marketplace submission and acceptance remain separate.

These limits stay in release notes. The fork does not advertise a new protocol,
VPN provisioner, Quick Share engine, native plugin store or synchronization core.

## Historical release receipt before the identity update

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
At the preparation check, the available browser was signed out and no bot review
was observed. The owner then confirmed CodeRabbit access. PRs #1 and #2 had already merged; PR #3 supplied a real documentation change. The observed scoped review is recorded below.


### Historical publication and installed runtime

The earlier release `v0.1.0` was published from `256d50c` under the previous development identity. Main-branch
[Functional run](https://github.com/ryan-winkler/omaconnect-kde-plus/actions/runs/40917326019)
and [CodeQL run](https://github.com/ryan-winkler/omaconnect-kde-plus/actions/runs/40917326011)
passed that exact commit. Main requires the three observed fixture/analysis checks,
pull requests and resolved conversations; force pushes and branch deletion are disabled.

Both installed copies now track the public repository. Native update succeeded on
ARM and x86_64. A supported shell restart replaced cached QML, then the new
**Omaconnect KDE Plus Settings** window mapped on both hosts. Hash/readback checks
preserved the original plugin, shell settings, bar entries, private appearance,
saved-address metadata and the existing BTH helper. No provider mode change,
permission toggle, pairing or real transfer ran during the update.

The [marketplace submission](https://github.com/omacom/omarchy-plugin-marketplace/issues/13289)
is open. Listing approval belongs to marketplace maintainers. See that issue for
current bot validation and exact-commit review state. Do not infer listing from
submission or a retained approval label.

All five in-app official provider-help URLs returned HTTP 200 at the release
check. The local Markdown guide has a registered default viewer on the tested
laptop. External services and desktop associations may change later.


### Owner acceptance follow-up — 29 October 2026

The owner confirmed that the real file-manager drag check passed on **both the
laptop and desktop**. The check asked for the correct file and recipient at review,
with the original file retained; the check stopped before Send. This accepts only the pre-Send external-drag review portion of RP22/G5 on these two installations. The explicit post-drop Send result and delivery portion remain open. It does not claim other file managers/platforms or broad assistive-technology acceptance. Product code and provider ownership are unchanged.

The owner also confirmed repository app access. PR #3 subsequently received the observed CodeRabbit review recorded below. That review covered the earlier documentation change; it did not cover the later technical identity and security changes.


### Observed CodeRabbit review and wording correction

[PR #3 review](https://github.com/ryan-winkler/omaconnect-kde-plus/pull/3#pullrequestreview-5703659944) is an observed `COMMENTED` review of the three-document change at `b6860b9`. It identified one minor issue: G5 combined a required explicit Send result with evidence that stopped before Send. This document and the persona gate now preserve that distinction. The earlier LAN receipt is not a substitute. New identity/security code needs its own checks and review.


### 0.2.0 source changes awaiting final receipts

The current target changes plugin/IPC/storage identity to `Omaconnect.plus`, removes inherited privileged setup launchers, and stops rendering/fetching provider-supplied media-art URLs while keeping text/player controls. The parent release task must record final-source verification, hosted results, migration and both installed readbacks. Earlier 0.1.0 results above do not prove these changes.

## 0.2.0 changed-boundary QA

The identity/security/settings implementation uses `Omaconnect.plus`. The integrated release gate passed **225 Python tests and three JavaScript
suites**, native manifest validation and per-file shell syntax. Local Markdown
file targets also pass. The exact source revision is attached to PR #3; installed
publication receipts are recorded separately. Earlier scans remain bound to their snapshots.

Fresh focused checks cover private text/Ping through stdin and a fake native bus,
no payload in live helper argv/environment/output, actual media/Activity sinks,
shared-source snapshot replacement with an effective raw-path negative control,
explicit cancellation acknowledgement, removed privilege helpers and SMS bounds.

The settings completeness pass adds safe Syncthing draft/readback behavior,
optional section visibility and initial collapse, 18 reviewed actions, and one
Copy-only drop boundary for both Send and the actual bar icon. The native bar
integration opens a persistent review window for the fixed peer and does not
submit. These Qt calls are controlled fixtures, not a real file-manager drag.
The owner's earlier physical pre-Send drag acceptance remains scoped to the Send
window and previous identity on both computers. Post-drop Send/delivery stays open.

Both hosts had KDE Connect `26.08.2-1`. Fresh package checks used temporary databases
and found no KDE Connect update. No system packages, phone permissions, VPN
profiles, router settings or KDE pairings changed during these checks.

See [settings audit/frontier panel](2026-10-29-settings-completeness-audit.md),
[privacy and remediation](security-privacy-review.md),
[Standard scan coverage](security-scan-review.md),
[scoped outside voices](final-outside-review.md) and
[full upstream review](UPSTREAM-REVIEW.md).

Final product-source digest (49 runtime/manifest files):
`aca8f7aa1693f3d66adcb2f6cdba7d93b3367eb37844f2e4b17b4a456e4e9f07`.
The last source change reserves a themed scrollbar gutter after inspection of the
six native captures. The final gate retains QML host/unqualified-type diagnostics;
this is not a warning-free lint claim. Native fixtures substitute providers and
use a private owned namespace root; they do not relax production ownership checks.

### CodeRabbit review corrections

The observed full [review5704818421](https://github.com/ryan-winkler/omaconnect-kde-plus/pull/3#pullrequestreview-5704818421)
covered `cd3b54c` and posted five Minor items. Verified repairs tighten watcher
topic signal, retain explicit gap evidence and recover from large comparisons,
make optional protected-file cache housekeeping best effort, isolate the
standalone transfer child HOME/cache, and mark the SMS guard implemented. The
additional cancellation-copy suggestion was applied. Focused checks first failed
for the changed cases and then passed. The post-review gate supersedes the prior
216-test source scope; no earlier scanner snapshot is silently expanded.

Biome could not parse Qt's valid `.pragma library` headers in its inspected JS
files. Native Qt loading and JS model checks cover those files; that tool gap is
not a product syntax error or a lint pass. Hosted CodeQL covers Python/workflows,
not KDE's native engine or all QML semantics.
