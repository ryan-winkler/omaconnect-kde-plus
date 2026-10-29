# Contribute to Omaconnect KDE Plus

**Start with one small change.** Documentation, design, accessibility, testing and code contributions are welcome. You do not need to know every provider or own every supported device.

KDE Connect owns pairing, its native modules and the device protocol. Existing network tools own VPN policy and keys. Syncshell owns synchronization. This fork joins their daily controls and explains the result.

## Find the right place

| Task | Start here | Check |
| --- | --- | --- |
| Improve help or report a confusing step | [Help map](docs/HELP.md), [support](SUPPORT.md) | The instruction names the task, result and next step. |
| Add or improve an icon | [Icon guide](docs/ICONS.md), `Appearance.js`, `components/AppearanceIcon.qml` | Source/license, preset parity and fallback. |
| Change icon selection, aliases or local identity links | `components/IconChooser.qml`, `AppearanceStore.qml`, `scripts/appearance.py` | Apply/Cancel, keyboard use, stable IDs and private atomic state. |
| Change sharing or file drops | `KdeConnectController.qml`, `TransferModel.js`, `components/SendWindow.qml`, `scripts/portal_files.py` | Fixed recipient, explicit Send, cancellation and honest delivery state. |
| Change quick actions | `ActionCatalog.js`, `components/QuickActionsSettings.qml` | Capability, order, labels, contextual help and disabled reasons. |
| Change native device features | `components/NativeFeaturesSection.qml`, `scripts/discover_devices.sh`, `scripts/open_app.sh` | Native ownership, exact device, readback and handoff failures. |
| Change connection guidance or address discovery | `components/NetworkOptions.qml`, `DiscoveryController.qml`, `DiscoveryModel.js`, `scripts/manage_addresses.py` | Opt-in sources, approval, input bounds and baseline preservation. |
| Change home access | `BthControlCard.qml`, `BthControlModel.js` | Existing helper contract; requested mode and observed state stay distinct. |
| Change settings navigation | `components/SettingsPanel.qml`, `scripts/network_preferences.py` | One home per domain, clear links to native settings, focus and narrow layouts. |
| Add a provider or change a contract | [Contracts](docs/CONTRACTS.md), [domain map](docs/2026-10-29-contribution-architecture.md) | Discuss ownership and failure modes before implementation. |

`good first issue` marks a bounded task with a useful starting point. `help wanted` marks work where another contributor can help. Maintainers should add a clear acceptance check before applying either label. You can ask for help before choosing a task.

## Share reusable improvements upstream

Offer reusable fixes and enhancements to the project that owns the behavior when appropriate. Keep a change here when it is specific to Plus, or record why an upstream contribution does not fit. An upstream offer is a reviewed proposal; it does not promise acceptance or an automatic merge.

| Behavior belongs to… | Contribution route |
| --- | --- |
| The original OmaConnect UI, launcher or helper | [Jitendra Dara’s OmaConnect](https://github.com/jitendradara12/omaconnect). Reproduce against its current source before proposing the smallest reusable change. |
| The KDE Connect protocol, daemon or native desktop application | [KDE Connect desktop source](https://invent.kde.org/kde/kdeconnect-kde), following [KDE’s contribution and reporting guidance](https://kdeconnect.kde.org/get-involved.html). |
| Android native modules, permissions or application behavior | [KDE Connect Android source](https://invent.kde.org/kde/kdeconnect-android), following the same KDE guidance. |
| Plus-specific settings, appearance metadata or integration UI | This repository. Explain the Plus requirement and retain the existing provider boundary. |

**Search before opening an issue or PR.** Check open and closed work in this fork and the owning upstream. If an existing proposal covers the behavior, link it and contribute relevant evidence or a focused follow-up there. Do not create a competing duplicate. Treat security reports through [SECURITY.md](SECURITY.md) and the affected upstream’s private reporting route first.

The 29 October 2026 audit found existing upstream proposals for [plain-text device values (#32)](https://github.com/jitendradara12/omaconnect/pull/32), [structured D-Bus parsing and SMS input validation (#33)](https://github.com/jitendradara12/omaconnect/pull/33), and [per-script syntax checks and CI (#34)](https://github.com/jitendradara12/omaconnect/pull/34), all by [riccelso](https://github.com/riccelso). Reference these proposals instead of opening duplicates. Recheck their current state and the exact Plus boundary before adapting code; a broad upstream patch can change contracts that Plus must preserve.

For each contribution:

- [ ] Link the exact related upstream issue/PR, or state that the search found none.
- [ ] Offer a reusable change upstream, link the existing proposal it supports, or explain why it belongs only in Plus.
- [ ] Credit the source author and exact issue/PR or commit for adapted work; retain its license notices.
- [ ] Explain any fork-only adaptation, deferred upstream offer or upstream decision that requires a local difference.
- [ ] Include focused checks and remaining device/UI acceptance limits. Keep upstream review and merge status separate from those results.

For a bounded contributor task, use the [task form](https://github.com/ryan-winkler/omaconnect-kde-plus/issues/new?template=contributor_task.yml). Give the outcome, owning paths, acceptance checks and upstream route. Maintainers apply **good first issue** only after reviewing the scope.

## Make the change

1. Read [AGENTS.md](AGENTS.md) and the owning domain above.
2. For a behavior defect, add a focused check that fails for the reported case. Use owned temporary state and fake services.
3. Make the smallest complete change. Reuse platform controls and existing domain helpers.
4. Run `./scripts/validate.sh` and `python3 .github/check_doc_links.py`. Report missing prerequisites and skipped checks.
5. Update the relevant contract and [help map](docs/HELP.md). Each feature needs nearby helper text or a direct documentation link.
6. Open a pull request. State the problem, resulting behavior, checks and open device/UI checks.

Small documentation and focused bug fixes can go directly to a PR. For a new provider, public schema, native-module installer or major navigation change, open a feature issue first. This avoids duplicate work and protects the existing boundaries. See the [settings decision](docs/2026-10-29-settings-rice-personas.md) before proposing a second KDE plugin manager.

The stable plugin ID is `Omaconnect.plus`. Do not change it after release: Omarchy registers plugins by manifest ID, and `omarchy plugin update` cannot rename an installed plugin, so a new ID would drop users' bar placement, settings and private metadata. A second provider can justify a shared controller; hypothetical future providers do not justify a framework today.

## Test without changing personal state

The normal suite uses private temporary configuration and fake providers. See [native QA](tests/NATIVE-QA.md) for separate native checks. Hosted CI does not prove installed-bar use, keyboard or assistive-technology acceptance, real delivery or offsite connectivity.

Do not make automated checks install a plugin, restart the shell, change VPN modes, pair devices, read router/phone state or send a real file. An authorized device check must name its scope and record the observed result separately. Never infer receipt from a successful submission command.

## Keep review clear

- Use plain English, short instructions and stable domain names. Explain disabled controls. State must have words as well as color.
- Keep remote names and user text plain. Use fixed argument arrays and bounded input/output.
- Keep appearance, address hints and pairing trust separate. Do not duplicate the UniFi collector or add another protocol daemon.
- Include no credentials, private configurations, raw device inventories or personal receipts. Use small invented examples.
- Record asset sources and licenses. Preserve [MIT attribution](LICENSE) and [upstream lineage](FORK.md).
- Keep one behavior or extraction per change. Avoid unrelated moves and speculative dependencies.

Use `git commit -s` for new contributions when possible. This adds a Developer Certificate of Origin sign-off; it does not transfer your copyright. Read [DCO 1.1](https://developercertificate.org/) before signing. We do not require contributors to rewrite inherited history or install a separate DCO app.

CodeRabbit can provide an additional review when its GitHub app has repository access. Its comments do not replace maintainer review, tests or device evidence. See [release and contributor checks](docs/contributor-release-plan.md) for setup status and limits.

## Add a feature or setting

Reuse the owning domain before creating a new abstraction:

| Change | Source of behavior | Boundary and check |
| --- | --- | --- |
| A reviewed shortcut | `ActionCatalog.js`, then the existing `Panel.qml` dispatcher | Add the ID to preference/migration validation; keep the catalogue parity check. Expose capability, loaded state and help. Never turn a plugin name into an arbitrary command. |
| A Plus preference | `manifest.json` and `PreferenceControls` in the owning Settings domain | Add its typed key to `network_preferences.py` and migration validation. Verify saved readback and defaults. Visibility must not change native permissions or VPN policy. |
| File selection or drop | `FileDropArea.qml` and the existing controller/portal helper | Both the bar and Send target share Copy-only review. Do not add a second transfer engine or implicit Send. |
| Native module support | Searchable `components/NativeFeaturesSection.qml` and selected-device native handoff | Preserve unknown reported IDs. Use a verified native API before offering a direct action. |
| Syncthing | The optional local identity note and existing owner route | Keep sync state, keys and folder operations with Syncthing/Syncshell. |

Keep UI data catalogues small. Python validation remains an independent trust
boundary; parity tests prevent drift. Prefer one focused check to a new framework.
Include nearby helper text or a fixed documentation link for each new control.
