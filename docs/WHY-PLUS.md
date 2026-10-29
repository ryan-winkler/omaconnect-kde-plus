# Why choose Omaconnect KDE Plus?

**Choose Plus when you want a configurable device view, normal file selection with review, and explicit links to your existing network tools.** Keep Jitendra's OmaConnect when its current workflow meets your needs. Both use KDE Connect; Plus does not introduce a new sharing protocol or grant extra phone permissions.

This comparison uses the actual upstream **1.5.0** snapshot at [`71282d2`](https://github.com/jitendradara12/omaconnect/tree/71282d2042b1a1cda1cb1cac84251694eaabb7cb), not an assumption about every future upstream release. The Plus column describes implemented source. Device acceptance and publication have their own [verification record](VERIFICATION.md).

## Feature matrix

| Task | Jitendra's OmaConnect at the pinned base | Omaconnect KDE Plus | Owner or limit |
| --- | --- | --- | --- |
| Pair and see devices | Pairing requests, verification, unpairing, reachability, battery and cellular data. | Retains these KDE-backed tasks and local device context. | KDE Connect owns identity, trust and permissions. These are inherited capabilities. |
| Choose a bar or device icon | Automatic device-type icon or fixed fallback, controlled by a display preference. | Presets, installed theme icons, custom symbols, validated local PNG/SVG, preview/Apply/Cancel and per-device aliases. | Display metadata does not rename a KDE identity. See [icon sources/storage](ICONS.md). |
| Select a file | Recent matching files from fixed home folders, shown through `omarchy-menu-select`; one returned path. | Desktop portal file chooser with bounded multiselect; persistent Send window accepts local Copy drops. | Regular local files only, up to 100 files/1 TiB. No folder archive or remote URL import. |
| Review before sending | File selection proceeds to the KDE submission path. | Separate recipient/count/size review and explicit Send. Changing device selection does not retarget the reviewed batch. | A drop creates a draft. It does not send. |
| Understand the result | Shows “File sent” after CLI success and “cancelled” after stopping the process. | Separates accepted request, failure, unknown timeout and unconfirmed cancellation; bounded session activity. | CLI success still does not prove receipt. The KDE path API retains a later-open race. |
| Configure daily shortcuts | Per-action visibility flags and a fixed toolbar order. | Add/remove/reorder a verified action catalog; Ring is optional, with readiness and recovery guidance. | Shortcut configuration does not enable native modules or execute an action. |
| Find settings | Omarchy widget preferences. | Dedicated Appearance, Connections, Quick actions and Device features pages with helper text and native-owner links. | One settings home per domain; native permissions stay in KDE Connect. |
| Reach native KDE features | Common actions and a generic native-app launcher. Discovery maps a fixed subset of module IDs. | Search the safe returned native inventory, distinguish support/loading and open the selected peer in native KDE Connect. | Native Plugin Settings manages installed modules; it is not an add-on download store. Unknown safe IDs remain visible without invented commands. |
| Connect over existing networks | Tailscale peer discovery and custom LAN/VPN address entry. | Separate Tailscale, MikroTik Back to Home and other WireGuard visibility switches, short guides and existing-owner handoffs. | Plus does not provision VPNs. Switches show/hide controls; they do not connect a tunnel. |
| Use existing BTH policy | No BTH-specific card in the pinned base. | Existing controller's Automatic/On/Off card, observed state and trusted helper-path setting. | The existing helper owns policy and keys; missing/invalid state disables unsafe actions. |
| Manage saved route hints | Adds/removes KDE custom addresses. | Per-KDE-identity approval records, source labels, opt-in rediscovery, baseline preservation and separate removal review. | An address or source label does not prove device identity. No UniFi collector is added. |
| Link Syncthing identities | No Syncthing association surface in the pinned base. | Explicit local association of full IDs and handoff to the existing Syncshell panel. | No extra engine, secret import or inline sync controls. |
| View media artwork | Provider album-art URI is bound to QML Image sources in the pinned base. | The 0.1.1 privacy change keeps text/player controls and removes rendering/fetching of provider-supplied album-art URLs. | This reduces that resource-loading surface; it does not certify the whole media or network stack. |
| Install prerequisites | In-panel dependency/firewall helpers in the upstream snapshot. | Manual supported Omarchy package instructions; inherited privileged setup entry points are removed from the 0.1.1 identity update. | The user/system owner manages packages and firewall policy. See [installation](../README.md#install-and-open). |
| Use existing media, commands, SMS, clipboard and text | Already supplied through KDE Connect/native tools. | Retains them, adds guidance and corrects sender-capability checks for media/remote commands. | Availability depends on both platforms, loaded modules and permissions. These are not new protocols. |

Upstream evidence: [manifest/preferences](https://github.com/jitendradara12/omaconnect/blob/71282d2042b1a1cda1cb1cac84251694eaabb7cb/manifest.json), [file picker](https://github.com/jitendradara12/omaconnect/blob/71282d2042b1a1cda1cb1cac84251694eaabb7cb/scripts/pick_file.sh), [controller](https://github.com/jitendradara12/omaconnect/blob/71282d2042b1a1cda1cb1cac84251694eaabb7cb/KdeConnectController.qml), [bar icon](https://github.com/jitendradara12/omaconnect/blob/71282d2042b1a1cda1cb1cac84251694eaabb7cb/BarWidget.qml), [media artwork](https://github.com/jitendradara12/omaconnect/blob/71282d2042b1a1cda1cb1cac84251694eaabb7cb/components/MediaPlayerSection.qml). Plus evidence: [contracts](CONTRACTS.md), [help map](HELP.md), [capability audit](2026-10-29-kde-capability-audit.md) and owning source files linked in [contributing](../CONTRIBUTING.md).

## Audience and decision

The audience is an Omarchy user who already uses KDE Connect, plus contributors who must maintain the fork. Decide whether the daily improvements above justify another UI to maintain. The recommended scope stays a narrow UI fork over existing engines. The technical plugin/IPC/storage ID is **`Omaconnect.plus`**; the public display name is **Omaconnect KDE Plus**.

## Core message

Plus makes device tasks easier to find and review while keeping KDE Connect and existing network tools responsible for their own jobs.

## Storyline

| Section | Headline | Purpose |
| --- | --- | --- |
| Existing foundation | OmaConnect already supplies useful KDE-backed device tasks. | Credit the base and prevent invented differentiation. |
| Daily friction | Icon choice, recent-file selection and fixed shortcuts do not fit every workflow. | Name concrete reasons to consider Plus. |
| Focused change | Plus adds choice, review and clear settings/owner routes. | Explain the user result before the implementation. |
| Trust boundary | Native owners retain pairing, permissions, VPN policy and synchronization. | Prevent an “all-in-one” claim from becoming a second protocol stack. |
| Evidence | Installed receipts, fixtures, scans and physical acceptance are separate. | Let the user assess what is proven. |
| Decision | Adopt Plus for these tasks; contribute reusable fixes upstream. | Keep the fork's maintenance cost bounded. |

## Pyramid logic

The recommendation has three supports: task control, discoverability and ownership. The icon/file/action work gives control with explicit drafts and recovery. Settings and nearby help expose existing features without a second native module manager. Domain helpers keep protocol and policy changes with their owners. The matrix and source links support these claims. A historical receipt does not validate the new technical ID.

## Hostile questions and red/blue decisions

| Challenge | Answer and evidence boundary | Decision |
| --- | --- | --- |
| Why fork instead of using the original? | The matrix identifies specific UI changes. Existing KDE tasks alone do not justify a fork. | Keep the fork narrow and propose reusable fixes upstream. |
| Does “Plus” mean better transfers or new protocols? | The same KDE engine submits files. Plus improves selection, review and honest state. It cannot prove delivery from CLI status. | State the engine and receipt limits beside sharing controls. |
| Why not put every native module switch in this window? | That duplicates native permissions and device state. Search and selected-device handoff expose the existing feature set. | Keep native KDE Plugin Settings authoritative. |
| Do network switches connect or secure the network? | They control display/adapter visibility. Existing providers and the reviewed BTH helper own connections and policy. | Keep intent, observed state and reachability distinct. |
| Is the renamed identity already tested because the old release worked? | No. Old receipts used an earlier development ID. Version 0.1.1 has no supported public upgrade path. Preserve owner development installs with separate checks. | Require `Omaconnect.plus` manifest, settings, storage, IPC and fresh-install readback evidence. |
| Did the drag test also prove Send and delivery? | No. The owner accepted external drag, correct review and Copy/source retention before Send on both computers. | Close only that pre-Send portion. Actual post-drop Send/delivery remains open. |
| Do security tools prove this is secure? | CodeQL can analyze Python and workflow code; secret scanning/push protection detect supported secret patterns; CodeRabbit reviews a scoped change. Their actual results are recorded separately. | Keep scanner capabilities visible and state language/scope limits. No certification claim. |
| Can more audits replace device testing? | Synthetic scenarios and red/blue challenges find questions; they cannot generate physical receipts. | Recheck changed boundaries and open acceptance items. Avoid another review loop after a copy fix. |

This narrative follows Strategy21 Narrative Builder: answer first, then evidence, tradeoffs and skeptical questions. It is a decision aid, not market research or a score from independent users.
