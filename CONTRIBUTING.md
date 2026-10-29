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

## Make the change

1. Read [AGENTS.md](AGENTS.md) and the owning domain above.
2. For a behavior defect, add a focused check that fails for the reported case. Use owned temporary state and fake services.
3. Make the smallest complete change. Reuse platform controls and existing domain helpers.
4. Run `./scripts/validate.sh` and `python3 .github/check_doc_links.py`. Report missing prerequisites and skipped checks.
5. Update the relevant contract and [help map](docs/HELP.md). Each feature needs nearby helper text or a direct documentation link.
6. Open a pull request. State the problem, resulting behavior, checks and open device/UI checks.

Small documentation and focused bug fixes can go directly to a PR. For a new provider, public schema, native-module installer or major navigation change, open a feature issue first. This avoids duplicate work and protects the existing boundaries. See the [settings decision](docs/2026-10-29-settings-rice-personas.md) before proposing a second KDE plugin manager.

The stable plugin ID is `ryan.omaconnect`. Keep existing settings and identity compatible. A second provider can justify a shared controller; hypothetical future providers do not justify a framework today.

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
