# Upstream work review — 29 October 2026

**Keep the narrow fork. Adopt useful upstream fixes by behavior, not by PR title or merge state.** The audit found a shell syntax gate gap, and the current release update fixes it with per-file checks. The focused negative fixture confirms the fix. Structured D-Bus parsing is a useful adapted follow-up. Most closed items are already inherited or superseded; a closed issue does not prove every proposed acceptance criterion was implemented.

The exact product ID is **`Omaconnect.plus`**. The display name remains **Omaconnect KDE Plus**. This report does not change protocol ownership, install providers, or authorize upstream changes.

## Scope and evidence

The requested upstream is [Jitendra Dara’s OmaConnect](https://github.com/jitendradara12/omaconnect). The fork’s pinned upstream base is [`71282d2042b1a1cda1cb1cac84251694eaabb7cb`](https://github.com/jitendradara12/omaconnect/tree/71282d2042b1a1cda1cb1cac84251694eaabb7cb), version 1.5.0. The review used paginated GitHub API inventories, every PR’s details and changed-file patches, all closed non-PR issue bodies and event records, local ancestry checks, API comparisons for nonlocal merge commits, and current source.

Inventory at inspection:

- **22 pull requests:** 4 open and 18 closed; the closed set contains **15 merged and 3 unmerged**.
- **11 closed non-PR issues.** GitHub’s issues endpoint also returns PRs; those were excluded from the issue counts.
- **1 open non-PR issue**, #17, was also inspected because it directly concerns the file picker.
- Of the 15 PRs marked merged, **13 merge commits are ancestors of the pinned base**. #21 and #26 have divergent merge histories; their relevant behavior is nevertheless present in later source. An unavailable/nonancestor merge SHA is not proof that its feature is absent.

The source worktree was undergoing the 0.1.1 identity/security update. Findings below name behaviors and functions, not an assertion that every later parent edit was absent. Recheck only the changed boundary after a fix. No real device action, install, file transfer, VPN change, native setting change, upstream comment, or Git mutation ran in this audit.

## Prioritized decisions

| Priority | Item | Evidence and decision | Acceptance before adoption |
| --- | --- | --- | --- |
| P2 — fixed in current release update | [PR #34](https://github.com/jitendradara12/omaconnect/pull/34): syntax-check every shell script | At initial inspection, `bash -n scripts/*.sh` checked only the first file. The current runner uses a per-file syntax loop. An owned runner fixture returned **0** for the old gate and **2** for the fixed gate when a later-sorted script was invalid. This proves the coverage fix; it does not claim a syntax error existed in product scripts. | Focused negative fixture passed. Real test stages and providers were replaced by no-op stubs in this gate-specific probe; it is not a whole-suite receipt. Preserve private HOME/runtime isolation and existing JS/native checks. |
| P2 — complete current hardening | [PR #32](https://github.com/jitendradara12/omaconnect/pull/32): plain-text provider values | Most corresponding inherited `Text` sinks are already hardened in Plus. The new Plus Activity view is outside that PR’s file list. The parent’s independent review found its peer-name `AutoText` path and changed the current component to `Text.PlainText`. Do not assume an upstream patch covers newly added components. | Real-component hostile peer-name image probe makes zero requests after `Text.PlainText`, while the visible peer string and honest activity result remain intact. |
| P2 — small defensive follow-up | [PR #33](https://github.com/jitendradara12/omaconnect/pull/33): SMS ID input guard | `scripts/open_sms.sh` currently quotes the ID as a single argv value but lacks the input guard used by sibling helpers. Adopt a compatible bounded ID check and exact error/argv tests. Do not call whitespace in quoted argv shell injection or claim RCE without a reachable exploit. | Valid current IDs and empty/default launch still work; malformed/overlong IDs refuse without launching the app; missing binary remains a distinct unavailable result. |
| P2 — adapted follow-up | [PR #33](https://github.com/jitendradara12/omaconnect/pull/33): structured D-Bus parsing | JSON avoids text-format ambiguity and `GetAll` can reduce per-device calls. The proposed implementation freezes upstream’s **14-field** device output and uses `PLUGIN_FILTER`; a direct import would lose Plus’s loaded-state columns and safe native/third-party inventory. It also preserves provider artwork URI publication. | Keep Plus’s current 16-field contract, full safe plugin IDs, loaded-known state, correct sender/receiver capability direction and no artwork fetch. Add strict type/size/count/deadline fixtures and exact native argv. Do not import the whole PR unchanged. |
| P3 — guidance first | [PR #23](https://github.com/jitendradara12/omaconnect/pull/23): native KDE appearance and contact names | This PR is closed **unmerged**. Its proposed hook writes global `kdeglobals` and affects other KDE apps; its dependency installer/AUR assumptions are not a current verified package contract. Offer native owner guidance before adding any setup mechanism. | Verify current package availability and the real missing contact backend; document an optional supported command only when needed. Any global theme hook needs explicit scope/ownership and rollback. Do not revive automatic installers. |
| P3 — no bulk import | [PR #28](https://github.com/jitendradara12/omaconnect/pull/28): formatting/hierarchy | Closed unmerged and described as “no code change,” yet the patch touches broad hierarchy/source structure. Current native fixtures and domain components already exist. A large formatting merge gives little user benefit and risks stale bindings. | Accept only a separately reproduced layout defect and its smallest fix. Do not reformat the whole controller for conformity. |
| No action | [PR #1](https://github.com/jitendradara12/omaconnect/pull/1): image optimization | Closed unmerged preview optimization. Plus already has a new native fixture preview with invented data; the marketplace also optimizes preview assets. | Keep source/license attribution and actual preview checks. No extra optimizer or large asset pipeline is needed. |

The current [Why Plus matrix](WHY-PLUS.md) is the user-facing comparison. This report is the contributor follow-up map, not a promise to implement every idea.

## Every pull request

“Already inherited” means the relevant source is in the pinned ancestry or current implementation. It does not turn an old PR test count into a current runtime receipt.

| PR | Upstream state | Current fork disposition |
| --- | --- | --- |
| [#1 — Optimize images](https://github.com/jitendradara12/omaconnect/pull/1) | Closed, unmerged | Not adopted; current preview supersedes the optimization target. No user-facing gap established. |
| [#8 — Keyboard shortcut formatting](https://github.com/jitendradara12/omaconnect/pull/8) | Merged; ancestor | Historical README correction inherited; current shortcuts/help have their own documentation. |
| [#11 — Hover chooses bottom device](https://github.com/jitendradara12/omaconnect/pull/11) | Merged; ancestor | Already inherited. Current device delegate selects on explicit click, with guarded `modelData`; reviewed file batches retain their original recipient independently. |
| [#12 — Large search roots break File action](https://github.com/jitendradara12/omaconnect/pull/12) | Merged; ancestor | Old picker fix inherited in history, then superseded by the portal chooser and bounded review. Do not restore the old search menu as the primary picker. |
| [#14 — Typed empty device list](https://github.com/jitendradara12/omaconnect/pull/14) | Merged; ancestor | Already inherited: discovery accepts `(@as [],)` and tests cover the empty state. Empty is not the same as daemon unavailable. |
| [#15 — Preferences/security transparency](https://github.com/jitendradara12/omaconnect/pull/15) | Merged; ancestor | Preferences and common UI improvements inherited; Plus supersedes fixed shortcuts with the catalog and removes the privileged setup launchers rather than preserving their unsafe invocation. |
| [#16 — Update preview](https://github.com/jitendradara12/omaconnect/pull/16) | Merged; ancestor | Historical asset update inherited; Plus uses its own preview. |
| [#19 — Tailscale discovery/refinements](https://github.com/jitendradara12/omaconnect/pull/19) | Merged; ancestor | Inherited foundation. Plus deliberately makes optional integrations explicit, covers BTH/WireGuard as well, and uses approved per-identity route hints. Do not resurrect hidden automatic discovery. |
| [#20 — Media controls](https://github.com/jitendradara12/omaconnect/pull/20) | Merged; ancestor | Text, player selection and Previous/PlayPause/Next are inherited and retained. The PR body advertises timeline/volume, but the actual merged patch does not implement them and includes a test that the README does not promise volume. These are proposal-description overclaims, not a proven lost feature. Provider artwork loading is removed by Plus privacy hardening. |
| [#21 — Multiple media players](https://github.com/jitendradara12/omaconnect/pull/21) | Marked merged; divergent merge SHA | Behavior is present through later refactoring: player list, explicit selection and empty-state logic. Do not cherry-pick an old divergent branch over the later implementation. |
| [#23 — Theme native windows/contact names](https://github.com/jitendradara12/omaconnect/pull/23) | Closed, unmerged | Not implemented as a global setup feature. Evaluate optional native guidance and verified contact-backend requirements; do not copy theme hooks/installers wholesale. |
| [#24 — Battery beside icon](https://github.com/jitendradara12/omaconnect/pull/24) | Merged; ancestor | Already inherited as `showBarBattery`, surfaced in Appearance with helper text. |
| [#25 — Refactor](https://github.com/jitendradara12/omaconnect/pull/25) | Merged; ancestor | Main controller/media/lifecycle refactoring inherited. This is also evidence for behavior described in divergent #21/#26. |
| [#26 — Direct media process ID](https://github.com/jitendradara12/omaconnect/pull/26) | Marked merged; divergent merge SHA | Current code uses `mediaActionProcess.running`, not `root.mediaActionProcess.running`, for the id-bound process. Behavior present; no extra merge required. |
| [#27 — Replacement-bar service bridge](https://github.com/jitendradara12/omaconnect/pull/27) | Merged; ancestor | Already inherited: own `bridge/Bridge.qml` rendezvous and native-facade fallback. Preserve Omarchy’s service-less replacement-bar trust boundary. |
| [#28 — QML format/hierarchy](https://github.com/jitendradara12/omaconnect/pull/28) | Closed, unmerged | No blanket adoption. Current component boundaries and native checks are the basis; reproduce any hierarchy problem before changing it. |
| [#29 — Rewrite tests](https://github.com/jitendradara12/omaconnect/pull/29) | Merged; ancestor | Existing inherited test foundation. Plus adds actual helper/model/native fixtures; tests that mirror source strings are not proof of a physical journey. |
| [#30 — hjkl navigation](https://github.com/jitendradara12/omaconnect/pull/30) | Merged; ancestor | Already inherited and extended with real Qt keyboard checks and native Button focus/activation. Retain regressions; do not reapply old key handling. |
| [#31 — Privileged setup/argv/pairing ID](https://github.com/jitendradara12/omaconnect/pull/31) | Open, unmerged | Setup issue is superseded by removal of privileged scripts, service/controller methods and UI entry points. Its defensive pairing-ID proposal is a separate input-boundary question; validate it against current daemon IDs rather than copying setup machinery back in. |
| [#32 — Plain-text device strings](https://github.com/jitendradara12/omaconnect/pull/32) | Open, unmerged | Security principle already applied in most Plus sinks; independently check new Plus components and native-kit sinks. Parent’s Activity regression/fix is required because that component is not in this upstream patch. |
| [#33 — Structured busctl JSON/SMS guard](https://github.com/jitendradara12/omaconnect/pull/33) | Open, unmerged | Small SMS guard eligible; structured parsers are a useful adapted follow-up. A wholesale import would regress full plugin inventory/loaded state and preserve unwanted art data. |
| [#34 — Staged CI/validation](https://github.com/jitendradara12/omaconnect/pull/34) | Open, unmerged | Per-script syntax checking is now fixed and the focused invalid-later-script fixture passes. Python discovery and CI already exist in Plus. Preserve existing pinned actions, permissions, private runtime and explicit native skips; add a shell-test convention only when a real shell suite requires it. |

## Every closed non-PR issue

| Issue | Current evidence and disposition |
| --- | --- |
| [#2 — Split BarWidget/Panel](https://github.com/jitendradara12/omaconnect/issues/2) | Separation/Loader exists. Current BarWidget is larger than the proposed approximate 50 lines because appearance and native IPC have real responsibilities. Line count alone is not a defect. Keep the component boundary; no cosmetic size target. |
| [#3 — D-Bus discovery/polling](https://github.com/jitendradara12/omaconnect/issues/3) | Main discovery uses the external helper; generation guards reject stale completions; fallback timer runs only when the signal process is down. Current parser robustness is a distinct #33 follow-up. |
| [#4 — Hygiene/manifest](https://github.com/jitendradara12/omaconnect/issues/4) | No root `opencode.json`; `.gitignore` covers Python cache/scratch; validator resolves native PATH/Omarchy paths; root preview and manifest exist. New exact-ID validation is a separate release receipt. |
| [#5 — Dynamic size/scroll](https://github.com/jitendradara12/omaconnect/issues/5) | Bounded native fitting/ScrollView and independent Settings/Send windows are present. Existing width/page fixtures and owner pre-Send checks have explicit scope. Large text/RTL/AT and every tiling layout are not universally accepted by closing this issue. |
| [#6 — Composers/focus modularity](https://github.com/jitendradara12/omaconnect/issues/6) | Components and styled input tokens are implemented. The literal proposed all-`FocusScope` rewrite is not: Panel still uses explicit `focusSection` states. No new behavioral failure was reproduced. Keep tested ordinary keyboard semantics and modularize further only when a real focus defect justifies it. Closed is not proof of every design bullet. |
| [#7 — FileDialog segfault](https://github.com/jitendradara12/omaconnect/issues/7) | The share path uses the separate Python desktop-portal chooser rather than in-process `QtQuick.Dialogs.FileDialog`. This preserves the normal graphical picker without reinstating the reported popup-parent crash path. |
| [#9 — Phone icon](https://github.com/jitendradara12/omaconnect/issues/9) | Superseded by labelled presets, theme search, custom glyph/image and per-device aliases. No single global glyph substitution is required. |
| [#10 — Hover chooses bottom peer](https://github.com/jitendradara12/omaconnect/issues/10) | Fixed in ancestor PR11; explicit click selection remains. Draft/operation recipient identity is independently frozen in Plus. |
| [#13 — Empty means daemon stopped](https://github.com/jitendradara12/omaconnect/issues/13) | Fixed in ancestor PR14 and retained typed-empty parsing/tests. Distinguish no devices from unavailable service. |
| [#18 — Null modelData on network change](https://github.com/jitendradara12/omaconnect/issues/18) | Current delegate guards `modelData` for pending/current/cursor/icon/name/state and click. No unguarded reported access was found in that delegate. Preserve these guards during later parser/UI work. |
| [#22 — Battery beside icon](https://github.com/jitendradara12/omaconnect/issues/22) | Implemented by ancestor PR24 and retained as an explicit Appearance preference with a missing-report explanation. |

## Open issue directly relevant to Plus

[#17 — default file picker instead of fzf search](https://github.com/jitendradara12/omaconnect/issues/17) remains open upstream. Plus implements the desktop portal multiselect chooser and an independent drop-review window. The prior owner check accepted real pre-Send drag/review/source retention on laptop and desktop. That is not a claim of a new post-drop Send/delivery receipt or of all portals/file managers.

## Source ownership and next contributions

Keep each candidate in its owning domain:

- Validation gate: `scripts/validate.sh` and a regression that puts an invalid script after a valid one.
- Native input contracts: `scripts/open_sms.sh` and exact-argv/no-launch-on-invalid-input fixtures.
- Discovery/media parser: helpers plus the declared controller wire contract; preserve full native feature visibility.
- Native appearance/contacts: documentation and the existing KDE/system owner first.
- Focus/layout: current native UI fixtures and a reproduced user journey before extraction.

Credit the upstream PR and author when adapting code. Keep the original MIT notices. Before implementing a deferred item, check its current upstream state and the corresponding Plus code again. This report is a dated audit of public evidence; it is not a new protocol roadmap or a security certification.
